# NCF Narrative Evaluations

A web application for New College of Florida faculty to write, save, and submit
end-of-semester **narrative evaluations** for students. Advisors can view their
advisees' evaluations, students can view their own, and the Registrar / Provost's
Office have oversight and export access.

## Architecture

- **Frontend:** a single `index.html` file (Quill rich-text editor) — no build step.
- **Backend:** [Supabase](https://supabase.com) (managed PostgreSQL + Auth) over HTTPS.
- **No application server.** The page talks directly to Supabase; Row Level Security
  (RLS) is the FERPA enforcement layer.

The app ships in **demo mode** (`CONFIG.demoMode = true` in `index.html`), which stores
data in the browser's `localStorage` so it can be explored with no backend.

## Roles

| Role | Access |
|---|---|
| **Faculty** | Write/submit evaluations for students in their own courses |
| **Faculty Advisor** | View submitted public narratives for their advisees (never private notes) |
| **Student** | View *their own* submitted evaluations, grouped by semester (no private notes, no drafts) |
| **Registrar** | Read-all, amend, FERPA access log, CSV export |
| **PO Office** | Provost's Office — read-all oversight (read-only, no editing) |
| **Admin** | Full access |

Each evaluation has a **course designation** (Strong Sat / Sat / Marginal Sat / Unsat /
INC), a **public narrative** (part of the academic record), and **private/internal
notes** (faculty + registrar/PO/admin only — never visible to advisors or students).

## Try the demo

Open `index.html` in a browser and pick a user from the role selector.
Suggested walkthrough: **Faculty → Student → PO Office → Registrar**.

To reset demo data, run `resetDemoData()` in the browser console.

## How it works

See [`HOW_IT_WORKS.md`](HOW_IT_WORKS.md) for a plain-language overview — architecture,
roles & FERPA access, the data model, how data comes in from Banner, and how it's stored.

## Production setup

See [`IT_SETUP_GUIDE.md`](IT_SETUP_GUIDE.md) for the full Supabase + auth + Banner-import
guide. Database schema lives in [`schema.sql`](schema.sql).

> ⚠️ Do not disable RLS on any table — it is how FERPA access restrictions are enforced.
