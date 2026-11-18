
-- ==============================================
-- RAWDEA MILESTONE 12
-- User Blocking and Privacy
-- ==============================================

-- ==============================================
-- 1. USER BLOCKS
-- ==============================================

create table public.user_blocks (

    blocker_id uuid not null
        references public.profiles(id)
        on delete cascade,

    blocked_id uuid not null
        references public.profiles(id)
        on delete cascade,

    -- Store display information because the
    -- blocked profile becomes inaccessible.
    blocked_username text not null default '',
    blocked_display_name text not null default '',

    created_at timestamptz not null default now(),

    constraint user_blocks_pkey
        primary key (blocker_id, blocked_id),

    constraint user_blocks_no_self_block
        check (blocker_id <> blocked_id)
);

-- The primary key helps find accounts
-- blocked by the current user.

-- Reverse lookup helps detect when another
-- account has blocked the current user.

create index user_blocks_reverse_idx
on public.user_blocks (
    blocked_id,
    blocker_id
);

create index user_blocks_created_idx
on public.user_blocks (
    blocker_id,
    created_at desc
);

-- ==============================================
-- 2. PERMISSIONS AND RLS
-- ==============================================

alter table public.user_blocks
enable row level security;

revoke all on public.user_blocks
from public, anon, authenticated;

-- The app can read its own blocked list,
-- but cannot directly insert/delete blocks.
-- Those actions use controlled RPC functions.

grant select on public.user_blocks
to authenticated;

create policy "Read own blocked users"
on public.user_blocks
for select
to authenticated
using (
    blocker_id = (select auth.uid())
);

-- ==============================================
-- 3. PRIVATE BLOCK CHECK
-- ==============================================

-- This function checks both directions:
--
-- A blocks B
-- OR
-- B blocks A
--
-- SECURITY DEFINER avoids RLS recursion.
-- It must be owned by a trusted database role.

create schema if not exists private;

create or replace function
private.rawdea_can_access_user(
    target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select
        (select auth.uid()) is not null

        and target_user_id is not null

        and not exists (

            select 1
            from public.user_blocks b

            where
                (
                    b.blocker_id = (select auth.uid())
                    and b.blocked_id = target_user_id
                )

                or

                (
                    b.blocker_id = target_user_id
                    and b.blocked_id = (select auth.uid())
                )
        );
$$;

revoke execute on function
private.rawdea_can_access_user(uuid)
from public, anon, authenticated;

grant usage on schema private
to authenticated;

grant execute on function
private.rawdea_can_access_user(uuid)
to authenticated;

-- ==============================================
-- 4. PROTECT PUBLIC CONTENT
-- ==============================================

-- Rawdea currently displays content only
-- to authenticated users.
--
-- Remove anonymous SELECT permissions so
-- users cannot bypass blocking by signing out.
--
-- This deliberately changes public API
-- visibility: logged-out users cannot
-- fetch profiles, posts, or Projects.

revoke select on
    public.profiles,
    public.posts,
    public.projects
from public, anon;

-- RESTRICTIVE policies are important:
--
-- Existing permissive policies still enforce
-- post and Project ownership/visibility.
-- These new rules must ALSO pass.

create policy "Block privacy profiles"
on public.profiles
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(id)
);

create policy "Block privacy posts"
on public.posts
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(user_id)
);

create policy "Block privacy projects"
on public.projects
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(user_id)
);

-- ==============================================
-- 5. USER FOLLOW PRIVACY
-- ==============================================

create policy "Block privacy user follows"
on public.user_follows
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(follower_id)

    and

    private.rawdea_can_access_user(
        followed_user_id
    )
);

create policy "Block prevents user follows"
on public.user_follows
as restrictive
for insert
to authenticated
with check (
    private.rawdea_can_access_user(
        followed_user_id
    )
);

-- ==============================================
-- 6. PROJECT FOLLOW PRIVACY
-- ==============================================

create policy "Block privacy project follows"
on public.project_follows
as restrictive
for select
to authenticated
using (

    private.rawdea_can_access_user(follower_id)

    and

    exists (
        select 1
        from public.projects p
        where p.id = project_id
    )
);

create policy "Block prevents project follows"
on public.project_follows
as restrictive
for insert
to authenticated
with check (
    exists (
        select 1
        from public.projects p
        where p.id = project_id
    )
);

-- ==============================================
-- 7. POST ENGAGEMENT PRIVACY
-- ==============================================

-- The existing likes/comments INSERT policies
-- already require SELECT access to the post.
--
-- Now blocked accounts cannot SELECT each
-- other's posts, so they cannot interact
-- with those posts.

-- Also hide old likes by blocked accounts.

create policy "Block privacy likes"
on public.post_likes
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(user_id)
);

-- Also hide old comments by blocked accounts.

create policy "Block privacy comments"
on public.post_comments
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(user_id)
);

-- ==============================================
-- 8. NOTIFICATION PRIVACY
-- ==============================================

create policy "Block privacy notifications"
on public.notifications
as restrictive
for select
to authenticated
using (
    private.rawdea_can_access_user(actor_id)
);

create policy "Block privacy notification updates"
on public.notifications
as restrictive
for update
to authenticated
using (
    private.rawdea_can_access_user(actor_id)
)
with check (
    private.rawdea_can_access_user(actor_id)
);

-- Existing bookmarks remain owned by the user.
-- Post hydration still uses posts RLS.
-- This preserves the ability to remove bookmarks
-- even if their posts become inaccessible.

-- ==============================================
-- 9. BLOCK USER FUNCTION
-- ==============================================

create or replace function
public.rawdea_block_user(
    target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare

    viewer_id uuid := (select auth.uid());

    target_username text;
    target_display_name text;

begin

    -- Validate authentication.

    if viewer_id is null then
        raise exception 'Authentication required';
    end if;

    -- Never allow self-blocking.

    if target_user_id is null
       or viewer_id = target_user_id then

        raise exception 'Cannot block this account';
    end if;

    -- Obtain display information.
    -- If the target already blocks us, avoid
    -- exposing their current profile details.

    if private.rawdea_can_access_user(
        target_user_id
    ) then

        select
            p.username,
            p.display_name
        into
            target_username,
            target_display_name
        from public.profiles p
        where p.id = target_user_id;

    else

        select
            'blocked_account',
            'Blocked account'
        into
            target_username,
            target_display_name
        from public.profiles p
        where p.id = target_user_id;

    end if;

    if not found then
        raise exception 'Account not found';
    end if;

    -- Save the block.

    insert into public.user_blocks (
        blocker_id,
        blocked_id,
        blocked_username,
        blocked_display_name
    )
    values (
        viewer_id,
        target_user_id,
        target_username,
        target_display_name
    )
    on conflict (blocker_id, blocked_id)
    do nothing;

    -- Remove user follows in both directions.

    delete from public.user_follows uf
    where
        (
            uf.follower_id = viewer_id
            and uf.followed_user_id = target_user_id
        )
        or
        (
            uf.follower_id = target_user_id
            and uf.followed_user_id = viewer_id
        );

    -- Remove Project follows in both directions.

    delete from public.project_follows pf
    using public.projects p

    where pf.project_id = p.id

      and (
          (
              pf.follower_id = viewer_id
              and p.user_id = target_user_id
          )

          or

          (
              pf.follower_id = target_user_id
              and p.user_id = viewer_id
          )
      );

    -- Remove existing notifications between
    -- both accounts.

    delete from public.notifications n
    where
        (
            n.recipient_id = viewer_id
            and n.actor_id = target_user_id
        )
        or
        (
            n.recipient_id = target_user_id
            and n.actor_id = viewer_id
        );

end;
$$;

-- ==============================================
-- 10. UNBLOCK USER FUNCTION
-- ==============================================

create or replace function
public.rawdea_unblock_user(
    target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare

    viewer_id uuid := (select auth.uid());

begin

    if viewer_id is null then
        raise exception 'Authentication required';
    end if;

    if target_user_id is null then
        raise exception 'Invalid account';
    end if;

    delete from public.user_blocks
    where blocker_id = viewer_id
      and blocked_id = target_user_id;

    -- Do not restore previous follows.

end;
$$;

-- ==============================================
-- 11. FUNCTION PERMISSIONS
-- ==============================================

revoke execute on function
public.rawdea_block_user(uuid)
from public, anon, authenticated;

revoke execute on function
public.rawdea_unblock_user(uuid)
from public, anon, authenticated;

grant execute on function
public.rawdea_block_user(uuid)
to authenticated;

grant execute on function
public.rawdea_unblock_user(uuid)
to authenticated;

-- ==============================================
-- 12. RELOAD SUPABASE API SCHEMA
-- ==============================================

notify pgrst, 'reload schema';
