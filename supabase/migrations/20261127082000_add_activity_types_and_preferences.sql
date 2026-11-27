-- RAWDEA Project Lab: Activity for chosen answers and stage
-- changes, and per-user notification preferences.

-- ==========================================
-- 1. NEW NOTIFICATION KINDS
-- ==========================================

alter table public.notifications
add column stage public.project_stage;

alter table public.notifications
drop constraint notifications_kind_check;

alter table public.notifications
add constraint notifications_kind_check
check (
    (
        kind = 'user_follow'
        and post_id is null
        and project_id is null
        and comment_id is null
        and stage is null
    )
    or (
        kind = 'project_follow'
        and project_id is not null
        and post_id is null
        and comment_id is null
        and stage is null
    )
    or (
        kind = 'post_like'
        and post_id is not null
        and project_id is null
        and comment_id is null
        and stage is null
    )
    or (
        kind in ('post_comment', 'best_answer')
        and post_id is not null
        and comment_id is not null
        and project_id is null
        and stage is null
    )
    or (
        kind = 'stage_change'
        and project_id is not null
        and stage is not null
        and post_id is null
        and comment_id is null
    )
);

-- A stage change disappears with the Project's visibility. The
-- subquery runs under projects RLS.
create policy "Stage notifications follow Project visibility"
on public.notifications
as restrictive
for select
to authenticated
using (
    kind <> 'stage_change'
    or exists (
        select 1
        from public.projects p
        where p.id = project_id
    )
);

-- ==========================================
-- 2. PREFERENCES
-- ==========================================

create table public.notification_preferences (
    user_id uuid primary key
        references public.profiles(id)
        on delete cascade,

    answers boolean not null default true,
    stage_changes boolean not null default true,
    likes boolean not null default true
);

alter table public.notification_preferences enable row level security;

revoke all on table public.notification_preferences
from public, anon, authenticated;

grant select, insert, update on table public.notification_preferences
to authenticated;

create policy "Read own notification preferences"
on public.notification_preferences
for select to authenticated
using (user_id = (select auth.uid()));

create policy "Create own notification preferences"
on public.notification_preferences
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "Update own notification preferences"
on public.notification_preferences
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- One place decides whether a recipient wants a notification,
-- so the existing notification triggers stay unchanged.
create function private.rawdea_apply_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_preferences public.notification_preferences;
begin
    select * into v_preferences
    from public.notification_preferences
    where user_id = new.recipient_id;

    -- No row means everything is on.
    if not found then
        return new;
    end if;

    if (new.kind = 'post_like' and not v_preferences.likes)
       or (new.kind = 'stage_change' and not v_preferences.stage_changes)
       or (
           not v_preferences.answers
           and (
               new.kind = 'best_answer'
               or (
                   new.kind = 'post_comment'
                   and exists (
                       select 1
                       from public.posts p
                       where p.id = new.post_id
                         and p.kind = 'question'
                   )
               )
           )
       ) then
        return null;
    end if;

    return new;
end;
$$;

create trigger rawdea_notification_preferences
before insert on public.notifications
for each row
execute function private.rawdea_apply_notification_preferences();

-- ==========================================
-- 3. BEST ANSWER
-- ==========================================

create function private.notify_best_answer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_replier uuid;
begin
    select c.user_id into v_replier
    from public.post_comments c
    where c.id = new.best_reply_id;

    -- Choosing the same answer again does not notify twice.
    if v_replier is not null
       and v_replier <> new.user_id
       and not exists (
           select 1
           from public.notifications n
           where n.kind = 'best_answer'
             and n.comment_id = new.best_reply_id
       ) then

        insert into public.notifications (
            recipient_id, actor_id, kind, post_id, comment_id
        )
        values (
            v_replier, new.user_id, 'best_answer',
            new.id, new.best_reply_id
        );
    end if;

    return new;
end;
$$;

create trigger on_best_answer_notification
after update of best_reply_id on public.posts
for each row
when (
    new.best_reply_id is not null
    and new.best_reply_id is distinct from old.best_reply_id
)
execute function private.notify_best_answer();

-- ==========================================
-- 4. STAGE CHANGE
-- ==========================================

create function private.notify_stage_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid;
begin
    -- Hidden and archived Projects tell nobody.
    select p.user_id into v_owner
    from public.projects p
    where p.id = new.project_id
      and not p.is_hidden
      and not p.is_archived;

    if v_owner is null then
        return new;
    end if;

    -- Only the latest unread move is worth showing.
    delete from public.notifications
    where kind = 'stage_change'
      and project_id = new.project_id
      and not is_read;

    insert into public.notifications (
        recipient_id, actor_id, kind, project_id, stage
    )
    select f.follower_id, v_owner, 'stage_change',
           new.project_id, new.to_stage
    from public.project_follows f
    where f.project_id = new.project_id
      and f.follower_id <> v_owner
      and not exists (
          select 1
          from public.user_blocks b
          where (b.blocker_id = f.follower_id and b.blocked_id = v_owner)
             or (b.blocker_id = v_owner and b.blocked_id = f.follower_id)
      );

    return new;
end;
$$;

create trigger on_stage_change_notification
after insert on public.project_stage_events
for each row
execute function private.notify_stage_change();

revoke execute on function private.rawdea_apply_notification_preferences()
from public, anon, authenticated;
revoke execute on function private.notify_best_answer()
from public, anon, authenticated;
revoke execute on function private.notify_stage_change()
from public, anon, authenticated;

notify pgrst, 'reload schema';
