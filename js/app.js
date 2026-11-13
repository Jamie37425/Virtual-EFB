/* =========================================================
   EFB launcher
   - Apps are websites (URLs) or HTML files stored on the device.
   - Embedded apps run in iframes that stay alive in the background,
     so you can switch between them from the dock like a real EFB.
   - Everything is saved on the tablet (localStorage + IndexedDB).
   ========================================================= */
(() => {
  'use strict';

  const VERSION = '2.1.0';
  const NATIVE = !!window.EFBNative;   // true when running inside the EFB Android app
  const DEFAULT_STAMP = 1794760000000;
  const LS_APPS = 'efb.apps.v1';
  const LS_SETTINGS = 'efb.settings.v1';
  const LS_STAMP = 'efb.stamp.v1';

  const COLORS = [
    '#0a9fd6', '#2563eb', '#1e3a8a', '#0d9488', '#16a34a',
    '#d97706', '#dc2626', '#c026d3', '#7c3aed', '#475569',
  ];

  const DEFAULT_APPS = [{"id":"chk","name":"Checklists","type":"url","url":"apps/checklist.html","icon":"☑","color":"#16a34a","mode":"embed"},{"id":"calc","name":"Wind & Conv","type":"url","url":"apps/calc.html","icon":"🧭","color":"#0a9fd6","mode":"embed"},{"id":"windy","name":"Windy","type":"url","url":"apps/windy.html","icon":"🌀","color":"#7c3aed","mode":"embed","embedOk":true}];

  const DEFAULT_SETTINGS = {"simbriefId":"","callsign":"","dim":0,"wake":true,"seconds":false};

  /* ---------------- tiny IndexedDB key/value store (for HTML files) ---------------- */
  const idb = (() => {
    let dbp;
    const open = () => dbp || (dbp = new Promise((res, rej) => {
      const r = indexedDB.open('efb', 1);
      r.onupgradeneeded = () => r.result.createObjectStore('files');
      r.onsuccess = () => res(r.result);
      r.onerror = () => rej(r.error);
    }));
    const tx = async (mode, fn) => {
      const db = await open();
      return new Promise((res, rej) => {
        const t = db.transaction('files', mode);
        const req = fn(t.objectStore('files'));
        t.oncomplete = () => res(req ? req.result : undefined);
        t.onerror = t.onabort = () => rej(t.error);
      });
    };
    return {
      get: (k) => tx('readonly', (s) => s.get(k)),
      set: (k, v) => tx('readwrite', (s) => s.put(v, k)),
      del: (k) => tx('readwrite', (s) => s.delete(k)),
      clear: () => tx('readwrite', (s) => s.clear()),
    };
  })();

  /* ---------------- helpers ---------------- */
  const $ = (id) => document.getElementById(id);
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  const pad2 = (n) => String(n).padStart(2, '0');
  const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  function loadJSON(key, fallback) {
    try { const v = JSON.parse(localStorage.getItem(key)); return v ?? fallback; }
    catch { return fallback; }
  }

  let toastTimer;
  function toast(msg, ms = 2200) {
    const t = $('toast');
    t.textContent = msg; t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.hidden = true; }, ms);
  }

  /** Turn what the user typed into a usable URL.
   *  "simbrief.com" -> "https://simbrief.com", "apps/x.html" stays relative. */
  function normalizeUrl(raw) {
    const u = (raw || '').trim();
    if (!u) return '';
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(u) || /^(data|blob|about):/i.test(u)) return u;  // has a scheme already
    if (/^(\.{0,2}\/)/.test(u)) return u;                    // ./ ../ /
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?(\/|$)/i.test(u)) return 'http://' + u;  // local network devices
    const segs = u.split('/');
    const first = segs[0];
    const looksLikeDomain = first.includes('.') && (segs.length > 1 || !/\.html?$/i.test(first));
    return looksLikeDomain ? 'https://' + u : u;
  }
  function getPcBase() {
    let custom = (localStorage.getItem('efb.pcBase') || '').trim();
    if (!NATIVE && (location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
      return location.origin;
    }
    if (custom) {
      return /^https?:\/\//i.test(custom) ? custom.replace(/\/$/, '') : `http://${custom}`.replace(/\/$/, '');
    }
    if (!NATIVE && location.protocol.startsWith('http')) {
      return location.origin;
    }
    return '';
  }

  function getPcHost() {
    const base = getPcBase();
    if (!base) return '';
    try {
      return new URL(base).hostname;
    } catch {
      return base.replace(/^https?:\/\//, '').split(/[:/]/)[0];
    }
  }

  function resolveUrl(u) {
    if (!u) return '';
    const host = getPcHost();
    if (host) {
      u = u.replaceAll('{SIM_PC}', host);
    } else {
      u = u.replaceAll('{SIM_PC}', 'localhost');
    }
    return u;
  }

  const absUrl = (u) => {
    u = resolveUrl(u);
    try { return new URL(u, location.href).href; } catch { return u; }
  };
  const isCrossOrigin = (u) => {
    try { return new URL(absUrl(u)).origin !== location.origin; } catch { return true; }
  };

  /* ---------------- state ---------------- */
  const savedStamp = +(localStorage.getItem(LS_STAMP) || 0);
  const useDefaults = DEFAULT_STAMP > savedStamp;
  let apps = (!useDefaults && loadJSON(LS_APPS, null)) || clone(DEFAULT_APPS);
  let settings = Object.assign({}, DEFAULT_SETTINGS, useDefaults ? {} : loadJSON(LS_SETTINGS, {}));
  if (useDefaults) {
    localStorage.setItem(LS_APPS, JSON.stringify(apps));
    localStorage.setItem(LS_SETTINGS, JSON.stringify(settings));
    localStorage.setItem(LS_STAMP, String(DEFAULT_STAMP));
    try {
      localStorage.removeItem('efb.simbrief.activeFlight');
      localStorage.removeItem('efb.calc.rwyOverrides.v1');
      localStorage.removeItem('efb.calc.lastIcao.v1');
    } catch {}
  }
  const running = new Map();   // appId -> { iframe, blobUrl }
  let activeId = null;
  let editing = false;
  let lastHomeAt = 0;

  const saveApps = () => {
    const now = Date.now();
    localStorage.setItem(LS_STAMP, String(now));
    localStorage.setItem(LS_APPS, JSON.stringify(apps));
    syncDefaultsToDisk(now);
  };
  const saveSettings = () => {
    const now = Date.now();
    localStorage.setItem(LS_STAMP, String(now));
    localStorage.setItem(LS_SETTINGS, JSON.stringify(settings));
    syncDefaultsToDisk(now);
  };
  const findApp = (id) => apps.find((a) => a.id === id);

  // Two-way sync between Tablet Android App and PC Web Version
  const PC_SERVER = () => getPcBase();
  const apiUrl = (path) => {
    const base = PC_SERVER();
    return base ? `${base}/${path}` : path;
  };

  function syncDefaultsToDisk(stamp = Date.now()) {
    if (!location.protocol.startsWith('http') && !PC_SERVER()) return;
    localStorage.setItem(LS_STAMP, String(stamp));
    fetch(apiUrl('api/sync-defaults'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ stamp, apps, settings }),
    }).catch(() => {});
  }

  let syncingState = false;
  async function syncWithServer() {
    if ((!location.protocol.startsWith('http') && !PC_SERVER()) || syncingState || editing) return;
    syncingState = true;
    try {
      const r = await fetch(apiUrl('api/state?t=' + Date.now()), { cache: 'no-store' });
      if (!r.ok) return;
      const remote = await r.json();
      if (!remote || !Array.isArray(remote.apps)) return;
      const localStamp = +(localStorage.getItem(LS_STAMP) || 0);
      const remoteStamp = +(remote.stamp || 0);
      if (remoteStamp > localStamp) {
        apps = remote.apps;
        if (remote.settings) settings = Object.assign({}, DEFAULT_SETTINGS, remote.settings);
        localStorage.setItem(LS_APPS, JSON.stringify(apps));
        localStorage.setItem(LS_SETTINGS, JSON.stringify(settings));
        localStorage.setItem(LS_STAMP, String(remoteStamp));
        applySettings();
        renderGrid();
      } else if (localStamp > remoteStamp) {
        syncDefaultsToDisk(localStamp);
      }
    } catch {} finally {
      syncingState = false;
    }
  }

  /* ---------------- icons ---------------- */
  function renderIcon(el, app) {
    el.textContent = '';
    el.classList.remove('letters');
    el.style.setProperty('--c', app.color || COLORS[0]);
    if (app.iconImg) {
      const img = document.createElement('img');
      img.src = app.iconImg; img.alt = '';
      el.appendChild(img);
      return;
    }
    const txt = (app.icon || '').trim() || (app.name || '?').slice(0, 2).toUpperCase();
    if (/^[A-Za-z0-9]{2,4}$/.test(txt)) el.classList.add('letters');
    el.textContent = txt;
  }

  function appMeta(app) {
    let m;
    if (app.type === 'file') m = 'HTML FILE';
    else if (!isCrossOrigin(app.url)) m = 'LOCAL';
    else { try { m = new URL(absUrl(app.url)).hostname.replace(/^www\./, '').toUpperCase(); } catch { m = 'WEB'; } }
    return app.mode === 'external' ? '↗ ' + m : m;
  }

  /* ================= HOME GRID ================= */
  const grid = $('grid');

  function renderGrid() {
    grid.textContent = '';
    grid.classList.toggle('editing', editing);
    $('emptyMsg').hidden = apps.length > 0;
    $('btnEdit').classList.toggle('on', editing);
    $('btnEdit').textContent = editing ? 'DONE' : 'EDIT';

    apps.forEach((app, i) => {
      const tile = document.createElement('div');
      tile.className = 'tile' + (running.has(app.id) ? ' running' : '');
      tile.setAttribute('role', 'button');
      tile.tabIndex = 0;
      tile.style.setProperty('--c', app.color);
      tile.dataset.id = app.id;

      const icon = document.createElement('div');
      icon.className = 'tile-icon';
      renderIcon(icon, app);

      const name = document.createElement('div');
      name.className = 'tile-name';
      name.textContent = app.name;

      const meta = document.createElement('div');
      meta.className = 'tile-meta' + (app.mode === 'external' ? ' ext' : '');
      meta.textContent = appMeta(app);

      const ed = document.createElement('div');
      ed.className = 'tile-edit';
      ed.innerHTML =
        `<button data-act="left" title="Move left" ${i === 0 ? 'disabled' : ''}>◀</button>` +
        `<button data-act="edit" title="Edit">✎</button>` +
        `<button data-act="right" title="Move right" ${i === apps.length - 1 ? 'disabled' : ''}>▶</button>` +
        `<button data-act="del" class="del" title="Delete">✕</button>`;

      tile.append(icon, name, meta, ed);
      grid.appendChild(tile);
    });
  }

  // tap / long-press handling on tiles
  let pressTimer = null, longPressed = false;
  grid.addEventListener('pointerdown', (e) => {
    const tile = e.target.closest('.tile');
    if (!tile || editing) return;
    longPressed = false;
    pressTimer = setTimeout(() => {
      longPressed = true;
      editing = true;
      renderGrid();
      if (navigator.vibrate) navigator.vibrate(30);
    }, 650);
  });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) =>
    grid.addEventListener(ev, () => clearTimeout(pressTimer)));
  grid.addEventListener('contextmenu', (e) => e.preventDefault());

  grid.addEventListener('click', (e) => {
    if (Date.now() - lastHomeAt < 450) { e.preventDefault(); e.stopPropagation(); return; }
    if (longPressed) { longPressed = false; return; }
    const tile = e.target.closest('.tile');
    if (!tile) return;
    const app = findApp(tile.dataset.id);
    if (!app) return;
    const act = e.target.closest('button')?.dataset.act;

    if (!editing) { launch(app); return; }

    const i = apps.indexOf(app);
    if (act === 'left' && i > 0) { [apps[i - 1], apps[i]] = [apps[i], apps[i - 1]]; saveApps(); renderGrid(); }
    else if (act === 'right' && i < apps.length - 1) { [apps[i + 1], apps[i]] = [apps[i], apps[i + 1]]; saveApps(); renderGrid(); }
    else if (act === 'del') deleteApp(app);
    else openEditor(app);
  });
  grid.addEventListener('keydown', (e) => {
    if ((e.key === 'Enter' || e.key === ' ') && e.target.classList.contains('tile')) { e.preventDefault(); e.target.click(); }
  });

  $('btnEdit').addEventListener('click', () => { editing = !editing; renderGrid(); });
  $('btnAdd').addEventListener('click', () => openEditor(null));

  /* ================= RUNNING APPS ================= */
  const frames = $('frames');

  async function launch(app) {
    if (app.mode === 'external') { openExternal(app); return; }
    if (running.has(app.id)) { activate(app.id); return; }

    let src, blobUrl = null;
    if (app.type === 'file') {
      const file = await idb.get(app.id).catch(() => null);
      if (!file) { toast('HTML file missing – edit the app and choose the file again'); return; }
      blobUrl = URL.createObjectURL(new Blob([file.html], { type: 'text/html' }));
      src = blobUrl;
    } else {
      src = absUrl(app.url);
    }

    // Android app: websites get their own native full-screen browser under the top bar (nothing can block them)
    if (NATIVE && app.type === 'url' && isCrossOrigin(app.url)) {
      running.set(app.id, { native: true, url: src });
      activate(app.id);
      return;
    }

    const iframe = document.createElement('iframe');
    iframe.setAttribute('allow', 'geolocation; fullscreen; clipboard-read; clipboard-write; screen-wake-lock; autoplay');
    iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    iframe.title = app.name;
    iframe.src = src;
    frames.appendChild(iframe);
    running.set(app.id, { iframe, blobUrl });
    activate(app.id);

    if (app.type === 'url' && isCrossOrigin(app.url) && !app.embedOk) showHint(app);
  }

  function activate(id) {
    const app = findApp(id);
    if (!app || !running.has(id)) return;
    activeId = id;
    ensureBackGuard();
    $('home').hidden = true;
    $('sbHomeActions').hidden = true;
    $('appview').hidden = false;
    $('sbAppControls').hidden = false;
    running.forEach((r, key) => { if (r.iframe) r.iframe.classList.toggle('active', key === id); });
    if (NATIVE) {
      const r = running.get(id);
      if (r.native) {
        const barPx = Math.round($('statusbar').getBoundingClientRect().bottom * window.devicePixelRatio);
        window.EFBNative.openApp(id, r.url, barPx);
      } else {
        window.EFBNative.hideApps();
        window.EFBNative.setOrb(true);
      }
    }
    renderIcon($('abIcon'), app);
    $('abTitle').textContent = app.name;
    if ($('embedHint').dataset.app !== id) hideHint();
    renderDock();
  }

  function goHome() {
    lastHomeAt = Date.now();
    activeId = null;
    $('appview').hidden = true;
    $('sbAppControls').hidden = true;
    $('home').hidden = false;
    $('sbHomeActions').hidden = false;
    hideHint();
    if (NATIVE) window.EFBNative.hideApps();
    renderDock();
    renderGrid();
  }
  window.efbGoHome = goHome;

  function closeApp(id) {
    const r = running.get(id);
    if (!r) return;
    if (r.native) window.EFBNative.closeApp(id);
    if (r.iframe) r.iframe.remove();
    if (r.blobUrl) URL.revokeObjectURL(r.blobUrl);
    running.delete(id);
    if (activeId === id) {
      const others = [...running.keys()];
      if (others.length) activate(others[others.length - 1]); else goHome();
    } else {
      renderDock();
    }
    renderGrid();
  }

  async function openExternal(app) {
    if (NATIVE && app.type === 'url') { window.EFBNative.openExternal(absUrl(app.url)); return; }
    if (app.type === 'file') {
      const file = await idb.get(app.id).catch(() => null);
      if (!file) { toast('HTML file missing'); return; }
      window.open(URL.createObjectURL(new Blob([file.html], { type: 'text/html' })), '_blank');
    } else {
      window.open(absUrl(app.url), '_blank', 'noopener');
    }
  }

  $('abClose').addEventListener('click', () => activeId && closeApp(activeId));
  $('abReload').addEventListener('click', () => {
    const r = running.get(activeId);
    if (r && r.native) { window.EFBNative.reloadApp(activeId); return; }
    if (r) { const s = r.iframe.src; r.iframe.src = 'about:blank'; setTimeout(() => { r.iframe.src = s; }, 30); }
  });
  $('abExternal').addEventListener('click', () => { const a = findApp(activeId); if (a) openExternal(a); });

  /* embed hint – shown when a 3rd-party site is opened inside the EFB */
  let hintTimer;
  function showHint(app) {
    const h = $('embedHint');
    h.dataset.app = app.id;
    h.hidden = false;
    clearTimeout(hintTimer);
    hintTimer = setTimeout(hideHint, 9000);
  }
  function hideHint() { clearTimeout(hintTimer); $('embedHint').hidden = true; $('embedHint').dataset.app = ''; }
  $('hintDismiss').addEventListener('click', () => {
    const a = findApp($('embedHint').dataset.app);
    if (a) { a.embedOk = true; saveApps(); }   // it works – don't show again for this app
    hideHint();
  });
  $('hintOpenExt').addEventListener('click', () => { const a = findApp($('embedHint').dataset.app); if (a) openExternal(a); hideHint(); });
  $('hintAlwaysExt').addEventListener('click', () => {
    const a = findApp($('embedHint').dataset.app);
    if (!a) return;
    a.mode = 'external'; saveApps();
    closeApp(a.id);
    hideHint();
    openExternal(a);
    toast(a.name + ' will now open outside the EFB');
  });

  /* ================= FLOATING iPad-STYLE HOME BUTTON ================= */
  const orb = $('homeOrb');
  function renderDock() {
    orb.hidden = NATIVE || activeId === null;   // the Android app draws its own native home button
    if (NATIVE) window.EFBNative.setOrb(activeId !== null);
  }

  // Draggable AssistiveTouch-style home button + tap to go home
  (() => {
    const savedPos = loadJSON('efb.orb.pos', null);
    if (savedPos && typeof savedPos.x === 'number' && typeof savedPos.y === 'number') {
      orb.style.left = Math.min(window.innerWidth - 56, Math.max(8, savedPos.x)) + 'px';
      orb.style.top = Math.min(window.innerHeight - 56, Math.max(36, savedPos.y)) + 'px';
      orb.style.right = 'auto';
      orb.style.bottom = 'auto';
    }

    let dragging = false, moved = false, startX = 0, startY = 0, origX = 0, origY = 0;
    orb.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      dragging = true; moved = false;
      const rect = orb.getBoundingClientRect();
      startX = e.clientX; startY = e.clientY;
      origX = rect.left; origY = rect.top;
      orb.setPointerCapture(e.pointerId);
    });
    orb.addEventListener('pointermove', (e) => {
      if (!dragging) return;
      const dx = e.clientX - startX, dy = e.clientY - startY;
      if (Math.hypot(dx, dy) > 6) {
        moved = true;
        orb.classList.add('dragging');
        const nx = Math.min(window.innerWidth - 54, Math.max(6, origX + dx));
        const ny = Math.min(window.innerHeight - 54, Math.max(34, origY + dy));
        orb.style.left = nx + 'px';
        orb.style.top = ny + 'px';
        orb.style.right = 'auto';
        orb.style.bottom = 'auto';
      }
    });
    ['pointerup', 'pointercancel'].forEach((ev) => orb.addEventListener(ev, (e) => {
      if (!dragging) return;
      e.preventDefault();
      e.stopPropagation();
      dragging = false;
      orb.classList.remove('dragging');
      if (moved) {
        const rect = orb.getBoundingClientRect();
        localStorage.setItem('efb.orb.pos', JSON.stringify({ x: Math.round(rect.left), y: Math.round(rect.top) }));
      } else {
        lastHomeAt = Date.now();
        setTimeout(goHome, 25);
      }
    }));
    orb.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
    });
  })();
  $('logoBtn')?.addEventListener('click', goHome);

  /* Android back button: go back inside the app first, then to the EFB menu. */
  let guard = false;
  history.replaceState({ efb: 'root' }, '');
  function ensureBackGuard() {
    if (!guard) { history.pushState({ efb: 'guard' }, ''); guard = true; }
  }
  window.addEventListener('popstate', (e) => {
    if (e.state && e.state.efb === 'guard') { guard = true; return; }
    guard = false;
    if (activeId) { goHome(); ensureBackGuard(); }
  });

  /* ================= ADD / EDIT DIALOG ================= */
  const dlg = $('appDialog');
  let editId = null, pendingFile = null, pendingIconImg = null, selColor = COLORS[0];

  // colour swatches
  COLORS.forEach((c) => {
    const b = document.createElement('button');
    b.type = 'button'; b.dataset.c = c;
    b.style.setProperty('--c', c);
    b.title = c;
    $('colorChoices').appendChild(b);
  });
  $('colorChoices').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    selColor = b.dataset.c;
    updateEditorUI();
  });

  const formType = () => dlg.querySelector('input[name="fType"]:checked').value;
  const formMode = () => dlg.querySelector('input[name="fMode"]:checked').value;

  function updateEditorUI() {
    const isFile = formType() === 'file';
    $('rowUrl').hidden = isFile;
    $('rowFile').hidden = !isFile;
    [...$('colorChoices').children].forEach((b) => b.classList.toggle('sel', b.dataset.c === selColor));
    renderIcon($('iconPreview'), {
      name: $('fName').value || '?', icon: $('fIcon').value, iconImg: pendingIconImg, color: selColor,
    });
    $('btnClearIconImg').hidden = !pendingIconImg;
  }

  function openEditor(app) {
    editId = app ? app.id : null;
    pendingFile = null;
    pendingIconImg = app ? app.iconImg || null : null;
    selColor = app ? app.color : COLORS[Math.floor(Math.random() * COLORS.length)];
    $('appDialogTitle').textContent = app ? 'EDIT APP' : 'ADD APP';
    $('fName').value = app ? app.name : '';
    $('fUrl').value = app && app.type === 'url' ? app.url : '';
    $('fIcon').value = app ? app.icon || '' : '';
    $('fFile').value = '';
    $('fIconImg').value = '';
    $('fFileInfo').textContent = app && app.type === 'file'
      ? `Current file: ${app.fileName || 'stored'} – choose a new file to replace it.`
      : 'Single-file HTML pages work best (CSS/JS inside the file).';
    dlg.querySelector(`input[name="fType"][value="${app ? app.type : 'url'}"]`).checked = true;
    dlg.querySelector(`input[name="fMode"][value="${app ? app.mode : 'embed'}"]`).checked = true;
    $('btnDeleteApp').hidden = !app;
    updateEditorUI();
    dlg.showModal();
  }

  dlg.querySelectorAll('input[name="fType"]').forEach((r) => r.addEventListener('change', updateEditorUI));
  $('fName').addEventListener('input', updateEditorUI);
  $('fIcon').addEventListener('input', updateEditorUI);
  $('btnCancelApp').addEventListener('click', () => dlg.close());
  $('btnClearIconImg').addEventListener('click', () => { pendingIconImg = null; $('fIconImg').value = ''; updateEditorUI(); });

  $('fFile').addEventListener('change', async () => {
    const f = $('fFile').files[0];
    if (!f) return;
    const html = await f.text();
    pendingFile = { name: f.name, html };
    $('fFileInfo').textContent = `Loaded: ${f.name} (${Math.round(f.size / 1024)} KB)`;
    if (!$('fName').value) { $('fName').value = f.name.replace(/\.html?$/i, '').slice(0, 24); updateEditorUI(); }
  });

  $('fIconImg').addEventListener('change', async () => {
    const f = $('fIconImg').files[0];
    if (!f) return;
    try { pendingIconImg = await imageToDataUrl(f, 128); updateEditorUI(); }
    catch { toast('Could not read that image'); }
  });

  function imageToDataUrl(file, size) {
    return new Promise((res, rej) => {
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.onload = () => {
        const c = document.createElement('canvas');
        c.width = c.height = size;
        const ctx = c.getContext('2d');
        const s = Math.min(img.width, img.height);   // centre-crop to a square
        ctx.drawImage(img, (img.width - s) / 2, (img.height - s) / 2, s, s, 0, 0, size, size);
        URL.revokeObjectURL(url);
        res(c.toDataURL('image/png'));
      };
      img.onerror = () => { URL.revokeObjectURL(url); rej(new Error('bad image')); };
      img.src = url;
    });
  }

  $('appForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const type = formType();
    const name = $('fName').value.trim();
    const existing = editId ? findApp(editId) : null;
    if (!name) { toast('Please enter a name'); return; }

    const app = existing || { id: uid() };
    const url = normalizeUrl($('fUrl').value);
    if (type === 'url' && !url) { toast('Please enter a web address'); $('fUrl').focus(); return; }
    if (type === 'file' && !pendingFile && !(existing && existing.type === 'file')) { toast('Please choose an HTML file'); return; }

    try {
      if (type === 'file' && pendingFile) {
        await idb.set(app.id, pendingFile);
        app.fileName = pendingFile.name;
      }
      if (type === 'url' && existing && existing.type === 'file') {
        await idb.del(app.id);
        delete app.fileName;
      }
    } catch (err) {
      toast('Could not save the file on this device'); console.error(err); return;
    }

    if (existing && (existing.url !== url || existing.type !== type)) delete app.embedOk;
    Object.assign(app, {
      name, type, url: type === 'url' ? url : '',
      icon: $('fIcon').value.trim(), iconImg: pendingIconImg || undefined,
      color: selColor, mode: formMode(),
    });
    if (!existing) apps.push(app);
    saveApps();
    if (running.has(app.id)) closeApp(app.id);   // restart with the new settings
    dlg.close();
    renderGrid();
    toast(existing ? 'App updated' : 'App added');
  });

  $('btnDeleteApp').addEventListener('click', () => {
    const a = findApp(editId);
    if (a) { dlg.close(); deleteApp(a); }
  });

  function deleteApp(app) {
    if (!confirm(`Delete "${app.name}" from the EFB?`)) return;
    closeApp(app.id);
    apps = apps.filter((a) => a.id !== app.id);
    if (app.type === 'file') idb.del(app.id).catch(() => {});
    saveApps();
    renderGrid();
  }

  /* ================= SETTINGS ================= */
  const sdlg = $('settingsDialog');
  $('btnSettings').addEventListener('click', () => {
    $('sSimbriefId').value = settings.simbriefId || '';
    $('simbriefStatus').textContent = settings.callsign ? `Active Callsign: ${settings.callsign}` : '';
    $('sDim').value = settings.dim;
    $('sWake').checked = settings.wake;
    $('sSeconds').checked = settings.seconds;
    $('sWake').disabled = !NATIVE && !('wakeLock' in navigator);
    const baseAbout = `EFB v${VERSION} · ${apps.length} apps · ` +
      (window.matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches ? 'installed' : 'running in browser');
    $('aboutLine').textContent = baseAbout;
    fetch(apiUrl('api/info')).then((r) => r.json()).then((info) => {
      if (info && info.ip) {
        const p = info.port && info.port !== 80 ? `:${info.port}` : '';
        $('aboutLine').textContent = `${baseAbout} · Tablet address: http://${info.ip}${p}`;
      }
    }).catch(() => {});
    updatePcConnectionUI(false);
    sdlg.showModal();
  });

  async function updatePcConnectionUI(test = false) {
    const ipInput = $('sPcIp');
    const statusEl = $('pcIpStatus');
    if (!ipInput || !statusEl) return;

    let pcBase = (localStorage.getItem('efb.pcBase') || '').trim();
    if (pcBase && !ipInput.value) {
      ipInput.value = pcBase.replace(/^https?:\/\//i, '').replace(/\/$/, '');
    }

    if (!NATIVE && location.protocol.startsWith('http')) {
      // Running on PC browser
      try {
        const r = await fetch('api/info?t=' + Date.now(), { cache: 'no-store' });
        if (r.ok) {
          const info = await r.json();
          if (info && info.ip) {
            statusEl.innerHTML = `<span style="color:var(--green)">✓ PC Server Active · Local IP: <b>${info.ip}</b></span> (Enter this IP on your tablet to sync)`;
            if (!ipInput.value) ipInput.value = info.ip;
            return;
          }
        }
      } catch {}
    }

    const currentVal = ipInput.value.trim().replace(/^https?:\/\//i, '').replace(/\/$/, '');
    if (!currentVal) {
      statusEl.textContent = 'Enter the IP shown on your PC screen (http://localhost) so this tablet syncs checklists.';
      return;
    }

    if (test) {
      statusEl.style.color = 'var(--dim)';
      statusEl.textContent = `Testing connection to ${currentVal}...`;
      const target = `http://${currentVal}`;
      const ctl = new AbortController();
      const tm = setTimeout(() => ctl.abort(), 3500);
      try {
        const r = await fetch(`${target}/api/info?t=` + Date.now(), { signal: ctl.signal, cache: 'no-store' });
        clearTimeout(tm);
        if (r.ok) {
          const info = await r.json();
          statusEl.style.color = '';
          statusEl.innerHTML = `<span style="color:var(--green)">✓ Connected to ${info.host || 'Sim PC'} (${info.ip || currentVal})</span>`;
          toast(`Connected to ${info.host || 'Sim PC'}`);
          syncWithServer();
          return;
        }
      } catch {}
      clearTimeout(tm);
      statusEl.style.color = '';
      statusEl.innerHTML = `<span style="color:var(--amber)">Saved ${currentVal} (PC not responding - verify serve.ps1 is running on PC)</span>`;
    } else {
      statusEl.innerHTML = `Configured: <b>${currentVal}</b> · Tap CONNECT to test`;
    }
  }

  if ($('btnConnectPc')) {
    $('btnConnectPc').addEventListener('click', () => {
      const val = $('sPcIp').value.trim().replace(/^https?:\/\//i, '').replace(/\/$/, '');
      if (!val) {
        localStorage.removeItem('efb.pcBase');
        $('pcIpStatus').textContent = 'Disconnected. Enter your Sim PC IP to reconnect.';
        toast('PC connection cleared');
        return;
      }
      localStorage.setItem('efb.pcBase', 'http://' + val);
      updatePcConnectionUI(true);
    });
  }
  if ($('sPcIp')) {
    $('sPcIp').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        $('btnConnectPc').click();
      }
    });
  }

  async function fetchSimbriefCallsign(silent = false) {
    const inputVal = $('sSimbriefId') ? $('sSimbriefId').value.trim() : '';
    const id = sdlg.open ? inputVal : (inputVal || settings.simbriefId || '').trim();
    settings.simbriefId = id;
    saveSettings();
    if (!id) {
      settings.callsign = '';
      saveSettings();
      applySettings();
      if ($('simbriefStatus')) $('simbriefStatus').textContent = '';
      return;
    }
    const statusEl = $('simbriefStatus');
    const btn = $('btnFetchSimbrief');
    if (btn) { btn.disabled = true; btn.textContent = '...'; }
    if (statusEl && !silent) { statusEl.style.color = 'var(--dim)'; statusEl.textContent = 'Fetching SimBrief OFP...'; }

    try {
      const param = /^\d+$/.test(id) ? `userid=${encodeURIComponent(id)}` : `username=${encodeURIComponent(id)}`;
      const r = await fetch(`https://www.simbrief.com/api/xml.fetcher.php?${param}&json=1&t=${Date.now()}`, { cache: 'no-store' });
      const data = await r.json();
      if (!r.ok || data?.fetch?.status !== 'Success') {
        throw new Error(data?.fetch?.status || 'No active SimBrief OFP found for this ID');
      }
      const cs =
        (typeof data?.atc?.callsign === 'string' && data.atc.callsign.trim()) ||
        ((typeof data?.general?.icao_airline === 'string' ? data.general.icao_airline : '') +
         (typeof data?.general?.flight_number === 'string' ? data.general.flight_number : '')).trim() ||
        (typeof data?.aircraft?.reg === 'string' && data.aircraft.reg.trim()) ||
        '';
      settings.callsign = cs.toUpperCase();
      saveSettings();
      applySettings();
      const orig = typeof data?.origin?.icao_code === 'string' ? data.origin.icao_code : '';
      const origRwy = typeof data?.origin?.plan_rwy === 'string' ? data.origin.plan_rwy : '';
      const dest = typeof data?.destination?.icao_code === 'string' ? data.destination.icao_code : '';

      const destRwy = typeof data?.destination?.plan_rwy === 'string' ? data.destination.plan_rwy : '';

      // Extract Navigraph runway magnetic headings from SimBrief TLR
      const toList = (x) => (!x ? [] : Array.isArray(x) ? x : [x]);
      const runwaysFound = {};
      toList(data?.tlr?.takeoff?.runway).forEach((r) => {
        const id = (r.identifier || '').trim().toUpperCase();
        const mag = parseInt(r.magnetic_course || r.mag_course || r.heading_mag, 10);
        if (orig && id && !isNaN(mag) && mag >= 1 && mag <= 360) runwaysFound[`${orig}:${id}`] = mag;
      });
      toList(data?.tlr?.landing?.runway).forEach((r) => {
        const id = (r.identifier || '').trim().toUpperCase();
        const mag = parseInt(r.magnetic_course || r.mag_course || r.heading_mag, 10);
        if (dest && id && !isNaN(mag) && mag >= 1 && mag <= 360) runwaysFound[`${dest}:${id}`] = mag;
      });

      const flightInfo = {
        callsign: cs,
        orig,
        origRwy,
        dest,
        destRwy,
        runways: runwaysFound,
        updatedAt: Date.now()
      };
      try {
        localStorage.setItem('efb.simbrief.activeFlight', JSON.stringify(flightInfo));
        if (Object.keys(runwaysFound).length > 0) {
          const ov = JSON.parse(localStorage.getItem('efb.calc.rwyOverrides.v1') || '{}');
          Object.assign(ov, runwaysFound);
          localStorage.setItem('efb.calc.rwyOverrides.v1', JSON.stringify(ov));
        }
      } catch {}

      const routeInfo = orig && dest ? ` (${orig} → ${dest})` : '';
      if (statusEl) {
        statusEl.style.color = 'var(--green)';
        statusEl.textContent = cs ? `Active Callsign: ${settings.callsign}${routeInfo}` : 'OFP found, but no callsign set';
      }
      if (!silent && cs) toast(`Callsign set to ${settings.callsign}`);
    } catch (err) {
      if (statusEl && !silent) {
        statusEl.style.color = 'var(--red)';
        statusEl.textContent = err.message || 'Could not fetch SimBrief data';
      }
      if (!silent) toast('SimBrief fetch failed');
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = 'FETCH'; }
    }
  }

  // Save SimBrief Pilot ID immediately as you type so it is always remembered
  $('sSimbriefId').addEventListener('input', () => {
    settings.simbriefId = $('sSimbriefId').value.trim();
    saveSettings();
  });
  $('btnFetchSimbrief').addEventListener('click', () => fetchSimbriefCallsign(false));
  $('sSimbriefId').addEventListener('change', () => fetchSimbriefCallsign(false));
  $('sbCallsign').addEventListener('click', () => {
    if (settings.simbriefId) fetchSimbriefCallsign(false);
  });
  $('sDim').addEventListener('input', () => { settings.dim = +$('sDim').value; saveSettings(); applySettings(); });
  $('sWake').addEventListener('change', () => { settings.wake = $('sWake').checked; saveSettings(); applyWake(); });
  $('sSeconds').addEventListener('change', () => { settings.seconds = $('sSeconds').checked; saveSettings(); tick(); });

  function applySettings() {
    if ($('sSimbriefId')) $('sSimbriefId').value = settings.simbriefId || '';
    $('sbCallsign').textContent = settings.callsign || '';
    $('dimmer').style.opacity = settings.dim / 100;
  }

  // export / import / reset
  $('btnExport').addEventListener('click', async () => {
    const files = {};
    for (const a of apps) if (a.type === 'file') files[a.id] = await idb.get(a.id).catch(() => null);
    const data = { efbExport: 1, version: VERSION, exported: new Date().toISOString(), apps, files };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `efb-apps-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(link.href), 5000);
    toast('Apps exported');
  });
  $('btnImport').addEventListener('click', () => $('importFile').click());
  $('importFile').addEventListener('change', async () => {
    const f = $('importFile').files[0];
    $('importFile').value = '';
    if (!f) return;
    try {
      const data = JSON.parse(await f.text());
      if (!Array.isArray(data.apps)) throw new Error('no apps');
      if (!confirm(`Replace your current apps with ${data.apps.length} apps from this file?`)) return;
      closeAll();
      await idb.clear();
      for (const [id, file] of Object.entries(data.files || {})) if (file) await idb.set(id, file);
      apps = data.apps.filter((a) => a && a.id && a.name);
      saveApps(); saveSettings(); renderGrid(); applySettings();
      toast('Apps imported');
    } catch (err) { console.error(err); toast('That is not a valid EFB export file'); }
  });
  $('btnReset').addEventListener('click', async () => {
    if (!confirm('Reset to the default apps? Your own apps will be removed.')) return;
    closeAll();
    await idb.clear().catch(() => {});
    apps = clone(DEFAULT_APPS);
    settings = Object.assign({}, DEFAULT_SETTINGS);
    try {
      localStorage.removeItem('efb.simbrief.activeFlight');
      localStorage.removeItem('efb.calc.rwyOverrides.v1');
      localStorage.removeItem('efb.calc.lastIcao.v1');
    } catch {}
    saveApps(); saveSettings(); renderGrid(); applySettings();
    toast('Reset to defaults');
  });
  function closeAll() { [...running.keys()].forEach(closeApp); goHome(); }

  /* ================= STATUS BAR ================= */
  function tick() {
    const d = new Date();
    const hh = pad2(d.getUTCHours()), mm = pad2(d.getUTCMinutes()), ss = pad2(d.getUTCSeconds());
    $('utcClock').textContent = settings.seconds ? `${hh}:${mm}:${ss}Z` : `${hh}:${mm}Z`;
    $('utcDate').textContent = `${pad2(d.getUTCDate())} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
  }
  function startClock() {
    tick();
    setTimeout(() => { tick(); setInterval(tick, 1000); }, 1000 - (Date.now() % 1000));
  }

  if (navigator.getBattery) {
    navigator.getBattery().then((b) => {
      const el = $('battStatus');
      const upd = () => {
        const pct = Math.round(b.level * 100);
        el.hidden = false;
        el.querySelector('.batt-fill').style.width = pct + '%';
        el.querySelector('.batt').classList.toggle('low', pct <= 30 && pct > 15);
        el.querySelector('.batt').classList.toggle('crit', pct <= 15);
        el.querySelector('.batt-label').textContent = pct + '%' + (b.charging ? '⚡' : '');
      };
      upd();
      b.addEventListener('levelchange', upd);
      b.addEventListener('chargingchange', upd);
    }).catch(() => {});
  }

  // keep screen awake (Wake Lock API, needs HTTPS)
  let wakeLock = null;
  async function applyWake() {
    if (NATIVE) { window.EFBNative.keepAwake(!!settings.wake); return; }
    try {
      if (settings.wake && 'wakeLock' in navigator && document.visibilityState === 'visible') {
        if (!wakeLock) {
          wakeLock = await navigator.wakeLock.request('screen');
          wakeLock.addEventListener('release', () => { wakeLock = null; });
        }
      } else if (!settings.wake && wakeLock) {
        await wakeLock.release(); wakeLock = null;
      }
    } catch (err) { console.warn('Wake lock failed', err); }
  }
  document.addEventListener('visibilitychange', applyWake);

  // full screen toggle
  const fsBtn = $('btnFullscreen');
  if (!document.fullscreenEnabled) fsBtn.hidden = true;
  fsBtn.addEventListener('click', () => {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen({ navigationUI: 'hide' }).catch(() => {});
  });

  /* ================= START ================= */
  window.addEventListener('message', (e) => {
    if (e?.data?.type === 'simbrief-callsign-updated' && e.data.callsign) {
      settings.callsign = e.data.callsign;
      saveSettings();
      applySettings();
    }
  });
  applySettings();
  syncWithServer();
  window.addEventListener('focus', syncWithServer);
  if (!NATIVE && location.protocol.startsWith('http')) {
    fetch('api/info?t=' + Date.now(), { cache: 'no-store' })
      .then((r) => r.json())
      .then((info) => {
        if (info && info.ip && $('btnServerIpPill')) {
          $('btnServerIpPill').textContent = 'SYNC IP: ' + info.ip;
          $('btnServerIpPill').hidden = false;
          $('btnServerIpPill').onclick = () => $('btnSettings').click();
        }
      })
      .catch(() => {});
  }
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') syncWithServer();
  });
  setInterval(() => {
    if (activeId === null && document.visibilityState === 'visible') syncWithServer();
  }, 4000);
  if (settings.simbriefId) fetchSimbriefCallsign(true);
  startClock();
  applyWake();
  renderGrid();
  renderDock();

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then((regs) => {
      for (const r of regs) r.unregister();
    }).catch(() => {});
    if (window.caches) {
      caches.keys().then((keys) => keys.forEach((k) => caches.delete(k))).catch(() => {});
    }
  }
})();
