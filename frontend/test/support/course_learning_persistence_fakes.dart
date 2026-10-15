import 'dart:async';

import 'package:linguist/src/core/course/course_learning_persistence.dart';

/// Models SharedPreferences' immediate cache mutation separately from the
/// durable platform image. A held failed write deliberately leaves the
/// optimistic cache dirty until restore() is called by the repository.
class FakeLearningPersistence implements LearningPersistence {
  final Map<String, String> cache = {};
  final Map<String, String> platform = {};
  final List<String> reads = [];
  Completer<void>? _entered;
  Completer<bool>? _gate;
  bool holdWrites = false;
  Object? restoreFailure;
  int writeCount = 0;

  String? get platformValue =>
      platform.values.isEmpty ? null : platform.values.first;

  void holdNextWrite() {
    holdWrites = true;
    _entered = Completer<void>();
    _gate = Completer<bool>();
  }

  Future<void> get writeEntered => _entered?.future ?? Future.value();

  void releaseWrite({required bool persist}) {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete(persist);
    holdWrites = false;
  }

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    return cache[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    cache[key] = value;
    if (holdWrites) {
      _entered?.complete();
      final accepted = await _gate!.future;
      if (!accepted) throw StateError('platform rejected write');
    }
    platform[key] = value;
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (restoreFailure case final failure?) throw failure;
    if (lastCommitted == null) {
      cache.remove(key);
      platform.remove(key);
    } else {
      cache[key] = lastCommitted;
      platform[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {
    cache
      ..clear()
      ..addAll(platform);
  }
}
