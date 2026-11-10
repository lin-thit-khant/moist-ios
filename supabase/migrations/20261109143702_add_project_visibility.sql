-- Archive and visibility control for Projects

alter table public.projects
add column is_archived boolean not null default false,
add column is_hidden boolean not null default false;

-- Replace the previous public-read policy
drop policy "Public can view projects"
on public.projects;

create policy "View public or owned projects"
on public.projects
for select
to anon, authenticated
using (
    (
        is_hidden = false
        and is_archived = false
    )
    or user_id = (select auth.uid())
);
