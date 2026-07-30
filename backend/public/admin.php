<?php

declare(strict_types=1);

?><!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Expense Super Admin</title>
  <meta name="robots" content="noindex,nofollow">
  <meta name="theme-color" content="#0E1C1A">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --ink:#0E1C1A; --ink-soft:#1A302C; --tide:#0F9F74; --tide-soft:#C8F0DF;
      --seafoam:#3DDC97; --mist:#E2EBE7; --foam:#EEF3F1; --foam-deep:#E4EDE9;
      --slate:#3D544E; --muted:#6E817A; --danger:#E85A4F; --hairline:#D3DFDA;
      --panel:#fff; --font:"Plus Jakarta Sans",system-ui,sans-serif;
    }
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:var(--font);background:var(--foam);color:var(--ink);min-height:100vh}
    button,input,select,textarea{font:inherit}
    a{color:var(--tide);text-decoration:none}
    .hidden{display:none!important}
    .shell{display:grid;grid-template-columns:240px 1fr;min-height:100vh}
    @media(max-width:900px){.shell{grid-template-columns:1fr}.sidebar{display:none}.shell.nav-open .sidebar{display:block}}
    .sidebar{background:linear-gradient(165deg,var(--ink),#143029 50%,var(--ink-soft));color:#fff;padding:1.25rem 1rem;display:flex;flex-direction:column;gap:1rem}
    .brand{font-weight:800;font-size:1.15rem;letter-spacing:-.03em}
    .brand span{display:block;font-size:.72rem;font-weight:600;color:rgba(255,255,255,.55);margin-top:.2rem}
    .nav-btn{display:block;width:100%;text-align:left;border:0;background:transparent;color:rgba(255,255,255,.78);padding:.7rem .85rem;border-radius:12px;cursor:pointer;font-weight:600;font-size:.9rem}
    .nav-btn:hover,.nav-btn.active{background:rgba(255,255,255,.1);color:#fff}
    .main{padding:1.25rem 1.5rem 2.5rem}
    .topbar{display:flex;justify-content:space-between;align-items:center;gap:1rem;margin-bottom:1.25rem}
    .topbar h1{font-size:1.45rem;font-weight:800;letter-spacing:-.03em}
    .card{background:var(--panel);border-radius:18px;padding:1.1rem 1.15rem;box-shadow:0 8px 20px rgba(14,28,26,.04);margin-bottom:1rem}
    .stats{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:.75rem}
    .stat{background:var(--panel);border-radius:16px;padding:1rem;box-shadow:0 8px 20px rgba(14,28,26,.04)}
    .stat b{display:block;font-size:1.35rem;font-weight:800;letter-spacing:-.03em}
    .stat span{font-size:.72rem;font-weight:700;color:var(--muted);letter-spacing:.06em;text-transform:uppercase}
    .row{display:flex;flex-wrap:wrap;gap:.6rem;align-items:center;margin-bottom:.85rem}
    input,select,textarea{border:1.5px solid var(--hairline);border-radius:12px;padding:.65rem .8rem;background:#fff;min-width:0}
    input:focus,select:focus,textarea:focus{outline:2px solid rgba(15,159,116,.35);border-color:var(--tide)}
    .btn{border:0;border-radius:12px;padding:.65rem 1rem;font-weight:700;cursor:pointer;background:var(--ink);color:#fff}
    .btn:hover{background:var(--ink-soft)}
    .btn.secondary{background:#fff;color:var(--ink);border:1.5px solid var(--hairline)}
    .btn.tide{background:var(--tide)}
    .btn.danger{background:var(--danger)}
    .btn.sm{padding:.4rem .7rem;font-size:.8rem}
    table{width:100%;border-collapse:collapse;font-size:.88rem}
    th,td{text-align:left;padding:.7rem .55rem;border-bottom:1px solid var(--hairline);vertical-align:top}
    th{font-size:.72rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted)}
    .badge{display:inline-block;padding:.15rem .45rem;border-radius:999px;font-size:.68rem;font-weight:700}
    .badge.ok{background:var(--tide-soft);color:var(--tide)}
    .badge.warn{background:#FDE8E6;color:var(--danger)}
    .badge.muted{background:var(--mist);color:var(--slate)}
    .login-wrap{min-height:100vh;display:grid;place-items:center;padding:1.5rem;background:linear-gradient(180deg,var(--foam),var(--foam-deep))}
    .login-card{width:min(420px,100%);background:#fff;border-radius:24px;padding:1.75rem;box-shadow:0 20px 40px rgba(14,28,26,.08)}
    .login-card h1{font-size:1.6rem;font-weight:800;margin-bottom:.35rem}
    .login-card p{color:var(--muted);margin-bottom:1.25rem;font-size:.95rem}
    .field{margin-bottom:.85rem}
    .field label{display:block;font-size:.75rem;font-weight:700;color:var(--muted);margin-bottom:.35rem}
    .field input{width:100%}
    .error{color:var(--danger);font-size:.85rem;margin:.5rem 0}
    .muted{color:var(--muted);font-size:.85rem}
    .grid-2{display:grid;grid-template-columns:1fr 1fr;gap:.75rem}
    @media(max-width:700px){.grid-2{grid-template-columns:1fr}}
    .config-grid{display:grid;gap:.75rem}
    .toggle-row{display:flex;justify-content:space-between;align-items:center;gap:1rem;padding:.75rem 0;border-bottom:1px solid var(--hairline)}
    .drawer{position:fixed;inset:0;background:rgba(14,28,26,.35);display:none;place-items:center;padding:1rem;z-index:50}
    .drawer.open{display:grid}
    .drawer-panel{background:#fff;width:min(560px,100%);max-height:90vh;overflow:auto;border-radius:20px;padding:1.25rem}
    .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.78rem;word-break:break-all}
  </style>
</head>
<body>
  <div id="loginView" class="login-wrap">
    <div class="login-card">
      <h1>Expense Admin</h1>
      <p>Sign in with your super-admin account.</p>
      <div class="field"><label>Email</label><input id="loginEmail" type="email" autocomplete="username"></div>
      <div class="field"><label>Password</label><input id="loginPassword" type="password" autocomplete="current-password"></div>
      <div id="loginError" class="error hidden"></div>
      <button class="btn" id="loginBtn" style="width:100%;margin-top:.5rem">Sign in</button>
    </div>
  </div>

  <div id="appView" class="shell hidden">
    <aside class="sidebar">
      <div class="brand">Expense<span>Super Admin</span></div>
      <nav>
        <button class="nav-btn active" data-tab="dashboard">Dashboard</button>
        <button class="nav-btn" data-tab="users">Users</button>
        <button class="nav-btn" data-tab="devices">Devices</button>
        <button class="nav-btn" data-tab="trips">Trips</button>
        <button class="nav-btn" data-tab="config">Config</button>
        <button class="nav-btn" data-tab="audit">Audit log</button>
      </nav>
      <div style="margin-top:auto">
        <div class="muted" id="adminEmail" style="color:rgba(255,255,255,.55);font-size:.78rem;margin-bottom:.5rem"></div>
        <button class="nav-btn" id="logoutBtn">Sign out</button>
      </div>
    </aside>

    <main class="main">
      <div class="topbar">
        <h1 id="pageTitle">Dashboard</h1>
        <button class="btn secondary sm" id="refreshBtn">Refresh</button>
      </div>

      <section id="tab-dashboard"></section>
      <section id="tab-users" class="hidden"></section>
      <section id="tab-devices" class="hidden"></section>
      <section id="tab-trips" class="hidden"></section>
      <section id="tab-config" class="hidden"></section>
      <section id="tab-audit" class="hidden"></section>
    </main>
  </div>

  <div class="drawer" id="drawer">
    <div class="drawer-panel" id="drawerBody"></div>
  </div>

<script>
const TOKEN_KEY = 'expenseAdminToken';
const state = { token: localStorage.getItem(TOKEN_KEY) || '', tab: 'dashboard', me: null };

async function api(path, opts = {}) {
  const headers = Object.assign({ 'Accept': 'application/json', 'Content-Type': 'application/json' }, opts.headers || {});
  if (state.token) headers.Authorization = 'Bearer ' + state.token;
  const res = await fetch(path, Object.assign({}, opts, { headers }));
  const json = await res.json().catch(() => ({}));
  if (res.status === 401) {
    logout(false);
    throw new Error(json.error || 'Unauthorized');
  }
  if (!json.ok) throw new Error(json.error || ('Request failed (' + res.status + ')'));
  return json.data;
}

function logout(reload = true) {
  state.token = '';
  localStorage.removeItem(TOKEN_KEY);
  if (reload) location.reload();
}

function fmt(dt) {
  if (!dt) return '—';
  try { return new Date(dt.replace(' ', 'T') + 'Z').toLocaleString(); } catch { return dt; }
}

function badge(text, kind) {
  return `<span class="badge ${kind || 'muted'}">${text}</span>`;
}

function showTab(tab) {
  state.tab = tab;
  document.querySelectorAll('.nav-btn[data-tab]').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  ['dashboard','users','devices','trips','config','audit'].forEach(t => {
    document.getElementById('tab-' + t).classList.toggle('hidden', t !== tab);
  });
  const titles = { dashboard:'Dashboard', users:'Users', devices:'Devices', trips:'Trips', config:'Remote config', audit:'Audit log' };
  document.getElementById('pageTitle').textContent = titles[tab] || tab;
  loadTab(tab);
}

async function loadTab(tab) {
  try {
    if (tab === 'dashboard') await renderDashboard();
    if (tab === 'users') await renderUsers();
    if (tab === 'devices') await renderDevices();
    if (tab === 'trips') await renderTrips();
    if (tab === 'config') await renderConfig();
    if (tab === 'audit') await renderAudit();
  } catch (e) {
    document.getElementById('tab-' + tab).innerHTML = `<div class="card error">${e.message}</div>`;
  }
}

async function renderDashboard() {
  const data = await api('/api/admin/dashboard');
  const s = data.stats;
  const c = data.config_snapshot;
  document.getElementById('tab-dashboard').innerHTML = `
    <div class="stats">
      ${stat('Users', s.users)}
      ${stat('Active 7d', s.active_users_7d)}
      ${stat('Active 30d', s.active_users_30d)}
      ${stat('New 7d', s.new_users_7d)}
      ${stat('Premium', s.premium_grants)}
      ${stat('Banned', s.banned)}
      ${stat('Devices', s.devices)}
      ${stat('Guests', s.guest_devices)}
      ${stat('Trips', s.trips)}
      ${stat('Trip expenses', s.trip_expenses)}
    </div>
    <div class="card" style="margin-top:1rem">
      <h3 style="margin-bottom:.75rem">Live remote config</h3>
      <div class="row">
        ${c.maintenance_mode ? badge('Maintenance ON', 'warn') : badge('Maintenance off', 'ok')}
        ${c.force_update ? badge('Force update ON', 'warn') : badge('Force update off', 'ok')}
        ${badge('Min iOS ' + c.min_ios_version, 'muted')}
        ${badge('Min app ' + c.min_app_version, 'muted')}
      </div>
      <p class="muted">App Store: <a href="${c.app_store_url}" target="_blank" rel="noopener">${c.app_store_url}</a></p>
    </div>`;
}
function stat(label, value) {
  return `<div class="stat"><span>${label}</span><b>${value}</b></div>`;
}

async function renderUsers(q = '', filter = 'all', page = 1) {
  const data = await api(`/api/admin/users?q=${encodeURIComponent(q)}&filter=${filter}&page=${page}`);
  const rows = data.users.map(u => `
    <tr>
      <td><strong>#${u.id}</strong><div class="muted">${u.email || '—'}</div></td>
      <td>${u.display_name || '—'}
        <div>${u.is_admin ? badge('Admin','ok') : ''} ${u.premium ? badge('Premium','ok') : ''} ${u.is_banned ? badge('Banned','warn') : ''}</div>
      </td>
      <td><div>${fmt(u.last_seen_at)}</div><div class="muted">Data: ${fmt(u.last_data_at)}</div></td>
      <td class="muted">${u.app_version || '—'} / iOS ${u.ios_version || '—'}</td>
      <td><button class="btn sm secondary" onclick="openUser(${u.id})">Open</button></td>
    </tr>`).join('');
  document.getElementById('tab-users').innerHTML = `
    <div class="card">
      <div class="row">
        <input id="userQ" placeholder="Search email, name, id" value="${q.replace(/"/g,'&quot;')}" style="flex:1;min-width:180px">
        <select id="userFilter">
          ${['all','premium','banned','admin','inactive'].map(f => `<option value="${f}" ${f===filter?'selected':''}>${f}</option>`).join('')}
        </select>
        <button class="btn" id="userSearchBtn">Search</button>
      </div>
      <div class="muted" style="margin-bottom:.5rem">${data.total} users · page ${data.page}</div>
      <table>
        <thead><tr><th>User</th><th>Name / flags</th><th>Last seen</th><th>Versions</th><th></th></tr></thead>
        <tbody>${rows || '<tr><td colspan="5">No users</td></tr>'}</tbody>
      </table>
      <div class="row" style="margin-top:.75rem">
        <button class="btn secondary sm" ${page<=1?'disabled':''} onclick="renderUsers(document.getElementById('userQ').value, document.getElementById('userFilter').value, ${page-1})">Prev</button>
        <button class="btn secondary sm" onclick="renderUsers(document.getElementById('userQ').value, document.getElementById('userFilter').value, ${page+1})">Next</button>
      </div>
    </div>`;
  document.getElementById('userSearchBtn').onclick = () =>
    renderUsers(document.getElementById('userQ').value, document.getElementById('userFilter').value, 1);
}

async function openUser(id) {
  const data = await api('/api/admin/users/' + id);
  const u = data.user;
  const devices = (data.devices || []).map(d => `
    <div class="mono">${d.device_uuid}</div>
    <div class="muted">${d.device_model || '—'} · last ${fmt(d.last_seen_at)} · ${d.app_version || '?'}</div>`).join('') || '<div class="muted">No devices linked</div>';
  const trips = (data.trips || []).map(t => `<div>${t.name} <span class="muted">(${t.invite_code}) · ${t.member_count} members</span></div>`).join('') || '<div class="muted">No trips</div>';
  const docs = (data.sync_documents || []).map(d => `<div>${d.doc_type} · ${d.bytes} bytes · ${fmt(d.updated_at)}</div>`).join('') || '<div class="muted">No sync docs</div>';

  document.getElementById('drawerBody').innerHTML = `
    <div class="row" style="justify-content:space-between">
      <h2>#${u.id} ${u.display_name || ''}</h2>
      <button class="btn secondary sm" onclick="closeDrawer()">Close</button>
    </div>
    <p class="muted">${u.email || 'no email'}</p>
    <div class="row" style="margin:.75rem 0">
      ${u.premium ? badge('Premium until ' + (u.premium_until || ''), 'ok') : badge('No premium', 'muted')}
      ${u.is_banned ? badge('Banned', 'warn') : badge('Active', 'ok')}
      ${u.is_admin ? badge('Admin', 'ok') : ''}
    </div>
    <div class="grid-2">
      <div><div class="muted">Last seen</div><strong>${fmt(u.last_seen_at)}</strong></div>
      <div><div class="muted">Last data change</div><strong>${fmt(u.last_data_at)}</strong></div>
      <div><div class="muted">App / iOS</div><strong>${u.app_version || '—'} / ${u.ios_version || '—'}</strong></div>
      <div><div class="muted">Device</div><strong>${u.device_model || '—'}</strong></div>
      <div><div class="muted">Created</div><strong>${fmt(u.created_at)}</strong></div>
      <div><div class="muted">Premium note</div><strong>${u.premium_note || '—'}</strong></div>
    </div>
    <hr style="border:0;border-top:1px solid var(--hairline);margin:1rem 0">
    <h3>Grant premium</h3>
    <div class="row">
      <button class="btn tide sm" onclick="grantPremium(${u.id}, 30)">+30 days</button>
      <button class="btn tide sm" onclick="grantPremium(${u.id}, 365)">+1 year</button>
      <button class="btn tide sm" onclick="grantPremium(${u.id}, 0, true)">Lifetime</button>
      <button class="btn secondary sm" onclick="revokePremium(${u.id})">Revoke</button>
    </div>
    <h3 style="margin-top:1rem">Moderation</h3>
    <div class="row">
      <button class="btn ${u.is_banned?'tide':'danger'} sm" onclick="toggleBan(${u.id}, ${u.is_banned?0:1})">${u.is_banned?'Unban':'Ban'}</button>
      <button class="btn secondary sm" onclick="toggleAdmin(${u.id}, ${u.is_admin?0:1})">${u.is_admin?'Remove admin':'Make admin'}</button>
      <button class="btn danger sm" onclick="deleteUser(${u.id})">Delete user</button>
    </div>
    <div class="field" style="margin-top:1rem">
      <label>Internal notes</label>
      <textarea id="userNotes" rows="3" style="width:100%">${(u.notes||'').replace(/</g,'&lt;')}</textarea>
      <button class="btn sm" style="margin-top:.5rem" onclick="saveNotes(${u.id})">Save notes</button>
    </div>
    <div class="field" style="margin-top:1rem">
      <label>Set new password</label>
      <input id="userNewPassword" type="password" autocomplete="new-password" placeholder="Min. 8 characters" style="width:100%">
      <button class="btn sm" style="margin-top:.5rem" onclick="savePassword(${u.id})">Update password</button>
      <p class="muted" style="margin-top:.4rem;font-size:.85rem">Updates login password for this account. Other sessions will need to sign in again.</p>
    </div>
    <h3 style="margin-top:1rem">Devices</h3>${devices}
    <h3 style="margin-top:1rem">Trips</h3>${trips}
    <h3 style="margin-top:1rem">Sync documents</h3>${docs}`;
  document.getElementById('drawer').classList.add('open');
}

function closeDrawer(){ document.getElementById('drawer').classList.remove('open'); }

async function grantPremium(id, days, lifetime=false) {
  await api('/api/admin/users/' + id + '/premium', { method:'POST', body: JSON.stringify({ days, lifetime, note: 'Granted from admin panel' }) });
  openUser(id); loadTab('users');
}
async function revokePremium(id) {
  await api('/api/admin/users/' + id + '/premium', { method:'DELETE' });
  openUser(id); loadTab('users');
}
async function toggleBan(id, banned) {
  await api('/api/admin/users/' + id, { method:'PATCH', body: JSON.stringify({ is_banned: !!banned }) });
  openUser(id); loadTab('users');
}
async function toggleAdmin(id, admin) {
  await api('/api/admin/users/' + id, { method:'PATCH', body: JSON.stringify({ is_admin: !!admin }) });
  openUser(id); loadTab('users');
}
async function saveNotes(id) {
  const notes = document.getElementById('userNotes').value;
  await api('/api/admin/users/' + id, { method:'PATCH', body: JSON.stringify({ notes }) });
  alert('Notes saved');
}
async function savePassword(id) {
  const password = (document.getElementById('userNewPassword').value || '').trim();
  if (password.length < 8) {
    alert('Password must be at least 8 characters');
    return;
  }
  if (!confirm('Update password for this user?')) return;
  await api('/api/admin/users/' + id, { method:'PATCH', body: JSON.stringify({ password }) });
  document.getElementById('userNewPassword').value = '';
  alert('Password updated');
}
async function deleteUser(id) {
  if (!confirm('Permanently delete this user and related data?')) return;
  await api('/api/admin/users/' + id, { method:'DELETE' });
  closeDrawer(); loadTab('users');
}

async function renderDevices(q='', guests=false, page=1) {
  const data = await api(`/api/admin/devices?q=${encodeURIComponent(q)}&guests=${guests?1:0}&page=${page}`);
  const rows = data.devices.map(d => `
    <tr>
      <td><div class="mono">${d.device_uuid}</div>
        <div class="muted">${d.is_guest==1||!d.user_id ? badge('Guest','muted') : badge('Linked','ok')}</div></td>
      <td>${d.user_email || d.user_display_name || '—'}
        ${d.user_id ? `<div class="muted">user #${d.user_id}</div>` : ''}</td>
      <td>${d.device_model || '—'}<div class="muted">${d.app_version||'—'} / iOS ${d.ios_version||'—'}</div></td>
      <td>${fmt(d.last_seen_at)}<div class="muted">Data ${fmt(d.last_data_at)}</div></td>
      <td class="muted">${d.locale || '—'} · ${d.timezone || '—'}</td>
    </tr>`).join('');
  document.getElementById('tab-devices').innerHTML = `
    <div class="card">
      <div class="row">
        <input id="devQ" placeholder="Search UUID, model, email" value="${q.replace(/"/g,'&quot;')}" style="flex:1">
        <label class="muted"><input type="checkbox" id="devGuests" ${guests?'checked':''}> Guests only</label>
        <button class="btn" id="devSearch">Search</button>
      </div>
      <div class="muted" style="margin-bottom:.5rem">${data.total} devices</div>
      <table>
        <thead><tr><th>Device UUID</th><th>User</th><th>Hardware</th><th>Activity</th><th>Locale</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="5">No devices yet — app heartbeats will appear here</td></tr>'}</tbody>
      </table>
    </div>`;
  document.getElementById('devSearch').onclick = () =>
    renderDevices(document.getElementById('devQ').value, document.getElementById('devGuests').checked, 1);
}

async function renderTrips(page=1) {
  const data = await api('/api/admin/trips?page=' + page);
  const rows = data.trips.map(t => `
    <tr>
      <td><strong>${t.name}</strong><div class="mono">${t.invite_code}</div></td>
      <td>${t.owner_name || '—'}<div class="muted">${t.owner_email || ('#'+t.owner_id)}</div></td>
      <td>${t.member_count} members · ${t.expense_count} expenses</td>
      <td>${t.currency}</td>
      <td>${fmt(t.created_at)}</td>
    </tr>`).join('');
  document.getElementById('tab-trips').innerHTML = `
    <div class="card">
      <div class="muted" style="margin-bottom:.5rem">${data.total} trips</div>
      <table>
        <thead><tr><th>Trip</th><th>Owner</th><th>Activity</th><th>FX</th><th>Created</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="5">No trips</td></tr>'}</tbody>
      </table>
    </div>`;
}

async function renderConfig() {
  const data = await api('/api/admin/config');
  const c = data.config;
  const val = (k) => (c[k] && c[k].value != null) ? c[k].value : '';
  const bool = (k) => val(k) === '1';
  document.getElementById('tab-config').innerHTML = `
    <div class="card config-grid">
      <div class="toggle-row"><div><strong>Maintenance mode</strong><div class="muted">Blocks the app with a message</div></div>
        <input type="checkbox" id="cfg_maintenance_mode" ${bool('maintenance_mode')?'checked':''}></div>
      <div class="field"><label>Maintenance message</label><textarea id="cfg_maintenance_message" rows="2" style="width:100%">${esc(val('maintenance_message'))}</textarea></div>
      <div class="toggle-row"><div><strong>Force update</strong><div class="muted">Require update before using the app</div></div>
        <input type="checkbox" id="cfg_force_update" ${bool('force_update')?'checked':''}></div>
      <div class="grid-2">
        <div class="field"><label>Minimum iOS version</label><input id="cfg_min_ios_version" value="${esc(val('min_ios_version'))}"></div>
        <div class="field"><label>Minimum app version</label><input id="cfg_min_app_version" value="${esc(val('min_app_version'))}"></div>
      </div>
      <div class="field"><label>App Store URL</label><input id="cfg_app_store_url" value="${esc(val('app_store_url'))}"></div>
      <div class="field"><label>Support email</label><input id="cfg_support_email" value="${esc(val('support_email'))}"></div>
      <div class="toggle-row"><div><strong>Announcement banner</strong></div>
        <input type="checkbox" id="cfg_announcement_active" ${bool('announcement_active')?'checked':''}></div>
      <div class="field"><label>Announcement title</label><input id="cfg_announcement_title" value="${esc(val('announcement_title'))}"></div>
      <div class="field"><label>Announcement message</label><textarea id="cfg_announcement_message" rows="2" style="width:100%">${esc(val('announcement_message'))}</textarea></div>
      <h3>Feature flags</h3>
      ${flag('feature_trips_enabled','Trips', bool('feature_trips_enabled'))}
      ${flag('feature_sync_enabled','Cloud sync', bool('feature_sync_enabled'))}
      ${flag('feature_registration_enabled','New registrations', bool('feature_registration_enabled'))}
      ${flag('feature_receipt_scan_enabled','Receipt scan', bool('feature_receipt_scan_enabled'))}
      <button class="btn" id="saveConfigBtn">Save config</button>
    </div>`;
  document.getElementById('saveConfigBtn').onclick = saveConfig;
}
function flag(id, label, on) {
  return `<div class="toggle-row"><div><strong>${label}</strong></div><input type="checkbox" id="cfg_${id}" ${on?'checked':''}></div>`;
}
function esc(s){ return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;'); }

async function saveConfig() {
  const keys = [
    'maintenance_mode','maintenance_message','force_update','min_ios_version','min_app_version',
    'app_store_url','support_email','announcement_active','announcement_title','announcement_message',
    'feature_trips_enabled','feature_sync_enabled','feature_registration_enabled','feature_receipt_scan_enabled'
  ];
  const config = {};
  keys.forEach(k => {
    const el = document.getElementById('cfg_' + k);
    if (!el) return;
    config[k] = el.type === 'checkbox' ? (el.checked ? '1' : '0') : el.value;
  });
  await api('/api/admin/config', { method:'PUT', body: JSON.stringify({ config }) });
  alert('Config saved — apps pick this up on next heartbeat.');
  renderConfig();
}

async function renderAudit(page=1) {
  const data = await api('/api/admin/audit?page=' + page);
  const rows = data.events.map(e => `
    <tr>
      <td>${fmt(e.created_at)}</td>
      <td>${e.admin_email || e.admin_name || ('#'+e.admin_user_id)}</td>
      <td><strong>${e.action}</strong><div class="muted">${e.target_type || ''} ${e.target_id || ''}</div></td>
      <td class="mono">${esc(e.details||'')}</td>
      <td class="muted">${e.ip_address || '—'}</td>
    </tr>`).join('');
  document.getElementById('tab-audit').innerHTML = `
    <div class="card">
      <table>
        <thead><tr><th>When</th><th>Admin</th><th>Action</th><th>Details</th><th>IP</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="5">No audit events</td></tr>'}</tbody>
      </table>
    </div>`;
}

async function bootApp() {
  state.me = await api('/api/auth/me');
  if (!state.me.is_admin) throw new Error('This account is not an admin');
  document.getElementById('loginView').classList.add('hidden');
  document.getElementById('appView').classList.remove('hidden');
  document.getElementById('adminEmail').textContent = state.me.email || state.me.display_name;
  showTab('dashboard');
}

document.getElementById('loginBtn').onclick = async () => {
  const err = document.getElementById('loginError');
  err.classList.add('hidden');
  try {
    const data = await api('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email: document.getElementById('loginEmail').value,
        password: document.getElementById('loginPassword').value
      })
    });
    state.token = data.api_token;
    localStorage.setItem(TOKEN_KEY, state.token);
    await bootApp();
  } catch (e) {
    err.textContent = e.message;
    err.classList.remove('hidden');
  }
};

document.querySelectorAll('.nav-btn[data-tab]').forEach(b => b.onclick = () => showTab(b.dataset.tab));
document.getElementById('logoutBtn').onclick = () => logout(true);
document.getElementById('refreshBtn').onclick = () => loadTab(state.tab);
document.getElementById('drawer').onclick = (e) => { if (e.target.id === 'drawer') closeDrawer(); };

if (state.token) {
  bootApp().catch(() => logout(true));
}
</script>
</body>
</html>
