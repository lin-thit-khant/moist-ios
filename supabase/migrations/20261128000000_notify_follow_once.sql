-- Unfollowing and following again must not repeat the same Activity row.

create or replace function private.notify_user_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if new.follower_id <> new.followed_user_id
       and not exists (
           select 1
           from public.notifications n
           where n.recipient_id = new.followed_user_id
             and n.actor_id = new.follower_id
             and n.kind = 'user_follow'
       ) then

        insert into public.notifications (
            recipient_id,
            actor_id,
            kind
        )
        values (
            new.followed_user_id,
            new.follower_id,
            'user_follow'
        );

    end if;

    return new;

end;
$$;

create or replace function private.notify_project_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    project_owner_id uuid;
begin

    select p.user_id
    into project_owner_id
    from public.projects p
    where p.id = new.project_id;

    if project_owner_id is not null
       and project_owner_id <> new.follower_id
       and not exists (
           select 1
           from public.notifications n
           where n.recipient_id = project_owner_id
             and n.actor_id = new.follower_id
             and n.kind = 'project_follow'
             and n.project_id = new.project_id
       ) then

        insert into public.notifications (
            recipient_id,
            actor_id,
            kind,
            project_id
        )
        values (
            project_owner_id,
            new.follower_id,
            'project_follow',
            new.project_id
        );

    end if;

    return new;

end;
$$;
