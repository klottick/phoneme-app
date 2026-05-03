import 'package:supabase_flutter/supabase_flutter.dart';

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
        Phoneme(id: 'fr-6', languageCode: 'fr', ipaSymbol: '/ɛ/', descriptor: 'open-mid front unrounded vowel', difficultyLevel: 1),
        Phoneme(id: 'fr-7', languageCode: 'fr', ipaSymbol: '/ə/', descriptor: 'schwa', difficultyLevel: 1),
        Phoneme(id: 'fr-8', languageCode: 'fr', ipaSymbol: '/ɔ/', descriptor: 'open-mid back rounded vowel', difficultyLevel: 2),
        Phoneme(id: 'fr-9', languageCode: 'fr', ipaSymbol: '/œ/', descriptor: 'open-mid front rounded vowel', difficultyLevel: 3),
        Phoneme(id: 'fr-10', languageCode: 'fr', ipaSymbol: '/ø/', descriptor: 'close front rounded vowel', difficultyLevel: 3),
        Phoneme(id: 'fr-11', languageCode: 'fr', ipaSymbol: '/ɲ/', descriptor: 'palatal nasal', difficultyLevel: 3),
        Phoneme(id: 'fr-12', languageCode: 'fr', ipaSymbol: '/ʃ/', descriptor: 'voiceless postalveolar fricative', difficultyLevel: 2),
        Phoneme(id: 'fr-13', languageCode: 'fr', ipaSymbol: '/ʒ/', descriptor: 'voiced postalveolar fricative', difficultyLevel: 2),
        Phoneme(id: 'fr-14', languageCode: 'fr', ipaSymbol: '/ɡ/', descriptor: 'voiced velar plosive', difficultyLevel: 1),
        Phoneme(id: 'fr-15', languageCode: 'fr', ipaSymbol: '/z/', descriptor: 'voiced alveolar fricative', difficultyLevel: 2),
        Phoneme(id: 'fr-16', languageCode: 'fr', ipaSymbol: '/ʒ/', descriptor: 'voiced postalveolar fricative', difficultyLevel: 2),
        Phoneme(id: 'fr-17', languageCode: 'fr', ipaSymbol: '/ɑ/', descriptor: 'open back unrounded vowel', difficultyLevel: 1),
        Phoneme(id: 'fr-18', languageCode: 'fr', ipaSymbol: '/i/', descriptor: 'close front unrounded vowel', difficultyLevel: 1),
      ];
    }

    if (languageCode == 'ja') {
      return const <Phoneme>[
        Phoneme(id: 'ja-1', languageCode: 'ja', ipaSymbol: '/a/', descriptor: 'open central vowel', difficultyLevel: 1),
        Phoneme(id: 'ja-2', languageCode: 'ja', ipaSymbol: '/i/', descriptor: 'close front vowel', difficultyLevel: 1),
        Phoneme(id: 'ja-3', languageCode: 'ja', ipaSymbol: '/ɯ/', descriptor: 'close back unrounded vowel', difficultyLevel: 2),
        Phoneme(id: 'ja-4', languageCode: 'ja', ipaSymbol: '/ɾ/', descriptor: 'alveolar tap', difficultyLevel: 1),
        Phoneme(id: 'ja-5', languageCode: 'ja', ipaSymbol: '/ɸ/', descriptor: 'voiceless bilabial fricative', difficultyLevel: 2),
        Phoneme(id: 'ja-6', languageCode: 'ja', ipaSymbol: '/ʑ/', descriptor: 'voiced palatal fricative', difficultyLevel: 3),
        Phoneme(id: 'ja-7', languageCode: 'ja', ipaSymbol: '/ç/', descriptor: 'voiceless palatal fricative', difficultyLevel: 3),
        Phoneme(id: 'ja-8', languageCode: 'ja', ipaSymbol: '/ɕ/', descriptor: 'voiceless postalveolar affricate', difficultyLevel: 3),
        Phoneme(id: 'ja-9', languageCode: 'ja', ipaSymbol: '/dʑ/', descriptor: 'voiced postalveolar affricate', difficultyLevel: 3),
        Phoneme(id: 'ja-10', languageCode: 'ja', ipaSymbol: '/ts/', descriptor: 'voiceless alveolar affricate', difficultyLevel: 2),
        Phoneme(id: 'ja-11', languageCode: 'ja', ipaSymbol: '/dz/', descriptor: 'voiced alveolar affricate', difficultyLevel: 2),
        Phoneme(id: 'ja-12', languageCode: 'ja', ipaSymbol: '/ɡ/', descriptor: 'voiced velar plosive', difficultyLevel: 1),
        Phoneme(id: 'ja-13', languageCode: 'ja', ipaSymbol: '/ɓ/', descriptor: 'voiced bilabial nasal', difficultyLevel: 2),
        Phoneme(id: 'ja-14', languageCode: 'ja', ipaSymbol: '/ɱ/', descriptor: 'labiodental nasal', difficultyLevel: 2),
        Phoneme(id: 'ja-15', languageCode: 'ja', ipaSymbol: '/ɳ/', descriptor: 'alveolar nasal', difficultyLevel: 2),
        Phoneme(id: 'ja-16', languageCode: 'ja', ipaSymbol: '/ɲ/', descriptor: 'palatal nasal', difficultyLevel: 3),
      ];
    }

    return const <Phoneme>[
      Phoneme(id: 'en-1', languageCode: 'en', ipaSymbol: '/iː/', descriptor: 'close front unrounded vowel (fleece)', difficultyLevel: 1),
      Phoneme(id: 'en-2', languageCode: 'en', ipaSymbol: '/ɪ/', descriptor: 'near-close near-front unrounded vowel (kit)', difficultyLevel: 1),
      Phoneme(id: 'en-3', languageCode: 'en', ipaSymbol: '/ɛ/', descriptor: 'open-mid front unrounded vowel (dress)', difficultyLevel: 1),
      Phoneme(id: 'en-4', languageCode: 'en', ipaSymbol: '/æ/', descriptor: 'near-open front unrounded vowel (trap)', difficultyLevel: 1),
      Phoneme(id: 'en-5', languageCode: 'en', ipaSymbol: '/ʊ/', descriptor: 'near-close near-back rounded vowel (foot)', difficultyLevel: 1),
      Phoneme(id: 'en-6', languageCode: 'en', ipaSymbol: '/uː/', descriptor: 'close back rounded vowel (goose)', difficultyLevel: 1),
      Phoneme(id: 'en-7', languageCode: 'en', ipaSymbol: '/ə/', descriptor: 'schwa (about)', difficultyLevel: 1),
      Phoneme(id: 'en-8', languageCode: 'en', ipaSymbol: '/ʌ/', descriptor: 'open-mid back unrounded vowel (strut)', difficultyLevel: 2),
      Phoneme(id: 'en-9', languageCode: 'en', ipaSymbol: '/ɑː/', descriptor: 'open back unrounded vowel (father)', difficultyLevel: 2),
      Phoneme(id: 'en-10', languageCode: 'en', ipaSymbol: '/ɔː/', descriptor: 'open-mid back rounded vowel (thought)', difficultyLevel: 2),
      Phoneme(id: 'en-11', languageCode: 'en', ipaSymbol: '/r/', descriptor: 'alveolar approximant', difficultyLevel: 2),
      Phoneme(id: 'en-12', languageCode: 'en', ipaSymbol: '/l/', descriptor: 'alveolar lateral approximant', difficultyLevel: 2),
      Phoneme(id: 'en-13', languageCode: 'en', ipaSymbol: '/θ/', descriptor: 'voiceless dental fricative (thin)', difficultyLevel: 2),
      Phoneme(id: 'en-14', languageCode: 'en', ipaSymbol: '/ð/', descriptor: 'voiced dental fricative (this)', difficultyLevel: 2),
      Phoneme(id: 'en-15', languageCode: 'en', ipaSymbol: '/ʃ/', descriptor: 'voiceless postalveolar fricative (ship)', difficultyLevel: 3),
      Phoneme(id: 'en-16', languageCode: 'en', ipaSymbol: '/ʒ/', descriptor: 'voiced postalveolar fricative (measure)', difficultyLevel: 3),
      Phoneme(id: 'en-17', languageCode: 'en', ipaSymbol: '/tʃ/', descriptor: 'voiceless postalveolar affricate (chain)', difficultyLevel: 3),
      Phoneme(id: 'en-18', languageCode: 'en', ipaSymbol: '/dʒ/', descriptor: 'voiced postalveolar affricate (jump)', difficultyLevel: 3),
      Phoneme(id: 'en-19', languageCode: 'en', ipaSymbol: '/ŋ/', descriptor: 'velar nasal (sing)', difficultyLevel: 3),
      Phoneme(id: 'en-20', languageCode: 'en', ipaSymbol: '/ɜː/', descriptor: 'open-mid central unrounded vowel (nurse)', difficultyLevel: 3),
      Phoneme(id: 'en-21', languageCode: 'en', ipaSymbol: '/æə/', descriptor: 'diphthong toward schwa (square)', difficultyLevel: 3),
      Phoneme(id: 'en-22', languageCode: 'en', ipaSymbol: '/ʊə/', descriptor: 'diphthong toward schwa (cure)', difficultyLevel: 4),
      Phoneme(id: 'en-23', languageCode: 'en', ipaSymbol: '/ɪə/', descriptor: 'diphthong toward schwa (here)', difficultyLevel: 4),
      Phoneme(id: 'en-24', languageCode: 'en', ipaSymbol: '/eɪ/', descriptor: 'closing diphthong (face)', difficultyLevel: 2),
      Phoneme(id: 'en-25', languageCode: 'en', ipaSymbol: '/aɪ/', descriptor: 'closing diphthong (price)', difficultyLevel: 2),
      Phoneme(id: 'en-26', languageCode: 'en', ipaSymbol: '/ɔɪ/', descriptor: 'closing diphthong (choice)', difficultyLevel: 3),
      Phoneme(id: 'en-27', languageCode: 'en', ipaSymbol: '/əʊ/', descriptor: 'closing diphthong (goat)', difficultyLevel: 2),
      Phoneme(id: 'en-28', languageCode: 'en', ipaSymbol: '/aʊ/', descriptor: 'closing diphthong (mouth)', difficultyLevel: 2),
      Phoneme(id: 'en-29', languageCode: 'en', ipaSymbol: '/p/', descriptor: 'voiceless bilabial plosive (pin)', difficultyLevel: 1),
      Phoneme(id: 'en-30', languageCode: 'en', ipaSymbol: '/b/', descriptor: 'voiced bilabial plosive (bin)', difficultyLevel: 1),
      Phoneme(id: 'en-31', languageCode: 'en', ipaSymbol: '/t/', descriptor: 'voiceless alveolar plosive (tea)', difficultyLevel: 1),
      Phoneme(id: 'en-32', languageCode: 'en', ipaSymbol: '/d/', descriptor: 'voiced alveolar plosive (do)', difficultyLevel: 1),
      Phoneme(id: 'en-33', languageCode: 'en', ipaSymbol: '/k/', descriptor: 'voiceless velar plosive (cat)', difficultyLevel: 1),
      Phoneme(id: 'en-34', languageCode: 'en', ipaSymbol: '/g/', descriptor: 'voiced velar plosive (go)', difficultyLevel: 1),
      Phoneme(id: 'en-35', languageCode: 'en', ipaSymbol: '/f/', descriptor: 'voiceless labiodental fricative (few)', difficultyLevel: 2),
      Phoneme(id: 'en-36', languageCode: 'en', ipaSymbol: '/v/', descriptor: 'voiced labiodental fricative (view)', difficultyLevel: 2),
      Phoneme(id: 'en-37', languageCode: 'en', ipaSymbol: '/s/', descriptor: 'voiceless alveolar fricative (see)', difficultyLevel: 2),
      Phoneme(id: 'en-38', languageCode: 'en', ipaSymbol: '/z/', descriptor: 'voiced alveolar fricative (zoo)', difficultyLevel: 2),
      Phoneme(id: 'en-39', languageCode: 'en', ipaSymbol: '/h/', descriptor: 'voiceless glottal fricative (hat)', difficultyLevel: 1),
      Phoneme(id: 'en-40', languageCode: 'en', ipaSymbol: '/m/', descriptor: 'bilabial nasal (men)', difficultyLevel: 1),
      Phoneme(id: 'en-41', languageCode: 'en', ipaSymbol: '/n/', descriptor: 'alveolar nasal (now)', difficultyLevel: 1),
      Phoneme(id: 'en-42', languageCode: 'en', ipaSymbol: '/w/', descriptor: 'labial-velar approximant (wet)', difficultyLevel: 1),
      Phoneme(id: 'en-43', languageCode: 'en', ipaSymbol: '/j/', descriptor: 'palatal approximant (yes)', difficultyLevel: 2),
      Phoneme(id: 'en-44', languageCode: 'en', ipaSymbol: '/ɒ/', descriptor: 'open-mid back rounded vowel (lot)', difficultyLevel: 2),
    ];
  }

  List<MinimalPair> _mockMinimalPairs(String languageCode) {
    if (languageCode == 'fr') {
      return const <MinimalPair>[
        MinimalPair(id: 'fr-mp-1', wordA: 'roue', wordB: 'rue', phonemeA: '/u/', phonemeB: '/y/'),
        MinimalPair(id: 'fr-mp-2', wordA: 'sans', wordB: 'saint', phonemeA: '/ɑ̃/', phonemeB: '/ɛ̃/'),
        MinimalPair(id: 'fr-mp-3', wordA: 'patte', wordB: 'pâte', phonemeA: '/a/', phonemeB: '/ɑ/'),
        MinimalPair(id: 'fr-mp-4', wordA: 'vin', wordB: 'vain', phonemeA: '/ɛ̃/', phonemeB: '/ɛ/'),
        MinimalPair(id: 'fr-mp-5', wordA: 'bon', wordB: 'ban', phonemeA: '/ɔ̃/', phonemeB: '/ɑ̃/'),
        MinimalPair(id: 'fr-mp-6', wordA: 'sont', wordB: 'son', phonemeA: '/ɔ̃/', phonemeB: '/ɔ/'),
        MinimalPair(id: 'fr-mp-7', wordA: 'poule', wordB: 'pull', phonemeA: '/ul/', phonemeB: '/yl/'),
        MinimalPair(id: 'fr-mp-8', wordA: 'mur', wordB: 'mûr', phonemeA: '/yɾ/', phonemeB: '/yɾ/'),
        MinimalPair(id: 'fr-mp-9', wordA: 'dos', wordB: 'daux', phonemeA: '/o/', phonemeB: '/o/'),
        MinimalPair(id: 'fr-mp-10', wordA: 'sel', wordB: 'ces', phonemeA: '/sɛl/', phonemeB: '/sɛ/'),
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
      MinimalPair(id: 'en-mp-6', wordA: 'pat', wordB: 'bat', phonemeA: '/p/', phonemeB: '/b/'),
      MinimalPair(id: 'en-mp-7', wordA: 'tin', wordB: 'din', phonemeA: '/t/', phonemeB: '/d/'),
      MinimalPair(id: 'en-mp-8', wordA: 'kin', wordB: 'gin', phonemeA: '/k/', phonemeB: '/g/'),
      MinimalPair(id: 'en-mp-9', wordA: 'fine', wordB: 'vine', phonemeA: '/f/', phonemeB: '/v/'),
      MinimalPair(id: 'en-mp-10', wordA: 'sea', wordB: 'zee', phonemeA: '/s/', phonemeB: '/z/'),
      MinimalPair(id: 'en-mp-11', wordA: 'chip', wordB: 'jump', phonemeA: '/tʃ/', phonemeB: '/dʒ/'),
      MinimalPair(id: 'en-mp-12', wordA: 'thin', wordB: 'then', phonemeA: '/θ/', phonemeB: '/ð/'),
      MinimalPair(id: 'en-mp-13', wordA: 'sing', wordB: 'thing', phonemeA: '/ŋ/', phonemeB: '/θ/'),
      MinimalPair(id: 'en-mp-14', wordA: 'seat', wordB: 'sit', phonemeA: '/iː/', phonemeB: '/ɪ/'),
      MinimalPair(id: 'en-mp-15', wordA: 'fool', wordB: 'full', phonemeA: '/uː/', phonemeB: '/ʊ/'),
      MinimalPair(id: 'en-mp-16', wordA: 'cat', wordB: 'cut', phonemeA: '/æ/', phonemeB: '/ʌ/'),
      MinimalPair(id: 'en-mp-17', wordA: 'boot', wordB: 'book', phonemeA: '/uː/', phonemeB: '/ʊ/'),
      MinimalPair(id: 'en-mp-18', wordA: 'dare', wordB: 'dear', phonemeA: '/ɛə/', phonemeB: '/ɪə/'),
      MinimalPair(id: 'en-mp-19', wordA: 'horse', wordB: 'house', phonemeA: '/ɔːs/', phonemeB: '/aʊs/'),
      MinimalPair(id: 'en-mp-20', wordA: 'pair', wordB: 'pear', phonemeA: '/eə/', phonemeB: '/ɛə/'),
    ];
  }
}
