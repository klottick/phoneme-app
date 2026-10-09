\set ON_ERROR_STOP on
begin;
\ir ../seed.sql

do $$ begin
  if not exists (
    select 1 from public.phonemes p
    join public.languages l on l.id = p.language_id
    where l.code = 'en' and p.ipa_symbol = '/iː/'
      and p.descriptor = 'close front unrounded vowel (fleece)'
      and p.difficulty_level = 1
  ) then raise exception 'English phoneme fields were not seeded correctly'; end if;
  if not exists (
    select 1 from public.phonemes p
    join public.languages l on l.id = p.language_id
    where l.code = 'fr' and p.ipa_symbol = '/u/'
      and p.descriptor = 'close back rounded vowel (tout)'
      and p.difficulty_level = 1
  ) then raise exception 'French phoneme fields were not seeded correctly'; end if;
  if not exists (
    select 1 from public.phonemes p
    join public.languages l on l.id = p.language_id
    where l.code = 'ja' and p.ipa_symbol = '/ɯ/'
      and p.descriptor = 'close back unrounded vowel'
      and p.difficulty_level = 2
  ) then raise exception 'Japanese phoneme fields were not seeded correctly'; end if;
  if exists (
    select 1 from public.languages l where not exists (
      select 1 from public.minimal_pairs mp where mp.language_id = l.id
    )
  ) then raise exception 'A language has no seeded minimal pairs'; end if;
  if not exists (select 1 from public.confusion_pairs) then
    raise exception 'Confusion pairs were not seeded';
  end if;
end $$;
rollback;
