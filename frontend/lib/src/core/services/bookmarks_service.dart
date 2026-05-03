import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkedPhoneme {
  final String phonemeId;
  final String phonemeSymbol;
  final String name;
  final DateTime bookmarkedAt;
  final String? note;

  const BookmarkedPhoneme({
    required this.phonemeId,
    required this.phonemeSymbol,
    required this.name,
    required this.bookmarkedAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'phonemeId': phonemeId,
        'phonemeSymbol': phonemeSymbol,
        'name': name,
        'bookmarkedAt': bookmarkedAt.toIso8601String(),
        'note': note,
      };

  factory BookmarkedPhoneme.fromJson(Map<String, dynamic> json) => BookmarkedPhoneme(
        phonemeId: json['phonemeId'],
        phonemeSymbol: json['phonemeSymbol'],
        name: json['name'],
        bookmarkedAt: DateTime.parse(json['bookmarkedAt']),
        note: json['note'],
      );

  BookmarkedPhoneme copyWith({String? note}) => BookmarkedPhoneme(
        phonemeId: phonemeId,
        phonemeSymbol: phonemeSymbol,
        name: name,
        bookmarkedAt: bookmarkedAt,
        note: note ?? this.note,
      );
}

class BookmarksNotifier extends StateNotifier<List<BookmarkedPhoneme>> {
  static const String _storageKey = 'bookmarked_phonemes';

  BookmarksNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        state = decoded.map((e) => BookmarkedPhoneme.fromJson(e)).toList();
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

  bool isBookmarked(String phonemeId) {
    return state.any((b) => b.phonemeId == phonemeId);
  }

  Future<void> addBookmark({
    required String phonemeId,
    required String phonemeSymbol,
    required String name,
    String? note,
  }) async {
    if (isBookmarked(phonemeId)) return;

    final bookmark = BookmarkedPhoneme(
      phonemeId: phonemeId,
      phonemeSymbol: phonemeSymbol,
      name: name,
      bookmarkedAt: DateTime.now(),
      note: note,
    );
    state = [...state, bookmark];
    await save();
  }

  Future<void> removeBookmark(String phonemeId) async {
    state = state.where((b) => b.phonemeId != phonemeId).toList();
    await save();
  }

  Future<void> updateNote(String phonemeId, String note) async {
    final index = state.indexWhere((b) => b.phonemeId == phonemeId);
    if (index != -1) {
      state = [
        ...state.sublist(0, index),
        state[index].copyWith(note: note),
        ...state.sublist(index + 1),
      ];
      await save();
    }
  }

  Future<void> toggleBookmark({
    required String phonemeId,
    required String phonemeSymbol,
    required String name,
  }) async {
    if (isBookmarked(phonemeId)) {
      await removeBookmark(phonemeId);
    } else {
      await addBookmark(
        phonemeId: phonemeId,
        phonemeSymbol: phonemeSymbol,
        name: name,
      );
    }
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<BookmarkedPhoneme>>((ref) {
  return BookmarksNotifier();
});