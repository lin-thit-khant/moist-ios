
-- ==============================================
-- RAWDEA MILESTONE 13 - BATCH 2
-- Moderation Review Workflow
-- ==============================================

-- ==============================================
-- 1. MODERATOR ALLOWLIST
-- ==============================================

create table private.rawdea_moderators (

    user_id uuid primary key
        references auth.users(id)
        on delete cascade,

    is_active boolean not null default true,

    added_at timestamptz not null default now()
);

alter table private.rawdea_moderators
enable row level security;

revoke all on private.rawdea_moderators
from public, anon, authenticated;

-- There are deliberately no client RLS
-- policies for this table.
-- Membership is managed by a trusted admin.

-- ==============================================
-- 2. EXTEND CONTENT REPORTS
-- ==============================================

alter table public.content_reports
add column reviewer_id uuid,
add column reviewed_at timestamptz,
add column resolution_note text;

alter table public.content_reports
add constraint content_reports_review_metadata_check
check (
    (
        status = 'pending'
        and reviewer_id is null
        and reviewed_at is null
        and resolution_note is null
    )
    or
    (
        status = 'reviewing'
        and reviewer_id is not null
        and reviewed_at is null
        and resolution_note is null
    )
    or
    (
        status = 'dismissed'
        and reviewer_id is not null
        and reviewed_at is not null
        and resolution_note is not null
    )
    or status = 'actioned'
);

-- The actioned status is reserved for Batch 3.
-- No Batch 2 RPC can set it.

-- ==============================================
-- 3. MODERATION AUDIT EVENTS
-- ==============================================

create table private.moderation_review_events (

    id uuid primary key default gen_random_uuid(),

    report_id uuid not null
        references public.content_reports(id)
        on delete restrict,

    moderator_id uuid not null,

    action text not null,

    previous_status text not null,
    new_status text not null,

    note text,

    created_at timestamptz not null default now(),

    constraint moderation_event_action_check
        check (
            action in (
                'claim',
                'release',
                'dismiss',
                'reopen'
            )
        ),

    constraint moderation_event_note_check
        check (
            (
                action in ('dismiss', 'reopen')
                and note is not null
                and char_length(btrim(note))
                    between 5 and 1000
            )
            or
            (
                action in ('claim', 'release')
                and note is null
            )
        )
);

create index moderation_events_report_idx
on private.moderation_review_events (
    report_id,
    created_at,
    id
);

alter table private.moderation_review_events
enable row level security;

revoke all on private.moderation_review_events
from public, anon, authenticated;

-- No direct authenticated client access
-- to audit events.

-- ==============================================
-- 4. CHECK MODERATOR AUTHORIZATION
-- ==============================================

create or replace function
public.rawdea_is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select
        (select auth.uid()) is not null
        and exists (
            select 1
            from private.rawdea_moderators m
            where m.user_id = (select auth.uid())
              and m.is_active = true
        );
$$;

-- ==============================================
-- 5. FETCH MODERATION QUEUE
-- ==============================================

create or replace function
public.rawdea_moderation_queue(
    p_status text default 'pending',
    p_after_created_at text default null,
    p_after_id uuid default null,
    p_limit integer default 21
)
returns table (
    id uuid,
    target_type text,
    reason text,
    status text,
    evidence_username text,
    created_at timestamptz,
    created_at_cursor text,
    reviewer_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin

    if not public.rawdea_is_moderator() then
        raise exception
            'Moderator access required'
            using errcode = '42501';
    end if;

    if p_status is null
       or p_status not in (
           'pending',
           'reviewing',
           'dismissed',
           'actioned'
       ) then
        raise exception 'Invalid moderation status';
    end if;

    if (
        (p_after_created_at is null)
        <> (p_after_id is null)
    ) then
        raise exception 'Invalid pagination cursor';
    end if;

    return query
    select
        r.id,
        r.target_type,
        r.reason,
        r.status,
        r.evidence_username,
        r.created_at,
        r.created_at::text,
        r.reviewer_id

    from public.content_reports r

    where r.status = p_status

      and (
          p_after_created_at is null

          or (
              r.created_at,
              r.id
          ) > (
              p_after_created_at::timestamptz,
              p_after_id
          )
      )

    order by
        r.created_at asc,
        r.id asc

    limit least(
        greatest(coalesce(p_limit, 21), 1),
        51
    );

end;
$$;

-- ==============================================
-- 6. FETCH ONE REPORT'S DETAILS
-- ==============================================

create or replace function
public.rawdea_moderation_detail(
    p_report_id uuid
)
returns table (

    id uuid,
    reporter_id uuid,
    subject_user_id uuid,

    target_type text,
    target_id uuid,

    reason text,
    explanation text,

    evidence_text text,
    evidence_username text,

    status text,
    created_at timestamptz,

    reviewer_id uuid,
    reviewed_at timestamptz,
    resolution_note text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin

    if not public.rawdea_is_moderator() then
        raise exception
            'Moderator access required'
            using errcode = '42501';
    end if;

    return query
    select
        r.id,
        r.reporter_id,
        r.subject_user_id,
        r.target_type,
        r.target_id,
        r.reason,
        r.explanation,
        r.evidence_text,
        r.evidence_username,
        r.status,
        r.created_at,
        r.reviewer_id,
        r.reviewed_at,
        r.resolution_note

    from public.content_reports r

    where r.id = p_report_id;

end;
$$;

-- ==============================================
-- 7. FETCH REVIEW HISTORY
-- ==============================================

create or replace function
public.rawdea_moderation_history(
    p_report_id uuid
)
returns table (

    id uuid,
    moderator_id uuid,

    action text,
    previous_status text,
    new_status text,

    note text,
    created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin

    if not public.rawdea_is_moderator() then
        raise exception
            'Moderator access required'
            using errcode = '42501';
    end if;

    return query
    select
        e.id,
        e.moderator_id,
        e.action,
        e.previous_status,
        e.new_status,
        e.note,
        e.created_at

    from private.moderation_review_events e

    where e.report_id = p_report_id

    order by
        e.created_at asc,
        e.id asc;

end;
$$;

-- ==============================================
-- 8. REVIEW ACTION RPC
-- ==============================================

create or replace function
public.rawdea_moderation_action(
    p_report_id uuid,
    p_action text,
    p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare

    v_moderator_id uuid := (select auth.uid());

    v_report public.content_reports%rowtype;

    v_note text;
    v_next_status text;

begin

    -- ==========================================
    -- A. REQUIRE MODERATOR ROLE
    -- ==========================================

    if not public.rawdea_is_moderator() then
        raise exception
            'Moderator access required'
            using errcode = '42501';
    end if;

    -- ==========================================
    -- B. VALIDATE ACTION
    -- ==========================================

    if p_report_id is null then
        raise exception 'Invalid report';
    end if;

    if p_action is null
       or p_action not in (
           'claim',
           'release',
           'dismiss',
           'reopen'
       ) then
        raise exception 'Invalid moderation action';
    end if;

    v_note := nullif(
        btrim(coalesce(p_note, '')),
        ''
    );

    if p_action in ('dismiss', 'reopen') then

        if v_note is null
           or char_length(v_note) not between 5 and 1000
        then
            raise exception
                'A review note of 5 to 1000 characters is required';
        end if;

    elsif v_note is not null then

        raise exception
            'This action does not accept a review note';

    end if;

    -- ==========================================
    -- C. LOCK THE REPORT
    -- ==========================================

    select *
    into v_report
    from public.content_reports r
    where r.id = p_report_id
    for update;

    if not found then
        raise exception 'Report not found';
    end if;

    -- ==========================================
    -- D. APPLY ALLOWED TRANSITIONS
    -- ==========================================

    if p_action = 'claim' then

        if v_report.status <> 'pending' then
            raise exception
                'Only pending reports can be claimed';
        end if;

        v_next_status := 'reviewing';

        update public.content_reports
        set
            status = v_next_status,
            reviewer_id = v_moderator_id,
            reviewed_at = null,
            resolution_note = null
        where id = p_report_id;

    elsif p_action = 'release' then

        if v_report.status <> 'reviewing'
           or v_report.reviewer_id
              is distinct from v_moderator_id
        then
            raise exception
                'Only the assigned moderator can release this report';
        end if;

        v_next_status := 'pending';

        update public.content_reports
        set
            status = v_next_status,
            reviewer_id = null,
            reviewed_at = null,
            resolution_note = null
        where id = p_report_id;

    elsif p_action = 'dismiss' then

        if v_report.status <> 'reviewing'
           or v_report.reviewer_id
              is distinct from v_moderator_id
        then
            raise exception
                'Claim the report before dismissing it';
        end if;

        v_next_status := 'dismissed';

        update public.content_reports
        set
            status = v_next_status,
            reviewer_id = v_moderator_id,
            reviewed_at = now(),
            resolution_note = v_note
        where id = p_report_id;

    elsif p_action = 'reopen' then

        if v_report.status <> 'dismissed' then
            raise exception
                'Only dismissed reports can be reopened';
        end if;

        v_next_status := 'pending';

        update public.content_reports
        set
            status = v_next_status,
            reviewer_id = null,
            reviewed_at = null,
            resolution_note = null
        where id = p_report_id;

    end if;

    -- ==========================================
    -- E. WRITE AUDIT EVENT
    -- ==========================================

    insert into private.moderation_review_events (

        report_id,
        moderator_id,
        action,
        previous_status,
        new_status,
        note
    )
    values (

        p_report_id,
        v_moderator_id,
        p_action,
        v_report.status,
        v_next_status,
        v_note
    );

    return v_next_status;

end;
$$;

-- ==============================================
-- 9. RPC PERMISSIONS
-- ==============================================

revoke execute on function
public.rawdea_is_moderator()
from public, anon, authenticated;

revoke execute on function
public.rawdea_moderation_queue(
    text, text, uuid, integer
)
from public, anon, authenticated;

revoke execute on function
public.rawdea_moderation_detail(uuid)
from public, anon, authenticated;

revoke execute on function
public.rawdea_moderation_history(uuid)
from public, anon, authenticated;

revoke execute on function
public.rawdea_moderation_action(
    uuid, text, text
)
from public, anon, authenticated;

grant execute on function
public.rawdea_is_moderator()
to authenticated;

grant execute on function
public.rawdea_moderation_queue(
    text, text, uuid, integer
)
to authenticated;

grant execute on function
public.rawdea_moderation_detail(uuid)
to authenticated;

grant execute on function
public.rawdea_moderation_history(uuid)
to authenticated;

grant execute on function
public.rawdea_moderation_action(
    uuid, text, text
)
to authenticated;

-- ==============================================
-- 10. RELOAD POSTGREST
-- ==============================================

notify pgrst, 'reload schema';

