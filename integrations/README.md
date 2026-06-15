# Integration — student360

How the **NCF Narrative Evaluations** app feeds the **student360** dashboard.

## The picture

```
  Narrative Evaluations (Supabase)                         student360 (Next.js + Prisma)
  ┌───────────────────────────────┐   read-only Postgres   ┌──────────────────────────────┐
  │ evaluations + courses +       │  ───────────────────▶  │ connectors/evaluations_       │
  │ students + profiles           │   (the export VIEW)    │   connector.py  (already      │
  │   └─ VIEW                      │                        │   exists) → upserts into      │
  │      student360_evaluations_  │                        │   Evaluation table by sourceId│
  │      export                   │                        │ → student detail page (RBAC)  │
  └───────────────────────────────┘                        │ → AI eval-summary (Claude)    │
                                                            └──────────────────────────────┘
```

student360 was already built to ingest narrative evaluations through a connector
(like Banner/Navigate/Knack). We don't add live API calls in the UI — we feed its
existing pipeline. The **join key is the N-Number** (`students.n_number` here =
`Student.id` in student360).

## What is shared — and what is NOT

- ✅ Shared: **submitted public narratives** (+ course, instructor, term, designation).
- 🚫 Never shared: the **private evaluation**. The export view does not select it,
  so it physically cannot leave this app. (The private evaluation stays only with
  the student, their advisor, and the course faculty — enforced here by RLS.)

## Setup (one time)

1. **Create the export view** — in the Narrative Evaluations Supabase → SQL Editor,
   run [`student360_export.sql`](student360_export.sql). It builds
   `public.student360_evaluations_export` and (optionally) a least-privilege
   `student360_reader` role.

2. **Point student360's connector at it** — set these env vars in student360
   (`.env` / deployment), then let its scheduler run `connectors/run_all.py`:
   ```bash
   # Preferred: direct read-only Postgres
   EVALUATIONS_DB_URL=postgresql://student360_reader:***@db.<project>.supabase.co:5432/postgres
   EVALUATIONS_SOURCE=student360_evaluations_export

   # Or, via Supabase REST instead of a DB connection:
   # EVALUATIONS_API_URL=https://<project>.supabase.co/rest/v1
   # EVALUATIONS_API_KEY=<service_role_or_scoped_key>
   # EVALUATIONS_SOURCE=student360_evaluations_export
   ```

3. **Run the sync** — `python3 connectors/evaluations_connector.py` (or the whole
   `run_all.py`). It upserts each submitted evaluation into student360's
   `Evaluation` table, keyed by `sourceId` = this app's evaluation id. Re-runs are
   idempotent (ON CONFLICT updates text/status/submittedAt).

## Field mapping

| Narrative Evaluations (view) | student360 `Evaluation` |
|---|---|
| `id` | `sourceId` |
| `n_number` | `studentId` (→ `Student.id`) |
| faculty `full_name` | `instructorName` |
| course `code` / `name` | `courseCode` / `courseTitle` |
| `semester + year` | `term` (e.g. `Spring 2026`) |
| derived | `termCode` (e.g. `202601`) |
| `public_narrative` | `evaluationText` |
| `status` / `submitted_at` | `status` / `submittedAt` |

## Follow-ups (not in v1)

- **Designation** (SS/S/MS/U/Pass/F) is in the view but student360's `Evaluation`
  model has no column yet. Add `designation String?` + connector mapping + a badge
  to surface it.
- **Private evaluation in student360** — if advisors should read it inside
  student360 too, add a separate gated field and map it, and ensure student360
  only shows it to the student's *own* advisor (its `canViewStudent` RBAC already
  scopes to `advisorId`). Keep it out of the AI-summary corpus.
