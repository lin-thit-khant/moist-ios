
-- RAWDEA Milestone 8
-- Private post bookmarks

-- ==========================================
-- 1. BOOKMARKS
-- ==========================================

create table public.post_bookmarks (

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    post_id uuid not null
        references public.posts(id)
        on delete cascade,

    created_at timestamptz not null
        default now(),

    constraint post_bookmarks_pkey
        primary key (user_id, post_id)
);

-- Efficient retrieval of a user's most
-- recently saved posts.

create index post_bookmarks_user_created_idx
on public.post_bookmarks (
    user_id,
    created_at desc,
    post_id desc
);

-- Efficient cleanup when a post is deleted.

create index post_bookmarks_post_id_idx
on public.post_bookmarks (post_id);

-- ==========================================
-- 2. PERMISSIONS
-- ==========================================

alter table public.post_bookmarks
enable row level security;

revoke all on table public.post_bookmarks
from anon, authenticated;

grant select, insert, delete
on table public.post_bookmarks
to authenticated;

-- No UPDATE permission.
-- Saving and removing are separate actions.

-- ==========================================
-- 3. READ OWN BOOKMARKS
-- ==========================================

create policy "Users can read own bookmarks"
on public.post_bookmarks
for select
to authenticated
using (
    user_id = (select auth.uid())
);

-- ==========================================
-- 4. SAVE ACCESSIBLE POSTS
-- ==========================================

create policy "Users can save accessible posts"
on public.post_bookmarks
for insert
to authenticated
with check (

    user_id = (select auth.uid())

    and exists (
        select 1
        from public.posts p
        where p.id = post_id
    )
);

-- ==========================================
-- 5. REMOVE OWN BOOKMARKS
-- ==========================================

create policy "Users can remove own bookmarks"
on public.post_bookmarks
for delete
to authenticated
using (
    user_id = (select auth.uid())
);

-- ==========================================
-- 6. RELOAD SCHEMA
-- ==========================================

notify pgrst, 'reload schema';

