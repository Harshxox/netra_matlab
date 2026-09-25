/**
 * NetraAPI — browser client for the MATLAB backend (src/server/netraServer.m).
 *
 * Every call returns a promise. If the MATLAB backend is unreachable the
 * client degrades to the pre-computed snapshot in web/data/snapshot.json,
 * which holds REAL pipeline output captured by src/server/exportSnapshot.m —
 * not invented numbers. NetraAPI.online tells the UI which mode it's in so
 * it can label the difference honestly.
 */
(function () {
  'use strict';

  const cfg = window.NETRA_CONFIG || {};
  const BASE = (cfg.apiBase || '').replace(/\/$/, '');

  const API = {
    online: false,
    checked: false,
    snapshot: null,
    mode: 'unknown'          // 'live' | 'cached' | 'unknown'
  };

  // ---------------------------------------------------------------
  function withTimeout(promise, ms) {
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('timeout')), ms);
      promise.then(
        (v) => { clearTimeout(t); resolve(v); },
        (e) => { clearTimeout(t); reject(e); }
      );
    });
  }

  async function req(method, path, body) {
    const opts = { method, headers: {} };
    if (body !== undefined) {
      opts.headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(body);
    }
    const res = await withTimeout(
      fetch(BASE + path, opts),
      method === 'POST' && path === '/api/screen' ? 120000 : 15000
    );
    const data = await res.json();
    if (!res.ok || data.ok === false) {
      throw new Error(data.error || ('HTTP ' + res.status));
    }
    return data;
  }

  // ---------------------------------------------------------------
  /** Loads the baked snapshot once. */
  async function loadSnapshot() {
    if (API.snapshot) return API.snapshot;
    try {
      const res = await fetch(cfg.snapshotUrl || 'data/snapshot.json');
      API.snapshot = await res.json();
    } catch (e) {
      console.warn('[netra] no snapshot available:', e.message);
      API.snapshot = { patients: [], records: [], snapshot: null };
    }
    return API.snapshot;
  }

  /** Pings the MATLAB backend. Safe to call repeatedly. */
  API.probe = async function () {
    try {
      const res = await withTimeout(
        fetch(BASE + '/api/health'),
        cfg.probeTimeout || 4000
      );
      const data = await res.json();
      API.online = data.ok === true;
      API.mode = API.online ? 'live' : 'cached';
    } catch (e) {
      API.online = false;
      API.mode = 'cached';
    }
    API.checked = true;
    if (!API.online) await loadSnapshot();
    document.dispatchEvent(new CustomEvent('netra:mode', {
      detail: { online: API.online, mode: API.mode }
    }));
    return API.online;
  };

  /** Turns a backend-relative file URL into something the browser can load. */
  API.fileUrl = function (u) {
    if (!u) return '';
    if (/^(https?:|data:)/.test(u)) return u;
    if (API.online) return BASE + u;
    // offline: snapshot stores plain relative paths under web/
    return u.replace(/^\/api\/file\?p=/, '').replace(/%2F/gi, '/');
  };

  // ---------------------------------------------------------------
  API.login = async function (user, pass) {
    if (API.online) return req('POST', '/api/login', { user, pass });
    const snap = await loadSnapshot();
    const found = (snap.users || []).find(
      (u) => u.user === String(user).toLowerCase() && u.pass === pass
    );
    if (!found) throw new Error('Invalid username or password');
    return { ok: true, role: found.role, name: found.name };
  };

  API.listPatients = async function (q) {
    if (API.online) {
      const d = await req('GET', '/api/patients?q=' + encodeURIComponent(q || ''));
      return d.patients || [];
    }
    const snap = await loadSnapshot();
    const all = snap.patients || [];
    if (!q) return all;
    const needle = String(q).toLowerCase();
    return all.filter((p) =>
      [p.patientId, p.name, p.phone].join(' ').toLowerCase().includes(needle)
    );
  };

  API.registerPatient = async function (profile) {
    if (API.online) return req('POST', '/api/patients', profile);
    throw new Error('Registering a patient needs the MATLAB backend running.');
  };

  API.dossier = async function (patientId) {
    if (API.online) {
      const d = await req('GET', '/api/patients/' + encodeURIComponent(patientId));
      return d.dossier;
    }
    const snap = await loadSnapshot();
    const dossiers = snap.dossiers || {};
    // MATLAB sanitises struct keys, so PT-2026-0008 is stored as PT_2026_0008
    return dossiers[patientId]
        || dossiers[String(patientId).replace(/[^A-Za-z0-9]/g, '_')]
        || null;
  };

  /** Full pipeline record for a patient, if one was baked into the snapshot. */
  API.recordFor = async function (patientId) {
    const snap = await loadSnapshot();
    return (snap.records || []).find((r) => r.patientId === patientId) || null;
  };

  /** Runs the real MATLAB pipeline on an uploaded File object. */
  API.screen = async function (file, patientId, eye) {
    if (!API.online) {
      throw new Error(
        'Live screening needs the MATLAB backend. Showing a cached result instead.'
      );
    }
    const imageBase64 = await fileToBase64(file);
    const d = await req('POST', '/api/screen', {
      patientId: patientId || '',
      eye: eye || 'OD',
      filename: file.name,
      imageBase64
    });
    return d.record;
  };

  /** The cached record to show when live screening isn't available. */
  API.cachedRecord = async function (index) {
    const snap = await loadSnapshot();
    const recs = snap.records || [];
    if (!recs.length) return null;
    return recs[(index || 0) % recs.length];
  };

  API.review = async function (patientId, eye, finalGrade, notes, reviewerId) {
    if (API.online) {
      return req('POST', '/api/review', {
        patientId, eye, finalGrade, notes, reviewerId
      });
    }
    throw new Error('Saving a decision needs the MATLAB backend running.');
  };

  API.adminSnapshot = async function () {
    if (API.online) {
      const d = await req('GET', '/api/admin/snapshot');
      return d.snapshot;
    }
    const snap = await loadSnapshot();
    return snap.snapshot;
  };

  // ---------------------------------------------------------------
  function fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const fr = new FileReader();
      fr.onload = () => resolve(String(fr.result).split(',')[1]);
      fr.onerror = () => reject(new Error('Could not read the image file'));
      fr.readAsDataURL(file);
    });
  }

  window.NetraAPI = API;
  API.probe();
}());
