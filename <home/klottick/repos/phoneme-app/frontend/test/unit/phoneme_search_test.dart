import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/search/phoneme_search_screen.dart';

void main() {
  group('PhonemeSearchQuery', () {
    test('creates with default values', () {
      const query = PhonemeSearchQuery();

      expect(query.query, '');
      expect(query.selectedCategories, isEmpty);
      expect(query.selectedDifficulties, isEmpty);
      expect(query.showBookmarkedOnly, false);
    });

    test('copyWith updates single field', () {
      const query = PhonemeSearchQuery();
      final updated = query.copyWith(query: 'test');

      expect(updated.query, 'test');
      expect(updated.showBookmarkedOnly, false);
    });

    test('copyWith updates multiple fields', () {
      const query = PhonemeSearchQuery();
      final updated = query.copyWith(
        selectedCategories: {'vowel'},
        selectedDifficulties: {1, 2},
      );

      expect(updated.selectedCategories, {'vowel'});
      expect(updated.selectedDifficulties, {1, 2});
    });
  });

  group('PhonemeSearchNotifier', () {
    test('setQuery updates query', () {
      final notifier = PhonemeSearchNotifier();

      notifier.setQuery('æ');

      expect(notifier.state.query, 'æ');
    });

    test('toggleCategory adds and removes', () {
      final notifier = PhonemeSearchNotifier();

      notifier.toggleCategory('vowel');
      expect(notifier.state.selectedCategories, {'vowel'});

      notifier.toggleCategory('vowel');
      expect(notifier.state.selectedCategories, isEmpty);
    });

    test('toggleDifficulty adds and removes', () {
      final notifier = PhonemeSearchNotifier();

      notifier.toggleDifficulty(1);
      expect(notifier.state.selectedDifficulties, {1});

      notifier.toggleDifficulty(1);
      expect(notifier.state.selectedDifficulties, isEmpty);
    });

    test('toggleBookmarkedOnly toggles', () {
      final notifier = PhonemeSearchNotifier();

      notifier.toggleBookmarkedOnly();
      expect(notifier.state.showBookmarkedOnly, true);

      notifier.toggleBookmarkedOnly();
      expect(notifier.state.showBookmarkedOnly, false);
    });

    test('clearFilters resets all', () {
      final notifier = PhonemeSearchNotifier();

      notifier.setQuery('test');
      notifier.toggleCategory('vowel');
      notifier.toggleDifficulty(1);
      notifier.clearFilters();

      expect(notifier.state.query, '');
      expect(notifier.state.selectedCategories, isEmpty);
      expect(notifier.state.selectedDifficulties, isEmpty);
    });

    test('filter by query text', () {
      final notifier = PhonemeSearchNotifier();
      final phonemes = _createTestPhonemes();

      notifier.setQuery('vowel');
      final filtered = notifier.filter(phonemes);

      expect(filtered.every((p) => p.ipaSymbol == 'æ'), true);
    });

    test('filter by category', () {
      final notifier = PhonemeSearchNotifier();
      final phonemes = _createTestPhonemes();

      notifier.toggleCategory('vowel');
      final filtered = notifier.filter(phonemes);

      expect(filtered.every((p) =>
        'aeiouæʌəɪɛɔɑ'.contains(p.ipaSymbol)), true);
    });

    test('filter by difficulty', () {
      final notifier = PhonemeSearchNotifier();
      final phonemes = _createTestPhonemes();

      notifier.toggleDifficulty(1);
      final filtered = notifier.filter(phonemes);

      expect(filtered.every((p) => p.difficultyLevel == 1), true);
    });

    test('filter combines multiple criteria', () {
      final notifier = PhonemeSearchNotifier();
      final phonemes = _createTestPhonemes();

      notifier.toggleCategory('vowel');
      notifier.toggleDifficulty(1);
      final filtered = notifier.filter(phonemes);

      expect(filtered.length, 1);
    });
  });
}

class _TestPhoneme {
  final String ipaSymbol;
  final String descriptor;
  final int difficultyLevel;

  _TestPhoneme({
    required this.ipaSymbol,
    required this.descriptor,
    required this.difficultyLevel,
  });
}

List<_TestPhoneme> _createTestPhonemes() => [
  _TestPhoneme(ipaSymbol: 'æ', descriptor: 'near-open front vowel', difficultyLevel: 1),
  _TestPhoneme(ipaSymbol: 'ə', descriptor: 'schwa', difficultyLevel: 1),
  _TestPhoneme(ipaSymbol: 'p', descriptor: 'voiceless bilabial plosive', difficultyLevel: 2),
];