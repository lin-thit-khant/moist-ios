-- RAWDEA Project Lab: a short public description for each Project.
-- It is user content, so it passes the same publication filter.

alter table public.projects
add column description text not null default '',
add constraint projects_description_length
    check (char_length(description) <= 280);

create or replace function
private.rawdea_filter_project_description()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Checked when written, and again when the Project
    -- becomes public. Post rules apply: it is free text.
    if btrim(new.description) <> ''
       and (
           tg_op = 'INSERT'
           or new.description is distinct from old.description
           or (
               (old.is_hidden or old.is_archived)
               and not new.is_hidden
               and not new.is_archived
           )
       ) then

        perform private.rawdea_assert_publication(
            'post',
            new.description
        );
    end if;

    return new;
end;
$$;

create trigger rawdea_prepublication_project_description
before insert or update of description, is_hidden, is_archived
on public.projects
for each row
execute function private.rawdea_filter_project_description();

revoke execute on function
private.rawdea_filter_project_description()
from public, anon, authenticated;

notify pgrst, 'reload schema';
