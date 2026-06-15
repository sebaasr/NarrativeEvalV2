-- ════════════════════════════════════════════════════════════════
-- student360 export view
-- ----------------------------------------------------------------
-- Reshapes Narrative Evaluations into the exact columns that student360's
-- connector (connectors/evaluations_connector.py) expects, and maps student_id
-- to the NCF N-Number — which student360 uses as Student.id.
--
-- FERPA: only SUBMITTED public narratives are exposed here. The PRIVATE
-- EVALUATION is deliberately NOT included in this view, so it is never shared
-- with student360.
--
-- Run this in the Narrative Evaluations Supabase (SQL Editor) once.
-- ════════════════════════════════════════════════════════════════

create or replace view public.student360_evaluations_export as
select
  e.id::text                          as id,             -- becomes Evaluation.sourceId in student360
  s.n_number                          as student_id,     -- = student360 Student.id (N-Number)
  f.full_name                         as instructor_name,
  c.code                              as course_code,
  c.name                              as course_title,
  c.semester || ' ' || c.year         as term,           -- e.g. 'Spring 2026'
  (c.year::text ||
     case c.semester
       when 'Spring' then '01'
       when 'Summer' then '06'
       when 'Fall'   then '09'
       else '00'
     end)                             as term_code,      -- e.g. '202601'
  e.public_narrative                  as evaluation_text,
  e.designation                       as designation,    -- extra; used only if student360 adds the column
  e.status                            as status,
  e.submitted_at                      as submitted_at
from public.evaluations e
join public.students  s on s.id = e.student_id
join public.courses   c on c.id = e.course_id
join public.profiles  f on f.id = e.faculty_id
where e.status = 'submitted';

comment on view public.student360_evaluations_export is
  'Read-only export for student360. Public narratives only — the private evaluation is never exposed.';


-- ── Optional: a dedicated least-privilege login for the student360 connector ──
-- Prefer this over using the postgres/service role. It can read ONLY the export
-- view, nothing else. (The view is owned by postgres, which bypasses RLS, so the
-- reader sees all submitted evaluations through the view without table access.)
--
-- create role student360_reader login password 'CHANGE_ME_STRONG';
-- grant usage on schema public to student360_reader;
-- grant select on public.student360_evaluations_export to student360_reader;
--
-- Then point student360's EVALUATIONS_DB_URL at this role, e.g.:
--   postgresql://student360_reader:CHANGE_ME_STRONG@db.<project>.supabase.co:5432/postgres
-- and set EVALUATIONS_SOURCE=student360_evaluations_export
