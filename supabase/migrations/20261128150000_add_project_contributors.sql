-- RAWDEA Project collaborators, part 2: invited contributors, the
-- owner's say over posts and answers, and credit for stage moves.

-- ==========================================
-- 1. MEMBERS
-- ==========================================

create table public.project_members (
    project_id uuid not null
        references public.projects(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    status text not null
        check (status in (
            'invited', 'active', 'declined', 'left', 'removed'
        )),

    invited_at timestamptz not null default now(),
    joined_at timestamptz,
    ended_at timestamptz,

    primary key (project_id, user_id)
);

create index project_members_user_idx
on public.project_members(user_id, status);

alter table public.project_members enable row level security;

revoke all on table public.project_members
from public, anon, authenticated;

-- Read only. Every change goes through the functions below.
grant select on table public.project_members to authenticated;

-- Active contributors show wherever the Project shows. Invitations
-- and endings are between the owner and that person.
create policy "Read permitted project members"
on public.project_members
for select
to authenticated
using (
    user_id = (select auth.uid())
    or (
        private.rawdea_project_owner(project_id) = (select auth.uid())
        and private.rawdea_can_access_user(user_id)
    )
    or (
        status = 'active'
        and private.rawdea_can_access_user(user_id)
        and private.rawdea_account_active(user_id)
        and exists (
            select 1
            from public.projects p
            where p.id = project_id
        )
    )
);

-- Access pauses while the Project is shipped, hidden or archived.
create or replace function private.rawdea_member_can_post(
    p_user_id uuid,
    p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.project_members m
        join public.projects p on p.id = m.project_id
        where m.project_id = p_project_id
          and m.user_id = p_user_id
          and m.status = 'active'
          and not p.is_default
          and not p.is_hidden
          and not p.is_archived
          and p.stage <> 'shipped'
          and private.rawdea_account_active(p.user_id)
          and private.rawdea_account_active(m.user_id)
          and not private.rawdea_blocked_between(m.user_id, p.user_id)
    );
$$;

-- ==========================================
-- 2. INVITE, ANSWER, LEAVE, REMOVE
-- ==========================================

create function public.rawdea_invite_contributor(
    p_project_id uuid,
    p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
    v_project public.projects;
begin
    -- Invitations to one Project wait their turn, so the cap holds.
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
       or v_project.stage = 'shipped'
       or p_user_id is null
       or p_user_id = v_owner
       or not private.rawdea_account_active(p_user_id)
       or private.rawdea_blocked_between(v_owner, p_user_id)
       or not exists (
           select 1
           from public.project_suggestions s
           where s.project_id = p_project_id
             and s.user_id = p_user_id
             and s.status = 'approved'
       ) then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_INVITE_UNAVAILABLE';
    end if;

    if exists (
        select 1
        from public.project_members m
        where m.project_id = p_project_id
          and m.user_id = p_user_id
          and m.status in ('invited', 'active')
    ) then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_INVITE_CHANGED';
    end if;

    if (
        select count(*)
        from public.project_members m
        where m.project_id = p_project_id
          and m.status in ('invited', 'active')
    ) >= 5 then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_CONTRIBUTORS_FULL';
    end if;

    insert into public.project_members (project_id, user_id, status)
    values (p_project_id, p_user_id, 'invited')
    on conflict (project_id, user_id) do update
    set status = 'invited',
        invited_at = now(),
        joined_at = null,
        ended_at = null;

    delete from public.notifications
    where project_id = p_project_id
      and (
          (kind = 'contributor_invite' and recipient_id = p_user_id)
          or (kind = 'contributor_prompt' and actor_id = p_user_id)
      );

    insert into public.notifications (
        recipient_id, actor_id, kind, project_id
    )
    values (p_user_id, v_owner, 'contributor_invite', p_project_id);
end;
$$;

create function public.rawdea_respond_to_invite(
    p_project_id uuid,
    p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user uuid := (select auth.uid());
    v_project public.projects;
begin
    select * into v_project
    from public.projects p
    where p.id = p_project_id
    for share;

    perform 1
    from public.project_members m
    where m.project_id = p_project_id
      and m.user_id = v_user
      and m.status = 'invited'
    for update;

    if not found or p_accept is null then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_INVITE_CHANGED';
    end if;

    if p_accept then
        if v_project.is_hidden
           or v_project.is_archived
           or not private.rawdea_account_active(v_user)
           or not private.rawdea_account_active(v_project.user_id)
           or private.rawdea_blocked_between(v_user, v_project.user_id) then
            raise exception using
                errcode = 'P0001',
                message = 'RAWDEA_INVITE_UNAVAILABLE';
        end if;

        update public.project_members
        set status = 'active',
            joined_at = clock_timestamp()
        where project_id = p_project_id
          and user_id = v_user;

        -- Joining also follows the Project.
        insert into public.project_follows (follower_id, project_id)
        values (v_user, p_project_id)
        on conflict do nothing;
    else
        update public.project_members
        set status = 'declined',
            ended_at = now()
        where project_id = p_project_id
          and user_id = v_user;
    end if;

    delete from public.notifications
    where kind = 'contributor_invite'
      and project_id = p_project_id
      and recipient_id = v_user;
end;
$$;

-- Always allowed, even while suspended.
create function public.rawdea_leave_project(p_project_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.project_members
    set status = 'left',
        ended_at = now()
    where project_id = p_project_id
      and user_id = (select auth.uid())
      and status = 'active';

    if not found then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_INVITE_CHANGED';
    end if;
end;
$$;

-- ==========================================
-- 3. THE OWNER'S SAY OVER POSTS
-- ==========================================

alter table public.posts
add column owner_hidden boolean not null default false;

create policy "Owner hidden posts"
on public.posts
as restrictive
for select
to authenticated
using (
    not owner_hidden
    or user_id = (select auth.uid())
    or private.rawdea_project_owner(project_id) = (select auth.uid())
);

create policy "Owner hidden posts for visitors"
on public.posts
as restrictive
for select
to anon
using (not owner_hidden);

create or replace function private.rawdea_guard_post_project()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_client boolean := current_user in ('anon', 'authenticated');
    v_moved boolean := tg_op = 'UPDATE'
        and new.project_id is distinct from old.project_id;
begin
    if v_client then
        if tg_op = 'INSERT' then
            new.suggestion_id := null;
            new.owner_hidden := false;
        elsif v_moved then
            new.suggestion_id := null;
            new.owner_hidden := false;
        else
            new.suggestion_id := old.suggestion_id;
            new.owner_hidden := old.owner_hidden;
        end if;
    end if;

    if private.rawdea_project_owner(new.project_id) = new.user_id then
        return new;
    end if;

    if v_client then
        if v_moved then
            raise exception 'Posts can only be moved into your own Project'
                using errcode = '42501';
        end if;

        if tg_op = 'INSERT' then
            if new.kind = 'decision'
               or not private.rawdea_member_can_post(
                   new.user_id, new.project_id
               ) then
                raise exception 'You cannot post in this Project'
                    using errcode = '42501';
            end if;
        elsif new.kind is distinct from old.kind
              and new.kind = 'decision' then
            raise exception 'Only the owner posts decisions'
                using errcode = '42501';
        end if;

    -- Trusted writes other than an approved suggestion, such as a
    -- released held post, go to General if access has ended.
    elsif tg_op = 'INSERT'
          and new.suggestion_id is null
          and (
              new.kind = 'decision'
              or not private.rawdea_member_can_post(
                  new.user_id, new.project_id
              )
          ) then
        new.project_id := private.rawdea_default_project(new.user_id);
    end if;

    return new;
end;
$$;

-- A post the owner hid stays out of sight after the move.
create or replace function private.rawdea_release_guest_posts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.posts p
    where p.project_id = old.id
      and p.user_id <> old.user_id
      and private.rawdea_filter_category('post', p.content) is not null;

    update public.posts p
    set project_id = private.rawdea_default_project(p.user_id),
        suggestion_id = null,
        is_hidden = p.is_hidden or p.owner_hidden,
        owner_hidden = false
    where p.project_id = old.id
      and p.user_id <> old.user_id;

    return old;
end;
$$;

create function public.rawdea_owner_set_post_hidden(
    p_post_id uuid,
    p_hidden boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
begin
    update public.posts po
    set owner_hidden = p_hidden
    from public.projects p
    where po.id = p_post_id
      and p.id = po.project_id
      and p.user_id = v_owner
      and po.user_id <> v_owner
      and p_hidden is not null
      and private.rawdea_account_active(v_owner);

    if not found then
        raise exception 'That post is not available'
            using errcode = '42501';
    end if;
end;
$$;

create function public.rawdea_remove_contributor(
    p_project_id uuid,
    p_user_id uuid,
    p_hide_posts boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
begin
    if v_owner is null
       or private.rawdea_project_owner(p_project_id)
          is distinct from v_owner then
        raise exception 'That Project is not available'
            using errcode = '42501';
    end if;

    update public.project_members
    set status = 'removed',
        ended_at = now()
    where project_id = p_project_id
      and user_id = p_user_id;

    if not found then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_INVITE_CHANGED';
    end if;

    if p_hide_posts then
        update public.posts
        set owner_hidden = true
        where project_id = p_project_id
          and user_id = p_user_id;
    end if;

    delete from public.notifications
    where kind = 'contributor_invite'
      and project_id = p_project_id
      and recipient_id = p_user_id;
end;
$$;

-- A block in either direction ends membership at once.
create function private.rawdea_end_membership_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.project_members m
    set status = 'removed',
        ended_at = now()
    from public.projects p
    where p.id = m.project_id
      and m.status in ('invited', 'active')
      and (
          (m.user_id = new.blocker_id and p.user_id = new.blocked_id)
          or (m.user_id = new.blocked_id and p.user_id = new.blocker_id)
      );

    return new;
end;
$$;

create trigger rawdea_end_membership_on_block
after insert on public.user_blocks
for each row
execute function private.rawdea_end_membership_on_block();

-- ==========================================
-- 4. CONTRIBUTOR POSTS THAT NEED A CHECK
-- ==========================================

-- Like rawdea_hold_post, for a Project the caller contributes to.
create function public.rawdea_hold_contribution(
    p_content text,
    p_project_id uuid,
    p_kind public.post_kind default 'note'
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user uuid := (select auth.uid());
    v_content text := btrim(coalesce(p_content, ''), E' \t\r\n');
    v_reason text;
begin
    if v_user is null
       or coalesce(p_kind, 'note') = 'decision'
       or not private.rawdea_member_can_post(v_user, p_project_id) then
        raise exception 'That Project is not available'
            using errcode = '42501';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('post:' || v_user::text, 13506)
    );

    -- Sending the same text again does not queue it twice.
    select h.reason into v_reason
    from private.rawdea_held_posts h
    where h.user_id = v_user
      and h.project_id = p_project_id
      and h.content = v_content
      and h.status = 'pending';

    if v_reason is not null then
        return v_reason;
    end if;

    perform private.rawdea_assert_publication('post', v_content);
    perform private.rawdea_count_post(v_user);

    v_reason := private.rawdea_hold_reason(v_user, v_content);

    if v_reason is null then
        raise exception 'This post does not need a check';
    end if;

    insert into private.rawdea_held_posts (
        user_id, project_id, content, kind, reason
    )
    values (
        v_user, p_project_id, v_content,
        coalesce(p_kind, 'note'), v_reason
    );

    return v_reason;
end;
$$;

-- ==========================================
-- 5. BEST ANSWER
-- ==========================================

create function public.rawdea_owner_set_best_reply(
    p_post_id uuid,
    p_comment_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
begin
    update public.posts po
    set best_reply_id = p_comment_id
    from public.projects p
    where po.id = p_post_id
      and po.kind = 'question'
      and p.id = po.project_id
      and p.user_id = v_owner
      and (po.user_id = v_owner or not po.is_hidden)
      and private.rawdea_account_active(v_owner)
      and private.rawdea_account_active(po.user_id)
      and private.rawdea_target_allowed('post', po.id)
      and not private.rawdea_blocked_between(v_owner, po.user_id);

    if not found then
        raise exception 'That question is not available'
            using errcode = '42501';
    end if;
end;
$$;

-- The person who chose is the one named.
create or replace function private.notify_best_answer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_replier uuid;
    v_chooser uuid := coalesce((select auth.uid()), new.user_id);
begin
    select c.user_id into v_replier
    from public.post_comments c
    where c.id = new.best_reply_id;

    -- Choosing the same answer again does not notify twice.
    if v_replier is not null
       and v_replier <> v_chooser
       and not private.rawdea_blocked_between(v_replier, v_chooser)
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
            v_replier, v_chooser, 'best_answer',
            new.id, new.best_reply_id
        );
    end if;

    return new;
end;
$$;

-- ==========================================
-- 6. NOTIFICATIONS
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
        kind = 'suggestions_waiting'
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

alter table public.notification_preferences
add column collaboration boolean not null default true;

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
       or (new.kind = 'credited' and not v_preferences.collaboration)
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

-- After a person's third approved suggestion, offer to invite them.
create function private.rawdea_prompt_invite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := private.rawdea_project_owner(new.project_id);
begin
    if (
        select count(*)
        from public.project_suggestions s
        where s.project_id = new.project_id
          and s.user_id = new.user_id
          and s.status = 'approved'
    ) = 3
    and not exists (
        select 1
        from public.project_members m
        where m.project_id = new.project_id
          and m.user_id = new.user_id
          and m.status in ('invited', 'active')
    )
    and (
        select count(*)
        from public.project_members m
        where m.project_id = new.project_id
          and m.status in ('invited', 'active')
    ) < 5
    and not private.rawdea_blocked_between(v_owner, new.user_id) then
        insert into public.notifications (
            recipient_id, actor_id, kind, project_id
        )
        values (v_owner, new.user_id, 'contributor_prompt', new.project_id);
    end if;

    return new;
end;
$$;

create trigger rawdea_prompt_invite
after update of status on public.project_suggestions
for each row
when (new.status = 'approved' and old.status <> 'approved')
execute function private.rawdea_prompt_invite();

-- ==========================================
-- 7. CREDIT
-- ==========================================

create table public.project_stage_credits (
    event_id uuid not null
        references public.project_stage_events(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    primary key (event_id, user_id)
);

create index project_stage_credits_user_idx
on public.project_stage_credits(user_id);

alter table public.project_stage_credits enable row level security;

revoke all on table public.project_stage_credits
from public, anon, authenticated;

grant select on table public.project_stage_credits to authenticated;

create policy "Read credits of visible stage events"
on public.project_stage_credits
for select
to authenticated
using (
    private.rawdea_can_access_user(user_id)
    and private.rawdea_account_active(user_id)
    and exists (
        select 1
        from public.project_stage_events e
        where e.id = event_id
    )
);

-- Everyone but the owner with a visible post in the Project since
-- the given time. Only suggested and contributor posts qualify,
-- because nobody else can write there.
create function private.rawdea_credited_users(
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
      and po.user_id <> p.user_id
      and not po.is_hidden
      and not po.owner_hidden
      and (p_since is null or po.created_at >= p_since)
      and private.rawdea_target_allowed('post', po.id)
      and private.rawdea_account_active(po.user_id)
      and not private.rawdea_blocked_between(po.user_id, p.user_id);
$$;

-- Where the credit window of a move begins. Shipping credits
-- everything; any other move credits the stage being left.
create function private.rawdea_credit_since(
    p_project_id uuid,
    p_to_stage public.project_stage,
    p_excluding uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
    select case when p_to_stage = 'shipped' then null else (
        select max(e.created_at)
        from public.project_stage_events e
        where e.project_id = p_project_id
          and e.id is distinct from p_excluding
    ) end;
$$;

create function private.rawdea_record_credit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_project public.projects;
begin
    insert into public.project_stage_credits (event_id, user_id)
    select new.id, u
    from private.rawdea_credited_users(
        new.project_id,
        private.rawdea_credit_since(new.project_id, new.to_stage, new.id)
    ) as u;

    select * into v_project
    from public.projects p
    where p.id = new.project_id;

    if v_project.is_hidden or v_project.is_archived then
        return new;
    end if;

    -- Credited people hear it once, in place of the stage notice.
    delete from public.notifications n
    using public.project_stage_credits c
    where c.event_id = new.id
      and n.recipient_id = c.user_id
      and n.project_id = new.project_id
      and (
          n.kind = 'credited' and not n.is_read
          or n.kind = 'stage_change' and not n.is_read
      );

    insert into public.notifications (
        recipient_id, actor_id, kind, project_id, stage
    )
    select c.user_id, v_project.user_id, 'credited',
           new.project_id, new.to_stage
    from public.project_stage_credits c
    where c.event_id = new.id;

    return new;
end;
$$;

-- Named to run after on_stage_change_notification.
create trigger rawdea_stage_credit
after insert on public.project_stage_events
for each row
execute function private.rawdea_record_credit();

-- The owner sees who a move would name before making it.
create function public.rawdea_stage_credit_preview(
    p_project_id uuid,
    p_stage public.project_stage
)
returns table (username text)
language sql
stable
security definer
set search_path = ''
as $$
    select pr.username
    from private.rawdea_credited_users(
        p_project_id,
        private.rawdea_credit_since(p_project_id, p_stage, null)
    ) as u
    join public.profiles pr on pr.id = u
    where private.rawdea_project_owner(p_project_id) = (select auth.uid())
    order by pr.username;
$$;

-- Security invoker: only what the viewer may read counts.
create function public.rawdea_contributed_to(p_user_id uuid)
returns table (
    project_id uuid,
    project_name text,
    owner_username text,
    is_contributor boolean,
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
-- 8. EXECUTION PRIVILEGES
-- ==========================================

revoke execute on function
    private.rawdea_end_membership_on_block(),
    private.rawdea_prompt_invite(),
    private.rawdea_credited_users(uuid, timestamptz),
    private.rawdea_credit_since(uuid, public.project_stage, uuid),
    private.rawdea_record_credit()
from public, anon, authenticated;

revoke execute on function
    public.rawdea_invite_contributor(uuid, uuid),
    public.rawdea_respond_to_invite(uuid, boolean),
    public.rawdea_leave_project(uuid),
    public.rawdea_remove_contributor(uuid, uuid, boolean),
    public.rawdea_owner_set_post_hidden(uuid, boolean),
    public.rawdea_owner_set_best_reply(uuid, uuid),
    public.rawdea_hold_contribution(text, uuid, public.post_kind),
    public.rawdea_stage_credit_preview(uuid, public.project_stage),
    public.rawdea_contributed_to(uuid)
from public, anon, authenticated;

grant execute on function
    public.rawdea_invite_contributor(uuid, uuid),
    public.rawdea_respond_to_invite(uuid, boolean),
    public.rawdea_leave_project(uuid),
    public.rawdea_remove_contributor(uuid, uuid, boolean),
    public.rawdea_owner_set_post_hidden(uuid, boolean),
    public.rawdea_owner_set_best_reply(uuid, uuid),
    public.rawdea_hold_contribution(text, uuid, public.post_kind),
    public.rawdea_stage_credit_preview(uuid, public.project_stage),
    public.rawdea_contributed_to(uuid)
to authenticated;

notify pgrst, 'reload schema';
