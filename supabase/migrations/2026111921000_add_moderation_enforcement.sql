
-- ==============================================
-- RAWDEA MILESTONE 13 - BATCH 3
-- Moderation Enforcement and Restoration
-- ==============================================

-- ==============================================
-- 1. PRIVATE ENFORCEMENT RECORDS
-- ==============================================

create table private.moderation_enforcements (

    id uuid primary key default gen_random_uuid(),

    target_type text not null,
    target_id uuid not null,

    source_report_id uuid not null
        references public.content_reports(id)
        on delete restrict,

    moderator_id uuid not null
        references auth.users(id),

    enforced_at timestamptz not null default now(),

    revoked_at timestamptz,
    revoked_by uuid references auth.users(id),
    revocation_note text,

    constraint moderation_enforcement_target_check
        check (
            target_type in (
                'post',
                'comment',
                'account'
            )
        ),

    constraint moderation_enforcement_revocation_check
        check (
            (
                revoked_at is null
                and revoked_by is null
                and revocation_note is null
            )
            or
            (
                revoked_at is not null
                and revoked_by is not null
                and revocation_note is not null
                and char_length(btrim(revocation_note))
                    between 5 and 1000
            )
        )
);

-- Only one active restriction per target.
-- Historical restrictions are preserved.

create unique index moderation_one_active_target_idx
on private.moderation_enforcements (
    target_type,
    target_id
)
where revoked_at is null;

create index moderation_enforcements_report_idx
on private.moderation_enforcements (
    source_report_id,
    enforced_at desc
);

create index moderation_enforcements_account_idx
on private.moderation_enforcements (
    target_id
)
where target_type = 'account'
  and revoked_at is null;

alter table private.moderation_enforcements
enable row level security;

revoke all on private.moderation_enforcements
from public, anon, authenticated;

-- No normal-user RLS policies.
-- Moderator RPCs are the only app interface.

-- ==============================================
-- 2. PRIVATE ENFORCEMENT CHECK FUNCTIONS
-- ==============================================

-- Does the target have no active restriction?

create or replace function
private.rawdea_target_allowed(
    p_type text,
    p_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_id is not null
       and not exists (
           select 1
           from private.moderation_enforcements e
           where e.target_type = p_type
             and e.target_id = p_id
             and e.revoked_at is null
       );
$$;

-- Is the account not suspended?

create or replace function
private.rawdea_account_active(
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_user_id is not null
       and private.rawdea_target_allowed(
           'account',
           p_user_id
       );
$$;

revoke execute on function
private.rawdea_target_allowed(text,uuid)
from public, anon, authenticated;

revoke execute on function
private.rawdea_account_active(uuid)
from public, anon, authenticated;

-- Needed for RLS policy evaluation.
-- The private schema is not exposed in
-- Supabase's PostgREST API schemas.

grant usage on schema private to authenticated;

grant execute on function
private.rawdea_target_allowed(text,uuid)
to authenticated;

grant execute on function
private.rawdea_account_active(uuid)
to authenticated;

-- ==============================================
-- 3. POST ENFORCEMENT
-- ==============================================

-- Enforced posts disappear from:
-- normal feed, Following, discovery,
-- Project details and author profiles.
--
-- This also hides them from their author.
-- Existing visibility and block policies
-- continue to apply.

create policy "Moderation visibility posts"
on public.posts
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(user_id)
    and private.rawdea_target_allowed('post', id)
);

-- Suspended users cannot publish new posts.

create policy "Moderation posting restriction"
on public.posts
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

create policy "Moderation post editing restriction"
on public.posts
as restrictive
for update
to authenticated
using (
    private.rawdea_account_active(
        (select auth.uid())
    )
    and private.rawdea_target_allowed('post', id)
)
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
    and private.rawdea_target_allowed('post', id)
);

-- ==============================================
-- 4. COMMENT ENFORCEMENT
-- ==============================================

create policy "Moderation visibility comments"
on public.post_comments
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(user_id)
    and private.rawdea_target_allowed('comment', id)
);

create policy "Moderation comment creation restriction"
on public.post_comments
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

create policy "Moderation comment editing restriction"
on public.post_comments
as restrictive
for update
to authenticated
using (
    private.rawdea_account_active(
        (select auth.uid())
    )
    and private.rawdea_target_allowed('comment', id)
)
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
    and private.rawdea_target_allowed('comment', id)
);

-- ==============================================
-- 5. ACCOUNT VISIBILITY
-- ==============================================

-- Suspended accounts are hidden from others.
-- An account owner can still fetch their
-- own profile to see their account state.

create policy "Moderation visibility profiles"
on public.profiles
as restrictive
for select
to authenticated
using (
    id = (select auth.uid())
    or private.rawdea_account_active(id)
);

create policy "Moderation profile editing restriction"
on public.profiles
as restrictive
for update
to authenticated
using (
    private.rawdea_account_active(
        (select auth.uid())
    )
)
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

-- ==============================================
-- 6. PROJECT VISIBILITY AND WRITES
-- ==============================================

create policy "Moderation visibility projects"
on public.projects
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(user_id)
);

create policy "Moderation project creation restriction"
on public.projects
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

create policy "Moderation project editing restriction"
on public.projects
as restrictive
for update
to authenticated
using (
    private.rawdea_account_active(
        (select auth.uid())
    )
)
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

-- ==============================================
-- 7. LIKES AND BOOKMARKS
-- ==============================================

create policy "Moderation visibility likes"
on public.post_likes
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(user_id)
);

create policy "Moderation like creation restriction"
on public.post_likes
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

create policy "Moderation bookmark creation restriction"
on public.post_bookmarks
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

-- Existing deletion permissions remain,
-- so users can remove their own likes
-- and bookmarks when permitted.

-- ==============================================
-- 8. USER FOLLOW PRIVACY
-- ==============================================

create policy "Moderation visibility user follows"
on public.user_follows
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(follower_id)
    and private.rawdea_account_active(
        followed_user_id
    )
);

create policy "Moderation user follow restriction"
on public.user_follows
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
    and private.rawdea_account_active(
        followed_user_id
    )
);

-- ==============================================
-- 9. PROJECT FOLLOW PRIVACY
-- ==============================================

create policy "Moderation visibility project follows"
on public.project_follows
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(follower_id)
    and exists (
        select 1
        from public.projects p
        where p.id = project_id
    )
);

create policy "Moderation project follow restriction"
on public.project_follows
as restrictive
for insert
to authenticated
with check (
    private.rawdea_account_active(
        (select auth.uid())
    )
);

-- ==============================================
-- 10. NOTIFICATION PRIVACY
-- ==============================================

-- Do not surface notifications pointing to
-- moderated content or suspended authors.

create policy "Moderation visibility notifications"
on public.notifications
as restrictive
for select
to authenticated
using (
    private.rawdea_account_active(actor_id)

    and (
        post_id is null
        or exists (
            select 1
            from public.posts p
            where p.id = post_id
        )
    )

    and (
        comment_id is null
        or exists (
            select 1
            from public.post_comments c
            where c.id = comment_id
        )
    )
);

-- ==============================================
-- 11. RESTRICT REPORTS FROM SUSPENDED USERS
-- ==============================================

create or replace function
private.rawdea_check_reporter_active()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if not private.rawdea_account_active(
        new.reporter_id
    ) then

        raise exception
            'Account suspended: reporting unavailable'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

create trigger rawdea_active_reporter_required
before insert on public.content_reports
for each row
execute function private.rawdea_check_reporter_active();

revoke execute on function
private.rawdea_check_reporter_active()
from public, anon, authenticated;

-- ==============================================
-- 12. SELF ACCOUNT STATUS RPC
-- ==============================================

-- A suspended user must still be able
-- to learn whether their own account
-- is currently restricted.
--
-- This RPC cannot query another account.

create or replace function
public.rawdea_my_account_suspended()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select
        (select auth.uid()) is not null
        and not private.rawdea_account_active(
            (select auth.uid())
        );
$$;

revoke execute on function
public.rawdea_my_account_suspended()
from public, anon, authenticated;

grant execute on function
public.rawdea_my_account_suspended()
to authenticated;

-- ==============================================
-- 13. TIGHTEN REPORT STATUS METADATA
-- ==============================================

alter table public.content_reports
drop constraint content_reports_review_metadata_check;

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
        status in ('dismissed', 'actioned')
        and reviewer_id is not null
        and reviewed_at is not null
        and resolution_note is not null
    )
);

-- ==============================================
-- 14. EXTEND AUDIT EVENT CONSTRAINTS
-- ==============================================

alter table private.moderation_review_events
drop constraint moderation_event_action_check;

alter table private.moderation_review_events
add constraint moderation_event_action_check
check (
    action in (
        'claim',
        'release',
        'dismiss',
        'reopen',
        'enforce',
        'restore'
    )
);

alter table private.moderation_review_events
drop constraint moderation_event_note_check;

alter table private.moderation_review_events
add constraint moderation_event_note_check
check (
    (
        action in (
            'dismiss',
            'reopen',
            'enforce',
            'restore'
        )
        and note is not null
        and char_length(btrim(note)) between 5 and 1000
    )
    or
    (
        action in ('claim', 'release')
        and note is null
    )
);

-- ==============================================
-- 15. REPLACE EXISTING REVIEW ACTION RPC
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

    v_enforcement_id uuid;

begin

    -- Authorization is mandatory for
    -- every action, including restoration.

    if not public.rawdea_is_moderator() then
        raise exception
            'Moderator access required'
            using errcode = '42501';
    end if;

    if p_report_id is null then
        raise exception 'Invalid report';
    end if;

    if p_action is null
       or p_action not in (
           'claim',
           'release',
           'dismiss',
           'reopen',
           'enforce',
           'restore'
       ) then

        raise exception
            'Invalid moderation action';
    end if;

    v_note := nullif(
        btrim(coalesce(p_note, '')),
        ''
    );

    if p_action in (
        'dismiss',
        'reopen',
        'enforce',
        'restore'
    ) then

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

    -- Lock the report for the complete
    -- operation to avoid concurrent
    -- decisions on the same report.

    select *
    into v_report
    from public.content_reports r
    where r.id = p_report_id
    for update;

    if not found then
        raise exception 'Report not found';
    end if;

    -- ==========================================
    -- A. EXISTING BATCH 2 ACTIONS
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

    -- ==========================================
    -- B. NEW: ENFORCE RESTRICTION
    -- ==========================================

    elsif p_action = 'enforce' then

        if v_report.status <> 'reviewing'
           or v_report.reviewer_id
              is distinct from v_moderator_id
        then
            raise exception
                'Claim the report before enforcing it';
        end if;

        -- Verify that the target still exists
        -- and still belongs to the reported
        -- subject account.

        if v_report.target_type = 'post' then

            if not exists (
                select 1
                from public.posts p
                where p.id = v_report.target_id
                  and p.user_id =
                      v_report.subject_user_id
            ) then
                raise exception
                    'Reported post no longer exists';
            end if;

        elsif v_report.target_type = 'comment' then

            if not exists (
                select 1
                from public.post_comments c
                where c.id = v_report.target_id
                  and c.user_id =
                      v_report.subject_user_id
            ) then
                raise exception
                    'Reported comment no longer exists';
            end if;

        elsif v_report.target_type = 'account' then

            if not exists (
                select 1
                from public.profiles p
                where p.id = v_report.target_id
                  and p.id =
                      v_report.subject_user_id
            ) then
                raise exception
                    'Reported account no longer exists';
            end if;

            -- Never suspend an active moderator
            -- through an ordinary moderation report.

            if exists (
                select 1
                from private.rawdea_moderators m
                where m.user_id = v_report.target_id
                  and m.is_active = true
            ) then
                raise exception
                    'Active moderators cannot be suspended';
            end if;

        else

            raise exception 'Unsupported report target';

        end if;

        -- Reject concurrent or repeat
        -- restrictions for the same target.

        insert into private.moderation_enforcements (
            target_type,
            target_id,
            source_report_id,
            moderator_id
        )
        values (
            v_report.target_type,
            v_report.target_id,
            v_report.id,
            v_moderator_id
        )
        on conflict do nothing
        returning id into v_enforcement_id;

        if v_enforcement_id is null then
            raise exception
                'This target already has an active restriction';
        end if;

        v_next_status := 'actioned';

        update public.content_reports
        set
            status = v_next_status,
            reviewer_id = v_moderator_id,
            reviewed_at = now(),
            resolution_note = v_note
        where id = p_report_id;

    -- ==========================================
    -- C. NEW: REVERSE AN ENFORCEMENT
    -- ==========================================

    elsif p_action = 'restore' then

        if v_report.status <> 'actioned' then
            raise exception
                'Only actioned reports can be restored';
        end if;

        -- Only the report that originally
        -- created the restriction can lift
        -- that particular restriction.

        update private.moderation_enforcements e
        set
            revoked_at = now(),
            revoked_by = v_moderator_id,
            revocation_note = v_note
        where e.source_report_id = p_report_id
          and e.target_type = v_report.target_type
          and e.target_id = v_report.target_id
          and e.revoked_at is null
        returning e.id into v_enforcement_id;

        if v_enforcement_id is null then
            raise exception
                'Active enforcement record not found';
        end if;

        -- Return to the pending queue so
        -- the case can be reviewed again.

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
    -- D. APPEND AUDIT RECORD
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
-- 16. RESTORE RPC EXECUTION PRIVILEGES
-- ==============================================

revoke execute on function
public.rawdea_moderation_action(uuid,text,text)
from public, anon, authenticated;

grant execute on function
public.rawdea_moderation_action(uuid,text,text)
to authenticated;

-- ==============================================
-- 17. REFRESH POSTGREST
-- ==============================================


-- ==============================================
-- BATCH 3: REPORT ENFORCEMENT HARDENING
-- ==============================================

-- Extend the existing BEFORE INSERT trigger
-- to reject reports against content that
-- has already been removed by moderation.

create or replace function
private.rawdea_check_reporter_active()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_parent_post_id uuid;
    v_parent_author_id uuid;
begin

    if not private.rawdea_account_active(
        new.reporter_id
    ) then

        raise exception
            'Account suspended: reporting unavailable'
            using errcode = '42501';
    end if;

    if not private.rawdea_account_active(
        new.subject_user_id
    )
    or not private.rawdea_target_allowed(
        new.target_type,
        new.target_id
    ) then

        raise exception
            'This item is not available for reporting'
            using errcode = '42501';
    end if;

    -- A comment also becomes unavailable
    -- when its parent post is moderated
    -- or the parent author is suspended.

    if new.target_type = 'comment' then

        select
            c.post_id,
            p.user_id
        into
            v_parent_post_id,
            v_parent_author_id
        from public.post_comments c
        join public.posts p
          on p.id = c.post_id
        where c.id = new.target_id;

        if v_parent_post_id is not null
           and (
               not private.rawdea_target_allowed(
                   'post',
                   v_parent_post_id
               )
               or not private.rawdea_account_active(
                   v_parent_author_id
               )
           ) then

            raise exception
                'This item is not available for reporting'
                using errcode = '42501';
        end if;

    end if;

    return new;
end;
$$;

-- Historical moderator UUIDs should remain
-- in audit records if Auth accounts are later
-- deleted. Avoid preventing account deletion
-- solely because of the moderator identity FK.

alter table private.moderation_enforcements
drop constraint moderation_enforcements_moderator_id_fkey;

alter table private.moderation_enforcements
drop constraint moderation_enforcements_revoked_by_fkey;

-- Use wall-clock timestamps for new audit
-- events even when multiple actions occur
-- inside a single transaction.

alter table private.moderation_review_events
alter column created_at
set default clock_timestamp();

notify pgrst, 'reload schema';

