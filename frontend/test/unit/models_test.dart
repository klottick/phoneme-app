import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/models/minimal_pair.dart';

void main() {
  group('Phoneme', () {
    test('fromJson parses basic fields', () {
      final json = {
        'id': 'test-id-123',
        'ipa_symbol': '/i/',
        'descriptor': 'close front unrounded vowel',
        'difficulty_level': 1,
        'languages': {'code': 'en'},
      };

      final phoneme = Phoneme.fromJson(json);

      expect(phoneme.id, 'test-id-123');
      expect(phoneme.ipaSymbol, '/i/');
      expect(phoneme.descriptor, 'close front unrounded vowel');
      expect(phoneme.difficultyLevel, 1);
      expect(phoneme.languageCode, 'en');
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{};

      final phoneme = Phoneme.fromJson(json);

      expect(phoneme.id, '');
      expect(phoneme.ipaSymbol, '');
      expect(phoneme.difficultyLevel, 1);
    });
  });

  group('MinimalPair', () {
    test('fromJson parses basic fields', () {
      final json = {
        'id': 'pair-id-456',
        'word_a': 'sheep',
        'word_b': 'ship',
        'phoneme_a': {'ipa_symbol': '/iː/'},
        'phoneme_b': {'ipa_symbol': '/ɪ/'},
      };

      final pair = MinimalPair.fromJson(json);

      expect(pair.id, 'pair-id-456');
      expect(pair.wordA, 'sheep');
      expect(pair.wordB, 'ship');
      expect(pair.phonemeA, '/iː/');
      expect(pair.phonemeB, '/ɪ/');
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final pair = MinimalPair.fromJson(json);

      expect(pair.id, '');
      expect(pair.wordA, '');
      expect(pair.wordB, '');
    });
  });
}