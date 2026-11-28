-- Hold for review: allow, hold, block, rate limit, queue and appeals.
-- LOCAL SUPABASE ONLY. Everything runs in one transaction and is rolled back.
--
--   docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/tests/hold_for_review.sql

begin;

insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
select id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       id || '@holdtest.invalid', now() - age, now()
from (values
    ('0000ddd1-0000-4000-8000-000000000000'::uuid, interval '2 days'),   -- new
    ('0000ddd2-0000-4000-8000-000000000000'::uuid, interval '30 days'),  -- established
    ('0000ddd3-0000-4000-8000-000000000000'::uuid, interval '30 days'),  -- moderator
    ('0000ddd4-0000-4000-8000-000000000000'::uuid, interval '2 days')    -- new, for links
) as t(id, age);

insert into private.rawdea_moderators (user_id)
values ('0000ddd3-0000-4000-8000-000000000000');

create function pg_temp.act_as(n int) returns void language plpgsql as $$
begin
    perform set_config('request.jwt.claims', json_build_object(
        'sub', '0000ddd' || n || '-0000-4000-8000-000000000000',
        'role', 'authenticated')::text, true);
end $$;

-- Runs a statement and requires it to fail with a matching message.
create function pg_temp.refused(sql text, expected text) returns void language plpgsql as $$
begin
    begin
        execute sql;
    exception when others then
        if sqlerrm not like '%' || expected || '%' then
            raise exception 'Expected "%", got "%" for: %', expected, sqlerrm, sql;
        end if;
        return;
    end;
    raise exception 'Expected "%" but succeeded: %', expected, sql;
end $$;

create function pg_temp.post(n int, body text) returns text language sql as $$
    select format('insert into public.posts (user_id, content) values (%L, %L)',
                  '0000ddd' || n || '-0000-4000-8000-000000000000', body);
$$;

create function pg_temp.check_that(ok boolean, what text) returns void language plpgsql as $$
begin
    if ok is not true then raise exception 'FAILED: %', what; end if;
end $$;

grant execute on all functions in schema pg_temp to authenticated;

set local role authenticated;

-- Established account: allow, hold, block --------------------------------

select pg_temp.act_as(2);
insert into public.posts (user_id, content) values
    ('0000ddd2-0000-4000-8000-000000000000', 'Shipped the onboarding screen today.'),
    ('0000ddd2-0000-4000-8000-000000000000', 'One link: https://example.com/notes'),
    ('0000ddd2-0000-4000-8000-000000000000', 'The build output was garbage, so I fixed it.'),
    ('0000ddd2-0000-4000-8000-000000000000', 'Edited README.md and bumped Node.js'),
    ('0000ddd2-0000-4000-8000-000000000000', 'A fourth and fifth post are fine when established.');

select pg_temp.refused(pg_temp.post(2, 'Honestly this idea is garbage and so are people who like it.'),
                       'RAWDEA_FILTER_HELD:possible_insult');
select pg_temp.refused(pg_temp.post(2, 'You are such an idiot'), 'RAWDEA_FILTER_HELD:possible_insult');
select pg_temp.refused(pg_temp.post(2, 'Check these: a.com b.com'), 'RAWDEA_FILTER_HELD:several_links');
select pg_temp.refused(pg_temp.post(2, 'Check these: a.com b.com c.com'), 'RAWDEA_FILTER_HELD:several_links');
select pg_temp.refused(pg_temp.post(2, 'http://a.com http://b.com http://c.com'), 'RAWDEA_FILTER_HELD:several_links');
select pg_temp.refused(pg_temp.post(2, 'http://a.com http://b.com http://c.com http://d.com'),
                       'RAWDEA_FILTER_BLOCKED:excessive_links');
select pg_temp.refused(pg_temp.post(2, 'Send me your password and I will fix it'),
                       'RAWDEA_FILTER_BLOCKED:credential_scam');
select pg_temp.refused(pg_temp.post(2, 'I will hurt you'), 'RAWDEA_FILTER_BLOCKED:targeted_threat');
select pg_temp.refused(pg_temp.post(2, 'go kill yourself, idiot'),
                       'RAWDEA_FILTER_BLOCKED:self_harm_encouragement');
select pg_temp.refused(
    'update public.posts set content = ''now an idiot edit'' where user_id = ''0000ddd2-0000-4000-8000-000000000000''',
    'RAWDEA_FILTER_HELD_EDIT:possible_insult');

select pg_temp.refused('select public.rawdea_hold_post(''A calm post'')', 'does not need a check');
select pg_temp.refused('select public.rawdea_hold_post(''I will hurt you'')', 'RAWDEA_FILTER_BLOCKED');

-- Clients cannot reach the private state or the moderator functions.
select pg_temp.refused('select * from private.rawdea_held_posts', 'permission denied');
select pg_temp.refused('delete from private.rawdea_post_log', 'permission denied');
select pg_temp.refused('select * from public.rawdea_moderation_held_queue()', 'Moderator access required');

-- New account: any link is held, 3 posts per hour ------------------------

select pg_temp.act_as(4);
select pg_temp.refused(pg_temp.post(4, 'My notes: example.com/notes'), 'RAWDEA_FILTER_HELD:new_account_link');
select pg_temp.refused(pg_temp.post(4, 'My notes: www.example.org'), 'RAWDEA_FILTER_HELD:new_account_link');

select pg_temp.act_as(1);
insert into public.posts (user_id, content)
values ('0000ddd1-0000-4000-8000-000000000000', 'First');
insert into public.posts (user_id, content)
values ('0000ddd1-0000-4000-8000-000000000000', 'Second');
-- A blocked post does not count.
select pg_temp.refused(pg_temp.post(1, 'I will hurt you'), 'RAWDEA_FILTER_BLOCKED');
-- A held post counts as the third.
select pg_temp.check_that(
    public.rawdea_hold_post('My notes: example.com/notes') = 'new_account_link', 'hold returns reason');
select pg_temp.refused(pg_temp.post(1, 'Fourth'), 'RAWDEA_RATE_LIMIT');
select pg_temp.refused('select public.rawdea_hold_post(''Also example.com'')', 'RAWDEA_RATE_LIMIT');
-- Deleting a post does not free a slot.
delete from public.posts where content = 'First';
select pg_temp.refused(pg_temp.post(1, 'Fourth'), 'RAWDEA_RATE_LIMIT');

select pg_temp.check_that((select count(*) from public.rawdea_my_held_posts()) = 0,
                          'pending holds make no notice');
select pg_temp.check_that(
    not exists (select 1 from public.posts where content like 'My notes%'), 'held post is not public');

-- An hour later the limit has passed.
reset role;
update private.rawdea_post_log set created_at = now() - interval '61 minutes'
where user_id = '0000ddd1-0000-4000-8000-000000000000';
set local role authenticated;
insert into public.posts (user_id, content)
values ('0000ddd1-0000-4000-8000-000000000000', 'After an hour');

-- Held posts: someone else's Project is refused.
select pg_temp.act_as(2);
reset role;
create temporary table other_project on commit drop as
    select id from public.projects where user_id = '0000ddd1-0000-4000-8000-000000000000' limit 1;
grant select on other_project to authenticated;
set local role authenticated;
select pg_temp.refused(
    format('select public.rawdea_hold_post(''a.com b.com'', %L)', (select id from other_project)),
    'That Project is not available');
select public.rawdea_hold_post('Second one: a.com b.com');
select pg_temp.refused('select public.rawdea_moderation_decide_held(gen_random_uuid(), true)',
                       'Moderator access required');

-- Moderator: approve one, remove one -------------------------------------

select pg_temp.act_as(3);
create temporary table held on commit drop as
    select * from public.rawdea_moderation_held_queue()
    where content in ('My notes: example.com/notes', 'Second one: a.com b.com');
select pg_temp.check_that((select count(*) from held) = 2, 'both holds are queued with a reason');

select public.rawdea_moderation_decide_held(id, true) from held where content like 'My notes%';
select public.rawdea_moderation_decide_held(id, false) from held where content like 'Second one%';

select pg_temp.check_that(
    exists (select 1 from public.posts p join held h on h.id = p.id
            where p.content like 'My notes%' and p.project_id is not null),
    'approved post is published in a Project');
select pg_temp.check_that(
    not exists (select 1 from public.posts where content like 'Second one%'), 'removed post stays out');
select pg_temp.refused(
    format('select public.rawdea_moderation_decide_held(%L, true)',
           (select id from held where content like 'Second one%')),
    'already been decided');

-- The approval cannot be replayed to skip the check.
select pg_temp.act_as(1);
delete from public.posts where content like 'My notes%';
select pg_temp.refused(
    format('insert into public.posts (id, user_id, content) values (%L, %L, %L)',
           (select id from held where content like 'My notes%'),
           '0000ddd1-0000-4000-8000-000000000000', 'My notes: example.com/notes'),
    'RAWDEA_FILTER_HELD');

select pg_temp.check_that(
    (select status = 'approved' and not seen from public.rawdea_my_held_posts()), 'author sees approval');
select public.rawdea_mark_held_seen();
select pg_temp.check_that((select seen from public.rawdea_my_held_posts()), 'notice marked read');
select pg_temp.refused(
    format('select public.rawdea_appeal_held_post(%L)', (select id from held where content like 'Second one%')),
    'not available');

-- Second look: once ------------------------------------------------------

select pg_temp.act_as(2);
select public.rawdea_appeal_held_post(id) from held where content like 'Second one%';
select pg_temp.check_that(
    (select status = 'pending' and appealed from public.rawdea_my_held_posts()), 'appeal is pending');

select pg_temp.act_as(3);
select pg_temp.check_that(
    (select appealed from public.rawdea_moderation_held_queue() where content like 'Second one%'),
    'appeal returns to the queue');
select public.rawdea_moderation_decide_held(id, false) from held where content like 'Second one%';

select pg_temp.act_as(2);
select pg_temp.refused(
    format('select public.rawdea_appeal_held_post(%L)', (select id from held where content like 'Second one%')),
    'not available');

-- Signed-out callers get nothing.
set local role anon;
select pg_temp.refused('select * from public.rawdea_my_held_posts()', 'permission denied');
select pg_temp.refused('select public.rawdea_hold_post(''a.com b.com'')', 'permission denied');

reset role;
\echo 'hold_for_review: all checks passed'
rollback;
