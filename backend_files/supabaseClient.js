// ============================================================
//  supabaseClient.js
//  Place this file in your project root alongside index.html
//  Import it in every other JS file that needs the database
// ============================================================

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// ── Replace these two values with your own project credentials ──
// Supabase Dashboard → Project Settings → API
const SUPABASE_URL  = 'https://YOUR_PROJECT_REF.supabase.co';
const SUPABASE_ANON = 'YOUR_ANON_PUBLIC_KEY';
// ────────────────────────────────────────────────────────────────

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, {
  auth: {
    // Persist the session in localStorage so users stay logged in
    // across page refreshes and browser restarts
    persistSession:     true,
    autoRefreshToken:   true,
    detectSessionInUrl: true,
    storage:            window.localStorage,
  },
});

// ── Convenience: get the currently signed-in user (or null) ──
export async function getCurrentUser() {
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) { console.error('getCurrentUser:', error.message); return null; }
  return user;
}

// ── Convenience: get the full profile row for the current user ──
export async function getCurrentProfile() {
  const user = await getCurrentUser();
  if (!user) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();

  if (error) { console.error('getCurrentProfile:', error.message); return null; }
  return data;
}
