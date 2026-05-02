-- Auto-generated from ipa-dict
-- License: MIT
-- Language: ja

-- Ensure phonemes exist (or create them)

-- Phoneme ɕidekasɯ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ɕidekasɯ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ɕidekasɯ');
-- Phoneme ɕimekasɯ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ɕimekasɯ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ');
-- Phoneme ɕimekiɾi
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ɕimekiɾi', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi');
-- Phoneme ɕimekiɾɯ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ɕimekiɾɯ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ');
-- Phoneme ɕimeɾasɯ
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, 'ɕimeɾasɯ', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = 'ɕimeɾasɯ');

-- Generated minimal pairs for ja
-- Source: ipa-dict (MIT licensed)

INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '〆切', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '〆切り', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '締め切り', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '締切', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '締切り', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '閉め切り', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾi' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekiɾɯ' LIMIT 1), '閉切り', '〆切る');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕidekasɯ' LIMIT 1), '〆粕', '為出かす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕidekasɯ' LIMIT 1), '搾めかす', '為出かす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕidekasɯ' LIMIT 1), '搾め糟', '為出かす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕidekasɯ' LIMIT 1), '搾め滓', '為出かす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕidekasɯ' LIMIT 1), '搾滓', '為出かす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimeɾasɯ' LIMIT 1), '〆粕', '湿らす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimeɾasɯ' LIMIT 1), '搾めかす', '湿らす');
INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ((SELECT id FROM public.languages WHERE code = 'ja'), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimekasɯ' LIMIT 1), (SELECT id FROM public.phonemes WHERE ipa_symbol = 'ɕimeɾasɯ' LIMIT 1), '搾め糟', '湿らす');
