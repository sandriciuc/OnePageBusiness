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
  offers_data JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Add offers_data to existing strategies tables (safe if column already exists)
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS offers_data JSONB DEFAULT '[]'::jsonb;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS funnel_data JSONB DEFAULT '[]'::jsonb;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS dashboard_products JSONB DEFAULT '[]'::jsonb;

-- 12. Ideas table (per-user idea capture, cross-device)
CREATE TABLE IF NOT EXISTS ideas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  text TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE ideas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own ideas" ON ideas;
CREATE POLICY "Users can manage own ideas"
  ON ideas FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS ideas_updated_at ON ideas;
CREATE TRIGGER ideas_updated_at
  BEFORE UPDATE ON ideas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

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

-- 9. Services table (admin-defined offerings for calendar)
CREATE TABLE IF NOT EXISTS services (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL DEFAULT 'New Service',
  price DECIMAL(10,2) DEFAULT 0,
  duration_minutes INTEGER DEFAULT 60,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin manages own services" ON services;
CREATE POLICY "Admin manages own services"
  ON services FOR ALL
  USING (auth.uid() = admin_id)
  WITH CHECK (auth.uid() = admin_id);

-- 10. Appointments table
CREATE TABLE IF NOT EXISTS appointments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  client_name TEXT DEFAULT '',
  client_email TEXT DEFAULT '',
  service_id UUID,
  service_name TEXT DEFAULT '',
  price DECIMAL(10,2) DEFAULT 0,
  duration_minutes INTEGER DEFAULT 60,
  start_at TIMESTAMPTZ NOT NULL,
  notes TEXT DEFAULT '',
  status TEXT DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled', 'completed')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin manages own appointments" ON appointments;
CREATE POLICY "Admin manages own appointments"
  ON appointments FOR ALL
  USING (auth.uid() = admin_id)
  WITH CHECK (auth.uid() = admin_id);

-- 11. Money Flow table (one row per user per month)
CREATE TABLE IF NOT EXISTS money_flow (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  month TEXT NOT NULL,
  revenue JSONB DEFAULT '[]'::jsonb,
  fixed_expenses JSONB DEFAULT '[]'::jsonb,
  variable_expenses JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, month)
);

ALTER TABLE money_flow ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own money flow" ON money_flow;
CREATE POLICY "Users can manage own money flow"
  ON money_flow FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS money_flow_updated_at ON money_flow;
CREATE TRIGGER money_flow_updated_at
  BEFORE UPDATE ON money_flow
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Add extras column to money_flow for per-month metadata (e.g. leads count)
ALTER TABLE money_flow ADD COLUMN IF NOT EXISTS extras JSONB DEFAULT '{}'::jsonb;

-- 13. Clients table
CREATE TABLE IF NOT EXISTS clients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL DEFAULT 'New Client',
  email TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  company TEXT DEFAULT '',
  project_notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own clients" ON clients;
CREATE POLICY "Users can manage own clients"
  ON clients FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS clients_updated_at ON clients;
CREATE TRIGGER clients_updated_at
  BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 14. Client proposals table
CREATE TABLE IF NOT EXISTS client_proposals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  client_name TEXT DEFAULT '',
  offer_name TEXT DEFAULT '',
  price DECIMAL(10,2) DEFAULT 0,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'accepted', 'declined')),
  date DATE,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE client_proposals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own proposals" ON client_proposals;
CREATE POLICY "Users can manage own proposals"
  ON client_proposals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS client_proposals_updated_at ON client_proposals;
CREATE TRIGGER client_proposals_updated_at
  BEFORE UPDATE ON client_proposals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
