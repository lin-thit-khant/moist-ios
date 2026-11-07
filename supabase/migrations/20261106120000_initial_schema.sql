
-- RAWDEA: Initial database schema
-- This migration represents the existing schema
-- before Projects were introduced.

-- 1. Profiles

create table public.profiles (
    id uuid not null,
    username text not null,
    display_name text not null default '',
    bio text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint profiles_pkey primary key (id),
    constraint profiles_username_key unique (username),

    constraint profiles_id_fkey
        foreign key (id)
        references auth.users(id)
        on delete cascade,

    constraint profiles_username_check
        check (
            username = lower(username)
            and username ~ '^[a-z0-9_]{3,24}$'
        ),

    constraint profiles_bio_check
        check (char_length(bio) <= 160)
);

-- 2. Posts

create table public.posts (
    id uuid not null default gen_random_uuid(),
    user_id uuid not null,
    content text not null,
    created_at timestamptz not null default now(),

    constraint posts_pkey primary key (id),

    constraint posts_profile_fkey
        foreign key (user_id)
        references public.profiles(id)
        on delete cascade,

    constraint posts_user_id_fkey
        foreign key (user_id)
        references auth.users(id)
        on delete cascade,

    constraint posts_content_check
        check (
            char_length(content) between 1 and 500
            and length(trim(content)) > 0
        )
);

-- 3. Automatically create profiles after signup

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, username)
    values (
        new.id,
        'user_' || left(replace(new.id::text, '-', ''), 12)
    );

    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- 4. Database permissions

grant select on public.profiles, public.posts
to anon;

grant select, insert, update, delete
on public.profiles, public.posts
to authenticated;

-- 5. Enable Row Level Security

alter table public.profiles enable row level security;
alter table public.posts enable row level security;

-- 6. Profile policies

create policy "Profiles are viewable by everyone"
on public.profiles
for select to anon, authenticated
using (true);

create policy "Users can create their own profile"
on public.profiles
for insert to authenticated
with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles
for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- 7. Post policies

create policy "Posts are viewable by everyone"
on public.posts
for select to anon, authenticated
using (true);

create policy "Users can create their own posts"
on public.posts
for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own posts"
on public.posts
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their own posts"
on public.posts
for delete to authenticated
using ((select auth.uid()) = user_id);

