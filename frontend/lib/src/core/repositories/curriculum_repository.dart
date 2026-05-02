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
        Phoneme(id: 'fr-1', languageCode: 'fr', ipaSymbol: '/a/', descriptor: 'open front unrounded vowel', difficultyLevel: 1),
        Phoneme(id: 'fr-2', languageCode: 'fr', ipaSymbol: '/u/', descriptor: 'close back rounded vowel', difficultyLevel: 1),
        Phoneme(id: 'fr-3', languageCode: 'fr', ipaSymbol: '/y/', descriptor: 'close front rounded vowel', difficultyLevel: 2),
        Phoneme(id: 'fr-4', languageCode: 'fr', ipaSymbol: '/ɑ̃/', descriptor: 'open back nasal vowel', difficultyLevel: 2),
        Phoneme(id: 'fr-5', languageCode: 'fr', ipaSymbol: '/ʁ/', descriptor: 'voiced uvular fricative', difficultyLevel: 2),
      ];
    }

    if (languageCode == 'ja') {
      return const <Phoneme>[
        Phoneme(id: 'ja-1', languageCode: 'ja', ipaSymbol: '/a/', descriptor: 'open central vowel', difficultyLevel: 1),
        Phoneme(id: 'ja-2', languageCode: 'ja', ipaSymbol: '/i/', descriptor: 'close front vowel', difficultyLevel: 1),
        Phoneme(id: 'ja-3', languageCode: 'ja', ipaSymbol: '/u/', descriptor: 'close back vowel', difficultyLevel: 1),
        Phoneme(id: 'ja-4', languageCode: 'ja', ipaSymbol: '/ɯ/', descriptor: 'close back unrounded vowel', difficultyLevel: 2),
        Phoneme(id: 'ja-5', languageCode: 'ja', ipaSymbol: '/ɾ/', descriptor: 'alveolar tap', difficultyLevel: 1),
        Phoneme(id: 'ja-6', languageCode: 'ja', ipaSymbol: '/ɸ/', descriptor: 'voiceless bilabial fricative', difficultyLevel: 2),
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
      Phoneme(id: 'en-1', languageCode: 'en', ipaSymbol: '/iː/', descriptor: 'close front unrounded vowel (fleece)', difficultyLevel: 1),
      Phoneme(id: 'en-2', languageCode: 'en', ipaSymbol: '/ɪ/', descriptor: 'near-close near-front unrounded vowel (kit)', difficultyLevel: 1),
      Phoneme(id: 'en-3', languageCode: 'en', ipaSymbol: '/ɛ/', descriptor: 'open-mid front unrounded vowel (dress)', difficultyLevel: 1),
      Phoneme(id: 'en-4', languageCode: 'en', ipaSymbol: '/æ/', descriptor: 'near-open front unrounded vowel (trap)', difficultyLevel: 1),
      Phoneme(id: 'en-5', languageCode: 'en', ipaSymbol: '/r/', descriptor: 'alveolar approximant', difficultyLevel: 2),
      Phoneme(id: 'en-6', languageCode: 'en', ipaSymbol: '/l/', descriptor: 'alveolar lateral approximant', difficultyLevel: 2),
      Phoneme(id: 'en-7', languageCode: 'en', ipaSymbol: '/θ/', descriptor: 'voiceless dental fricative (thin)', difficultyLevel: 2),
      Phoneme(id: 'en-8', languageCode: 'en', ipaSymbol: '/ð/', descriptor: 'voiced dental fricative (this)', difficultyLevel: 2),
    ];
  }

  List<MinimalPair> _mockMinimalPairs(String languageCode) {
    if (languageCode == 'fr') {
      return const <MinimalPair>[
        MinimalPair(id: 'fr-mp-1', wordA: 'roue', wordB: 'rue', phonemeA: '/u/', phonemeB: '/y/'),
        MinimalPair(id: 'fr-mp-2', wordA: 'sans', wordB: 'saint', phonemeA: '/ɑ̃/', phonemeB: '/ɛ̃/'),
        MinimalPair(id: 'fr-mp-3', wordA: 'patte', wordB: 'pâte', phonemeA: '/a/', phonemeB: '/ɑ/'),
        MinimalPair(id: 'fr-mp-4', wordA: 'vin', wordB: 'vain', phonemeA: '/ɛ̃/', phonemeB: '/ɛ/'),
      ];
    }

    if (languageCode == 'ja') {
      return const <MinimalPair>[
        MinimalPair(id: 'ja-mp-1', wordA: 'fuku', wordB: 'foko', phonemeA: '/ɯ/', phonemeB: '/o/'),
        MinimalPair(id: 'ja-mp-2', wordA: 'haha', wordB: 'ɸaɸa', phonemeA: '/h/', phonemeB: '/ɸ/'),
        MinimalPair(id: 'ja-mp-3', wordA: 'chikyuu', wordB: 'shikyuu', phonemeA: '/ɕ/', phonemeB: '/s/'),
      ];
    }

    return const <MinimalPair>[
      MinimalPair(id: 'en-mp-1', wordA: 'sheep', wordB: 'ship', phonemeA: '/iː/', phonemeB: '/ɪ/'),
      MinimalPair(id: 'en-mp-2', wordA: 'right', wordB: 'light', phonemeA: '/r/', phonemeB: '/l/'),
      MinimalPair(id: 'en-mp-3', wordA: 'bed', wordB: 'bad', phonemeA: '/ɛ/', phonemeB: '/æ/'),
      MinimalPair(id: 'en-mp-4', wordA: 'cot', wordB: 'caught', phonemeA: '/ɒ/', phonemeB: '/ɔː/'),
      MinimalPair(id: 'en-mp-5', wordA: 'pull', wordB: 'pool', phonemeA: '/ʊ/', phonemeB: '/uː/'),
    ];
  }
}
