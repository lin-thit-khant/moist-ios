-- Project collaborators: suggestions, contributors, credit and cycles.
-- LOCAL SUPABASE ONLY. Everything runs in one transaction and is rolled back.
--
--   docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/tests/collaborators.sql

begin;

-- 1 owner, 2 maya, 3 ravi, 4 tom, 5 stranger, 6-9 more helpers,
-- 10 moderator.
create function pg_temp.uid(n int) returns uuid language sql immutable as $$
    select ('0000' || lpad(n::text, 2, '0') || 'cc-0000-4000-8000-000000000000')::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
select pg_temp.uid(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       n || '@collabtest.invalid', now() - interval '30 days', now()
from generate_series(1, 10) n;

insert into private.rawdea_moderators (user_id) values (pg_temp.uid(10));

create function pg_temp.act_as(n int) returns void language plpgsql as $$
begin
    perform set_config('request.jwt.claims', json_build_object(
        'sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
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

create function pg_temp.check_that(ok boolean, what text) returns void language plpgsql as $$
begin
    if ok is not true then raise exception 'FAILED: %', what; end if;
end $$;

-- Fixed Project ids: 1 main, 2 second.
create function pg_temp.pid(n int) returns uuid language sql immutable as $$
    select ('0000ccc1-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid;
$$;

create function pg_temp.suggest(p int, body text, kind text default 'note') returns text language sql as $$
    select format('select public.rawdea_suggest(%L, %L, %L)', pg_temp.pid(p), kind, body);
$$;

create function pg_temp.post(n int, p int, body text, kind text default 'note') returns text language sql as $$
    select format('insert into public.posts (user_id, project_id, content, kind) values (%L, %L, %L, %L)',
                  pg_temp.uid(n), pg_temp.pid(p), body, kind);
$$;

-- Approves a held post with either form of the moderator call.
create function pg_temp.approve_held(held_id uuid) returns void language plpgsql as $$
begin
    if to_regprocedure('public.rawdea_moderation_decide_held(uuid,boolean,boolean)') is null then
        execute 'select public.rawdea_moderation_decide_held($1, true)' using held_id;
    else
        execute 'select public.rawdea_moderation_decide_held($1, true, false)' using held_id;
    end if;
end $$;

create function pg_temp.suggestion(body text) returns uuid language sql as $$
    select id from public.project_suggestions where content = body;
$$;

grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;

select pg_temp.act_as(1);
insert into public.projects (id, user_id, name) values
    (pg_temp.pid(1), pg_temp.uid(1), 'Pocket Ledger'),
    (pg_temp.pid(2), pg_temp.uid(1), 'Second Project');

-- Everyone but the stranger follows the main Project.
do $$
declare n int;
begin
    foreach n in array array[2, 3, 4, 6, 7, 8, 9] loop
        perform pg_temp.act_as(n);
        insert into public.project_follows (follower_id, project_id)
        values (pg_temp.uid(n), pg_temp.pid(1)), (pg_temp.uid(n), pg_temp.pid(2));
    end loop;
end $$;

-- SUGGESTIONS ------------------------------------------------------------

select pg_temp.act_as(5);
select pg_temp.refused(pg_temp.suggest(1, 'I do not follow'), 'RAWDEA_SUGGEST_UNAVAILABLE');

select pg_temp.act_as(1);
select pg_temp.refused(pg_temp.suggest(1, 'My own Project'), 'RAWDEA_SUGGEST_UNAVAILABLE');

select pg_temp.act_as(2);
select pg_temp.refused(pg_temp.suggest(1, 'We decided', 'decision'), 'Suggest a note');
select pg_temp.refused(pg_temp.suggest(1, '   '), '1 to 500');
select pg_temp.refused(pg_temp.suggest(1, repeat('a', 501)), '1 to 500');
select pg_temp.refused(pg_temp.suggest(1, 'I will hurt you'), 'RAWDEA_FILTER_BLOCKED');
select pg_temp.refused(pg_temp.suggest(1, 'see a.com and b.com'), 'RAWDEA_SUGGESTION_NEEDS_EDIT');
select pg_temp.refused(pg_temp.post(2, 1, 'A follower cannot post'), 'You cannot post');
select pg_temp.refused(
    format('insert into public.project_suggestions (project_id, user_id, content) values (%L, %L, %L)',
           pg_temp.pid(1), pg_temp.uid(2), 'sneaky'), 'permission denied');

select public.rawdea_suggest(pg_temp.pid(1), 'note', 'maya one');
select public.rawdea_suggest(pg_temp.pid(1), 'question', 'maya two');
select public.rawdea_suggest(pg_temp.pid(1), 'progress', 'maya three');
select pg_temp.refused(pg_temp.suggest(1, 'maya four'), 'RAWDEA_SUGGESTION_LIMIT');
-- The limit is per Project.
select public.rawdea_suggest(pg_temp.pid(2), 'note', 'maya elsewhere');
select pg_temp.check_that((select count(*) from public.project_suggestions) = 4, 'suggester sees own');
select pg_temp.refused('update public.project_suggestions set status = ''approved''', 'permission denied');
select pg_temp.refused(
    format('select public.rawdea_decide_suggestion(%L, true)', pg_temp.suggestion('maya one')),
    'not available');

select pg_temp.act_as(3);
select pg_temp.check_that((select count(*) from public.project_suggestions) = 0, 'others see none');
select pg_temp.refused(
    format('select public.rawdea_withdraw_suggestion(%L)',
           '00000000-0000-0000-0000-000000000001'), 'RAWDEA_SUGGESTION_CHANGED');

select pg_temp.act_as(1);
select pg_temp.check_that((select count(*) from public.project_suggestions) = 4, 'owner sees received');
select pg_temp.check_that(
    (select count(*) = 1 and max(item_count) = 3 from public.notifications
     where kind = 'suggestions_waiting' and project_id = pg_temp.pid(1)),
    'one grouped notice per Project');

select public.rawdea_decide_suggestion(pg_temp.suggestion('maya one'), true);
select public.rawdea_decide_suggestion(pg_temp.suggestion('maya two'), false);
select pg_temp.refused(
    format('select public.rawdea_decide_suggestion(%L, true)', pg_temp.suggestion('maya one')),
    'RAWDEA_SUGGESTION_CHANGED');
select pg_temp.check_that(
    (select p.user_id = pg_temp.uid(2) and p.project_id = pg_temp.pid(1)
            and p.suggestion_id = s.id and s.status = 'approved' and s.post_id = p.id
     from public.posts p join public.project_suggestions s on s.id = p.suggestion_id
     where p.content = 'maya one'),
    'approval publishes under the suggester, marked suggested');
select pg_temp.check_that(
    not exists (select 1 from public.posts where content = 'maya two'), 'declined stays private');
select pg_temp.check_that(
    (select item_count = 1 from public.notifications where kind = 'suggestions_waiting'
     and project_id = pg_temp.pid(1)), 'grouped count follows decisions');

select pg_temp.act_as(2);
select pg_temp.check_that(
    (select count(*) filter (where kind = 'suggestion_approved') = 1
        and count(*) filter (where kind = 'suggestion_declined') = 1
     from public.notifications), 'suggester hears both results');
select public.rawdea_withdraw_suggestion(pg_temp.suggestion('maya three'));
select pg_temp.check_that(
    (select status = 'withdrawn' from public.project_suggestions where content = 'maya three'),
    'withdrawn');
-- A suggested post keeps its mark and cannot become a decision.
update public.posts set suggestion_id = null where content = 'maya one';
select pg_temp.check_that(
    (select suggestion_id is not null from public.posts where content = 'maya one'), 'mark is protected');
select pg_temp.refused('update public.posts set kind = ''decision'' where content = ''maya one''',
                       'Only the owner');
update public.posts set content = 'maya one, edited' where content = 'maya one';
select pg_temp.check_that(
    exists (select 1 from public.posts where content = 'maya one, edited'), 'author edits own');

-- Expiry after 14 days, without a scheduler.
select public.rawdea_suggest(pg_temp.pid(1), 'note', 'maya old');
reset role;
update public.project_suggestions set created_at = now() - interval '15 days' where content = 'maya old';
set local role authenticated;
select pg_temp.act_as(1);
select pg_temp.refused(
    format('select public.rawdea_decide_suggestion(%L, true)', pg_temp.suggestion('maya old')),
    'RAWDEA_SUGGESTION_CHANGED');
select public.rawdea_close_expired_suggestions();
select pg_temp.check_that(
    (select status = 'closed' from public.project_suggestions where content = 'maya old'),
    'expired closes');

-- Off, shipped, hidden and archived.
update public.projects set suggestions_enabled = false where id = pg_temp.pid(2);
select pg_temp.act_as(3);
select pg_temp.refused(pg_temp.suggest(2, 'off'), 'RAWDEA_SUGGEST_UNAVAILABLE');
select pg_temp.act_as(1);
update public.projects set suggestions_enabled = true where id = pg_temp.pid(2);
select public.rawdea_set_project_stage(pg_temp.pid(2), 'shipped');
select pg_temp.check_that(
    (select status = 'closed' from public.project_suggestions where content = 'maya elsewhere'),
    'shipping closes waiting');
select pg_temp.act_as(3);
select pg_temp.refused(pg_temp.suggest(2, 'shipped'), 'RAWDEA_SUGGEST_UNAVAILABLE');
select pg_temp.act_as(1);
select public.rawdea_set_project_stage(pg_temp.pid(2), 'early');
select pg_temp.act_as(3);
select public.rawdea_suggest(pg_temp.pid(2), 'note', 'before hide');
select pg_temp.act_as(1);
update public.projects set is_hidden = true where id = pg_temp.pid(2);
select pg_temp.check_that(
    (select status = 'closed' from public.project_suggestions where content = 'before hide'),
    'hiding closes waiting');
update public.projects set is_hidden = false where id = pg_temp.pid(2);
select pg_temp.act_as(3);
select public.rawdea_suggest(pg_temp.pid(2), 'note', 'before archive');
select pg_temp.act_as(1);
update public.projects set is_archived = true where id = pg_temp.pid(2);
select pg_temp.check_that(
    (select status = 'closed' from public.project_suggestions where content = 'before archive'),
    'archiving closes waiting');
update public.projects set is_archived = false where id = pg_temp.pid(2);

-- Default Project takes none.
reset role;
select private.rawdea_default_project(pg_temp.uid(1));
create temporary table general on commit drop as
    select id from public.projects where user_id = pg_temp.uid(1) and is_default;
grant select on general to authenticated;
set local role authenticated;
select pg_temp.act_as(3);
insert into public.project_follows (follower_id, project_id)
select pg_temp.uid(3), id from general;
select pg_temp.refused(
    format('select public.rawdea_suggest(%L, ''note'', ''general'')', (select id from general)),
    'RAWDEA_SUGGEST_UNAVAILABLE');

-- Blocking removes waiting suggestions, in either direction.
select pg_temp.act_as(9);
select public.rawdea_suggest(pg_temp.pid(1), 'note', 'nine waits');
select pg_temp.act_as(1);
select public.rawdea_block_user(pg_temp.uid(9));
select pg_temp.act_as(9);
select pg_temp.check_that(
    (select status = 'closed' from public.project_suggestions where content = 'nine waits'),
    'block closes waiting');
select pg_temp.refused(pg_temp.suggest(1, 'blocked'), 'RAWDEA_SUGGEST_UNAVAILABLE');
select pg_temp.act_as(1);
select public.rawdea_unblock_user(pg_temp.uid(9));

-- A suspended account cannot suggest.
reset role;
insert into public.content_reports (id, reporter_id, target_type, target_id, subject_user_id, reason)
values ('0000ccc2-0000-4000-8000-000000000001', pg_temp.uid(1), 'account', pg_temp.uid(5), pg_temp.uid(5), 'spam');
insert into private.moderation_enforcements (target_type, target_id, source_report_id, moderator_id)
values ('account', pg_temp.uid(5), '0000ccc2-0000-4000-8000-000000000001', pg_temp.uid(10));
reset role;
insert into public.project_follows (follower_id, project_id) values (pg_temp.uid(5), pg_temp.pid(1));
set local role authenticated;
select pg_temp.act_as(5);
select pg_temp.refused(pg_temp.suggest(1, 'suspended'), 'RAWDEA_SUGGEST_UNAVAILABLE');
reset role;
delete from private.moderation_enforcements where target_id = pg_temp.uid(5);
delete from public.project_follows where follower_id = pg_temp.uid(5);
set local role authenticated;

-- CONTRIBUTORS -----------------------------------------------------------

select pg_temp.act_as(1);
select pg_temp.refused(
    format('select public.rawdea_invite_contributor(%L, %L)', pg_temp.pid(1), pg_temp.uid(3)),
    'RAWDEA_INVITE_UNAVAILABLE');
select pg_temp.act_as(3);
select pg_temp.refused(
    format('select public.rawdea_invite_contributor(%L, %L)', pg_temp.pid(1), pg_temp.uid(2)),
    'not available');
select pg_temp.refused(
    format('insert into public.project_members (project_id, user_id, status) values (%L, %L, ''active'')',
           pg_temp.pid(1), pg_temp.uid(3)), 'permission denied');

-- Everyone else gets one approved suggestion.
do $$
declare n int;
begin
    foreach n in array array[3, 4, 6, 7, 8] loop
        perform pg_temp.act_as(n);
        perform public.rawdea_suggest(pg_temp.pid(1), 'note', 'first from ' || n);
    end loop;
    perform pg_temp.act_as(1);
    foreach n in array array[3, 4, 6, 7, 8] loop
        perform public.rawdea_decide_suggestion(pg_temp.suggestion('first from ' || n), true);
    end loop;
end $$;

select public.rawdea_invite_contributor(pg_temp.pid(1), pg_temp.uid(2));
select pg_temp.refused(
    format('select public.rawdea_invite_contributor(%L, %L)', pg_temp.pid(1), pg_temp.uid(2)),
    'RAWDEA_INVITE_CHANGED');
select public.rawdea_invite_contributor(pg_temp.pid(1), pg_temp.uid(n)) from unnest(array[3, 4, 6, 7]) n;
select pg_temp.refused(
    format('select public.rawdea_invite_contributor(%L, %L)', pg_temp.pid(1), pg_temp.uid(8)),
    'RAWDEA_CONTRIBUTORS_FULL');

-- Invitations are private.
select pg_temp.act_as(5);
select pg_temp.check_that((select count(*) from public.project_members where project_id = pg_temp.pid(1)) = 0, 'invites are private');

select pg_temp.act_as(2);
select pg_temp.check_that(
    exists (select 1 from public.notifications where kind = 'contributor_invite'), 'invite notice');
select pg_temp.refused(pg_temp.post(2, 1, 'Not yet accepted'), 'You cannot post');
delete from public.project_follows where follower_id = pg_temp.uid(2) and project_id = pg_temp.pid(1);
select public.rawdea_respond_to_invite(pg_temp.pid(1), true);
select pg_temp.check_that(
    exists (select 1 from public.project_follows
            where follower_id = pg_temp.uid(2) and project_id = pg_temp.pid(1)), 'accepting follows');
select pg_temp.check_that(
    not exists (select 1 from public.notifications where kind = 'contributor_invite'), 'invite cleared');
select pg_temp.act_as(3);
select public.rawdea_respond_to_invite(pg_temp.pid(1), true);
select pg_temp.act_as(4);
select public.rawdea_respond_to_invite(pg_temp.pid(1), true);
select pg_temp.act_as(6);
select public.rawdea_respond_to_invite(pg_temp.pid(1), false);
select pg_temp.refused(
    format('select public.rawdea_respond_to_invite(%L, true)', pg_temp.pid(1)), 'RAWDEA_INVITE_CHANGED');

select pg_temp.act_as(5);
select pg_temp.check_that(
    (select count(*) = 3 and bool_and(status = 'active') from public.project_members
     where project_id = pg_temp.pid(1)),
    'active contributors are public');

-- What a contributor may do.
select pg_temp.act_as(2);
insert into public.posts (user_id, project_id, content, kind) values
    (pg_temp.uid(2), pg_temp.pid(1), 'maya progress', 'progress'),
    (pg_temp.uid(2), pg_temp.pid(1), 'maya asks', 'question');
select pg_temp.refused(pg_temp.post(2, 1, 'maya decides', 'decision'), 'You cannot post');
select pg_temp.refused('update public.posts set kind = ''decision'' where content = ''maya progress''',
                       'Only the owner');
select pg_temp.refused(pg_temp.post(2, 2, 'not a member there'), 'You cannot post');
select pg_temp.refused(
    format('select public.rawdea_set_project_stage(%L, ''shipped'')', pg_temp.pid(1)), 'Project not found');
update public.projects set stage = 'shipped', cycle = 9 where id = pg_temp.pid(1);
select pg_temp.check_that(
    (select stage = 'early' and cycle = 1 from public.projects where id = pg_temp.pid(1)),
    'contributor changes no Project');
insert into public.posts (user_id, content) values (pg_temp.uid(2), 'maya older post');
select pg_temp.refused(
    format('update public.posts set project_id = %L where content = ''maya older post''', pg_temp.pid(1)),
    'your own Project');
select pg_temp.refused(
    format('select public.rawdea_invite_contributor(%L, %L)', pg_temp.pid(1), pg_temp.uid(8)),
    'not available');

-- The owner hides, never edits.
select pg_temp.act_as(1);
update public.posts set content = 'owner rewrote' where content = 'maya progress';
delete from public.posts where content = 'maya progress';
select pg_temp.check_that(
    exists (select 1 from public.posts where content = 'maya progress'), 'owner cannot edit or delete');
select pg_temp.act_as(3);
select pg_temp.refused(
    format('select public.rawdea_owner_set_post_hidden(%L, true)',
           (select id from public.posts where content = 'maya progress')), 'not available');
select pg_temp.act_as(1);
select public.rawdea_owner_set_post_hidden(
    (select id from public.posts where content = 'maya progress'), true);
select pg_temp.check_that(
    exists (select 1 from public.posts where content = 'maya progress' and owner_hidden), 'owner still reads');
select pg_temp.act_as(3);
select pg_temp.check_that(
    not exists (select 1 from public.posts where content = 'maya progress'), 'hidden from others');
select pg_temp.act_as(2);
update public.posts set owner_hidden = false where content = 'maya progress';
select pg_temp.check_that(
    (select owner_hidden from public.posts where content = 'maya progress'), 'author cannot unhide');
set local role anon;
select pg_temp.refused('select * from public.posts', 'permission denied');
set local role authenticated;
select pg_temp.act_as(1);
select public.rawdea_owner_set_post_hidden(
    (select id from public.posts where content = 'maya progress'), false);

-- Best answer: asker and owner only.
select pg_temp.act_as(3);
insert into public.post_comments (post_id, user_id, content)
select id, pg_temp.uid(3), 'ravi answers' from public.posts where content = 'maya asks';
create temporary table qa on commit drop as
    select c.post_id, c.id as comment_id from public.post_comments c where c.content = 'ravi answers';
grant select on qa to authenticated;
select pg_temp.act_as(4);
select pg_temp.refused(
    format('select public.rawdea_owner_set_best_reply(%L, %L)', post_id, comment_id), 'not available') from qa;
update public.posts set best_reply_id = (select comment_id from qa) where id = (select post_id from qa);
select pg_temp.check_that(
    (select best_reply_id is null from public.posts where content = 'maya asks'), 'bystander cannot pick');
select pg_temp.act_as(1);
select public.rawdea_owner_set_best_reply(post_id, comment_id) from qa;
select pg_temp.check_that(
    (select best_reply_id is not null from public.posts where content = 'maya asks'), 'owner picks');
select pg_temp.act_as(3);
select pg_temp.check_that(
    exists (select 1 from public.notifications
            where kind = 'best_answer' and actor_id = pg_temp.uid(1)), 'notice names who chose');
select pg_temp.act_as(2);
update public.posts set best_reply_id = null where content = 'maya asks';
update public.posts set best_reply_id = (select comment_id from qa) where content = 'maya asks';
select pg_temp.check_that(
    (select best_reply_id is not null from public.posts where content = 'maya asks'), 'asker picks');

-- Pauses.
select pg_temp.act_as(1);
update public.projects set is_hidden = true where id = pg_temp.pid(1);
select pg_temp.check_that(
    exists (select 1 from public.posts where content = 'maya progress'), 'owner reads while hidden');
select pg_temp.act_as(2);
select pg_temp.refused(pg_temp.post(2, 1, 'into hidden'), 'You cannot post');
select pg_temp.act_as(1);
update public.projects set is_hidden = false, is_archived = true where id = pg_temp.pid(1);
select pg_temp.act_as(2);
select pg_temp.refused(pg_temp.post(2, 1, 'into archived'), 'You cannot post');
select pg_temp.act_as(1);
update public.projects set is_archived = false where id = pg_temp.pid(1);
select pg_temp.act_as(2);
select pg_temp.refused(
    format('insert into public.posts (user_id, project_id, content) values (%L, %L, ''into general'')',
           pg_temp.uid(2), (select id from general)), 'You cannot post');

-- A contributor's held post.
select pg_temp.refused(pg_temp.post(2, 1, 'look a.com b.com'), 'RAWDEA_FILTER_HELD');
select pg_temp.refused(
    format('select public.rawdea_hold_contribution(%L, %L, ''decision'')', 'look a.com b.com', pg_temp.pid(1)),
    'not available');
select public.rawdea_hold_contribution('look a.com b.com', pg_temp.pid(1), 'note');
select public.rawdea_hold_contribution('look a.com b.com', pg_temp.pid(1), 'note');
select public.rawdea_hold_contribution('later c.com d.com', pg_temp.pid(1), 'note');
select pg_temp.act_as(5);
select pg_temp.refused(
    format('select public.rawdea_hold_contribution(%L, %L)', 'x a.com b.com', pg_temp.pid(1)), 'not available');
select pg_temp.act_as(10);
create temporary table held on commit drop as
    select * from public.rawdea_moderation_held_queue()
    where content in ('look a.com b.com', 'later c.com d.com');
grant select on held to authenticated;
select pg_temp.check_that((select count(*) from held) = 2, 'a resend queues once');
select pg_temp.approve_held(id) from held where content like 'look%';
select pg_temp.check_that(
    (select project_id = pg_temp.pid(1) and user_id = pg_temp.uid(2)
     from public.posts where content = 'look a.com b.com'), 'approved contribution lands in the Project');

-- Leaving, removing.
select pg_temp.act_as(2);
select public.rawdea_leave_project(pg_temp.pid(1));
select pg_temp.refused(pg_temp.post(2, 1, 'after leaving'), 'You cannot post');
select pg_temp.act_as(10);
select pg_temp.approve_held(id) from held where content like 'later%';
reset role;
select pg_temp.check_that(
    (select p.is_default from public.posts po join public.projects p on p.id = po.project_id
     where po.content = 'later c.com d.com'), 'released after access ended goes to General');
set local role authenticated;

select pg_temp.act_as(4);
insert into public.posts (user_id, project_id, content) values (pg_temp.uid(4), pg_temp.pid(1), 'tom note');
select pg_temp.act_as(1);
select public.rawdea_remove_contributor(pg_temp.pid(1), pg_temp.uid(4), false);
select pg_temp.check_that(
    (select not owner_hidden from public.posts where content = 'tom note'), 'remove keeps posts');
select public.rawdea_remove_contributor(pg_temp.pid(1), pg_temp.uid(4), true);
select pg_temp.check_that(
    (select owner_hidden from public.posts where content = 'tom note'), 'remove and hide');
select public.rawdea_owner_set_post_hidden((select id from public.posts where content = 'tom note'), false);
select pg_temp.act_as(4);
select pg_temp.refused(pg_temp.post(4, 1, 'after removal'), 'You cannot post');

-- A block ends membership at once, from the contributor's side too.
select pg_temp.act_as(7);
select public.rawdea_respond_to_invite(pg_temp.pid(1), true);
select public.rawdea_block_user(pg_temp.uid(1));
select pg_temp.refused(pg_temp.post(7, 1, 'blocked owner'), 'You cannot post');
select pg_temp.check_that(
    (select status = 'removed' from public.project_members where user_id = pg_temp.uid(7)), 'membership ended');
select public.rawdea_unblock_user(pg_temp.uid(1));

-- The third approval prompts the owner once.
select pg_temp.act_as(8);
select public.rawdea_suggest(pg_temp.pid(1), 'note', 'eight two');
select public.rawdea_suggest(pg_temp.pid(1), 'note', 'eight three');
select pg_temp.act_as(1);
select public.rawdea_decide_suggestion(pg_temp.suggestion('eight two'), true);
select pg_temp.check_that(
    not exists (select 1 from public.notifications where kind = 'contributor_prompt'), 'no early prompt');
select public.rawdea_decide_suggestion(pg_temp.suggestion('eight three'), true);
select pg_temp.check_that(
    (select count(*) = 1 from public.notifications
     where kind = 'contributor_prompt' and actor_id = pg_temp.uid(8)), 'prompt after the third');

-- CREDIT -----------------------------------------------------------------

-- Visible helpers so far: maya, ravi's approved note, tom, 6, 7, 8.
select public.rawdea_owner_set_post_hidden(
    (select id from public.posts where content = 'first from 6'), true);
select pg_temp.check_that(
    (select count(*) from public.rawdea_stage_credit_preview(pg_temp.pid(1), 'in_progress')) = 5,
    'preview names visible helpers');
select pg_temp.act_as(5);
select pg_temp.check_that(
    (select count(*) from public.rawdea_stage_credit_preview(pg_temp.pid(1), 'in_progress')) = 0,
    'preview is for the owner');

-- Maya also follows, so would otherwise get two notices.
select pg_temp.act_as(2);
insert into public.project_follows (follower_id, project_id)
values (pg_temp.uid(2), pg_temp.pid(1)) on conflict do nothing;
select pg_temp.act_as(1);
select public.rawdea_set_project_stage(pg_temp.pid(1), 'in_progress');
reset role;
select pg_temp.check_that(
    (select array_agg(c.user_id order by c.user_id)
     from public.project_stage_credits c join public.project_stage_events e on e.id = c.event_id
     where e.project_id = pg_temp.pid(1))
    = array[pg_temp.uid(2), pg_temp.uid(3), pg_temp.uid(4), pg_temp.uid(7), pg_temp.uid(8)],
    'snapshot holds exactly the visible helpers');
select pg_temp.check_that(
    (select count(*) filter (where kind = 'credited') = 1
        and count(*) filter (where kind = 'stage_change') = 0
     from public.notifications
     where recipient_id = pg_temp.uid(2) and project_id = pg_temp.pid(1)
       and kind in ('credited', 'stage_change')),
    'a credited follower hears once');
-- Move the first stage into the past.
update public.posts set created_at = now() - interval '3 hours' where project_id = pg_temp.pid(1);
update public.project_stage_events set created_at = now() - interval '2 hours' where project_id = pg_temp.pid(1);
set local role authenticated;

-- Ravi helps during In progress.
select pg_temp.act_as(3);
select pg_temp.check_that(
    (select status = 'active' from public.project_members where user_id = pg_temp.uid(3)), 'ravi active');
insert into public.posts (user_id, project_id, content) values (pg_temp.uid(3), pg_temp.pid(1), 'ravi in progress');
select pg_temp.act_as(1);
select pg_temp.check_that(
    (select array_agg(username) from public.rawdea_stage_credit_preview(pg_temp.pid(1), 'early'))
    = (select array[username] from public.profiles where id = pg_temp.uid(3)),
    'a later move credits only the stage being left');
select public.rawdea_set_project_stage(pg_temp.pid(1), 'shipped');
select pg_temp.check_that(
    (select count(*) from public.project_stage_credits c
     join public.project_stage_events e on e.id = c.event_id
     where e.project_id = pg_temp.pid(1) and e.to_stage = 'shipped') = 5,
    'shipping credits the whole cycle');
select pg_temp.act_as(3);
select pg_temp.refused(pg_temp.post(3, 1, 'after ship'), 'You cannot post');
select pg_temp.check_that(
    exists (select 1 from public.notifications where kind = 'credited' and stage = 'shipped'), 'told once shipped');

-- A viewer who blocked a helper does not see their credit.
select pg_temp.act_as(5);
select public.rawdea_block_user(pg_temp.uid(3));
select pg_temp.check_that(
    not exists (select 1 from public.project_stage_credits where user_id = pg_temp.uid(3)), 'blocked credit hidden');
select pg_temp.check_that(
    not exists (select 1 from public.project_members where user_id = pg_temp.uid(3)), 'blocked member hidden');
select public.rawdea_unblock_user(pg_temp.uid(3));

select pg_temp.check_that(
    (select is_contributor and cycles = array[1] from public.rawdea_contributed_to(pg_temp.uid(3))
     where project_id = pg_temp.pid(1)), 'contributed to, as contributor');
select pg_temp.check_that(
    (select not is_contributor from public.rawdea_contributed_to(pg_temp.uid(8))
     where project_id = pg_temp.pid(1)), 'contributed to, as suggested');

-- CYCLES -----------------------------------------------------------------

create function pg_temp.start(note text, name text default 'Round two', stage text default 'in_progress')
returns text language sql as $$
    select format('select public.rawdea_start_cycle(%L, %L, %L, %L)',
                  pg_temp.pid(1), note, name, stage);
$$;
grant execute on function pg_temp.start(text, text, text) to authenticated;

select pg_temp.refused(pg_temp.start('not mine'), 'not available');
select pg_temp.act_as(1);
select pg_temp.refused(
    format('select public.rawdea_start_cycle(%L, ''note'')', pg_temp.pid(2)), 'RAWDEA_CYCLE_UNAVAILABLE');
select pg_temp.refused(pg_temp.start('x', repeat('n', 61)), 'up to 60');
select pg_temp.refused(pg_temp.start(''), '1 to 500');
select pg_temp.refused(pg_temp.start('x', 'ok', 'shipped'), 'Early or In progress');
select pg_temp.refused(pg_temp.start('look a.com b.com'), 'RAWDEA_FILTER_HELD');
select pg_temp.check_that(
    (select cycle = 1 and stage = 'shipped' from public.projects where id = pg_temp.pid(1)),
    'a held note saves nothing');

-- One active contributor and one pending invite come into the start.
update public.projects set suggestions_enabled = false where id = pg_temp.pid(1);
reset role;
create temporary table before_cycle on commit drop as
    select stage_changed_at from public.projects where id = pg_temp.pid(1);
delete from public.notifications where project_id = pg_temp.pid(1);
set local role authenticated;
select pg_temp.act_as(1);
select public.rawdea_start_cycle(pg_temp.pid(1), 'Opening two', 'Round two');
reset role;
select pg_temp.check_that(
    (select cycle = 2 and cycle_name = 'Round two' and stage = 'in_progress' and suggestions_enabled
     from public.projects where id = pg_temp.pid(1)), 'cycle 2 started');
select pg_temp.check_that(
    not exists (select 1 from public.project_members
                where project_id = pg_temp.pid(1) and status in ('active', 'invited')), 'just the owner');
select pg_temp.check_that(
    (select cycle = 2 and user_id = pg_temp.uid(1) from public.posts where content = 'Opening two'),
    'opening note');
select pg_temp.check_that(
    (select count(*) = 0 from public.posts
     where project_id = pg_temp.pid(1) and cycle = 2 and content <> 'Opening two'), 'old posts stay in cycle 1');
select pg_temp.check_that(
    (select count(*) = 1 and bool_and(starts_cycle and cycle_name = 'Round two')
     from public.project_stage_events where project_id = pg_temp.pid(1) and cycle = 2), 'one start event');
select pg_temp.check_that(
    not exists (select 1 from public.notifications
                where project_id = pg_temp.pid(1) and kind in ('stage_change', 'credited')),
    'starting is not a credited move');
select pg_temp.check_that(
    (select count(*) = count(distinct recipient_id) and count(*) >= 5 from public.notifications
     where project_id = pg_temp.pid(1) and kind = 'cycle_started'), 'one notice per past helper');
set local role authenticated;

-- Undo restores everything.
select pg_temp.act_as(3);
select pg_temp.refused(format('select public.rawdea_undo_cycle(%L)', pg_temp.pid(1)), 'not available');
select pg_temp.act_as(1);
select public.rawdea_undo_cycle(pg_temp.pid(1));
reset role;
select pg_temp.check_that(
    (select p.cycle = 1 and p.cycle_name is null and p.stage = 'shipped'
            and not p.suggestions_enabled and p.stage_changed_at = b.stage_changed_at
     from public.projects p, before_cycle b where p.id = pg_temp.pid(1)), 'undo restores the Project');
select pg_temp.check_that(
    (select status = 'active' from public.project_members
     where project_id = pg_temp.pid(1) and user_id = pg_temp.uid(3)), 'undo restores contributors');
select pg_temp.check_that(
    not exists (select 1 from public.posts where content = 'Opening two')
    and not exists (select 1 from public.project_stage_events where project_id = pg_temp.pid(1) and cycle = 2)
    and not exists (select 1 from public.notifications where project_id = pg_temp.pid(1) and kind = 'cycle_started'),
    'undo removes its traces');
set local role authenticated;

-- Undo closes when something else is posted.
select pg_temp.act_as(1);
select public.rawdea_start_cycle(pg_temp.pid(1), 'Opening again', null);
insert into public.posts (user_id, project_id, content) values (pg_temp.uid(1), pg_temp.pid(1), 'more work');
select pg_temp.refused(format('select public.rawdea_undo_cycle(%L)', pg_temp.pid(1)), 'RAWDEA_CYCLE_UNDO_CLOSED');
delete from public.posts where content = 'more work';

-- Or someone joins.
select public.rawdea_invite_contributor(pg_temp.pid(1), pg_temp.uid(8));
select pg_temp.act_as(8);
select public.rawdea_respond_to_invite(pg_temp.pid(1), true);
select pg_temp.act_as(1);
select pg_temp.refused(format('select public.rawdea_undo_cycle(%L)', pg_temp.pid(1)), 'RAWDEA_CYCLE_UNDO_CLOSED');

-- Or a day passes.
select public.rawdea_remove_contributor(pg_temp.pid(1), pg_temp.uid(8), false);
reset role;
update public.project_members set joined_at = null where project_id = pg_temp.pid(1) and user_id = pg_temp.uid(8);
update public.project_cycles set started_at = now() - interval '25 hours' where project_id = pg_temp.pid(1);
set local role authenticated;
select pg_temp.act_as(1);
select pg_temp.refused(format('select public.rawdea_undo_cycle(%L)', pg_temp.pid(1)), 'RAWDEA_CYCLE_UNDO_CLOSED');

-- Credit is kept per cycle.
select public.rawdea_invite_contributor(pg_temp.pid(1), pg_temp.uid(2));
select pg_temp.act_as(2);
select public.rawdea_respond_to_invite(pg_temp.pid(1), true);
insert into public.posts (user_id, project_id, content) values (pg_temp.uid(2), pg_temp.pid(1), 'maya in two');
select pg_temp.act_as(1);
select public.rawdea_set_project_stage(pg_temp.pid(1), 'shipped');
select pg_temp.check_that(
    (select array_agg(c.user_id) from public.project_stage_credits c
     join public.project_stage_events e on e.id = c.event_id
     where e.project_id = pg_temp.pid(1) and e.cycle = 2) = array[pg_temp.uid(2)],
    'cycle 2 credit is its own');
select pg_temp.check_that(
    (select cycles = array[1, 2] from public.rawdea_contributed_to(pg_temp.uid(2))
     where project_id = pg_temp.pid(1)), 'both cycles listed');

-- One new cycle per 30 days.
select pg_temp.refused(pg_temp.start('too soon'), 'RAWDEA_CYCLE_TOO_SOON');
reset role;
update public.project_cycles set started_at = now() - interval '31 days' where project_id = pg_temp.pid(1);
set local role authenticated;
select pg_temp.act_as(1);
select public.rawdea_start_cycle(pg_temp.pid(1), 'Third', 'Three', 'early');
select pg_temp.check_that(
    (select cycle = 3 and stage = 'early' from public.projects where id = pg_temp.pid(1)), 'cycle 3');

-- SIGNED OUT -------------------------------------------------------------

set local role anon;
select pg_temp.refused('select * from public.project_suggestions', 'permission denied');
select pg_temp.refused('select * from public.project_members', 'permission denied');
select pg_temp.refused('select * from public.project_stage_credits', 'permission denied');
select pg_temp.refused(pg_temp.suggest(1, 'anon'), 'permission denied');
select pg_temp.refused(
    format('select public.rawdea_decide_suggestion(%L, true)', pg_temp.pid(1)), 'permission denied');

-- ACCOUNT DELETION -------------------------------------------------------

reset role;
select set_config('request.jwt.claims', '', true);
create temporary table guest_posts on commit drop as
    select id, user_id from public.posts
    where project_id = pg_temp.pid(1) and user_id <> pg_temp.uid(1);
delete from auth.users where id = pg_temp.uid(1);
set constraints all immediate;
select pg_temp.check_that(
    (select count(*) > 0 and bool_and(p.is_default and p.user_id = g.user_id)
     from guest_posts g
     join public.posts po on po.id = g.id
     join public.projects p on p.id = po.project_id),
    'other people keep their posts in General');

\echo 'collaborators: all checks passed'
rollback;
