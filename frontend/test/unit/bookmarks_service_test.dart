import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/bookmarks_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('BookmarkedPhoneme', () {
    test('creates with required fields', () {
      final bookmark = BookmarkedPhoneme(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'near-open front unrounded vowel',
        bookmarkedAt: DateTime(2024, 1, 15),
      );

      expect(bookmark.phonemeId, 'æ');
      expect(bookmark.phonemeSymbol, 'æ');
      expect(bookmark.name, contains('vowel'));
      expect(bookmark.note, isNull);
    });

    test('toJson serializes correctly', () {
      final bookmark = BookmarkedPhoneme(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
        bookmarkedAt: DateTime(2024, 1, 15),
        note: 'my note',
      );

      final json = bookmark.toJson();

      expect(json['phonemeId'], 'æ');
      expect(json['note'], 'my note');
      expect(json['bookmarkedAt'], isA<String>());
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'phonemeId': 'æ',
        'phonemeSymbol': 'æ',
        'name': 'test',
        'bookmarkedAt': '2024-01-15T00:00:00.000',
        'note': 'my note',
      };

      final bookmark = BookmarkedPhoneme.fromJson(json);

      expect(bookmark.phonemeId, 'æ');
      expect(bookmark.note, 'my note');
    });

    test('copyWith updates note', () {
      final bookmark = BookmarkedPhoneme(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
        bookmarkedAt: DateTime(2024, 1, 15),
        note: 'original',
      );

      final updated = bookmark.copyWith(note: 'updated');

      expect(updated.note, 'updated');
      expect(updated.phonemeId, 'æ');
    });
  });

  group('BookmarksNotifier', () {
    test('isBookmarked returns false for non-bookmarked', () {
      final notifier = BookmarksNotifier();
      
      expect(notifier.isBookmarked('æ'), false);
    });

    test('addBookmark adds to state', () async {
      final notifier = BookmarksNotifier();
      
      await notifier.addBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      
      expect(notifier.isBookmarked('æ'), true);
    });

    test('addBookmark does not duplicate', () async {
      final notifier = BookmarksNotifier();
      
      await notifier.addBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      await notifier.addBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      
      expect(notifier.state.length, 1);
    });

    test('removeBookmark removes from state', () async {
      final notifier = BookmarksNotifier();
      
      await notifier.addBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      await notifier.removeBookmark('æ');
      
      expect(notifier.isBookmarked('æ'), false);
    });

    test('toggleBookmark adds and removes', () async {
      final notifier = BookmarksNotifier();
      
      await notifier.toggleBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      expect(notifier.isBookmarked('æ'), true);
      
      await notifier.toggleBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      expect(notifier.isBookmarked('æ'), false);
    });

    test('updateNote updates note', () async {
      final notifier = BookmarksNotifier();
      
      await notifier.addBookmark(
        phonemeId: 'æ',
        phonemeSymbol: 'æ',
        name: 'test',
      );
      await notifier.updateNote('æ', 'new note');
      
      expect(notifier.state.first.note, 'new note');
    });
  });
}