-- ============================================================
--  BudgetNest — Supabase PostgreSQL Schema
--  Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================


-- ────────────────────────────────────────────────────────────
--  STEP 1: PROFILES TABLE
--  Extends Supabase auth.users with BudgetNest-specific fields
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type     TEXT        NOT NULL CHECK (user_type IN ('student', 'business')),
  full_name     TEXT        NOT NULL,
  -- Student-specific
  student_id    TEXT        UNIQUE,
  institution   TEXT,
  -- Business-specific
  business_name TEXT,
  category      TEXT,
  phone         TEXT,
  -- Shared
  email         TEXT        NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast user_type lookups
CREATE INDEX idx_profiles_user_type ON public.profiles(user_type);


-- ────────────────────────────────────────────────────────────
--  STEP 2: STUDENT BUDGET TABLES
-- ────────────────────────────────────────────────────────────

-- Student Expenses
CREATE TABLE IF NOT EXISTS public.student_expenses (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  category      TEXT        NOT NULL
                  CHECK (category IN (
                    'accommodation', 'food', 'transport',
                    'tuition', 'books', 'personal', 'other'
                  )),
  note          TEXT,
  date          DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Student Income (bursaries, part-time work, allowances)
CREATE TABLE IF NOT EXISTS public.student_income (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  source        TEXT        NOT NULL
                  CHECK (source IN (
                    'bursary', 'scholarship', 'part_time',
                    'family_allowance', 'other'
                  )),
  note          TEXT,
  date          DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_student_expenses_student ON public.student_expenses(student_id);
CREATE INDEX idx_student_income_student   ON public.student_income(student_id);


-- ────────────────────────────────────────────────────────────
--  STEP 3: BUSINESS BUDGET TABLES
-- ────────────────────────────────────────────────────────────

-- Business Operational Costs
CREATE TABLE IF NOT EXISTS public.business_costs (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  category      TEXT        NOT NULL
                  CHECK (category IN (
                    'rent', 'utilities', 'salaries', 'marketing',
                    'supplies', 'hosting', 'transport', 'other'
                  )),
  note          TEXT,
  date          DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Business Revenue
CREATE TABLE IF NOT EXISTS public.business_revenue (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  stream        TEXT        NOT NULL
                  CHECK (stream IN (
                    'ad_subscription', 'listing_fee',
                    'student_subscription', 'service_fee', 'other'
                  )),
  note          TEXT,
  date          DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_business_costs_business   ON public.business_costs(business_id);
CREATE INDEX idx_business_revenue_business ON public.business_revenue(business_id);


-- ────────────────────────────────────────────────────────────
--  STEP 4: LISTINGS TABLE
--  Businesses post listings; students browse them
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.listings (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  description   TEXT,
  category      TEXT        NOT NULL
                  CHECK (category IN (
                    'accommodation', 'food', 'salon', 'furniture',
                    'tuition', 'laundry', 'repairs', 'retail', 'other'
                  )),
  price         NUMERIC(10,2),
  price_period  TEXT        DEFAULT 'once',
  is_verified   BOOLEAN     DEFAULT FALSE,
  is_active     BOOLEAN     DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_listings_business  ON public.listings(business_id);
CREATE INDEX idx_listings_category  ON public.listings(category);
CREATE INDEX idx_listings_active    ON public.listings(is_active);


-- ────────────────────────────────────────────────────────────
--  STEP 5: AUTO-UPDATE updated_at TRIGGER
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_student_expenses_updated_at
  BEFORE UPDATE ON public.student_expenses
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_student_income_updated_at
  BEFORE UPDATE ON public.student_income
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_business_costs_updated_at
  BEFORE UPDATE ON public.business_costs
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_business_revenue_updated_at
  BEFORE UPDATE ON public.business_revenue
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_listings_updated_at
  BEFORE UPDATE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ────────────────────────────────────────────────────────────
--  STEP 6: AUTO-CREATE PROFILE ON SIGN UP
--  Runs automatically when a new user registers via Supabase Auth
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id, user_type, full_name, email,
    student_id, institution,
    business_name, category, phone
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'student'),
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    NEW.raw_user_meta_data->>'student_id',
    NEW.raw_user_meta_data->>'institution',
    NEW.raw_user_meta_data->>'business_name',
    NEW.raw_user_meta_data->>'category',
    NEW.raw_user_meta_data->>'phone'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ────────────────────────────────────────────────────────────
--  STEP 7: ROW LEVEL SECURITY (RLS)
--  Users can ONLY read/write their OWN rows
-- ────────────────────────────────────────────────────────────

-- Enable RLS on every table
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_expenses  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_income    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_costs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_revenue  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings          ENABLE ROW LEVEL SECURITY;


-- ── profiles ──────────────────────────────────────────────
-- Users can read/update their own profile only
CREATE POLICY "profiles: own read"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles: own update"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);


-- ── student_expenses ──────────────────────────────────────
CREATE POLICY "expenses: student owns"
  ON public.student_expenses FOR ALL
  USING      (auth.uid() = student_id)
  WITH CHECK (auth.uid() = student_id);


-- ── student_income ────────────────────────────────────────
CREATE POLICY "income: student owns"
  ON public.student_income FOR ALL
  USING      (auth.uid() = student_id)
  WITH CHECK (auth.uid() = student_id);


-- ── business_costs ────────────────────────────────────────
CREATE POLICY "costs: business owns"
  ON public.business_costs FOR ALL
  USING      (auth.uid() = business_id)
  WITH CHECK (auth.uid() = business_id);


-- ── business_revenue ──────────────────────────────────────
CREATE POLICY "revenue: business owns"
  ON public.business_revenue FOR ALL
  USING      (auth.uid() = business_id)
  WITH CHECK (auth.uid() = business_id);


-- ── listings ──────────────────────────────────────────────
-- Businesses manage their own listings
CREATE POLICY "listings: business manages own"
  ON public.listings FOR ALL
  USING      (auth.uid() = business_id)
  WITH CHECK (auth.uid() = business_id);

-- ALL authenticated users (students) can READ active listings
CREATE POLICY "listings: authenticated read active"
  ON public.listings FOR SELECT
  USING (is_active = TRUE AND auth.role() = 'authenticated');


-- ────────────────────────────────────────────────────────────
--  DONE — Schema is ready
-- ────────────────────────────────────────────────────────────
