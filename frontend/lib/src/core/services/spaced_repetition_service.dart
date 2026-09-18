import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpacedRepetitionItem {
  final String id;
  final String phonemeId;
  final int easeFactor;
  final int interval;
  final int repetitions;
  final DateTime? nextReview;
  final DateTime? lastReview;

  const SpacedRepetitionItem({
    required this.id,
    required this.phonemeId,
    this.easeFactor = 250,
    this.interval = 1,
    this.repetitions = 0,
    this.nextReview,
    this.lastReview,
  });

  SpacedRepetitionItem copyWith({
    String? id,
    String? phonemeId,
    int? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReview,
    DateTime? lastReview,
  }) {
    return SpacedRepetitionItem(
      id: id ?? this.id,
      phonemeId: phonemeId ?? this.phonemeId,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReview: nextReview ?? this.nextReview,
      lastReview: lastReview ?? this.lastReview,
    );
  }

  bool get isDue => nextReview == null || nextReview!.isBefore(DateTime.now());

  double get successRate {
    if (repetitions == 0) return 0.5;
    return (repetitions / (repetitions + interval)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phonemeId': phonemeId,
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReview': nextReview?.toIso8601String(),
        'lastReview': lastReview?.toIso8601String(),
      };

  factory SpacedRepetitionItem.fromJson(Map<String, dynamic> json) => SpacedRepetitionItem(
        id: json['id'] as String,
        phonemeId: json['phonemeId'] as String,
        easeFactor: json['easeFactor'] as int? ?? 250,
        interval: json['interval'] as int? ?? 1,
        repetitions: json['repetitions'] as int? ?? 0,
        nextReview: json['nextReview'] != null
            ? DateTime.parse(json['nextReview'] as String)
            : null,
        lastReview: json['lastReview'] != null
            ? DateTime.parse(json['lastReview'] as String)
            : null,
      );
}

class SpacedRepetitionService {
  static const int _minEaseFactor = 130;
  static const int _defaultEaseFactor = 250;

  SpacedRepetitionItem processReview(SpacedRepetitionItem item, int quality) {
    final now = DateTime.now();
    int newEase = item.easeFactor;
    int newInterval = item.interval;
    int newReps = item.repetitions;

    if (quality < 3) {
      newReps = 0;
      newInterval = 1;
    } else {
      if (newReps == 0) {
        newInterval = 1;
      } else if (newReps == 1) {
        newInterval = 6;
      } else {
        newInterval = (item.interval * item.easeFactor / 1000).round();
      }
      newReps++;
    }

    newEase = (item.easeFactor + (100 - quality) * (5 - quality) * 10 / 1000).round();
    newEase = newEase.clamp(_minEaseFactor, 350);

    final nextReview = now.add(Duration(days: newInterval));

    return item.copyWith(
      easeFactor: newEase,
      interval: newInterval,
      repetitions: newReps,
      lastReview: now,
      nextReview: nextReview,
    );
  }

  SpacedRepetitionItem createItem(String phonemeId) {
    return SpacedRepetitionItem(
      id: 'srs_${phonemeId}_${DateTime.now().millisecondsSinceEpoch}',
      phonemeId: phonemeId,
      easeFactor: _defaultEaseFactor,
      interval: 1,
      repetitions: 0,
      nextReview: DateTime.now(),
    );
  }

  List<SpacedRepetitionItem> getDueItems(List<SpacedRepetitionItem> items, {int limit = 20}) {
    final now = DateTime.now();
    final due = items.where((i) => i.nextReview == null || i.nextReview!.isBefore(now)).toList();
    due.sort((a, b) {
      if (a.nextReview == null && b.nextReview == null) return 0;
      if (a.nextReview == null) return -1;
      if (b.nextReview == null) return 1;
      return a.nextReview!.compareTo(b.nextReview!);
    });
    return due.take(limit).toList();
  }

  int getNextInterval(intRepetitions, int easeFactor) {
    if (intRepetitions == 0) return 1;
    if (intRepetitions == 1) return 6;
    return (intRepetitions * easeFactor / 1000).round();
  }
}

class SpacedRepetitionNotifier extends StateNotifier<List<SpacedRepetitionItem>> {
  final SpacedRepetitionService _service = SpacedRepetitionService();
  final String _storageKey;

  SpacedRepetitionNotifier(this._storageKey) : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      try {
        final decoded = jsonDecode(data) as List<dynamic>;
        state = decoded
            .map((e) => SpacedRepetitionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> addPhoneme(String phonemeId) async {
    if (!state.any((i) => i.phonemeId == phonemeId)) {
      state = [...state, _service.createItem(phonemeId)];
      await save();
    }
  }

  Future<void> recordReview(String phonemeId, int quality) async {
    final index = state.indexWhere((i) => i.phonemeId == phonemeId);
    if (index != -1) {
      final updated = _service.processReview(state[index], quality);
      state = [
        ...state.sublist(0, index),
        updated,
        ...state.sublist(index + 1),
      ];
      await save();
    }
  }

  List<SpacedRepetitionItem> getDueItems({int limit = 20}) {
    return _service.getDueItems(state, limit: limit);
  }

  SpacedRepetitionItem? getItem(String phonemeId) {
    try {
      return state.firstWhere((i) => i.phonemeId == phonemeId);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> getAnalytics() {
    final total = state.length;
    final mastered = state.where((i) => i.repetitions >= 5 && i.easeFactor >= 200).length;
    final learning = state.where((i) => i.repetitions > 0 && i.repetitions < 5).length;
    final newItems = state.where((i) => i.repetitions == 0).length;
    final dueNow = state.where((i) => i.isDue).length;

    final avgEase = total > 0
        ? state.map((i) => i.easeFactor).reduce((a, b) => a + b) / total
        : 250.0;

    return {
      'total': total,
      'mastered': mastered,
      'learning': learning,
      'new': newItems,
      'dueNow': dueNow,
      'avgEaseFactor': avgEase,
    };
  }
}

final srsProvider =
    StateNotifierProvider<SpacedRepetitionNotifier, List<SpacedRepetitionItem>>((ref) {
  return SpacedRepetitionNotifier('srs_phonemes');
});