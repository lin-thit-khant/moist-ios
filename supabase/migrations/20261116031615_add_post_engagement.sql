-- RAWDEA Milestone 7
-- Post Likes and Comments

-- ==========================================
-- 1. POST LIKES
-- ==========================================

create table public.post_likes (
    post_id uuid not null
        references public.posts(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    created_at timestamptz not null
        default now(),

    constraint post_likes_pkey
        primary key (post_id, user_id)
);

-- Helps with user deletion and future
-- "liked posts" functionality.

create index post_likes_user_id_idx
on public.post_likes(user_id);

-- ==========================================
-- 2. POST COMMENTS
-- ==========================================

create table public.post_comments (
    id uuid primary key default gen_random_uuid(),

    post_id uuid not null
        references public.posts(id)
        on delete cascade,

    user_id uuid not null,

    content text not null,

    created_at timestamptz not null default now(),

    constraint post_comments_user_id_fkey
        foreign key (user_id)
        references public.profiles(id)
        on delete cascade,

    constraint post_comments_content_check
        check (
            char_length(content) between 1 and 500
            and char_length(btrim(content)) > 0
        )
);

create index post_comments_post_created_idx
on public.post_comments (
    post_id,
    created_at desc,
    id desc
);

create index post_comments_user_id_idx
on public.post_comments(user_id);

-- ==========================================
-- 3. ENABLE RLS
-- ==========================================

alter table public.post_likes
enable row level security;

alter table public.post_comments
enable row level security;

revoke all on public.post_likes
from anon, authenticated;

revoke all on public.post_comments
from anon, authenticated;

grant select, insert, delete
on public.post_likes
to authenticated;

grant select, insert, delete
on public.post_comments
to authenticated;

-- Only comment content can be updated
-- using the authenticated database role.

grant update (content)
on public.post_comments
to authenticated;

-- ==========================================
-- 4. LIKE POLICIES
-- ==========================================

-- Only show likes on posts that the
-- requesting user can read through
-- the existing posts RLS policy.

create policy "Read likes on accessible posts"
on public.post_likes
for select
to authenticated
using (
    exists (
        select 1
        from public.posts p
        where p.id = post_id
    )
);

create policy "Like accessible posts"
on public.post_likes
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

create policy "Remove own likes"
on public.post_likes
for delete
to authenticated
using (
    user_id = (select auth.uid())
);

-- ==========================================
-- 5. COMMENT POLICIES
-- ==========================================

create policy "Read comments on accessible posts"
on public.post_comments
for select
to authenticated
using (
    exists (
        select 1
        from public.posts p
        where p.id = post_id
    )
);

create policy "Comment on accessible posts"
on public.post_comments
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

create policy "Edit own comments"
on public.post_comments
for update
to authenticated
using (
    user_id = (select auth.uid())

    and exists (
        select 1
        from public.posts p
        where p.id = post_id
    )
)
with check (
    user_id = (select auth.uid())

    and exists (
        select 1
        from public.posts p
        where p.id = post_id
    )
);

create policy "Delete own comments"
on public.post_comments
for delete
to authenticated
using (
    user_id = (select auth.uid())
);

-- ==========================================
-- 6. REFRESH POSTGREST SCHEMA
-- ==========================================

notify pgrst, 'reload schema';
