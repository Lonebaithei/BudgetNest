-- ============================================================
--  BudgetNest — Admin Schema Patch
--  Run this AFTER schema.sql in Supabase → SQL Editor
--  Adds: admin user_type, enquiries table, audit log,
--        and admin-level RLS policies on all existing tables
-- ============================================================


-- ────────────────────────────────────────────────────────────
--  STEP 1: Extend profiles to allow 'admin' user_type
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_user_type_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_user_type_check
    CHECK (user_type IN ('student', 'business', 'admin'));

-- Add suspended and last_seen fields
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT,
  ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;


-- ────────────────────────────────────────────────────────────
--  STEP 2: ENQUIRIES TABLE
--  Captures business contact form submissions from index.html
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.enquiries (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT        NOT NULL,
  phone         TEXT        NOT NULL,
  email         TEXT,
  category      TEXT        NOT NULL,
  description   TEXT        NOT NULL,
  heard_from    TEXT,
  status        TEXT        NOT NULL DEFAULT 'new'
                  CHECK (status IN ('new', 'contacted', 'approved', 'rejected')),
  assigned_to   UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_note    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_enquiries_status ON public.enquiries(status);
CREATE INDEX idx_enquiries_created ON public.enquiries(created_at DESC);

CREATE TRIGGER trg_enquiries_updated_at
  BEFORE UPDATE ON public.enquiries
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ────────────────────────────────────────────────────────────
--  STEP 3: AUDIT LOG
--  Tracks every admin action for accountability
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_log (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id      UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action        TEXT        NOT NULL,   -- e.g. 'approved_listing', 'suspended_user'
  target_table  TEXT,                   -- e.g. 'listings', 'profiles'
  target_id     UUID,                   -- the row that was acted on
  detail        TEXT,                   -- human-readable description
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_admin   ON public.audit_log(admin_id);
CREATE INDEX idx_audit_created ON public.audit_log(created_at DESC);


-- ────────────────────────────────────────────────────────────
--  STEP 4: ADMIN RLS POLICIES
--  Admins can read and manage ALL rows across all tables
--  (their own writes are also allowed via standard policies)
-- ────────────────────────────────────────────────────────────

-- Helper: is the current user an admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND user_type = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;


-- ── profiles ──────────────────────────────────────────────
CREATE POLICY "profiles: admin full access"
  ON public.profiles FOR ALL
  USING      (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── student_expenses ──────────────────────────────────────
CREATE POLICY "expenses: admin read all"
  ON public.student_expenses FOR SELECT
  USING (public.is_admin());


-- ── student_income ────────────────────────────────────────
CREATE POLICY "income: admin read all"
  ON public.student_income FOR SELECT
  USING (public.is_admin());


-- ── business_costs ────────────────────────────────────────
CREATE POLICY "costs: admin read all"
  ON public.business_costs FOR SELECT
  USING (public.is_admin());


-- ── business_revenue ──────────────────────────────────────
CREATE POLICY "revenue: admin read all"
  ON public.business_revenue FOR SELECT
  USING (public.is_admin());


-- ── listings ──────────────────────────────────────────────
CREATE POLICY "listings: admin full access"
  ON public.listings FOR ALL
  USING      (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── enquiries ─────────────────────────────────────────────
-- Anyone (even unauthenticated via anon key) can INSERT an enquiry
ALTER TABLE public.enquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "enquiries: public insert"
  ON public.enquiries FOR INSERT
  WITH CHECK (TRUE);

CREATE POLICY "enquiries: admin full access"
  ON public.enquiries FOR ALL
  USING      (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── audit_log ─────────────────────────────────────────────
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit: admin full access"
  ON public.audit_log FOR ALL
  USING      (public.is_admin())
  WITH CHECK (public.is_admin());


-- ────────────────────────────────────────────────────────────
--  STEP 5: CREATE YOUR FIRST ADMIN ACCOUNT
--
--  After running this file:
--  1. Register a normal account via index.html using the
--     email you want as admin (e.g. admin@budgetnest.bw)
--  2. Then run the UPDATE below — replace the email value
--     with the email you just registered with
-- ────────────────────────────────────────────────────────────

-- UPDATE public.profiles
--   SET user_type = 'admin', full_name = 'BudgetNest Admin'
--   WHERE email = 'admin@budgetnest.bw';

-- ── DONE ──────────────────────────────────────────────────
