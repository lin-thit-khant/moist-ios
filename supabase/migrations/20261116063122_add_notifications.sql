
-- RAWDEA Milestone 9
-- In-app notifications

-- ==========================================
-- 1. NOTIFICATIONS
-- ==========================================

create table public.notifications (

    id uuid primary key default gen_random_uuid(),

    recipient_id uuid not null,
    actor_id uuid not null,

    kind text not null,

    post_id uuid,
    project_id uuid,
    comment_id uuid,

    is_read boolean not null default false,

    created_at timestamptz not null default now(),

    constraint notifications_recipient_id_fkey
        foreign key (recipient_id)
        references public.profiles(id)
        on delete cascade,

    constraint notifications_actor_id_fkey
        foreign key (actor_id)
        references public.profiles(id)
        on delete cascade,

    constraint notifications_post_id_fkey
        foreign key (post_id)
        references public.posts(id)
        on delete cascade,

    constraint notifications_project_id_fkey
        foreign key (project_id)
        references public.projects(id)
        on delete cascade,

    constraint notifications_comment_id_fkey
        foreign key (comment_id)
        references public.post_comments(id)
        on delete cascade,

    constraint notifications_no_self_event
        check (recipient_id <> actor_id),

    constraint notifications_kind_check
        check (
            (
                kind = 'user_follow'
                and post_id is null
                and project_id is null
                and comment_id is null
            )
            or
            (
                kind = 'project_follow'
                and project_id is not null
                and post_id is null
                and comment_id is null
            )
            or
            (
                kind = 'post_like'
                and post_id is not null
                and project_id is null
                and comment_id is null
            )
            or
            (
                kind = 'post_comment'
                and post_id is not null
                and comment_id is not null
                and project_id is null
            )
        )
);

-- ==========================================
-- 2. INDEXES
-- ==========================================

create index notifications_recipient_created_idx
on public.notifications (
    recipient_id,
    created_at desc,
    id desc
);

create index notifications_recipient_unread_idx
on public.notifications (recipient_id)
where is_read = false;

-- ==========================================
-- 3. PERMISSIONS
-- ==========================================

alter table public.notifications
enable row level security;

revoke all on table public.notifications
from anon, authenticated;

grant select on table public.notifications
to authenticated;

-- Users can update only read status.

grant update (is_read)
on table public.notifications
to authenticated;

-- No client INSERT or DELETE privileges.

-- ==========================================
-- 4. READ OWN NOTIFICATIONS
-- ==========================================

create policy "Read own notifications"
on public.notifications
for select
to authenticated
using (
    recipient_id = (select auth.uid())
);

-- ==========================================
-- 5. UPDATE OWN READ STATUS
-- ==========================================

create policy "Update own notification read status"
on public.notifications
for update
to authenticated
using (
    recipient_id = (select auth.uid())
)
with check (
    recipient_id = (select auth.uid())
);

-- ==========================================
-- 6. PRIVATE TRIGGER SCHEMA
-- ==========================================

create schema if not exists private;

-- ==========================================
-- 7. USER FOLLOW NOTIFICATION
-- ==========================================

create function private.notify_user_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if new.follower_id <> new.followed_user_id then

        insert into public.notifications (
            recipient_id,
            actor_id,
            kind
        )
        values (
            new.followed_user_id,
            new.follower_id,
            'user_follow'
        );

    end if;

    return new;

end;
$$;

create trigger on_user_follow_notification
after insert on public.user_follows
for each row
execute function private.notify_user_follow();


-- ==========================================
-- 8. PROJECT FOLLOW NOTIFICATION
-- ==========================================

create function private.notify_project_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    project_owner_id uuid;
begin

    select p.user_id
    into project_owner_id
    from public.projects p
    where p.id = new.project_id;

    if project_owner_id is not null
       and project_owner_id <> new.follower_id then

        insert into public.notifications (
            recipient_id,
            actor_id,
            kind,
            project_id
        )
        values (
            project_owner_id,
            new.follower_id,
            'project_follow',
            new.project_id
        );

    end if;

    return new;

end;
$$;

create trigger on_project_follow_notification
after insert on public.project_follows
for each row
execute function private.notify_project_follow();


-- ==========================================
-- 9. POST LIKE NOTIFICATION
-- ==========================================

create function private.notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    post_owner_id uuid;
begin

    select p.user_id
    into post_owner_id
    from public.posts p
    where p.id = new.post_id;

    if post_owner_id is not null
       and post_owner_id <> new.user_id then

        insert into public.notifications (
            recipient_id,
            actor_id,
            kind,
            post_id
        )
        values (
            post_owner_id,
            new.user_id,
            'post_like',
            new.post_id
        );

    end if;

    return new;

end;
$$;

create trigger on_post_like_notification
after insert on public.post_likes
for each row
execute function private.notify_post_like();


-- ==========================================
-- 10. POST COMMENT NOTIFICATION
-- ==========================================

create function private.notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    post_owner_id uuid;
begin

    select p.user_id
    into post_owner_id
    from public.posts p
    where p.id = new.post_id;

    if post_owner_id is not null
       and post_owner_id <> new.user_id then

        insert into public.notifications (
            recipient_id,
            actor_id,
            kind,
            post_id,
            comment_id
        )
        values (
            post_owner_id,
            new.user_id,
            'post_comment',
            new.post_id,
            new.id
        );

    end if;

    return new;

end;
$$;

create trigger on_post_comment_notification
after insert on public.post_comments
for each row
execute function private.notify_post_comment();


-- ==========================================
-- 11. RESTRICT FUNCTION EXECUTION
-- ==========================================

revoke execute
on function private.notify_user_follow()
from public, anon, authenticated;

revoke execute
on function private.notify_project_follow()
from public, anon, authenticated;

revoke execute
on function private.notify_post_like()
from public, anon, authenticated;

revoke execute
on function private.notify_post_comment()
from public, anon, authenticated;


-- ==========================================
-- 12. RELOAD POSTGREST SCHEMA
-- ==========================================

notify pgrst, 'reload schema';
