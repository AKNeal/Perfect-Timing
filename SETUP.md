# Perfect Timing — Setup Guide

This is the step-by-step for going live. Plan 20-30 minutes.

---

## Overview of what you're setting up

1. **Supabase** — free-tier database that stores your orders and handles staff login
2. **Formspree** — free-tier service that sends you an email when a new order comes in
3. **GitHub** — hosts the code
4. **Vercel** — serves the live site at `perfecttiming.space`

You only do all of this once. After that, editing the site is just "change a file, push to GitHub, Vercel auto-deploys."

---

## PART 1 — Set up Supabase (the database)

### Step 1: Create the project

1. Go to **https://supabase.com** and sign up (free).
2. Click **"New project"**.
3. Name it `perfect-timing`.
4. Set a database password (save this in a password manager — you rarely need it, but don't lose it).
5. Pick a region close to you (US West is good for Alaska).
6. Click **"Create new project"** and wait ~2 minutes for it to provision.

### Step 2: Run the setup SQL

1. In your Supabase project dashboard, click **"SQL Editor"** in the left sidebar.
2. Click **"New query"**.
3. Paste the ENTIRE block below and click **"Run"**:

```sql
-- =============================================================
-- Perfect Timing — Database schema
-- =============================================================

-- Orders table
create table if not exists orders (
  id              uuid primary key default gen_random_uuid(),
  customer_name   text not null,
  customer_phone  text not null,
  pickup_date     date not null,
  pickup_slot     text not null,
  items           jsonb not null,
  items_summary   text,
  meals           jsonb,
  meal_count      integer default 0,
  cash_payment    boolean default false,
  subtotal        numeric(10,2),
  discount        numeric(10,2) default 0,
  notes           text,
  subscription    boolean default false,
  byoc_count      integer default 0,
  total           numeric(10,2) not null,
  status          text default 'pending',
  created_at      timestamptz default now()
);

-- Index for faster dashboard queries
create index if not exists idx_orders_pickup_date on orders (pickup_date);
create index if not exists idx_orders_status on orders (status);
create index if not exists idx_orders_created_at on orders (created_at desc);

-- =============================================================
-- Row Level Security (RLS) — controls who can do what
-- =============================================================
alter table orders enable row level security;

-- Allow ANYONE (public, unauthenticated) to INSERT an order.
-- This is how customers submit orders from the website.
create policy "anyone can place an order"
  on orders for insert
  to anon
  with check (true);

-- Allow only signed-in admin users to READ orders.
create policy "admin can read orders"
  on orders for select
  to authenticated
  using (true);

-- Allow only signed-in admin users to UPDATE orders (change status).
create policy "admin can update orders"
  on orders for update
  to authenticated
  using (true);

-- Note: no DELETE policy. Orders can't be deleted from the UI
-- (by design — keeps history). You can delete manually via the
-- Supabase dashboard if you ever need to.
-- =============================================================
-- Business schedule (single row; admin edits via Settings UI)
-- =============================================================
create table if not exists business_schedule (
  id              integer primary key default 1,
  start_time      text not null default '05:00',    -- "HH:MM" 24h
  end_time        text not null default '10:00',    -- "HH:MM" 24h
  slot_minutes    integer not null default 15 check (slot_minutes in (10,15,20,30,60)),
  default_capacity integer not null default 1 check (default_capacity between 1 and 5),
  days_open       jsonb not null default '[1,2,3,4,5]',  -- 0=Sun ... 6=Sat
  updated_at      timestamptz default now(),
  constraint singleton check (id = 1)
);

insert into business_schedule (id) values (1) on conflict do nothing;

alter table business_schedule enable row level security;

create policy "anyone can read business schedule"
  on business_schedule for select
  to anon, authenticated
  using (true);

create policy "admins can update business schedule"
  on business_schedule for update
  to authenticated
  using (true);

-- =============================================================
-- Closed days (holidays, time off, admin days)
-- =============================================================
create table if not exists closed_days (
  closed_date date primary key,
  created_at  timestamptz default now()
);

alter table closed_days enable row level security;

create policy "anyone can read closed days"
  on closed_days for select
  to anon, authenticated
  using (true);

create policy "admins can manage closed days"
  on closed_days for all
  to authenticated
  using (true);

-- =============================================================
-- Slot capacity overrides (per-slot capacity beyond the default)
-- =============================================================
create table if not exists slot_settings (
  slot_label  text primary key,                                   -- e.g. "5:00 AM"
  capacity    integer not null default 1 check (capacity between 1 and 5),
  updated_at  timestamptz default now()
);

alter table slot_settings enable row level security;

create policy "anyone can read slot settings"
  on slot_settings for select
  to anon, authenticated
  using (true);

create policy "admins can manage slot settings"
  on slot_settings for all
  to authenticated
  using (true);

-- =============================================================
-- Menu item overrides (optional — for menu management in admin)
-- =============================================================
create table if not exists menu_items (
  code         text primary key,
  name         text,
  description  text,
  price        numeric(10,2),
  category     text,
  available    boolean default true,
  updated_at   timestamptz default now()
);

alter table menu_items enable row level security;

create policy "anyone can read menu items"
  on menu_items for select
  to anon, authenticated
  using (true);

create policy "admins can manage menu items"
  on menu_items for all
  to authenticated
  using (true);
```

4. You should see "Success. No rows returned."

### Step 2.5: If you already set up the database before April 24, 2026

If your `orders` table already exists, you need to add the new column and create the new tables. In the SQL Editor, run:

```sql
-- BYOC column (idempotent)
alter table orders add column if not exists byoc_count integer default 0;
alter table orders add column if not exists meals jsonb;
alter table orders add column if not exists meal_count integer default 0;
alter table orders add column if not exists cash_payment boolean default false;
alter table orders add column if not exists subtotal numeric(10,2);
alter table orders add column if not exists discount numeric(10,2) default 0;

-- Business schedule (singleton config row)
create table if not exists business_schedule (
  id              integer primary key default 1,
  start_time      text not null default '05:00',
  end_time        text not null default '10:00',
  slot_minutes    integer not null default 15 check (slot_minutes in (10,15,20,30,60)),
  default_capacity integer not null default 1 check (default_capacity between 1 and 5),
  days_open       jsonb not null default '[1,2,3,4,5]',
  updated_at      timestamptz default now(),
  constraint singleton check (id = 1)
);
insert into business_schedule (id) values (1) on conflict do nothing;
alter table business_schedule enable row level security;
create policy "anyone can read business schedule" on business_schedule for select to anon, authenticated using (true);
create policy "admins can update business schedule" on business_schedule for update to authenticated using (true);

-- Closed days
create table if not exists closed_days (
  closed_date date primary key,
  created_at timestamptz default now()
);
alter table closed_days enable row level security;
create policy "anyone can read closed days" on closed_days for select to anon, authenticated using (true);
create policy "admins can manage closed days" on closed_days for all to authenticated using (true);

-- Slot capacity overrides
create table if not exists slot_settings (
  slot_label text primary key,
  capacity integer not null default 1 check (capacity between 1 and 5),
  updated_at timestamptz default now()
);
alter table slot_settings enable row level security;
create policy "anyone can read slot settings" on slot_settings for select to anon, authenticated using (true);
create policy "admins can manage slot settings" on slot_settings for all to authenticated using (true);

-- Menu items (for admin menu mgmt)
create table if not exists menu_items (
  code text primary key,
  name text, description text, price numeric(10,2),
  category text, available boolean default true,
  updated_at timestamptz default now()
);
alter table menu_items enable row level security;
create policy "anyone can read menu items" on menu_items for select to anon, authenticated using (true);
create policy "admins can manage menu items" on menu_items for all to authenticated using (true);
```

If you're doing a fresh setup, skip this — Step 2 already included everything.

### Step 3: Create your staff login

1. Still in Supabase, click **"Authentication"** in the left sidebar, then **"Users"**.
2. Click **"Add user"** → **"Create new user"**.
3. Enter your email and a strong password (save this in a password manager).
4. Check **"Auto Confirm User"** (so you don't have to verify email).
5. Click **"Create user"**.

**Repeat this step for every admin user** you want to give dashboard access to. You can add/remove admin users anytime from this same screen.

### Step 4: Grab your API keys

1. Click **"Project Settings"** (gear icon at the bottom of the left sidebar) → **"API"**.
2. Copy two values:
   - **Project URL** (looks like `https://abcdefghijk.supabase.co`)
   - **anon / public key** (a long string starting with `eyJ...`) — this is safe to put in client-side code

Keep these open in a tab — you'll paste them into the code in Part 3.

---

## PART 2 — Set up Formspree (email alerts)

1. Go to **https://formspree.io** and sign up (free — 50 submissions/month on free tier, plenty to start).
2. Click **"+ New Form"**.
3. Name it `Perfect Timing Orders`.
4. Set the email address where order alerts should go.
5. Click **"Create Form"**.
6. On the form page, look for the **form endpoint URL**. It'll look like `https://formspree.io/f/xyznabcd` — copy the part after `/f/` (e.g. `xyznabcd`). That's your Form ID.
7. Formspree will send you a confirmation email the first time a real order comes in — just click the link to activate it.

---

## PART 3 — Plug the keys into the code

### In `index.html`

Open the file and find this block near the top of the `<script>` tag:

```javascript
const SUPABASE_URL       = 'YOUR_SUPABASE_URL_HERE';
const SUPABASE_ANON_KEY  = 'YOUR_SUPABASE_ANON_KEY_HERE';
const FORMSPREE_FORM_ID  = 'YOUR_FORMSPREE_FORM_ID_HERE';
```

Replace all three strings with your actual values:

```javascript
const SUPABASE_URL       = 'https://abcdefghijk.supabase.co';
const SUPABASE_ANON_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
const FORMSPREE_FORM_ID  = 'xyznabcd';
```

### In `admin/index.html`

Find the same block (Formspree isn't needed here, just Supabase):

```javascript
const SUPABASE_URL       = 'YOUR_SUPABASE_URL_HERE';
const SUPABASE_ANON_KEY  = 'YOUR_SUPABASE_ANON_KEY_HERE';
```

Paste the SAME two Supabase values.

---

## PART 4 — Deploy to Vercel

1. Create a new private GitHub repo (call it `perfect-timing` or similar).
2. Push this folder's contents to the repo (so `index.html`, `admin/index.html`, etc. are at the repo root).
3. Go to **https://vercel.com** → **"Add New"** → **"Project"** → import your GitHub repo.
4. Framework preset: **Other**. Leave build/output settings blank.
5. Click **"Deploy"**.
6. After deploy finishes: **Settings** → **Domains** → add `perfecttiming.space` and follow the DNS instructions.

---

## PART 5 — Test the whole flow

1. Open `perfecttiming.space` (or the Vercel preview URL).
2. Build a test order, fill in a name/phone (use your real phone so you can verify), and submit.
3. **Check 3 things:**
   - The confirmation popup should say "See you then" (NO red error warning).
   - You should get an email within ~30 seconds.
   - In Supabase dashboard → **Table editor** → `orders` table, your order should appear.
4. Go to `perfecttiming.space/admin`. Sign in with the admin email/password you created in Part 1, Step 3.
5. Your test order should appear in the dashboard.
6. Click it to expand. Click **"Prepping"** then **"Complete"** to test status changes.

If all that works, you're live. 🎉

---

## How order alerts work (answering "how does the system alert us?")

**Two alerts per order, both automatic:**

1. **Email** — Formspree sends an email to the address you configured (in Part 2) with the customer name, phone, date, slot, items, total, and any notes. This is your primary alert.
2. **Dashboard** — The order appears in the admin dashboard at `/admin` immediately. Click the "↻ Refresh" button to see new orders (or refresh the page). Orders default to showing "Pending" orders for "Tomorrow" pickup.

**Recommended routine:**

- Before you go to bed each night, open `/admin`, filter to "Pending" + "Pickup tomorrow", and see what needs to be prepped overnight (slow cooker stuff).
- In the morning, filter to "Pending" + "Pickup today" — this is your prep list for the day.
- Mark orders "Prepping" when you start, "Complete" when the customer picks up.

---

## Troubleshooting

**"Backend not configured yet" error on staff login page**
You didn't replace the placeholders in `admin/index.html`. See Part 3.

**Order submits with red "⚠ Something went wrong" warning**
Either Supabase or Formspree isn't set up right. The error message tells you which. Double-check that:
- Your Supabase URL starts with `https://` and ends with `.supabase.co`
- Your anon key starts with `eyJ`
- Your Formspree ID is just the short string (e.g. `xyznabcd`), not the full URL
- The SQL in Part 1, Step 2 ran successfully (check the Table Editor — you should see an `orders` table)

**"Invalid login credentials" on staff sign-in**
Make sure the email is confirmed. Go to Supabase → Authentication → Users, find the user, and check "Email confirmed." If it's not, click the user and toggle "Auto Confirm."

**Orders submit but I don't get an email**
Check your spam folder. Also, on Formspree's first submission, they send a confirmation email to you to activate the form. If you never clicked that, orders will silently fail. Log into Formspree → Forms → check status.

**Can I edit menu items without breaking things?**
Yes — menu items live in JavaScript arrays near the bottom of `index.html` (search for `const coffees`, `const foods`, `const addons`). If you change menu items, you MUST also update the matching arrays in `admin/index.html` so the recipe panel shows the new items.

---

## Security notes (important, read this)

- The `SUPABASE_ANON_KEY` is safe to put in public-facing code. That's what the "anon" in the name means — it's meant for client-side use. What prevents abuse is the Row Level Security policies in the SQL above: anon users can only INSERT into orders (place an order), not SELECT (read) or UPDATE or DELETE them.
- Only signed-in admin users (created in Authentication → Users) can read and update orders.
- **Never** commit a `.env` file or anything containing your Supabase **service_role** key. That one has full admin access. Only the anon/public key goes in the code.
- If you ever need to reset a staff password, go to Supabase → Authentication → Users → click the user → "Send password recovery."
- If you ever think a key has leaked, go to Supabase → Project Settings → API → "Reset API keys" and update the values in both `index.html` and `admin/index.html`.
