-- Rawdea review content: realistic people, Projects and posts for design reviews.
--
-- LOCAL SUPABASE ONLY. Run with:
--   docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 < supabase/review/seed_review_content.sql
--
-- Every row this script creates has an id starting with 0000eeee-, so
-- remove_review_content.sql can delete exactly these rows and nothing else.
-- Safe to run more than once: existing rows are skipped.
-- All people are fictional. Accounts have no password and cannot sign in.

begin;

-- Interactions are made on behalf of the local design-review account when it exists.
create temporary table review_viewer on commit drop as
select id from public.profiles where username = 'designreview';

-- People -------------------------------------------------------------------

create temporary table review_people (n int, username text, display_name text, bio text) on commit drop;
insert into review_people values
    (1, 'nora_patel',     'Nora Patel',     'Designer learning to build what I draw. Writing it all down as I go.'),
    (2, 'theo_okafor',    'Theo Okafor',    'Notes on notes. Librarian by day.'),
    (3, 'aye_chan',       'Aye Chan',       'Second year of a very small garden in Yangon.'),
    (4, 'mateo_rivera',   'Mateo Rivera',   'PhD student. Cities, heat and shade.'),
    (5, 'hana_sato',      'Hana Sato',      'One drawing a day, good or not.'),
    (6, 'kofi_mensah',    'Kofi Mensah',    'Building a 12 m² cabin with my dad, mostly on weekends.'),
    (7, 'ingrid_solberg', 'Ingrid Solberg-Haraldsdóttir Lindqvist', 'Translator. Long name, short sentences.'),
    (8, 'sam_lee',        'Sam',            '');

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select format('0000eeee-a%s-4000-8000-000000000000', lpad(n::text, 3, '0'))::uuid,
       '00000000-0000-0000-0000-000000000000'::uuid,
       'authenticated', 'authenticated',
       username || '@review.rawdea.test',
       now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
       now() - interval '30 days', now() - interval '30 days'
from review_people
on conflict (id) do nothing;

-- The auth trigger creates a placeholder profile; give it the real details.
update public.profiles p
set username = r.username, display_name = r.display_name, bio = r.bio
from review_people r
where p.id = format('0000eeee-a%s-4000-8000-000000000000', lpad(r.n::text, 3, '0'))::uuid
  and p.username is distinct from r.username;

-- Projects -----------------------------------------------------------------

create temporary table review_projects (n int, owner int, name text, pinned boolean) on commit drop;
insert into review_projects values
    (1, 1, 'Learning SwiftUI in public', true),
    (2, 3, 'Garden journal, year two', true),
    (3, 4, 'Thesis notes: shade in hot cities', false),
    (4, 5, 'A drawing a day', false),
    (5, 6, 'The cabin', true),
    (6, 2, 'Reading log 2026', false);

insert into public.projects (id, user_id, name, is_pinned, created_at)
select format('0000eeee-0001-4000-8000-%s', lpad(n::text, 12, '0'))::uuid,
       format('0000eeee-a%s-4000-8000-000000000000', lpad(owner::text, 3, '0'))::uuid,
       name, pinned, now() - interval '20 days'
from review_projects
on conflict (id) do nothing;

-- Posts --------------------------------------------------------------------
-- (n, author, project or null, minutes ago, content). Runs of posts in the
-- same Project are adjacent in time so the feed has threads to join.

create temporary table review_posts (n int, author int, project int, minutes int, content text) on commit drop;
insert into review_posts values
    (1,  1, 1,   38,  'Finally understood why my list kept redrawing. Identity matters more than I thought. Writing up what changed tomorrow.'),
    (2,  1, 1,   95,  'Day 14. Navigation stacks still confuse me, so I’m drawing them on paper first.'),
    (3,  1, 1,  190,  'Small win: Dynamic Type works on every screen now. The trick was deleting fixed heights, not adding code.'),
    (4,  2, null, 300, 'The best notes I keep are the ones I almost didn’t write down.'),
    (5,  3, 2,  410,  'Moved the tomatoes to the east bed. Three weeks of notes say they hated the afternoon sun.'),
    (6,  3, 2,  470,  'Basil is doing better than anything I planted on purpose.'),
    (7,  4, 3,  560,  'Measured surface temperature under three street trees and one bus shelter today. The shelter was 9 °C hotter than the worst tree. I keep rewriting the chapter around that one number.'),
    (8,  4, 3,  640,  'My supervisor asked what the thesis is about in one sentence. I said “who gets shade”. She said start there.'),
    (9,  5, 4,  720,  'Day 212. Hands again. Still bad at hands.'),
    (10, 7, null, 800, 'Translated a poem where the word for “dusk” also means “the time you stop working”. English has nothing like it, so I left a footnote and went for a walk.'),
    (11, 6, 5,  900,  'Walls are up. Dad insists on checking every corner with a level twice. He has been right twice.'),
    (12, 6, 5,  960,  'Rain all week. Spent it drawing the window frames instead.'),
    (13, 6, 5, 1100,  'Bought reclaimed wood for the floor. It smells like an old school.'),
    (14, 8, null, 1180, 'ok.'),
    (15, 2, 6, 1260,  'Finished “The Overstory” after a month. Slow, then all at once.'),
    (16, 2, 6, 1330,  'Rule for this year: if I stop a book I write one line about why. So far the lines are more interesting than the books.'),
    (17, 1, 1, 1420,  'Tried three ways to structure the profile screen. The simplest one won, again.'),
    (18, 3, 2, 1500,  'Garden plan for the cool season: fewer things, closer together, all of them things we actually eat.'),
    (19, 5, 4, 1600,  'Day 211. Drew my bus stop from memory, then from life. Memory had more trees.'),
    (20, 4, null, 1700, 'Any recommendations for writing in the mornings when your brain wants to read email first?'),
    (21, 7, null, 1790, 'A good sentence is one you can say out loud without running out of breath.'),
    (22, 6, 5, 1880,  'Roof plan, version four. Version three had a gutter pointing at the door.'),
    (23, 8, null, 1960, 'Started a notebook just for questions I don’t want answered yet. It is already half full. Some of them are about work, most of them are about why people keep plants they don’t water, and one is about whether my cat knows it is Tuesday. I plan to keep it unanswered for a year and see which ones still matter then.'),
    (24, 1, null, 2050, 'Notes app, sketchbook, this. Three places, one idea, slowly.'),
    (25, 3, 2, 2150,  'First chilli of the year. Small, very angry.'),
    (26, 4, 3, 2240,  'Interviewed a street vendor who moves her stall twice a day to follow the shade of one building. That is the whole thesis in one person.'),
    (27, 5, 4, 2330,  'Day 210. Skipped colour, kept lines. Felt lighter.'),
    (28, 2, null, 2400, 'Libraries are the last indoor place you can stay without buying anything.');

insert into public.posts (id, user_id, project_id, content, created_at)
select format('0000eeee-0002-4000-8000-%s', lpad(n::text, 12, '0'))::uuid,
       format('0000eeee-a%s-4000-8000-000000000000', lpad(author::text, 3, '0'))::uuid,
       case when project is null then null
            else format('0000eeee-0001-4000-8000-%s', lpad(project::text, 12, '0'))::uuid end,
       content,
       now() - make_interval(mins => minutes)
from review_posts
on conflict (id) do nothing;

-- Comments between review people ------------------------------------------

insert into public.post_comments (id, post_id, user_id, content, created_at)
select format('0000eeee-0003-4000-8000-%s', lpad(c.n::text, 12, '0'))::uuid,
       format('0000eeee-0002-4000-8000-%s', lpad(c.post::text, 12, '0'))::uuid,
       format('0000eeee-a%s-4000-8000-000000000000', lpad(c.author::text, 3, '0'))::uuid,
       c.content, now() - make_interval(mins => c.minutes)
from (values
    (1, 1, 5, 30,   'Same thing bit me last week. Stable ids fixed it.'),
    (2, 1, 2, 25,   'Please do write it up.'),
    (3, 7, 3, 500,  'Nine degrees is a lot. Is that typical?'),
    (4, 7, 4, 480,  'Typical for metal roofs at noon, yes. Trees win every time.'),
    (5, 11, 1, 880, 'Your dad sounds like a good code reviewer.'),
    (6, 20, 7, 1650, 'Phone in another room, kettle on, one paragraph before anything else.')
) as c(n, post, author, minutes, content)
on conflict (id) do nothing;

-- People and Projects following each other --------------------------------

insert into public.user_follows (follower_id, followed_user_id)
select format('0000eeee-a%s-4000-8000-000000000000', lpad(a::text, 3, '0'))::uuid,
       format('0000eeee-a%s-4000-8000-000000000000', lpad(b::text, 3, '0'))::uuid
from (values (1,3),(2,1),(3,1),(4,2),(5,1),(6,3),(7,2),(8,5)) as f(a, b)
on conflict do nothing;

-- The design-review account: something in Following, Saved and Activity ---

insert into public.user_follows (follower_id, followed_user_id)
select v.id, format('0000eeee-a%s-4000-8000-000000000000', lpad(b::text, 3, '0'))::uuid
from review_viewer v, (values (1),(3),(7)) as f(b)
on conflict do nothing;

insert into public.project_follows (follower_id, project_id)
select v.id, format('0000eeee-0001-4000-8000-%s', lpad(p::text, 12, '0'))::uuid
from review_viewer v, (values (1),(2),(5)) as f(p)
on conflict do nothing;

insert into public.post_likes (post_id, user_id)
select format('0000eeee-0002-4000-8000-%s', lpad(p::text, 12, '0'))::uuid, v.id
from review_viewer v, (values (1),(4),(7)) as f(p)
on conflict do nothing;

insert into public.post_bookmarks (post_id, user_id)
select format('0000eeee-0002-4000-8000-%s', lpad(p::text, 12, '0'))::uuid, v.id
from review_viewer v, (values (7),(10),(23)) as f(p)
on conflict do nothing;

-- Review people following the design-review account creates Activity items.
insert into public.user_follows (follower_id, followed_user_id)
select format('0000eeee-a%s-4000-8000-000000000000', lpad(a::text, 3, '0'))::uuid, v.id
from review_viewer v, (values (2),(5),(6)) as f(a)
on conflict do nothing;

commit;
