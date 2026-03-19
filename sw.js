// ============================================================
//  sw.js — BudgetNest Service Worker  v3
//  Strategy:
//    HTML files  → Network first  (always get latest updates)
//    Other assets → Cache first   (fast load for JS/CSS/fonts)
//  Bump the CACHE version string whenever you deploy changes.
// ============================================================

const CACHE   = 'budgetnest-v3';
const HTML    = ['./index.html', './BudgetNest.html', './dashboard.html', './admin.html'];
const ASSETS  = ['./manifest.json'];

// ── INSTALL: pre-cache non-HTML assets only ──────────────────
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

// ── ACTIVATE: delete every old cache version ─────────────────
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k !== CACHE).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// ── FETCH ─────────────────────────────────────────────────────
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;

  const url = new URL(e.request.url);
  const isHTML = HTML.some(p => url.pathname.endsWith(p.replace('./', '/')))
               || url.pathname === '/'
               || url.pathname.endsWith('.html');

  if (isHTML) {
    // Network first — always try to get the latest version
    e.respondWith(
      fetch(e.request)
        .then(res => {
          if (res && res.status === 200) {
            const clone = res.clone();
            caches.open(CACHE).then(c => c.put(e.request, clone));
          }
          return res;
        })
        .catch(() => caches.match(e.request)) // offline fallback
    );
  } else {
    // Cache first for JS, CSS, fonts, images
    e.respondWith(
      caches.match(e.request).then(cached => {
        const network = fetch(e.request).then(res => {
          if (res && res.status === 200 && res.type === 'basic') {
            caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          }
          return res;
        });
        return cached || network;
      })
    );
  }
});
