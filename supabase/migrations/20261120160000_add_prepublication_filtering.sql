
-- ==============================================
-- RAWDEA MILESTONE 13 - BATCH 4
-- Pre-publication Content Filtering
-- ==============================================

-- ==============================================
-- 1. PRIVATE FILTER RULES
-- ==============================================

create table private.rawdea_content_filter_rules (

    id bigint generated always as identity
        primary key,

    target_kind text not null,

    category text not null,

    pattern text not null,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    constraint content_filter_kind_check
        check (
            target_kind in (
                'all',
                'post',
                'comment',
                'profile',
                'project'
            )
        ),

    constraint content_filter_category_check
        check (
            category in (
                'targeted_threat',
                'self_harm_encouragement',
                'credential_scam'
            )
        ),

    constraint content_filter_pattern_check
        check (
            char_length(pattern) between 1 and 250
        )
);

alter table private.rawdea_content_filter_rules
enable row level security;

revoke all on private.rawdea_content_filter_rules
from public, anon, authenticated;

-- No user-facing RLS policies.
-- Rules can only be managed by trusted
-- database administrators.

-- ==============================================
-- 2. STARTER FILTER RULES
-- ==============================================

-- Patterns operate on normalized text:
-- lowercase, repeated punctuation and
-- whitespace converted to spaces.
--
-- These are intentionally narrow rules.
-- They do not attempt to classify every
-- category of objectionable content.

insert into private.rawdea_content_filter_rules (
    target_kind,
    category,
    pattern
)
values

(
    'all',
    'targeted_threat',
    '(^| )i (will|am going to|m going to) (kill|hurt) you( |$)'
),

(
    'all',
    'self_harm_encouragement',
    '(^| )(go|you should) kill yourself( |$)'
),

(
    'all',
    'credential_scam',
    '(^| )send me your (password|verification code)( |$)'
);

-- ==============================================
-- 3. CLASSIFY CONTENT
-- ==============================================

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

    -- Normalize case, spaces and punctuation
    -- before matching the phrase rules.
    --
    -- This catches simple variations such as
    -- repeated spaces and punctuation.

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

    -- Avoid regular expressions on extremely
    -- long, unexpected profile fields.

    if char_length(v_normalized) > 2000 then
        return 'invalid_length';
    end if;

    -- Check private, administrator-controlled
    -- rules in deterministic ID order.

    select r.category
    into v_category
    from private.rawdea_content_filter_rules r

    where r.is_active = true

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

    -- Detect excessive URL posting.
    -- 4 or more web links in one post/comment
    -- is rejected as potential link spam.
    --
    -- This is separate from normalized text
    -- because punctuation is meaningful
    -- inside URLs.

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

-- ==============================================
-- 4. ASSERT PUBLICATION IS ALLOWED
-- ==============================================

create or replace function
private.rawdea_assert_publication(
    p_kind text,
    p_content text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_category text;
begin

    v_category := private.rawdea_filter_category(
        p_kind,
        p_content
    );

    if v_category is not null then

        raise exception using

            errcode = 'P0001',

            message =
                'RAWDEA_FILTER_BLOCKED:' ||
                v_category;

    end if;

end;
$$;

-- ==============================================
-- 5. FILTER POST CREATION AND EDITING
-- ==============================================

create or replace function
private.rawdea_filter_post_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if tg_op = 'INSERT' then

        perform private.rawdea_assert_publication(
            'post',
            new.content
        );

        return new;
    end if;

    -- Filter new content and content that
    -- is being made visible again.

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

    return new;

end;
$$;

create trigger rawdea_prepublication_posts
before insert or update of
    content,
    is_hidden,
    project_id
on public.posts
for each row
execute function private.rawdea_filter_post_trigger();

-- ==============================================
-- 6. FILTER COMMENTS
-- ==============================================

create or replace function
private.rawdea_filter_comment_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if tg_op = 'INSERT' then

        perform private.rawdea_assert_publication(
            'comment',
            new.content
        );

        return new;
    end if;

    if new.content is distinct from old.content then

        perform private.rawdea_assert_publication(
            'comment',
            new.content
        );

    end if;

    return new;

end;
$$;

create trigger rawdea_prepublication_comments
before insert or update of content
on public.post_comments
for each row
execute function
private.rawdea_filter_comment_trigger();

-- ==============================================
-- 7. FILTER PROFILE CONTENT
-- ==============================================

create or replace function
private.rawdea_filter_profile_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    -- Existing profiles don't have a strict
    -- display-name length check.
    -- Apply a reasonable maximum to new edits.

    if char_length(new.display_name) > 80 then

        raise exception using
            errcode = 'P0001',
            message =
                'RAWDEA_FILTER_BLOCKED:invalid_length';

    end if;

    if tg_op = 'INSERT' then

        perform private.rawdea_assert_publication(
            'profile',
            new.username
        );

        perform private.rawdea_assert_publication(
            'profile',
            new.display_name
        );

        perform private.rawdea_assert_publication(
            'profile',
            new.bio
        );

        return new;
    end if;

    if new.username is distinct from old.username then

        perform private.rawdea_assert_publication(
            'profile',
            new.username
        );

    end if;

    if new.display_name
       is distinct from old.display_name then

        perform private.rawdea_assert_publication(
            'profile',
            new.display_name
        );

    end if;

    if new.bio is distinct from old.bio then

        perform private.rawdea_assert_publication(
            'profile',
            new.bio
        );

    end if;

    return new;

end;
$$;

create trigger rawdea_prepublication_profiles
before insert or update of
    username,
    display_name,
    bio
on public.profiles
for each row
execute function
private.rawdea_filter_profile_trigger();

-- ==============================================
-- 8. FILTER PROJECT NAMES
-- ==============================================

create or replace function
private.rawdea_filter_project_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_existing_category text;
begin

    if tg_op = 'INSERT' then

        perform private.rawdea_assert_publication(
            'project',
            new.name
        );

        return new;
    end if;

    if new.name is distinct from old.name
       or (
           (old.is_hidden or old.is_archived)
           and not new.is_hidden
           and not new.is_archived
       ) then

        perform private.rawdea_assert_publication(
            'project',
            new.name
        );

    end if;

    -- A Project becoming publicly visible
    -- must not republish a previously stored
    -- post that violates the current rules.

    if (old.is_hidden or old.is_archived)
       and not new.is_hidden
       and not new.is_archived then

        select
            private.rawdea_filter_category(
                'post',
                p.content
            )
        into v_existing_category
        from public.posts p

        where p.project_id = new.id
          and p.is_hidden = false

          and private.rawdea_filter_category(
              'post',
              p.content
          ) is not null

        limit 1;

        if v_existing_category is not null then

            raise exception using
                errcode = 'P0001',
                message =
                    'RAWDEA_FILTER_BLOCKED:' ||
                    v_existing_category;

        end if;

    end if;

    return new;

end;
$$;

create trigger rawdea_prepublication_projects
before insert or update of
    name,
    is_hidden,
    is_archived
on public.projects
for each row
execute function
private.rawdea_filter_project_trigger();

-- ==============================================
-- 9. EXECUTION PRIVILEGES
-- ==============================================

-- Private helper functions are called
-- internally by trusted triggers.
-- They are not public client RPCs.

revoke execute on function
private.rawdea_filter_category(text,text)
from public, anon, authenticated;

revoke execute on function
private.rawdea_assert_publication(text,text)
from public, anon, authenticated;

revoke execute on function
private.rawdea_filter_post_trigger()
from public, anon, authenticated;

revoke execute on function
private.rawdea_filter_comment_trigger()
from public, anon, authenticated;

revoke execute on function
private.rawdea_filter_profile_trigger()
from public, anon, authenticated;

revoke execute on function
private.rawdea_filter_project_trigger()
from public, anon, authenticated;

-- ==============================================
-- 10. RELOAD POSTGREST
-- ==============================================

notify pgrst, 'reload schema';

