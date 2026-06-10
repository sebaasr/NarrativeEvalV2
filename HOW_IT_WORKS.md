# How It Works — NCF Narrative Evaluations

A plain-language guide to **how the system works, how data comes in, and how it
is stored**. For technical setup steps, see [`IT_SETUP_GUIDE.md`](IT_SETUP_GUIDE.md).
For the exact database definition, see [`schema.sql`](schema.sql).

---

## 1. What the system does

Faculty write a **narrative evaluation** for each student in their courses at the
end of the semester. Each evaluation has:

- a **course designation** (Strong Sat / Sat / Marginal Sat / Unsat / Pass / Fail),
- a **public narrative** — the official feedback that becomes part of the academic record,
- a **private evaluation** — a second narrative shared only with the student, their advisor, and the course faculty.

Students read their own evaluations. Advisors read their advisees'. The Registrar
and the Provost's Office (PO Office) oversee and export. The course **description**
shown on every evaluation comes from Banner.

---

## 2. Architecture

```
   ┌──────────────────────────┐         HTTPS          ┌───────────────────────────┐
   │   Browser (index.html)   │  ───────────────────▶  │        Supabase           │
   │   • Quill editor UI      │   anon key + JWT       │  • PostgreSQL (the data)  │
   │   • role-aware views     │  ◀───────────────────  │  • Auth (Google SSO/SAML) │
   └──────────────────────────┘    only rows the       │  • Row Level Security     │
                                    user may see        │  • daily backups          │
                                                        └───────────────────────────┘
```

- **No application server.** A single static `index.html` talks directly to Supabase.
- The **anon key** is safe to ship in the HTML: the database refuses to return any
  row the signed-in user isn't allowed to see (see §6).
- It can run on **Supabase Cloud** or **self-hosted** Supabase on NCF servers
  (both covered in the IT guide).

---

## 3. Roles — who sees what

| Role | Can see | Can write |
|---|---|---|
| **Faculty** | Students/evaluations in **their own courses**; can browse/search those + their advisees by semester / AOC / professor | Create & edit evaluations for their courses (until submitted) |
| **Faculty Advisor** | All evaluations of **their advisees** — public narrative **and** private evaluation | — (read-only of advisee records) |
| **Student** | **Their own** submitted evaluations — public **and** private — across all semesters; filter by semester / area / faculty | — |
| **Registrar** | **All** evaluations (public only), the FERPA access log; CSV export; can amend | Amend submitted evaluations |
| **PO Office** | **All** evaluations (public only) — read-only oversight | — |
| **Admin** | Everything; manage courses/semesters/roles | Full |

> **The private evaluation is intentionally narrow:** only the faculty author, the
> student, and the student's advisor can read it. The Registrar, PO Office, and Admin
> **cannot** — it is a private channel, not an internal-only note.

---

## 4. The two narratives

| | Public Narrative | Private Evaluation |
|---|---|---|
| **Purpose** | Official feedback; part of the academic record | Candid guidance / advice |
| **Stored in** | `evaluations.public_narrative` | `evaluation_private_notes.content` (separate table) |
| **Who reads it** | Faculty, advisor, student, registrar, PO, admin | Faculty (author), student, advisor — **only** |

Storing the private evaluation in a **separate table** is what lets the database
grant it to exactly three parties while keeping the public record broadly visible.

---

## 5. Course designations

| Stored value | Shown as |
|---|---|
| `strong_sat` | Strong Sat (SS) |
| `sat` | Sat (S) |
| `marginal_sat` | Marginal Sat (MS) |
| `unsat` | Unsat (U) |
| `pass` | Pass |
| `fail` | Fail (F) |

> **Open decision:** today the designation is chosen in-app. The team discussed
> instead pulling it from **Banner** (it is due the day before narratives) and
> linking out. If that is decided, the dropdown becomes a read-only value + Banner link.

---

## 6. Data model (tables)

All tables live in PostgreSQL. Key ones:

| Table | What it holds | Notable fields |
|---|---|---|
| `profiles` | One row per user (faculty/registrar/po_office/admin/student) | `role`, `is_advisor`, `division`, `student_id` (links a student login to their record) |
| `semesters` | Academic terms | `term`, `year`, `is_current` |
| `courses` | One row per course section per semester | `code`, `name`, `faculty_id`, `division`, `description` (from Banner), `banner_crn` |
| `students` | One row per student | `n_number`, `advisor_id`, `year_level`, `contracts_completed`, `aoc`, `banner_id` |
| `enrollments` | Links students ↔ courses | `student_id`, `course_id` |
| `evaluations` | The main record per student per course | `designation`, `public_narrative`, `status` (draft/submitted), `submitted_at` |
| `evaluation_private_notes` | The **private evaluation** (separate for access control) | `evaluation_id`, `content` |
| `evaluation_amendments` | Archived prior versions when a submitted eval is amended | snapshot fields, `reason`, `amended_by` |
| `access_log` | FERPA audit trail — every view/edit/export | `user_id`, `student_id`, `action`, `created_at` |

Two temporary **staging** tables (`import_students_staging`,
`import_enrollments_staging`) exist only to receive Banner CSVs during import.

---

## 7. How data comes in — Banner

Banner is the system of record for people, courses, and rosters. This app **imports
from Banner each semester**; it does not write back to Banner.

```
   Banner  ──export CSV──▶  Supabase staging tables  ──apply_student_import()──▶  live tables
   (SIS)                    (import_*_staging)                                   (students, enrollments)
```

**Each semester, the Registrar/IT:**

1. **Courses** — add the term's course sections (with `banner_crn` and the Banner
   course **description**). Faculty are matched by email.
2. **Students** — upload `students.csv`:
   ```
   n_number, full_name, email, advisor_email, year_level, contracts_completed, aoc, banner_id
   ```
   Example: `N00412356, Alex Rivera, arivera@ncf.edu, msantos@ncf.edu, Third Year, 5, Sociology, 1234567`
3. **Enrollments** — upload `enrollments.csv`:
   ```
   n_number, banner_crn
   ```
4. Run `select public.apply_student_import();` — it upserts students (matching
   advisors by email and courses by `banner_crn`) and inserts enrollments, then
   clears the staging tables.

Faculty, PO Office, and student **logins** are created as `profiles` rows (see the
IT guide). On first SSO login the app links the person's auth ID to their profile.

> **Open question for the Registrar:** does Banner expose `contracts_completed`, and
> does it designate students by year? These drive what the CSV can actually carry.

---

## 8. How the data is stored

**Everything lives in one PostgreSQL database on Supabase.** Nothing of substance is
stored in the browser (demo mode uses `localStorage` only for the offline demo).

Two deployment shapes — pick one with NCF IT:

| | Supabase Cloud | Self-hosted Supabase |
|---|---|---|
| Where the data sits | Supabase (AWS us-east-1) | NCF servers (Docker) |
| Backups | Managed daily + point-in-time (Pro) | Your cron `pg_dump` (see IT guide) |
| FERPA posture | Requires a signed BAA with Supabase | Data never leaves NCF |
| Effort | Lowest | Higher (you run it) |

Retention & safety:
- **Backups:** daily; test a restore quarterly.
- **Audit:** every view/edit/export is written to `access_log` (FERPA §99.32).
- **Amendments:** editing a submitted evaluation archives the prior version in
  `evaluation_amendments` — nothing is silently overwritten.
- **Secrets:** the Supabase **service-role key** is never put in the HTML; only the
  anon key ships to the browser. Rotate the service key annually.

---

## 9. Why it's FERPA-safe (the short version)

Access is enforced **in the database**, not just in the UI, via Row Level Security
(RLS). Even with the anon key visible in the page source, the database returns only
the rows a user's role permits. The UI mirrors these rules for a clean experience,
but the database is the real gate.

> ⚠️ Never disable RLS on any table — that is the FERPA control.

---

## 10. Open decisions (to confirm)

1. **Designation source** — choose in-app, or pull from Banner + link? (§5)
2. **"AOC" meaning & search scope** — for search, "AOC" currently means the
   student's major. Browse/search is scoped to what each role may already see; the
   spec's "all evaluations of a particular AOC" could mean a wider faculty read,
   which would be a deliberate access-policy change.
3. **Banner fields** — confirm `contracts_completed` and year designation are
   available to export. (§7)
4. **Relationship to student360** — does the student-facing view live here or in
   [student360], and do they share one database?
