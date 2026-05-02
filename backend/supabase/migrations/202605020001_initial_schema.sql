create extension if not exists "pgcrypto";

create table if not exists public.languages (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  native_language text,
  created_at timestamptz not null default now()
);

create table if not exists public.phonemes (
  id uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages (id) on delete cascade,
  ipa_symbol text not null,
  descriptor text not null,
  difficulty_level int not null default 1,
  created_at timestamptz not null default now(),
  unique (language_id, ipa_symbol)
);

create table if not exists public.minimal_pairs (
  id uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages (id) on delete cascade,
  phoneme_a_id uuid not null references public.phonemes (id) on delete cascade,
  phoneme_b_id uuid not null references public.phonemes (id) on delete cascade,
  word_a text not null,
  word_b text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.audio_assets (
  id uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages (id) on delete cascade,
  phoneme_id uuid references public.phonemes (id) on delete cascade,
  minimal_pair_id uuid references public.minimal_pairs (id) on delete cascade,
  bucket text not null,
  path text not null,
  speaker_label text,
  created_at timestamptz not null default now()
);

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages (id) on delete cascade,
  slug text not null unique,
  title text not null,
  lesson_type text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  language_id uuid not null references public.languages (id) on delete cascade,
  phoneme_id uuid references public.phonemes (id) on delete cascade,
  mastery_score numeric(5,2) not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, language_id, phoneme_id)
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  minimal_pair_id uuid references public.minimal_pairs (id) on delete set null,
  is_correct boolean not null,
  response_time_ms int,
  created_at timestamptz not null default now()
);

create table if not exists public.review_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  phoneme_id uuid not null references public.phonemes (id) on delete cascade,
  due_at timestamptz not null,
  interval_days int not null default 1,
  ease_factor numeric(4,2) not null default 2.50,
  created_at timestamptz not null default now(),
  unique (user_id, phoneme_id)
);

alter table public.profiles enable row level security;
alter table public.user_progress enable row level security;
alter table public.attempts enable row level security;
alter table public.review_queue enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can manage own progress"
  on public.user_progress for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own attempts"
  on public.attempts for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own queue"
  on public.review_queue for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into public.languages (code, name)
values
  ('en', 'English'),
  ('fr', 'French'),
  ('ja', 'Japanese')
on conflict (code) do nothing;
