-- 1. Create one profile for each authenticated user.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  username text not null unique
    check (
      username = lower(username)
      and username ~ '^[a-z0-9_]{3,24}$'
    ),

    display_name text not null default '',

    bio text not null default ''
      check (char_length(bio) <= 160),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

-- 2. Enable Row Level Security.
alter table public.profiles enable row level security;

-- 3. Allow anyone using the app to read public profiles.
create policy "Profiles are viewable by everyone"
on public.profiles
for select
to anon, authenticated
using (true);

-- 4. Allow authenticated users to create their own profile only.
create policy "Users can create their own profile"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

-- 5. Allow authenticated users to update their own profile only.
create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- 6. Automatically create a profile when a new account is created.
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

-- 7. Run the function whenever Supabase creates an auth user.
create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- 8. Create profiles for accounts that already exist.
insert into public.profiles (id, username)
select
    id,
    'user_' || left(replace(id::text, '-', ''), 12)
from auth.users
on conflict do nothing;