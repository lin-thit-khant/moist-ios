-- Removes everything seed_review_content.sql created, and nothing else.
--
-- LOCAL SUPABASE ONLY. Run with:
--   docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 < supabase/review/remove_review_content.sql
--
-- Review rows all have ids starting with 0000eeee-. Deleting the review
-- accounts cascades to their profiles, Projects, posts, comments, follows and
-- notifications. The explicit deletes first remove what the local
-- design-review account did on review content (likes, saves, follows), so
-- nothing depends on the cascade order.

begin;

delete from public.post_likes      where post_id::text like '0000eeee-%';
delete from public.post_bookmarks  where post_id::text like '0000eeee-%';
delete from public.project_follows where project_id::text like '0000eeee-%';
delete from public.user_follows    where follower_id::text like '0000eeee-%'
                                      or followed_user_id::text like '0000eeee-%';
delete from public.notifications   where actor_id::text like '0000eeee-%'
                                      or post_id::text like '0000eeee-%'
                                      or project_id::text like '0000eeee-%';
-- Review posts and Projects owned by the design-review account. A Project
-- that has since gained your own posts is kept.
delete from public.posts           where id::text like '0000eeee-%';
delete from public.projects pr     where pr.id::text like '0000eeee-%'
    and not exists (select 1 from public.posts p where p.project_id = pr.id);
delete from auth.users             where id::text like '0000eeee-%';

commit;
