import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/models/phoneme.dart';

void main() {
  group('Phoneme', () {
    test('creates with required fields', () {
      const phoneme = Phoneme(
        id: 'en-æ',
        languageCode: 'en',
        ipaSymbol: 'æ',
        descriptor: 'near-open front unrounded vowel',
        difficultyLevel: 1,
      );

      expect(phoneme.id, 'en-æ');
      expect(phoneme.ipaSymbol, 'æ');
      expect(phoneme.difficultyLevel, 1);
    });

    test('factory fromJson handles complete data', () {
      final json = {
        'id': 'en-æ',
        'languageCode': 'en',
        'ipa_symbol': 'æ',
        'descriptor': 'test',
        'difficulty_level': 2,
      };

      final phoneme = Phoneme.fromJson(json);

      expect(phoneme.ipaSymbol, 'æ');
      expect(phoneme.difficultyLevel, 2);
    });

    test('factory fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final phoneme = Phoneme.fromJson(json);

      expect(phoneme.ipaSymbol, '');
      expect(phoneme.difficultyLevel, 1);
    });

    test('toJson produces correct output', () {
      const phoneme = Phoneme(
        id: 'en-æ',
        languageCode: 'en',
        ipaSymbol: 'æ',
        descriptor: 'test',
        difficultyLevel: 2,
      );

      final json = phoneme.toJson();

      expect(json['id'], 'en-æ');
      expect(json['ipa_symbol'], 'æ');
      expect(json['difficulty_level'], 2);
    });
  });
}