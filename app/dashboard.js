/* Netra dashboard - runs inside MATLAB uihtml.
   uihtml calls the global setup(htmlComponent). That object gives us:
     htmlComponent.Data                      - struct pushed from MATLAB
     htmlComponent.sendEventToMATLAB(n, d)   - HTML -> MATLAB
     htmlComponent.addEventListener(n, cb)   - MATLAB -> HTML  */

let hc = null;
let data = {};
let selectedEye = "OD";
let timer = null;

function setup(htmlComponent) {
  hc = htmlComponent;

  hc.addEventListener("DataChanged", () => render(hc.Data));
  hc.addEventListener("screening",   e => render(e.Data));
  hc.addEventListener("status",      e => showStatus(e.Data && e.Data.msg));

  wireControls();
  if (hc.Data && hc.Data.result) render(hc.Data);
}

function wireControls() {
  document.querySelectorAll(".eye").forEach(b =>
    b.addEventListener("click", () => {
      selectedEye = b.dataset.eye;
      document.querySelectorAll(".eye").forEach(x => x.classList.toggle("active", x === b));
      send("eyeChanged", { eye: selectedEye });
    }));

  document.querySelectorAll(".layer").forEach(b =>
    b.addEventListener("click", () => setLayer(b.dataset.layer, b)));

  document.getElementById("btnAgree").addEventListener("click", () =>
    send("reviewDecision", { type: "agree", finalGrade: gradeOf(data), notes: "" }));

  document.getElementById("btnOverride").addEventListener("click", () => {
    const p = document.getElementById("overridePanel");
    p.hidden = !p.hidden;
  });

  document.getElementById("btnOverrideSave").addEventListener("click", () =>
    send("reviewDecision", {
      type: "override",
      finalGrade: parseInt(document.getElementById("overrideGrade").value, 10),
      notes: document.getElementById("overrideNotes").value
    }));

  document.getElementById("btnPdf").addEventListener("click", () => send("generateReport", {}));
}

function render(d) {
  if (!d) return;
  data = d;

  document.getElementById("patientId").textContent = d.patientId || "--";

  const q = (d.quality && d.quality.status) || "--";
  const chip = document.getElementById("qualityChip");
  chip.textContent = q;
  chip.className = "chip " + q;

  const verdict = document.getElementById("verdict");
  const recapture = d.routing === "recapture" || !d.result;
  if (recapture) {
    verdict.textContent = "RECAPTURE IMAGE";
    verdict.className = "verdict recapture";
    setLayers(d);
    setWhy(["Image quality insufficient to grade",
            ...(d.quality && d.quality.reasons ? d.quality.reasons : [])]);
    clearGrade();
    startTimer();
    return;
  }

  const refer = !!d.result.referable;
  verdict.textContent = refer ? "REFER TO SPECIALIST" : "ROUTINE FOLLOW-UP";
  verdict.className = "verdict " + (refer ? "refer" : "routine");

  const g = gradeOf(d);
  document.querySelectorAll(".pip").forEach(p => {
    const pg = parseInt(p.dataset.g, 10);
    p.classList.toggle("on", pg <= g);
    p.classList.toggle("cur", pg === g);
  });
  document.getElementById("gradeLabel").textContent = d.result.gradeLabel || "";

  const c = Math.round((d.result.confidence || 0) * 100);
  document.getElementById("confPct").textContent = c + "%";
  document.getElementById("confFill").style.width = c + "%";
  document.getElementById("method").textContent =
    d.result.method ? ("method: " + d.result.method) : "";

  setWhy(d.result.notes || []);

  const L = d.lesions || {};
  document.getElementById("lesMA").textContent = num(L.maCount);
  document.getElementById("lesHE").textContent = num(L.heCount);
  document.getElementById("lesEX").textContent =
    (L.exudateAreaPct != null ? L.exudateAreaPct.toFixed(2) + "%" : "--");
  document.getElementById("lesNV").textContent = L.nvPresent ? "Present" : "Not detected";

  document.getElementById("historyTrend").textContent =
    (d.history && d.history.trend) || "First screening";

  setLayers(d);
  startTimer();
}

function setLayers(d) {
  const L = d.layers || {};
  window._layers = L;
  const order = ["evidence", "original", "enhanced", "gradcam", "lesionOverlay", "vesselMap"];
  const first = order.find(k => L[k]) || Object.keys(L)[0];
  const btn = document.querySelector('.layer[data-layer="' + first + '"]');
  setLayer(first, btn);
}

function setLayer(name, btn) {
  const L = window._layers || {};
  if (L[name]) document.getElementById("fundusImg").src = L[name];
  document.querySelectorAll(".layer").forEach(b => b.classList.toggle("active", b === btn));
}

function setWhy(items) {
  const ul = document.getElementById("whyList");
  ul.innerHTML = "";
  (items || []).forEach(t => {
    const li = document.createElement("li");
    li.textContent = t;
    ul.appendChild(li);
  });
}

function clearGrade() {
  document.querySelectorAll(".pip").forEach(p => p.classList.remove("on", "cur"));
  document.getElementById("gradeLabel").textContent = "--";
  document.getElementById("confFill").style.width = "0";
  document.getElementById("confPct").textContent = "--";
  ["lesMA","lesHE","lesEX","lesNV"].forEach(id => document.getElementById(id).textContent = "--");
}

function showStatus(msg) {
  const el = document.getElementById("statusMsg");
  el.textContent = msg || "";
  if (msg) setTimeout(() => (el.textContent = ""), 4000);
}

function startTimer() {
  let t = 30;
  const el = document.getElementById("reviewTimer");
  clearInterval(timer);
  const tick = () => {
    el.textContent = "0:" + String(Math.max(t, 0)).padStart(2, "0");
    if (t-- <= 0) clearInterval(timer);
  };
  tick();
  timer = setInterval(tick, 1000);
}

function send(name, payload) { if (hc) hc.sendEventToMATLAB(name, payload || {}); }
function gradeOf(d) { return d && d.result ? (d.result.grade | 0) : 0; }
function num(x) { return x == null ? "--" : String(x); }
