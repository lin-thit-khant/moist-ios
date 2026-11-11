-- Allow owners to pin Projects.
alter table public.projects
add column is_pinned boolean not null default false;

-- Allow owners to hide individual posts.
alter table public.posts
add column is_hidden boolean not null default false;

-- Replace the old public-read policy.
drop policy if exists "Posts are viewable by everyone"
on public.posts;

-- Everyone can read public posts.
-- Owners can also read their own hidden posts.
create policy "View public or owned posts"
on public.posts
for select
to anon, authenticated
using (
    is_hidden = false
    or user_id = (select auth.uid())
);

-- Improve owner-specific post loading.
create index if not exists posts_user_created_at_idx
on public.posts(user_id, created_at desc);
