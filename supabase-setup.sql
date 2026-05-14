-- ═══════════════════════════════════════════════════════
-- ONE PAGE BUSINESS — Database Setup
-- Safe to run multiple times (idempotent)
-- ═══════════════════════════════════════════════════════

-- 1. Profiles table (extends Supabase auth)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'client')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Strategy data table (one row per client)
CREATE TABLE IF NOT EXISTS strategies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  vision TEXT DEFAULT '',
  goals TEXT DEFAULT '',
  offers TEXT DEFAULT '',
  ideal_client TEXT DEFAULT '',
  pricing TEXT DEFAULT '',
  positioning TEXT DEFAULT '',
  messaging TEXT DEFAULT '',
  funnel_architecture TEXT DEFAULT '',
  revenue_streams TEXT DEFAULT '',
  team TEXT DEFAULT '',
  systems TEXT DEFAULT '',
  quarterly_goals TEXT DEFAULT '',
  weekly_actions TEXT DEFAULT '',
  campaigns TEXT DEFAULT '',
  content_plan TEXT DEFAULT '',
  lead_generation TEXT DEFAULT '',
  sales_pipeline TEXT DEFAULT '',
  financial_target TEXT DEFAULT '',
  kpis JSONB DEFAULT '{
    "revenue": {"current": "", "target": "", "status": "on-track"},
    "leads": {"current": "", "target": "", "status": "on-track"},
    "calls": {"current": "", "target": "", "status": "on-track"},
    "conversionRate": {"current": "", "target": "", "status": "on-track"},
    "cac": {"current": "", "target": "", "status": "on-track"},
    "emailGrowth": {"current": "", "target": "", "status": "on-track"}
  }'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategies ENABLE ROW LEVEL SECURITY;

-- 4. Helper function to check admin (avoids infinite recursion in RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Profiles policies
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin can view all profiles" ON profiles;
CREATE POLICY "Admin can view all profiles"
  ON profiles FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Allow insert on signup" ON profiles;
CREATE POLICY "Allow insert on signup"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- 5. Strategies policies
DROP POLICY IF EXISTS "Users can view own strategy" ON strategies;
CREATE POLICY "Users can view own strategy"
  ON strategies FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own strategy" ON strategies;
CREATE POLICY "Users can insert own strategy"
  ON strategies FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own strategy" ON strategies;
CREATE POLICY "Users can update own strategy"
  ON strategies FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin can view all strategies" ON strategies;
CREATE POLICY "Admin can view all strategies"
  ON strategies FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admin can update all strategies" ON strategies;
CREATE POLICY "Admin can update all strategies"
  ON strategies FOR UPDATE
  USING (public.is_admin());

-- 6. Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    'client'
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.strategies (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 7. Auto-update timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS strategies_updated_at ON strategies;
CREATE TRIGGER strategies_updated_at
  BEFORE UPDATE ON strategies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 8. Projects table (admin management)
CREATE TABLE IF NOT EXISTS projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL DEFAULT 'New Project',
  objective TEXT DEFAULT '',
  due_date DATE,
  tasks JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own projects" ON projects;
CREATE POLICY "Users can manage own projects"
  ON projects FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS projects_updated_at ON projects;
CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
