import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/word_of_the_day_service.dart';

void main() {
  group('WordBank', () {
    test('getWordForDate returns valid word', () {
      final date = DateTime(2024, 1, 15);
      final word = WordBank.getWordForDate(date);

      expect(word.word, isNotEmpty);
      expect(word.pronunciation, startsWith('/'));
      expect(word.meaning, isNotEmpty);
      expect(word.phonemes, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
    });

    test('getWordForDate returns same word for same date', () {
      final date = DateTime(2024, 1, 15);
      
      final word1 = WordBank.getWordForDate(date);
      final word2 = WordBank.getWordForDate(date);

      expect(word1.word, word2.word);
    });

    test('getWordForDate returns different words for different dates', () {
      final date1 = DateTime(2024, 1, 1);
      final date2 = DateTime(2024, 1, 2);
      
      final word1 = WordBank.getWordForDate(date1);
      final word2 = WordBank.getWordForDate(date2);

      expect(word1.word, isNot(equals(word2.word)));
    });

    test('getRandomWord returns valid word', () {
      final word = WordBank.getRandomWord();

      expect(word.word, isNotEmpty);
      expect(word.pronunciation, startsWith('/'));
      expect(word.meaning, isNotEmpty);
    });

    test('words contain IPA phonemes', () {
      final randomWord = WordBank.getRandomWord();

      expect(randomWord.phonemes, isNotEmpty);
    });
  });

  group('WordOfTheDay', () {
    test('has required fields', () {
      final word = WordBank.getRandomWord();

      expect(word.word, isA<String>());
      expect(word.pronunciation, isA<String>());
      expect(word.meaning, isA<String>());
      expect(word.phonemes, isA<List<String>>());
      expect(word.exampleSentence, isA<String>());
      expect(word.date, isA<DateTime>());
    });
  });
}