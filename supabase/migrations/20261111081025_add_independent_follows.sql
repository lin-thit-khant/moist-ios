-- RAWDEA: Independent following system
-- People and Projects are followed separately.

-- ==========================================
-- 1. USER FOLLOWS
-- ==========================================

create table public.user_follows (
    follower_id uuid not null,
    followed_user_id uuid not null,
    
    created_at timestamptz not null
        default now(),
        
    constraint user_follows_pkey
        primary key (
            follower_id,
            followed_user_id
        ),
    
    constraint user_follows_follower_id_fkey
        foreign key (follower_id)
        references public.profiles(id)
        on delete cascade,
        
    constraint user_follows_followed_user_id_fkey
        foreign key (followed_user_id)
        references public.profiles(id)
        on delete cascade,
        
    constraint user_follows_no_self_follow
        check (follower_id <> followed_user_id)
);

-- ==========================================
-- 2. PROJECT FOLLOWS
-- ==========================================

create table public.project_follows (
    follower_id uuid not null,
    project_id uuid not null,
    
    created_at timestamptz not null
        default now(),
        
    constraint project_follows_pkey
        primary key (
            follower_id,
            project_id
        ),
        
    constraint project_follows_follower_id_fkey
        foreign key (follower_id)
        references public.profiles(id)
        on delete cascade,
        
    constraint project_follows_project_id_fkey
        foreign key (project_id)
        references public.projects(id)
        on delete cascade
);

-- ==========================================
-- 3. INDEXES
-- ==========================================

-- Efficient follower counts and lookups.

create index user_follows_target_idx
on public.user_follows(followed_user_id);

create index project_follows_target_idx
on public.project_follows(project_id);

-- Efficient chronological following lists.

create index user_follows_follower_created_idx
on public.user_follows(
    follower_id,
    created_at desc
);

create index project_follows_follower_created_idx
on public.project_follows(
    follower_id,
    created_at desc
);

-- ==========================================
-- 4. PERMISSIONS AND RLS
-- ==========================================

alter table public.user_follows
enable row level security;

alter table public.project_follows
enable row level security;

revoke all on table public.user_follows
from anon, authenticated;

revoke all on table public.project_follows
from anon, authenticated;

grant select, insert, delete
on table public.user_follows
to authenticated;

grant select, insert, delete
on table public.project_follows
to authenticated;

-- No UPDATE permission:
-- Follow records are created or removed,
-- never transferred to a different account.

-- ==========================================
-- 5. USER FOLLOW POLICIES
-- ==========================================

-- The following graph is visible to
-- authenticated users.

create policy "Authenticated can read user follows"
on public.user_follows
for select
to authenticated
using (true);

-- Users may follow others, but not themselves.

create policy "Users can follow other users"
on public.user_follows
for insert
to authenticated
with check (
    follower_id = (select auth.uid())
    and follower_id <> followed_user_id
);

-- Users can remove only their own follows.

create policy "Users can unfollow users"
on public.user_follows
for delete
to authenticated
using (
    follower_id = (select auth.uid())
);

-- ==========================================
-- 6. PROJECT FOLLOW POLICIES
-- ==========================================

-- A user can see:
-- 1. Their own follow records.
-- 2. Follows for publicly accessible Projects.
-- 3. Follows for Projects they own.


create policy "Users can read permitted project follows"
on public.project_follows
for select
to authenticated
using (
    follower_id = (select auth.uid())
    
    or exists (
        select 1
        from public.projects p
        where p.id = project_id
          and (
              (
                  p.is_hidden = false
                  and p.is_archived = false
              )
              or p.user_id = (select auth.uid())
        )
    )
);

-- Only public, active Projects belonging
-- to someone else can be followed.

create policy "Users can follow public projects"
on public.project_follows
for insert
to authenticated
with check (
    follower_id = (select auth.uid())
    
    and exists (
        select 1
        from public.projects p
        where p.id = project_id
          and p.is_hidden = false
          and p.is_archived = false
          and p.user_id <> (select auth.uid())
    )
);

-- Users can unfollow their own follow records,
-- even when a Project becomes hidden.

create policy "Users can unfollow projects"
on public.project_follows
for delete
to authenticated
using (
    follower_id = (select auth.uid())
);

-- ==========================================
-- 7. PROJECT POST VISIBILITY SECURITY
-- ==========================================

-- Existing RLS correctly protects individually
-- hidden posts, but project visibility must
-- also affect public access to their posts.

drop policy if exists "View public or owned posts"
on public.posts;

create policy "View public or owned posts"
on public.posts
for select
to anon, authenticated
using (
    -- Owners can still read all their posts.
    user_id = (select auth.uid())
    
    or (
        is_hidden = false
        
        and (
            -- Public free post.
            project_id is null
            
            or exists (
                select 1
                from public.projects p
                where p.id = posts.project_id
                  and p.is_hidden = false
                  and p.is_archived = false
            )
        )
    )
);


