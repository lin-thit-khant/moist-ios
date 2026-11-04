
SELECT has_table_privilege(
    'authenticated',
    'public.posts',
    'UPDATE'
) AS can_update_posts;
