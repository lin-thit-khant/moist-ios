
-- 1. Create Projects
create table public.projects (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    name text not null,

    created_at timestamptz not null default now(),

    constraint projects_name_valid
        check (char_length(btrim(name)) between 1 and 80),

    constraint projects_id_user_id_unique
        unique (id, user_id)
);

-- 2. Add optional Project membership to posts
alter table public.posts
add column project_id uuid;

-- 3. Only allow posts in their author's Projects
alter table public.posts
add constraint posts_project_owner_fk
foreign key (project_id, user_id)
references public.projects(id, user_id)
on delete set null (project_id);

-- 4. Indexes for loading Projects and their posts
create index projects_user_created_at_idx
on public.projects(user_id, created_at desc);

create index posts_project_created_at_idx
on public.posts(project_id, created_at desc)
where project_id is not null;

-- 5. Enable Row Level Security
alter table public.projects
enable row level security;

-- 6. Grant only the necessary database permissions
revoke all on table public.projects
from anon, authenticated;

grant select on table public.projects
to anon;

grant select, insert, update, delete
on table public.projects
to authenticated;

-- 7. Public Projects are readable
create policy "Public can view projects"
on public.projects
for select
to anon, authenticated
using (true);

-- 8. Users can create only their own Projects
create policy "Users can create own projects"
on public.projects
for insert
to authenticated
with check ((select auth.uid()) = user_id);

-- 9. Users can update only their own Projects
create policy "Users can update own projects"
on public.projects
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- 10. Users can delete only their own Projects
create policy "Users can delete own projects"
on public.projects
for delete
to authenticated
using ((select auth.uid()) = user_id);

