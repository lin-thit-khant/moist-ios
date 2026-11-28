-- RAWDEA hold for review: a "hold" outcome between allow and
-- block for posts, and a rate limit for new accounts.
--
-- A held post never enters public.posts. It waits in a private
-- table until a moderator approves it, so existing feeds, counts,
-- notifications and RLS need no change.

-- ==========================================
-- 1. HOLD RULES
-- ==========================================

alter table private.rawdea_content_filter_rules
add column action text not null default 'block';

alter table private.rawdea_content_filter_rules
drop constraint content_filter_category_check;

alter table private.rawdea_content_filter_rules
add constraint content_filter_category_check
check (
    (
        action = 'block'
        and category in (
            'targeted_threat',
            'self_harm_encouragement',
            'credential_scam'
        )
    )
    or (action = 'hold' and category = 'possible_insult')
);

-- Matched against the same normalized text as the block rules.
-- Deliberately narrow: a hold costs a person a wait.
insert into private.rawdea_content_filter_rules (
    target_kind, category, pattern, action
)
values
(
    'post', 'possible_insult',
    '(^| )(idiots?|morons?|losers?|scumbags?)( |$)',
    'hold'
),
(
    'post', 'possible_insult',
    '(^| )(you are|you re|youre|u r|they are|they re) (all )?(so |such )?((a|an) )?(stupid|dumb|garbage|trash|worthless|pathetic|useless)( |$)',
    'hold'
),
(
    'post', 'possible_insult',
    '(^| )(garbage|trash|stupid|dumb|worthless|pathetic) .*(and )?so (are|is) (the )?(people|anyone|everyone|you)( |$)',
    'hold'
);

-- Only block rules may block.
create or replace function
private.rawdea_filter_category(
    p_kind text,
    p_content text
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_normalized text;
    v_category text;
    v_url_count integer;
begin
    if p_kind not in (
        'post', 'comment', 'profile', 'project'
    ) or p_kind is null then
        raise exception
            'Invalid filtering target';
    end if;

    v_normalized := pg_catalog.btrim(
        pg_catalog.lower(
            pg_catalog.regexp_replace(
                coalesce(p_content, ''),
                '[[:space:][:punct:]]+',
                ' ',
                'g'
            )
        )
    );

    if char_length(v_normalized) > 2000 then
        return 'invalid_length';
    end if;

    select r.category
    into v_category
    from private.rawdea_content_filter_rules r
    where r.is_active = true
      and r.action = 'block'
      and (
          r.target_kind = 'all'
          or r.target_kind = p_kind
      )
      and v_normalized ~ r.pattern
    order by r.id asc
    limit 1;

    if v_category is not null then
        return v_category;
    end if;

    if p_kind in ('post', 'comment') then

        select count(*)
        into v_url_count
        from pg_catalog.regexp_matches(
            coalesce(p_content, ''),
            '(https?://|www\.)[[:alnum:]]',
            'gi'
        ) as matches;

        if v_url_count >= 4 then
            return 'excessive_links';
        end if;

    end if;

    return null;
end;
$$;

-- ==========================================
-- 2. PRIVATE STATE
-- ==========================================

-- One row per post a client sent, so that deleting
-- a post does not reset the hourly limit.
create table private.rawdea_post_log (
    id bigint generated always as identity primary key,
    user_id uuid not null
        references auth.users(id) on delete cascade,
    created_at timestamptz not null default clock_timestamp()
);

create index rawdea_post_log_user_idx
on private.rawdea_post_log (user_id, created_at);

create table private.rawdea_held_posts (

    -- Becomes the post's id if approved.
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id) on delete cascade,

    project_id uuid
        references public.projects(id) on delete set null,

    content text not null
        check (
            char_length(content) between 1 and 500
            and length(trim(content)) > 0
        ),

    kind public.post_kind not null default 'note',

    reason text not null
        check (reason in (
            'possible_insult', 'several_links', 'new_account_link'
        )),

    status text not null default 'pending'
        check (status in ('pending', 'approved', 'removed')),

    created_at timestamptz not null default clock_timestamp(),

    decided_by uuid,
    decided_at timestamptz,
    appealed_at timestamptz,
    seen_at timestamptz,
    published_at timestamptz
);

create index rawdea_held_posts_queue_idx
on private.rawdea_held_posts (status, created_at, id);

create index rawdea_held_posts_author_idx
on private.rawdea_held_posts (user_id, created_at desc);

-- Audit trail of every decision and appeal.
create table private.rawdea_held_post_events (
    id bigint generated always as identity primary key,
    held_id uuid not null
        references private.rawdea_held_posts(id) on delete cascade,
    actor_id uuid not null,
    action text not null
        check (action in ('approve', 'remove', 'appeal')),
    created_at timestamptz not null default clock_timestamp()
);

alter table private.rawdea_post_log enable row level security;
alter table private.rawdea_held_posts enable row level security;
alter table private.rawdea_held_post_events enable row level security;

-- No client policies. All access goes through the functions below.
revoke all on
    private.rawdea_post_log,
    private.rawdea_held_posts,
    private.rawdea_held_post_events
from public, anon, authenticated;

-- ==========================================
-- 3. CHECKS
-- ==========================================

-- Account age comes from auth.users, which clients cannot edit.
create function private.rawdea_is_new_account(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from auth.users u
        where u.id = p_user_id
          and u.created_at > now() - interval '7 days'
    );
$$;

-- Why a post needs a check first, or null.
create function private.rawdea_hold_reason(
    p_user_id uuid,
    p_content text
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_normalized text;
    v_links integer;
begin
    v_normalized := pg_catalog.btrim(
        pg_catalog.lower(
            pg_catalog.regexp_replace(
                coalesce(p_content, ''),
                '[[:space:][:punct:]]+',
                ' ',
                'g'
            )
        )
    );

    if exists (
        select 1
        from private.rawdea_content_filter_rules r
        where r.is_active
          and r.action = 'hold'
          and r.target_kind in ('all', 'post')
          and v_normalized ~ r.pattern
    ) then
        return 'possible_insult';
    end if;

    -- Each address counts once, with or without http or www.
    select count(*)
    into v_links
    from pg_catalog.regexp_matches(
        coalesce(p_content, ''),
        '(?:https?://|www\.)[^[:space:]]+|\m[[:alnum:]-]+(?:\.[[:alnum:]-]+)*\.(?:com|net|org|io|app|dev|co|me|ly|xyz|info)\M(?:/[^[:space:]]*)?',
        'gi'
    ) as matches;

    if v_links >= 2 then
        return 'several_links';
    end if;

    if v_links = 1 and private.rawdea_is_new_account(p_user_id) then
        return 'new_account_link';
    end if;

    return null;
end;
$$;

-- New accounts: 3 posts in any hour, held ones included.
create function private.rawdea_count_post(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Concurrent posts from one account wait their turn.
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            'post:' || p_user_id::text,
            13506
        )
    );

    if private.rawdea_is_new_account(p_user_id)
       and (
           select count(*)
           from private.rawdea_post_log l
           where l.user_id = p_user_id
             and l.created_at > clock_timestamp() - interval '1 hour'
       ) >= 3 then

        raise exception using
            errcode = 'P0001',
            message = 'RAWDEA_RATE_LIMIT';
    end if;

    insert into private.rawdea_post_log (user_id)
    values (p_user_id);
end;
$$;

-- ==========================================
-- 4. POSTS TRIGGER
-- ==========================================

-- Order: block, then the hourly limit, then hold.
create or replace function
private.rawdea_filter_post_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_reason text;
begin

    if tg_op = 'INSERT' then

        perform private.rawdea_assert_publication(
            'post',
            new.content
        );

        -- Trusted server writes carry no user.
        if (select auth.uid()) is null then
            return new;
        end if;

        -- A moderator is publishing exactly what was held.
        if exists (
            select 1
            from private.rawdea_held_posts h
            where h.id = new.id
              and h.user_id = new.user_id
              and h.content = new.content
              and h.status = 'approved'
              and h.published_at is null
        ) then
            return new;
        end if;

        perform private.rawdea_count_post(new.user_id);

        v_reason := private.rawdea_hold_reason(
            new.user_id,
            new.content
        );

        if v_reason is not null then
            raise exception using
                errcode = 'P0001',
                message = 'RAWDEA_FILTER_HELD:' || v_reason;
        end if;

        return new;
    end if;

    if new.content is distinct from old.content

       or (
           old.is_hidden = true
           and new.is_hidden = false
       )

       or new.project_id
          is distinct from old.project_id then

        perform private.rawdea_assert_publication(
            'post',
            new.content
        );

    end if;

    -- Editing must not be a way around the check.
    if new.content is distinct from old.content
       and (select auth.uid()) is not null then

        v_reason := private.rawdea_hold_reason(
            new.user_id,
            new.content
        );

        if v_reason is not null then
            raise exception using
                errcode = 'P0001',
                message = 'RAWDEA_FILTER_HELD_EDIT:' || v_reason;
        end if;

    end if;

    return new;

end;
$$;

-- ==========================================
-- 5. AUTHOR
-- ==========================================

-- Called after the posts trigger refused with RAWDEA_FILTER_HELD.
-- Repeats the posting checks, because this bypasses posts RLS.
create function public.rawdea_hold_post(
    p_content text,
    p_project_id uuid default null,
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
       or not private.rawdea_account_active(v_user) then
        raise exception 'Posting is not available'
            using errcode = '42501';
    end if;

    if p_project_id is not null
       and not exists (
           select 1
           from public.projects p
           where p.id = p_project_id
             and p.user_id = v_user
       ) then
        raise exception 'That Project is not available'
            using errcode = '42501';
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

-- Decisions on the caller's own held posts. Never names the moderator.
create function public.rawdea_my_held_posts()
returns table (
    id uuid,
    content text,
    reason text,
    status text,
    appealed boolean,
    seen boolean,
    updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        h.id,
        h.content,
        h.reason,
        h.status,
        h.appealed_at is not null,
        h.status = 'pending' or h.seen_at is not null,
        greatest(h.decided_at, h.appealed_at)
    from private.rawdea_held_posts h
    where h.user_id = (select auth.uid())
      and (h.status <> 'pending' or h.appealed_at is not null)
      -- Old results leave Activity.
      and greatest(h.decided_at, h.appealed_at)
          > now() - interval '30 days'
    order by 7 desc, 1
    limit 50;
$$;

create function public.rawdea_mark_held_seen()
returns void
language sql
security definer
set search_path = ''
as $$
    update private.rawdea_held_posts
    set seen_at = clock_timestamp()
    where user_id = (select auth.uid())
      and status <> 'pending'
      and seen_at is null;
$$;

-- One second look per removed post. Allowed while suspended,
-- like other appeals.
create function public.rawdea_appeal_held_post(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user uuid := (select auth.uid());
begin
    update private.rawdea_held_posts
    set status = 'pending',
        appealed_at = clock_timestamp()
    where id = p_id
      and user_id = v_user
      and status = 'removed'
      and appealed_at is null;

    if not found then
        raise exception 'A second look is not available';
    end if;

    insert into private.rawdea_held_post_events (
        held_id, actor_id, action
    )
    values (p_id, v_user, 'appeal');
end;
$$;

-- ==========================================
-- 6. MODERATOR
-- ==========================================

create function public.rawdea_moderation_held_queue()
returns table (
    id uuid,
    content text,
    reason text,
    username text,
    account_created_at timestamptz,
    appealed boolean,
    created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if not public.rawdea_is_moderator() then
        raise exception 'Moderator access required'
            using errcode = '42501';
    end if;

    return query
    select
        h.id,
        h.content,
        h.reason,
        p.username,
        u.created_at,
        h.appealed_at is not null,
        h.created_at
    from private.rawdea_held_posts h
    join public.profiles p on p.id = h.user_id
    join auth.users u on u.id = h.user_id
    where h.status = 'pending'
    order by h.created_at, h.id
    limit 100;
end;
$$;

create function public.rawdea_moderation_decide_held(
    p_id uuid,
    p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_moderator uuid := (select auth.uid());
    v_held private.rawdea_held_posts%rowtype;
begin
    if not public.rawdea_is_moderator() then
        raise exception 'Moderator access required'
            using errcode = '42501';
    end if;

    if p_approve is null then
        raise exception 'Invalid decision';
    end if;

    select *
    into v_held
    from private.rawdea_held_posts h
    where h.id = p_id
    for update;

    if not found or v_held.status <> 'pending' then
        raise exception 'This post has already been decided';
    end if;

    update private.rawdea_held_posts
    set status = case when p_approve then 'approved' else 'removed' end,
        decided_by = v_moderator,
        decided_at = clock_timestamp(),
        seen_at = null
    where id = p_id;

    if p_approve then
        -- A missing Project falls back to the author's default one.
        insert into public.posts (
            id, user_id, content, project_id, kind
        )
        values (
            v_held.id, v_held.user_id, v_held.content,
            v_held.project_id, v_held.kind
        );

        update private.rawdea_held_posts
        set published_at = clock_timestamp()
        where id = p_id;
    end if;

    insert into private.rawdea_held_post_events (
        held_id, actor_id, action
    )
    values (
        p_id, v_moderator,
        case when p_approve then 'approve' else 'remove' end
    );
end;
$$;

-- ==========================================
-- 7. EXECUTION PRIVILEGES
-- ==========================================

revoke execute on function private.rawdea_is_new_account(uuid)
from public, anon, authenticated;
revoke execute on function private.rawdea_hold_reason(uuid, text)
from public, anon, authenticated;
revoke execute on function private.rawdea_count_post(uuid)
from public, anon, authenticated;

revoke execute on function
    public.rawdea_hold_post(text, uuid, public.post_kind),
    public.rawdea_my_held_posts(),
    public.rawdea_mark_held_seen(),
    public.rawdea_appeal_held_post(uuid),
    public.rawdea_moderation_held_queue(),
    public.rawdea_moderation_decide_held(uuid, boolean)
from public, anon, authenticated;

grant execute on function
    public.rawdea_hold_post(text, uuid, public.post_kind),
    public.rawdea_my_held_posts(),
    public.rawdea_mark_held_seen(),
    public.rawdea_appeal_held_post(uuid),
    public.rawdea_moderation_held_queue(),
    public.rawdea_moderation_decide_held(uuid, boolean)
to authenticated;

notify pgrst, 'reload schema';
