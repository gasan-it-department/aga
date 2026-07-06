-- Run in Supabase SQL Editor.
-- Incident status/location data comes from incidents_reports.
-- Moving responder coordinates come from vehicles.vehicle_current_coordinates.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'app_main_schema'
      and tablename = 'vehicles'
  ) then
    alter publication supabase_realtime add table app_main_schema.vehicles;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'app_main_schema'
      and tablename = 'incidents_reports'
  ) then
    alter publication supabase_realtime add table app_main_schema.incidents_reports;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'test'
      and tablename = 'vehicles'
  ) then
    alter publication supabase_realtime add table test.vehicles;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'test'
      and tablename = 'incidents_reports'
  ) then
    alter publication supabase_realtime add table test.incidents_reports;
  end if;
end
$$;
