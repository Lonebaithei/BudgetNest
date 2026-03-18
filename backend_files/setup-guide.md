# BudgetNest — Supabase Backend Setup Guide

## Files in this package

| File | Purpose |
|------|---------|
| `schema.sql` | Paste into Supabase SQL Editor — creates all tables, RLS, and triggers |
| `supabaseClient.js` | Single shared Supabase connection — import this everywhere |
| `auth.js` | Sign Up and Login functions for Students and Businesses |
| `db.js` | Full CRUD for Expenses, Income, Costs, Revenue, and Listings |

---

## PART 1 — Create Your Supabase Project

**Step 1.** Go to https://supabase.com and click **Start your project**.

**Step 2.** Sign in with GitHub (free, no credit card needed).

**Step 3.** Click **New project**.
- Organisation: your personal org
- Name: `BudgetNest`
- Database password: create a strong password and **save it**
- Region: choose the closest to Botswana — **South Africa (Cape Town)**
- Plan: **Free**

**Step 4.** Wait about 2 minutes for the project to provision.

---

## PART 2 — Run the Database Schema

**Step 5.** In your Supabase project, go to the left sidebar → **SQL Editor**.

**Step 6.** Click **New query**.

**Step 7.** Open `schema.sql` from this package, copy the entire contents, and paste it into the editor.

**Step 8.** Click **Run** (or press Ctrl+Enter).

You should see: `Success. No rows returned` at the bottom. If any errors appear, check that you are pasting the complete file and not just part of it.

**Step 9.** Verify the tables were created:
- Go to **Table Editor** in the left sidebar
- You should see: `profiles`, `student_expenses`, `student_income`, `business_costs`, `business_revenue`, `listings`

---

## PART 3 — Get Your API Keys

**Step 10.** In the left sidebar, go to **Project Settings** → **API**.

**Step 11.** Copy two values:
- **Project URL** — looks like `https://abcdefgh.supabase.co`
- **anon public** key — a long JWT string starting with `eyJ...`

**Step 12.** Open `supabaseClient.js` and replace the two placeholder values:

```js
// BEFORE
const SUPABASE_URL  = 'https://YOUR_PROJECT_REF.supabase.co';
const SUPABASE_ANON = 'YOUR_ANON_PUBLIC_KEY';

// AFTER (example — use your real values)
const SUPABASE_URL  = 'https://abcdefgh.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

> The `anon` key is safe to include in frontend code. It is public by design.
> Never use the `service_role` key in frontend code.

---

## PART 4 — Connect the Files to Your App

**Step 13.** Add all four JS files to your GitHub repo alongside `index.html`:

```
your-repo/
├── index.html
├── budgetnest.html
├── manifest.json
├── sw.js
├── supabaseClient.js   ← new
├── auth.js             ← new
└── db.js               ← new
```

**Step 14.** In `index.html`, change the `<script>` tag to use modules and import `auth.js`:

```html
<!-- Replace the existing <script> at the bottom of index.html with: -->
<script type="module">
  import { signUpStudent, signUpBusiness, login } from './auth.js';

  // Hook up the Student submit button
  window.submitStudent = async function() {
    const institution = document.getElementById('s-institution').value;
    const sid         = document.getElementById('s-id').value.trim();
    const name        = document.getElementById('s-name').value.trim();
    const email       = document.getElementById('s-email').value.trim();
    const password    = document.getElementById('s-password').value;

    if (!institution || !sid || !name || !email || password.length < 6) {
      alert('Please fill in all fields (password min 6 characters).');
      return;
    }

    const result = await signUpStudent({
      email, password,
      fullName: name, studentId: sid, institution,
    });

    if (result.error) {
      alert('Sign up failed: ' + result.error);
    } else {
      document.getElementById('student-form-card').style.display = 'none';
      document.getElementById('student-success-name').textContent =
        'Welcome, ' + name.split(' ')[0] + '!';
      document.getElementById('student-success').classList.add('show');
      setTimeout(() => { window.location.href = 'budgetnest.html'; }, 2000);
    }
  };

  // Hook up the Business submit button
  window.submitBusiness = async function() {
    const name     = document.getElementById('b-name').value.trim();
    const phone    = document.getElementById('b-phone').value.trim();
    const email    = document.getElementById('b-email').value.trim();
    const category = document.getElementById('b-category').value;
    const desc     = document.getElementById('b-desc').value.trim();

    if (!name || !phone || !email || !category || !desc) {
      alert('Please fill in all required fields.');
      return;
    }

    // For the business panel the password is generated or set separately
    // For now, prompt for a password
    const password = prompt('Create a password for your business account (min 6 chars):');
    if (!password || password.length < 6) return;

    const result = await signUpBusiness({
      email, password,
      fullName: name, businessName: name,
      category: category.split('  ')[1] || category,
      phone,
    });

    if (result.error) {
      alert('Registration failed: ' + result.error);
    } else {
      document.getElementById('business-form-card').style.display = 'none';
      document.getElementById('business-success').classList.add('show');
    }
  };
</script>
```

**Step 15.** Add an Email field to the student login form in `index.html`
(Supabase Auth requires an email address — add it above the password field):

```html
<div class="form-group">
  <label>Email address</label>
  <input type="email" id="s-email" placeholder="your@email.com"/>
</div>
```

---

## PART 5 — Enable Email Confirmation (Optional but recommended)

**Step 16.** In Supabase → **Authentication** → **Settings**:
- Toggle **Enable email confirmations** ON for production
- For testing, you can leave it OFF so users can log in immediately without clicking a confirmation email

---

## PART 6 — Verify RLS is Working

**Step 17.** In Supabase → **Table Editor** → click on `student_expenses` → **RLS Policies**.

You should see one policy: `expenses: student owns`.

**Step 18.** To test manually:
1. Register two different student accounts
2. Log in as Student A and add an expense
3. Log in as Student B — they should see zero expenses (their own data only)

---

## PART 7 — Using the CRUD Functions in budgetnest.html

Once a student is logged in, you can call the `db.js` functions anywhere:

```html
<script type="module">
  import { createExpense, getExpenses, getStudentSummary } from './db.js';

  // Add an expense
  async function addExpense() {
    try {
      const expense = await createExpense({
        title:    'Weekly grocery hamper',
        amount:   180,
        category: 'food',
        note:     'Naledi Grocery Hampers',
      });
      console.log('Saved:', expense);
    } catch (err) {
      console.error(err.message);
    }
  }

  // Get this month's summary
  async function loadDashboard() {
    const now       = new Date();
    const dateFrom  = new Date(now.getFullYear(), now.getMonth(), 1)
                        .toISOString().split('T')[0];
    const summary   = await getStudentSummary({ dateFrom });
    console.log('Balance this month: P' + summary.balance);
  }
</script>
```

---

## Summary of What Each File Does

### `schema.sql`
- Creates 6 tables: `profiles`, `student_expenses`, `student_income`, `business_costs`, `business_revenue`, `listings`
- Adds indexes for fast queries
- Auto-sets `updated_at` via triggers
- Auto-creates a profile row whenever a new user registers via Supabase Auth
- Enables Row Level Security on every table
- Students can only see their own expenses and income
- Businesses can only see their own costs and revenue
- Active listings are readable by all signed-in users

### `supabaseClient.js`
- Creates a single shared Supabase client with session persistence
- Exports `getCurrentUser()` and `getCurrentProfile()` helpers

### `auth.js`
- `signUpStudent()` — registers a student and creates their profile
- `signUpBusiness()` — registers a business and creates their profile
- `login()` — signs in any user and returns their `user_type` for routing
- `logout()` — signs out and redirects to `index.html`
- `sendPasswordReset()` — triggers a password reset email
- `onAuthChange()` — listener for login/logout events

### `db.js`
- Student: `createExpense`, `getExpenses`, `updateExpense`, `deleteExpense`
- Student: `createIncome`, `getIncome`, `updateIncome`, `deleteIncome`
- Student: `getStudentSummary` — total income, expenses, and balance
- Business: `createCost`, `getCosts`, `updateCost`, `deleteCost`
- Business: `createRevenue`, `getRevenue`, `updateRevenue`, `deleteRevenue`
- Business: `getBusinessSummary` — total revenue, costs, and profit
- Listings: `createListing`, `getListings`, `getMyListings`, `updateListing`, `deactivateListing`, `deleteListing`
