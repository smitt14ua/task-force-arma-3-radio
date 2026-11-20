#include "CommandProcessor.hpp"
#include "helpers.hpp"
#include "serverData.hpp"
#include "task_force_radio.hpp"
#include "Logger.hpp"
#include "PlaybackHandler.hpp"
#include <public_rare_definitions.h>
#include "Locks.hpp"
#include "Teamspeak.hpp"
#include "antennaManager.h"
#include "version.h"
#include <iomanip>
#include <filesystem>
#include <string_view>
#include <set>
#include <future>

using namespace std::literals::string_view_literals;

extern bool isSeriousModeEnabled(TSServerID serverConnectionHandlerID, TSClientID clientId);
extern void setGameClientMuteStatus(TSServerID serverConnectionHandlerID, TSClientID clientID, std::pair<bool, bool> isOverRadio = { false,false });

CommandProcessor::CommandProcessor() {
    vadEnabled = Teamspeak::hlp_checkVad();//Needed in case releaseAllTangents is called before the first tangent press

    TFAR::getInstance().doDiagReport.connect([this](std::stringstream& diag) {
        diag << "CP:\n";
        diag << TS_INDENT << "shouldRun: " << shouldRun << "\n";
        diag << TS_INDENT << "cmdQueueBacklog: " << commandQueue.size() << "\n";
        diag << TS_INDENT << "thread: " << myThread->get_id() << "\n";
    });


}


CommandProcessor::~CommandProcessor() {
    stopThread();
}

void CommandProcessor::stopThread() {
    if (!myThread)
        return;
    {
        std::lock_guard<std::mutex> lock(theadMutex);
        shouldRun = false;
    }
    threadWorkCondition.notify_one();
    if (myThread->joinable()) //This happened once.. When something else crashed and dllDetach was called unexpectedly
        myThread->join();
    myThread = nullptr;
}

void CommandProcessor::releaseTransmissionOnGameEnd() {
    if (!myThread || !threadRunning || std::this_thread::get_id() == myThread->get_id())
        return; //No command thread, so no transmission was started either
    auto done = std::make_shared<std::promise<void>>();
    auto finished = done->get_future();
    {
        std::lock_guard<std::mutex> lock(theadMutex);
        taskQueue.emplace([this, done]() {
            if (pendingTangentRelease || TFAR::getInstance().m_gameData.tangentPressed)
                releaseCurrentTransmission(pendingTangentRelease ? pendingTangentRelease->serverConnection : Teamspeak::getCurrentServerConnection());
            done->set_value();
        });
    }
    threadWorkCondition.notify_one();
    finished.wait_for(std::chrono::milliseconds(500)); //Don't hang the caller if the command thread is stuck
}

void CommandProcessor::queueCommand(const std::string& command) {
    ProfileFunction;
    if (!myThread || !threadRunning) {
        shouldRun = true; // thread somehow exited? wtf..
        myThread = std::make_unique<std::thread>(&CommandProcessor::threadRun, this);
        threadRunning = true;
    }
    {
        std::lock_guard<std::mutex> lock(theadMutex);
        commandQueue.emplace(command);
    }
    threadWorkCondition.notify_one();
}



//Minimum number of tab separated tokens (including the command name) a game command needs before its tokens are indexed
static size_t minimumTokenCount(gameCommand command) {
    switch (command) {
        case gameCommand::POS: return 14;
        case gameCommand::FREQ: return 11;
        case gameCommand::TANGENT: return 5;
        case gameCommand::TRACK: return 4;
        case gameCommand::SETCFG: return 3;
        case gameCommand::TS_INFO:
        case gameCommand::IS_SPEAKING:
        case gameCommand::KILLED:
        case gameCommand::RELEASE_ALL_TANGENTS:
        case gameCommand::AddRadioTower:
        case gameCommand::DeleteRadioTower: return 2;
        default: return 1; //SPEAKERS validates its tokens itself
    }
}

static void logMalformedCommand(const std::string& command) {
    Logger::log(LoggerTypes::teamspeakClientlog, "Ignoring malformed game command: " + command, LogLevel_WARNING);
}

DEFINE_API_PROFILER(processCommand)
std::string CommandProcessor::processCommand(const std::string& command) {
    Logger::log(LoggerTypes::gameCommands, command);
    API_PROFILER(processCommand);
    ProfileFunction;
    ProfilerLog(command);
    std::vector<std::string_view> tokens; tokens.reserve(28);
    helpers::split(command, '\t', tokens, 2); //may not be used in nickname
    const auto gameCommand = toGameCommand(tokens[0], tokens.size());
    if (gameCommand == gameCommand::unknown) return "UNKNOWN COMMAND";
    //Only up to 2 tokens are split here, the full POS check happens in the async processing
    if (tokens.size() < std::min<size_t>(minimumTokenCount(gameCommand), 2)) {
        logMalformedCommand(command);
        return "UNKNOWN COMMAND";
    }


    switch (gameCommand) {
        case gameCommand::TS_INFO: return ts_info(tokens[1]);
        case gameCommand::POS:
            //POS nickname [x,y,z] [viewdirUnitvector(x,y,z)] canSpeak canUseSWRadio canUseLRRadio canUseDDRadio vehicleID terrainInterception voiceVolume objectInterception
            queueCommand(command);//do processing async
            [[fallthrough]];
        case gameCommand::IS_SPEAKING: {
            const auto nickname = convertNickname(tokens[1]);
            const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(Teamspeak::getCurrentServerConnection());
            if (!clientDataDir) return "00";
            const auto clientData = clientDataDir->getClientData(nickname);
            if (!clientData)
                return "00";
            const bool receivingTransmission = clientData->receivingTransmission > 0;

            const bool clientTalkingOnRadio = clientData->currentTransmittingTangentOverType != sendingRadioType::LISTEN_TO_NONE;
            if (clientData->clientTalkingNow || clientTalkingOnRadio)
                return receivingTransmission ? "11" : "10";
            return receivingTransmission ? "01" : "00";
        }
        case gameCommand::IS_SPEAKING_BULK:
        {
            tokens.clear();
            helpers::split(command, '\t', tokens); // Previously we only split two tokens for performance reasons

            std::string result;
            result.reserve((tokens.size() - 1) * 3 + 1);

            const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(Teamspeak::getCurrentServerConnection());
            if (!clientDataDir) // No data available, lets say no-one is speaking
            {
                for (size_t i = 1; i < tokens.size(); ++i)
                {
                    result += "00\t";
                }
                return result;
            }


            for (size_t i = 1; i < tokens.size(); ++i)
            {
                const auto nickname = convertNickname(tokens[i]);

                const auto clientData = clientDataDir->getClientData(nickname);
                if (!clientData) // Client not known, lets say they are not speaking
                {
                    result += "00\t";
                    continue;
                }

                const bool receivingTransmission = clientData->receivingTransmission > 0;
                const bool clientTalkingOnRadio = clientData->currentTransmittingTangentOverType != sendingRadioType::LISTEN_TO_NONE;
                // talking, receiving transmission

                if (clientData->clientTalkingNow || clientTalkingOnRadio)
                    result += receivingTransmission ? "11\t" : "10\t";
                else
                    result += receivingTransmission ? "01\t" : "00\t";
            }

            return result;
        }
    }

    return "ASYNC COMMAND SENT IN SYNC CONTEXT";
}


gameCommand CommandProcessor::toGameCommand(std::string_view textCommand, size_t tokenCount) {
    if (textCommand.length() < 3) return gameCommand::unknown;
    const auto hash = const_strhash(textCommand.data(), textCommand.length());
    switch (hash) {
        case FORCE_COMPILETIME(const_strhash("POS"sv)):
            return gameCommand::POS;
        case FORCE_COMPILETIME(const_strhash("IS_SPEAKING"sv)):
            return gameCommand::IS_SPEAKING;
        case FORCE_COMPILETIME(const_strhash("IS_SPEAKING_BULK"sv)):
            return gameCommand::IS_SPEAKING_BULK;
        case FORCE_COMPILETIME(const_strhash("TS_INFO"sv)):
            return gameCommand::TS_INFO;
        case FORCE_COMPILETIME(const_strhash("FREQ"sv)):
            return gameCommand::FREQ;
        case FORCE_COMPILETIME(const_strhash("KILLED"sv)):
            return gameCommand::KILLED;
        case FORCE_COMPILETIME(const_strhash("DFRAME"sv)):
            return gameCommand::DFRAME;
        case FORCE_COMPILETIME(const_strhash("TRACK"sv)):
            return gameCommand::TRACK;
        case FORCE_COMPILETIME(const_strhash("SPEAKERS"sv)):
            return gameCommand::SPEAKERS;
        case FORCE_COMPILETIME(const_strhash("RELEASE_ALL_TANGENTS"sv)):
            return gameCommand::RELEASE_ALL_TANGENTS;
        case FORCE_COMPILETIME(const_strhash("MISSIONEND"sv)):
            return gameCommand::MISSIONEND;
        case FORCE_COMPILETIME(const_strhash("SETCFG"sv)):
            return gameCommand::SETCFG;
        case FORCE_COMPILETIME(const_strhash("TANGENT"sv)):
        case FORCE_COMPILETIME(const_strhash("TANGENT_LR"sv)):
        case FORCE_COMPILETIME(const_strhash("TANGENT_DD"sv)):
            return gameCommand::TANGENT;
        case FORCE_COMPILETIME(const_strhash("RadioTwrAdd"sv)):
            return gameCommand::AddRadioTower;
        case FORCE_COMPILETIME(const_strhash("RadioTwrDel"sv)):
            return gameCommand::DeleteRadioTower;
        case FORCE_COMPILETIME(const_strhash("collectDebugInfo"sv)):
            return gameCommand::collectDebugInfo;
    }
    return gameCommand::unknown;
}

void CommandProcessor::threadRun() {
    threadRunning = true;
    //An exception escaping this thread would terminate TeamSpeak
    const auto runGuarded = [](const std::string& what, auto&& function) {
        try {
            function();
        } catch (const std::exception& ex) {
            Logger::log(LoggerTypes::teamspeakClientlog, std::string("Game command failed: ") + ex.what() + " (" + what + ")", LogLevel_ERROR);
        } catch (...) {
            Logger::log(LoggerTypes::teamspeakClientlog, "Game command failed: unknown exception (" + what + ")", LogLevel_ERROR);
        }
    };
    const auto sendDueTangentRelease = [this, &runGuarded]() {
        if (pendingTangentRelease && std::chrono::steady_clock::now() >= pendingTangentRelease->deadline)
            runGuarded("delayed tangent release", [this]() { sendPendingTangentRelease(true); });
    };
    while (shouldRun) {
        std::unique_lock<std::mutex> lock(theadMutex);
        const auto hasWork = [this] {return !commandQueue.empty() || !taskQueue.empty() || !shouldRun; };
        //A delayed tangent release is due at its deadline, handled here instead of by a detached thread
        if (pendingTangentRelease)
            threadWorkCondition.wait_until(lock, pendingTangentRelease->deadline, hasWork);
        else
            threadWorkCondition.wait(lock, hasWork);
        if (!shouldRun) break;
        if (!taskQueue.empty() && commandQueue.empty()) { //Internal work after the commands queued before it
            auto task = std::move(taskQueue.front());
            taskQueue.pop();
            lock.unlock();
            sendDueTangentRelease();
            runGuarded("internal task", task);
            continue;
        }
        if (commandQueue.empty()) { //release deadline reached
            lock.unlock();
            sendDueTangentRelease();
            continue;
        }
        ProfileFunction;
        const auto command(std::move(commandQueue.front()));
        commandQueue.pop();
        lock.unlock();
        sendDueTangentRelease(); //A release that is already due goes out before the next command
        runGuarded(command, [this, &command]() { processAsynchronousCommand(command); });
    }
    //Shutting down while transmitting or a release is pending: release now (TeamSpeak is still loaded and our game
    //name still set, onGameEnd runs after this), so nobody keeps hearing us
    if (pendingTangentRelease)
        runGuarded("delayed tangent release", [this]() { sendPendingTangentRelease(true); });
    else if (TFAR::getInstance().m_gameData.tangentPressed)
        runGuarded("tangent release on shutdown", [this]() { releaseCurrentTransmission(Teamspeak::getCurrentServerConnection()); });
    threadRunning = false;
}


DEFINE_API_PROFILER(processAsynchronousCommand)
void CommandProcessor::processAsynchronousCommand(const std::string& command) {
    if (command.substr(0,3) != "POS") //else double log as POS is also logged in sync processing
        Logger::log(LoggerTypes::gameCommands, command);
    API_PROFILER(processAsynchronousCommand);
    ProfileFunction;
    ProfilerLog(command);
    std::vector<std::string_view> tokens; tokens.reserve(18);
    helpers::split(command, '\t', tokens); //may not be used in nickname
    const auto gameCommand = toGameCommand(tokens[0], tokens.size());
    if (gameCommand == gameCommand::unknown) return;
    if (tokens.size() < minimumTokenCount(gameCommand)) {
        logMalformedCommand(command);
        return;
    }
    TSServerID currentServerConnectionHandlerID = Teamspeak::getCurrentServerConnection();
    auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(currentServerConnectionHandlerID);
    if (!clientDataDir) return;


    switch (gameCommand) {

        case gameCommand::FREQ: {//async
                                 //FREQ, str(_freq), str(_freq_lr)
                                //_alive, speakVolume, _nickname, 
                                //waves, TF_terrain_interception_coefficient, _globalVolume,
                                //_receivingDistanceMultiplicator, TF_speakerDistance

            TFAR::getInstance().m_gameData.setFreqInfos(tokens);

            if (!clientDataDir->myClientData) return;//shouldn't be possible.. but safety first

            //Rename to ingame name. This is okey here as long as we always get FREQ commands. Even if now having any Radios
            //Could be replaced by telling everyone in channel our ingame name.. So they can assign it to clientID. If we really want to remove renaming in TS
            const std::string& nickname = convertNickname(tokens[5]);
            std::string myNickname = Teamspeak::getMyNickname(currentServerConnectionHandlerID);
            if (!myNickname.empty() && myNickname != nickname && (nickname != "Error: No unit" && nickname != "Error: No vehicle" && nickname != "any")) {
                //Requests the rename (retries of the same name are rate limited inside). Our own data is indexed under
                //the game name right away: our own POS commands use it, also while (or if) TS hasn't applied it.
                //TS confirms a successful rename with onUpdateClientEvent, which re-indexes under the same name again.
                if (Teamspeak::setMyNicknameToGameName(currentServerConnectionHandlerID, nickname)) {
                    TFAR::getInstance().onTeamspeakClientUpdated(currentServerConnectionHandlerID, clientDataDir->myClientData->clientId, nickname);
                }
            }
        } return;
        case gameCommand::POS: {
            //POS nickname [x,y,z] [viewdirUnitvector(x,y,z)] canSpeak canUseSWRadio canUseLRRadio canUseDDRadio vehicleID terrainInterception voiceVolume objectInterception
            unitPositionPacket packet{
                convertNickname(tokens[1]),                 //nickname
                Position3D(tokens[2]),                      //position
                Direction3D(tokens[3]),                     //direction
                helpers::isTrue(tokens[4]),                 //canSpeak
                helpers::isTrue(tokens[5]),                 //canUseSWRadio
                helpers::isTrue(tokens[6]),                 //canUseLRRadio
                helpers::isTrue(tokens[7]),                 //canUseDDRadio
                tokens[8],                                  //vehicleID
                helpers::parseArmaNumberToInt(tokens[9]),   //terrainInterception
                helpers::parseArmaNumber(tokens[10]),       //voiceVolume
                helpers::parseArmaNumberToInt(tokens[11]),  //objectInterception
                helpers::isTrue(tokens[12]),                //isSpectating
                helpers::isTrue(tokens[13])                 //isEnemyToPlayer
            };

            processUnitPosition(currentServerConnectionHandlerID, packet);
        } return;
        case gameCommand::KILLED:
            processUnitKilled(convertNickname(tokens[1]), currentServerConnectionHandlerID);
            return;
        case gameCommand::TRACK:
            TFAR::trackPiwik(tokens);
            return;
        case gameCommand::DFRAME:
        {
            //Don't overflow INVALID_DATA_FRAME (INT_MAX, e.g. a DFRAME after game disconnect): restart at 0 instead
            auto& currentDataFrame = TFAR::getInstance().m_gameData.currentDataFrame;
            currentDataFrame = (currentDataFrame >= INVALID_DATA_FRAME - 1) ? 0 : currentDataFrame + 1;
        }
            return;
        case gameCommand::SPEAKERS:
            processSpeakers(tokens);
            return;
        case gameCommand::TANGENT: //async
            processTangent(tokens, command, currentServerConnectionHandlerID);
            return;
        case gameCommand::RELEASE_ALL_TANGENTS:
            releaseAllTangents(convertNickname(tokens[1]), currentServerConnectionHandlerID);
            return;
        case gameCommand::SETCFG: {//async
            const auto key = tokens[1];
            const auto value = tokens[2];
            const Setting keyEnum(key);
            if (!settings::isValidKey(keyEnum)) {
                std::string msg;
                msg.reserve("Used invalid config key: "sv.length() + key.length() + " (You probably need to update your TFAR Teamspeak plugin)"sv.length());
                msg += "Used invalid config key: "sv;
                msg += key;
                msg += " (You probably need to update your TFAR Teamspeak plugin)"sv;

                Logger::log(LoggerTypes::teamspeakClientlog, msg, LogLevel_WARNING);
                //Show it without blocking, so game messages keep being processed while the box is open. Once per text.
                static std::mutex shownMutex;
                static std::set<std::string, std::less<>> shownMessages;
                std::lock_guard<std::mutex> shownLock(shownMutex);
                if (const auto [it, inserted] = shownMessages.insert(std::move(msg)); inserted) {
                    helpers::showMessageBoxDetached(*it, "Task Force Radio", MB_OK);
                }
                return;
            }
            if (tokens.size() == 4) {
                const auto type = tokens[3];
                if (type == "BOOL"sv) {
                    TFAR::config.set(key, value == "true"sv || value == "TRUE"sv);
                } else if (type == "SCALAR"sv) {
                    TFAR::config.set(key, helpers::parseArmaNumber(value));
                } else {//unsupported type or STRING
                    TFAR::config.set(key, value);
                }
            } else {
                TFAR::config.set(key, std::string(""));
            }
        } return;
        case gameCommand::MISSIONEND: //Handled by pipe extension. That sets last GameTick to 0 so SharedMemoryHandler::onDisconnected will fire
            //TFAR::getInstance().onGameDisconnected();
            //Practically never arrives: the extension wipes the async queue right after queueing it (onShutdown)
            return;
        case gameCommand::AddRadioTower: {
            auto data = helpers::split(tokens[1], 0xA);
            for (auto& element : data) {
                auto antennaData = helpers::split(element, ';');
                if (antennaData.size() == 3)
                  TFAR::getAntennaManager()->addAntenna(Antenna(NetID(antennaData[0]), Position3D(antennaData[2]), helpers::parseArmaNumber(antennaData[1])));
                else {
                    //#TODO log?
                }
            }
            return;

        }

        case gameCommand::DeleteRadioTower: {
            auto data = helpers::split(tokens[1], 0xA);
            for (auto& element : data) {
                TFAR::getAntennaManager()->removeAntenna(element);
            }
            return;

        }
        case gameCommand::collectDebugInfo: {
            std::stringstream date;
            const auto now = std::chrono::system_clock::now();
            const auto in_time_t = std::chrono::system_clock::to_time_t(now);
            date << std::put_time(std::localtime(&in_time_t), "%d-%m_%H-%M-%S");
            const auto dateString = date.str();

            auto basePath = std::string(getenv("appdata")) + R"(\TS3Client\logs\)" + dateString + "\\";
            std::error_code err;

            std::filesystem::create_directories(basePath,err);

            Logger::flushAll(); //File loggers don't flush every line

            std::filesystem::copy(std::string(getenv("appdata")) + R"(\TS3Client\TFAR_pluginCommands.log)", basePath + "TFAR_pluginCommands.log",err);
            std::filesystem::copy(std::string(getenv("appdata")) + R"(\TS3Client\TFAR_gameCommands.log)", basePath + "TFAR_gameCommands.log", err);

            clientDataDir->forEachClient([&basePath](const std::shared_ptr<clientData>& cli) {
                auto messages = cli->takeCircularLog();
                auto nick = cli->getNickname();
                constexpr auto illegalChars = R"(\/:?"<>|)"sv;
                for (auto it = nick.begin(); it < nick.end(); ++it) {
                    if (illegalChars.find(*it) != std::string::npos) {
                        *it = ' ';
                    }
                }

                std::ofstream fs(basePath + "CL_" + nick + ".log");
                for (auto& msg : messages) {
                    fs << msg << '\n';
                }

                std::ofstream vdl(basePath + "VDL_" + nick + ".log");
                cli->verboseDataLog(vdl);
            });


            std::stringstream diag;
            diag << "diag from " << dateString << "\n";
            TFAR::getInstance().doDiagReport(diag);

            std::ofstream fsd(basePath + "diag.log");
            fsd << diag.str();

            std::stringstream pos;
            TFAR::getInstance().doTypeDiagReport("pos", pos);
            std::ofstream fsp(basePath + "pos.log");
            fsp << pos.str();
            Teamspeak::printMessageToCurrentTab((std::string("TFAR: logged to ") + basePath).c_str());

        }
    }
}

//TANGENT game command + what other clients need to know about us
std::string CommandProcessor::tangentBroadcast(std::string_view command, const clientData& myClientData) {
    return std::string(command) + "\t" + (myClientData.canUseSWRadio ? "1\t" : "0\t") + (myClientData.canUseDDRadio ? "1\t" : "0\t") + myClientData.getNickname();
}

void CommandProcessor::processTangent(const std::vector<std::string_view>& tokens, const std::string& command, TSServerID currentServerConnectionHandlerID) {
    //TANGENT, PRESSED/RELEASED, _freq+Radiocode, Range inclusive transmittingdist Multiplicator, Subtype, classname
    const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(currentServerConnectionHandlerID);
    if (!clientDataDir) return;
    auto myClientData = clientDataDir->myClientData;
    if (!myClientData) return; //safety first

    const bool pressed = tokens[1] == "PRESSED"sv;

    const auto subtypeString = tokens[4];
    const auto subtype = PTTDelayArguments::stringToSubtype(tokens[4]);

    const bool changed = TFAR::getInstance().m_gameData.tangentPressed != pressed;

    if (!changed) //If nothing changed there is nothing to do.
        return;

    TFAR::getInstance().m_gameData.tangentPressed = pressed;

    myClientData->setCurrentTransmittingSubtype(subtypeString);

    if (pressed) {
        myClientData->range = helpers::parseArmaNumberToInt(tokens[3]); //range needs to be set to indicate that we are transmitting
        if (myClientData->currentTransmittingTangentOverType == sendingRadioType::LISTEN_TO_NONE)
            myClientData->effects.requestStateReset(); //new transmission: drop the radio effect state of the previous one
        myClientData->currentTransmittingTangentOverType = (tokens[0] == "TANGENT_LR") ? sendingRadioType::LISTEN_TO_LR : sendingRadioType::LISTEN_TO_SW;

        myClientData->setCurrentTransmittingFrequency(tokens[2]);
    } else {
        myClientData->range = 0; //range needs to be set to indicate that we are transmitting
        myClientData->currentTransmittingTangentOverType = sendingRadioType::LISTEN_TO_NONE;
        myClientData->setCurrentTransmittingFrequency(std::string("prev_").append(tokens[2]));
    }


    auto commandToBroadcast = tangentBroadcast(command, *myClientData);
    playTangentSound(currentServerConnectionHandlerID, tokens[2], subtypeString, pressed);

    if (!pressed) {
        if (!TFAR::config.get<bool>(Setting::full_duplex)) {
            TFAR::getInstance().m_gameData.setCurrentTransmittingRadio("");
        }
        //Voice stays forced on until the deadline. Only one release can be pending: a RELEASED needs a PRESSED
        //before it, and that PRESSED resolved any older pending release.
        const auto pttDelay = std::max(TFAR::getInstance().m_gameData.pttDelay, 0ms);
        const auto tangentReleaseDelay = std::max(std::chrono::milliseconds(static_cast<int>(TFAR::config.get<float>(Setting::tangentReleaseDelay))), 0ms);
        pendingTangentRelease = PendingTangentRelease{ std::move(commandToBroadcast), currentServerConnectionHandlerID,
            std::chrono::steady_clock::now() + pttDelay + tangentReleaseDelay };
        return;
    }

    if (!TFAR::config.get<bool>(Setting::full_duplex) && tokens.size() == 6) {
        TFAR::getInstance().m_gameData.setCurrentTransmittingRadio(tokens[5]);
    }

    if (pendingTangentRelease) {
        //Pressed again before the delayed release went out. VAD is still disabled by us, so don't read it again.
        if (commandToBroadcast == lastPressedBroadcast) {
            pendingTangentRelease.reset(); //Same transmission: others still hear it, just keep transmitting
            return;
        }
        //Other radio/frequency/type: others need the old RELEASED first, exactly as after a normal release + press
        sendPendingTangentRelease(false);
    } else if (!voiceForcedByTangent) {
        //Force enable PTT
        vadEnabled = Teamspeak::hlp_checkVad();
        if (vadEnabled) Teamspeak::hlp_disableVad();
    }
    voiceForcedByTangent = true;
    lastPressedBroadcast = commandToBroadcast;
    // broadcast info about tangent pressed over all client
    disableVoiceAndSendCommand(commandToBroadcast, currentServerConnectionHandlerID, true);
}

void CommandProcessor::sendPendingTangentRelease(bool restoreVad) {
    if (!pendingTangentRelease) return;
    //Take it out first, so a failing TeamSpeak call can't make the command thread retry it forever
    const auto release = std::move(*pendingTangentRelease);
    pendingTangentRelease.reset();
    lastPressedBroadcast.clear();
    if (!restoreVad) { //A new transmission follows right away, keep voice forced on
        Teamspeak::sendPluginCommand(release.serverConnection, TFAR::getInstance().getPluginID(), release.commandToBroadcast, PluginCommandTarget_CURRENT_CHANNEL);
        return;
    }
    voiceForcedByTangent = false;
    if (vadEnabled) Teamspeak::hlp_enableVad();
    disableVoiceAndSendCommand(release.commandToBroadcast, release.serverConnection, false);
}

void CommandProcessor::playTangentSound(TSServerID serverConnection, std::string_view frequency, std::string_view subtypeString, bool pressed) {
    const auto subtype = PTTDelayArguments::stringToSubtype(subtypeString);
    auto soundToPlay = SoundDirectory::getRadioSound(subtype, pressed);
    if (soundToPlay.isEmpty()) return;
    const float globalVolume = TFAR::getInstance().m_gameData.globalVolume;
    //Only hold the lock for the lookup: playing may need other locks
    std::optional<FREQ_SETTINGS> settings;
    {
        LockGuard_shared frequencyLock(TFAR::getInstance().m_gameData.m_lock);
        const auto& frequencyMap = subtype == PTTDelayArguments::subtypes::digital ? TFAR::getInstance().m_gameData.mySwFrequencies : TFAR::getInstance().m_gameData.myLrFrequencies;
        if (const auto found = frequencyMap.find(frequency); found != frequencyMap.end())
            settings = found->second;
    }
    if (settings)
        TFAR::getPlaybackHandler()->playWavFile(serverConnection, soundToPlay, helpers::volumeMultiplifier(static_cast<float>(settings->volume)) * globalVolume, settings->stereoMode);
    else
        TFAR::getPlaybackHandler()->playWavFile(soundToPlay);
}

void CommandProcessor::releaseAllTangents(std::string_view nickname, TSServerID currentServerConnectionHandlerID) {
    //Need to release tangent in case it's currently pressed else player will hotmic. Happens right away.
    releaseCurrentTransmission(currentServerConnectionHandlerID);
    disableVoiceAndSendCommand(std::string("RELEASE_ALL_TANGENTS\t").append(nickname), currentServerConnectionHandlerID, false);
}

void CommandProcessor::releaseCurrentTransmission(TSServerID currentServerConnectionHandlerID) {
    //Clients with an older plugin only stop "receiving" us on a RELEASED, so the current transmission gets its
    //RELEASED first: a pending one, or (still held) the one the mod's own release would send. The old plugin sent
    //that RELEASED too, after the mod's release; the mod's later RELEASED is now dropped as unchanged instead.
    if (pendingTangentRelease) {
        sendPendingTangentRelease(false);
    } else if (TFAR::getInstance().m_gameData.tangentPressed && !lastPressedBroadcast.empty()) {
        const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(currentServerConnectionHandlerID);
        const auto myClientData = clientDataDir ? clientDataDir->myClientData : nullptr;
        //PRESSED broadcast: type PRESSED freq+code range subtype [classname] canUseSW canUseDD nickname.
        //The mod's RELEASED is: type RELEASED freq+code range subtype
        std::vector<std::string_view> pressedTokens;
        helpers::split(lastPressedBroadcast, '\t', pressedTokens);
        if (myClientData && pressedTokens.size() >= 5) {
            std::string releasedCommand(pressedTokens[0]);
            releasedCommand.append("\tRELEASED\t").append(pressedTokens[2]).append("\t").append(pressedTokens[3]).append("\t").append(pressedTokens[4]);
            Teamspeak::sendPluginCommand(currentServerConnectionHandlerID, TFAR::getInstance().getPluginID(), tangentBroadcast(releasedCommand, *myClientData), PluginCommandTarget_CURRENT_CHANNEL);
            //The mod's own RELEASED (and its sound) is dropped as unchanged now, play the release sound here
            playTangentSound(currentServerConnectionHandlerID, pressedTokens[2], pressedTokens[4], false);
        }
    }
    if (voiceForcedByTangent) {
        if (vadEnabled) Teamspeak::hlp_enableVad();
        voiceForcedByTangent = false;
    } else {
        vadEnabled = Teamspeak::hlp_checkVad(); //VAD is the user's here, don't restore a stale state
    }
    lastPressedBroadcast.clear();

    //Reset the local transmission, else a following PRESSED is dropped as unchanged and IS_SPEAKING stays "1x"
    TFAR::getInstance().m_gameData.tangentPressed = false;
    if (!TFAR::config.get<bool>(Setting::full_duplex)) {
        TFAR::getInstance().m_gameData.setCurrentTransmittingRadio("");
    }
    if (const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(currentServerConnectionHandlerID); clientDataDir) {
        if (const auto myClientData = clientDataDir->myClientData; myClientData) {
            if (myClientData->currentTransmittingTangentOverType != sendingRadioType::LISTEN_TO_NONE)
                myClientData->setCurrentTransmittingFrequency(std::string("prev_").append(myClientData->getCurrentTransmittingFrequency()));
            myClientData->range = 0;
            myClientData->currentTransmittingTangentOverType = sendingRadioType::LISTEN_TO_NONE;
        }
    }
}

void CommandProcessor::processSpeakers(std::vector<std::string_view>& tokens) const {
    //#TODO we don't really need to send Speakers every time.. Their pos is always static. Either on a person or on ground
    //Parsed without the lock (the audio thread reads speakers under it) and swapped in at the end.
    //Whatever got parsed is applied, also on early exit (empty if the command is malformed).
    decltype(gameData::speakers) speakers;
    const auto swapIn = [&speakers]() {
        LockGuard_exclusive lock(TFAR::getInstance().m_gameData.m_lock);
        TFAR::getInstance().m_gameData.speakers.swap(speakers);
    };
    if (tokens.size() != 2) {
        swapIn();
        return;
    }
    ProfileFunction;

    //if you switch TS tab... You don't get speakers bro!
    const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(Teamspeak::getCurrentServerConnection());
    if (!clientDataDir) {
        swapIn();
        return;
    }

    for (auto& speaker : helpers::split(tokens[1], 0xB)) {
        if (speaker.empty()) continue;

        std::vector<std::string_view> parts; parts.reserve(7);
        helpers::split(speaker, 0xA, parts);
        if (parts.size() < 6) break;
        //parts radio_id,nickname,pos,volume,vehicle,(waveZ)
        const auto clientData = clientDataDir->getClientData(convertNickname(parts[2]));

        SPEAKER_DATA data;
        data.radio_id = parts[0];
        data.client = clientData;
        data.pos = Position3D(parts[3]);
        data.volume = helpers::parseArmaNumberToInt(parts[4]);
        data.vehicle = helpers::getVehicleDescriptor(parts[5]);
        if (parts.size() > 6)
            data.waveZ = helpers::parseArmaNumber(parts[6]);
        else
            data.waveZ = data.pos.isNull() ? 1 : data.pos[2];

        for (auto& freq : helpers::split(parts[1], '|')) {
            speakers.insert(std::pair<std::string, SPEAKER_DATA>(freq, data));
        }
    }
    swapIn();
}

void CommandProcessor::processUnitKilled(std::string &&name, TSServerID serverConnection) const {
    ProfileFunction;
    const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(serverConnection);
    if (!clientDataDir)
        return;

    const auto killedData = clientDataDir->getClientData(name);
    if (killedData) {
        killedData->dataFrame = INVALID_DATA_FRAME;
    }

    //Someone else died: only his own mute state can change. Re-evaluating the whole channel for every death
    //(a mod that sends remote deaths too) makes every client send bulk unmutes and then re-mute far players one by
    //one, flooding the TeamSpeak server on big servers.
    if (killedData && killedData != clientDataDir->myClientData) {
        setGameClientMuteStatus(serverConnection, killedData->clientId);
        return;
    }

    const bool isSeriousMode = isSeriousModeEnabled(serverConnection, Teamspeak::getMyId(serverConnection));

    if (clientDataDir->myClientData) {
        if (clientDataDir->myClientData->dataFrame == INVALID_DATA_FRAME)
            TFAR::getInstance().m_gameData.alive = false;
    }

    const auto clientsIds = Teamspeak::getChannelClients(serverConnection, Teamspeak::getChannelOfClient(serverConnection));

    if (!isSeriousMode && !TFAR::getInstance().m_gameData.alive) {
        //If not seriousMode we can hear everyone when Dead
        Teamspeak::setClientMute(serverConnection, clientsIds, false);
        return;
    }

    const auto myId = Teamspeak::getMyId(serverConnection);
    std::vector<TSClientID> aliveClients; aliveClients.reserve(clientsIds.size());
    std::vector<TSClientID> deadClients;  deadClients.reserve(clientsIds.size());
    for (auto& id : clientsIds) {
        if (id == myId) continue;
        auto clientData = clientDataDir->getClientData(id);
        if (clientData && clientData->isAlive()) {
            aliveClients.push_back(id);
        } else {
            deadClients.push_back(id);
        }
    }
    /*
    serious mode:
    dead can hear dead.
    alive can hear alive
    alive cant hear dead
    dead cant hear alive

    non-serious mode:
    dead can hear dead.
    alive can hear alive
    alive can hear dead
    dead can hear alive
    */

    if (!TFAR::config.get<bool>(Setting::disableAutomaticMute)) {
        Teamspeak::setClientMute(serverConnection, deadClients, TFAR::getInstance().m_gameData.alive && isSeriousMode); //Mute dead people if seriousMode
        Teamspeak::setClientMute(serverConnection, aliveClients, !TFAR::getInstance().m_gameData.alive && isSeriousMode); //Mute alive people if seriousMode
    }
}


DEFINE_API_PROFILER(processUnitPosition)

void CommandProcessor::processUnitPosition(TSServerID serverConnection, unitPositionPacket& packet) {
    API_PROFILER(processUnitPosition);
    ProfileFunction;
    const auto clientDataDir = TFAR::getServerDataDirectory()->getClientDataDirectory(serverConnection);
    if (!clientDataDir) return;

    auto clientData = clientDataDir->getClientData(packet.nickname);
    if (!clientData) return;

    packet.myData = clientData == clientDataDir->myClientData;

    clientData->updatePosition(packet);
    //bool clientTalkingOnRadio = (clientData->currentTransmittingTangentOverType != sendingRadioType::LISTEN_TO_NONE) || clientData->clientTalkingNow;

    if (packet.myData) {
        Teamspeak::setMyClient3DPosition(serverConnection, Position3D());
    } else {
        setGameClientMuteStatus(serverConnection, clientData->clientId);
        Teamspeak::setClient3DPosition(serverConnection, clientData->clientId, Position3D());
    }
}

std::string CommandProcessor::ts_info(std::string_view command) {
    if (command == "SERVER")
        return Teamspeak::getServerName();
    if (command == "SERVERUID") 
        return Teamspeak::getServerUID();
    if (command == "CHANNEL")
        return Teamspeak::getChannelName();
    if (command == "CHANNELID")
        return std::to_string(Teamspeak::getChannelOfClient().baseType());
    if (command == "PING")
        return "PONG";
    if (command == "VERSION")
        return PLUGIN_VERSION;
    return "FAIL";
}

void CommandProcessor::disableVoiceAndSendCommand(std::string_view commandToBroadcast, TSServerID currentServerConnectionHandlerID, bool pressed) {
    Teamspeak::setVoiceDisabled(currentServerConnectionHandlerID, !(pressed || vadEnabled));
    Teamspeak::sendPluginCommand(currentServerConnectionHandlerID, TFAR::getInstance().getPluginID(), commandToBroadcast, PluginCommandTarget_CURRENT_CHANNEL);
}

std::string CommandProcessor::convertNickname(std::string_view nickname) {
    ProfileFunction;
    if (!nickname.empty() && (nickname.front() == ' ' || nickname.back() == ' ')) {
        std::string newName(nickname);
        if (nickname.front() == ' ') {
            newName.replace(0, nickname.find_first_not_of(' '), nickname.find_first_not_of(' '), '_');
        }
        if (nickname.back() == ' ') {
            newName.replace(nickname.find_last_not_of(' ') + 1, newName.length() - nickname.find_last_not_of(' ') - 1, newName.length() - nickname.find_last_not_of(' ') - 1, '_');
        }
        return newName;
    }
    return std::string(nickname);
}
