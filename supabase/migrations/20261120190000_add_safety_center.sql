
-- ==============================================
-- RAWDEA MILESTONE 13 - BATCH 5
-- Safety Center, Appeals, and Account Deletion
-- ==============================================

-- ==============================================
-- 1. PRIVATE SAFETY REQUESTS
-- ==============================================

create table private.rawdea_safety_requests (

    id uuid primary key default gen_random_uuid(),

    requester_id uuid not null
        references auth.users(id)
        on delete cascade,

    kind text not null
        check (kind in ('support', 'appeal')),

    message text not null
        check (
            char_length(btrim(message))
            between 20 and 2000
        ),

    status text not null default 'open'
        check (status in ('open', 'resolved')),

    response text,
    responded_by uuid,
    responded_at timestamptz,

    created_at timestamptz not null
        default clock_timestamp(),

    constraint safety_response_consistency
        check (
            (
                status = 'open'
                and response is null
                and responded_by is null
                and responded_at is null
            )
            or
            (
                status = 'resolved'
                and response is not null
                and char_length(btrim(response))
                    between 10 and 2000
                and responded_by is not null
                and responded_at is not null
            )
        )
);

create index rawdea_safety_open_idx
on private.rawdea_safety_requests (
    status, created_at, id
);

create index rawdea_safety_requester_idx
on private.rawdea_safety_requests (
    requester_id, created_at desc
);

alter table private.rawdea_safety_requests
enable row level security;

revoke all on private.rawdea_safety_requests
from public, anon, authenticated;

-- No direct client access.
-- All access uses authorized RPCs.

-- ==============================================
-- 2. SAFETY RESPONSE AUDIT
-- ==============================================

create table private.rawdea_safety_request_events (

    id uuid primary key default gen_random_uuid(),

    request_id uuid not null
        references private.rawdea_safety_requests(id)
        on delete cascade,

    moderator_id uuid not null,

    action text not null
        check (action = 'resolve'),

    response text not null
        check (
            char_length(btrim(response))
            between 10 and 2000
        ),

    created_at timestamptz not null
        default clock_timestamp()
);

alter table private.rawdea_safety_request_events
enable row level security;

revoke all on private.rawdea_safety_request_events
from public, anon, authenticated;

-- ==============================================
-- 3. SUBMIT SUPPORT OR APPEAL
-- ==============================================

create or replace function
public.rawdea_submit_safety_request(
    p_kind text,
    p_message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare

    v_user uuid := (select auth.uid());
    v_message text;
    v_id uuid;
    v_count integer;

begin

    if v_user is null then
        raise exception 'Authentication required'
            using errcode = '42501';
    end if;

    if p_kind is null
       or p_kind not in ('support', 'appeal') then

        raise exception 'Invalid request type';
    end if;

    v_message := btrim(coalesce(p_message, ''));

    if char_length(v_message) not between 20 and 2000 then

        raise exception
            'Please enter 20 to 2000 characters';
    end if;

    -- Serialize concurrent submissions
    -- from the same account.

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            'safety:' || v_user::text,
            13505
        )
    );

    -- Three requests per rolling 24 hours.

    select count(*)
    into v_count
    from private.rawdea_safety_requests r
    where r.requester_id = v_user
      and r.created_at >=
          now() - interval '24 hours';

    if v_count >= 3 then
        raise exception
            'Support request limit reached. Try again later';
    end if;

    -- Important:
    -- Do NOT check rawdea_account_active here.
    -- Suspended accounts must be able to appeal.

    insert into private.rawdea_safety_requests (
        requester_id,
        kind,
        message
    )
    values (
        v_user,
        p_kind,
        v_message
    )
    returning id into v_id;

    return v_id;

end;
$$;

-- ==============================================
-- 4. READ OWN SUPPORT REQUESTS
-- ==============================================

create or replace function
public.rawdea_my_safety_requests()
returns table (

    id uuid,
    kind text,
    message text,
    status text,
    response text,
    created_at timestamptz,
    responded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_user uuid := (select auth.uid());
begin

    if v_user is null then
        raise exception 'Authentication required'
            using errcode = '42501';
    end if;

    return query

    select
        r.id,
        r.kind,
        r.message,
        r.status,
        r.response,
        r.created_at,
        r.responded_at

    from private.rawdea_safety_requests r

    where r.requester_id = v_user

    order by
        r.created_at desc,
        r.id desc

    limit 50;

end;
$$;

-- ==============================================
-- 5. MODERATOR SAFETY INBOX
-- ==============================================

create or replace function
public.rawdea_moderation_safety_inbox(
    p_status text default 'open',
    p_limit integer default 100
)
returns table (

    id uuid,
    requester_id uuid,
    kind text,
    message text,
    status text,
    response text,
    created_at timestamptz,
    responded_at timestamptz
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

    if p_status is null
       or p_status not in ('open', 'resolved') then

        raise exception 'Invalid inbox status';
    end if;

    return query

    select
        r.id,
        r.requester_id,
        r.kind,
        r.message,
        r.status,
        r.response,
        r.created_at,
        r.responded_at

    from private.rawdea_safety_requests r

    where r.status = p_status

    order by
        r.created_at asc,
        r.id asc

    limit least(
        greatest(coalesce(p_limit, 100), 1),
        100
    );

end;
$$;

-- ==============================================
-- 6. MODERATOR RESPONSE
-- ==============================================

create or replace function
public.rawdea_moderation_reply_safety(
    p_request_id uuid,
    p_response text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare

    v_moderator uuid := (select auth.uid());
    v_request private.rawdea_safety_requests%rowtype;
    v_response text;

begin

    if not public.rawdea_is_moderator() then
        raise exception 'Moderator access required'
            using errcode = '42501';
    end if;

    v_response := btrim(coalesce(p_response, ''));

    if char_length(v_response) not between 10 and 2000 then
        raise exception
            'A response of 10 to 2000 characters is required';
    end if;

    -- Prevent conflicting review decisions.

    select *
    into v_request
    from private.rawdea_safety_requests r
    where r.id = p_request_id
    for update;

    if not found then
        raise exception 'Support request not found';
    end if;

    if v_request.status <> 'open' then
        raise exception
            'This request has already been resolved';
    end if;

    update private.rawdea_safety_requests
    set
        status = 'resolved',
        response = v_response,
        responded_by = v_moderator,
        responded_at = clock_timestamp()
    where id = p_request_id;

    insert into private.rawdea_safety_request_events (
        request_id,
        moderator_id,
        action,
        response
    )
    values (
        p_request_id,
        v_moderator,
        'resolve',
        v_response
    );

end;
$$;

-- ==============================================
-- 7. SELF-SERVICE ACCOUNT DELETION
-- ==============================================

create or replace function
public.rawdea_delete_my_account(
    p_confirmation text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare

    v_user uuid := (select auth.uid());
    v_deleted integer;

begin

    if v_user is null then
        raise exception 'Authentication required'
            using errcode = '42501';
    end if;

    if p_confirmation is distinct from 'DELETE' then
        raise exception 'Confirmation is required';
    end if;

    -- Prevent accidental deletion of the
    -- sole active moderation administrator.
    -- Disable their moderator membership
    -- through trusted SQL first.

    if public.rawdea_is_moderator() then
        raise exception
            'Remove moderator access before deleting this account';
    end if;

    -- Only delete the authenticated user.
    -- Auth and profile foreign-key cascades
    -- remove associated account content.
    --
    -- Existing moderation report evidence
    -- and audit records may be retained
    -- under the app's documented policy.

    delete from auth.users
    where id = v_user;

    get diagnostics v_deleted = row_count;

    if v_deleted <> 1 then
        raise exception 'Account deletion failed';
    end if;

end;
$$;

-- ==============================================
-- 8. RPC EXECUTION PRIVILEGES
-- ==============================================

revoke execute on function
public.rawdea_submit_safety_request(text,text)
from public, anon, authenticated;

revoke execute on function
public.rawdea_my_safety_requests()
from public, anon, authenticated;

revoke execute on function
public.rawdea_moderation_safety_inbox(text,integer)
from public, anon, authenticated;

revoke execute on function
public.rawdea_moderation_reply_safety(uuid,text)
from public, anon, authenticated;

revoke execute on function
public.rawdea_delete_my_account(text)
from public, anon, authenticated;

grant execute on function
public.rawdea_submit_safety_request(text,text)
to authenticated;

grant execute on function
public.rawdea_my_safety_requests()
to authenticated;

grant execute on function
public.rawdea_moderation_safety_inbox(text,integer)
to authenticated;

grant execute on function
public.rawdea_moderation_reply_safety(uuid,text)
to authenticated;

grant execute on function
public.rawdea_delete_my_account(text)
to authenticated;

notify pgrst, 'reload schema';

