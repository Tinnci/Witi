import 'dart:io';
import 'dart:convert';

/// Logging levels for the game
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical;

  /// Get the display name for the log level
  String get displayName => switch (this) {
    LogLevel.debug => 'DEBUG',
    LogLevel.info => 'INFO',
    LogLevel.warning => 'WARN',
    LogLevel.error => 'ERROR',
    LogLevel.critical => 'CRITICAL',
  };

  /// Get the priority value for comparison
  int get priority => index;
}

/// Game logger with timestamped logging and file output
///
/// Provides structured logging for development and debugging with
/// automatic file output and configurable log levels.
class GameLogger {
  static const String _logFileName = 'game_log.txt';
  static const int _maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int _maxLogFiles = 5;

  final List<LogEntry> _logHistory = [];
  final int _maxHistorySize;
  LogLevel _minimumLevel;
  bool _enableConsoleOutput;
  bool _enableFileOutput;

  File? _logFile;

  /// Create a game logger with configurable options
  GameLogger({
    LogLevel minimumLevel = LogLevel.info,
    bool enableConsoleOutput = true,
    bool enableFileOutput = true,
    int maxHistorySize = 1000,
    bool isTestMode = false,
  }) : _minimumLevel = minimumLevel,
       _enableConsoleOutput = enableConsoleOutput,
       _enableFileOutput =
           enableFileOutput && !isTestMode, // Disable file output in test mode
       _maxHistorySize = maxHistorySize {
    _initializeLogFile();
  }

  /// Create a logger for testing (no file output, reduced features)
  factory GameLogger.forTesting({
    LogLevel minimumLevel = LogLevel.debug,
    int maxHistorySize = 100,
  }) {
    return GameLogger(
      minimumLevel: minimumLevel,
      enableConsoleOutput: false, // Reduce noise in tests
      enableFileOutput: false,
      maxHistorySize: maxHistorySize,
      isTestMode: true, // This parameter is used in constructor logic
    );
  }

  /// Initialize the log file for output
  void _initializeLogFile() {
    if (!_enableFileOutput) return;

    try {
      // Create logs directory if it doesn't exist
      final logsDir = Directory('logs');
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }

      _logFile = File('logs/$_logFileName');

      // Rotate log file if it's too large
      if (_logFile!.existsSync() && _logFile!.lengthSync() > _maxLogFileSize) {
        _rotateLogFiles();
      }

      // Write session start marker
      _writeToFile(
        '=== Game Session Started at ${DateTime.now().toIso8601String()} ===',
      );
    } catch (e) {
      // Disable file logging if initialization fails
      _enableFileOutput = false;
      print('Failed to initialize log file: $e');
    }
  }

  /// Rotate log files when they become too large
  void _rotateLogFiles() {
    try {
      // Move existing log files
      for (int i = _maxLogFiles - 1; i > 0; i--) {
        final oldFile = File('logs/game_log.$i.txt');
        final newFile = File('logs/game_log.${i + 1}.txt');

        if (oldFile.existsSync()) {
          if (i == _maxLogFiles - 1) {
            oldFile.deleteSync(); // Delete oldest
          } else {
            oldFile.renameSync(newFile.path);
          }
        }
      }

      // Move current log to .1
      if (_logFile!.existsSync()) {
        _logFile!.renameSync('logs/game_log.1.txt');
      }
    } catch (e) {
      print('Failed to rotate log files: $e');
    }
  }

  /// Write a message to the log file
  void _writeToFile(String message) {
    if (!_enableFileOutput) return;

    try {
      _logFile!.writeAsStringSync(
        '$message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      // Silently fail file writing to avoid recursive logging
    }
  }

  /// Log a debug message
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.debug,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Log an info message
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.info,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Log a warning message
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Log an error message
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Log a critical message
  void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.critical,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Core logging method
  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    // Check if this level should be logged
    if (level.priority < _minimumLevel.priority) return;

    final timestamp = DateTime.now();
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: timestamp,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );

    // Add to history
    _logHistory.add(entry);
    if (_logHistory.length > _maxHistorySize) {
      _logHistory.removeAt(0);
    }

    // Format and output
    final formattedMessage = _formatLogEntry(entry);

    if (_enableConsoleOutput) {
      print(formattedMessage);
    }

    if (_enableFileOutput) {
      _writeToFile(formattedMessage);
    }
  }

  /// Format a log entry for output
  String _formatLogEntry(LogEntry entry) {
    final buffer = StringBuffer();

    // Timestamp and level
    final timestamp = entry.timestamp.toIso8601String();
    buffer.write('[$timestamp] [${entry.level.displayName}] ${entry.message}');

    // Context information
    if (entry.context != null && entry.context!.isNotEmpty) {
      buffer.write(' | Context: ${jsonEncode(entry.context)}');
    }

    // Error information
    if (entry.error != null) {
      buffer.write('\n  Error: ${entry.error}');
    }

    // Stack trace
    if (entry.stackTrace != null) {
      final stackLines = entry.stackTrace.toString().split('\n');
      for (final line in stackLines.take(10)) {
        // Limit stack trace output
        if (line.trim().isNotEmpty) {
          buffer.write('\n  $line');
        }
      }
    }

    return buffer.toString();
  }

  /// Get recent log entries
  List<LogEntry> getRecentLogs({int? count}) {
    final entries = List<LogEntry>.from(_logHistory);
    if (count != null && count < entries.length) {
      return entries.sublist(entries.length - count);
    }
    return entries;
  }

  /// Get log entries by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logHistory.where((entry) => entry.level == level).toList();
  }

  /// Get log entries with errors
  List<LogEntry> getErrorLogs() {
    return _logHistory
        .where(
          (entry) =>
              entry.level == LogLevel.error ||
              entry.level == LogLevel.critical ||
              entry.error != null,
        )
        .toList();
  }

  /// Set the minimum log level
  void setLogLevel(LogLevel level) {
    _minimumLevel = level;
    info('Log level changed to ${level.displayName}');
  }

  /// Enable or disable console output
  void setConsoleOutput(bool enabled) {
    _enableConsoleOutput = enabled;
    info('Console output ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Enable or disable file output
  void setFileOutput(bool enabled) {
    _enableFileOutput = enabled;
    if (enabled) {
      _initializeLogFile();
    }
    info('File output ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Clear log history
  void clearHistory() {
    final count = _logHistory.length;
    _logHistory.clear();
    info('Cleared $count log entries from history');
  }

  /// Get debug statistics
  Map<String, dynamic> getDebugStats() {
    final levelCounts = <String, int>{};
    for (final level in LogLevel.values) {
      levelCounts[level.displayName] = _logHistory
          .where((entry) => entry.level == level)
          .length;
    }

    return {
      'totalEntries': _logHistory.length,
      'levelCounts': levelCounts,
      'errorCount': getErrorLogs().length,
      'minimumLevel': _minimumLevel.displayName,
      'consoleOutput': _enableConsoleOutput,
      'fileOutput': _enableFileOutput,
    };
  }
}

/// Individual log entry
class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  const LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    return 'LogEntry(${level.displayName}: $message at $timestamp)';
  }
}
