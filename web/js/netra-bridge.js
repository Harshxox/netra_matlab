/**
 * netra-bridge.js — connects the UI to the MATLAB backend.
 *
 * Loads AFTER app.js / workstation.js and progressively enhances them:
 * the original UI keeps working, but data paths are taken over by NetraAPI.
 * Nothing here invents clinical numbers — every value rendered comes from the
 * pipeline record. When the backend is offline the UI is labelled "cached"
 * and fed the pre-computed real pipeline snapshot.
 */
(function () {
  'use strict';

  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));

  const GRADE = [
    { label: 'No DR',           short: 'No DR',        color: '#0f766e', tone: 'ok'   },
    { label: 'Mild NPDR',       short: 'Mild',         color: '#ca8a04', tone: 'warn' },
    { label: 'Moderate NPDR',   short: 'Moderate',     color: '#ea580c', tone: 'high' },
    { label: 'Severe NPDR',     short: 'Severe',       color: '#dc2626', tone: 'high' },
    { label: 'Proliferative DR',short: 'Proliferative',color: '#991b1b', tone: 'high' }
  ];

  const LAYERS = [
    ['original',      'Original'],
    ['enhanced',      'Enhanced'],
    ['gradcam',       'Attention'],
    ['lesionOverlay', 'Lesions'],
    ['vesselMap',     'Vessels'],
    ['evidence',      'Evidence']
  ];

  // ================================================================
  // Styles (injected, so syncUI never overwrites them)
  // ================================================================
  function injectStyles() {
    if ($('#netra-bridge-css')) return;
    const st = document.createElement('style');
    st.id = 'netra-bridge-css';
    st.textContent = `
.nt-result{font:400 14px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;color:#0f172a}
[data-theme="dark"] .nt-result{color:#e2e8f0}
.nt-verdict{display:flex;align-items:center;gap:12px;padding:13px 16px;border-radius:12px;
  color:#fff;font-weight:700;letter-spacing:.02em;margin-bottom:16px}
.nt-verdict small{display:block;font-weight:500;opacity:.9;font-size:11.5px;letter-spacing:0}
.nt-verdict .ic{width:28px;height:28px;border-radius:50%;background:rgba(255,255,255,.22);
  display:grid;place-items:center;font-size:15px;flex:none}
.nt-grade{display:flex;align-items:flex-end;gap:16px;margin-bottom:6px}
.nt-grade b{font-size:52px;line-height:.92;font-weight:800;letter-spacing:-.02em}
.nt-grade span{font-size:17px;font-weight:600;padding-bottom:6px}
.nt-scale{display:flex;gap:5px;margin:12px 0 18px}
.nt-scale i{height:6px;flex:1;border-radius:3px;background:#e2e8f0;transition:background .3s}
[data-theme="dark"] .nt-scale i{background:#334155}
.nt-tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(112px,1fr));gap:9px;margin-bottom:18px}
.nt-tile{background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:10px 12px}
[data-theme="dark"] .nt-tile{background:#1e293b;border-color:#334155}
.nt-tile em{display:block;font-style:normal;font-size:10.5px;text-transform:uppercase;
  letter-spacing:.06em;color:#64748b;margin-bottom:3px}
.nt-tile b{font-size:19px;font-weight:700;letter-spacing:-.01em}
.nt-layers{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px}
.nt-layers button{font:600 11.5px system-ui,sans-serif;padding:6px 11px;border-radius:7px;
  border:1px solid #cbd5e1;background:#fff;color:#475569;cursor:pointer;transition:.15s}
.nt-layers button:hover{border-color:#94a3b8}
.nt-layers button.on{background:#0f766e;border-color:#0f766e;color:#fff}
[data-theme="dark"] .nt-layers button{background:#1e293b;border-color:#475569;color:#cbd5e1}
.nt-img{width:100%;aspect-ratio:1;object-fit:contain;background:#05080c;border-radius:12px;display:block}
.nt-cap{font-size:11.5px;color:#64748b;margin:7px 0 18px;text-align:center}
.nt-h{font-size:10.5px;text-transform:uppercase;letter-spacing:.07em;color:#64748b;
  font-weight:700;margin:0 0 9px}
.nt-find{width:100%;border-collapse:collapse;margin-bottom:18px;font-size:13px}
.nt-find th{text-align:left;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;
  color:#64748b;font-weight:600;padding:0 0 7px;border-bottom:1px solid #e2e8f0}
.nt-find td{padding:9px 0;border-bottom:1px solid #f1f5f9}
[data-theme="dark"] .nt-find td{border-color:#334155}
.nt-find td:nth-child(2){text-align:right;font-weight:700;font-variant-numeric:tabular-nums}
.nt-find td:nth-child(3){text-align:right;width:92px}
.nt-pill{display:inline-block;font-size:10.5px;font-weight:700;padding:3px 9px;border-radius:99px}
.nt-pill.ok{background:#d1fae5;color:#065f46}
.nt-pill.warn{background:#fef3c7;color:#92400e}
.nt-pill.high{background:#fee2e2;color:#991b1b}
.nt-why{background:#f8fafc;border-left:3px solid #0f766e;border-radius:0 9px 9px 0;
  padding:12px 15px;font-size:13px;line-height:1.55;margin-bottom:16px}
[data-theme="dark"] .nt-why{background:#1e293b}
.nt-chips{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:16px}
.nt-chip{font-size:10.5px;font-weight:600;padding:4px 10px;border-radius:99px;
  background:#f1f5f9;color:#475569;border:1px solid #e2e8f0}
[data-theme="dark"] .nt-chip{background:#1e293b;color:#cbd5e1;border-color:#334155}
.nt-foot{font-size:11px;color:#94a3b8;line-height:1.5;border-top:1px solid #e2e8f0;padding-top:12px}
.nt-err{background:#fef2f2;border:1px solid #fecaca;color:#991b1b;padding:13px 15px;
  border-radius:10px;font-size:13px;line-height:1.5}
.sim-step.nt-done .step-num{background:#0f766e!important;color:#fff!important}
`;
    document.head.appendChild(st);
  }

  // ================================================================
  // Mode badge
  // ================================================================
  function mountModeBadge() {
    if ($('#netra-mode-badge')) return;
    const el = document.createElement('div');
    el.id = 'netra-mode-badge';
    el.style.cssText = 'position:fixed;right:14px;bottom:14px;z-index:9999;'
      + 'font:600 11px/1.35 system-ui,-apple-system,sans-serif;padding:7px 11px;'
      + 'border-radius:999px;display:flex;align-items:center;gap:7px;'
      + 'box-shadow:0 3px 14px rgba(0,0,0,.18);user-select:none';
    el.innerHTML = '<span class="dot"></span><span class="txt">checking…</span>';
    document.body.appendChild(el);
    paintBadge(el, null);
  }

  function paintBadge(el, online) {
    el = el || $('#netra-mode-badge');
    if (!el) return;
    const dot = $('.dot', el), txt = $('.txt', el);
    dot.style.cssText = 'width:7px;height:7px;border-radius:50%;flex:none';
    if (online === true) {
      el.style.background = '#0f766e'; el.style.color = '#ecfdf5';
      dot.style.background = '#4ade80';
      txt.textContent = 'MATLAB backend live';
      el.title = 'Connected to netraServer — screenings run the real pipeline.';
    } else if (online === false) {
      el.style.background = '#78350f'; el.style.color = '#fef3c7';
      dot.style.background = '#fbbf24';
      txt.textContent = 'Cached pipeline output';
      el.title = 'MATLAB backend offline. Showing real results computed earlier. '
               + 'Live screening is disabled.';
    } else {
      el.style.background = '#334155'; el.style.color = '#e2e8f0';
      dot.style.background = '#94a3b8';
      txt.textContent = 'checking…';
    }
  }

  function toast(msg, kind) {
    const t = document.createElement('div');
    t.style.cssText = 'position:fixed;left:50%;top:22px;transform:translateX(-50%);'
      + 'z-index:10000;max-width:min(560px,90vw);font:500 13px/1.45 system-ui,sans-serif;'
      + 'padding:11px 16px;border-radius:10px;color:#fff;box-shadow:0 8px 28px rgba(0,0,0,.22);'
      + 'background:' + (kind === 'error' ? '#b91c1c' : kind === 'warn' ? '#b45309' : '#0f766e');
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .4s'; t.style.opacity = '0'; }, 4000);
    setTimeout(() => t.remove(), 4500);
  }

  // ================================================================
  // Scan flow: file -> preview -> steps -> pipeline -> result
  // ================================================================
  function mountUploader() {
    const anchors = ['#btnStartScanSequence', '#btnWelcomeSimulateScan', '#btnMenuSimulateScan']
      .map((s) => $(s)).filter(Boolean);
    if (!anchors.length) return;

    let input = $('#netra-file-input');
    if (!input) {
      input = document.createElement('input');
      input.type = 'file';
      input.id = 'netra-file-input';
      input.accept = 'image/png,image/jpeg,image/jpg,image/tif,image/tiff';
      input.style.display = 'none';
      document.body.appendChild(input);
      input.addEventListener('change', onFileChosen);
    }

    anchors.forEach((btn) => {
      btn.addEventListener('click', (ev) => {
        if (!window.NetraAPI || !window.NetraAPI.online) return;  // let the demo run
        ev.preventDefault();
        ev.stopImmediatePropagation();
        input.click();
      }, true);
    });
  }

  function setStep(n) {
    for (let i = 1; i <= 4; i++) {
      const el = $('#simStep' + i);
      if (!el) continue;
      el.classList.toggle('active', i === n);
      el.classList.toggle('nt-done', i < n);
    }
  }

  async function onFileChosen(ev) {
    const file = ev.target.files && ev.target.files[0];
    ev.target.value = '';
    if (!file) return;

    const patient = readActivePatient();
    const pid = (patient && (patient.patientId || patient.id)) || '';

    // 1/2 — show what was actually uploaded
    const preview = $('#simFundusPreviewImg');
    const objUrl = URL.createObjectURL(file);
    if (preview) preview.src = objUrl;
    const hud = $('#simHudStatus');
    if (hud) hud.textContent = 'IMAGE LOADED';
    setStep(2);

    const flash = $('#simCameraFlash');
    if (flash) { flash.style.animation = 'none'; void flash.offsetWidth; flash.style.animation = ''; }

    // 3 — pipeline
    setStep(3);
    if (hud) hud.textContent = 'MATLAB PIPELINE RUNNING';
    const box = $('#simDiagnosticsOutput');
    if (box) {
      box.style.display = 'block';
      box.innerHTML = '<div style="display:flex;align-items:center;gap:10px;font:500 13px system-ui">'
        + '<span style="width:16px;height:16px;border:2px solid rgba(15,118,110,.25);'
        + 'border-top-color:#0f766e;border-radius:50%;display:inline-block;'
        + 'animation:netraspin .8s linear infinite"></span>'
        + 'Quality check → segmentation → grading → explainability…</div>'
        + '<style>@keyframes netraspin{to{transform:rotate(360deg)}}</style>';
    }

    try {
      const record = await window.NetraAPI.screen(file, pid, 'OD');
      setStep(4);
      if (hud) hud.textContent = 'ANALYSIS COMPLETE';
      renderScanResult(record);
      renderRecord(record);
      toast('Grade ' + record.result.grade + ' · ' + record.result.gradeLabel
            + (record.result.referable ? ' — refer to specialist' : ' — routine follow-up'));
    } catch (e) {
      setStep(1);
      if (hud) hud.textContent = 'ANALYSIS FAILED';
      if (box) {
        box.style.display = 'block';
        box.innerHTML = '<div class="nt-err"><strong>Screening failed.</strong><br>'
          + esc(e.message) + '</div>';
      }
      toast(e.message, 'error');
    } finally {
      setTimeout(() => URL.revokeObjectURL(objUrl), 30000);
    }
  }

  // ================================================================
  // The clinical result panel
  // ================================================================
  function renderScanResult(rec) {
    const box = $('#simDiagnosticsOutput');
    if (!box || !rec || !rec.result) return;

    const res = rec.result;
    const les = rec.lesions || {};
    const q   = rec.quality || {};
    const ex  = rec.explain || {};
    const g   = GRADE[res.grade] || GRADE[0];
    const refer = !!res.referable;

    const pct = (x) => (x == null ? '—' : Math.round(x * 100) + '%');
    const url = (u) => window.NetraAPI.fileUrl(u);

    // severity scale 0-4
    const scale = GRADE.map((_, i) =>
      '<i style="background:' + (i <= res.grade ? g.color : '') + '"></i>').join('');

    // available image layers
    const layers = LAYERS.filter(([k]) => rec.images && rec.images[k]);
    const layerBtns = layers.map(([k, lbl], i) =>
      '<button data-layer="' + k + '"' + (i === 0 ? ' class="on"' : '') + '>' + lbl + '</button>'
    ).join('');

    const findings = [
      ['Microaneurysms',      fmtInt(les.maCount),       flag(les.maCount > 0)],
      ['Hemorrhages',         fmtInt(les.heCount),       flag(les.heCount > 0)],
      ['Hard exudates',       les.exudateAreaPct != null
                                ? Number(les.exudateAreaPct).toFixed(2) + '%' : '—',
                              flag(les.exudateAreaPct > 0)],
      ['Neovascularization',  les.nvPresent ? 'Present' : 'None',
                              les.nvPresent
                                ? '<span class="nt-pill high">critical</span>'
                                : '<span class="nt-pill ok">absent</span>']
    ].map((r) => '<tr><td>' + r[0] + '</td><td>' + r[1] + '</td><td>' + r[2] + '</td></tr>').join('');

    const why = (res.notes && res.notes.length) ? res.notes[0] : '';

    const chips = [];
    if (ex.heatMethod) chips.push('Attention: ' + ex.heatMethod);
    if (ex.xaiLabel)   chips.push('Attention vs lesions: ' + ex.xaiLabel
                                  + (ex.xaiScore != null ? ' (' + pct(ex.xaiScore) + ')' : ''));
    if (res.calibration && res.calibration.available) {
      chips.push('Confidence calibrated (' + res.calibration.method
                 + ', n=' + res.calibration.n + ')');
    }
    if (res.method) chips.push('Grader: ' + res.method);

    box.style.display = 'block';
    box.innerHTML =
      '<div class="nt-result">'

      + '<div class="nt-verdict" style="background:' + (refer ? g.color : '#0f766e') + '">'
      +   '<span class="ic">' + (refer ? '!' : '✓') + '</span>'
      +   '<span>' + (refer ? 'REFER TO SPECIALIST' : 'ROUTINE FOLLOW-UP')
      +     '<small>' + (refer
            ? 'Referable diabetic retinopathy detected (grade ≥ 2)'
            : 'No referable disease detected at this screening') + '</small></span>'
      + '</div>'

      + '<div class="nt-grade"><b style="color:' + g.color + '">' + res.grade + '</b>'
      +   '<span style="color:' + g.color + '">' + esc(res.gradeLabel || g.short)
      +   '<br><small style="font-weight:400;color:#64748b;font-size:12px">'
      +   'ICDR severity scale 0–4</small></span></div>'
      + '<div class="nt-scale">' + scale + '</div>'

      + '<div class="nt-tiles">'
      +   tile('Calibrated confidence', pct(res.confidence))
      +   tile('Referable risk',        pct(res.pReferable != null ? res.pReferable : res.confidence))
      +   tile('Image quality',         cap(q.status || '—'))
      +   tile('Analysis time',         rec.meta && rec.meta.elapsedSec
                                          ? rec.meta.elapsedSec.toFixed(1) + 's' : '—')
      + '</div>'

      + (layers.length
          ? '<p class="nt-h">Evidence</p>'
            + '<div class="nt-layers">' + layerBtns + '</div>'
            + '<img class="nt-img" id="nt-layer-img" alt="">'
            + '<p class="nt-cap">Generated by the MATLAB pipeline for this image.</p>'
          : '')

      + '<p class="nt-h">Findings</p>'
      + '<table class="nt-find"><thead><tr><th>Lesion</th><th style="text-align:right">Detected</th>'
      +   '<th style="text-align:right">Status</th></tr></thead><tbody>' + findings + '</tbody></table>'

      + (why ? '<p class="nt-h">Why this grade</p><div class="nt-why">' + esc(why) + '</div>' : '')

      + '<div class="nt-chips">' + chips.map((c) => '<span class="nt-chip">' + esc(c) + '</span>').join('') + '</div>'

      + '<div class="nt-foot">Screening aid for clinician review — not a diagnosis and not a '
      + 'certified medical device. A qualified ophthalmologist makes the final decision.</div>'
      + '</div>';

    // layer switching
    const img = $('#nt-layer-img', box);
    if (img && layers.length) window.NetraAPI.setImage(img, rec.images[layers[0][0]]);
    $$('.nt-layers button', box).forEach((b) => {
      b.addEventListener('click', () => {
        $$('.nt-layers button', box).forEach((x) => x.classList.remove('on'));
        b.classList.add('on');
        if (img) window.NetraAPI.setImage(img, rec.images[b.dataset.layer]);
      });
    });

    box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function tile(label, value) {
    return '<div class="nt-tile"><em>' + label + '</em><b>' + value + '</b></div>';
  }
  function flag(bad) {
    return bad ? '<span class="nt-pill warn">detected</span>'
               : '<span class="nt-pill ok">none</span>';
  }
  function fmtInt(n) { return (n == null) ? '—' : String(n); }

  // ================================================================
  // Doctor workstation rendering
  // ================================================================
  function renderRecord(rec) {
    if (!rec || !rec.result) return;
    window.__netraRecord = rec;
    const url = (u) => window.NetraAPI.fileUrl(u);
    const res = rec.result, les = rec.lesions || {};

    const imgs = rec.images || {};
    const pv = $('#fundusDisplayImg');
    if (pv && (imgs.evidence || imgs.gradcam || imgs.original)) {
      window.NetraAPI.setImage(pv, imgs.evidence || imgs.gradcam || imgs.original);
    }

    const ev = $('.evidence-card');
    if (ev) {
      const badge = $('.evidence-badge', ev), conf = $('.confidence', ev);
      const h3 = $('h3', ev), p = $('p', ev);
      if (badge) badge.textContent = rec.routing === 'refer_specialist'
        ? '⚠ REFER URGENT' : '✓ ROUTINE FOLLOW-UP';
      if (conf) conf.textContent = Math.round((res.confidence || 0) * 100) + '% Calibrated';
      if (h3) h3.textContent = 'Grade ' + res.grade + ': ' + (res.gradeLabel || '');
      if (p && res.notes && res.notes.length) p.textContent = res.notes[0];
    }

    const legend = $$('.legend-item b');
    if (legend.length >= 4) {
      legend[0].textContent = fmtInt(les.maCount);
      legend[1].textContent = fmtInt(les.heCount);
      legend[2].textContent = les.exudateAreaPct != null
        ? Number(les.exudateAreaPct).toFixed(1) + '%' : '—';
      legend[3].textContent = les.nvPresent ? 'Yes' : '0';
    }
    const lb = $('.layer-button[data-layer="4"] b');
    if (lb) lb.textContent = (les.maCount || 0) + (les.heCount || 0);

    const hud = $('.hud .ok');
    if (hud && rec.quality) {
      const f = rec.quality.focusScore;
      hud.textContent = 'Quality: ' + cap(rec.quality.status)
        + (f ? ' (focus ' + Number(f).toFixed(3) + ')' : '');
    }

    updateEvidenceSidebar(rec);
    swapRetinaCanvas(rec);
  }

  /**
   * The sidebar ships with hardcoded clinical claims (macular edema, a
   * glaucoma CDR, TTA agreement) that this pipeline does not produce.
   * Replace them with findings actually present in the record, so nothing
   * on screen asserts something the model never computed.
   */
  function updateEvidenceSidebar(rec) {
    const res = rec.result || {}, les = rec.lesions || {}, ex = rec.explain || {};
    const cards = $$('.evidence-card');

    // --- card 1: replace the three fabricated flags ------------------
    const flags = $$('.evidence-card .flag');
    if (flags.length) {
      const items = [];
      if (les.nvPresent) {
        items.push(['', 'Neovascularization detected',
                    'Proliferative features present — urgent referral', '']);
      }
      if (les.exudateAreaPct > 0) {
        items.push(['', 'Hard exudates ' + Number(les.exudateAreaPct).toFixed(2) + '% of retina',
                    'Detected by the lesion segmentation stage', 'warning']);
      }
      if (les.maCount != null || les.heCount != null) {
        items.push(['', 'MA ' + fmtInt(les.maCount) + ' · HE ' + fmtInt(les.heCount),
                    'Counts drive the ICDR grade', les.heCount > 0 ? 'warning' : 'normal']);
      }
      if (ex.xaiLabel) {
        items.push(['', 'Attention vs lesions: ' + ex.xaiLabel,
                    'Model attention overlaps the detected lesions', 'normal']);
      }
      if (rec.quality && rec.quality.status) {
        items.push(['', 'Image quality: ' + cap(rec.quality.status),
                    'Gating check before grading', 'normal']);
      }

      flags.forEach((el, i) => {
        const it = items[i];
        if (!it) { el.style.display = 'none'; return; }
        el.style.display = '';
        el.className = 'flag' + (it[3] ? ' ' + it[3] : '');
        el.innerHTML = '<b>' + (it[3] === 'normal' ? '✓' : '⚠') + '</b>'
          + '<span><strong>' + esc(it[1]) + '</strong><small>' + esc(it[2]) + '</small></span>';
      });
    }

    // --- card 2: self-checks from real values ------------------------
    const checks = $('.checks');
    if (checks) {
      const c = [];
      c.push(ck(rec.quality && rec.quality.status !== 'ungradable', 'Quality ' + cap((rec.quality || {}).status || '—')));
      c.push(ck(true, 'Confidence ' + Math.round((res.confidence || 0) * 100) + '%'));
      if (ex.xaiScore != null) {
        c.push(ck(ex.xaiLabel === 'aligned', 'Attention ' + Math.round(ex.xaiScore * 100) + '%'));
      }
      if (res.calibration && res.calibration.available) {
        c.push(ck(true, 'Calibrated (' + res.calibration.method + ')'));
      }
      if (res.method) c.push(ck(res.method !== 'rules', 'Grader: ' + res.method));
      checks.innerHTML = c.join('');
      const head = checks.parentElement && $('p', checks.parentElement);
      const pass = c.filter((x) => x.indexOf('check ok') > -1).length;
      if (head) head.textContent = pass + ' passed · ' + (c.length - pass) + ' to note';
    }

    // --- card 3: assistant grounded in the record --------------------
    const asst = $('.assistant');
    if (asst) {
      const why = (res.notes && res.notes.length) ? res.notes[0] : null;
      asst.innerHTML = why
        ? '<b>Why grade ' + res.grade + '?</b><br>' + esc(why)
          + ' Calibrated confidence ' + Math.round((res.confidence || 0) * 100) + '%.'
        : '<b>Grade ' + res.grade + '</b><br>Calibrated confidence '
          + Math.round((res.confidence || 0) * 100) + '%.';
    }
    if (cards[2]) {
      const prompts = $$('.assistant-prompt', cards[2]);
      if (prompts[0]) prompts[0].textContent = 'Why grade ' + res.grade + '?';
    }

    // --- legend tooltips ---------------------------------------------
    const li = $$('.legend-item');
    if (li.length >= 4) {
      li[0].title = 'Microaneurysms: ' + fmtInt(les.maCount) + ' detected';
      li[1].title = 'Hemorrhages: ' + fmtInt(les.heCount) + ' detected';
      li[2].title = 'Hard exudates: ' + (les.exudateAreaPct != null
                      ? Number(les.exudateAreaPct).toFixed(2) + '% retinal area' : 'n/a');
      li[3].title = 'Neovascularization: ' + (les.nvPresent ? 'present' : 'none detected');
    }
  }

  function ck(ok, label) {
    return '<span class="check' + (ok ? ' ok' : '') + '">'
         + (ok ? '✓ ' : '⚠ ') + esc(label) + '</span>';
  }

  function swapRetinaCanvas(rec) {
    const canvas = $('#retina-canvas');
    if (!canvas || !rec.images) return;
    const url = (u) => window.NetraAPI.fileUrl(u);
    const map = { 1: 'original', 2: 'enhanced', 3: 'gradcam', 4: 'lesionOverlay', 5: 'vesselMap' };

    let host = $('#netra-layer-img');
    if (!host) {
      host = document.createElement('img');
      host.id = 'netra-layer-img';
      host.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;'
                         + 'object-fit:contain;border-radius:inherit;background:#05080c';
      canvas.parentElement.style.position = 'relative';
      canvas.parentElement.appendChild(host);
    }
    canvas.style.visibility = 'hidden';

    const show = (n) => {
      const src = rec.images[map[n]];
      if (src) { window.NetraAPI.setImage(host, src); host.style.display = 'block'; }
      else { host.style.display = 'none'; canvas.style.visibility = 'visible'; }
    };
    show(1);
    $$('.layer-button').forEach((b) => {
      b.addEventListener('click', () => show(Number(b.dataset.layer)), true);
    });
  }

  // ================================================================
  // Doctor queue
  // ================================================================
  async function hydrateQueue() {
    const queue = $('#patient-queue');
    if (!queue) return;

    let snap;
    try { snap = await window.NetraAPI.adminSnapshot(); } catch (e) { return; }
    if (!snap || !snap.patients || !snap.patients.length) return;

    const rows = snap.patients
      .filter((p) => p.lastGrade != null && p.lastGrade >= 0)
      .sort((a, b) => (b.lastGrade || 0) - (a.lastGrade || 0));
    if (!rows.length) return;

    queue.innerHTML = rows.map((p, i) => {
      const urgent = !!p.referable || (p.lastGrade || 0) >= 2;
      return '<button class="queue-patient' + (i === 0 ? ' selected' : '')
        + '" data-pid="' + esc(p.patientId) + '" data-name="' + esc(p.name) + '">'
        + '<span><strong>' + esc(p.name) + '</strong><small>'
        + esc(p.patientId) + ' · ' + esc(p.village || 'PHC') + '</small></span>'
        + '<b class="severity ' + (urgent ? 'urgent' : 'routine') + '">'
        + (urgent ? 'URGENT' : 'ROUTINE') + ' · G' + p.lastGrade + '</b></button>';
    }).join('');

    const count = $('.queue-count');
    if (count) count.textContent = rows.length + ' Pending';
    const sum = $('.summary-number');
    if (sum) sum.innerHTML = rows.length + ' <small>cases waiting</small>';

    $$('.queue-patient', queue).forEach((btn) => {
      btn.addEventListener('click', async () => {
        $$('.queue-patient', queue).forEach((b) => b.classList.remove('selected'));
        btn.classList.add('selected');
        const nameEl = $('#patient-name');
        if (nameEl) nameEl.textContent = btn.dataset.name;
        try {
          const d = await window.NetraAPI.dossier(btn.dataset.pid);
          if (d) await renderDossier(d);
        } catch (e) { /* keep current view */ }
      });
    });

    const first = $('.queue-patient', queue);
    if (first) first.click();
  }

  async function renderDossier(d) {
    const p = d.profile || {};
    const head = $('.case-head p');
    if (head) {
      head.innerHTML = [
        p.age > 0 ? p.age + ' Yrs' : 'Age n/a',
        p.sex || '—',
        p.diabetesYears > 0 ? 'Diabetic ' + p.diabetesYears + ' Yrs' : 'Diabetes n/a',
        'ID: ' + esc(p.patientId || '')
      ].join(' · ') + '<br>' + esc(p.village || '');
    }

    const s = (d.screenings && d.screenings[0]) || null;
    const hasImages = s && s.images && Object.values(s.images).some(Boolean);

    // Offline the baked snapshot carries the richest record; online the
    // dossier now carries this screening's own overlays and lesion counts.
    if (!hasImages) {
      const full = await window.NetraAPI.recordFor(p.patientId);
      if (full) { renderRecord(full); return; }
    }
    if (!s) return;

    const les = s.lesions || {};
    renderRecord({
      result: {
        grade: s.grade, gradeLabel: s.gradeLabel,
        confidence: s.confidence, referable: s.referable, notes: []
      },
      lesions: les,
      routing: s.routing,
      quality: { status: s.qualityStatus, focusScore: les.focusScore || 0 },
      images: s.images || {},
      explain: {}
    });
  }

  // ================================================================
  // Login
  // ================================================================
  function wireLogin() {
    const form = $('#doctorLoginForm');
    if (!form) return;
    form.addEventListener('submit', async (ev) => {
      if (!window.NetraAPI || !window.NetraAPI.online) return;
      ev.preventDefault();
      ev.stopImmediatePropagation();
      const user = ($('#inputDoctorId') || {}).value || '';
      const pass = ($('#inputDoctorPassword') || {}).value || '';
      try {
        const r = await window.NetraAPI.login(user.trim(), pass);
        localStorage.setItem('netra_active_role', r.role === 'admin' ? 'district' : 'specialist');
        localStorage.setItem('netra_active_doctor', JSON.stringify({ name: r.name, role: r.role }));
        window.location.href = 'doctor-dashboard.html';
      } catch (e) { toast(e.message, 'error'); }
    }, true);
  }

  // ================================================================
  // Helpers
  // ================================================================
  function readActivePatient() {
    try { return JSON.parse(localStorage.getItem('netra_active_patient') || 'null'); }
    catch (e) { return null; }
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g,
      (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function cap(s) { s = String(s || ''); return s.charAt(0).toUpperCase() + s.slice(1); }

  // ================================================================
  // Boot
  // ================================================================
  function boot() {
    injectStyles();
    mountModeBadge();
    mountUploader();
    wireLogin();
  }

  document.addEventListener('netra:mode', async (e) => {
    paintBadge(null, e.detail.online);
    await hydrateQueue();
    if (!e.detail.online) {
      const rec = await window.NetraAPI.cachedRecord(0);
      if (rec) {
        renderRecord(rec);
        if ($('#simDiagnosticsOutput')) renderScanResult(rec);
      }
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
}());
