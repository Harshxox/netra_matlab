/* Netra - runs inside MATLAB uihtml.
   setup(htmlComponent): .Data / .sendEventToMATLAB(name,d) / .addEventListener(name,cb)
   All pipeline + storage logic is MATLAB-side; this file only renders. */

let hc = null;
let role = "operator";
let patient = null;        // current patient profile
let data = {};             // current screening record
let layers = {};
let findTimer = null;

const GRADE_COLORS = ["#10b981", "#84cc16", "#f59e0b", "#f97316", "#ef4444"];
const LAYER_DEFS = [
  ["evidence",      "Evidence",  '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>'],
  ["gradcam",       "Attention", '<circle cx="12" cy="12" r="5"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>'],
  ["lesionOverlay", "Lesions",   '<circle cx="7" cy="8" r="1.6"/><circle cx="15" cy="7" r="1.6"/><circle cx="11" cy="15" r="1.6"/>'],
  ["vesselMap",     "Vessels",   '<path d="M12 3v6M12 9 7 14M12 9l5 5M7 14v5M17 14v5"/>'],
  ["enhanced",      "Enhanced",  '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 12h16M12 4v16"/>'],
  ["original",      "Original",  '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="m21 17-5-5-9 8"/>'],
];
const VICON = {
  refer:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/></svg>',
  routine:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8.5 12.5 2.5 2.5 5-5"/></svg>',
  recapture: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 4h-5L8 6H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-4"/><path d="M17 8h5M19.5 5.5v5"/><circle cx="12" cy="13" r="3"/></svg>',
};

/* ============================================================ setup */
function setup(htmlComponent) {
  hc = htmlComponent;
  hc.addEventListener("session",        e => onSession(e.Data));
  hc.addEventListener("loggedOut",      () => showLogin());
  hc.addEventListener("patientResults", e => renderFindResults(e.Data && e.Data.rows));
  hc.addEventListener("patientReady",   e => onPatientReady(e.Data));
  hc.addEventListener("screening",      e => renderScreening(e.Data));
  hc.addEventListener("adminData",      e => renderAdmin(e.Data));
  hc.addEventListener("patientDetail",  e => renderPatientDetail(e.Data));
  hc.addEventListener("status",         e => showStatus(e.Data && e.Data.msg));
  hc.addEventListener("busy",           e => { if (e.Data && e.Data.on) showView("loading", e.Data.text); });
  buildLayerControl();
  wire();
}

/* ============================================================ auth */
function onSession(s) {
  if (!s || !s.ok) {
    const el = document.getElementById("loginErr");
    el.textContent = (s && s.msg) || "Sign-in failed";
    el.hidden = false;
    return;
  }
  role = s.role;
  document.getElementById("loginView").hidden = true;
  document.getElementById("shell").hidden = false;
  document.getElementById("userName").textContent = s.name || "User";
  document.getElementById("userRole").textContent = role === "admin" ? "District console" : "Screening operator";
  document.getElementById("userAv").textContent = initials(s.name);
  document.querySelector('[data-nav="admin"]').style.display = role === "admin" ? "" : "none";
  document.querySelector('[data-nav="patients"]').style.display = role === "admin" ? "none" : "";

  if (role === "admin") { navTo("admin"); }
  else { navTo("register"); document.getElementById("findInput").focus(); }
}
function showLogin() {
  document.getElementById("shell").hidden = true;
  document.getElementById("loginView").hidden = false;
  document.getElementById("loginUser").value = "";
  document.getElementById("loginPass").value = "";
  document.getElementById("loginErr").hidden = true;
  patient = null; data = {};
}

/* ============================================================ view routing */
const VIEWS = ["register", "landing", "loading", "dash", "admin"];
function showView(v, loadText) {
  VIEWS.forEach(k => { const el = document.getElementById(k); if (el) el.hidden = (k !== v); });
  document.getElementById("actionBar").hidden = (v !== "dash");
  document.getElementById("qualityChip").hidden = (v !== "dash");
  document.getElementById("eyeSeg").hidden = !(v === "dash" || v === "landing");
  document.getElementById("hdrSearch").hidden = true;
  document.getElementById("patientCtx").hidden = !(patient && (v === "landing" || v === "dash"));
  if (v === "loading" && loadText) document.getElementById("loadText").textContent = loadText;
}
function navTo(v) {
  document.querySelectorAll("#sideNav button").forEach(b =>
    b.classList.toggle("active", b.dataset.nav === (v === "admin" ? "admin" : v === "register" ? "patients" : "screen")));
  if (v === "admin") { showView("admin"); send("requestAdminData", {}); }
  else if (v === "register") { showView("register"); }
  else if (v === "screen") { showView(data && data.result !== undefined ? "dash" : (patient ? "landing" : "register")); }
  else showView(v);
}

/* ============================================================ wiring */
function wire() {
  document.getElementById("loginBtn").addEventListener("click", doLogin);
  document.getElementById("loginPass").addEventListener("keydown", e => { if (e.key === "Enter") doLogin(); });
  document.getElementById("logoutBtn").addEventListener("click", () => send("logout", {}));

  document.querySelectorAll("#sideNav button").forEach(b =>
    b.addEventListener("click", () => {
      const n = b.dataset.nav;
      if (n === "admin") navTo("admin");
      else if (n === "patients") navTo("register");
      else navTo("screen");
    }));

  // register view
  document.getElementById("findInput").addEventListener("input", e => {
    clearTimeout(findTimer);
    const q = e.target.value;
    findTimer = setTimeout(() => send("searchPatients", { q }), 220);
  });
  document.getElementById("rgSubmit").addEventListener("click", submitRegister);

  // screening
  document.querySelectorAll(".eye-seg button").forEach(b =>
    b.addEventListener("click", () => {
      document.querySelectorAll(".eye-seg button").forEach(x => x.classList.toggle("active", x === b));
      send("eyeChanged", { eye: b.dataset.eye });
    }));
  document.getElementById("ctaOpen").addEventListener("click", () => send("requestOpen", {}));
  document.getElementById("btnNew").addEventListener("click", () => navTo("register"));
  document.getElementById("btnAgree").addEventListener("click", () =>
    send("reviewDecision", { type: "agree", finalGrade: gradeOf(), notes: "" }));
  document.getElementById("btnOverride").addEventListener("click", () => {
    const p = document.getElementById("override-panel"); p.hidden = !p.hidden;
  });
  document.getElementById("btnOverrideSave").addEventListener("click", () => {
    send("reviewDecision", { type: "override",
      finalGrade: parseInt(document.getElementById("overrideGrade").value, 10),
      notes: document.getElementById("overrideNotes").value });
    document.getElementById("override-panel").hidden = true;
  });
  document.getElementById("btnPdf").addEventListener("click", () => send("generateReport", {}));
  document.getElementById("fsBtn").addEventListener("click", () => fs(true));
  document.getElementById("vmClose").addEventListener("click", () => fs(false));
  document.addEventListener("keydown", e => { if (e.key === "Escape") fs(false); });
  document.getElementById("viewerModal").addEventListener("click", e => { if (e.target.id === "viewerModal") fs(false); });

  // admin
  document.getElementById("admRefresh").addEventListener("click", () => send("requestAdminData", {}));
}
function doLogin() {
  send("login", {
    user: document.getElementById("loginUser").value,
    pass: document.getElementById("loginPass").value,
  });
}
function fs(on) { document.getElementById("viewerModal").hidden = !on; }

/* ============================================================ register / select patient */
function renderFindResults(rows) {
  const box = document.getElementById("findResults");
  if (!rows || !rows.length) { box.innerHTML = '<div class="rv-empty">No matching patients.</div>'; return; }
  box.innerHTML = rows.slice(0, 30).map(r => `
    <div class="rv-row" data-id="${esc(r.patientId)}">
      <div class="rr-av">${initials(r.name)}</div>
      <div class="rr-t"><b>${esc(r.name || "(no name)")}</b><span>${esc(r.patientId)}${r.phone ? " · " + esc(r.phone) : ""}</span></div>
      <div class="rr-meta">${has(r.age) ? r.age + "y " : ""}${esc(r.sex || "")}<br>${esc(r.village || "")}</div>
    </div>`).join("");
  box.querySelectorAll(".rv-row").forEach(el =>
    el.addEventListener("click", () => send("selectPatient", { patientId: el.dataset.id })));
}
function submitRegister() {
  const p = {
    name: v("rgName"), age: numv("rgAge"), sex: v("rgSex"), phone: v("rgPhone"),
    village: v("rgVillage"), diabetesYears: numv("rgDm"), notes: v("rgNotes"),
  };
  if (!p.name) { showStatus("Enter the patient's name"); return; }
  send("registerPatient", p);
}
function onPatientReady(d) {
  if (!d || !d.patient) return;
  patient = d.patient;
  setPatientCtx();
  document.getElementById("landingPatient").textContent =
    `${patient.name || patient.patientId}${patient.age ? ", " + patient.age + "y" : ""}${patient.village ? " · " + patient.village : ""}. Capture or upload the fundus photograph.`;
  data = {};
  navTo("screen");
  showView("landing");
  showStatus(d.isNew ? "Patient registered" : "Patient loaded");
}
function setPatientCtx() {
  const el = document.getElementById("patientCtx");
  if (!patient) { el.hidden = true; return; }
  el.innerHTML = `<div class="pc-av">${initials(patient.name)}</div>
    <div class="pc-t"><b>${esc(patient.name || patient.patientId)}</b>
    <span>${esc(patient.patientId)}${patient.age ? " · " + patient.age + "y" : ""}${patient.sex ? " " + esc(patient.sex) : ""}${patient.village ? " · " + esc(patient.village) : ""}</span></div>`;
  el.hidden = false;
}

/* ============================================================ screening render */
function renderScreening(d) {
  if (!d) return;
  data = d;
  if (d.patient) { patient = d.patient; setPatientCtx(); }

  const graded = d.result && !Array.isArray(d.result) && d.result.grade !== undefined;
  const recapture = d.routing === "recapture" || !graded;

  const q = (d.quality && d.quality.status) || "--";
  const chip = document.getElementById("qualityChip");
  chip.className = "chip " + q; chip.querySelector("span").textContent = q;

  layers = d.layers || {};
  refreshLayers();
  fs(false);
  setRing(graded ? d.result.grade : 0);
  navTo("screen"); showView("dash");
  const dash = document.getElementById("dash");
  dash.classList.remove("enter"); void dash.offsetWidth; dash.classList.add("enter");

  if (recapture) return renderRecapture(d);
  renderGraded(d);
}

function renderGraded(d) {
  const r = d.result, L = d.lesions || {};
  const g = r.grade | 0;
  const refer = !!r.referable;
  const conf = Math.round((r.confidence || 0) * 100);
  const calibrated = !!(r.calibration && r.calibration.available);
  const pRef = (r.pReferable != null) ? r.pReferable : pReferable(r);

  const pAge = (patient && has(patient.age)) ? patient.age + "y" : "--";
  document.getElementById("topVitals").innerHTML = `
    <div><b>${d.eye || "OD"}</b><span>Eye</span></div>
    <div><b>${pAge}</b><span>Age</span></div>
    <div><b>${conf}%</b><span>Confidence</span></div>`;

  document.getElementById("dTitle").textContent = "Grade " + g;
  document.getElementById("dSub").textContent = (r.gradeLabel || "") + "  ·  0-4 International Clinical DR scale";
  renderXaiStrip(d, r);

  setVerdict(refer ? "refer" : "routine",
    refer ? "Refer to specialist" : "Routine follow-up",
    routingText(d.routing) + "  ·  " + (r.method === "rules" ? "classical CV" : "ResNet-50") + (calibrated ? ", calibrated" : ""));

  document.getElementById("gauges").innerHTML = [
    gaugeCard("DR Severity", g, 0, 4, GRADE_COLORS[g], String(g), "of 4", "No DR", "Proliferative"),
    gaugeCard("Model Confidence", conf, 0, 100, "#0d9488", conf + "%", calibrated ? "calibrated" : "uncalibrated", "0%", "100%"),
    gaugeCard("Referable Risk", Math.round(pRef * 100), 0, 100, pRef >= 0.327 ? "#f43f5e" : "#10b981",
      Math.round(pRef * 100) + "%", calibrated ? "P(grade ≥ 2), calibrated" : "P(grade ≥ 2)", "low", "high"),
  ].join("");

  document.getElementById("findTbody").innerHTML = [
    findRow("Microaneurysms", "0 - 5", num(L.maCount), "> 15", statusOf(L.maCount, 6, 15), "Early DR marker"),
    findRow("Hemorrhages", "0", num(L.heCount), "≥ 1", statusOf(L.heCount, 1, 6), "Vascular leak"),
    findRow("Exudate area", "0%", fmtPct(L.exudateAreaPct), "> 0.6%", statusOf(L.exudateAreaPct, 0.1, 0.6), "Lipid deposit"),
    findRow("Neovascularization", "Absent", L.nvPresent ? "Present" : "Absent", "Present", L.nvPresent ? "high" : "normal", "Proliferative sign"),
  ].join("");

  setWhy(r.notes || []);
  const trend = d.history && d.history.trend;
  const t = document.getElementById("trend");
  t.textContent = trend || "First screening";
  t.className = "trend" + (trend && trend !== "First screening" ? "" : " empty");

  setLayer(layers.evidence ? "evidence" : firstLayer());
}

function renderRecapture(d) {
  document.getElementById("topVitals").innerHTML =
    `<div><b>${d.eye || "OD"}</b><span>Eye</span></div><div><b>--</b><span>Confidence</span></div><div><b>${fmtDate(d.date)}</b><span>Screened</span></div>`;
  document.getElementById("dTitle").textContent = "Ungradable";
  document.getElementById("dSub").textContent = "Image quality is insufficient for grading";
  document.getElementById("xaiStrip").innerHTML = "";
  setVerdict("recapture", "Recapture image", "Ask the operator to retake the photo");
  document.getElementById("gauges").innerHTML = "";
  document.getElementById("findTbody").innerHTML =
    `<tr><td class="ind" colspan="5" style="color:var(--ink-3)">Grading skipped &mdash; no lesion analysis performed.</td></tr>`;
  const reasons = (d.quality && d.quality.reasons && d.quality.reasons.length) ? d.quality.reasons : ["Image did not pass the quality check"];
  setWhy(reasons);
  const t = document.getElementById("trend"); t.textContent = "--"; t.className = "trend empty";
  setLayer(firstLayer());
}

/* ============================================================ admin console */
function renderAdmin(snap) {
  if (!snap) return;
  const s = snap.stats || {};
  document.getElementById("admStats").innerHTML = [
    admStat(s.totalPatients, "Registered patients"),
    admStat(s.totalScreenings, "Screenings done"),
    admStat(pctStr(s.referralRate), "Referral rate"),
    admStat(s.pendingReview, "Pending review"),
    admStat(s.screenedToday, "Screened today"),
  ].join("");

  const P = snap.patients || [];
  document.getElementById("admCount").textContent = P.length;
  document.getElementById("admTbody").innerHTML = P.map(p => `
    <tr data-id="${esc(p.patientId)}">
      <td class="ind">${esc(p.name || "(no name)")}<br><span style="color:var(--ink-3);font-weight:400">${esc(p.patientId)}</span></td>
      <td>${agey(p.age)} ${esc(p.sex || "")}</td>
      <td>${esc(p.village || "--")}</td>
      <td class="res">${p.screenings}</td>
      <td>${gradeBadge(p.lastGrade, p.lastGradeLabel)}</td>
      <td>${reviewPill(p.reviewStatus, p.screenings)}</td>
    </tr>`).join("") || `<tr><td colspan="6" class="rv-empty">No patients registered yet.</td></tr>`;

  document.querySelectorAll("#admTbody tr[data-id]").forEach(tr =>
    tr.addEventListener("click", () => {
      document.querySelectorAll("#admTbody tr").forEach(x => x.classList.remove("sel"));
      tr.classList.add("sel");
      send("requestPatientDetail", { patientId: tr.dataset.id });
    }));
}
function admStat(v, l) { return `<div class="adm-stat"><div class="as-v">${v == null ? "0" : v}</div><div class="as-l">${l}</div></div>`; }

function renderPatientDetail(d) {
  const box = document.getElementById("admDetail");
  if (!d || !d.profile) { box.innerHTML = '<div class="rv-empty">Patient not found.</div>'; return; }
  const p = d.profile;
  const sc = d.screenings || [];
  const trend = d.history && d.history.trend;

  box.innerHTML = `
    <div class="pd-profile">
      <div class="pd-av">${initials(p.name)}</div>
      <div class="pd-t"><b>${esc(p.name || "(no name)")}</b><span>${esc(p.patientId)}</span></div>
    </div>
    <div class="pd-meta">
      <div><b>Age / Sex</b>${agey(p.age)} ${esc(p.sex || "")}</div>
      <div><b>Phone</b>${esc(p.phone || "--")}</div>
      <div><b>Village / PHC</b>${esc(p.village || "--")}</div>
      <div><b>Diabetes</b>${yrs(p.diabetesYears)}</div>
      <div><b>Registered</b>${fmtDate(p.registeredOn)} by ${esc(p.registeredBy || "--")}</div>
      <div><b>Trend</b>${esc(trend || "First screening")}</div>
    </div>
    ${p.notes ? `<div class="pd-meta"><div style="grid-column:1/-1"><b>Notes</b>${esc(p.notes)}</div></div>` : ""}
    <div class="pd-sc-t">Screening history (${sc.length})</div>
    <div class="pd-sc">
      ${sc.length ? sc.map(s => scRow(s)).join("") : '<div class="rv-empty">No screenings yet for this patient.</div>'}
    </div>`;
  box.querySelectorAll("[data-report]").forEach(el =>
    el.addEventListener("click", () => send("openReportPath", { path: el.dataset.report })));
}
function scRow(s) {
  const g = s.grade;
  const col = (g == null) ? "#9aa3b2" : GRADE_COLORS[g];
  const gtxt = (g == null) ? "?" : g;
  return `<div class="pd-scrow">
    <div class="pd-grade" style="background:${col}">${gtxt}</div>
    <div class="pd-info"><b>${esc(s.gradeLabel || "Ungradable")} ${s.referable ? "· Referable" : ""}</b>
      <span>${fmtDateTime(s.date)} · ${esc(s.qualityStatus || "")} · ${esc(s.gradingMethod || "")} · review ${esc(s.reviewStatus || "-")}${s.finalGrade != null ? " (final " + s.finalGrade + ")" : ""}</span></div>
    ${s.reportPath ? `<span class="lk" data-report="${esc(s.reportPath)}">Open report</span>` : ""}
  </div>`;
}
function gradeBadge(g, label) {
  if (g == null) return `<span class="g-badge" style="color:var(--ink-3)">—</span>`;
  return `<span class="g-badge"><span class="g-dot" style="background:${GRADE_COLORS[g]}"></span>${g} ${esc(label || "")}</span>`;
}
function reviewPill(st, n) {
  if (!n) return `<span class="pill normal" style="background:var(--panel-2);color:var(--ink-3)">no screening</span>`;
  if (st === "reviewed") return `<span class="pill normal">reviewed</span>`;
  return `<span class="pill elevated">pending</span>`;
}

/* ============================================================ shared render bits */
function renderXaiStrip(d, r) {
  const box = document.getElementById("xaiStrip"); if (!box) return;
  const ex = d.explain || {}, cal = r.calibration || {}, chips = [];
  const method = ex.heatMethod === "gradcam" ? "Grad-CAM"
    : (ex.heatMethod || "").indexOf("occlusion") === 0 ? "Occlusion sensitivity" : "Lesion-evidence map";
  chips.push(chip("mid", eyeIcon(), method));
  if (ex.xaiLabel) {
    const cls = ex.xaiLabel === "aligned" ? "ok" : ex.xaiLabel === "partial" ? "mid" : "bad";
    chips.push(chip(cls, checkIcon(), "Attention " + ex.xaiLabel + (ex.xaiScore != null ? " " + Math.round(ex.xaiScore * 100) + "%" : "")));
  }
  chips.push(cal.available
    ? chip("ok", gaugeIcon(), "Confidence calibrated" + (cal.ece != null ? " · ECE " + (cal.ece * 100).toFixed(0) + "%" : ""))
    : chip("mid", gaugeIcon(), "Confidence uncalibrated"));
  box.innerHTML = chips.join("");
}
function chip(cls, icon, txt) { return '<span class="xai-chip ' + cls + '">' + icon + esc(txt) + '</span>'; }
function eyeIcon()   { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>'; }
function checkIcon() { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>'; }
function gaugeIcon() { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 13V7M4 14a8 8 0 0 1 16 0"/><circle cx="12" cy="14" r="1.6"/></svg>'; }

function gaugeCard(label, value, min, max, color, valText, unit, loLbl, hiLbl) {
  const frac = Math.max(0, Math.min(1, (value - min) / (max - min || 1)));
  return `<div class="gcard"><div class="glabel">${label}</div>
    <div class="gauge">${gaugeSVG(frac, color)}<div class="gval">${valText}<div class="gunit">${unit}</div></div></div>
    <div class="grange"><span>${loLbl}</span><span>${hiLbl}</span></div></div>`;
}
function gaugeSVG(frac, color) {
  const N = 30, cx = 100, cy = 96, R = 78, len = 13, fill = Math.round(frac * N);
  let t = "";
  for (let i = 0; i < N; i++) {
    const a = Math.PI - (i / (N - 1)) * Math.PI;
    const x1 = cx + (R - len) * Math.cos(a), y1 = cy - (R - len) * Math.sin(a);
    const x2 = cx + R * Math.cos(a), y2 = cy - R * Math.sin(a);
    t += `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${i < fill ? color : "#e6e9f0"}" stroke-width="4.4" stroke-linecap="round"/>`;
  }
  return `<svg viewBox="0 0 200 104">${t}</svg>`;
}
function findRow(ind, lo, res, hi, status, cat) {
  const label = { normal: "Normal", elevated: "Elevated", high: "High" }[status] || "Normal";
  const sub = cat ? `<br><span style="color:var(--ink-3);font-weight:500;font-size:11px">${cat}</span>` : "";
  return `<tr>
    <td class="ind">${ind}${sub}</td>
    <td>${lo}<span class="arrow">&rarr;</span></td>
    <td class="res">${res}</td>
    <td><span class="arrow">&larr;</span>${hi}</td>
    <td><span class="pill ${status}">${label}</span></td></tr>`;
}
function statusOf(v, warnAt, highAt) { v = v || 0; return v >= highAt ? "high" : v >= warnAt ? "elevated" : "normal"; }
function setVerdict(kind, label, sub) {
  const vv = document.getElementById("verdict");
  vv.className = "verdict " + kind;
  document.getElementById("verdictIcon").innerHTML = VICON[kind] || "";
  document.getElementById("verdictLabel").textContent = label;
  document.getElementById("verdictSub").textContent = sub || "";
}
function setWhy(items) {
  const ic = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>';
  document.getElementById("whyList").innerHTML =
    (items || []).map(x => `<div>${ic}<span>${esc(x)}</span></div>`).join("") || `<div><span>No specific findings recorded.</span></div>`;
}

/* ============================================================ layers */
function buildLayerControl() {
  const html = LAYER_DEFS.map(([k, label, p]) =>
    `<button data-layer="${k}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${p}</svg>${label}</button>`).join("");
  ["layerSeg", "modalLayerSeg"].forEach(id => {
    const seg = document.getElementById(id); if (!seg) return;
    seg.innerHTML = html;
    seg.querySelectorAll("button").forEach(b => b.addEventListener("click", () => setLayer(b.dataset.layer)));
  });
}
function refreshLayers() {
  document.querySelectorAll("#layerSeg button, #modalLayerSeg button").forEach(b => b.hidden = !layers[b.dataset.layer]);
  document.getElementById("legend").hidden = !(layers.evidence || layers.lesionOverlay);
}
function firstLayer() { return ["evidence", "original", "enhanced", "gradcam", "lesionOverlay", "vesselMap"].find(k => layers[k]) || Object.keys(layers)[0]; }
function setLayer(name) {
  if (!name || !layers[name]) return;
  document.getElementById("fundusImg").src = layers[name];
  document.getElementById("vmImg").src = layers[name];
  const def = LAYER_DEFS.find(d => d[0] === name);
  document.getElementById("imgCap").textContent = def ? def[1] : name;
  document.querySelectorAll("#layerSeg button, #modalLayerSeg button").forEach(b => b.classList.toggle("active", b.dataset.layer === name));
}
function setRing(grade) {
  const g = [
    ["#10b981", "rgba(16,185,129,.18)", "rgba(16,185,129,.4)"],
    ["#84cc16", "rgba(132,204,22,.18)", "rgba(132,204,22,.4)"],
    ["#f59e0b", "rgba(245,158,11,.18)", "rgba(245,158,11,.42)"],
    ["#f97316", "rgba(249,115,22,.18)", "rgba(249,115,22,.44)"],
    ["#ef4444", "rgba(239,68,68,.18)", "rgba(239,68,68,.46)"],
  ][Math.max(0, Math.min(4, grade | 0))];
  [document.getElementById("fundusFrame"), document.querySelector(".vm-frame")].forEach(el => {
    if (!el) return;
    el.style.setProperty("--ring-a", g[0]); el.style.setProperty("--ring-soft", g[1]); el.style.setProperty("--ring-glow", g[2]);
  });
}

/* ============================================================ misc */
function showStatus(msg) {
  const el = document.getElementById("statusMsg");
  if (!msg) { el.textContent = ""; return; }
  el.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>' + esc(msg);
  clearTimeout(el._t); el._t = setTimeout(() => (el.textContent = ""), 4500);
}
function send(name, p) { if (hc) hc.sendEventToMATLAB(name, p || {}); }
function gradeOf() { return (data.result && !Array.isArray(data.result)) ? (data.result.grade | 0) : 0; }
function pReferable(r) { const p = r.classProbabilities; return (Array.isArray(p) && p.length >= 5) ? p[2] + p[3] + p[4] : (r.referable ? 0.8 : 0.15); }
function num(x) { return x == null ? "0" : String(x); }
function has(x) { return typeof x === "number" && isFinite(x) && x >= 0; }
function agey(x) { return has(x) ? x + "y" : "--"; }
function yrs(x) { return has(x) ? x + " years" : "--"; }
function numv(id) { const x = parseFloat(document.getElementById(id).value); return isNaN(x) ? null : x; }
function v(id) { return document.getElementById(id).value.trim(); }
function fmtPct(x) { return x == null ? "0%" : x.toFixed(2) + "%"; }
function fmtDate(s) {
  if (!s) return "--";
  s = String(s);
  let m = s.match(/(\d{4})-(\d{2})-(\d{2})/);          // 2026-09-10
  if (m) return `${m[3]}/${m[2]}/${m[1].slice(2)}`;
  m = s.match(/^(\d{1,2})[ -]([A-Za-z]{3})[ -](\d{4})/); // 10 Sep 2026
  if (m) return `${m[1]} ${m[2]} ${m[3]}`;
  return s.slice(0, 12);
}
function fmtDateTime(s) { const d = fmtDate(s); const t = String(s || "").match(/(\d{2}):(\d{2})/); return t ? d + " " + t[0] : d; }
function pctStr(x) { return x == null ? "0%" : Math.round(x) + "%"; }
function routingText(r) { return { refer_specialist: "Refer to ophthalmology", routine_followup: "Annual re-screening", recapture: "Recapture image" }[r] || ""; }
function initials(n) { n = (n || "").trim(); if (!n) return "--"; const p = n.split(/\s+/); return (p[0][0] + (p.length > 1 ? p[p.length - 1][0] : "")).toUpperCase(); }
function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }
