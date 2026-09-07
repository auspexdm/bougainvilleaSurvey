-- Bougainvillea — guest feedback & quality control
-- Paste this whole file into Supabase → SQL Editor → Run. Safe to run once.

-- ---------------------------------------------------------------- tables

create table if not exists surveys (
  id             uuid primary key,
  room           text        not null,
  at             timestamptz not null default now(),
  recommendation text,
  comments       text        default '',
  avg            numeric(3,2),
  has_low        boolean     default false
);

create table if not exists survey_ratings (
  id         bigserial primary key,
  survey_id  uuid not null references surveys(id) on delete cascade,
  item       text not null,          -- e.g. room_clean
  department text not null,          -- e.g. Room / Housekeeping
  score      smallint not null check (score between 1 and 5)
);

create table if not exists issues (
  id          uuid primary key default gen_random_uuid(),
  survey_id   uuid references surveys(id) on delete cascade,
  room        text not null,
  department  text not null,
  category    text not null,
  tags        text[] default '{}',
  other_text  text   default '',
  rating      smallint,
  at          timestamptz not null default now(),
  status      text not null default 'Open'
              check (status in ('Open','In Progress','Resolved','Closed')),
  assigned_to text default '',
  notes       text default '',
  resolved_at timestamptz
);

create table if not exists settings (
  id                    int primary key default 1 check (id = 1),
  resort_name           text default 'Bougainvillea',
  logo_url              text default '',
  google_review_url     text default '',
  brand_colour          text default '#70235E',
  survey_length         text default 'short' check (survey_length in ('short','full')),
  low_threshold         smallint default 3,
  resolution_target_hrs int default 2,
  report_time           text default '21:00',
  base_url              text default ''
);

insert into settings (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------- indexes

create index if not exists surveys_at_idx        on surveys (at desc);
create index if not exists surveys_room_idx      on surveys (room);
create index if not exists ratings_survey_idx    on survey_ratings (survey_id);
create index if not exists ratings_item_idx      on survey_ratings (item);
create index if not exists issues_at_idx         on issues (at desc);
create index if not exists issues_status_idx     on issues (status);
create index if not exists issues_room_idx       on issues (room);

-- ---------------------------------------------------------------- security
-- Guests are anonymous: they may write, never read.
-- Staff must be signed in: they may read everything and update issues.

alter table surveys        enable row level security;
alter table survey_ratings enable row level security;
alter table issues         enable row level security;
alter table settings       enable row level security;

drop policy if exists guest_insert_survey  on surveys;
drop policy if exists staff_read_survey    on surveys;
create policy guest_insert_survey  on surveys        for insert to anon          with check (true);
create policy staff_read_survey    on surveys        for select to authenticated using (true);

drop policy if exists guest_insert_rating on survey_ratings;
drop policy if exists staff_read_rating   on survey_ratings;
create policy guest_insert_rating  on survey_ratings for insert to anon          with check (true);
create policy staff_read_rating    on survey_ratings for select to authenticated using (true);

drop policy if exists guest_insert_issue on issues;
drop policy if exists staff_read_issue   on issues;
drop policy if exists staff_update_issue on issues;
create policy guest_insert_issue   on issues         for insert to anon          with check (true);
create policy staff_read_issue     on issues         for select to authenticated using (true);
create policy staff_update_issue   on issues         for update to authenticated using (true) with check (true);

-- Everyone needs to read settings (the survey needs the review URL and threshold).
-- Only signed-in staff can change them.
drop policy if exists anyone_read_settings on settings;
drop policy if exists staff_write_settings on settings;
create policy anyone_read_settings on settings for select to anon, authenticated using (true);
create policy staff_write_settings on settings for update to authenticated using (true) with check (true);
