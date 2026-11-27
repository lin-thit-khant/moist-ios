-- RAWDEA Project Lab: likes on answers. Same visibility, block
-- and moderation rules as likes on posts.

create table public.comment_likes (
    comment_id uuid not null
        references public.post_comments(id)
        on delete cascade,
    user_id uuid not null
        references public.profiles(id)
        on delete cascade,
    created_at timestamptz not null default now(),

    constraint comment_likes_pkey primary key (comment_id, user_id)
);

create index comment_likes_user_idx
on public.comment_likes(user_id);

alter table public.comment_likes enable row level security;

revoke all on table public.comment_likes
from public, anon, authenticated;

grant select, insert, delete on table public.comment_likes
to authenticated;

-- The subquery runs under comment RLS, so hidden, removed and
-- blocked comments cannot be read or liked.
create policy "Read likes on visible comments"
on public.comment_likes
for select to authenticated
using (
    exists (select 1 from public.post_comments c where c.id = comment_id)
);

create policy "Like visible comments"
on public.comment_likes
for insert to authenticated
with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.post_comments c where c.id = comment_id)
);

create policy "Remove own comment likes"
on public.comment_likes
for delete to authenticated
using (user_id = (select auth.uid()));

create policy "Block privacy comment likes"
on public.comment_likes
as restrictive
for select to authenticated
using (private.rawdea_can_access_user(user_id));

create policy "Moderation visibility comment likes"
on public.comment_likes
as restrictive
for select to authenticated
using (private.rawdea_account_active(user_id));

create policy "Moderation comment like restriction"
on public.comment_likes
as restrictive
for insert to authenticated
with check (private.rawdea_account_active((select auth.uid())));

notify pgrst, 'reload schema';
