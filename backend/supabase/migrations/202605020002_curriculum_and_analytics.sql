create table if not exists public.lesson_items (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  item_order int not null,
  phoneme_id uuid references public.phonemes (id) on delete set null,
  minimal_pair_id uuid references public.minimal_pairs (id) on delete set null,
  prompt text,
  unique (lesson_id, item_order)
);

create table if not exists public.confusion_pairs (
  id uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages (id) on delete cascade,
  phoneme_a_id uuid not null references public.phonemes (id) on delete cascade,
  phoneme_b_id uuid not null references public.phonemes (id) on delete cascade,
  sort_order int not null default 0,
  unique (language_id, phoneme_a_id, phoneme_b_id)
);

create table if not exists public.user_confusion_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  confusion_pair_id uuid not null references public.confusion_pairs (id) on delete cascade,
  total_attempts int not null default 0,
  total_misses int not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, confusion_pair_id)
);

create table if not exists public.learning_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  event_name text not null,
  language_code text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_attempts_user_created_at
  on public.attempts (user_id, created_at desc);

create index if not exists idx_review_queue_user_due_at
  on public.review_queue (user_id, due_at);

create index if not exists idx_events_event_name_created_at
  on public.learning_events (event_name, created_at desc);

alter table public.user_confusion_stats enable row level security;
alter table public.learning_events enable row level security;

create policy "Users can manage own confusion stats"
  on public.user_confusion_stats for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can insert own events"
  on public.learning_events for insert
  with check (auth.uid() = user_id or user_id is null);

create policy "Users can view own events"
  on public.learning_events for select
  using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values
  ('phoneme-audio', 'phoneme-audio', true),
  ('minimal-pair-audio', 'minimal-pair-audio', true),
  ('user-recordings', 'user-recordings', false)
on conflict (id) do nothing;

create policy "Public read phoneme audio"
  on storage.objects for select
  using (bucket_id in ('phoneme-audio', 'minimal-pair-audio'));

create policy "Users upload recordings"
  on storage.objects for insert
  with check (
    bucket_id = 'user-recordings'
    and auth.role() = 'authenticated'
    and owner = auth.uid()
  );

create policy "Users read own recordings"
  on storage.objects for select
  using (
    bucket_id = 'user-recordings'
    and owner = auth.uid()
  );

create policy "Users delete own recordings"
  on storage.objects for delete
  using (
    bucket_id = 'user-recordings'
    and owner = auth.uid()
  );
