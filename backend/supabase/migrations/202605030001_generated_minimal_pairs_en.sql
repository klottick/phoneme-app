-- Auto-generated from ipa-dict
-- License: MIT
-- Language: en_US

-- Ensure phonemes exist (or create them)

-- Phoneme ˈbaɪt
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaɪt', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaɪt');
-- Phoneme ˈbaʊs
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaʊs', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊs');
-- Phoneme ˈbaʊt
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaʊt', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt');
-- Phoneme ˈbaʊz
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaʊz', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊz');
-- Phoneme ˈbaʊɝ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaʊɝ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊɝ');
-- Phoneme ˈbaʊɹ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaʊɹ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊɹ');
-- Phoneme ˈbaʊʃ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈbaʊʃ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊʃ');
-- Phoneme ˈboʊt
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈboʊt', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈboʊt');
-- Phoneme ˈdaʊt
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈdaʊt', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈdaʊt');
-- Phoneme ˈfaʊt
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈfaʊt', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈfaʊt');
-- Phoneme ˈɡaʊt
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ˈɡaʊt', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ˈɡaʊt');

-- Generated minimal pairs for en_US
-- Source: ipa-dict (MIT licensed)

INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊɝ' LIMIT 1), '''bout', 'bauer');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊɝ' LIMIT 1), 'bout', 'bauer');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊʃ' LIMIT 1), '''bout', 'bausch');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊʃ' LIMIT 1), 'bout', 'bausch');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaɪt' LIMIT 1), '''bout', 'bight');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaɪt' LIMIT 1), 'bout', 'bight');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈboʊt' LIMIT 1), '''bout', 'boat');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈboʊt' LIMIT 1), 'bout', 'boat');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊz' LIMIT 1), '''bout', 'boughs');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊz' LIMIT 1), 'bout', 'boughs');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊɹ' LIMIT 1), '''bout', 'bour');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊɹ' LIMIT 1), 'bout', 'bour');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊs' LIMIT 1), '''bout', 'bouse');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊs' LIMIT 1), 'bout', 'bouse');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈdaʊt' LIMIT 1), '''bout', 'doubt');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈdaʊt' LIMIT 1), 'bout', 'doubt');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈfaʊt' LIMIT 1), '''bout', 'fout');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈfaʊt' LIMIT 1), 'bout', 'fout');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈɡaʊt' LIMIT 1), '''bout', 'gout');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'en'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈbaʊt' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ˈɡaʊt' LIMIT 1), 'bout', 'gout');
