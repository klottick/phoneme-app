import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supported_languages.dart';
import '../models/minimal_pair.dart';
import '../models/phoneme.dart';

class CurriculumRepository {
  CurriculumRepository(this._client);

  final SupabaseClient _client;

  Future<List<Phoneme>> getPhonemes(String languageCode) async {
    try {
      final rows = await _client
          .from('phonemes')
          .select('id, ipa_symbol, descriptor, difficulty_level, languages!inner(code)')
          .eq('languages.code', languageCode)
          .order('difficulty_level')
          .limit(60);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Phoneme.fromJson)
          .toList();
    } catch (_) {
      return _mockPhonemes(languageCode);
    }
  }

  Future<List<MinimalPair>> getMinimalPairs(String languageCode) async {
    try {
      final rows = await _client.from('minimal_pairs').select('''
            id,
            word_a,
            word_b,
            phoneme_a:phonemes!minimal_pairs_phoneme_a_id_fkey(ipa_symbol),
            phoneme_b:phonemes!minimal_pairs_phoneme_b_id_fkey(ipa_symbol),
            languages!inner(code)
          ''').eq('languages.code', languageCode).limit(30);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(MinimalPair.fromJson)
          .toList();
    } catch (_) {
      return _mockMinimalPairs(languageCode);
    }
  }

  List<Phoneme> _mockPhonemes(String languageCode) {
    if (languageCode == 'fr') {
      return const <Phoneme>[
        Phoneme(id: 'fr-1', languageCode: 'fr', ipaSymbol: '/u/', descriptor: 'close back rounded vowel', difficultyLevel: 1),
        Phoneme(id: 'fr-2', languageCode: 'fr', ipaSymbol: '/y/', descriptor: 'close front rounded vowel', difficultyLevel: 2),
        Phoneme(id: 'fr-3', languageCode: 'fr', ipaSymbol: '/ɑ̃/', descriptor: 'open back nasal vowel', difficultyLevel: 2),
      ];
    }

    if (languageCode == 'ja') {
      return const <Phoneme>[
        Phoneme(id: 'ja-1', languageCode: 'ja', ipaSymbol: '/ɾ/', descriptor: 'alveolar tap', difficultyLevel: 1),
        Phoneme(id: 'ja-2', languageCode: 'ja', ipaSymbol: '/ɯ/', descriptor: 'close back unrounded vowel', difficultyLevel: 1),
        Phoneme(id: 'ja-3', languageCode: 'ja', ipaSymbol: '/ɸ/', descriptor: 'voiceless bilabial fricative', difficultyLevel: 2),
      ];
    }

    return const <Phoneme>[
      Phoneme(id: 'en-1', languageCode: 'en', ipaSymbol: '/i/', descriptor: 'close front unrounded vowel', difficultyLevel: 1),
      Phoneme(id: 'en-2', languageCode: 'en', ipaSymbol: '/ɪ/', descriptor: 'near-close near-front unrounded vowel', difficultyLevel: 1),
      Phoneme(id: 'en-3', languageCode: 'en', ipaSymbol: '/r/', descriptor: 'postalveolar approximant', difficultyLevel: 2),
    ];
  }

  List<MinimalPair> _mockMinimalPairs(String languageCode) {
    final labels = {
      for (final language in supportedLanguages) language.code: language.label,
    };

    if (languageCode == 'fr') {
      return <MinimalPair>[
        MinimalPair(id: 'fr-mp-1', wordA: 'roue', wordB: 'rue', phonemeA: '/u/', phonemeB: '/y/'),
        MinimalPair(id: 'fr-mp-2', wordA: 'sans', wordB: 'saint', phonemeA: '/ɑ̃/', phonemeB: '/ɛ̃/'),
      ];
    }

    if (languageCode == 'ja') {
      return <MinimalPair>[
        MinimalPair(id: 'ja-mp-1', wordA: 'fuku', wordB: 'foko', phonemeA: '/ɯ/', phonemeB: '/o/'),
        MinimalPair(
          id: 'ja-mp-2',
          wordA: 'kara',
          wordB: 'kala',
          phonemeA: '/ɾ/',
          phonemeB: '/l/',
        ),
      ];
    }

    return <MinimalPair>[
      MinimalPair(id: 'en-mp-1', wordA: 'sheep', wordB: 'ship', phonemeA: '/i/', phonemeB: '/ɪ/'),
      MinimalPair(id: 'en-mp-2', wordA: 'right', wordB: 'light', phonemeA: '/r/', phonemeB: '/l/'),
      MinimalPair(
        id: 'meta',
        wordA: labels[languageCode] ?? 'A',
        wordB: 'drill',
        phonemeA: '/a/',
        phonemeB: '/b/',
      ),
    ];
  }
}
