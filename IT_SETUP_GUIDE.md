# NCF Narrative Evaluations — IT Setup Guide

**Prepared for:** NCF Information Technology  
**Application:** Narrative Evaluations System  
**Files:** `index.html`, `schema.sql`  
**Estimated setup time:** 2–4 hours

---

## What This System Is

A web application that allows NCF faculty to write, save, and submit narrative evaluations for students in their courses. Advisors can view their advisees' evaluations, students can view their own, and the Registrar and Provost's Office (PO Office) can view and export all evaluations.

**Architecture (simple on purpose):**
- **Frontend:** A single HTML file (`index.html`) served from any web server
- **Backend:** [Supabase](https://supabase.com) — a managed PostgreSQL database with built-in authentication, API, and daily backups
- **No application server required.** The HTML file talks directly to Supabase over HTTPS.

**Data storage:** All evaluation data lives in a PostgreSQL database hosted on Supabase. Nothing is stored in the browser.

---

## Option A: Supabase Cloud (Recommended to Start)

Supabase Cloud is hosted infrastructure. NCF's data lives on Supabase's servers (AWS us-east-1). Supabase is FERPA-compliant and will sign a FERPA Business Associate Agreement (BAA) — request this at `support@supabase.com` before going live.

**Cost:** ~$25/month (Pro plan required for daily backups and SAML SSO)  
**Pros:** Fastest to set up, managed backups, no server maintenance  
**Cons:** Data off-premises (mitigated by BAA)

---

## Option B: Self-Hosted Supabase (Recommended for Data Sovereignty)

Supabase is open source and can run on any university server via Docker. Data never leaves NCF infrastructure.

**Requirements:**
- A Linux server (Ubuntu 22.04 recommended), minimum 2 CPU / 4GB RAM / 50GB disk
- Docker and Docker Compose installed
- A domain name or subdomain (e.g., `eval-db.ncf.edu`) with SSL certificate

**Installation:**
```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
# Edit .env: set POSTGRES_PASSWORD, JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY
# Generate JWT_SECRET: openssl rand -base64 32
# Generate ANON_KEY and SERVICE_ROLE_KEY: see https://supabase.com/docs/guides/self-hosting
docker compose up -d
```

The Supabase dashboard will be available at `http://your-server:3000`.  
For production, put Nginx in front with SSL. See: https://supabase.com/docs/guides/self-hosting/docker

---

## Step 1: Create a Supabase Project

**For Cloud:**
1. Go to https://supabase.com and create an account
2. Click **New Project**
3. Name it `ncf-narrative-evaluations`
4. Choose the **us-east-1** region (or nearest)
5. Set a strong database password and save it securely
6. Wait ~2 minutes for provisioning

**For Self-Hosted:**  
Project is created during Docker setup above.

---

## Step 2: Run the Database Schema

1. In the Supabase Dashboard, click **SQL Editor** → **New Query**
2. Open the file `schema.sql` from this folder
3. Paste the entire contents into the SQL editor
4. Click **Run**
5. You should see: *Success. No rows returned.*

This creates all tables, security policies, and helper functions.

> ⚠️ **Important:** Do not disable Row Level Security (RLS) on any table. RLS is how FERPA access restrictions are enforced at the database level.

---

## Step 3: Configure Authentication

### Option 3A: Google SSO (Easiest — use if NCF has Google Workspace)

Faculty and staff sign in with their `@ncf.edu` Google accounts. No passwords to manage.

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or use an existing NCF project)
3. Go to **APIs & Services** → **OAuth consent screen**
   - User type: **Internal** (only @ncf.edu accounts can sign in)
   - Add scopes: `email`, `profile`
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
   - Application type: **Web application**
   - Authorized redirect URIs: `https://YOUR-SUPABASE-PROJECT.supabase.co/auth/v1/callback`
   - (For self-hosted: `https://eval-db.ncf.edu/auth/v1/callback`)
5. Copy the **Client ID** and **Client Secret**
6. In Supabase Dashboard → **Authentication** → **Providers** → **Google**
   - Enable Google provider
   - Paste Client ID and Client Secret
   - Save

### Option 3B: Email + Password (Fallback)

Works with any email. Supabase handles password hashing.

1. In Supabase Dashboard → **Authentication** → **Providers** → **Email**
2. Ensure **Enable Email provider** is on
3. Under **Email Templates**, customize the confirmation email with NCF branding if desired
4. Under **Auth** → **Settings**, set **Site URL** to your app's URL (e.g., `https://evaluations.ncf.edu`)

### Option 3C: SAML 2.0 (If NCF uses Shibboleth or Active Directory Federation Services)

Requires Supabase Pro plan. Contact Supabase support to enable SAML for your project, then:
1. Get your IdP metadata XML from your Shibboleth/ADFS administrator
2. In Supabase Dashboard → **Authentication** → **SSO Providers**, add your IdP
3. Provide Supabase's ACS URL back to your IdP administrator

---

## Step 4: Get Your API Credentials

1. In Supabase Dashboard → **Settings** → **API**
2. Copy:
   - **Project URL** (looks like `https://abcdefghij.supabase.co`)
   - **anon / public** key (the long string under "Project API keys")

> The anon key is safe to include in the HTML file. Row Level Security ensures users can only access data their role permits, even with the key visible in source code.

---

## Step 5: Configure the App

Open `index.html` in a text editor. Find this section near line 460:

```javascript
const CONFIG = {
  supabaseUrl:     'YOUR_SUPABASE_PROJECT_URL',
  supabaseAnonKey: 'YOUR_SUPABASE_ANON_KEY',
  autoSaveDelay:   3000,
  demoMode:        true,   // ← CHANGE THIS TO false
};
```

Replace the placeholders:
```javascript
const CONFIG = {
  supabaseUrl:     'https://abcdefghij.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  autoSaveDelay:   3000,
  demoMode:        false,   // ← set to false for production
};
```

Save the file.

---

## Step 6: Add Faculty and Staff to the System

Before faculty can log in and see their courses, they need a profile row in the database with the correct role assigned.

**Option A: Admin creates profiles in advance (recommended)**

In Supabase Dashboard → **SQL Editor**, run:

```sql
-- Add a faculty member
insert into public.profiles (id, email, full_name, role, is_advisor, division)
values (
  gen_random_uuid(),
  'msantos@ncf.edu',
  'Dr. Maria Santos',
  'faculty',
  true,          -- true if they are also an advisor
  'Social Sciences'
);

-- Add the Registrar
insert into public.profiles (id, email, full_name, role, is_advisor, division)
values (
  gen_random_uuid(),
  'registrar@ncf.edu',
  'Sarah Johnson',
  'registrar',
  false,
  'Registrar''s Office'
);
```

> Note: When a user logs in via Google SSO, Supabase creates a row in `auth.users` with a UUID. The app then looks up their profile by matching the `auth.users.id` to `profiles.id`. For pre-created profiles, you'll need to update the `id` to match after the user's first login:

```sql
-- After faculty member logs in for the first time, link their auth ID:
update public.profiles
set id = (select id from auth.users where email = 'msantos@ncf.edu')
where email = 'msantos@ncf.edu';
```

**Option B: Auto-provisioning**  
The app auto-creates a profile with `role = 'faculty'` on first login. An admin then updates roles as needed via SQL.

> **Roles:** `faculty`, `registrar`, `po_office` (Provost's Office — read-only oversight), `admin`, and `student`. Auto-provisioning only creates `faculty`; create `student` and `po_office` profiles explicitly. A **student** profile must set `role = 'student'` and link to its student record via `student_id`:
>
> ```sql
> -- After the student exists in public.students:
> insert into public.profiles (id, email, full_name, role, student_id)
> values (
>   gen_random_uuid(),
>   'arivera@ncf.edu',
>   'Alex Rivera',
>   'student',
>   (select id from public.students where n_number = 'N00412356')
> );
> -- After their first SSO login, link the auth id (same pattern as faculty):
> update public.profiles
> set id = (select id from auth.users where email = 'arivera@ncf.edu')
> where email = 'arivera@ncf.edu';
> ```

---

## Step 7: Import Course and Student Data from Banner

Do this at the start of each semester.

### Export from Banner

Your Banner administrator needs to export two CSV files:

**File 1: `students.csv`**  
Banner report or query with columns:
```
n_number, full_name, email, advisor_email, year_level, contracts_completed, banner_id
```
Example row: `N00412356, Alex Rivera, arivera@ncf.edu, msantos@ncf.edu, Third Year, 5, 1234567`

**File 2: `enrollments.csv`**  
```
n_number, banner_crn
```
Example row: `N00412356, 12345`

You also need to manually add course records (or add a courses export). In Supabase SQL Editor:

```sql
-- Add a course
insert into public.courses (code, name, semester_id, faculty_id, division, description, banner_crn)
values (
  'SOC 301',
  'Social Theory and Practice',
  (select id from public.semesters where term = 'Spring' and year = 2026),
  (select id from public.profiles where email = 'msantos@ncf.edu'),
  'Social Sciences',
  'Course description here...',
  '12345'   -- Banner CRN
);
```

### Import students and enrollments

1. In Supabase Dashboard → **Table Editor** → `import_students_staging`
   - Click **Insert** → **Import data from CSV**
   - Upload `students.csv`
2. Repeat for `import_enrollments_staging` with `enrollments.csv`
3. In SQL Editor, run:
   ```sql
   select public.apply_student_import();
   ```
4. Verify the output shows the expected counts.

---

## Step 8: Deploy the App to Your Web Server

The application is a single HTML file plus an `assets/` folder with three image
files (NCF logos).

### Files to deploy:
```
index.html
assets/NCF Logo Horiz BLACK REV copy.png
assets/NCF Logo Horiz BLACK copy.jpg
assets/NCF Shield RGB_no color copy.png
```

### Apache / Nginx

Copy `index.html` and the `assets/` folder to any directory served by your web server:

```bash
# Example: Apache
cp index.html /var/www/html/evaluations/
cp -r assets/ /var/www/html/evaluations/
```

The app will be accessible at `https://yourdomain.ncf.edu/evaluations/`.

### SSL

SSL is required. If not already configured:
```bash
# Ubuntu / Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d evaluations.ncf.edu
```

### Configure Supabase CORS

In Supabase Dashboard → **Settings** → **API** → **CORS**:  
Add your app's URL to the allowed origins:  
`https://evaluations.ncf.edu`

---

## Step 9: Add to the Faculty Portal

Add a link or tile to your existing faculty portal (SharePoint, Canvas, or institutional CMS):

- **URL:** `https://evaluations.ncf.edu/` (or wherever you deployed)
- **Link text:** "Narrative Evaluations"
- **Who sees it:** Faculty, Advisors, Registrar, Academic Affairs

If your portal supports iframe embedding, the app can be embedded directly. Note that SSO redirect flows may not work in some iframe contexts — a direct link is safer.

---

## Step 10: Configure Backups

### Supabase Cloud (Pro plan)
Automatic daily backups are included. Enable point-in-time recovery:
- Dashboard → **Settings** → **Database** → **Backups**
- Enable **Point in Time Recovery**
- Retention: 7 days (free) or up to 30 days (Pro)

### Self-Hosted
Set up a daily cron job:

```bash
# /etc/cron.d/ncf-eval-backup
0 2 * * * postgres pg_dump -U postgres -d postgres | gzip > /backups/ncf_eval_$(date +\%Y\%m\%d).sql.gz

# Keep 90 days of backups
0 3 * * * find /backups -name "ncf_eval_*.sql.gz" -mtime +90 -delete
```

Store backups on a separate server or NAS. Test restores quarterly.

---

## FERPA Compliance Notes

This system is designed with FERPA compliance as a core requirement:

| Requirement | How it's addressed |
|---|---|
| Access limited to authorized officials | Row Level Security in PostgreSQL enforces role-based access at the database level |
| Faculty see only their students | RLS policies verify faculty_id matches course ownership |
| Public vs. private evaluation | The public narrative is the official record; a separate **private evaluation** is shared only with the student, their advisor, and the course faculty — RLS denies it to the Registrar, PO Office, and Admin |
| Registrar has legitimate educational interest access | Registrar role has read access to all evaluations |
| Access logging | Every view and edit is recorded in the `access_log` table |
| No unauthorized disclosure | Student data is never exposed via client-side code; all access is validated server-side by RLS |
| Right to inspect records | Registrar can pull any student's full evaluation history for records requests |

**Before going live:** Request a FERPA BAA from Supabase (Cloud) or confirm your self-hosted instance is on NCF infrastructure with appropriate physical and network security controls.

---

## Ongoing Maintenance

| Task | Frequency | Who |
|---|---|---|
| Import new semester rosters from Banner | Each semester | IT or Registrar |
| Add new faculty profiles | As needed | IT admin |
| Update faculty-advisor assignments | Each semester | IT or Registrar |
| Review access log for anomalies | Monthly | IT Security |
| Test backup restoration | Quarterly | IT |
| Update Supabase (self-hosted) | Monthly | IT |
| Rotate Supabase service role key | Annually | IT |

---

## Troubleshooting

**Faculty can log in but see no courses:**  
Their profile `id` in `profiles` doesn't match their `auth.users` id. Run the link query in Step 6.

**Evaluations not saving:**  
Check browser console for CORS errors. Ensure the app's URL is in Supabase's allowed origins (Step 8).

**Google SSO redirects fail:**  
Confirm the redirect URI in Google Cloud Console exactly matches the Supabase callback URL (no trailing slash).

**"Row Level Security policy violation" errors:**  
A user is trying to access data outside their role permissions. This is the security layer working correctly. Check the user's role in the `profiles` table.

**Private evaluation visible to the Registrar or PO Office (should never happen):**  
The private evaluation is restricted to the student, their advisor, and the course faculty. Verify RLS is enabled on `evaluation_private_notes`. Run: `select tablename, rowsecurity from pg_tables where schemaname = 'public';`

---

## Questions

For questions about this system, contact the person who provided this guide.  
For Supabase platform support: https://supabase.com/support  
For Supabase self-hosting documentation: https://supabase.com/docs/guides/self-hosting
