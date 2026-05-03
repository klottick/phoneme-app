import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/models/minimal_pair.dart';

void main() {
  group('Phoneme Model', () {
    test('creates with required fields', () {
      const phoneme = Phoneme(
        id: 'test-1',
        languageCode: 'en',
        ipaSymbol: 'æ',
        descriptor: 'near-open front unrounded',
        difficultyLevel: 1,
      );

      expect(phoneme.id, 'test-1');
      expect(phoneme.ipaSymbol, 'æ');
      expect(phoneme.descriptor, 'near-open front unrounded');
      expect(phoneme.languageCode, 'en');
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'test-2',
        'languages': {'code': 'en'},
        'ipa_symbol': 'ʃ',
        'descriptor': 'voiceless postalveolar fricative',
        'difficulty_level': 2,
      };

      final phoneme = Phoneme.fromJson(json);

      expect(phoneme.id, 'test-2');
      expect(phoneme.ipaSymbol, 'ʃ');
      expect(phoneme.descriptor, 'voiceless postalveolar fricative');
    });
  });

  group('MinimalPair Model', () {
    test('creates with required fields', () {
      const pair = MinimalPair(
        id: 'pair-1',
        wordA: 'ship',
        wordB: 'sheep',
        phonemeA: 'ɪ',
        phonemeB: 'iː',
      );

      expect(pair.id, 'pair-1');
      expect(pair.wordA, 'ship');
      expect(pair.wordB, 'sheep');
      expect(pair.phonemeA, 'ɪ');
      expect(pair.phonemeB, 'iː');
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'pair-2',
        'word_a': 'cat',
        'word_b': 'cap',
        'phoneme_a': {'ipa_symbol': 't'},
        'phoneme_b': {'ipa_symbol': 'p'},
      };

      final pair = MinimalPair.fromJson(json);

      expect(pair.id, 'pair-2');
      expect(pair.wordA, 'cat');
      expect(pair.wordB, 'cap');
    });
  });
}