-- Project Lab review content: stages, every post type, open and answered
-- questions, follows and Activity, for UI testing.
--
-- LOCAL SUPABASE ONLY. Run seed_review_content.sql first, then:
--   docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 < supabase/review/seed_project_lab.sql
--
-- Every row has an id starting with 0000eeee- (or belongs to one that
-- does), so remove_review_content.sql removes it. Safe to run more than
-- once: existing rows are skipped.

begin;

do $$
begin
    if not exists (select 1 from public.profiles where username = 'designreview') then
        raise exception 'Create the local designreview account first';
    end if;
    if not exists (select 1 from public.profiles where username = 'nora_patel') then
        raise exception 'Run seed_review_content.sql first';
    end if;
end;
$$;

-- Person 0 is the design-review account.
create temporary table lab_people on commit drop as
select 0 as n, id from public.profiles where username = 'designreview'
union all
select n, format('0000eeee-a%s-4000-8000-000000000000', lpad(n::text, 3, '0'))::uuid
from generate_series(1, 8) as n;

-- Projects, at their current stage ------------------------------------------

create temporary table lab_projects
(n int, owner int, name text, stage public.project_stage, started int, moved int, pinned boolean)
on commit drop;
insert into lab_projects values
    (101, 0, 'Kiln Log',           'in_progress', 60, 18, true),
    (102, 0, 'Pocket field guide', 'early',       12, 12, false),
    (103, 3, 'Rooftop compost',    'in_progress', 45,  9, false),
    (104, 2, 'Night Shift Radio',  'shipped',     90,  3, false),
    (105, 4, 'Seed swap map',      'early',        6,  6, false),
    (106, 1, 'Tidepool notes',     'in_progress', 30,  1, false);

insert into public.projects (id, user_id, name, stage, stage_changed_at, is_pinned, created_at)
select format('0000eeee-0001-4000-8000-%s', lpad(l.n::text, 12, '0'))::uuid,
       p.id, l.name, l.stage,
       now() - make_interval(days => l.moved),
       l.pinned,
       now() - make_interval(days => l.started)
from lab_projects l join lab_people p on p.n = l.owner
on conflict (id) do nothing;

-- Follows come before stage history so followers hear about it ---------------

create temporary table lab_new_follows on commit drop as
with added as (
    insert into public.project_follows (follower_id, project_id)
    select p.id, format('0000eeee-0001-4000-8000-%s', lpad(f.project::text, 12, '0'))::uuid
    from (values
        (0, 103), (0, 104), (0, 105), (0, 106),
        (1, 101), (3, 101), (4, 101), (2, 102),
        (1, 103), (5, 104), (6, 106)
    ) as f(person, project)
    join lab_people p on p.n = f.person
    on conflict do nothing
    returning follower_id, project_id
)
select * from added;

-- Posts ---------------------------------------------------------------------
-- (n, author, project, kind, hours ago, content)

create temporary table lab_posts
(n int, author int, project int, kind public.post_kind, hours int, content text)
on commit drop;
insert into lab_posts values
    (101, 0, 101, 'note',     1380, 'A glaze log where failed tiles are as visible as the good ones.'),
    (102, 0, 101, 'note',      960, 'Sketching a shelf layout so tiles fire in rows of six.'),
    (103, 0, 101, 'progress',  432, 'First full firing logged. Twelve tiles, five keepers, and a page of notes about the other seven.'),
    (104, 0, 101, 'decision',  216, 'Dropping the matte white glaze. It crawls on every tile.'),
    (105, 0, 101, 'question',   72, 'Should I switch to the cheaper clay body for the next batch, or keep testing this one?'),
    (106, 0, 101, 'progress',    2, 'Third firing of the celadon test tiles. Cone 10, slow cool. The crackle finally matches the first batch.'),
    (107, 0, 102, 'note',      240, 'A field guide small enough for a back pocket, one tree per page.'),
    (108, 0, 102, 'question',   20, 'Drawings or photos for the leaf pages? Photos are faster, drawings explain more.'),

    (110, 3, 103, 'note',      900, 'Three bins on the roof, one rule: nothing that smells by Friday.'),
    (111, 3, 103, 'progress',  216, 'The first bin reached 55 degrees. It is officially working.'),
    (112, 3, 103, 'decision',   96, 'No more cooked rice. It turns the middle into a brick.'),
    (113, 3, 103, 'question',    5, 'How often are you turning your pile in the rainy season?'),

    (120, 2, 104, 'progress',  500, 'Episode 12 recorded on the night platform. The trains do half the editing.'),
    (121, 2, 104, 'decision',  200, 'Fifteen minutes per episode, no longer. I cut better than I add.'),
    (122, 2, 104, 'progress',   72, 'All twenty episodes are out. This one is done.'),

    (130, 4, 105, 'note',      140, 'A map of who has spare seeds within walking distance.'),
    (131, 4, 105, 'question',   26, 'What should a listing show besides the plant name?'),
    (132, 4, 105, 'progress',    4, 'First sketch is up. Eleven neighbours, nineteen kinds of seed.'),

    (140, 1, 106, 'note',      600, 'Learning to draw what lives in the rock pools.'),
    (141, 1, 106, 'question',   30, 'Is it worth logging tide height on every visit, or only on unusual days?'),
    (142, 1, 106, 'progress',   24, 'Thirty pools mapped. Moving from sketches to a proper log.');

insert into public.posts (id, user_id, project_id, kind, content, created_at)
select format('0000eeee-0002-4000-8000-%s', lpad(l.n::text, 12, '0'))::uuid,
       p.id,
       format('0000eeee-0001-4000-8000-%s', lpad(l.project::text, 12, '0'))::uuid,
       l.kind, l.content,
       now() - make_interval(hours => l.hours)
from lab_posts l join lab_people p on p.n = l.author
on conflict (id) do nothing;

-- Stage history --------------------------------------------------------------

insert into public.project_stage_events
    (id, project_id, from_stage, to_stage, post_id, created_at)
select format('0000eeee-0004-4000-8000-%s', lpad(e.n::text, 12, '0'))::uuid,
       format('0000eeee-0001-4000-8000-%s', lpad(e.project::text, 12, '0'))::uuid,
       e.from_stage::public.project_stage,
       e.to_stage::public.project_stage,
       format('0000eeee-0002-4000-8000-%s', lpad(e.post::text, 12, '0'))::uuid,
       now() - make_interval(days => e.days)
from (values
    (1, 101, 'early',       'in_progress', 103, 18),
    (2, 103, 'early',       'in_progress', 111,  9),
    (3, 104, 'early',       'in_progress', 120, 21),
    (4, 104, 'in_progress', 'shipped',     122,  3),
    (5, 106, 'early',       'in_progress', 142,  1)
) as e(n, project, from_stage, to_stage, post, days)
on conflict (id) do nothing;

-- Answers and comments -------------------------------------------------------

insert into public.post_comments (id, post_id, user_id, content, created_at)
select format('0000eeee-0003-4000-8000-%s', lpad(c.n::text, 12, '0'))::uuid,
       format('0000eeee-0002-4000-8000-%s', lpad(c.post::text, 12, '0'))::uuid,
       p.id, c.content,
       now() - make_interval(hours => c.hours)
from (values
    -- Your open question: use Mark as best here.
    (101, 105, 1, 60, 'Keep this one for one more firing. You only just matched the crackle, so changing clay now muddies the test.'),
    (102, 105, 3, 48, 'Fire two test tiles of each side by side first. Shrinkage is what will catch you.'),
    (103, 105, 4, 30, 'What does the cheaper one cost per kilo? It might not matter at your volume.'),
    (104, 105, 8, 10, 'Switch. You can always switch back.'),
    (105, 106, 5,  1, 'That surface is lovely. How slow was the cool?'),
    -- Answered questions.
    (110, 131, 0, 20, 'The month the seeds were saved. Old seed is the usual disappointment.'),
    (111, 131, 2, 18, 'Whether pickup is outside or by knocking.'),
    (112, 141, 0, 22, 'Log it every time. The unusual days only make sense against the ordinary ones.'),
    (113, 141, 6, 20, 'Only unusual days, or you will give up by week three.'),
    -- One open question with an answer, one comment on a note.
    (120, 113, 6,  3, 'Once a week, and I add dry leaves each time.'),
    (121, 110, 0, 24, 'Friday is a good rule. Mine is Sunday and it shows.')
) as c(n, post, person, hours, content)
join lab_people p on p.n = c.person
on conflict (id) do nothing;

-- Choosing these notifies the design-review account.
update public.posts p
set best_reply_id = format('0000eeee-0003-4000-8000-%s', lpad(a.comment::text, 12, '0'))::uuid
from (values (131, 110), (141, 112)) as a(post, comment)
where p.id = format('0000eeee-0002-4000-8000-%s', lpad(a.post::text, 12, '0'))::uuid
  and p.best_reply_id is null;

-- Likes on your posts ---------------------------------------------------------

insert into public.post_likes (post_id, user_id)
select format('0000eeee-0002-4000-8000-%s', lpad(l.post::text, 12, '0'))::uuid, p.id
from (values (106, 1), (106, 3), (106, 5), (104, 2), (105, 4), (108, 6)) as l(post, person)
join lab_people p on p.n = l.person
on conflict do nothing;

-- Descriptions ----------------------------------------------------------------

update public.projects p
set description = d.description
from (values
    (101, 'Glaze tests, failures included. One potter, one kiln, a lot of tiles.'),
    (103, 'Turning kitchen scraps into soil, four floors up.'),
    (104, 'A weekly show recorded on train platforms.')
) as d(n, description)
where p.id = format('0000eeee-0001-4000-8000-%s', lpad(d.n::text, 12, '0'))::uuid
  and p.description = '';

-- Home shows these as already read: one Project caught up, one partly new ----

update public.project_follows f
set last_seen_at = now()
from lab_new_follows n, lab_people v
where v.n = 0
  and n.follower_id = v.id
  and f.follower_id = n.follower_id
  and f.project_id = n.project_id
  and f.project_id = '0000eeee-0001-4000-8000-000000000104';

commit;
