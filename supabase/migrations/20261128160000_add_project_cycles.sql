-- RAWDEA Project collaborators, part 3: a shipped Project can
-- start its next cycle. Credit is kept per cycle.

-- ==========================================
-- 1. COLUMNS AND HISTORY
-- ==========================================

alter table public.projects
add column cycle integer not null default 1 check (cycle >= 1),
add column cycle_name text check (char_length(cycle_name) between 1 and 60),
add column cycle_started_at timestamptz;

alter table public.posts
add column cycle integer not null default 1;

alter table public.project_stage_events
add column cycle integer not null default 1,
add column starts_cycle boolean not null default false,
add column cycle_name text;

alter table public.project_members
add column ended_by_cycle integer,
add column status_before_cycle text;

-- One row per cycle after the first, with what undo restores.
create table public.project_cycles (
    project_id uuid not null
        references public.projects(id)
        on delete cascade,

    cycle integer not null check (cycle > 1),
    started_at timestamptz not null default now(),

    previous_name text,
    previous_started_at timestamptz,
    previous_stage_changed_at timestamptz not null,
    previous_suggestions_enabled boolean not null,

    opening_post_id uuid
        references public.posts(id)
        on delete set null,

    primary key (project_id, cycle)
);

alter table public.project_cycles enable row level security;

-- No client policies. All access goes through the functions below.
revoke all on table public.project_cycles
from public, anon, authenticated;

-- ==========================================
-- 2. STAMPS AND GUARDS
-- ==========================================

-- Only the functions below move a Project between cycles.
create function private.rawdea_guard_cycle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if current_user in ('anon', 'authenticated') then
        if tg_op = 'INSERT' then
            new.cycle := 1;
            new.cycle_name := null;
            new.cycle_started_at := null;
        else
            new.cycle := old.cycle;
            new.cycle_name := old.cycle_name;
            new.cycle_started_at := old.cycle_started_at;
        end if;
    end if;

    return new;
end;
$$;

create trigger rawdea_guard_project_cycle
before insert or update on public.projects
for each row
execute function private.rawdea_guard_cycle();

-- A post belongs to the cycle it arrived in.
create function private.rawdea_stamp_post_cycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'INSERT'
       or new.project_id is distinct from old.project_id then
        select p.cycle into new.cycle
        from public.projects p
        where p.id = new.project_id;

        new.cycle := coalesce(new.cycle, 1);
    else
        new.cycle := old.cycle;
    end if;

    return new;
end;
$$;

-- Named to run after the Project is settled.
create trigger rawdea_stamp_post_cycle
before insert or update on public.posts
for each row
execute function private.rawdea_stamp_post_cycle();

create function private.rawdea_stamp_event_cycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    select
        p.cycle,
        case when s.starts then p.cycle_name end,
        s.starts
    into new.cycle, new.cycle_name, new.starts_cycle
    from public.projects p,
         (
             select coalesce(
                 current_setting('rawdea.starts_cycle', true), ''
             ) = 'on' as starts
         ) s
    where p.id = new.project_id;

    return new;
end;
$$;

create trigger rawdea_stamp_event_cycle
before insert on public.project_stage_events
for each row
execute function private.rawdea_stamp_event_cycle();

-- Undo returns a Project to Shipped without writing history.
create or replace function private.rawdea_guard_project()
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
        elsif coalesce(
            current_setting('rawdea.undo_cycle', true), ''
        ) = 'on' then
            return new;
        end if;

        new.stage_changed_at := case
            when new.stage is distinct from old.stage then now()
            else old.stage_changed_at
        end;
    end if;

    return new;
end;
$$;

create or replace function private.rawdea_record_stage_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_post_id uuid :=
        nullif(current_setting('rawdea.stage_post_id', true), '')::uuid;
begin
    if coalesce(current_setting('rawdea.undo_cycle', true), '') = 'on' then
        return new;
    end if;

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

-- ==========================================
-- 3. CREDIT PER CYCLE
-- ==========================================

create or replace function private.rawdea_credited_users(
    p_project_id uuid,
    p_since timestamptz
)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
    select distinct po.user_id
    from public.posts po
    join public.projects p on p.id = po.project_id
    where po.project_id = p_project_id
      and po.cycle = p.cycle
      and po.user_id <> p.user_id
      and not po.is_hidden
      and not po.owner_hidden
      and (p_since is null or po.created_at >= p_since)
      and private.rawdea_target_allowed('post', po.id)
      and private.rawdea_account_active(po.user_id)
      and not private.rawdea_blocked_between(po.user_id, p.user_id);
$$;

-- Starting a cycle is not a move anyone is credited for, and
-- followers read it in their feed instead of Activity.
drop trigger rawdea_stage_credit on public.project_stage_events;

create trigger rawdea_stage_credit
after insert on public.project_stage_events
for each row
when (not new.starts_cycle)
execute function private.rawdea_record_credit();

drop trigger on_stage_change_notification on public.project_stage_events;

create trigger on_stage_change_notification
after insert on public.project_stage_events
for each row
when (not new.starts_cycle)
execute function private.notify_stage_change();

drop function public.rawdea_contributed_to(uuid);

create function public.rawdea_contributed_to(p_user_id uuid)
returns table (
    project_id uuid,
    project_name text,
    owner_username text,
    is_contributor boolean,
    cycles integer[],
    latest_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        p.id,
        p.name,
        pr.username,
        bool_or(po.suggestion_id is null),
        array_agg(distinct po.cycle order by po.cycle),
        max(po.created_at)
    from public.posts po
    join public.projects p on p.id = po.project_id
    join public.profiles pr on pr.id = p.user_id
    where po.user_id = p_user_id
      and p.user_id <> p_user_id
      and not po.is_hidden
      and not po.owner_hidden
      and not p.is_hidden
      and not p.is_archived
    group by p.id, p.name, pr.username
    order by max(po.created_at) desc
    limit 50;
$$;

-- ==========================================
-- 4. START AND UNDO
-- ==========================================

create function public.rawdea_start_cycle(
    p_project_id uuid,
    p_note text,
    p_name text default null,
    p_stage public.project_stage default 'in_progress'
)
returns public.projects
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
    v_name text := nullif(btrim(coalesce(p_name, ''), E' \t\r\n'), '');
    v_note text := btrim(coalesce(p_note, ''), E' \t\r\n');
    v_project public.projects;
    v_next integer;
    v_post uuid;
begin
    select * into v_project
    from public.projects p
    where p.id = p_project_id
    for update;

    if v_owner is null
       or v_project.user_id is distinct from v_owner
       or not private.rawdea_account_active(v_owner) then
        raise exception 'That Project is not available'
            using errcode = '42501';
    end if;

    if v_project.is_default
       or v_project.is_hidden
       or v_project.is_archived
       or v_project.stage <> 'shipped' then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_CYCLE_UNAVAILABLE';
    end if;

    if exists (
        select 1
        from public.project_cycles c
        where c.project_id = p_project_id
          and c.started_at > now() - interval '30 days'
    ) then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_CYCLE_TOO_SOON';
    end if;

    if p_stage is null or p_stage = 'shipped' then
        raise exception 'A cycle starts Early or In progress';
    end if;

    if char_length(v_note) not between 1 and 500 then
        raise exception 'The opening note is 1 to 500 characters';
    end if;

    if char_length(v_name) > 60 then
        raise exception 'A cycle name is up to 60 characters';
    end if;

    if v_name is not null then
        perform private.rawdea_assert_publication('project', v_name);
    end if;

    v_next := v_project.cycle + 1;

    insert into public.project_cycles (
        project_id, cycle, previous_name, previous_started_at,
        previous_stage_changed_at, previous_suggestions_enabled
    )
    values (
        p_project_id, v_next, v_project.cycle_name,
        v_project.cycle_started_at, v_project.stage_changed_at,
        v_project.suggestions_enabled
    );

    perform set_config('rawdea.stage_post_id', '', true);
    perform set_config('rawdea.starts_cycle', 'on', true);

    update public.projects
    set cycle = v_next,
        cycle_name = v_name,
        cycle_started_at = now(),
        stage = p_stage,
        suggestions_enabled = true
    where id = p_project_id;

    perform set_config('rawdea.starts_cycle', '', true);

    -- The next cycle starts with just the owner.
    update public.project_members
    set status_before_cycle = status,
        ended_by_cycle = v_next,
        status = 'left',
        ended_at = now()
    where project_id = p_project_id
      and status in ('invited', 'active');

    delete from public.notifications
    where project_id = p_project_id
      and kind in ('contributor_invite', 'contributor_prompt');

    -- The note passes the same checks as any post. If it needs
    -- one, nothing about the cycle is saved.
    insert into public.posts (user_id, content, project_id, kind)
    values (v_owner, v_note, p_project_id, 'note')
    returning id into v_post;

    update public.project_cycles
    set opening_post_id = v_post
    where project_id = p_project_id
      and cycle = v_next;

    -- One notice to everyone who helped before.
    insert into public.notifications (
        recipient_id, actor_id, kind, project_id, item_count
    )
    select helper.user_id, v_owner, 'cycle_started', p_project_id, v_next
    from (
        select s.user_id
        from public.project_suggestions s
        where s.project_id = p_project_id
          and s.status = 'approved'
        union
        select m.user_id
        from public.project_members m
        where m.project_id = p_project_id
          and m.joined_at is not null
    ) as helper
    where helper.user_id <> v_owner
      and private.rawdea_account_active(helper.user_id)
      and not private.rawdea_blocked_between(helper.user_id, v_owner);

    select * into v_project
    from public.projects p
    where p.id = p_project_id;

    return v_project;
end;
$$;

create function public.rawdea_undo_cycle(p_project_id uuid)
returns public.projects
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
    v_project public.projects;
    v_cycle public.project_cycles;
begin
    select * into v_project
    from public.projects p
    where p.id = p_project_id
    for update;

    if v_owner is null
       or v_project.user_id is distinct from v_owner
       or not private.rawdea_account_active(v_owner) then
        raise exception 'That Project is not available'
            using errcode = '42501';
    end if;

    select * into v_cycle
    from public.project_cycles c
    where c.project_id = p_project_id
      and c.cycle = v_project.cycle;

    if v_cycle.project_id is null
       or v_cycle.started_at <= now() - interval '24 hours'
       or exists (
           select 1
           from public.posts po
           where po.project_id = p_project_id
             and po.cycle = v_cycle.cycle
             and po.id is distinct from v_cycle.opening_post_id
       )
       or exists (
           select 1
           from public.post_comments c
           where c.post_id = v_cycle.opening_post_id
             and c.user_id <> v_owner
       )
       or exists (
           select 1
           from public.project_members m
           where m.project_id = p_project_id
             and m.joined_at >= v_cycle.started_at
       )
       or exists (
           select 1
           from public.project_stage_events e
           where e.project_id = p_project_id
             and e.cycle = v_cycle.cycle
             and not e.starts_cycle
       ) then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_CYCLE_UNDO_CLOSED';
    end if;

    delete from public.project_stage_events
    where project_id = p_project_id
      and cycle = v_cycle.cycle;

    delete from public.posts
    where id = v_cycle.opening_post_id;

    perform set_config('rawdea.undo_cycle', 'on', true);

    update public.projects
    set cycle = v_cycle.cycle - 1,
        cycle_name = v_cycle.previous_name,
        cycle_started_at = v_cycle.previous_started_at,
        stage = 'shipped',
        stage_changed_at = v_cycle.previous_stage_changed_at,
        suggestions_enabled = v_cycle.previous_suggestions_enabled
    where id = p_project_id;

    perform set_config('rawdea.undo_cycle', '', true);

    -- Invitations sent for the undone cycle are withdrawn.
    delete from public.project_members
    where project_id = p_project_id
      and status = 'invited'
      and ended_by_cycle is distinct from v_cycle.cycle
      and invited_at >= v_cycle.started_at;

    update public.project_members m
    set status = case
            when private.rawdea_blocked_between(m.user_id, v_owner)
                then 'removed'
            else m.status_before_cycle
        end,
        ended_at = null,
        ended_by_cycle = null,
        status_before_cycle = null
    where m.project_id = p_project_id
      and m.ended_by_cycle = v_cycle.cycle;

    delete from public.notifications
    where project_id = p_project_id
      and kind in (
          'cycle_started', 'contributor_invite', 'contributor_prompt'
      );

    delete from public.project_cycles
    where project_id = p_project_id
      and cycle = v_cycle.cycle;

    select * into v_project
    from public.projects p
    where p.id = p_project_id;

    return v_project;
end;
$$;

-- ==========================================
-- 5. NOTIFICATIONS
-- ==========================================

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
        kind in (
            'project_follow',
            'suggestion_declined',
            'contributor_invite',
            'contributor_prompt'
        )
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
        kind in ('stage_change', 'credited')
        and project_id is not null
        and stage is not null
        and post_id is null
        and comment_id is null
    )
    or (
        kind in ('suggestions_waiting', 'cycle_started')
        and project_id is not null
        and item_count > 0
        and post_id is null
        and comment_id is null
        and stage is null
    )
    or (
        kind = 'suggestion_approved'
        and project_id is not null
        and post_id is not null
        and comment_id is null
        and stage is null
    )
);

create or replace function private.rawdea_apply_notification_preferences()
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

    -- No row means everything is on. An invitation always arrives.
    if not found then
        return new;
    end if;

    if (new.kind = 'post_like' and not v_preferences.likes)
       or (new.kind = 'stage_change' and not v_preferences.stage_changes)
       or (
           new.kind in (
               'suggestions_waiting',
               'suggestion_approved',
               'suggestion_declined',
               'contributor_prompt'
           )
           and not v_preferences.suggestions
       )
       or (
           new.kind in ('credited', 'cycle_started')
           and not v_preferences.collaboration
       )
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

-- ==========================================
-- 6. EXECUTION PRIVILEGES
-- ==========================================

revoke execute on function
    private.rawdea_guard_cycle(),
    private.rawdea_stamp_post_cycle(),
    private.rawdea_stamp_event_cycle()
from public, anon, authenticated;

revoke execute on function
    public.rawdea_contributed_to(uuid),
    public.rawdea_start_cycle(uuid, text, text, public.project_stage),
    public.rawdea_undo_cycle(uuid)
from public, anon, authenticated;

grant execute on function
    public.rawdea_contributed_to(uuid),
    public.rawdea_start_cycle(uuid, text, text, public.project_stage),
    public.rawdea_undo_cycle(uuid)
to authenticated;

notify pgrst, 'reload schema';
