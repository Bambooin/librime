//
// Copyright RIME Developers
// Distributed under the BSD License
//

#include <rime/build_config.h>

#ifdef RIME_ENABLE_LOGGING

#include "rime/logging.h"

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <exception>
#include <filesystem>
#include <memory>
#include <mutex>
#include <string>
#include <system_error>
#include <utility>
#include <vector>

#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>
#ifdef __ANDROID__
#include <spdlog/sinks/android_sink.h>
#endif

#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#endif

namespace rime {
namespace {

namespace fs = std::filesystem;

#if defined(RIME_ALSO_LOG_TO_STDERR) && RIME_ALSO_LOG_TO_STDERR
constexpr bool kAlsoLogToStderr = true;
#else
constexpr bool kAlsoLogToStderr = false;
#endif

std::mutex g_mutex;
std::shared_ptr<spdlog::logger> g_logger;
bool g_initialized = false;
bool g_log_to_stderr = true;
std::vector<std::string> g_logging_directories;
std::atomic<int> g_vlog_level{0};

spdlog::level::level_enum ToSpdlogLevel(LogSeverity severity) {
  switch (severity) {
    case LogSeverity::Info:
      return spdlog::level::info;
    case LogSeverity::Warning:
      return spdlog::level::warn;
    case LogSeverity::Error:
      return spdlog::level::err;
    case LogSeverity::Fatal:
      return spdlog::level::critical;
  }
  return spdlog::level::info;
}

spdlog::level::level_enum ToSpdlogLevel(int min_log_level) {
  if (min_log_level <= 0)
    return spdlog::level::info;
  if (min_log_level == 1)
    return spdlog::level::warn;
  if (min_log_level == 2)
    return spdlog::level::err;
  return spdlog::level::critical;
}

char LevelChar(LogSeverity severity) {
  switch (severity) {
    case LogSeverity::Info:
      return 'I';
    case LogSeverity::Warning:
      return 'W';
    case LogSeverity::Error:
      return 'E';
    case LogSeverity::Fatal:
      return 'F';
  }
  return 'I';
}

std::string ToUtf8(const fs::path& path) {
#if defined(__cpp_lib_char8_t)
  const auto value = path.u8string();
  return std::string(value.begin(), value.end());
#else
  return path.u8string();
#endif
}

fs::path ToPath(const std::string& utf8_path) {
#ifdef _WIN32
  return fs::u8path(utf8_path);
#else
  return fs::path(utf8_path);
#endif
}

std::string CurrentDate() {
  std::time_t now = std::time(nullptr);
  std::tm tm = {};
#ifdef _WIN32
  localtime_s(&tm, &now);
#else
  localtime_r(&now, &tm);
#endif
  char buffer[16] = {};
  std::strftime(buffer, sizeof(buffer), "%Y%m%d", &tm);
  return buffer;
}

std::string CurrentPid() {
#ifdef _WIN32
  return std::to_string(_getpid());
#else
  return std::to_string(getpid());
#endif
}

std::vector<fs::path> CandidateDirectories(const char* log_dir) {
  std::vector<fs::path> directories;
  if (log_dir != nullptr && log_dir[0] == '\0')
    return directories;

  if (log_dir != nullptr) {
    directories.push_back(ToPath(log_dir));
    return directories;
  }

  std::error_code ec;
  const auto temp_dir = fs::temp_directory_path(ec);
  if (!ec && !temp_dir.empty())
    directories.push_back(temp_dir);

  const auto current_dir = fs::current_path(ec);
  if (!ec && !current_dir.empty())
    directories.push_back(current_dir);

  std::vector<fs::path> unique_directories;
  for (const auto& directory : directories) {
    if (std::find(unique_directories.begin(), unique_directories.end(),
                  directory) == unique_directories.end()) {
      unique_directories.push_back(directory);
    }
  }
  return unique_directories;
}

std::shared_ptr<spdlog::sinks::basic_file_sink_mt> CreateFileSink(
    const fs::path& directory,
    const std::string& app_name,
    const std::string& date,
    const std::string& pid,
    std::string* file_name) {
  std::error_code ec;
  fs::create_directories(directory, ec);
  std::error_code exists_ec;
  if (ec && !fs::exists(directory, exists_ec)) {
    std::fprintf(stderr, "Rime: failed to create log directory %s: %s\n",
                 ToUtf8(directory).c_str(), ec.message().c_str());
    return nullptr;
  }

  *file_name = app_name + "." + date + "." + pid + ".log";
  const auto file_path = directory / ToPath(*file_name);
  try {
    auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(
        file_path.string(), false);
    fs::permissions(file_path, fs::perms::owner_read | fs::perms::owner_write,
                    fs::perm_options::replace, ec);
    return sink;
  } catch (const spdlog::spdlog_ex& ex) {
    std::fprintf(stderr, "Rime: failed to open log file %s: %s\n",
                 ToUtf8(file_path).c_str(), ex.what());
  } catch (const std::exception& ex) {
    std::fprintf(stderr, "Rime: failed to open log file %s: %s\n",
                 ToUtf8(file_path).c_str(), ex.what());
  }
  return nullptr;
}

void RefreshSymlinks(const fs::path& directory,
                     const std::string& app_name,
                     const std::string& file_name) {
  static const char* const kSeverities[] = {"INFO", "WARNING", "ERROR"};
  for (const char* severity : kSeverities) {
    const auto link_path = directory / ToPath(app_name + "." + severity);
    std::error_code ec;
    fs::remove(link_path, ec);

    ec.clear();
    fs::create_symlink(ToPath(file_name), link_path, ec);
#ifdef _WIN32
    if (ec) {
      // Creating symlinks on Windows often requires elevated privileges.
      // A hard link to the current log file is a useful fallback.
      ec.clear();
      fs::create_hard_link(directory / ToPath(file_name), link_path, ec);
    }
#endif
    if (ec) {
      std::fprintf(stderr, "Rime: failed to create log symlink %s: %s\n",
                   ToUtf8(link_path).c_str(), ec.message().c_str());
    }
  }
}

std::shared_ptr<spdlog::logger> BuildLogger(const char* app_name,
                                            int min_log_level,
                                            const char* log_dir,
                                            bool* log_to_stderr,
                                            std::vector<std::string>* dirs) {
  const std::string normalized_app_name =
      (app_name != nullptr && app_name[0] != '\0') ? app_name : "rime";
  std::vector<spdlog::sink_ptr> sinks;
  bool file_logging = false;

  if (log_dir == nullptr || log_dir[0] != '\0') {
    const auto directories = CandidateDirectories(log_dir);
    for (const auto& directory : directories) {
      dirs->push_back(ToUtf8(directory));
    }

    const std::string date = CurrentDate();
    const std::string pid = CurrentPid();
    for (const auto& directory : directories) {
      std::string file_name;
      auto sink =
          CreateFileSink(directory, normalized_app_name, date, pid, &file_name);
      if (!sink)
        continue;
      sinks.push_back(sink);
      file_logging = true;
      RefreshSymlinks(directory, normalized_app_name, file_name);
      break;
    }

    if (!file_logging) {
#ifdef __ANDROID__
      std::fprintf(stderr,
                   "Rime: no writable log directory found; logging to "
                   "logcat instead.\n");
#else
      std::fprintf(stderr,
                   "Rime: no writable log directory found; logging to "
                   "stderr instead.\n");
#endif
    }
  }

#ifdef __ANDROID__
  sinks.push_back(std::make_shared<spdlog::sinks::android_sink_mt>(
      normalized_app_name, true));
#endif

#ifndef __ANDROID__
  if (!file_logging || kAlsoLogToStderr) {
    sinks.push_back(std::make_shared<spdlog::sinks::stderr_color_sink_mt>());
  }
#else
  if (kAlsoLogToStderr) {
    sinks.push_back(std::make_shared<spdlog::sinks::stderr_color_sink_mt>());
  }
#endif

  auto logger = std::make_shared<spdlog::logger>(normalized_app_name,
                                                 sinks.begin(), sinks.end());
  logger->set_level(ToSpdlogLevel(min_log_level));
  logger->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%L] [%s:%#] %v");
  logger->flush_on(spdlog::level::err);
  *log_to_stderr = !file_logging;
  return logger;
}

}  // namespace

LogMessage::LogMessage(LogSeverity severity, const char* file, int line)
    : severity_(severity), file_(file), line_(line) {}

LogMessage::~LogMessage() {
  LogMessageToSink(severity_, file_, line_, stream_.str());
}

void InitializeLogging(const char* app_name,
                       int min_log_level,
                       const char* log_dir) {
  bool already_initialized = false;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_initialized) {
      already_initialized = true;
    } else {
      g_logging_directories.clear();
      bool log_to_stderr = true;
      auto logger = BuildLogger(app_name, min_log_level, log_dir,
                                &log_to_stderr, &g_logging_directories);
      g_logger = std::move(logger);
      g_log_to_stderr = log_to_stderr;
      g_initialized = true;
    }
  }

  if (already_initialized) {
    LogMessageToSink(LogSeverity::Warning, __FILE__, __LINE__,
                     "Rime logging is already initialized.");
  }
}

void ShutdownLogging() {
  std::shared_ptr<spdlog::logger> logger;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    logger = g_logger;
    g_logger.reset();
    g_initialized = false;
    g_log_to_stderr = true;
    g_logging_directories.clear();
  }
  if (logger) {
    try {
      logger->flush();
    } catch (const std::exception& ex) {
      std::fprintf(stderr, "Rime: failed to flush logs: %s\n", ex.what());
    } catch (...) {
      std::fprintf(stderr, "Rime: failed to flush logs.\n");
    }
  }
}

bool IsLoggingInitialized() {
  std::lock_guard<std::mutex> lock(g_mutex);
  return g_initialized;
}

bool IsLogToStderr() {
  std::lock_guard<std::mutex> lock(g_mutex);
  return g_log_to_stderr;
}

std::vector<std::string> GetLoggingDirectories() {
  std::lock_guard<std::mutex> lock(g_mutex);
  return g_logging_directories;
}

bool VlogIsOn(int verbose_level) {
  return verbose_level <= g_vlog_level.load(std::memory_order_relaxed);
}

void LogMessageToSink(LogSeverity severity,
                      const char* file,
                      int line,
                      const std::string& message) {
  std::shared_ptr<spdlog::logger> logger;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    logger = g_logger;
  }

  const char* source_file = file != nullptr ? file : "";
  if (logger) {
    try {
      logger->log(spdlog::source_loc{source_file, line, ""},
                  ToSpdlogLevel(severity), message);
      if (severity == LogSeverity::Fatal)
        logger->flush();
    } catch (const std::exception& ex) {
      std::fprintf(stderr, "Rime: logging failed: %s\n", ex.what());
    } catch (...) {
      std::fprintf(stderr, "Rime: logging failed.\n");
    }
  } else {
    std::fprintf(stderr, "%c %s:%d] %s\n", LevelChar(severity), source_file,
                 line, message.c_str());
    std::fflush(stderr);
  }

  if (severity == LogSeverity::Fatal)
    std::abort();
}

}  // namespace rime

#endif  // RIME_ENABLE_LOGGING
