with lang as (
  select id, code from public.languages
), phoneme_seed as (
  select * from (
    values
      ('en', '/i/', 'close front unrounded vowel', 1),
      ('en', '/ɪ/', 'near-close near-front unrounded vowel', 1),
      ('en', '/r/', 'postalveolar approximant', 2),
      ('en', '/l/', 'alveolar lateral approximant', 2),
      ('fr', '/u/', 'close back rounded vowel', 1),
      ('fr', '/y/', 'close front rounded vowel', 2),
      ('fr', '/ɑ̃/', 'open back nasal vowel', 2),
      ('fr', '/ɛ̃/', 'open-mid front nasal vowel', 2),
      ('ja', '/ɾ/', 'alveolar tap', 1),
      ('ja', '/ɸ/', 'voiceless bilabial fricative', 2),
      ('ja', '/ɯ/', 'close back unrounded vowel', 1),
      ('ja', '/o/', 'close-mid back rounded vowel', 1)
  ) as v(language_code, ipa_symbol, descriptor, difficulty_level)
)
insert into public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
select l.id, p.ipa_symbol, p.descriptor, p.difficulty_level
from phoneme_seed p
join lang l on l.code = p.language_code
on conflict (language_id, ipa_symbol) do update
set descriptor = excluded.descriptor,
    difficulty_level = excluded.difficulty_level;

with minimal_pair_seed as (
  select * from (
    values
      ('en', '/i/', '/ɪ/', 'sheep', 'ship'),
      ('en', '/r/', '/l/', 'right', 'light'),
      ('fr', '/u/', '/y/', 'roue', 'rue'),
      ('fr', '/ɑ̃/', '/ɛ̃/', 'sans', 'saint'),
      ('ja', '/ɯ/', '/o/', 'fuku', 'foko')
  ) as v(language_code, ipa_a, ipa_b, word_a, word_b)
)
insert into public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b)
select l.id, pa.id, pb.id, m.word_a, m.word_b
from minimal_pair_seed m
join public.languages l on l.code = m.language_code
join public.phonemes pa on pa.language_id = l.id and pa.ipa_symbol = m.ipa_a
join public.phonemes pb on pb.language_id = l.id and pb.ipa_symbol = m.ipa_b
where not exists (
  select 1
  from public.minimal_pairs mp
  where mp.language_id = l.id
    and mp.word_a = m.word_a
    and mp.word_b = m.word_b
);

with confusion_seed as (
  select mp.language_id, mp.phoneme_a_id, mp.phoneme_b_id,
         row_number() over (partition by mp.language_id order by mp.created_at) as sort_order
  from public.minimal_pairs mp
)
insert into public.confusion_pairs (language_id, phoneme_a_id, phoneme_b_id, sort_order)
select language_id, phoneme_a_id, phoneme_b_id, sort_order
from confusion_seed
on conflict (language_id, phoneme_a_id, phoneme_b_id) do update
set sort_order = excluded.sort_order;
