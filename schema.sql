-- ════════════════════════════════════════════════════════════════
-- NCF Narrative Evaluations — Supabase Database Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ════════════════════════════════════════════════════════════════

-- ── 1. PROFILES
-- Extends Supabase's built-in auth.users table.
-- Every faculty, advisor, registrar, and admin gets a row here.
-- Rows are created automatically on first login (handled in app),
-- or manually by an admin before first login.

create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text unique not null,
  full_name   text,
  role        text not null default 'faculty'
                check (role in ('faculty', 'registrar', 'admin', 'po_office', 'student')),
  is_advisor  boolean not null default false,
  division    text,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
  -- student_id is added by ALTER below, after the students table exists.
  -- It links a 'student'-role profile to its row in public.students.
);

comment on column public.profiles.role is
  'faculty = write evals for own courses; registrar = read-all + amend/export; '
  'po_office = Provost Office read-all oversight (no write); '
  'admin = full access; student = read-only view of own submitted evaluations';
comment on column public.profiles.is_advisor is
  'When true, this faculty member also has advisor view of their assigned advisees';


-- ── 2. SEMESTERS
-- Tracks academic terms. Mark one as is_current for default filtering.

create table public.semesters (
  id          uuid primary key default gen_random_uuid(),
  term        text not null check (term in ('Fall','Spring','Summer')),
  year        integer not null,
  is_current  boolean not null default false,
  is_active   boolean not null default true,
  created_at  timestamptz default now(),
  unique (term, year)
);

-- Seed current and recent semesters
insert into public.semesters (term, year, is_current) values
  ('Spring', 2026, true),
  ('Fall',   2025, false),
  ('Spring', 2025, false);


-- ── 3. COURSES
-- One row per course section per semester.
-- banner_crn is the Banner Course Reference Number — used to match
-- when importing roster data exported from Banner.

create table public.courses (
  id          uuid primary key default gen_random_uuid(),
  code        text not null,           -- e.g. 'SOC 301'
  name        text not null,
  semester_id uuid references public.semesters(id),
  faculty_id  uuid references public.profiles(id),
  division    text,
  description text,
  banner_crn  text,                    -- Banner CRN for roster import matching
  is_active   boolean not null default true,
  created_at  timestamptz default now()
);

create index on public.courses(faculty_id);
create index on public.courses(semester_id);


-- ── 4. STUDENTS
-- One row per student. advisor_id points to a profile row.
-- banner_id is the Banner student ID — used for roster import matching.

create table public.students (
  id          uuid primary key default gen_random_uuid(),
  n_number    text unique not null,    -- NCF N-Number, e.g. N00412356
  full_name   text not null,
  email       text unique,
  advisor_id  uuid references public.profiles(id),
  year_level  text,                    -- 'First Year', 'Second Year', etc.
  contracts_completed integer,         -- NCF contracts completed (shown alongside year)
  banner_id   text unique,             -- Banner PIDM for import matching
  is_active   boolean not null default true,
  created_at  timestamptz default now()
);

create index on public.students(advisor_id);
create index on public.students(n_number);

-- Link a student-role profile to its student record.
-- Added here (not in the profiles table above) because it references
-- public.students, which is created in this section.
alter table public.profiles
  add column student_id uuid references public.students(id) on delete set null;
create index on public.profiles(student_id);


-- ── 5. ENROLLMENTS
-- Links students to courses for a given semester.

create table public.enrollments (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.students(id) on delete cascade,
  course_id   uuid not null references public.courses(id)  on delete cascade,
  created_at  timestamptz default now(),
  unique (student_id, course_id)
);

create index on public.enrollments(course_id);
create index on public.enrollments(student_id);


-- ── 6. EVALUATIONS
-- The main evaluation record per student per course.
-- Public narrative is readable by the student's advisor.
-- Private notes are in a separate table with stricter access.

create table public.evaluations (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references public.students(id),
  course_id        uuid not null references public.courses(id),
  faculty_id       uuid not null references public.profiles(id),
  designation      text check (designation in (
                     'strong_sat','sat','marginal_sat','unsat','pass','fail'
                   )),  -- Strong Sat (SS) / Sat (S) / Marginal Sat (MS) / Unsat (U) / Pass / Fail (F)
  public_narrative text not null default '',
  status           text not null default 'draft'
                     check (status in ('draft','submitted')),
  submitted_at     timestamptz,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now(),
  unique (student_id, course_id)
);

create index on public.evaluations(faculty_id);
create index on public.evaluations(student_id);
create index on public.evaluations(course_id);
create index on public.evaluations(status);


-- ── 7. PRIVATE EVALUATION
-- A second, private narrative stored separately from the public one so Row
-- Level Security can restrict it to exactly three parties:
--   • the course faculty (author)
--   • the student (once the evaluation is submitted)
--   • the student's advisor
-- Registrar, PO Office, and Admin deliberately have NO access to this table.

create table public.evaluation_private_notes (
  id             uuid primary key default gen_random_uuid(),
  evaluation_id  uuid unique not null references public.evaluations(id) on delete cascade,
  content        text not null default '',
  updated_at     timestamptz default now()
);


-- ── 8. EVALUATION AMENDMENTS
-- When a submitted evaluation is amended, the previous version is
-- archived here before the evaluation is returned to draft status.

create table public.evaluation_amendments (
  id                    uuid primary key default gen_random_uuid(),
  evaluation_id         uuid not null references public.evaluations(id),
  designation_before    text,
  public_narrative_before text,
  private_note_before   text,
  status_before         text,
  amended_by            uuid references public.profiles(id),
  reason                text,
  created_at            timestamptz default now()
);

create index on public.evaluation_amendments(evaluation_id);


-- ── 9. FERPA ACCESS LOG
-- Records every view and edit of student records.
-- Required for FERPA compliance (34 CFR §99.32).

create table public.access_log (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references public.profiles(id),
  student_id    uuid references public.students(id),
  action        text not null,    -- 'view_evaluation', 'edit_draft', 'submit', 'export', 'view_student_record'
  resource_type text,
  resource_id   uuid,
  ip_address    text,             -- populated server-side in production
  created_at    timestamptz default now()
);

create index on public.access_log(student_id);
create index on public.access_log(user_id);
create index on public.access_log(created_at);


-- ════════════════════════════════════════════════════════════════
-- AUTO-UPDATE TRIGGERS
-- Keep updated_at columns current automatically.
-- ════════════════════════════════════════════════════════════════

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger evaluations_updated_at
  before update on public.evaluations
  for each row execute function public.set_updated_at();

create trigger private_notes_updated_at
  before update on public.evaluation_private_notes
  for each row execute function public.set_updated_at();

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- ════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- Used by Row Level Security policies below.
-- security definer = runs as the function owner, not the caller.
-- ════════════════════════════════════════════════════════════════

create or replace function public.my_role()
returns text language sql security definer stable as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_registrar_or_admin()
returns boolean language sql security definer stable as $$
  select coalesce((select role in ('registrar','admin')
                   from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.is_advisor_of(p_student_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.students
    where id = p_student_id and advisor_id = auth.uid()
  )
$$;

-- Read-all oversight roles: registrar, admin, and the Provost Office.
-- Used by SELECT policies. Note: po_office is read-only — it is deliberately
-- NOT used by INSERT/UPDATE policies, so PO Office cannot write or amend.
create or replace function public.can_read_all()
returns boolean language sql security definer stable as $$
  select coalesce((select role in ('registrar','admin','po_office')
                   from public.profiles where id = auth.uid()), false)
$$;

-- The student record linked to the current user (null for non-students).
-- Lets a student see only their own row in students/evaluations/etc.
create or replace function public.my_student_id()
returns uuid language sql security definer stable as $$
  select student_id from public.profiles where id = auth.uid()
$$;


-- ════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- This is the FERPA enforcement layer. Every table is locked down.
-- Disabling RLS on any table is a FERPA compliance risk.
-- ════════════════════════════════════════════════════════════════

alter table public.profiles                 enable row level security;
alter table public.semesters                enable row level security;
alter table public.courses                  enable row level security;
alter table public.students                 enable row level security;
alter table public.enrollments              enable row level security;
alter table public.evaluations              enable row level security;
alter table public.evaluation_private_notes enable row level security;
alter table public.evaluation_amendments    enable row level security;
alter table public.access_log               enable row level security;


-- PROFILES
create policy "own profile visible"
  on public.profiles for select
  using (id = auth.uid() or public.can_read_all());

create policy "own profile updatable"
  on public.profiles for update
  using (id = auth.uid());

create policy "admin inserts profiles"
  on public.profiles for insert
  with check (public.is_registrar_or_admin() or id = auth.uid());


-- SEMESTERS (everyone can read; only admin writes)
create policy "all authenticated read semesters"
  on public.semesters for select
  using (auth.uid() is not null);

create policy "admin manages semesters"
  on public.semesters for all
  using (public.my_role() = 'admin');


-- COURSES
create policy "faculty see own courses"
  on public.courses for select
  using (
    faculty_id = auth.uid()
    or public.can_read_all()
    or exists (
      select 1 from public.enrollments e
      join public.students s on e.student_id = s.id
      where e.course_id = courses.id and s.advisor_id = auth.uid()
    )
    -- Students see courses they are/were enrolled in (any semester).
    or exists (
      select 1 from public.enrollments e
      where e.course_id = courses.id and e.student_id = public.my_student_id()
    )
  );

create policy "admin manages courses"
  on public.courses for all
  using (public.my_role() = 'admin');


-- STUDENTS
create policy "faculty see students in their courses"
  on public.students for select
  using (
    public.can_read_all()
    or advisor_id = auth.uid()
    or id = public.my_student_id()   -- a student sees their own record
    or exists (
      select 1 from public.enrollments e
      join public.courses c on e.course_id = c.id
      where e.student_id = students.id and c.faculty_id = auth.uid()
    )
  );

create policy "admin manages students"
  on public.students for all
  using (public.my_role() = 'admin');


-- ENROLLMENTS
create policy "faculty see enrollments in their courses"
  on public.enrollments for select
  using (
    public.can_read_all()
    or student_id = public.my_student_id()   -- a student sees their own enrollments
    or exists (
      select 1 from public.courses c
      where c.id = enrollments.course_id and c.faculty_id = auth.uid()
    )
    or exists (
      select 1 from public.students s
      where s.id = enrollments.student_id and s.advisor_id = auth.uid()
    )
  );

create policy "admin manages enrollments"
  on public.enrollments for all
  using (public.my_role() = 'admin');


-- EVALUATIONS
create policy "faculty see evaluations for their courses"
  on public.evaluations for select
  using (
    faculty_id = auth.uid()
    or public.can_read_all()
    or public.is_advisor_of(student_id)
    -- A student sees only their OWN, and only once SUBMITTED (drafts stay hidden).
    or (student_id = public.my_student_id() and status = 'submitted')
  );

create policy "faculty create evaluations for their courses"
  on public.evaluations for insert
  with check (
    faculty_id = auth.uid()
    and exists (
      select 1 from public.courses c
      where c.id = course_id and c.faculty_id = auth.uid()
    )
  );

create policy "faculty update their draft evaluations"
  on public.evaluations for update
  using (
    (faculty_id = auth.uid() and status = 'draft')
    or public.is_registrar_or_admin()
  );


-- EVALUATION PRIVATE EVALUATION (the "Private Evaluation" box)
-- Shared ONLY with the course faculty (author), the student, and the student's
-- advisor. Registrar, PO Office, and Admin deliberately have NO access here —
-- this is a private channel between faculty, student, and advisor.
create policy "private evaluation visible to faculty, student, advisor"
  on public.evaluation_private_notes for select
  using (
    exists (
      select 1 from public.evaluations e
      where e.id = evaluation_private_notes.evaluation_id
        and (
          e.faculty_id = auth.uid()                                            -- course faculty (author)
          or (e.student_id = public.my_student_id() and e.status = 'submitted') -- the student (once submitted)
          or public.is_advisor_of(e.student_id)                                -- the student's advisor
        )
    )
  );

-- Only the course faculty (author) may write/edit the private evaluation.
create policy "faculty write their own private evaluation"
  on public.evaluation_private_notes for insert
  with check (
    exists (
      select 1 from public.evaluations e
      where e.id = evaluation_private_notes.evaluation_id
        and e.faculty_id = auth.uid()
    )
  );

create policy "faculty update their own private evaluation"
  on public.evaluation_private_notes for update
  using (
    exists (
      select 1 from public.evaluations e
      where e.id = evaluation_private_notes.evaluation_id
        and e.faculty_id = auth.uid()
    )
  );


-- EVALUATION AMENDMENTS
create policy "registrar and original faculty see amendments"
  on public.evaluation_amendments for select
  using (
    public.can_read_all()
    or exists (
      select 1 from public.evaluations e
      where e.id = evaluation_amendments.evaluation_id
        and e.faculty_id = auth.uid()
    )
  );

create policy "registrar inserts amendments"
  on public.evaluation_amendments for insert
  with check (public.is_registrar_or_admin());


-- ACCESS LOG
create policy "users insert own log entries"
  on public.access_log for insert
  with check (user_id = auth.uid());

create policy "registrar reads all log entries"
  on public.access_log for select
  using (public.can_read_all());


-- ════════════════════════════════════════════════════════════════
-- BANNER CSV IMPORT FUNCTION
-- Call via Supabase SQL editor after uploading a CSV from Banner.
-- See IT_SETUP_GUIDE.md for the Banner export instructions.
-- ════════════════════════════════════════════════════════════════

-- Temporary staging tables used during CSV import
create table if not exists public.import_students_staging (
  n_number   text,
  full_name  text,
  email      text,
  advisor_email text,
  year_level text,
  contracts_completed text,
  banner_id  text
);

create table if not exists public.import_enrollments_staging (
  n_number   text,
  banner_crn text
);

-- After loading CSVs into staging tables, call this to apply:
create or replace function public.apply_student_import()
returns text language plpgsql security definer as $$
declare
  inserted_students  int := 0;
  updated_students   int := 0;
  inserted_enrolls   int := 0;
begin
  -- Upsert students
  insert into public.students (n_number, full_name, email, advisor_id, year_level, contracts_completed, banner_id)
  select
    s.n_number,
    s.full_name,
    s.email,
    p.id as advisor_id,
    s.year_level,
    nullif(s.contracts_completed, '')::int,
    s.banner_id
  from public.import_students_staging s
  left join public.profiles p on lower(p.email) = lower(s.advisor_email)
  on conflict (n_number) do update set
    full_name           = excluded.full_name,
    email               = excluded.email,
    advisor_id          = excluded.advisor_id,
    year_level          = excluded.year_level,
    contracts_completed = excluded.contracts_completed,
    banner_id           = excluded.banner_id;

  get diagnostics inserted_students = row_count;

  -- Insert enrollments
  insert into public.enrollments (student_id, course_id)
  select st.id, c.id
  from public.import_enrollments_staging ie
  join public.students st on st.n_number = ie.n_number
  join public.courses   c  on c.banner_crn = ie.banner_crn
  on conflict (student_id, course_id) do nothing;

  get diagnostics inserted_enrolls = row_count;

  -- Clear staging tables
  truncate public.import_students_staging;
  truncate public.import_enrollments_staging;

  return format('Import complete: %s students upserted, %s enrollments added.',
                inserted_students, inserted_enrolls);
end;
$$;
