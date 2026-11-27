-- RAWDEA Project Lab: Project stages, post kinds, best replies,
-- last-seen Projects, and a Project for every post.

-- ==========================================
-- 1. PROJECT STAGE AND DEFAULT PROJECT
-- ==========================================

create type public.project_stage as enum ('early', 'in_progress', 'shipped');

alter table public.projects
add column stage public.project_stage not null default 'early',
add column stage_changed_at timestamptz,
add column is_default boolean not null default false;

-- Existing Projects have been Early since they were created.
update public.projects set stage_changed_at = created_at;

alter table public.projects
alter column stage_changed_at set default now(),
alter column stage_changed_at set not null;

create unique index projects_one_default_idx
on public.projects(user_id)
where is_default;

-- Security invoker: current_user tells client writes apart
-- from trusted ones. Owner-only writes stay enforced by RLS.
create function private.rawdea_guard_project()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        if current_user in ('anon', 'authenticated') then
            new.is_default := false;
            new.stage_changed_at := now();
        end if;
    else
        if current_user in ('anon', 'authenticated') then
            new.is_default := old.is_default;
        end if;

        new.stage_changed_at := case
            when new.stage is distinct from old.stage then now()
            else old.stage_changed_at
        end;
    end if;

    return new;
end;
$$;

create trigger rawdea_guard_projects
before insert or update on public.projects
for each row
execute function private.rawdea_guard_project();

-- ==========================================
-- 2. STAGE HISTORY
-- ==========================================

create table public.project_stage_events (
    id uuid primary key default gen_random_uuid(),

    project_id uuid not null
        references public.projects(id)
        on delete cascade,

    from_stage public.project_stage not null,
    to_stage public.project_stage not null,

    post_id uuid
        references public.posts(id)
        on delete set null,

    created_at timestamptz not null default now()
);

create index project_stage_events_project_idx
on public.project_stage_events(project_id, created_at desc);

create index project_stage_events_post_idx
on public.project_stage_events(post_id)
where post_id is not null;

alter table public.project_stage_events enable row level security;

revoke all on table public.project_stage_events
from public, anon, authenticated;

-- Read only. Rows are written by the trigger below.
grant select on table public.project_stage_events
to authenticated;

-- The subquery runs under projects RLS, so hidden, archived,
-- blocked, suspended and removed Projects hide their history.
create policy "Read stage events of visible projects"
on public.project_stage_events
for select
to authenticated
using (
    exists (
        select 1
        from public.projects p
        where p.id = project_id
    )
);

create function private.rawdea_record_stage_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_post_id uuid :=
        nullif(current_setting('rawdea.stage_post_id', true), '')::uuid;
begin
    if v_post_id is not null and not exists (
        select 1
        from public.posts p
        where p.id = v_post_id
          and p.project_id = new.id
          and p.user_id = new.user_id
    ) then
        raise exception 'The post does not belong to this Project';
    end if;

    insert into public.project_stage_events (
        project_id, from_stage, to_stage, post_id
    )
    values (new.id, old.stage, new.stage, v_post_id);

    return new;
end;
$$;

create trigger rawdea_stage_change
after update of stage on public.projects
for each row
when (old.stage is distinct from new.stage)
execute function private.rawdea_record_stage_change();

-- Security invoker: projects RLS decides who may change a stage.
create function public.rawdea_set_project_stage(
    p_project_id uuid,
    p_stage public.project_stage,
    p_post_id uuid default null
)
returns public.projects
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_project public.projects;
begin
    perform set_config(
        'rawdea.stage_post_id', coalesce(p_post_id::text, ''), true
    );

    update public.projects
    set stage = p_stage
    where id = p_project_id
      and user_id = (select auth.uid())
    returning * into v_project;

    if not found then
        raise exception 'Project not found';
    end if;

    perform set_config('rawdea.stage_post_id', '', true);

    return v_project;
end;
$$;

-- ==========================================
-- 3. POST KIND AND BEST REPLY
-- ==========================================

create type public.post_kind as enum
    ('note', 'question', 'progress', 'decision');

alter table public.posts
add column kind public.post_kind not null default 'note',
add column best_reply_id uuid
    references public.post_comments(id)
    on delete set null;

create index posts_best_reply_idx
on public.posts(best_reply_id)
where best_reply_id is not null;

-- Who may write is enforced by the existing owner-only posts
-- policies. This checks what may be chosen.
create function private.rawdea_check_best_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.best_reply_id is null then
        return new;
    end if;

    if tg_op = 'UPDATE'
       and new.best_reply_id is not distinct from old.best_reply_id then

        -- Changing a question into something else clears it.
        if new.kind <> 'question' then
            new.best_reply_id := null;
        end if;

        return new;
    end if;

    if new.kind <> 'question' then
        raise exception 'Only questions can have a best reply';
    end if;

    if not exists (
        select 1
        from public.post_comments c
        where c.id = new.best_reply_id
          and c.post_id = new.id
          and private.rawdea_account_active(c.user_id)
          and private.rawdea_target_allowed('comment', c.id)
          and (
              (select auth.uid()) is null
              or private.rawdea_can_access_user(c.user_id)
          )
    ) then
        raise exception 'That reply cannot be chosen';
    end if;

    return new;
end;
$$;

create trigger rawdea_best_reply
before insert or update of best_reply_id, kind
on public.posts
for each row
execute function private.rawdea_check_best_reply();

-- ==========================================
-- 4. EVERY POST BELONGS TO A PROJECT
-- ==========================================

create function private.rawdea_default_project(p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id uuid;
begin
    insert into public.projects (user_id, name, is_default)
    values (p_user_id, 'General', true)
    on conflict (user_id) where is_default do nothing;

    select p.id into v_id
    from public.projects p
    where p.user_id = p_user_id
      and p.is_default;

    return v_id;
end;
$$;

-- Posts sent without a Project go to the author's default one.
-- If the author hid or archived it, the post stays private.
create function private.rawdea_assign_default_project()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.project_id is null then
        new.project_id :=
            private.rawdea_default_project(new.user_id);
    end if;

    return new;
end;
$$;

-- Named to run before rawdea_prepublication_posts.
create trigger rawdea_default_project_posts
before insert or update of project_id
on public.posts
for each row
execute function private.rawdea_assign_default_project();

-- Backfill. Content and visibility do not change, so the
-- publication filter is paused only for this reassignment:
-- an old post must not abort the migration.
alter table public.posts
disable trigger rawdea_prepublication_posts;

update public.posts
set project_id = null
where project_id is null;

alter table public.posts
enable trigger rawdea_prepublication_posts;

-- Date each default Project from its oldest post.
update public.projects pr
set created_at = oldest.created_at
from (
    select project_id, min(created_at) as created_at
    from public.posts
    group by project_id
) oldest
where pr.id = oldest.project_id
  and pr.is_default;

-- A Project that still has posts cannot be deleted. Deferred so
-- that deleting an account can cascade through both tables.
alter table public.posts
drop constraint posts_project_owner_fk;

set constraints all immediate;

alter table public.posts
add constraint posts_project_owner_fk
foreign key (project_id, user_id)
references public.projects(id, user_id)
deferrable initially deferred;

alter table public.posts
alter column project_id set not null;

-- ==========================================
-- 5. LAST SEEN (PRIVATE TO THE FOLLOWER)
-- ==========================================

alter table public.project_follows
add column last_seen_at timestamptz;

-- Follows of public Projects are readable by other people,
-- so last_seen_at is left out of the readable columns.
revoke select on table public.project_follows
from authenticated;

grant select (follower_id, project_id, created_at)
on public.project_follows
to authenticated;

grant update (last_seen_at)
on public.project_follows
to authenticated;

create policy "Users can mark own project follows seen"
on public.project_follows
for update
to authenticated
using (follower_id = (select auth.uid()))
with check (follower_id = (select auth.uid()));

create policy "Moderation project follow update restriction"
on public.project_follows
as restrictive
for update
to authenticated
using (private.rawdea_account_active((select auth.uid())))
with check (private.rawdea_account_active((select auth.uid())));

-- The server clock decides the time.
create function private.rawdea_stamp_last_seen()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.last_seen_at is not null then
        new.last_seen_at := now();
    end if;

    return new;
end;
$$;

create trigger rawdea_last_seen
before insert or update of last_seen_at
on public.project_follows
for each row
execute function private.rawdea_stamp_last_seen();

create function public.rawdea_followed_project_last_seen()
returns table (project_id uuid, last_seen_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
    select f.project_id, f.last_seen_at
    from public.project_follows f
    join public.projects p on p.id = f.project_id
    where f.follower_id = (select auth.uid())
      and not p.is_hidden
      and not p.is_archived
      and private.rawdea_account_active(p.user_id)
      and private.rawdea_can_access_user(p.user_id);
$$;

-- ==========================================
-- 6. EXECUTION PRIVILEGES
-- ==========================================

revoke execute on function private.rawdea_guard_project()
from public, anon, authenticated;
revoke execute on function private.rawdea_record_stage_change()
from public, anon, authenticated;
revoke execute on function private.rawdea_check_best_reply()
from public, anon, authenticated;
revoke execute on function private.rawdea_default_project(uuid)
from public, anon, authenticated;
revoke execute on function private.rawdea_assign_default_project()
from public, anon, authenticated;
revoke execute on function private.rawdea_stamp_last_seen()
from public, anon, authenticated;

revoke execute on function
public.rawdea_set_project_stage(uuid, public.project_stage, uuid)
from public, anon;
grant execute on function
public.rawdea_set_project_stage(uuid, public.project_stage, uuid)
to authenticated;

revoke execute on function
public.rawdea_followed_project_last_seen()
from public, anon;
grant execute on function
public.rawdea_followed_project_last_seen()
to authenticated;

notify pgrst, 'reload schema';
