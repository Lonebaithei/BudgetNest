// ============================================================
//  auth.js
//  Handles Sign Up and Login for Students and Businesses
//  Import this in index.html's <script type="module">
// ============================================================

import { supabase } from './supabaseClient.js';


// ────────────────────────────────────────────────────────────
//  STUDENT — SIGN UP
// ────────────────────────────────────────────────────────────
/**
 * Register a new student.
 *
 * @param {Object} params
 * @param {string} params.email
 * @param {string} params.password
 * @param {string} params.fullName      e.g. "Lone Baithei"
 * @param {string} params.studentId     e.g. "BIDA24-344"
 * @param {string} params.institution   e.g. "BAC"
 *
 * @returns {{ user, profile, error }}
 */
export async function signUpStudent({ email, password, fullName, studentId, institution }) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      // These values are picked up by the handle_new_user() trigger
      // and automatically inserted into the profiles table
      data: {
        user_type:   'student',
        full_name:   fullName,
        student_id:  studentId,
        institution: institution,
      },
    },
  });

  if (error) return { user: null, profile: null, error: error.message };

  // Profile is created automatically by the database trigger.
  // Fetch it so the caller has it immediately.
  const profile = await fetchProfile(data.user.id);
  return { user: data.user, profile, error: null };
}


// ────────────────────────────────────────────────────────────
//  BUSINESS / INDIVIDUAL — SIGN UP
// ────────────────────────────────────────────────────────────
/**
 * Register a new business or individual seller.
 *
 * @param {Object} params
 * @param {string} params.email
 * @param {string} params.password
 * @param {string} params.fullName       Contact person's name
 * @param {string} params.businessName   Trading name
 * @param {string} params.category       e.g. "accommodation"
 * @param {string} params.phone          WhatsApp number
 *
 * @returns {{ user, profile, error }}
 */
export async function signUpBusiness({ email, password, fullName, businessName, category, phone }) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        user_type:     'business',
        full_name:     fullName,
        business_name: businessName,
        category:      category,
        phone:         phone,
      },
    },
  });

  if (error) return { user: null, profile: null, error: error.message };

  const profile = await fetchProfile(data.user.id);
  return { user: data.user, profile, error: null };
}


// ────────────────────────────────────────────────────────────
//  LOGIN  (works for both user types — Supabase Auth is unified)
// ────────────────────────────────────────────────────────────
/**
 * Sign in with email + password.
 * After login, fetch the profile to determine user_type
 * so you can redirect to the correct dashboard.
 *
 * @param {string} email
 * @param {string} password
 * @returns {{ user, profile, userType, error }}
 */
export async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) return { user: null, profile: null, userType: null, error: error.message };

  const profile = await fetchProfile(data.user.id);
  const userType = profile?.user_type ?? null;

  return { user: data.user, profile, userType, error: null };
}


// ────────────────────────────────────────────────────────────
//  LOGOUT
// ────────────────────────────────────────────────────────────
export async function logout() {
  const { error } = await supabase.auth.signOut();
  if (error) { console.error('logout:', error.message); return false; }
  window.location.href = 'index.html';
  return true;
}


// ────────────────────────────────────────────────────────────
//  PASSWORD RESET
// ────────────────────────────────────────────────────────────
export async function sendPasswordReset(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin + '/index.html',
  });
  if (error) return { success: false, error: error.message };
  return { success: true, error: null };
}


// ────────────────────────────────────────────────────────────
//  AUTH STATE LISTENER
//  Call this once on page load to react to login/logout events
// ────────────────────────────────────────────────────────────
/**
 * @param {Function} onLogin   Called with (user, profile) when signed in
 * @param {Function} onLogout  Called with no args when signed out
 */
export function onAuthChange(onLogin, onLogout) {
  supabase.auth.onAuthStateChange(async (event, session) => {
    if (event === 'SIGNED_IN' && session?.user) {
      const profile = await fetchProfile(session.user.id);
      onLogin(session.user, profile);
    } else if (event === 'SIGNED_OUT') {
      onLogout();
    }
  });
}


// ────────────────────────────────────────────────────────────
//  INTERNAL HELPER
// ────────────────────────────────────────────────────────────
async function fetchProfile(userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) { console.error('fetchProfile:', error.message); return null; }
  return data;
}


// ────────────────────────────────────────────────────────────
//  USAGE EXAMPLES
// ────────────────────────────────────────────────────────────
/*

// ── Student Sign Up ────────────────────────────────────────
const result = await signUpStudent({
  email:       'lone@student.bac.bw',
  password:    'securePass123',
  fullName:    'Lone Baithei',
  studentId:   'BIDA24-344',
  institution: 'BAC',
});
if (result.error) {
  showToast('Sign up failed: ' + result.error);
} else {
  window.location.href = 'budgetnest.html';
}


// ── Business Sign Up ──────────────────────────────────────
const result = await signUpBusiness({
  email:        'naledi@salon.co.bw',
  password:     'securePass123',
  fullName:     'Naledi Modise',
  businessName: 'Naledi Hair Studio',
  category:     'salon',
  phone:        '+267 71234567',
});


// ── Login (both user types) ───────────────────────────────
const result = await login('lone@student.bac.bw', 'securePass123');
if (result.error) {
  showToast('Login failed: ' + result.error);
} else if (result.userType === 'student') {
  window.location.href = 'budgetnest.html';
} else if (result.userType === 'business') {
  window.location.href = 'dashboard.html';
}

*/
