-- Directional courses are distinct from reusable target-language resources.
-- Legacy progress remains intact: its source language is unknown.
create table public.courses (
  id text primary key,
  source_language text not null references public.languages(code),
  target_language text not null references public.languages(code),
  title text not null,
  check (source_language <> target_language),
  unique (source_language, target_language)
);
insert into public.courses values ('en-fr', 'en', 'fr', 'French for English speakers');

create table public.course_lessons (
  id text primary key,
  course_id text not null references public.courses(id),
  title text not null,
  position int not null,
  unique(course_id, position)
);
insert into public.course_lessons values
  ('en-fr-vowels', 'en-fr', 'Keep French vowels steady', 1),
  ('en-fr-u-y', 'en-fr', 'Tu or tout?', 2),
  ('en-fr-nasal', 'en-fr', 'Let vowels resonate', 3),
  ('en-fr-r', 'en-fr', 'Meet the French R', 4),
  ('en-fr-mix', 'en-fr', 'Mix your new sounds', 5);

create table public.course_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  course_id text not null references public.courses(id),
  payload jsonb not null,
  received_at timestamptz not null default now(),
  primary key(user_id, id)
);
create table public.course_sound_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id text not null references public.courses(id),
  sound text not null,
  skill text not null check(skill in ('listening', 'spelling')),
  attempts int not null default 0,
  correct int not null default 0,
  due_at timestamptz not null default now(),
  primary key(user_id, course_id, sound, skill)
);
create table public.course_completions (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id text not null references public.course_lessons(id),
  completed_at timestamptz not null default now(),
  primary key(user_id, lesson_id)
);
create table public.course_arcade_scores (
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id text not null references public.courses(id),
  game text not null check(game in ('word', 'sound')),
  best_score int not null check(best_score >= 0),
  primary key(user_id, course_id, game)
);
create index course_reviews_due on public.course_sound_progress(user_id, course_id, due_at);

alter table public.courses enable row level security;
alter table public.course_lessons enable row level security;
create policy "Read available courses" on public.courses for select using (true);
create policy "Read course lessons" on public.course_lessons for select using (true);
alter table public.course_events enable row level security;
alter table public.course_sound_progress enable row level security;
alter table public.course_completions enable row level security;
alter table public.course_arcade_scores enable row level security;
create policy "Own course events" on public.course_events for select using (auth.uid() = user_id);
create policy "Own sound progress" on public.course_sound_progress for select using (auth.uid() = user_id);
create policy "Own course completions" on public.course_completions for select using (auth.uid() = user_id);
create policy "Own arcade scores" on public.course_arcade_scores for select using (auth.uid() = user_id);

-- One transaction deduplicates client events and applies learning evidence.
-- Clients cannot write aggregate tables directly. User identity is server-derived.
create function public.record_course_events(events jsonb) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  event jsonb;
  inserted_id text;
  uid uuid := auth.uid();
  hit int;
begin
  if uid is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(events) <> 'array' or jsonb_array_length(events) > 100 then
    raise exception 'Expected at most 100 events';
  end if;
  for event in select value from jsonb_array_elements(events) loop
    if event->>'user_id' is distinct from uid::text then raise exception 'Wrong event owner'; end if;
    if event->>'kind' not in ('answer', 'lesson', 'score') or event->>'kind' is null then raise exception 'Invalid event kind'; end if;
    if length(event->>'id') > 128 then raise exception 'Invalid event ID'; end if;
    inserted_id := null;
    insert into public.course_events(user_id, id, course_id, payload)
    values(uid, event->>'id', event->>'course_id', event)
    on conflict do nothing returning id into inserted_id;
    if inserted_id is null then continue; end if;
    if event->>'kind' = 'answer' then
      if event->>'sound' is null or length(event->>'sound') > 32 or
         event->>'skill' is null or event->>'skill' not in ('listening', 'spelling') or
         jsonb_typeof(event->'correct') is distinct from 'boolean' then
        raise exception 'Invalid answer';
      end if;
      hit := case when (event->>'correct')::boolean then 1 else 0 end;
      insert into public.course_sound_progress(user_id, course_id, sound, skill, attempts, correct, due_at)
      values(uid, event->>'course_id', event->>'sound', event->>'skill', 1, hit, now() + hit * interval '1 day')
      on conflict(user_id, course_id, sound, skill) do update set
        attempts = course_sound_progress.attempts + 1,
        correct = course_sound_progress.correct + hit,
        due_at = excluded.due_at;
    elsif event->>'kind' = 'lesson' then
      if not exists(select 1 from public.course_lessons where id = event->>'lesson_id' and course_id = event->>'course_id') then
        raise exception 'Lesson does not belong to course';
      end if;
      insert into public.course_completions(user_id, lesson_id) values(uid, event->>'lesson_id') on conflict do nothing;
    else
      insert into public.course_arcade_scores(user_id, course_id, game, best_score)
      values(uid, event->>'course_id', event->>'game', (event->>'score')::int)
      on conflict(user_id, course_id, game) do update set best_score = greatest(course_arcade_scores.best_score, excluded.best_score);
    end if;
  end loop;
end;
$$;
revoke all on function public.record_course_events(jsonb) from public;
grant execute on function public.record_course_events(jsonb) to authenticated;
