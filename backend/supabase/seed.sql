-- Enhanced seed data with focus on common learner confusion pairs
-- IPA symbols use Unicode IPA characters

-- Phonemes for English (key learner targets)
with english_phonemes as (
  insert into public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
  select l.id, symbol, descr, diff
  from public.languages l, (values
    ('en', '/iː/', 'close front unrounded vowel (fleece)', 1),
    ('en', '/ɪ/', 'near-close near-front unrounded vowel (kit)', 1),
    ('en', '/eɪ/', 'mid front diphthong (face)', 1),
    ('en', '/ɛ/', 'open-mid front unrounded vowel (dress)', 1),
    ('en', '/æ/', 'near-open front unrounded vowel (trap)', 1),
    ('en', '/ɑː/', 'open back unrounded vowel (father)', 1),
    ('en', '/ɒ/', 'open back rounded vowel (lot)', 1),
    ('en', '/ɔː/', 'open-mid back rounded vowel (thought)', 1),
    ('en', '/oʊ/', 'mid back diphthong (goat)', 1),
    ('en', '/ʊ/', 'near-close near-back rounded vowel (foot)', 1),
    ('en', '/uː/', 'close back rounded vowel (goose)', 1),
    ('en', '/ʌ/', 'open-mid back unrounded vowel (strut)', 1),
    ('en', '/ə/', 'schwa (comma)', 1),
    ('en', '/ɜː/', 'open-mid central unrounded vowel (nurse)', 2),
    ('en', '/æ/', 'near-open front unrounded vowel (trap)', 1),
    ('en', '/r/', 'alveolar approximant (right)', 2),
    ('en', '/l/', 'alveolar lateral approximant (left)', 2),
    ('en', '/w/', 'voiced labial-velar approximant (wet)', 1),
    ('en', '/j/', 'voiced palatal approximant (yes)', 1),
    ('en', '/θ/', 'voiceless dental fricative (thin)', 2),
    ('en', '/ð/', 'voiced dental fricative (this)', 2),
    ('en', '/ʃ/', 'voiceless postalveolar fricative (ship)', 2),
    ('en', '/ʒ/', 'voiced postalveolar fricative (vision)', 2),
    ('en', '/tʃ/', 'voiceless postalveolar affricate (chain)', 2),
    ('en', '/dʒ/', 'voiced postalveolar affricate (jump)', 2),
    ('en', '/ŋ/', 'voiced velar nasal (sing)', 2),
    ('en', '/h/', 'voiceless glottal fricative (hot)', 1)
  ) as v(symbol, descr, diff)
  where l.code = 'en'
  on conflict (language_id, ipa_symbol) do nothing
  returning id, ipa_symbol
)
select 1;

-- English minimal pairs (high-value learner pairs)
with english_pairs as (
  insert into public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b)
  select l.id, pa.id, pb.id, word_a, word_b
  from public.languages l,
  (values
    ('en', '/iː/', '/ɪ/', 'sheep', 'ship'),
    ('en', '/iː/', '/ɪ/', 'glee', 'gly'),
    ('en', '/ɪ/', '/iː/', 'sit', 'seat'),
    ('en', '/ɛ/', '/æ/', 'bed', 'bad'),
    ('en', '/ɛ/', '/eɪ/', 'pen', 'pain'),
    ('en', '/æ/', '/ɛ/', 'bat', 'bet'),
    ('en', '/æ/', '/ɑː/', 'bat', 'bar'),
    ('en', '/ɒ/', '/ɔː/', 'cot', 'caught'),
    ('en', '/ʌ/', '/ɑː/', 'cut', 'cart'),
    ('en', '/ʊ/', '/uː/', 'pull', 'pool'),
    ('en', '/f/', '/v/', 'few', 'view'),
    ('en', '/s/', '/z/', 'sea', 'zee'),
    ('en', '/θ/', '/ð/', 'thin', 'then'),
    ('en', '/ʃ/', '/s/', 'ship', 'sip'),
    ('en', '/tʃ/', '/dʒ/', 'chain', 'jam'),
    ('en', '/l/', '/r/', 'left', 'right'),
    ('en', '/n/', '/ŋ/', 'sin', 'sing'),
    ('en', '/h/', '/', 'hat', 'at'),
    ('en', '/w/', '//', 'wet', 'et')
  ) as v(lang, phon_a, phon_b, word_a, word_b)
  join public.phonemes pa on pa.language_id = l.id and pa.ipa_symbol = phon_a
  join public.phonemes pb on pb.language_id = l.id and pb.ipa_symbol = phon_b
  where l.code = 'en'
  on conflict do nothing
  returning id
)
select 1;

-- French phonemes (key learner targets)
with french_phonemes as (
  insert into public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
  select l.id, symbol, descr, diff
  from public.languages l, (values
    ('fr', '/a/', 'open front unrounded vowel (patte)', 1),
    ('fr', '/ə/', 'schwa (jeune)', 2),
    ('fr', '/i/', 'close front unrounded vowel (vite)', 1),
    ('fr', '/y/', 'close front rounded vowel (pur)', 2),
    ('fr', '/e/', 'close-mid front unrounded vowel (clé)', 1),
    ('fr', '/ɛ/', 'open-mid front unrounded vowel (père)', 1),
    ('fr', '/ɛː/', 'open front unrounded vowel (tête)', 2),
    ('fr', '/ɔ/', 'open-mid back rounded vowel (hotte)', 1),
    ('fr', '/o/', 'close-mid back rounded vowel (haut)', 1),
    ('fr', '/u/', 'close back rounded vowel (tout)', 1),
    ('fr', '/ɑ/', 'open back unrounded vowel (pâte)', 1),
    ('fr', '/ɑ̃/', 'open back nasal vowel (pain)', 2),
    ('fr', '/ɔ̃/', 'open-mid back nasal vowel (bon)', 2),
    ('fr', '/ɛ̃/', 'open-mid front nasal vowel (vin)', 2),
    ('fr', '/œ̃/', 'open-mid central nasal vowel (brun)', 2),
    ('fr', '/ʁ/', 'voiced uvular fricative (roue)', 2),
    ('fr', '/ʃ/', 'voiceless postalveolar fricative (chef)', 2),
    ('fr', '/ʒ/', 'voiced postalveolar fricative (gen)', 2),
    ('fr', '/ɲ/', 'voiced palatal nasal (gnat)', 2),
    ('fr', '/j/', 'voiced palatal approximant (pied)', 1),
    ('fr', '/w/', 'voiced labial-velar approximant (oui)', 1),
    ('fr', '/ɥ/', 'voiced labial-palatal approximant (huit)', 2)
  ) as v(symbol, descr, diff)
  where l.code = 'fr'
  on conflict (language_id, ipa_symbol) do nothing
  returning id, ipa_symbol
)
select 1;

-- French minimal pairs
with french_pairs as (
  insert into public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b)
  select l.id, pa.id, pb.id, word_a, word_b
  from public.languages l,
  (values
    ('fr', '/a/', '/ɑ/', 'patte', 'pâte'),
    ('fr', '/e/', '/ɛ/', 'clé', 'claire'),
    ('fr', '/ə/', '/ø/', 'je', 'jeu'),
    ('fr', '/i/', '/y/', 'vis', 'vue'),
    ('fr', '/u/', '/y/', 'roue', 'rue'),
    ('fr', '/o/', '/ɔ/', 'haut', 'hot'),
    ('fr', '/ɛ/', '/e/', 'père', 'pair'),
    ('fr', '/ɑ/', '/ɑ̃/', 'pas', 'pan'),
    ('fr', '/ɔ/', '/ɔ̃/', 'bon', 'bond'),
    ('fr', '/ɛ/', '/ɛ̃/', 'vin', 'vain'),
    ('fr', '/s/', '/ʃ/', 'sucer', 'choucroute'),
    ('fr', '/z/', '/ʒ/', 'poison', 'garage'),
    ('fr', '/l/', '/j/', 'taille', 'traille'),
    ('fr', '/n/', '/ɲ/', 'bagne', 'gagne')
  ) as v(lang, phon_a, phon_b, word_a, word_b)
  join public.phonemes pa on pa.language_id = l.id and pa.ipa_symbol = phon_a
  join public.phonemes pb on pb.language_id = l.id and pb.ipa_symbol = phon_b
  where l.code = 'fr'
  on conflict do nothing
  returning id
)
select 1;

-- Japanese phonemes (key learner targets)
with japanese_phonemes as (
  insert into public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
  select l.id, symbol, descr, diff
  from public.languages l, (values
    ('ja', '/a/', 'open central vowel', 1),
    ('ja', '/i/', 'close front vowel', 1),
    ('ja', '/u/', 'close back vowel', 1),
    ('ja', '/e/', 'close-mid front vowel', 1),
    ('ja', '/o/', 'close-mid back vowel', 1),
    ('ja', '/ɯ/', 'close back unrounded vowel', 2),
    ('ja', '/ɡ/', 'voiced velar plosive', 1),
    ('ja', '/k/', 'voiceless velar plosive', 1),
    ('ja', '/s/', 'voiceless alveolar fricative', 1),
    ('ja', '/ɕ/', 'voiceless alveolo-palatal fricative', 2),
    ('ja', '/h/', 'voiceless glottal fricative', 1),
    ('ja', '/ɸ/', 'voiceless bilabial fricative', 2),
    ('ja', '/t/', 'voiceless alveolar plosive', 1),
    ('ja', '/ts/', 'voiceless alveolar affricate', 1),
    ('ja', '/tɕ/', 'voiceless alveolo-palatal affricate', 2),
    ('ja', '/p/', 'voiceless bilabial plosive', 1),
    ('ja', '/b/', 'voiced bilabial plosive', 1),
    ('ja', '/d/', 'voiced alveolar plosive', 1),
    ('ja', '/ɾ/', 'alveolar tap', 1),
    ('ja', '/ɺ/', 'alveolar flap', 2),
    ('ja', '/r/', 'alveolar approximant', 2),
    ('ja', '/n/', 'alveolar nasal', 1),
    ('ja', '/ɲ/', 'palatal nasal', 2),
    ('ja', '/ŋ/', 'velar nasal', 2),
    ('ja', '/m/', 'bilabial nasal', 1),
    ('ja', '/j/', 'palatal approximant', 1),
    ('ja', '/w/', 'labial-velar approximant', 1)
  ) as v(symbol, descr, diff)
  where l.code = 'ja'
  on conflict (language_id, ipa_symbol) do nothing
  returning id, ipa_symbol
)
select 1;

-- Japanese minimal pairs (common confusions)
with japanese_pairs as (
  insert into public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b)
  select l.id, pa.id, pb.id, word_a, word_b
  from public.languages l,
  (values
    ('ja', '/ɾ/', '/r/', 'hiragana', 'hiragana'),
    ('ja', '/ɯ/', '/u/', 'fuku', 'fuko'),
    ('ja', '/ɕ/', '/s/', 'chikyuu', 'shikyuu'),
    ('ja', '/ts/', '/s/', 'tottori', 'sottori'),
    ('ja', '/ɡ/', '/k/', 'gogo', 'koko'),
    ('ja', '/h/', '/ɸ/', 'haha', 'ɸaɸa'),
    ('ja', '/ɾ/', '/d/', 'toritoga', 'todonga'),
    ('ja', '/j/', '/ɲ/', 'iyama', 'iɲama'),
    ('ja', '/w/', '/b/', 'wakaba', 'bakaba')
  ) as v(lang, phon_a, phon_b, word_a, word_b)
  join public.phonemes pa on pa.language_id = l.id and pa.ipa_symbol = phon_a
  join public.phonemes pb on pb.language_id = l.id and pb.ipa_symbol = phon_b
  where l.code = 'ja'
  on conflict do nothing
  returning id
)
select 1;

-- Update confusion pairs from minimal pairs
with confusion_seed as (
  insert into public.confusion_pairs (language_id, phoneme_a_id, phoneme_b_id, sort_order)
  select mp.language_id, mp.phoneme_a_id, mp.phoneme_b_id,
         row_number() over (partition by mp.language_id order by mp.created_at) as sort_order
  from public.minimal_pairs mp
  on conflict do nothing
  returning id
)
select count(*) as confusion_pairs_created;
