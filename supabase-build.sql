-- =============================================================
-- PERFECT TIMING — SUPABASE BUILD SCRIPT
-- Run this once in Supabase → SQL Editor → New Query → Run.
-- Safe to re-run; uses IF NOT EXISTS / ON CONFLICT throughout.
-- =============================================================

-- =============================================================
-- 1. ORDERS — every customer order
-- =============================================================
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

-- If you already have an orders table from earlier, this adds any missing columns
alter table orders add column if not exists meals jsonb;
alter table orders add column if not exists meal_count integer default 0;
alter table orders add column if not exists cash_payment boolean default false;
alter table orders add column if not exists subtotal numeric(10,2);
alter table orders add column if not exists discount numeric(10,2) default 0;
alter table orders add column if not exists byoc_count integer default 0;

create index if not exists idx_orders_pickup_date on orders (pickup_date);
create index if not exists idx_orders_status      on orders (status);
create index if not exists idx_orders_created_at  on orders (created_at desc);

alter table orders enable row level security;

drop policy if exists "anyone can place an order" on orders;
create policy "anyone can place an order"
  on orders for insert
  to anon, authenticated
  with check (true);

drop policy if exists "admins can read orders" on orders;
create policy "admins can read orders"
  on orders for select
  to authenticated
  using (true);

drop policy if exists "admins can update orders" on orders;
create policy "admins can update orders"
  on orders for update
  to authenticated
  using (true);

-- =============================================================
-- 2. BUSINESS SCHEDULE — single config row
-- =============================================================
create table if not exists business_schedule (
  id               integer primary key default 1,
  start_time       text not null default '05:00',
  end_time         text not null default '10:00',
  slot_minutes     integer not null default 15 check (slot_minutes in (10,15,20,30,60)),
  default_capacity integer not null default 1 check (default_capacity between 1 and 5),
  days_open        jsonb not null default '[1,2,3,4,5]',
  updated_at       timestamptz default now(),
  constraint singleton check (id = 1)
);

insert into business_schedule (id) values (1) on conflict do nothing;

alter table business_schedule enable row level security;

drop policy if exists "anyone can read business schedule" on business_schedule;
create policy "anyone can read business schedule"
  on business_schedule for select
  to anon, authenticated
  using (true);

drop policy if exists "admins can update business schedule" on business_schedule;
create policy "admins can update business schedule"
  on business_schedule for update
  to authenticated
  using (true);

-- =============================================================
-- 3. CLOSED DAYS — holidays, time off, admin days
-- =============================================================
create table if not exists closed_days (
  closed_date date primary key,
  created_at  timestamptz default now()
);

alter table closed_days enable row level security;

drop policy if exists "anyone can read closed days" on closed_days;
create policy "anyone can read closed days"
  on closed_days for select
  to anon, authenticated
  using (true);

drop policy if exists "admins can manage closed days" on closed_days;
create policy "admins can manage closed days"
  on closed_days for all
  to authenticated
  using (true);

-- =============================================================
-- 3b. CLOSED RANGES — multi-day closures (vacation, indefinite)
-- =============================================================
create table if not exists closed_ranges (
  id          uuid primary key default gen_random_uuid(),
  start_date  date not null,
  end_date    date,  -- NULL means indefinite
  created_at  timestamptz default now(),
  constraint chk_end_after_start check (end_date is null or end_date >= start_date)
);

create index if not exists idx_closed_ranges_start on closed_ranges (start_date);

alter table closed_ranges enable row level security;

drop policy if exists "anyone can read closed ranges" on closed_ranges;
create policy "anyone can read closed ranges"
  on closed_ranges for select
  to anon, authenticated
  using (true);

drop policy if exists "admins can manage closed ranges" on closed_ranges;
create policy "admins can manage closed ranges"
  on closed_ranges for all
  to authenticated
  using (true);

-- =============================================================
-- 4. SLOT SETTINGS — per-slot capacity overrides
-- =============================================================
create table if not exists slot_settings (
  slot_label  text primary key,
  capacity    integer not null default 1 check (capacity between 1 and 5),
  updated_at  timestamptz default now()
);

alter table slot_settings enable row level security;

drop policy if exists "anyone can read slot settings" on slot_settings;
create policy "anyone can read slot settings"
  on slot_settings for select
  to anon, authenticated
  using (true);

drop policy if exists "admins can manage slot settings" on slot_settings;
create policy "admins can manage slot settings"
  on slot_settings for all
  to authenticated
  using (true);

-- =============================================================
-- 5. MENU ITEMS — admin overrides for menu (name, price, available)
-- =============================================================
create table if not exists menu_items (
  code        text primary key,
  name        text,
  description text,
  price       numeric(10,2),
  category    text,
  available   boolean default true,
  updated_at  timestamptz default now()
);

alter table menu_items enable row level security;

drop policy if exists "anyone can read menu items" on menu_items;
create policy "anyone can read menu items"
  on menu_items for select
  to anon, authenticated
  using (true);

drop policy if exists "admins can manage menu items" on menu_items;
create policy "admins can manage menu items"
  on menu_items for all
  to authenticated
  using (true);

-- =============================================================
-- DONE — Now create your admin user:
-- Authentication → Users → "Add user" → Create new user
-- Check "Auto Confirm User" so you can log in right away.
-- =============================================================
