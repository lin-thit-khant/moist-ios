
-- ==============================================
-- RAWDEA MILESTONE 13 - BATCH 1
-- Content Reporting Foundation
-- ==============================================

-- ==============================================
-- 1. CONTENT REPORTS
-- ==============================================

create table public.content_reports (

    id uuid primary key default gen_random_uuid(),

    reporter_id uuid not null,

    target_type text not null,
    target_id uuid not null,

    -- The author/account being reported.
    subject_user_id uuid not null,

    reason text not null,
    explanation text,

    -- Evidence preserved at submission time.
    -- Only trusted moderation processes
    -- may read these fields.
    evidence_text text,
    evidence_username text,

    status text not null default 'pending',

    created_at timestamptz not null default now(),

    constraint content_reports_target_check
        check (
            target_type in (
                'post',
                'comment',
                'account'
            )
        ),

    constraint content_reports_reason_check
        check (
            reason in (
                'spam',
                'harassment',
                'hate',
                'sexual_content',
                'violence',
                'self_harm',
                'other'
            )
        ),

    constraint content_reports_explanation_check
        check (
            explanation is null
            or (
                char_length(explanation) between 1 and 1000
                and char_length(btrim(explanation)) > 0
            )
        ),

    constraint content_reports_other_check
        check (
            reason <> 'other'
            or explanation is not null
        ),

    constraint content_reports_status_check
        check (
            status in (
                'pending',
                'reviewing',
                'actioned',
                'dismissed'
            )
        ),

    constraint content_reports_no_self_report
        check (
            reporter_id <> subject_user_id
        ),

    constraint content_reports_reporter_target_key
        unique (
            reporter_id,
            target_type,
            target_id
        )
);

-- UUID references for users and reported
-- content intentionally do not cascade.
-- Reports and evidence should remain
-- reviewable if content/accounts are deleted.
-- The RPC validates all target references.

-- ==============================================
-- 2. INDEXES
-- ==============================================

-- Future moderation queue.

create index content_reports_status_created_idx
on public.content_reports (
    status,
    created_at asc,
    id asc
);

-- Report rate limiting.

create index content_reports_reporter_created_idx
on public.content_reports (
    reporter_id,
    created_at desc
);

-- Future investigation by reported user.

create index content_reports_subject_created_idx
on public.content_reports (
    subject_user_id,
    created_at desc
);

-- ==============================================
-- 3. SECURITY
-- ==============================================

alter table public.content_reports
enable row level security;

-- No RLS policies are created for users.
-- An authenticated user has no direct
-- SELECT, INSERT, UPDATE, or DELETE access.

revoke all on table public.content_reports
from public, anon, authenticated;

-- Only trusted database owners and
-- service-role administration may
-- access the moderation queue.

-- ==============================================
-- 4. SUBMIT REPORT RPC
-- ==============================================

create or replace function public.rawdea_submit_report(
    p_target_type text,
    p_target_id uuid,
    p_reason text,
    p_explanation text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare

    v_reporter_id uuid := (select auth.uid());

    v_subject_user_id uuid;
    v_post_owner_id uuid;

    v_evidence_text text;
    v_evidence_username text;

    v_explanation text;

    v_hourly_count integer;
    v_daily_count integer;

    v_report_id uuid;

begin

    -- ==========================================
    -- A. AUTHENTICATION
    -- ==========================================

    if v_reporter_id is null then
        raise exception 'Authentication required';
    end if;

    -- ==========================================
    -- B. VALIDATION
    -- ==========================================

    if p_target_type is null
       or p_target_type not in (
           'post',
           'comment',
           'account'
       ) then

        raise exception 'Invalid report target';
    end if;

    if p_target_id is null then
        raise exception 'Invalid report target';
    end if;

    if p_reason is null
       or p_reason not in (
           'spam',
           'harassment',
           'hate',
           'sexual_content',
           'violence',
           'self_harm',
           'other'
       ) then

        raise exception 'Invalid report reason';
    end if;

    v_explanation := nullif(
        btrim(coalesce(p_explanation, '')),
        ''
    );

    if char_length(v_explanation) > 1000 then
        raise exception
            'Report explanation is too long';
    end if;

    if p_reason = 'other'
       and v_explanation is null then

        raise exception
            'Please explain your report';
    end if;

    -- ==========================================
    -- C. PREVENT CONCURRENT RATE-LIMIT BYPASS
    -- ==========================================

    -- Serialize report submissions from the
    -- same user inside the current transaction.

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            v_reporter_id::text,
            93113
        )
    );

    -- ==========================================
    -- D. FIND REPORTED CONTENT
    -- ==========================================

    if p_target_type = 'post' then

        select
            p.user_id,
            p.content,
            author.username
        into
            v_subject_user_id,
            v_evidence_text,
            v_evidence_username
        from public.posts p
        join public.profiles author
          on author.id = p.user_id
        
        where p.id = p_target_id
        and p.is_hidden = false
        and (
            p.project_id is null
            or exists (
                select 1
                from public.projects pr
                where pr.id = p.project_id
                  and pr.is_hidden = false
                  and pr.is_archived = false
            )
        );


    elsif p_target_type = 'comment' then

        select
            c.user_id,
            c.content,
            author.username,
            p.user_id
        into
            v_subject_user_id,
            v_evidence_text,
            v_evidence_username,
            v_post_owner_id
        from public.post_comments c
        join public.posts p
          on p.id = c.post_id
        join public.profiles author
          on author.id = c.user_id
        
        where c.id = p_target_id
        and p.is_hidden = false
        and (
            p.project_id is null
            or exists (
                select 1
                from public.projects pr
                where pr.id = p.project_id
                  and pr.is_hidden = false
                  and pr.is_archived = false
            )
        );


    elsif p_target_type = 'account' then

        select
            p.id,
            left(
                'Display name: ' || p.display_name ||
                ' | Bio: ' || p.bio,
                1000
            ),
            p.username
        into
            v_subject_user_id,
            v_evidence_text,
            v_evidence_username
        from public.profiles p
        where p.id = p_target_id;

    end if;

    -- ==========================================
    -- E. VISIBILITY AND BLOCK PRIVACY
    -- ==========================================

    -- SECURITY DEFINER bypasses table RLS.
    -- Therefore these explicit checks are
    -- mandatory.

    if v_subject_user_id is null
       or v_subject_user_id = v_reporter_id
       or not private.rawdea_can_access_user(
           v_subject_user_id
       ) then

        raise exception
            'This item is not available for reporting';
    end if;

    -- Comments must also belong to a post
    -- whose author is accessible to the viewer.

    if v_post_owner_id is not null
       and not private.rawdea_can_access_user(
           v_post_owner_id
       ) then

        raise exception
            'This item is not available for reporting';
    end if;

    -- ==========================================
    -- F. DUPLICATE PREVENTION
    -- ==========================================

    if exists (
        select 1
        from public.content_reports r
        where r.reporter_id = v_reporter_id
          and r.target_type = p_target_type
          and r.target_id = p_target_id
    ) then

        raise exception
            'You have already reported this item';
    end if;

    -- ==========================================
    -- G. RATE LIMITING
    -- ==========================================

    select count(*)
    into v_hourly_count
    from public.content_reports r
    where r.reporter_id = v_reporter_id
      and r.created_at >=
          now() - interval '1 hour';

    if v_hourly_count >= 5 then
        raise exception
            'Report limit reached. Try again later';
    end if;

    select count(*)
    into v_daily_count
    from public.content_reports r
    where r.reporter_id = v_reporter_id
      and r.created_at >=
          now() - interval '24 hours';

    if v_daily_count >= 20 then
        raise exception
            'Daily report limit reached. Try again later';
    end if;

    -- ==========================================
    -- H. CREATE REPORT
    -- ==========================================

    insert into public.content_reports (

        reporter_id,
        target_type,
        target_id,
        subject_user_id,
        reason,
        explanation,
        evidence_text,
        evidence_username

    )
    values (

        v_reporter_id,
        p_target_type,
        p_target_id,
        v_subject_user_id,
        p_reason,
        v_explanation,
        left(v_evidence_text, 1000),
        v_evidence_username

    )

    on conflict (
        reporter_id,
        target_type,
        target_id
    )
    do nothing

    returning id into v_report_id;

    if v_report_id is null then
        raise exception
            'You have already reported this item';
    end if;

    return v_report_id;

end;
$$;

-- ==============================================
-- 5. RPC PERMISSIONS
-- ==============================================

revoke execute on function
public.rawdea_submit_report(
    text, uuid, text, text
)
from public, anon, authenticated;

grant execute on function
public.rawdea_submit_report(
    text, uuid, text, text
)
to authenticated;

-- ==============================================
-- 6. RELOAD API SCHEMA
-- ==============================================

notify pgrst, 'reload schema';

