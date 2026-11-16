
-- =============================================
-- RAWDEA MILESTONE 11
-- Cursor-based feed and comment pagination
--
-- SECURITY INVOKER:
-- Existing RLS is always enforced.
-- =============================================

-- ---------------------------------------------
-- 1. Index for chronological All Posts
-- ---------------------------------------------

create index if not exists posts_created_id_idx
on public.posts (
    created_at desc,
    id desc
);

-- ---------------------------------------------
-- 2. Paginated All Posts
-- ---------------------------------------------
--
-- No additional visibility filters.
-- Existing posts RLS determines visibility.
-- Owners can still see their own hidden posts.
--
-- created_at_cursor is returned as PostgreSQL
-- text to preserve timestamp precision.

create or replace function public.rawdea_page_all_posts(
    before_created_at text default null,
    before_id uuid default null,
    batch_size integer default 21
)
returns table (
    id uuid,
    created_at_cursor text
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        p.id,
        p.created_at::text as created_at_cursor

    from public.posts p

    where
        (
            before_created_at is null
            and before_id is null
        )
        or
        (
            before_created_at is not null
            and before_id is not null
            and (p.created_at, p.id) <
                (
                    before_created_at::timestamptz,
                    before_id
                )
        )

    order by
        p.created_at desc,
        p.id desc

    limit least(
        greatest(coalesce(batch_size, 21), 1),
        51
    );
$$;

-- ---------------------------------------------
-- 3. Paginated Following Posts
-- ---------------------------------------------
--
-- A post matches when:
-- A. Its author is followed, OR
-- B. Its Project is followed.
--
-- EXISTS prevents duplicate post rows.
-- Hidden/archived content is excluded.

create or replace function public.rawdea_page_following_posts(
    before_created_at text default null,
    before_id uuid default null,
    batch_size integer default 21
)
returns table (
    id uuid,
    created_at_cursor text
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        p.id,
        p.created_at::text as created_at_cursor

    from public.posts p

    where
        p.is_hidden = false

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

        and (
            exists (
                select 1
                from public.user_follows uf
                where uf.follower_id =
                    (select auth.uid())
                  and uf.followed_user_id = p.user_id
            )

            or exists (
                select 1
                from public.project_follows pf
                where pf.follower_id =
                    (select auth.uid())
                  and pf.project_id = p.project_id
            )
        )

        and (
            (
                before_created_at is null
                and before_id is null
            )
            or
            (
                before_created_at is not null
                and before_id is not null
                and (p.created_at, p.id) <
                    (
                        before_created_at::timestamptz,
                        before_id
                    )
            )
        )

    order by
        p.created_at desc,
        p.id desc

    limit least(
        greatest(coalesce(batch_size, 21), 1),
        51
    );
$$;

-- ---------------------------------------------
-- 4. Paginated Post Comments
-- ---------------------------------------------
--
-- Existing post_comments RLS determines
-- whether the caller can read comments.

create or replace function public.rawdea_page_post_comments(
    target_post_id uuid,
    before_created_at text default null,
    before_id uuid default null,
    batch_size integer default 21
)
returns table (
    id uuid,
    created_at_cursor text
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        c.id,
        c.created_at::text as created_at_cursor

    from public.post_comments c

    where c.post_id = target_post_id

      and (
          (
              before_created_at is null
              and before_id is null
          )
          or
          (
              before_created_at is not null
              and before_id is not null
              and (c.created_at, c.id) <
                  (
                      before_created_at::timestamptz,
                      before_id
                  )
          )
      )

    order by
        c.created_at desc,
        c.id desc

    limit least(
        greatest(coalesce(batch_size, 21), 1),
        51
    );
$$;

-- ---------------------------------------------
-- 5. Function permissions
-- ---------------------------------------------

revoke execute on function
    public.rawdea_page_all_posts(
        text, uuid, integer
    )
from public, anon, authenticated;

revoke execute on function
    public.rawdea_page_following_posts(
        text, uuid, integer
    )
from public, anon, authenticated;

revoke execute on function
    public.rawdea_page_post_comments(
        uuid, text, uuid, integer
    )
from public, anon, authenticated;

grant execute on function
    public.rawdea_page_all_posts(
        text, uuid, integer
    )
to authenticated;

grant execute on function
    public.rawdea_page_following_posts(
        text, uuid, integer
    )
to authenticated;

grant execute on function
    public.rawdea_page_post_comments(
        uuid, text, uuid, integer
    )
to authenticated;

-- ---------------------------------------------
-- 6. Refresh API schema
-- ---------------------------------------------

notify pgrst, 'reload schema';

