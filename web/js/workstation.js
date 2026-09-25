(function () {
  'use strict';

  const roleLabels = {
    specialist: 'Specialist Workstation',
    phc: 'PHC Village Kiosk',
    district: 'District Operations',
    patient: 'Patient-Friendly View'
  };

  const patients = [
    { name: 'Ramesh Gowda', meta: 'ID #KA-CKB-2026-084 · Bagepalli PHC', severity: 'URGENT · 87', type: 'urgent' },
    { name: 'Lakshmi Devi', meta: 'ID #KA-CKB-2026-081 · Gudibande PHC', severity: 'URGENT · 82', type: 'urgent' },
    { name: 'Suresh Babu', meta: 'ID #KA-CKB-2026-077 · Chintamani PHC', severity: 'URGENT · 78', type: 'urgent' },
    { name: 'Meena Rani', meta: 'ID #KA-CKB-2026-072 · Sidlaghatta PHC', severity: 'ROUTINE · 41', type: 'routine' },
    { name: "Joseph D'Souza", meta: 'ID #KA-CKB-2026-069 · Bagepalli PHC', severity: 'ROUTINE · 26', type: 'routine' }
  ];

  const state = {
    role: localStorage.getItem('netra_active_role') || 'specialist',
    filter: 'all',
    layer: 1,
    eye: 'OD',
    elapsed: 19,
    queued: 0
  };

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  // Load actual high-resolution retinal fundus photograph
  const fundusImage = new Image();
  fundusImage.src = 'assets/images/retinal_fundus_od.jpg';
  let fundusReady = false;
  let enhancedBuffer = null;

  fundusImage.onload = () => {
    fundusReady = true;
    buildEnhancedBuffer();
    drawRetina();
  };

  function buildEnhancedBuffer() {
    try {
      const off = document.createElement('canvas');
      off.width = 800;
      off.height = 600;
      const octx = off.getContext('2d');
      octx.fillStyle = '#05080c';
      octx.fillRect(0, 0, 800, 600);

      const size = 570;
      const x = (800 - size) / 2;
      const y = (600 - size) / 2;
      octx.drawImage(fundusImage, x, y, size, size);

      const imgData = octx.getImageData(x, y, size, size);
      const d = imgData.data;
      for (let i = 0; i < d.length; i += 4) {
        const r = d[i];
        const g = d[i + 1];
        const b = d[i + 2];
        // Red-Free filter: isolate green spectrum (540nm) where hemoglobin absorbs heavily
        let gVal = (g * 1.38) - (r * 0.28);
        gVal = Math.min(255, Math.max(0, gVal));
        d[i] = Math.round(gVal * 0.65);
        d[i + 1] = Math.round(gVal * 1.18);
        d[i + 2] = Math.round(gVal * 0.85);
      }
      octx.putImageData(imgData, x, y);
      enhancedBuffer = off;
    } catch (e) {
      console.warn('Offscreen buffer filter fallback:', e);
    }
  }

  function setRole(role) {
    state.role = role;
    const allowedViews = role === 'patient' ? ['patient'] : ['specialist', 'phc', 'district'];
    $$('.role-nav button').forEach((button) => {
      const allowed = allowedViews.includes(button.dataset.view);
      button.hidden = !allowed;
      button.classList.toggle('active', button.dataset.view === role);
    });
    const activeView = allowedViews.includes(role) ? role : allowedViews[0];
    $$('.workstation-view').forEach((view) => view.classList.toggle('active', view.dataset.view === activeView));
    const roleLabel = $('#current-role-label');
    if (roleLabel) roleLabel.textContent = roleLabels[activeView];
  }

  function renderQueue() {
    const queue = $('#patient-queue');
    if (!queue) return;
    queue.innerHTML = patients
      .filter((patient) => state.filter === 'all' || patient.type === state.filter)
      .map((patient, index) => `<button class="queue-patient ${index === 0 ? 'selected' : ''}" data-name="${patient.name}"><span><strong>${patient.name}</strong><small>${patient.meta}</small></span><b class="severity ${patient.type}">${patient.severity}</b></button>`)
      .join('');
    $$('.queue-patient').forEach((button) => button.addEventListener('click', () => {
      $$('.queue-patient').forEach((item) => item.classList.remove('selected'));
      button.classList.add('selected');
      const name = $('#patient-name');
      if (name) name.textContent = button.dataset.name;
    }));
  }

  function drawRetina() {
    const canvas = $('#retina-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const layer = state.layer;
    const isOS = state.eye === 'OS';

    // Base background
    ctx.save();
    ctx.fillStyle = '#05080c';
    ctx.fillRect(0, 0, 800, 600);

    const size = 570;
    const imgX = (800 - size) / 2;
    const imgY = (600 - size) / 2;

    // If OS (Left eye), flip horizontally across center x = 400 for realistic anatomical symmetry
    if (isOS) {
      ctx.translate(800, 0);
      ctx.scale(-1, 1);
    }

    // LAYER 1 & BASE: Draw real fundus image
    if (layer === 2 && enhancedBuffer) {
      ctx.drawImage(enhancedBuffer, 0, 0);
    } else {
      if (layer === 2) {
        // Fallback filter if getImageData was restricted
        ctx.save();
        ctx.filter = 'contrast(170%) brightness(105%) hue-rotate(55deg) saturate(130%)';
        if (fundusReady) {
          ctx.drawImage(fundusImage, imgX, imgY, size, size);
        }
        ctx.restore();
      } else {
        if (fundusReady) {
          ctx.drawImage(fundusImage, imgX, imgY, size, size);
        } else {
          // Placeholder gradient until image completes load
          const g = ctx.createRadialGradient(400, 300, 30, 400, 300, 270);
          g.addColorStop(0, '#c2410c');
          g.addColorStop(0.7, '#7c2d12');
          g.addColorStop(1, '#05080c');
          ctx.fillStyle = g;
          ctx.beginPath();
          ctx.arc(400, 300, 270, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }

    // LAYER 2: Enhanced overlay telemetry & RNFL contrast markers
    if (layer === 2) {
      ctx.save();
      // Draw delicate green-spectrum optical vignette
      ctx.strokeStyle = 'rgba(74, 222, 128, 0.35)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(400, 300, 275, 0, Math.PI * 2);
      ctx.stroke();

      // Optical Disc focal ring (nasal side: x ~ 304, y ~ 288)
      ctx.strokeStyle = 'rgba(134, 239, 172, 0.85)';
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.arc(304, 288, 33, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    // LAYER 3: Grad-CAM Deep-Learning Attention Heatmap
    if (layer === 3) {
      ctx.save();
      ctx.globalCompositeOperation = 'source-over';

      // 1. Primary Paramacular / Foveal Threat Hotspot (Highest network activation: Severe NPDR)
      const grad1 = ctx.createRadialGradient(475, 290, 8, 475, 290, 95);
      grad1.addColorStop(0, 'rgba(239, 68, 68, 0.88)');    // Crimson Red Core (Peak)
      grad1.addColorStop(0.25, 'rgba(249, 115, 22, 0.76)'); // Fiery Orange
      grad1.addColorStop(0.5, 'rgba(234, 179, 8, 0.58)');   // Amber Gold
      grad1.addColorStop(0.72, 'rgba(34, 197, 94, 0.36)');  // Emerald Green
      grad1.addColorStop(0.88, 'rgba(6, 182, 212, 0.16)');  // Cyan Edge
      grad1.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad1;
      ctx.beginPath();
      ctx.arc(475, 290, 95, 0, Math.PI * 2);
      ctx.fill();

      // 2. Inferior Temporal Arcade Hemorrhage Hotspot
      const grad2 = ctx.createRadialGradient(430, 400, 6, 430, 400, 75);
      grad2.addColorStop(0, 'rgba(239, 68, 68, 0.82)');
      grad2.addColorStop(0.3, 'rgba(249, 115, 22, 0.68)');
      grad2.addColorStop(0.6, 'rgba(234, 179, 8, 0.42)');
      grad2.addColorStop(0.85, 'rgba(59, 130, 246, 0.16)');
      grad2.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad2;
      ctx.beginPath();
      ctx.arc(430, 400, 75, 0, Math.PI * 2);
      ctx.fill();

      // 3. Superior Temporal Arcade Hotspot
      const grad3 = ctx.createRadialGradient(455, 170, 5, 455, 170, 62);
      grad3.addColorStop(0, 'rgba(249, 115, 22, 0.78)');
      grad3.addColorStop(0.35, 'rgba(234, 179, 8, 0.52)');
      grad3.addColorStop(0.7, 'rgba(16, 185, 129, 0.22)');
      grad3.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad3;
      ctx.beginPath();
      ctx.arc(455, 170, 62, 0, Math.PI * 2);
      ctx.fill();

      // 4. Subtle posterior pole ambient baseline
      const grad4 = ctx.createRadialGradient(430, 295, 20, 430, 295, 220);
      grad4.addColorStop(0, 'rgba(59, 130, 246, 0.18)');
      grad4.addColorStop(0.65, 'rgba(6, 182, 212, 0.08)');
      grad4.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad4;
      ctx.beginPath();
      ctx.arc(430, 295, 220, 0, Math.PI * 2);
      ctx.fill();

      ctx.restore();
    }

    // LAYER 4: Lesion Overlay (14 Microaneurysms + 9 Hemorrhages + Hard Exudates = 23 Lesions)
    if (layer === 4) {
      ctx.save();

      // A. 14 Microaneurysms (MA 1–14)
      const microaneurysms = [
        { x: 452, y: 275 }, { x: 468, y: 260 }, { x: 440, y: 310 },
        { x: 476, y: 326 }, { x: 516, y: 272 }, { x: 528, y: 292 },
        { x: 508, y: 322 }, { x: 432, y: 285 }, { x: 486, y: 254 },
        { x: 396, y: 338 }, { x: 412, y: 238 }, { x: 536, y: 314 },
        { x: 452, y: 346 }, { x: 492, y: 342 }
      ];

      microaneurysms.forEach((p) => {
        // Red core
        ctx.fillStyle = '#ef4444';
        ctx.beginPath();
        ctx.arc(p.x, p.y, 3.5, 0, Math.PI * 2);
        ctx.fill();

        // White hairline targeting ring
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 7, 0, Math.PI * 2);
        ctx.stroke();

        // Crimson halo
        ctx.strokeStyle = 'rgba(239, 68, 68, 0.55)';
        ctx.beginPath();
        ctx.arc(p.x, p.y, 11, 0, Math.PI * 2);
        ctx.stroke();
      });

      // B. 9 Retinal Hemorrhages (H 1–9)
      const hemorrhages = [
        { x: 430, y: 388, rx: 11, ry: 8, rot: 0.2 },
        { x: 462, y: 412, rx: 12, ry: 9, rot: -0.3 },
        { x: 380, y: 368, rx: 8,  ry: 7, rot: 0.1 },
        { x: 445, y: 174, rx: 15, ry: 7, rot: 0.6 },
        { x: 490, y: 162, rx: 9,  ry: 7, rot: 0.4 },
        { x: 388, y: 218, rx: 7,  ry: 6, rot: 0.0 },
        { x: 542, y: 362, rx: 10, ry: 8, rot: -0.2 },
        { x: 348, y: 322, rx: 8,  ry: 7, rot: 0.5 },
        { x: 414, y: 428, rx: 11, ry: 9, rot: 0.3 }
      ];

      hemorrhages.forEach((h) => {
        ctx.save();
        ctx.translate(h.x, h.y);
        ctx.rotate(h.rot);

        // Hemorrhage filled body
        ctx.fillStyle = 'rgba(220, 38, 38, 0.55)';
        ctx.beginPath();
        ctx.ellipse(0, 0, h.rx, h.ry, 0, 0, Math.PI * 2);
        ctx.fill();

        // Clinical blue border (matches H swatch #3b82f6)
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 1.8;
        ctx.stroke();

        // Crosshair brackets
        ctx.strokeStyle = 'rgba(59, 130, 246, 0.8)';
        ctx.lineWidth = 1;
        ctx.strokeRect(-h.rx - 3, -h.ry - 3, (h.rx + 3) * 2, (h.ry + 3) * 2);
        ctx.restore();
      });

      // C. Hard Exudates (HE: 3.2% retinal area - circinate ring near macula)
      const exudates = [
        { x: 462, y: 278, r: 2.5 }, { x: 466, y: 284, r: 3.0 }, { x: 458, y: 288, r: 2.2 },
        { x: 460, y: 298, r: 2.8 }, { x: 465, y: 306, r: 3.2 }, { x: 472, y: 312, r: 2.4 },
        { x: 479, y: 308, r: 3.5 }, { x: 483, y: 300, r: 2.6 }, { x: 485, y: 290, r: 3.0 },
        { x: 480, y: 282, r: 2.4 }, { x: 474, y: 275, r: 3.1 }, { x: 468, y: 271, r: 2.2 },
        { x: 452, y: 292, r: 2.5 }, { x: 456, y: 304, r: 2.0 }, { x: 470, y: 318, r: 2.7 },
        { x: 478, y: 316, r: 2.9 }, { x: 488, y: 296, r: 2.1 }, { x: 482, y: 272, r: 2.6 },
        { x: 494, y: 285, r: 2.8 }, { x: 492, y: 310, r: 2.4 }, { x: 450, y: 280, r: 2.2 }
      ];

      exudates.forEach((ex) => {
        ctx.fillStyle = '#fef08a'; // bright glistening yellow
        ctx.beginPath();
        ctx.arc(ex.x, ex.y, ex.r, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#eab308'; // golden amber core
        ctx.beginPath();
        ctx.arc(ex.x, ex.y, ex.r * 0.5, 0, Math.PI * 2);
        ctx.fill();
      });

      // D. High-Risk Lesion Bounding Box (Edema Threat Area)
      ctx.strokeStyle = '#ef4444';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 4]);
      ctx.strokeRect(420, 240, 125, 115);
      ctx.setLineDash([]);

      // Corner brackets
      ctx.strokeStyle = '#ef4444';
      ctx.lineWidth = 2.5;
      const bx = 420, by = 240, bw = 125, bh = 115, cl = 10;
      ctx.beginPath(); ctx.moveTo(bx, by + cl); ctx.lineTo(bx, by); ctx.lineTo(bx + cl, by); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(bx + bw - cl, by); ctx.lineTo(bx + bw, by); ctx.lineTo(bx + bw, by + cl); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(bx, by + bh - cl); ctx.lineTo(bx, by + bh); ctx.lineTo(bx + cl, by + bh); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(bx + bw - cl, by + bh); ctx.lineTo(bx + bw, by + bh); ctx.lineTo(bx + bw, by + bh - cl); ctx.stroke();

      ctx.restore();
    }

    // LAYER 5: Retinal Vessel Tree Segmentation
    if (layer === 5) {
      ctx.save();
      // Darken fundus background slightly for high vessel visibility
      ctx.fillStyle = 'rgba(5, 8, 12, 0.45)';
      ctx.fillRect(0, 0, 800, 600);

      // Superior Temporal Arcade Arteriole (Cyan #06b6d4)
      ctx.strokeStyle = '#06b6d4';
      ctx.lineWidth = 3.2;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.shadowColor = 'rgba(6, 182, 212, 0.65)';
      ctx.shadowBlur = 4;
      ctx.beginPath();
      ctx.moveTo(304, 275);
      ctx.bezierCurveTo(335, 210, 400, 155, 475, 140);
      ctx.bezierCurveTo(540, 130, 605, 150, 660, 195);
      ctx.stroke();

      // Superior Branch to Macula
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.moveTo(450, 155);
      ctx.bezierCurveTo(465, 195, 480, 230, 488, 255);
      ctx.stroke();

      // Superior Venule (Soft Periwinkle Indigo #818cf8)
      ctx.strokeStyle = '#818cf8';
      ctx.shadowColor = 'rgba(129, 140, 248, 0.5)';
      ctx.lineWidth = 3.6;
      ctx.beginPath();
      ctx.moveTo(300, 268);
      ctx.bezierCurveTo(325, 195, 395, 138, 470, 125);
      ctx.bezierCurveTo(550, 115, 620, 138, 680, 180);
      ctx.stroke();

      // Inferior Temporal Arcade Arteriole (Teal Cyan #14b8a6)
      ctx.strokeStyle = '#14b8a6';
      ctx.shadowColor = 'rgba(20, 184, 166, 0.65)';
      ctx.lineWidth = 3.4;
      ctx.beginPath();
      ctx.moveTo(304, 305);
      ctx.bezierCurveTo(345, 385, 410, 435, 485, 442);
      ctx.bezierCurveTo(555, 448, 615, 425, 665, 390);
      ctx.stroke();

      // Inferior Branch
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.moveTo(435, 415);
      ctx.bezierCurveTo(455, 375, 470, 345, 480, 335);
      ctx.stroke();

      // Inferior Venule (Periwinkle Indigo #818cf8)
      ctx.strokeStyle = '#818cf8';
      ctx.lineWidth = 3.8;
      ctx.beginPath();
      ctx.moveTo(300, 312);
      ctx.bezierCurveTo(335, 395, 400, 452, 475, 458);
      ctx.bezierCurveTo(545, 464, 625, 442, 680, 405);
      ctx.stroke();

      // Nasal Arteriole Branches
      ctx.strokeStyle = '#0ea5e9';
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      ctx.moveTo(304, 282);
      ctx.bezierCurveTo(260, 260, 215, 250, 168, 238);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(304, 296);
      ctx.bezierCurveTo(255, 330, 210, 355, 162, 372);
      ctx.stroke();

      ctx.shadowBlur = 0;

      // Optic Disc Neuroretinal Rim Outline (Emerald Green #10b981)
      ctx.strokeStyle = '#10b981';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(304, 288, 34, 0, Math.PI * 2);
      ctx.stroke();

      // Physiological Cup Boundary (Dashed Yellow #facc15 · CDR: 0.68)
      ctx.strokeStyle = '#facc15';
      ctx.lineWidth = 1.6;
      ctx.setLineDash([4, 3]);
      ctx.beginPath();
      ctx.arc(304, 288, 23, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);

      // Foveal Avascular Zone (FAZ 500µm Boundary)
      ctx.strokeStyle = '#eab308';
      ctx.lineWidth = 1.6;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.arc(494, 299, 22, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.restore();
    }

    // Restore coordinate transform if OS was flipped
    ctx.restore();

    // =========================================================================
    // HUD TELEMETRY & CLINICAL ANNOTATIONS (Always unflipped in screen space)
    // =========================================================================
    ctx.save();
    ctx.font = '600 11px Inter, system-ui, sans-serif';
    ctx.textBaseline = 'middle';

    // Layer-specific diagnostic HUD bar at bottom
    ctx.fillStyle = 'rgba(15, 23, 42, 0.88)';
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
    ctx.lineWidth = 1;
    ctx.roundRect(14, 554, 772, 34, 6);
    ctx.fill();
    ctx.stroke();

    if (layer === 1) {
      ctx.fillStyle = '#38bdf8';
      ctx.fillText('RAW COLOR FUNDUS', 28, 571);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('· 45° Posterior Pole · Optic Disc & Macula Centred · SNR 8.9 dB (Gradable)', 175, 571);
    } else if (layer === 2) {
      ctx.fillStyle = '#4ade80';
      ctx.fillText('RED-FREE / 540nm GREEN SPECTRUM', 28, 571);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('· RNFL Striations & Capillary Endothelium Highlighted · Hemorrhage Contrast Boosted', 270, 571);
    } else if (layer === 3) {
      ctx.fillStyle = '#f87171';
      ctx.fillText('GRAD-CAM AI HEATMAP', 28, 571);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('· Peak Attention 87.4% at Paramacular Region · Class Verdict: Grade 3 Severe NPDR', 188, 571);
      // Small colorbar indicator
      const cgrad = ctx.createLinearGradient(680, 0, 770, 0);
      cgrad.addColorStop(0, '#06b6d4');
      cgrad.addColorStop(0.5, '#eab308');
      cgrad.addColorStop(1, '#ef4444');
      ctx.fillStyle = cgrad;
      ctx.fillRect(680, 564, 90, 14);
      ctx.strokeStyle = 'rgba(255,255,255,0.3)';
      ctx.strokeRect(680, 564, 90, 14);
    } else if (layer === 4) {
      ctx.fillStyle = '#f87171';
      ctx.fillText('23 LESIONS MAPPED', 28, 571);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('· 14 Microaneurysms (Crimson) · 9 Hemorrhages (Blue) · Hard Exudates 3.2% (Yellow)', 166, 571);
    } else if (layer === 5) {
      ctx.fillStyle = '#22d3ee';
      ctx.fillText('VESSEL SEGMENTATION TREE', 28, 571);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('· Arteriolar Arcades (Cyan) · Venules (Indigo) · CDR 0.68 · FAZ Ø 500µm Clear Reflex', 212, 571);
    }

    ctx.restore();
  }

  function setupLoupe() {
    const viewport = $('.canvas-wrap');
    const loupe = $('#retina-loupe');
    const canvas = $('#retina-canvas');
    const loupeCanvas = $('#loupe-canvas');
    if (!viewport || !loupe || !canvas || !loupeCanvas) return;
    const loupeCtx = loupeCanvas.getContext('2d');

    const LOUPE_SIZE = 160;
    const ZOOM = 2.5;
    const SRC_SIZE = LOUPE_SIZE / ZOOM; // 64px from main canvas

    function updateLoupePosition(clientX, clientY) {
      const rect = canvas.getBoundingClientRect();
      const mouseX = clientX - rect.left;
      const mouseY = clientY - rect.top;

      // If mouse is outside visible canvas area, hide loupe
      if (mouseX < 0 || mouseY < 0 || mouseX > rect.width || mouseY > rect.height) {
        loupe.style.display = 'none';
        return;
      }

      // Convert mouse coordinates on canvas DOM element to internal 800x600 canvas coordinate space
      const cx = (mouseX / rect.width) * canvas.width;
      const cy = (mouseY / rect.height) * canvas.height;

      // Position circular loupe centered exactly on the cursor
      const wrapRect = viewport.getBoundingClientRect();
      const lx = clientX - wrapRect.left - (LOUPE_SIZE / 2);
      const ly = clientY - wrapRect.top - (LOUPE_SIZE / 2);
      loupe.style.left = `${lx}px`;
      loupe.style.top = `${ly}px`;
      loupe.style.display = 'block';

      // Source rectangle centered around (cx, cy)
      const sx = cx - (SRC_SIZE / 2);
      const sy = cy - (SRC_SIZE / 2);

      // Render 2.5x point magnification into loupe-canvas
      loupeCtx.save();
      loupeCtx.clearRect(0, 0, LOUPE_SIZE, LOUPE_SIZE);

      // Clip circular aperture
      loupeCtx.beginPath();
      loupeCtx.arc(LOUPE_SIZE / 2, LOUPE_SIZE / 2, (LOUPE_SIZE / 2) - 1, 0, Math.PI * 2);
      loupeCtx.clip();

      // Dark background
      loupeCtx.fillStyle = '#05080c';
      loupeCtx.fillRect(0, 0, LOUPE_SIZE, LOUPE_SIZE);

      // Draw zoomed portion directly from active main canvas
      loupeCtx.imageSmoothingEnabled = true;
      loupeCtx.imageSmoothingQuality = 'high';
      loupeCtx.drawImage(canvas, sx, sy, SRC_SIZE, SRC_SIZE, 0, 0, LOUPE_SIZE, LOUPE_SIZE);

      // Optical precision crosshair reticle
      const mid = LOUPE_SIZE / 2;
      loupeCtx.strokeStyle = 'rgba(14, 165, 233, 0.45)';
      loupeCtx.lineWidth = 1;
      loupeCtx.beginPath();
      // Hairlines with center clearance
      loupeCtx.moveTo(mid, mid - 32); loupeCtx.lineTo(mid, mid - 8);
      loupeCtx.moveTo(mid, mid + 8); loupeCtx.lineTo(mid, mid + 32);
      loupeCtx.moveTo(mid - 32, mid); loupeCtx.lineTo(mid - 8, mid);
      loupeCtx.moveTo(mid + 8, mid); loupeCtx.lineTo(mid + 32, mid);
      loupeCtx.stroke();

      // Center pinpoint circle
      loupeCtx.beginPath();
      loupeCtx.arc(mid, mid, 7, 0, Math.PI * 2);
      loupeCtx.stroke();

      // Outer focus ring
      loupeCtx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
      loupeCtx.beginPath();
      loupeCtx.arc(mid, mid, 44, 0, Math.PI * 2);
      loupeCtx.stroke();

      loupeCtx.restore();
    }

    viewport.addEventListener('mousemove', (event) => {
      updateLoupePosition(event.clientX, event.clientY);
    });

    viewport.addEventListener('mouseleave', () => {
      loupe.style.display = 'none';
    });

    // Touch support for mobile/tablets
    viewport.addEventListener('touchmove', (event) => {
      if (event.touches.length > 0) {
        updateLoupePosition(event.touches[0].clientX, event.touches[0].clientY);
      }
    }, { passive: true });

    viewport.addEventListener('touchend', () => {
      loupe.style.display = 'none';
    });
  }

  function updateSimulation() {
    const arrival = Number($('#sim-arrival-rate')?.value || 274);
    const specialists = Number($('#sim-specialists')?.value || 2);
    const bandwidth = Number($('#sim-bandwidth')?.value || 10);
    const wait = Math.max(2.4, (arrival / (specialists * 11)) + (10 / bandwidth) - 1.3);
    $('#sim-arrival-value').textContent = `${arrival} patients/day`;
    $('#sim-specialists-value').textContent = `${specialists} Specialist${specialists === 1 ? '' : 's'}`;
    $('#sim-bandwidth-value').textContent = `${bandwidth} Mbps`;
    $('#sim-wait').textContent = `${wait.toFixed(1)} Hours`;
    $('#sim-recommendation').innerHTML = `At <strong>${arrival} patients/day</strong>, <strong>${specialists} specialist${specialists === 1 ? '' : 's'}</strong> project an average wait of <strong>${wait.toFixed(1)}h</strong>.`;
    $('#sim-sla').textContent = wait < 24 ? '✓ Complies with <24h SLA' : '⚠ Exceeds 24h SLA';
    $('#sim-sla').className = `status-badge ${wait < 24 ? 'normal' : 'critical'}`;
  }

  function speakPatientReport() {
    if (!('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    const text = $('#patient-report')?.textContent || 'Please visit the district eye hospital for your specialist checkup.';
    window.speechSynthesis.speak(new SpeechSynthesisUtterance(text));
  }

  function init() {
    document.documentElement.dataset.theme = localStorage.getItem('netra_theme') || 'light';
    const storedRole = ['specialist', 'phc', 'district', 'patient'].includes(state.role) ? state.role : 'specialist';
    setRole(storedRole);
    renderQueue();
    drawRetina();
    setupLoupe();

    $$('.role-nav button').forEach((button) => button.addEventListener('click', () => setRole(button.dataset.view)));
    $$('.queue-filter button').forEach((button) => button.addEventListener('click', () => {
      $$('.queue-filter button').forEach((item) => item.classList.remove('active'));
      button.classList.add('active');
      state.filter = button.dataset.filter;
      renderQueue();
    }));
    $$('.layer-button').forEach((button) => button.addEventListener('click', () => {
      $$('.layer-button').forEach((item) => item.classList.remove('active'));
      button.classList.add('active');
      state.layer = Number(button.dataset.layer);
      drawRetina();
    }));
    window.addEventListener('keydown', (e) => {
      if (['1', '2', '3', '4', '5'].includes(e.key) && !['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) {
        const btn = $(`.layer-button[data-layer="${e.key}"]`);
        if (btn) btn.click();
      }
    });
    $('#zoom-reset')?.addEventListener('click', () => {
      const canvas = $('#retina-canvas');
      if (canvas) canvas.style.transform = 'scale(1)';
    });
    $('#compare-button')?.addEventListener('click', () => $('#compare-panel').classList.toggle('open'));
    $('#close-compare')?.addEventListener('click', () => $('#compare-panel').classList.remove('open'));
    $('#theme-button')?.addEventListener('click', () => {
      const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      localStorage.setItem('netra_theme', next);
    });
    $('.work-tools a[href="login.html"]')?.addEventListener('click', () => {
      localStorage.removeItem('netra_active_role');
      localStorage.removeItem('netra_active_doctor');
    });
    $('#agree-button')?.addEventListener('click', (event) => { event.currentTarget.textContent = '✓ Verdict Recorded'; });
    $('#override-button')?.addEventListener('click', () => {
      const grade = window.prompt('Override DR grade (0-4):', '2');
      if (grade !== null) window.alert(`Case updated to Grade ${grade}. Audit entry created.`);
    });
    $('#report-button')?.addEventListener('click', () => window.print());
    $('#notes-button')?.addEventListener('click', () => window.prompt('Add clinical note:'));
    $$('.assistant-prompt').forEach((button) => button.addEventListener('click', () => window.alert(`${button.textContent}\n\nGrounded in current patient telemetry.`)));
    $$('.eye-tab').forEach((button) => button.addEventListener('click', () => {
      $$('.eye-tab').forEach((item) => item.classList.remove('active'));
      button.classList.add('active');
      state.eye = button.dataset.eye;
      $('#eye-hud').textContent = `${button.dataset.eye} · Macula Centred`;
      drawRetina();
    }));
    $$('.capture-test').forEach((button) => button.addEventListener('click', () => {
      const quality = $('#capture-quality');
      const message = $('#capture-message');
      const good = button.dataset.quality === 'good';
      quality.textContent = good ? '✓ Quality: Gradable' : '⚠ Quality: Recapture';
      quality.className = `status-badge ${good ? 'normal' : 'warning'}`;
      message.textContent = good ? 'Sharp focus, adequate illumination, 45° FOV achieved.' : `${button.dataset.quality === 'dark' ? 'Image too dark' : 'Motion blur detected'}. Capture again.`;
      $('#tri-refer').style.display = good ? 'flex' : 'none';
      $('#tri-recapture').style.display = good ? 'none' : 'flex';
    }));
    $('#manual-sync')?.addEventListener('click', () => { state.queued = 0; $('#outbox-count').textContent = '0 queued'; $('#outbox-status').textContent = 'Connected · Auto-synced'; });
    $('#queue-record')?.addEventListener('click', () => { state.queued += 1; $('#outbox-count').textContent = `${state.queued} queued`; $('#outbox-status').textContent = 'Offline · Stored locally'; });
    $('#speak-report')?.addEventListener('click', speakPatientReport);
    $('#patient-speak-report')?.addEventListener('click', speakPatientReport);
    $$('.font-scale').forEach((button) => button.addEventListener('click', () => {
      $$('.font-scale').forEach((item) => item.classList.remove('active'));
      button.classList.add('active');
      document.querySelector('.patient-content').dataset.scale = button.dataset.scale;
    }));
    ['sim-arrival-rate', 'sim-specialists', 'sim-bandwidth'].forEach((id) => $(`#${id}`)?.addEventListener('input', updateSimulation));
    updateSimulation();
    window.setInterval(() => {
      state.elapsed += 1;
      const seconds = String(state.elapsed % 60).padStart(2, '0');
      const timer = $('#review-timer');
      if (timer) timer.textContent = `00:${seconds}`;
    }, 1000);
  }

  document.addEventListener('DOMContentLoaded', init);
}());
