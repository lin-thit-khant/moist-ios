# Review content

Realistic, fictional people, Projects and posts for design reviews on **local Supabase only**. They replace the test strings in screenshots without touching existing test data.

What the seed adds:

- 8 people, 6 Projects, 28 posts and 6 comments.
- Some follows, likes and saves for the local `designreview` account, if it exists.

Every row has an id starting with `0000eeee-`.

```bash
# Add (safe to run more than once)
docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 < supabase/review/seed_review_content.sql

# Remove exactly those rows
docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 < supabase/review/remove_review_content.sql
```

For Project Lab screens, run `seed_project_lab.sql` after the seed. It needs the `designreview` account and adds 6 Projects at all three stages (two owned by that account), every post type, open and answered questions, stage history, follows and Activity.

```bash
docker exec -i supabase_db_Moist psql -U postgres -v ON_ERROR_STOP=1 < supabase/review/seed_project_lab.sql
```

The removal script removes both.

The seed is not part of `seed.sql`, so `supabase db reset` does not load it.

The review accounts have no password and cannot sign in. Posts and comments go through the same prepublication filter as the app.

Timestamps are relative to when the seed runs. Run the removal script and then the seed again to bring the posts back to the top of Home.
