-- Nanou Club — initial schema
-- Design agreed in docs/PRD.md §6 before any app code was written.
-- Every table gets RLS the moment it is created; cross-boundary writes
-- (approving an application, confirming a booking) happen in security definer
-- functions so the rules live here, not in JavaScript.

create type application_status as enum ('pending','approved','rejected');
create type approval_vote     as enum ('approve','reject');
create type membership_status as enum ('active','lapsed','cancelled');
create type voyage_status     as enum ('draft','open','underway','completed','cancelled');
create type segment_kind      as enum ('sail','stay');
create type booking_status    as enum ('requested','confirmed','waitlisted','cancelled');
create type berth_type        as enum ('double','single','couch');
create type payment_kind      as enum ('membership','segment','stay','donation');

-- ---------------------------------------------------------------- profiles

create table profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  full_name          text not null default '',
  email              text,
  phone              text,
  bio                text,
  sailing_experience text,
  avatar_url         text,
  is_admin           boolean not null default false,
  created_at         timestamptz not null default now()
);

-- Auto-create a profile row for every new auth user.
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Helper predicates used throughout the policies.
create function is_admin(uid uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from profiles where id = uid and is_admin);
$$;

create function is_active_member(uid uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from memberships where profile_id = uid and status = 'active');
$$;

-- -------------------------------------------------------------- membership

create table membership_applications (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  statement  text,
  status     application_status not null default 'pending',
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create unique index one_pending_application_per_profile
  on membership_applications (profile_id) where (status = 'pending');

create table application_approvals (
  id             uuid primary key default gen_random_uuid(),
  application_id uuid not null references membership_applications (id) on delete cascade,
  approver_id    uuid not null references profiles (id) on delete cascade,
  vote           approval_vote not null,
  comment        text,
  created_at     timestamptz not null default now(),
  unique (application_id, approver_id)
);

create table memberships (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles (id) on delete cascade,
  status     membership_status not null default 'active',
  joined_on  date not null default current_date,
  ends_on    date
);

-- An approved application becomes a membership, however it got approved
-- (second member vote or admin decision).
create function on_application_decided() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' and old.status = 'pending' then
    new.decided_at := coalesce(new.decided_at, now());
    insert into memberships (profile_id) values (new.profile_id)
    on conflict (profile_id) do update set status = 'active', ends_on = null;
  elsif new.status = 'rejected' and old.status = 'pending' then
    new.decided_at := coalesce(new.decided_at, now());
  end if;
  return new;
end $$;

create trigger application_decided
  before update of status on membership_applications
  for each row execute function on_application_decided();

-- The second 'approve' vote flips the application to approved.
-- Bootstrap rule: while the club has fewer than 2 active members, votes cannot
-- reach quorum — the admin approves applications directly instead.
create function on_approval_vote() returns trigger
language plpgsql security definer set search_path = public as $$
declare approvals int;
begin
  select count(*) into approvals
  from application_approvals
  where application_id = new.application_id and vote = 'approve';
  if approvals >= 2 then
    update membership_applications
    set status = 'approved' where id = new.application_id and status = 'pending';
  end if;
  return new;
end $$;

create trigger approval_vote_cast
  after insert on application_approvals
  for each row execute function on_approval_vote();

-- ------------------------------------------------------------------ money

-- Fees are decided by club vote; rows may exist with a null amount until the
-- club has voted. The site's job is transparency, not pricing.
create table fee_schedule (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  amount_cents       integer,
  currency           text not null default 'EUR',
  period             text not null check (period in ('monthly','annual','one_off','per_night','per_leg')),
  decided_by_vote_on date,
  active             boolean not null default true,
  notes              text
);

-- Running costs of the boat, published for cost transparency.
create table cost_items (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  category     text not null check (category in ('mooring','insurance','crew','maintenance','fuel','admin','other')),
  amount_cents integer,
  currency     text not null default 'EUR',
  period       text not null check (period in ('monthly','annual','one_off')),
  active       boolean not null default true,
  notes        text
);

create table payments (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null references profiles (id) on delete cascade,
  kind            payment_kind not null,
  amount_cents    integer not null,
  currency        text not null default 'EUR',
  method          text,
  status          text not null default 'recorded',
  paid_on         date not null default current_date,
  fee_schedule_id uuid references fee_schedule (id),
  booking_id      uuid, -- FK added after bookings exists
  notes           text,
  created_at      timestamptz not null default now()
);

-- -------------------------------------------------------------- voyages

create table harbours (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  country     text,
  lat         double precision not null,
  lon         double precision not null,
  description text,
  image_url   text,
  created_at  timestamptz not null default now()
);

create table voyages (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  description    text,
  status         voyage_status not null default 'draft',
  hero_image_url text,
  created_by     uuid references profiles (id),
  created_at     timestamptz not null default now()
);

-- One timeline table for both sailing legs and harbour stays. For a 'stay',
-- arrive_harbour_id equals depart_harbour_id and route_geojson is null.
-- Berth defaults are Nanou's real accommodation: 2 doubles, 4 singles, 1 couch.
create table voyage_segments (
  id                 uuid primary key default gen_random_uuid(),
  voyage_id          uuid not null references voyages (id) on delete cascade,
  seq                integer not null,
  kind               segment_kind not null,
  depart_harbour_id  uuid not null references harbours (id),
  arrive_harbour_id  uuid not null references harbours (id),
  start_date         date not null,
  end_date           date not null,
  route_geojson      jsonb,
  distance_nm        numeric,
  berths_double      integer not null default 2 check (berths_double >= 0),
  berths_single      integer not null default 4 check (berths_single >= 0),
  berths_couch       integer not null default 1 check (berths_couch >= 0),
  contribution_cents integer,
  notes              text,
  unique (voyage_id, seq),
  check (end_date >= start_date),
  check (kind <> 'stay' or depart_harbour_id = arrive_harbour_id)
);

create table bookings (
  id         uuid primary key default gen_random_uuid(),
  segment_id uuid not null references voyage_segments (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  berth      berth_type not null,
  people     smallint not null default 1 check (people between 1 and 2),
  -- Hot bunking is a Nanou tradition: admin may confirm past capacity by
  -- setting overbook = true. Without it, the capacity check is enforced.
  overbook   boolean not null default false,
  status     booking_status not null default 'requested',
  note       text,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  check (berth = 'double' or people = 1)
);

alter table payments
  add constraint payments_booking_fk foreign key (booking_id) references bookings (id);

-- Capacity check runs inside the confirming transaction.
create function check_berth_capacity() returns trigger
language plpgsql security definer set search_path = public as $$
declare cap int; taken int;
begin
  if new.status = 'confirmed' and (old is null or old.status <> 'confirmed') and not new.overbook then
    select case new.berth
             when 'double' then berths_double
             when 'single' then berths_single
             else berths_couch
           end
      into cap from voyage_segments where id = new.segment_id;
    select count(*) into taken from bookings
      where segment_id = new.segment_id and berth = new.berth
        and status = 'confirmed' and id <> new.id;
    if taken >= cap then
      raise exception 'No % berths left on this segment (capacity %). Set overbook to hot-bunk.',
        new.berth, cap;
    end if;
  end if;
  if new.status in ('confirmed','waitlisted','cancelled') and old is not null
     and old.status is distinct from new.status then
    new.decided_at := coalesce(new.decided_at, now());
  end if;
  return new;
end $$;

create trigger booking_capacity
  before insert or update on bookings
  for each row execute function check_berth_capacity();

-- Public availability without exposing who booked. security_invoker stays off
-- (the view runs as owner, bypassing bookings RLS) deliberately: it exposes
-- only aggregate counts.
create view segment_availability as
select s.id as segment_id, s.voyage_id, s.kind, s.seq,
       s.berths_double - count(*) filter (where b.berth = 'double' and b.status = 'confirmed') as doubles_left,
       s.berths_single - count(*) filter (where b.berth = 'single' and b.status = 'confirmed') as singles_left,
       s.berths_couch  - count(*) filter (where b.berth = 'couch'  and b.status = 'confirmed') as couches_left,
       coalesce(sum(b.people) filter (where b.status = 'confirmed'), 0) as people_confirmed
from voyage_segments s
left join bookings b on b.segment_id = s.id
group by s.id;

-- ------------------------------------------------------- boat & crew

create table boat_updates (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  body         text,
  image_url    text,
  author_id    uuid references profiles (id),
  published_at timestamptz not null default now()
);

create table crew_assignments (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  role       text not null check (role in ('skipper','mate','engineer','keeper')),
  start_on   date not null,
  end_on     date
);

-- ------------------------------------------------------------------- RLS

alter table profiles                enable row level security;
alter table membership_applications enable row level security;
alter table application_approvals   enable row level security;
alter table memberships             enable row level security;
alter table fee_schedule            enable row level security;
alter table cost_items              enable row level security;
alter table payments                enable row level security;
alter table harbours                enable row level security;
alter table voyages                 enable row level security;
alter table voyage_segments         enable row level security;
alter table bookings                enable row level security;
alter table boat_updates            enable row level security;
alter table crew_assignments        enable row level security;

-- profiles: own row fully; members see each other's names/bios; admin all.
create policy profiles_self_all on profiles
  for all using (id = auth.uid()) with check (id = auth.uid() and is_admin = (select p.is_admin from profiles p where p.id = auth.uid()));
create policy profiles_members_read on profiles
  for select using (is_active_member(auth.uid()));
create policy profiles_admin_all on profiles
  for all using (is_admin(auth.uid()));

-- applications: applicant sees & submits own; members read pending (to vote); admin all.
create policy applications_own on membership_applications
  for select using (profile_id = auth.uid());
create policy applications_submit on membership_applications
  for insert with check (profile_id = auth.uid() and status = 'pending');
create policy applications_members_read on membership_applications
  for select using (is_active_member(auth.uid()));
create policy applications_admin_all on membership_applications
  for all using (is_admin(auth.uid()));

-- approvals: active members vote, never on their own application; visible to members.
create policy approvals_members_read on application_approvals
  for select using (is_active_member(auth.uid()) or is_admin(auth.uid()));
create policy approvals_vote on application_approvals
  for insert with check (
    approver_id = auth.uid()
    and is_active_member(auth.uid())
    and not exists (select 1 from membership_applications a
                    where a.id = application_id and a.profile_id = auth.uid())
  );
create policy approvals_admin_all on application_approvals
  for all using (is_admin(auth.uid()));

-- memberships & payments: own read; admin all.
create policy memberships_own_read on memberships for select using (profile_id = auth.uid());
create policy memberships_admin_all on memberships for all using (is_admin(auth.uid()));
create policy payments_own_read on payments for select using (profile_id = auth.uid());
create policy payments_admin_all on payments for all using (is_admin(auth.uid()));

-- public catalogue: anyone can read; admin writes.
create policy fees_public_read     on fee_schedule    for select using (true);
create policy fees_admin_all       on fee_schedule    for all using (is_admin(auth.uid()));
create policy costs_public_read    on cost_items      for select using (true);
create policy costs_admin_all      on cost_items      for all using (is_admin(auth.uid()));
create policy harbours_public_read on harbours        for select using (true);
create policy harbours_admin_all   on harbours        for all using (is_admin(auth.uid()));
create policy voyages_public_read  on voyages
  for select using (status <> 'draft' or is_admin(auth.uid()));
create policy voyages_admin_all    on voyages         for all using (is_admin(auth.uid()));
create policy segments_public_read on voyage_segments
  for select using (exists (select 1 from voyages v where v.id = voyage_id
                            and (v.status <> 'draft' or is_admin(auth.uid()))));
create policy segments_admin_all   on voyage_segments for all using (is_admin(auth.uid()));

-- bookings: members create & cancel their own, read their own; admin all.
create policy bookings_own_read on bookings for select using (profile_id = auth.uid());
create policy bookings_member_create on bookings
  for insert with check (profile_id = auth.uid() and is_active_member(auth.uid())
                         and status = 'requested' and overbook = false);
create policy bookings_own_cancel on bookings
  for update using (profile_id = auth.uid())
  with check (profile_id = auth.uid() and status = 'cancelled');
create policy bookings_admin_all on bookings for all using (is_admin(auth.uid()));

-- boat updates: world reads, admin writes (crew posting comes with Phase 3 roles).
create policy updates_public_read on boat_updates for select using (true);
create policy updates_admin_all   on boat_updates for all using (is_admin(auth.uid()));

-- crew: members read, admin manages.
create policy crew_members_read on crew_assignments
  for select using (is_active_member(auth.uid()) or is_admin(auth.uid()));
create policy crew_admin_all on crew_assignments for all using (is_admin(auth.uid()));

grant select on segment_availability to anon, authenticated;
