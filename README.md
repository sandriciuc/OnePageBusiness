# One Page Business

Strategic clarity system for entrepreneurs.
Built by Smaranda Andriciuc — Clarity · Systems · Results

## Tech Stack
- Single HTML file (index.html) with vanilla JS
- Supabase for authentication and database
- Deployed on Vercel

## Supabase Config
- **Project URL:** https://bxvsvqzpxasbbkxdllna.supabase.co
- **Anon Key:** eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ4dnN2cXpweGFzYmJreGRsbG5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1OTc1ODUsImV4cCI6MjA5NDE3MzU4NX0.zfDRLXlckYv0KF4EiKEz_s01Oye9Ur6ISvJGBzbQxZI

## Database Setup
Run `supabase-setup.sql` in Supabase SQL Editor. This creates:
- `profiles` table (user accounts with admin/client roles)
- `strategies` table (business strategy data per user)
- Row Level Security policies
- Auto-create profile + strategy on signup trigger

## Features
- User registration & login (Supabase Auth)
- 3-layer strategy builder (Clarity → Execution → Tracking)
- KPI dashboard with traffic-light status
- "One Page" dashboard view
- Admin panel to view all client strategies
- Auto-save to cloud

## To make yourself admin
1. Register an account
2. Go to Supabase → Table Editor → profiles
3. Change your role from `client` to `admin`

## Local Development
```
npx serve .
```
Opens at http://localhost:3000

## Deploy
Push to GitHub → Vercel auto-deploys from the repo.

## Known Issue
Registration may block if Supabase email confirmation is enabled.
Fix: Supabase → Authentication → Providers → Email → Disable "Confirm email"
