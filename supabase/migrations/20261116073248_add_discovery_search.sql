
-- =================================================
-- RAWDEA MILESTONE 10
-- Search and Discovery
--
-- SECURITY INVOKER:
-- Existing table permissions and RLS still apply.
--
-- Results are public discovery only:
-- No hidden posts, hidden Projects, or archives.
-- =================================================

-- ================================================
-- 1. SEARCH PEOPLE
-- ================================================

create or replace function public.rawdea_search_people(
    search_term text,
    page_size integer default 21,
    page_offset integer default 0
)
returns table (id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
    select p.id
    from public.profiles p
    where char_length(btrim(search_term)) >= 2
      and (
          strpos(
              lower(p.username),
              lower(btrim(search_term))
          ) > 0
          or
          strpos(
              lower(p.display_name),
              lower(btrim(search_term))
          ) > 0
          or
          strpos(
              lower(p.bio),
              lower(btrim(search_term))
          ) > 0
      )
    order by
        case
            when lower(p.username) =
                 lower(btrim(search_term))
            then 0
            else 1
        end,
        p.username asc,
        p.id asc
    limit least(greatest(coalesce(page_size, 21), 1), 50)
    offset greatest(coalesce(page_offset, 0), 0);
$$;


-- ================================================
-- 2. SEARCH PUBLIC PROJECTS
-- ================================================

create or replace function public.rawdea_search_projects(
    search_term text,
    page_size integer default 21,
    page_offset integer default 0
)
returns table (id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
    select p.id
    from public.projects p
    where char_length(btrim(search_term)) >= 2
      and p.is_hidden = false
      and p.is_archived = false
      and strpos(
          lower(p.name),
          lower(btrim(search_term))
      ) > 0
    order by
        p.created_at desc,
        p.id desc
    limit least(greatest(coalesce(page_size, 21), 1), 50)
    offset greatest(coalesce(page_offset, 0), 0);
$$;


-- ================================================
-- 3. SEARCH PUBLIC POSTS
-- ================================================

create or replace function public.rawdea_search_posts(
    search_term text,
    page_size integer default 21,
    page_offset integer default 0
)
returns table (id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
    select p.id
    from public.posts p
    where char_length(btrim(search_term)) >= 2

      -- Do not include individually hidden posts.
      and p.is_hidden = false

      -- Free posts are searchable.
      -- Project posts are searchable only when
      -- their Project is public and active.
      and (
          p.project_id is null
          or exists (
              select 1
              from public.projects pr
              where pr.id = p.project_id
                and pr.is_hidden = false
                and pr.is_archived = false
          )
      )

      and strpos(
          lower(p.content),
          lower(btrim(search_term))
      ) > 0

    order by
        p.created_at desc,
        p.id desc

    limit least(greatest(coalesce(page_size, 21), 1), 50)
    offset greatest(coalesce(page_offset, 0), 0);
$$;


-- ================================================
-- 4. EXECUTION PRIVILEGES
-- ================================================

-- Database functions can be callable by PUBLIC
-- unless EXECUTE is explicitly restricted.

revoke execute on function
    public.rawdea_search_people(text, integer, integer)
from public, anon, authenticated;

revoke execute on function
    public.rawdea_search_projects(text, integer, integer)
from public, anon, authenticated;

revoke execute on function
    public.rawdea_search_posts(text, integer, integer)
from public, anon, authenticated;

-- Only signed-in Rawdea users may search.

grant execute on function
    public.rawdea_search_people(text, integer, integer)
to authenticated;

grant execute on function
    public.rawdea_search_projects(text, integer, integer)
to authenticated;

grant execute on function
    public.rawdea_search_posts(text, integer, integer)
to authenticated;


-- ================================================
-- 5. REFRESH API SCHEMA
-- ================================================

notify pgrst, 'reload schema';

