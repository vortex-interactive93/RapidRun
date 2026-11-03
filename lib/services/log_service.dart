import 'dart:collection';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// In-memory ring buffer log service with broadcast stream.
/// Lightweight; avoids external deps and keeps recent diagnostics visible.
class LogService {
  static final LogService instance = LogService._();
  LogService._();

  final int _capacity = 500; // tune as needed
  final ListQueue<LogEntry> _entries = ListQueue();
  final _controller = StreamController<List<LogEntry>>.broadcast();

  Stream<List<LogEntry>> get stream => _controller.stream;
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stack,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      message: message,
      error: error?.toString(),
      stack: stack,
    );
    _entries.addFirst(entry); // newest first
    while (_entries.length > _capacity) {
      _entries.removeLast();
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('[LOG][$category] $message');
      if (error != null) {
        // ignore: avoid_print
        print('  error: $error');
      }
    }
    _controller.add(entries);
  }

  void clear() {
    _entries.clear();
    _controller.add(entries);
  }
}

class LogEntry {
  final DateTime timestamp;
  final String category;
  final String message;
  final String? error;
  final StackTrace? stack;
  LogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.error,
    this.stack,
  });
}
