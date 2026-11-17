#include "Logger.hpp"
#include "ts3_functions.h"
#include "profilers.hpp"
#include <ctime>
#include <iomanip> // put_time
#include <utility>

extern struct TS3Functions ts3Functions;
FileLogger::FileLogger(const std::string& filePath) : file(filePath) {}

FileLogger::~FileLogger() {
    flush();
}

void FileLogger::log(const std::string& message) {
    //Written from several threads
    std::lock_guard lock(fileMutex);
    if (file.is_open()) {
        const auto now = std::chrono::system_clock::now();
        auto inTimeT = std::chrono::system_clock::to_time_t(now);
        file << std::put_time(std::localtime(&inTimeT), "%H:%M:%S") << " " << message;
        //Flushing every line is slow, flush at most once a second (and on flush()/close)
        const auto steadyNow = std::chrono::steady_clock::now();
        if (steadyNow - lastFlush >= std::chrono::seconds(1)) {
            file.flush();
            lastFlush = steadyNow;
        }
    }
}

void FileLogger::flush() {
    std::lock_guard lock(fileMutex);
    if (file.is_open()) {
        file.flush();
        lastFlush = std::chrono::steady_clock::now();
    }
}

void FileLogger::log(const std::string& message, LogLevel _loglevel) {
    log(message); //#TODO add prefix according to loglevel
}

TeamspeakLogger::TeamspeakLogger(enum LogLevel defaultLoglevel) : level(defaultLoglevel) {}

void TeamspeakLogger::log(const std::string& message) {
    ts3Functions.logMessage(message.c_str(), level, "task_force_radio", 141);
}

void TeamspeakLogger::log(const std::string& message, LogLevel _loglevel) {
    ts3Functions.logMessage(message.c_str(), _loglevel, "task_force_radio", 141);
}

void CircularLogger::log(const std::string& message) {
    messages[offset] = message;
    if (++offset > messageCount) offset = 0;
}

void CircularLogger::log(const std::string& message, LogLevel _loglevel) {
    log(message);
}

void Logger::registerLogger(LoggerTypes type, std::shared_ptr<ILogger> logger) {
    getInstance()._registerLogger(type, std::move(logger));
}

void Logger::log(LoggerTypes type, const std::string& message) {
    getInstance()._log(type, message);
}

void Logger::log(LoggerTypes type, const std::string & message, LogLevel _loglevel) {
#if DEBUG_MOD_ENABLED || isCI
    if (
    #if ENABLE_PLUGIN_LOGS
        type == LoggerTypes::pluginCommands ||
    #endif
        (_loglevel != LogLevel_DEVEL && _loglevel != LogLevel_DEBUG))
    #endif
        getInstance()._log(type, message, _loglevel);
}

std::vector<std::shared_ptr<ILogger>> Logger::getLogger(LoggerTypes type) {
    const auto found = getInstance().registeredLoggers.find(type);
    if (found != getInstance().registeredLoggers.end())
        return found->second;
    return {};
}

void Logger::flushAll() {
    for (const auto& [type, loggers] : getInstance().registeredLoggers) {
        for (const auto& logger : loggers) {
            logger->flush();
        }
    }
}

void Logger::_registerLogger(LoggerTypes type, std::shared_ptr<ILogger> logger) {
    registeredLoggers[type].emplace_back(logger);
}

void Logger::_log(LoggerTypes type, const std::string& message) const {
    const auto found = registeredLoggers.find(type);
    if (found != registeredLoggers.end()) {
        for (const std::shared_ptr<ILogger>& it : registeredLoggers.at(type)) {
            it->log(message.back() == '\n' ? message : message + '\n');
        }
    }
    //If not found exit silently
}

void Logger::_log(LoggerTypes type, const std::string& message, LogLevel _loglevel) const {
    const auto found = registeredLoggers.find(type);
    if (found != registeredLoggers.end()) {
        for (const std::shared_ptr<ILogger>& it : registeredLoggers.at(type)) {
            it->log(message.back() == '\n' ? message : message + '\n', _loglevel);
        }
    }
    //If not found exit silently
}

void DebugStringLogger::log(const std::string & message) { OutputDebugStringA(message.c_str()); printf("%s", message.c_str()); }

void DebugStringLogger::log(const std::string & message, LogLevel _loglevel) { OutputDebugStringA(message.c_str()); printf("%s", message.c_str()); }
