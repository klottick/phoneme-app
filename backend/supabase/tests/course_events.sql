\set ON_ERROR_STOP on
begin;
\ir ../migrations/202609180001_language_pair_courses.sql

insert into auth.users(id, email) values
  ('10000000-0000-4000-8000-000000000001', 'course-test@example.invalid'),
  ('10000000-0000-4000-8000-000000000002', 'other-course-test@example.invalid');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
set local role authenticated;

select public.record_course_events('[
  {"id":"test-a","user_id":"10000000-0000-4000-8000-000000000001","course_id":"en-fr","kind":"answer","sound":"u","skill":"listening","correct":true},
  {"id":"test-b","user_id":"10000000-0000-4000-8000-000000000001","course_id":"en-fr","kind":"answer","sound":"u","skill":"spelling","correct":false},
  {"id":"test-c","user_id":"10000000-0000-4000-8000-000000000001","course_id":"en-fr","kind":"lesson","lesson_id":"en-fr-vowels"},
  {"id":"test-d","user_id":"10000000-0000-4000-8000-000000000001","course_id":"en-fr","kind":"score","game":"word","score":500}
]');
-- A retry must not count twice.
select public.record_course_events('[{"id":"test-a","user_id":"10000000-0000-4000-8000-000000000001","course_id":"en-fr","kind":"answer","sound":"u","skill":"listening","correct":true}]');
do $$ begin
  if (select attempts from public.course_sound_progress where skill = 'listening') <> 1 then raise exception 'Retry doubled learning evidence'; end if;
  if (select correct from public.course_sound_progress where skill = 'spelling') <> 0 then raise exception 'Skills were mixed'; end if;
  if (select count(*) from public.course_completions) <> 1 then raise exception 'Completion missing'; end if;
  if (select best_score from public.course_arcade_scores where game = 'word') <> 500 then raise exception 'Score missing'; end if;
end $$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
do $$ begin
  if exists(select 1 from public.course_sound_progress) then raise exception 'Another user can read progress'; end if;
  if exists(select 1 from public.course_events) then raise exception 'Another user can read events'; end if;
  begin
    perform public.record_course_events('[{"id":"spoof","user_id":"10000000-0000-4000-8000-000000000001","course_id":"en-fr","kind":"score","game":"word","score":900}]');
    raise exception 'Spoof accepted';
  exception when raise_exception then
    if sqlerrm <> 'Wrong event owner' then raise; end if;
  end;
end $$;
rollback;
