#pragma once
#include <thread>
#include <queue>
#include <mutex>
#include "common.hpp"
#include <atomic>
#include <optional>
#include <condition_variable>

struct unitPositionPacket;
class clientData;

enum class gameCommand {
    TS_INFO,                //Synchronous
    POS,                    //Synchronous
    IS_SPEAKING,            //Synchronous
    IS_SPEAKING_BULK,      //Synchronous
    FREQ,                   //Async
    KILLED,                 //Async
    TRACK,                  //Async
    DFRAME,                 //Async
    SPEAKERS,               //Async
    TANGENT,                //Async //TANGENT or TANGENT_LR or TANGENT_DD
    RELEASE_ALL_TANGENTS,   //Async
    SETCFG,                 //Async
    MISSIONEND,             //Async
    AddRadioTower,
    DeleteRadioTower,
    collectDebugInfo,       //Async
    unknown
};

class CommandProcessor {
public:
    CommandProcessor();
    ~CommandProcessor();
    void stopThread();
    void queueCommand(const std::string& command);
    std::string processCommand(const std::string& command);

    static gameCommand toGameCommand(std::string_view textCommand, size_t tokenCount);

    static inline std::atomic_bool vadEnabled = false;
private:
    void threadRun();
    void processAsynchronousCommand(const std::string& command);//Called inside thread

    void processSpeakers(std::vector<std::string_view>& tokens) const;
    void processUnitKilled(std::string &&name, TSServerID serverConnection) const;

    static void processUnitPosition(TSServerID serverConnection, unitPositionPacket& packet);
    static std::string ts_info(std::string_view command);

    //Local tangent (PTT) state machine. Only used by the command thread, so it needs no lock.
    //Idle: VAD and voice are the user's. Transmitting (tangentPressed): VAD disabled by us, voice forced on.
    //Release pending: RELEASED received, voice stays forced until the deadline (pttDelay + tangentReleaseDelay),
    //then VAD is restored and the RELEASED is broadcast. A PRESSED before the deadline cancels it (same
    //transmission) or sends it right away followed by the new PRESSED (other transmission).
    struct PendingTangentRelease {
        std::string commandToBroadcast;
        TSServerID serverConnection;
        std::chrono::steady_clock::time_point deadline;
    };
    void processTangent(const std::vector<std::string_view>& tokens, const std::string& command, TSServerID serverConnection);
    void releaseAllTangents(std::string_view nickname, TSServerID serverConnection);
    void sendPendingTangentRelease(bool restoreVad);
    static std::string tangentBroadcast(std::string_view command, const clientData& myClientData);
    std::optional<PendingTangentRelease> pendingTangentRelease;
    bool voiceForcedByTangent = false; //We disabled VAD and forced voice on (transmitting or release pending)
    std::string lastPressedBroadcast; //PRESSED broadcast other clients currently know about

    static void disableVoiceAndSendCommand(std::string_view commandToBroadcast, dataType::TSServerID currentServerConnectionHandlerID, bool pressed);

    static std::string convertNickname(std::string_view nickname);


    std::queue<std::string> commandQueue;
    std::unique_ptr<std::thread> myThread;
    std::condition_variable threadWorkCondition;
    std::mutex theadMutex;
    bool shouldRun = true;//don't need atomic here. believe me.
    bool threadRunning = false;
};

