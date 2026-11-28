-- RAWDEA Project collaborators, part 1: followers can suggest an
-- update, and the owner approves or declines it.

-- ==========================================
-- 1. A POST MAY LIVE IN SOMEONE ELSE'S PROJECT
-- ==========================================

alter table public.projects
add column suggestions_enabled boolean not null default true;

-- The name is kept because queries embed the Project by it. Who
-- may write into a Project is now decided by the trigger below.
alter table public.posts
drop constraint posts_project_owner_fk;

alter table public.posts
add constraint posts_project_owner_fk
foreign key (project_id)
references public.projects(id)
deferrable initially deferred;

create table public.project_suggestions (
    id uuid primary key default gen_random_uuid(),

    project_id uuid not null
        references public.projects(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    kind public.post_kind not null default 'note'
        check (kind <> 'decision'),

    content text not null
        check (
            char_length(content) between 1 and 500
            and length(btrim(content, E' \t\r\n')) > 0
        ),

    status text not null default 'waiting'
        check (status in (
            'waiting', 'approved', 'declined', 'withdrawn', 'closed'
        )),

    post_id uuid
        references public.posts(id)
        on delete set null,

    created_at timestamptz not null default now(),
    decided_at timestamptz
);

create index project_suggestions_project_idx
on public.project_suggestions(project_id, status, created_at desc);

create index project_suggestions_user_idx
on public.project_suggestions(user_id, created_at desc);

create index project_suggestions_post_idx
on public.project_suggestions(post_id)
where post_id is not null;

-- Marks a post that began as an approved suggestion.
alter table public.posts
add column suggestion_id uuid
    references public.project_suggestions(id)
    on delete set null;

create index posts_suggestion_idx
on public.posts(suggestion_id)
where suggestion_id is not null;

-- ==========================================
-- 2. WHO MAY WRITE INTO A PROJECT
-- ==========================================

create function private.rawdea_project_owner(p_project_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select p.user_id
    from public.projects p
    where p.id = p_project_id;
$$;

create function private.rawdea_blocked_between(p_one uuid, p_two uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.user_blocks b
        where (b.blocker_id = p_one and b.blocked_id = p_two)
           or (b.blocker_id = p_two and b.blocked_id = p_one)
    );
$$;

-- Replaced when contributors arrive.
create function private.rawdea_member_can_post(
    p_user_id uuid,
    p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select false;
$$;

-- Security invoker: current_user tells client writes apart
-- from trusted ones. Runs after the default Project trigger.
create function private.rawdea_guard_post_project()
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
        elsif v_moved then
            new.suggestion_id := null;
        else
            new.suggestion_id := old.suggestion_id;
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

create trigger rawdea_project_access_posts
before insert or update
on public.posts
for each row
execute function private.rawdea_guard_post_project();

-- Deleting a Project (account deletion) must not delete other
-- people's writing, so their posts return to their own General.
create function private.rawdea_release_guest_posts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- A post that no longer passes the filter cannot be moved.
    delete from public.posts p
    where p.project_id = old.id
      and p.user_id <> old.user_id
      and private.rawdea_filter_category('post', p.content) is not null;

    update public.posts p
    set project_id = private.rawdea_default_project(p.user_id),
        suggestion_id = null
    where p.project_id = old.id
      and p.user_id <> old.user_id;

    return old;
end;
$$;

create trigger rawdea_release_guest_posts
before delete on public.projects
for each row
execute function private.rawdea_release_guest_posts();

-- The Project owner also reads other people's posts while the
-- Project is hidden or archived.
drop policy "View public or owned posts" on public.posts;

create policy "View public or owned posts"
on public.posts
for select
to anon, authenticated
using (
    user_id = (select auth.uid())
    or (
        is_hidden = false
        and exists (
            select 1
            from public.projects p
            where p.id = posts.project_id
              and (
                  (p.is_hidden = false and p.is_archived = false)
                  or p.user_id = (select auth.uid())
              )
        )
    )
);

-- ==========================================
-- 3. SUGGESTION ACCESS
-- ==========================================

alter table public.project_suggestions enable row level security;

revoke all on table public.project_suggestions
from public, anon, authenticated;

-- Read only. Every change goes through the functions below.
grant select on table public.project_suggestions to authenticated;

create policy "Read own or received suggestions"
on public.project_suggestions
for select
to authenticated
using (
    user_id = (select auth.uid())
    or (
        private.rawdea_project_owner(project_id) = (select auth.uid())
        and private.rawdea_can_access_user(user_id)
        and private.rawdea_account_active(user_id)
    )
);

grant execute on function private.rawdea_project_owner(uuid)
to authenticated;
grant execute on function private.rawdea_member_can_post(uuid, uuid)
to authenticated;

revoke execute on function private.rawdea_project_owner(uuid)
from public, anon;
revoke execute on function private.rawdea_member_can_post(uuid, uuid)
from public, anon;
revoke execute on function private.rawdea_blocked_between(uuid, uuid)
from public, anon, authenticated;
revoke execute on function
    private.rawdea_release_guest_posts(),
    private.rawdea_guard_post_project()
from public, anon, authenticated;

-- ==========================================
-- 4. NOTIFICATIONS
-- ==========================================

alter table public.notifications
add column item_count integer;

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
    or (
        kind = 'suggestion_declined'
        and project_id is not null
        and post_id is null
        and comment_id is null
        and stage is null
    )
);

alter table public.notification_preferences
add column suggestions boolean not null default true;

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

    -- No row means everything is on.
    if not found then
        return new;
    end if;

    if (new.kind = 'post_like' and not v_preferences.likes)
       or (new.kind = 'stage_change' and not v_preferences.stage_changes)
       or (
           new.kind in (
               'suggestions_waiting',
               'suggestion_approved',
               'suggestion_declined'
           )
           and not v_preferences.suggestions
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

-- One row per Project: "2 new suggestions".
create function private.rawdea_refresh_suggestion_notice(
    p_project_id uuid,
    p_is_new boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := private.rawdea_project_owner(p_project_id);
    v_count integer;
    v_actor uuid;
begin
    select count(*), (array_agg(s.user_id order by s.created_at desc, s.id))[1]
    into v_count, v_actor
    from public.project_suggestions s
    where s.project_id = p_project_id
      and s.status = 'waiting'
      and s.created_at > now() - interval '14 days';

    if v_count = 0 then
        delete from public.notifications
        where kind = 'suggestions_waiting'
          and project_id = p_project_id;
    elsif p_is_new then
        delete from public.notifications
        where kind = 'suggestions_waiting'
          and project_id = p_project_id;

        insert into public.notifications (
            recipient_id, actor_id, kind, project_id, item_count
        )
        values (
            v_owner, v_actor, 'suggestions_waiting', p_project_id, v_count
        );
    else
        update public.notifications
        set item_count = v_count,
            actor_id = v_actor
        where kind = 'suggestions_waiting'
          and project_id = p_project_id;
    end if;
end;
$$;

-- ==========================================
-- 5. CLOSING
-- ==========================================

-- No scheduler: waiting suggestions older than 14 days are
-- closed the next time anyone touches them.
create function private.rawdea_close_suggestions(
    p_project_id uuid,
    p_only_expired boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.project_suggestions
    set status = 'closed',
        decided_at = now()
    where project_id = p_project_id
      and status = 'waiting'
      and (
          not p_only_expired
          or created_at <= now() - interval '14 days'
      );

    if found then
        perform private.rawdea_refresh_suggestion_notice(
            p_project_id, false
        );
    end if;
end;
$$;

-- Called before listing, so stored states match what is shown.
create function public.rawdea_close_expired_suggestions()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user uuid := (select auth.uid());
    v_project uuid;
begin
    for v_project in
        select distinct s.project_id
        from public.project_suggestions s
        join public.projects p on p.id = s.project_id
        where s.status = 'waiting'
          and s.created_at <= now() - interval '14 days'
          and (s.user_id = v_user or p.user_id = v_user)
    loop
        perform private.rawdea_close_suggestions(v_project, true);
    end loop;
end;
$$;

-- Shipping, hiding or archiving closes what is waiting.
create function private.rawdea_close_on_project_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if (new.stage = 'shipped' and old.stage <> 'shipped')
       or (new.is_hidden and not old.is_hidden)
       or (new.is_archived and not old.is_archived) then
        perform private.rawdea_close_suggestions(new.id, false);
    end if;

    return new;
end;
$$;

create trigger rawdea_close_suggestions_on_project
after update of stage, is_hidden, is_archived
on public.projects
for each row
execute function private.rawdea_close_on_project_change();

-- A block in either direction removes waiting suggestions.
create function private.rawdea_close_suggestions_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_project uuid;
begin
    for v_project in
        update public.project_suggestions s
        set status = 'closed',
            decided_at = now()
        from public.projects p
        where p.id = s.project_id
          and s.status = 'waiting'
          and (
              (s.user_id = new.blocker_id and p.user_id = new.blocked_id)
              or (s.user_id = new.blocked_id and p.user_id = new.blocker_id)
          )
        returning s.project_id
    loop
        perform private.rawdea_refresh_suggestion_notice(v_project, false);
    end loop;

    return new;
end;
$$;

create trigger rawdea_close_suggestions_on_block
after insert on public.user_blocks
for each row
execute function private.rawdea_close_suggestions_on_block();

-- ==========================================
-- 6. SUGGEST, WITHDRAW, DECIDE
-- ==========================================

create function public.rawdea_suggest(
    p_project_id uuid,
    p_kind public.post_kind,
    p_content text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user uuid := (select auth.uid());
    v_content text := btrim(coalesce(p_content, ''), E' \t\r\n');
    v_project public.projects;
    v_reason text;
    v_id uuid;
begin
    select * into v_project
    from public.projects p
    where p.id = p_project_id
    for share;

    if v_user is null
       or not private.rawdea_account_active(v_user)
       or v_project.id is null
       or v_project.user_id = v_user
       or v_project.is_default
       or v_project.is_hidden
       or v_project.is_archived
       or v_project.stage = 'shipped'
       or not v_project.suggestions_enabled
       or not private.rawdea_account_active(v_project.user_id)
       or private.rawdea_blocked_between(v_user, v_project.user_id)
       or not exists (
           select 1
           from public.project_follows f
           where f.follower_id = v_user
             and f.project_id = p_project_id
       ) then
        raise exception using
            errcode = '42501',
            message = 'RAWDEA_SUGGEST_UNAVAILABLE';
    end if;

    if p_kind is null or p_kind = 'decision' then
        raise exception 'Suggest a note, a question or progress';
    end if;

    if char_length(v_content) not between 1 and 500 then
        raise exception 'Suggestions are 1 to 500 characters';
    end if;

    -- One account's sends wait their turn, so the limit holds.
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('post:' || v_user::text, 13506)
    );

    perform private.rawdea_close_suggestions(p_project_id, true);

    if (
        select count(*)
        from public.project_suggestions s
        where s.project_id = p_project_id
          and s.user_id = v_user
          and s.status = 'waiting'
    ) >= 3 then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_SUGGESTION_LIMIT';
    end if;

    perform private.rawdea_assert_publication('post', v_content);
    perform private.rawdea_count_post(v_user);

    -- Nothing a moderator would need to check can be suggested.
    v_reason := private.rawdea_hold_reason(v_user, v_content);

    if v_reason is not null then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_SUGGESTION_NEEDS_EDIT:' || v_reason;
    end if;

    insert into public.project_suggestions (
        project_id, user_id, kind, content
    )
    values (p_project_id, v_user, p_kind, v_content)
    returning id into v_id;

    perform private.rawdea_refresh_suggestion_notice(p_project_id, true);

    return v_id;
end;
$$;

create function public.rawdea_withdraw_suggestion(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_project uuid;
begin
    update public.project_suggestions
    set status = 'withdrawn',
        decided_at = now()
    where id = p_id
      and user_id = (select auth.uid())
      and status = 'waiting'
    returning project_id into v_project;

    if v_project is null then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_SUGGESTION_CHANGED';
    end if;

    perform private.rawdea_refresh_suggestion_notice(v_project, false);
end;
$$;

-- Returns the new post's id when approved.
create function public.rawdea_decide_suggestion(
    p_id uuid,
    p_approve boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid := (select auth.uid());
    v_suggestion public.project_suggestions;
    v_project public.projects;
    v_claims text;
    v_sub text;
    v_post uuid;
begin
    select * into v_suggestion
    from public.project_suggestions s
    where s.id = p_id
    for update;

    select * into v_project
    from public.projects p
    where p.id = v_suggestion.project_id
    for share;

    if v_owner is null
       or p_approve is null
       or v_project.user_id is distinct from v_owner
       or not private.rawdea_account_active(v_owner) then
        raise exception 'That suggestion is not available'
            using errcode = '42501';
    end if;

    if v_suggestion.status <> 'waiting'
       or v_suggestion.created_at <= now() - interval '14 days' then
        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_SUGGESTION_CHANGED';
    end if;

    if p_approve then
        if v_project.is_hidden
           or v_project.is_archived
           or v_project.stage = 'shipped'
           or not private.rawdea_account_active(v_suggestion.user_id)
           or private.rawdea_blocked_between(
               v_owner, v_suggestion.user_id
           ) then
            raise exception using
                errcode = 'P0001',
                message = 'RAWDEA_SUGGESTION_CHANGED';
        end if;

        -- The text was checked when it was sent. As a trusted
        -- write it is not counted or held a second time.
        v_claims := current_setting('request.jwt.claims', true);
        v_sub := current_setting('request.jwt.claim.sub', true);
        perform set_config('request.jwt.claims', '', true);
        perform set_config('request.jwt.claim.sub', '', true);

        insert into public.posts (
            user_id, content, project_id, kind, suggestion_id
        )
        values (
            v_suggestion.user_id, v_suggestion.content,
            v_suggestion.project_id, v_suggestion.kind, p_id
        )
        returning id into v_post;

        perform set_config(
            'request.jwt.claims', coalesce(v_claims, ''), true
        );
        perform set_config(
            'request.jwt.claim.sub', coalesce(v_sub, ''), true
        );
    end if;

    update public.project_suggestions
    set status = case when p_approve then 'approved' else 'declined' end,
        post_id = v_post,
        decided_at = now()
    where id = p_id;

    perform private.rawdea_refresh_suggestion_notice(
        v_suggestion.project_id, false
    );

    if not private.rawdea_blocked_between(v_owner, v_suggestion.user_id) then
        insert into public.notifications (
            recipient_id, actor_id, kind, project_id, post_id
        )
        values (
            v_suggestion.user_id, v_owner,
            case when p_approve
                then 'suggestion_approved'
                else 'suggestion_declined'
            end,
            v_suggestion.project_id, v_post
        );
    end if;

    return v_post;
end;
$$;

-- ==========================================
-- 7. EXECUTION PRIVILEGES
-- ==========================================

revoke execute on function
    private.rawdea_refresh_suggestion_notice(uuid, boolean),
    private.rawdea_close_suggestions(uuid, boolean),
    private.rawdea_close_on_project_change(),
    private.rawdea_close_suggestions_on_block()
from public, anon, authenticated;

revoke execute on function
    public.rawdea_close_expired_suggestions(),
    public.rawdea_suggest(uuid, public.post_kind, text),
    public.rawdea_withdraw_suggestion(uuid),
    public.rawdea_decide_suggestion(uuid, boolean)
from public, anon, authenticated;

grant execute on function
    public.rawdea_close_expired_suggestions(),
    public.rawdea_suggest(uuid, public.post_kind, text),
    public.rawdea_withdraw_suggestion(uuid),
    public.rawdea_decide_suggestion(uuid, boolean)
to authenticated;

notify pgrst, 'reload schema';
