/**
 * Netra Eye Care System — Application Controller
 * Handles Multi-Page Navigation (Landing -> Login -> Dashboard),
 * Flexible Patient Authentication (Sign In with Name or ID, New Registration, Instant Demo),
 * Dynamic Returning Patient vs Brand-New Patient Dashboard states,
 * Canvas Vision Journey Chart, and Explainable AI Modals.
 */

(function () {
  'use strict';

  // Pre-configured Demo Patient (Ananya Sharma)
  const DEMO_PATIENT = {
    name: "Ananya Sharma",
    id: "NETRA-2026-8841",
    isDemo: true,
    screening: {
      date: "10 Aug 2026",
      eye: "Right Eye (OD)",
      status: "Normal",
      headline: "No signs of diabetic retinopathy detected.",
      sub: "Keep up with regular screenings!"
    },
    appointment: {
      type: "Retinal Screening",
      doctor: "Dr. Meera Iyer",
      date: "15 Sep 2026 • 10:30 AM",
      location: "Christ University Health Centre"
    },
    overview: {
      acuity: "6/6",
      iop: "14 mmHg",
      retina: "No abnormality"
    },
    journey: [
      { label: 'Jan 2025', val: 3 },
      { label: 'Apr 2025', val: 3 },
      { label: 'Jul 2025', val: 3 },
      { label: 'Oct 2025', val: 3 },
      { label: 'Jan 2026', val: 3 }
    ]
  };

  // Application State
  const state = {
    theme: localStorage.getItem('netra_theme') || 'light',
    language: localStorage.getItem('netra_lang') || 'en',
    activePatient: getStoredPatient(),
    activeLayer: 'original',
    currentTipIndex: 0,
    tips: [
      {
        rule: "Follow the 20-20-20 rule",
        tips: [
          "Follow the 20-20-20 rule",
          "Keep your screens at a comfortable distance",
          "Get regular eye check-ups",
          "Eat a balanced diet rich in leafy greens"
        ]
      },
      {
        rule: "Screen ergonomics",
        tips: [
          "Position screen 20-24 inches from your eyes",
          "Keep monitor slightly below eye level",
          "Adjust lighting to minimize glare",
          "Increase font size to avoid squinting"
        ]
      },
      {
        rule: "Hydration & Diet",
        tips: [
          "Drink 8-10 glasses of water daily",
          "Include Omega-3 fatty acids in meals",
          "Eat carrots, spinach, and sweet potatoes",
          "Limit high-glycemic sugar spikes"
        ]
      },
      {
        rule: "Diabetic Eye Care",
        tips: [
          "Maintain HbA1c under 7.0%",
          "Screen retinas at least once annually",
          "Monitor blood pressure and lipids",
          "Report sudden vision floaters immediately"
        ]
      },
      {
        rule: "Outdoor Protection",
        tips: [
          "Wear UV400 rated sunglasses",
          "Use wide-brimmed hats in bright sun",
          "Avoid direct gaze into bright spotlights",
          "Wear protective goggles in dusty conditions"
        ]
      },
      {
        rule: "Rest & Recovery",
        tips: [
          "Ensure 7-8 hours of sound sleep",
          "Avoid screen usage 30 mins before bed",
          "Use warm compresses for tired dry eyes",
          "Blink intentionally while reading"
        ]
      }
    ]
  };

  function getStoredPatient() {
    const raw = localStorage.getItem('netra_active_patient');
    if (raw) {
      try {
        return JSON.parse(raw);
      } catch (e) {
        return DEMO_PATIENT;
      }
    }
    return DEMO_PATIENT;
  }

  function setStoredPatient(patient) {
    state.activePatient = patient;
    localStorage.setItem('netra_active_patient', JSON.stringify(patient));
  }

  // DOM Elements Cache
  const elements = {
    html: document.documentElement,
    langDropdownBtn: document.getElementById('langDropdownBtn'),
    langDropdownMenu: document.getElementById('langDropdownMenu'),
    langLabelLanding: document.getElementById('langLabelLanding'),
    themeToggleBtn: document.getElementById('themeToggleBtn'),
    themeToggleText: document.getElementById('themeToggleText'),
    themeToggleIcon: document.getElementById('themeToggleIcon'),
    themeToggleDashBtn: document.getElementById('themeToggleDashBtn'),

    // Auth Role Switcher & Forms
    btnRolePatient: document.getElementById('btnRolePatient'),
    btnRoleDoctor: document.getElementById('btnRoleDoctor'),
    patientPortalSection: document.getElementById('patientPortalSection'),
    doctorPortalSection: document.getElementById('doctorPortalSection'),
    authTabSignIn: document.getElementById('authTabSignIn'),
    authTabSignUp: document.getElementById('authTabSignUp'),
    signInForm: document.getElementById('signInForm'),
    signUpForm: document.getElementById('signUpForm'),
    doctorLoginForm: document.getElementById('doctorLoginForm'),
    inputSignInId: document.getElementById('inputSignInId'),
    inputSignInPassword: document.getElementById('inputSignInPassword'),
    btnSignInSubmit: document.getElementById('btnSignInSubmit'),
    btnDoctorSubmit: document.getElementById('btnDoctorSubmit'),
    authStatusAlert: document.getElementById('authStatusAlert'),
    btnDemoPatient: document.getElementById('btnDemoPatient'),
    btnDemoDoctor: document.getElementById('btnDemoDoctor'),
    linkSwitchToSignUp: document.getElementById('linkSwitchToSignUp'),
    linkSwitchToSignIn: document.getElementById('linkSwitchToSignIn'),

    // Dashboard
    dashGreetingText: document.getElementById('dashGreetingText'),
    userSessionBadge: document.getElementById('userSessionBadge'),
    userNameLabel: document.getElementById('userNameLabel'),
    userAvatarInitial: document.getElementById('userAvatarInitial'),
    userProfileChipBtn: document.getElementById('userProfileChipBtn'),
    userProfileDropdown: document.getElementById('userProfileDropdown'),
    dropdownUserName: document.getElementById('dropdownUserName'),
    dropdownUserId: document.getElementById('dropdownUserId'),
    dropdownUserStatus: document.getElementById('dropdownUserStatus'),
    btnMenuSimulateScan: document.getElementById('btnMenuSimulateScan'),
    btnMenuResetUser: document.getElementById('btnMenuResetUser'),
    btnSwitchDemoUser: document.getElementById('btnSwitchDemoUser'),
    btnSignOutLink: document.getElementById('btnSignOutLink'),

    // First-Time Welcome Banner
    newPatientWelcomeBanner: document.getElementById('newPatientWelcomeBanner'),
    newPatientWelcomeTitle: document.getElementById('newPatientWelcomeTitle'),
    newPatientWelcomeDesc: document.getElementById('newPatientWelcomeDesc'),
    btnWelcomeBook: document.getElementById('btnWelcomeBook'),
    btnWelcomeSimulateScan: document.getElementById('btnWelcomeSimulateScan'),
    btnDismissWelcomeBanner: document.getElementById('btnDismissWelcomeBanner'),

    cardAppointmentContainer: document.getElementById('cardAppointmentContainer'),
    cardScreeningContainer: document.getElementById('cardScreeningContainer'),
    cardOverviewContainer: document.getElementById('cardOverviewContainer'),
    cardRemindersContainer: document.getElementById('cardRemindersContainer'),

    canvasJourney: document.getElementById('journeyChartCanvas'),
    journeyStatusBanner: document.getElementById('journeyStatusBanner'),
    journeyHeadlineText: document.getElementById('journeyHeadlineText'),
    journeySubText: document.getElementById('journeySubText'),

    tipsList: document.getElementById('tipsChecklist'),
    carouselDotsContainer: document.getElementById('carouselDotsContainer'),

    // Modals
    modalReport: document.getElementById('modalReport'),
    modalReportPatientSubtitle: document.getElementById('modalReportPatientSubtitle'),
    fundusDisplayImg: document.getElementById('fundusDisplayImg'),
    fundusCanvasOverlay: document.getElementById('fundusCanvasOverlay'),
    modalAppointment: document.getElementById('modalAppointment'),
    modalSupport: document.getElementById('modalSupport'),
    appointmentBookingForm: document.getElementById('appointmentBookingForm'),

    // Retinal Scan Simulator Modal
    modalSimulateScan: document.getElementById('modalSimulateScan'),
    simModalSubtitle: document.getElementById('simModalSubtitle'),
    btnStartScanSequence: document.getElementById('btnStartScanSequence'),
    simCameraFlash: document.getElementById('simCameraFlash'),
    simDiagnosticsOutput: document.getElementById('simDiagnosticsOutput'),

    // 20-20-20 Eye Rest Timer Modal
    modalEyeRestTimer: document.getElementById('modalEyeRestTimer'),
    timerCircleProgress: document.getElementById('timerCircleProgress'),
    timerSecondsCount: document.getElementById('timerSecondsCount'),
    timerStatusInstruction: document.getElementById('timerStatusInstruction'),
    btnToggleTimer: document.getElementById('btnToggleTimer'),
    btnResetTimer: document.getElementById('btnResetTimer'),
    checkRepeatTimer: document.getElementById('checkRepeatTimer'),

    // Reminders Manager Modal
    modalRemindersManager: document.getElementById('modalRemindersManager'),
    remindersManagerListContainer: document.getElementById('remindersManagerListContainer'),
    remindersCountLabel: document.getElementById('remindersCountLabel'),
    formAddReminder: document.getElementById('formAddReminder'),
    inputNewReminderTitle: document.getElementById('inputNewReminderTitle'),
    selectReminderCategory: document.getElementById('selectReminderCategory'),
    inputReminderTime: document.getElementById('inputReminderTime'),
    navItemReminders: document.getElementById('navItemReminders')
  };

  // Initialize Application on Page Load
  function init() {
    setupTheme(state.theme);
    setupLanguage(state.language);
    setupEventListeners();

    if (elements.cardAppointmentContainer) {
      renderDashboardForActivePatient();
    }
  }

  // =========================================================================
  // THEME MANAGEMENT (Adaptive Color Token System & Halation Control)
  // =========================================================================
  function setupTheme(theme) {
    state.theme = theme;
    localStorage.setItem('netra_theme', theme);
    elements.html.setAttribute('data-theme', theme);

    const isDark = theme === 'dark';
    const t = translations[state.language] || translations.en;
    const label = isDark ? (t.themeDark || "Exam Room Mode") : (t.themeLight || "Light Mode");
    
    if (elements.themeToggleText) elements.themeToggleText.textContent = label;
    
    const sunIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>`;
    const moonIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>`;

    if (elements.themeToggleIcon) {
      elements.themeToggleIcon.innerHTML = isDark ? sunIcon : moonIcon;
    }

    if (elements.canvasJourney) {
      renderJourneyChart();
    }
  }

  function toggleTheme() {
    const nextTheme = state.theme === 'light' ? 'dark' : 'light';
    setupTheme(nextTheme);
  }

  // =========================================================================
  // LOCALIZATION & MULTILINGUAL SYSTEM (EN, HI, KN)
  // =========================================================================
  function setupLanguage(lang) {
    if (!translations || !translations[lang]) return;
    state.language = lang;
    localStorage.setItem('netra_lang', lang);

    const t = translations[lang];

    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      if (t[key]) {
        el.textContent = t[key];
      }
    });

    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      const key = el.getAttribute('data-i18n-placeholder');
      if (t[key]) {
        el.setAttribute('placeholder', t[key]);
      }
    });

    const langNames = { en: "English", hi: "हिंदी", kn: "ಕನ್ನಡ" };
    if (elements.langLabelLanding) {
      elements.langLabelLanding.textContent = langNames[lang] || "English";
    }

    document.querySelectorAll('.lang-option').forEach(btn => {
      const optLang = btn.getAttribute('data-lang');
      if (optLang === lang) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    const themeLabel = state.theme === 'dark' ? t.themeDark : t.themeLight;
    if (elements.themeToggleText) elements.themeToggleText.textContent = themeLabel;

    if (elements.cardAppointmentContainer) {
      renderDashboardForActivePatient();
    }
  }

  // =========================================================================
  // DYNAMIC PATIENT DASHBOARD RENDERING
  // =========================================================================
  function renderDashboardForActivePatient() {
    const patient = state.activePatient || DEMO_PATIENT;
    const isDemo = patient.isDemo === true;
    const t = translations[state.language] || translations.en;

    // Top Bar Greeting & Profile
    const firstName = patient.name.split(' ')[0] || patient.name;
    if (elements.dashGreetingText) {
      elements.dashGreetingText.textContent = `${t.dashGreeting}, ${firstName} 👋`;
    }
    if (elements.userSessionBadge) {
      elements.userSessionBadge.className = 'clinical-badge status-normal';
      elements.userSessionBadge.textContent = 'Patient Portal';
    }
    if (elements.userNameLabel) {
      elements.userNameLabel.textContent = patient.name;
    }
    if (elements.userAvatarInitial) {
      elements.userAvatarInitial.textContent = (patient.name[0] || 'P').toUpperCase();
    }
    if (elements.dropdownUserName) {
      elements.dropdownUserName.textContent = patient.name;
    }
    if (elements.dropdownUserId) {
      elements.dropdownUserId.textContent = `ID: ${patient.id}`;
    }
    if (elements.dropdownUserStatus) {
      elements.dropdownUserStatus.textContent = isDemo ? 'Profile: Demo Account (Ananya)' : 'Profile: Patient Account';
    }
    if (elements.modalReportPatientSubtitle) {
      elements.modalReportPatientSubtitle.textContent = `Patient: ${patient.name} | ID: ${patient.id}`;
    }
    if (elements.simModalSubtitle) {
      elements.simModalSubtitle.textContent = `Retinal fundus examination demo for ${patient.name}`;
    }

    // Patient Onboarding Welcome Banner (Shown only if no screenings on file yet)
    if (elements.newPatientWelcomeBanner) {
      if (!isDemo && !patient.screening) {
        elements.newPatientWelcomeBanner.style.display = 'flex';
        if (elements.newPatientWelcomeTitle) {
          elements.newPatientWelcomeTitle.textContent = `Welcome to Netra Eye Care, ${firstName}!`;
        }
      } else {
        elements.newPatientWelcomeBanner.style.display = 'none';
      }
    }

    // 1. HERO BANNER
    const bannerKicker = document.getElementById('bannerKickerText');
    const bannerTitle = document.getElementById('bannerTitleText');
    const bannerDesc = document.getElementById('bannerDescText');
    const bannerBtn = document.getElementById('bannerBtnText');

    if (bannerKicker) bannerKicker.textContent = t.bannerKicker || "Your Vision Matters";
    if (bannerTitle) bannerTitle.textContent = t.bannerTitle || "Early Detection Brings a Brighter Tomorrow";
    if (bannerDesc) bannerDesc.textContent = t.bannerDesc || "Regular eye check-ups help keep your eyes healthy and your world clearer.";
    if (bannerBtn) bannerBtn.textContent = t.bannerBtn || "Book an Appointment";

    // 2. NEXT APPOINTMENT CARD
    if (elements.cardAppointmentContainer) {
      if (patient.appointment) {
        elements.cardAppointmentContainer.innerHTML = `
          <div>
            <div class="card-header-line">
              <h4 class="card-title">${t.nextAppointmentTitle}</h4>
              <a href="#" class="card-link" id="linkViewAppts">${t.viewAll}</a>
            </div>
            <div class="appointment-content">
              <div class="appt-calendar-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                  <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                  <line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
              </div>
              <div class="appt-details">
                <h4>${patient.appointment.type}</h4>
                <p class="appt-doc">${patient.appointment.doctor}</p>
                <p class="appt-time">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/></svg>
                  <span>${patient.appointment.date}</span>
                </p>
                <p class="appt-loc">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                  <span>${patient.appointment.location}</span>
                </p>
              </div>
            </div>
          </div>
          <div class="appt-actions-row">
            <button class="btn-appt-reschedule" id="btnRescheduleApptAction">${t.btnReschedule}</button>
            <button class="btn-appt-calendar" onclick="alert('Appointment synced with your calendar!')">${t.btnAddCalendar}</button>
          </div>
        `;
        const rescheduleBtn = document.getElementById('btnRescheduleApptAction');
        if (rescheduleBtn) {
          rescheduleBtn.addEventListener('click', () => elements.modalAppointment.classList.add('open'));
        }
      } else {
        // Patient with No Appointments Scheduled Yet
        elements.cardAppointmentContainer.innerHTML = `
          <div>
            <div class="card-header-line">
              <h4 class="card-title">${t.nextAppointmentTitle || 'Upcoming Appointments'}</h4>
            </div>
            <div class="appointment-content" style="margin-top: 10px;">
              <div class="appt-calendar-icon" style="background: var(--brand-primary-light); color: var(--brand-primary);">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                  <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                  <line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
              </div>
              <div class="appt-details">
                <h4>No upcoming appointments</h4>
                <p class="appt-doc" style="margin-top: 4px; font-size: 0.78rem; color: var(--text-secondary); line-height: 1.4;">
                  Regular annual check-ups are recommended for all diabetics to prevent sight-threatening retinopathy.
                </p>
              </div>
            </div>
          </div>
          <div class="appt-actions-row" style="margin-top: 14px;">
            <button class="btn-appt-reschedule" id="btnScheduleFirstApptAction" style="background: var(--brand-primary); width: 100%;">
              📅 Book an Appointment
            </button>
          </div>
        `;
        const schedBtn = document.getElementById('btnScheduleFirstApptAction');
        if (schedBtn) {
          schedBtn.addEventListener('click', () => elements.modalAppointment.classList.add('open'));
        }
      }
    }

    // 3. LATEST SCREENING RESULT CARD (Screening Present vs Fresh 0-Record State)
    if (elements.cardScreeningContainer) {
      if (patient.screening) {
        elements.cardScreeningContainer.innerHTML = `
          <div class="card-header-line">
            <h4 class="card-title">${t.screeningTitle}</h4>
            <span style="font-size: 0.8rem; color: var(--text-secondary);">${patient.screening.date}</span>
          </div>
          <div class="screening-body">
            <div class="screening-thumb-wrap">
              <img class="fundus-thumb" src="assets/images/retinal_fundus_od.jpg" alt="Retinal Fundus OD">
              <p class="eye-label">${t.eyeOD}</p>
            </div>
            <div class="screening-info">
              <div class="screening-badge-row">
                <span class="clinical-badge status-normal">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                  <span>${t.statusNormal}</span>
                </span>
                ${!isDemo ? '<span class="clinical-badge status-normal" style="margin-left: 6px;">New Scan Added!</span>' : ''}
              </div>
              <h4>${patient.screening.headline || t.screeningHeadline}</h4>
              <p>${patient.screening.sub || t.screeningSub}</p>
              <div style="display: flex; align-items: center; gap: 10px; margin-top: 8px; flex-wrap: wrap;">
                <button class="btn-view-report" id="btnTriggerModalReport">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>
                  </svg>
                  <span>${t.btnViewReport}</span>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                </button>
              </div>
            </div>
          </div>
        `;
        const trigger = document.getElementById('btnTriggerModalReport');
        if (trigger) {
          trigger.addEventListener('click', () => {
            elements.modalReport.classList.add('open');
            setFundusLayer('original');
          });
        }
      } else {
        // Patient with no prior screening on record
        elements.cardScreeningContainer.innerHTML = `
          <div class="card-header-line">
            <h4 class="card-title">${t.screeningTitle || 'Latest Retinal Screening'}</h4>
            <span class="clinical-badge status-warning">Screening Due</span>
          </div>
          <div class="screening-body">
            <div class="screening-thumb-wrap">
              <div style="width: 96px; height: 96px; border-radius: var(--radius-md); border: 2px dashed var(--border-subtle); display: flex; flex-direction: column; align-items: center; justify-content: center; background: var(--bg-surface-subtle); color: var(--text-tertiary);">
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                  <circle cx="12" cy="12" r="3"/>
                  <path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/>
                  <path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
                </svg>
                <span style="font-size: 0.65rem; margin-top: 4px; font-weight: 500;">No Scans</span>
              </div>
              <p class="eye-label">Not Examined</p>
            </div>
            <div class="screening-info">
              <h4>No screening records on file</h4>
              <p style="font-size: 0.78rem; color: var(--text-secondary); line-height: 1.4;">
                Annual fundus examinations are essential for detecting early diabetic retinopathy microaneurysms before vision loss occurs.
              </p>
              <div style="display: flex; align-items: center; gap: 10px; margin-top: 8px; flex-wrap: wrap;">
                <button class="btn-primary" id="btnBookFromScreeningCard" style="padding: 7px 12px; font-size: 0.78rem; font-weight: 600;">
                  📅 Schedule Screening
                </button>
                <button class="btn-secondary" id="btnSimulateScanCard" style="padding: 7px 12px; font-size: 0.78rem; font-weight: 600; background: var(--bg-surface);">
                  📸 Practice Scan Demo
                </button>
              </div>
            </div>
          </div>
        `;
        const btnSimulate = document.getElementById('btnSimulateScanCard');
        if (btnSimulate) {
          btnSimulate.addEventListener('click', openSimulateScanModal);
        }
        const btnBook = document.getElementById('btnBookFromScreeningCard');
        if (btnBook) {
          btnBook.addEventListener('click', () => elements.modalAppointment.classList.add('open'));
        }
      }
    }

    // 4. EYE HEALTH OVERVIEW CARD
    if (elements.cardOverviewContainer) {
      if (patient.overview) {
        elements.cardOverviewContainer.innerHTML = `
          <div class="card-header-line">
            <h4 class="card-title">${t.overviewTitle}</h4>
            ${!isDemo ? '<span class="clinical-badge status-normal">Baseline Recorded</span>' : ''}
          </div>
          <div class="overview-rows">
            <div class="overview-row-item">
              <div class="overview-label-group">
                <div class="overview-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/></svg></div>
                <span>${t.metricAcuity}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 12px;">
                <span class="overview-metric-val clinical-data-metric">${patient.overview.acuity}</span>
                <span class="clinical-badge status-normal"><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>${t.statusNormal}</span></span>
              </div>
            </div>
            <div class="overview-row-item">
              <div class="overview-label-group">
                <div class="overview-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg></div>
                <span>${t.metricIop}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 12px;">
                <span class="overview-metric-val clinical-data-metric">${patient.overview.iop}</span>
                <span class="clinical-badge status-normal"><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>${t.statusNormal}</span></span>
              </div>
            </div>
            <div class="overview-row-item">
              <div class="overview-label-group">
                <div class="overview-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="7" r="4"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg></div>
                <span>${t.metricRetina}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 12px;">
                <span class="overview-metric-val">${patient.overview.retina}</span>
                <span class="clinical-badge status-normal"><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>${t.statusStable}</span></span>
              </div>
            </div>
          </div>
        `;
      } else {
        // Patient Vitals Pending Exam
        elements.cardOverviewContainer.innerHTML = `
          <div class="card-header-line">
            <h4 class="card-title">${t.overviewTitle || 'Eye Health Overview'}</h4>
            <span class="clinical-badge status-warning">Pending Exam</span>
          </div>
          <div class="overview-rows">
            <div class="overview-row-item">
              <div class="overview-label-group">
                <div class="overview-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/></svg></div>
                <span>${t.metricAcuity || 'Visual Acuity'}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 12px;">
                <span class="overview-metric-val" style="color: var(--text-secondary); font-size: 0.85rem;">—</span>
                <span class="clinical-badge status-warning">Due</span>
              </div>
            </div>
            <div class="overview-row-item">
              <div class="overview-label-group">
                <div class="overview-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg></div>
                <span>${t.metricIop || 'Intraocular Pressure'}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 12px;">
                <span class="overview-metric-val" style="color: var(--text-secondary); font-size: 0.85rem;">—</span>
                <span class="clinical-badge status-warning">Due</span>
              </div>
            </div>
            <div class="overview-row-item">
              <div class="overview-label-group">
                <div class="overview-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="7" r="4"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg></div>
                <span>${t.metricRetina || 'Retinal Examination'}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 12px;">
                <span class="overview-metric-val" style="color: var(--text-secondary); font-size: 0.85rem;">Pending Exam</span>
                <span class="clinical-badge status-warning">Due</span>
              </div>
            </div>
          </div>
          <p style="font-size: 0.72rem; color: var(--text-tertiary); margin-top: 8px;">
            Clinical measurements will appear here after your next clinic visit.
          </p>
        `;
      }
    }

    // 5. REMINDERS CARD (Interactive, Actionable & Manageable)
    renderRemindersCard();

    // 6. VISION JOURNEY BOTTOM CALLOUT
    if (elements.journeyHeadlineText && elements.journeySubText) {
      if (patient.journey && patient.journey.length > 0) {
        elements.journeyHeadlineText.textContent = t.journeyStableHeadline || "Your eye health has been stable";
        elements.journeySubText.textContent = t.journeyStableSub || "Keep maintaining regular check-ups to stay on track.";
      } else {
        elements.journeyHeadlineText.textContent = "Start Tracking Your Vision Journey";
        elements.journeySubText.textContent = "Your retinal condition trajectory over time will be graphed here following your screenings.";
      }
    }

    renderJourneyChart();
    renderTipsCarousel(state.currentTipIndex);
  }

  // =========================================================================
  // VISION JOURNEY CANVAS CHART
  // Plots Ananya's trend OR baseline point OR clean guide for fresh users
  // =========================================================================
  function renderJourneyChart() {
    const canvas = elements.canvasJourney;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const width = canvas.parentElement.clientWidth || 360;
    const height = 140;
    
    const dpr = window.devicePixelRatio || 1;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
    ctx.scale(dpr, dpr);

    ctx.clearRect(0, 0, width, height);

    const isDark = state.theme === 'dark';
    const gridColor = isDark ? '#273447' : '#E5E9F0';
    const textColor = isDark ? '#94A3B8' : '#627289';
    const lineColor = isDark ? '#00B4D8' : '#007A87';
    const pointFill = isDark ? '#18202C' : '#FFFFFF';

    const t = translations[state.language] || translations.en;
    const yLabels = [t.chartSevere, t.chartModerate, t.chartMild, t.chartNormal];
    const xLabels = ['Jan 2025', 'Apr 2025', 'Jul 2025', 'Oct 2025', 'Jan 2026'];

    const leftMargin = 55;
    const rightMargin = 20;
    const topMargin = 12;
    const bottomMargin = 26;

    const chartWidth = width - leftMargin - rightMargin;
    const chartHeight = height - topMargin - bottomMargin;

    // Draw horizontal grid lines & Y labels
    ctx.font = '10px Inter, sans-serif';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';

    const yStep = chartHeight / (yLabels.length - 1);
    for (let i = 0; i < yLabels.length; i++) {
      const y = topMargin + i * yStep;
      ctx.fillStyle = textColor;
      ctx.fillText(yLabels[i], leftMargin - 8, y);

      ctx.beginPath();
      ctx.strokeStyle = gridColor;
      ctx.lineWidth = 1;
      ctx.moveTo(leftMargin, y);
      ctx.lineTo(width - rightMargin, y);
      ctx.stroke();
    }

    // Draw X labels
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    const xStep = chartWidth / (xLabels.length - 1);

    for (let i = 0; i < xLabels.length; i++) {
      const x = leftMargin + i * xStep;
      ctx.fillStyle = textColor;
      ctx.fillText(xLabels[i], x, height - bottomMargin + 8);
    }

    const patient = state.activePatient || DEMO_PATIENT;
    if (patient.journey && patient.journey.length > 1) {
      // Draw 5-point normal trend line (Demo Patient)
      const points = [];
      for (let i = 0; i < xLabels.length; i++) {
        const x = leftMargin + i * xStep;
        const y = topMargin + 3 * yStep;
        points.push({ x, y });
      }

      ctx.beginPath();
      ctx.strokeStyle = lineColor;
      ctx.lineWidth = 3;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      points.forEach((pt, idx) => {
        if (idx === 0) ctx.moveTo(pt.x, pt.y);
        else ctx.lineTo(pt.x, pt.y);
      });
      ctx.stroke();

      points.forEach((pt) => {
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = pointFill;
        ctx.fill();
        ctx.lineWidth = 2.5;
        ctx.strokeStyle = lineColor;
        ctx.stroke();
      });
    } else if (patient.journey && patient.journey.length === 1) {
      // 1 Simulated baseline point ("What if I did")
      const ptX = leftMargin + (xLabels.length - 1) * xStep;
      const ptY = topMargin + 3 * yStep;

      ctx.save();
      ctx.setLineDash([4, 4]);
      ctx.strokeStyle = isDark ? 'rgba(0, 180, 216, 0.4)' : 'rgba(0, 122, 135, 0.35)';
      ctx.beginPath();
      ctx.moveTo(leftMargin, ptY);
      ctx.lineTo(ptX, ptY);
      ctx.stroke();
      ctx.restore();

      ctx.beginPath();
      ctx.arc(ptX, ptY, 5.5, 0, Math.PI * 2);
      ctx.fillStyle = lineColor;
      ctx.fill();
      ctx.lineWidth = 3;
      ctx.strokeStyle = pointFill;
      ctx.stroke();

      ctx.fillStyle = isDark ? '#94E3FE' : '#007A87';
      ctx.font = 'bold 11px Inter, sans-serif';
      ctx.fillText("● Baseline Exam: Grade 0 (Normal)", width / 2 + 15, topMargin + 1.2 * yStep);

      ctx.fillStyle = textColor;
      ctx.font = 'italic 10px Inter, sans-serif';
      ctx.fillText("First clinical data point recorded. Trajectory will evolve over annual visits.", width / 2 + 15, topMargin + 1.8 * yStep);
    } else {
      // Brand New Patient: Truly empty history with helpful baseline prompt
      ctx.save();
      ctx.setLineDash([5, 5]);
      ctx.strokeStyle = isDark ? 'rgba(0, 180, 216, 0.4)' : 'rgba(0, 122, 135, 0.35)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(leftMargin, topMargin + 3 * yStep);
      ctx.lineTo(width - rightMargin, topMargin + 3 * yStep);
      ctx.stroke();
      ctx.restore();

      ctx.fillStyle = isDark ? '#94E3FE' : '#007A87';
      ctx.font = 'bold 11px Inter, sans-serif';
      ctx.fillText("No screening history yet (0 scans on record)", width / 2 + 15, topMargin + 1.2 * yStep);
      
      ctx.fillStyle = textColor;
      ctx.font = 'italic 10px Inter, sans-serif';
      ctx.fillText("Your vision trajectory will be plotted after your first visit.", width / 2 + 15, topMargin + 1.8 * yStep);
    }
  }

  // =========================================================================
  // EYE CARE TIPS CAROUSEL
  // =========================================================================
  function renderTipsCarousel(index) {
    state.currentTipIndex = index;
    const item = state.tips[index];
    if (!item || !elements.tipsList) return;

    elements.tipsList.innerHTML = '';
    item.tips.forEach(text => {
      const li = document.createElement('li');
      li.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <polyline points="20 6 9 17 4 12"/>
        </svg>
        <span>${text}</span>
      `;
      elements.tipsList.appendChild(li);
    });

    if (elements.carouselDotsContainer) {
      elements.carouselDotsContainer.innerHTML = '';
      state.tips.forEach((_, i) => {
        const dot = document.createElement('div');
        dot.className = `carousel-dot ${i === index ? 'active' : ''}`;
        dot.addEventListener('click', () => renderTipsCarousel(i));
        elements.carouselDotsContainer.appendChild(dot);
      });
    }
  }

  // =========================================================================
  // MULTI-LAYER RETINAL IMAGE VIEWER (EXPLAINABLE AI)
  // =========================================================================
  function setFundusLayer(layer) {
    state.activeLayer = layer;
    document.querySelectorAll('.btn-layer-toggle').forEach(btn => {
      if (btn.getAttribute('data-layer') === layer) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    const canvas = elements.fundusCanvasOverlay;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width = 380;
    const h = canvas.height = 380;

    ctx.clearRect(0, 0, w, h);

    if (layer === 'original') {
      elements.fundusDisplayImg.style.filter = 'none';
    } else if (layer === 'enhanced') {
      elements.fundusDisplayImg.style.filter = 'contrast(130%) brightness(105%) hue-rotate(-10deg)';
    } else if (layer === 'gradcam') {
      elements.fundusDisplayImg.style.filter = 'none';
      const grad = ctx.createRadialGradient(190, 190, 20, 190, 190, 140);
      grad.addColorStop(0, 'rgba(239, 68, 68, 0.65)');
      grad.addColorStop(0.4, 'rgba(245, 158, 11, 0.45)');
      grad.addColorStop(0.7, 'rgba(59, 130, 246, 0.25)');
      grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, w, h);
    } else if (layer === 'lesions') {
      elements.fundusDisplayImg.style.filter = 'none';
      ctx.strokeStyle = 'rgba(74, 222, 128, 0.9)';
      ctx.lineWidth = 2;
      ctx.strokeRect(140, 140, 100, 100);
      ctx.font = 'bold 11px Inter, sans-serif';
      ctx.fillStyle = '#4ADE80';
      ctx.fillText('✓ Clear Macula (0 lesions)', 140, 132);
    } else if (layer === 'vessels') {
      elements.fundusDisplayImg.style.filter = 'grayscale(100%) contrast(150%)';
      ctx.strokeStyle = 'rgba(0, 212, 255, 0.4)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(135, 190, 36, 0, Math.PI * 2);
      ctx.stroke();
      ctx.font = 'bold 11px Inter, sans-serif';
      ctx.fillStyle = '#00D4FF';
      ctx.fillText('Optic Disc Segmentation', 95, 240);
    }
  }

  // =========================================================================
  // RETINAL SCAN SIMULATION ("WHAT IF I DID?") & PATIENT RESET LOGIC
  // =========================================================================
  function openSimulateScanModal() {
    if (!elements.modalSimulateScan) return;
    const patient = state.activePatient || DEMO_PATIENT;
    if (elements.simModalSubtitle) {
      elements.simModalSubtitle.textContent = `Simulating baseline retinal examination for ${patient.name}`;
    }
    resetScanModalUI();
    elements.modalSimulateScan.classList.add('open');
  }

  function resetScanModalUI() {
    const step1 = document.getElementById('simStep1');
    const step2 = document.getElementById('simStep2');
    const step3 = document.getElementById('simStep3');
    const step4 = document.getElementById('simStep4');
    const hudStatus = document.getElementById('simHudStatus');
    const startBtn = elements.btnStartScanSequence;

    if (step1) step1.className = "sim-step active";
    if (step2) step2.className = "sim-step";
    if (step3) step3.className = "sim-step";
    if (step4) step4.className = "sim-step";
    if (hudStatus) hudStatus.textContent = "ALIGNMENT READY";
    if (elements.simDiagnosticsOutput) elements.simDiagnosticsOutput.style.display = "none";
    if (startBtn) {
      startBtn.disabled = false;
      startBtn.innerHTML = "📸 Capture & Analyze Retinal Scan";
      startBtn.onclick = runScanSimulation;
    }
  }

  function runScanSimulation() {
    const startBtn = elements.btnStartScanSequence;
    if (!startBtn) return;

    startBtn.disabled = true;
    startBtn.innerHTML = `<span class="spinner-inline"></span> Aligning Optical Axis...`;

    const step1 = document.getElementById('simStep1');
    const step2 = document.getElementById('simStep2');
    const step3 = document.getElementById('simStep3');
    const step4 = document.getElementById('simStep4');
    const flash = elements.simCameraFlash;
    const diag = elements.simDiagnosticsOutput;
    const hudStatus = document.getElementById('simHudStatus');

    if (hudStatus) hudStatus.textContent = "ALIGNING OPTICAL AXIS...";

    setTimeout(() => {
      if (step1) step1.className = "sim-step done";
      if (step2) step2.className = "sim-step active";
      if (hudStatus) hudStatus.textContent = "CAPTURING OD IMAGE (FLASH)...";
      startBtn.innerHTML = `<span class="spinner-inline"></span> Capturing Retinal Image...`;

      // Trigger Camera Flash Effect
      if (flash) {
        flash.classList.add('flashing');
        setTimeout(() => flash.classList.remove('flashing'), 250);
      }

      setTimeout(() => {
        if (step2) step2.className = "sim-step done";
        if (step3) step3.className = "sim-step active";
        if (hudStatus) hudStatus.textContent = "RUNNING GRAD-CAM & VESSEL ANALYSIS...";
        startBtn.innerHTML = `<span class="spinner-inline"></span> Running Explainable AI Inference...`;

        setTimeout(() => {
          if (step3) step3.className = "sim-step done";
          if (step4) step4.className = "sim-step done";
          if (hudStatus) hudStatus.textContent = "ANALYSIS COMPLETE: GRADE 0 NORMAL";
          if (diag) diag.style.display = "block";

          startBtn.disabled = false;
          startBtn.innerHTML = `✓ Save Report & View On Dashboard`;

          startBtn.onclick = function () {
            const active = state.activePatient || DEMO_PATIENT;
            active.isDemo = false;
            active.screening = {
              date: "Today (Clinical Simulation)",
              eye: "Right Eye (OD)",
              status: "Normal",
              headline: "No signs of diabetic retinopathy detected.",
              sub: "Baseline screening recorded successfully."
            };
            active.overview = {
              acuity: "6/6",
              iop: "14 mmHg",
              retina: "Healthy baseline"
            };
            active.journey = [
              { label: 'Today', val: 3 }
            ];

            setStoredPatient(active);
            if (elements.modalSimulateScan) elements.modalSimulateScan.classList.remove('open');
            renderDashboardForActivePatient();
            alert(`✓ Retinal scan and diagnostic report generated for ${active.name}! Your dashboard is now populated.`);
            resetScanModalUI();
          };
        }, 850);
      }, 750);
    }, 600);
  }

  function resetActivePatientToFresh() {
    const active = state.activePatient || DEMO_PATIENT;
    active.isDemo = false;
    active.screening = null;
    active.appointment = null;
    active.overview = null;
    active.journey = [];
    setStoredPatient(active);
    renderDashboardForActivePatient();
    alert(`✓ Records cleared for ${active.name}.`);
  }

  function handleSignOut(e) {
    if (e) e.preventDefault();
    localStorage.removeItem('netra_active_patient');
    localStorage.removeItem('netra_active_role');
    localStorage.removeItem('netra_active_doctor');
    window.location.href = "login.html";
  }

  // =========================================================================
  // REMINDERS & 20-20-20 EYE REST TIMER CONTROLLER
  // =========================================================================
  let timerRemaining = 20;
  let timerInterval = null;
  let isTimerRunning = false;
  const TIMER_TOTAL = 20;
  const CIRCUMFERENCE = 2 * Math.PI * 70; // 439.82

  function getReminderIconSvg(iconType, category) {
    if (category === 'meds' || iconType === 'meds') {
      return `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>`;
    }
    if (category === 'screening' || iconType === 'report') {
      return `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>`;
    }
    if (category === 'screen' || iconType === 'timer') {
      return `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;
    }
    if (category === 'doctor' || iconType === 'calendar') {
      return `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`;
    }
    if (category === 'profile') {
      return `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`;
    }
    return `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`;
  }

  function getPatientReminders(patient) {
    const pId = patient ? (patient.id || 'demo') : 'demo';
    const stored = localStorage.getItem(`netra_reminders_${pId}`);
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch (e) {}
    }
    const isDemo = patient ? (patient.isDemo === true) : true;
    const t = translations[state.language] || translations.en;
    if (isDemo) {
      return [
        {
          id: 'rem_appt',
          title: t.reminder1Title || 'Retinal Screening Appointment',
          meta: t.reminder1Meta || 'Tomorrow at 10:30 AM • Christ Univ Health Centre',
          icon: 'amber',
          category: 'doctor',
          categoryLabel: 'Appointment',
          actionTag: 'View Appt 📅',
          actionType: 'appointment',
          completed: false
        },
        {
          id: 'rem_report',
          title: t.reminder2Title || 'Annual Review Retinal Report',
          meta: t.reminder2Meta || 'Dr. Meera Iyer verified Grade 0 (Normal)',
          icon: 'teal',
          category: 'screening',
          categoryLabel: 'Screening',
          actionTag: 'Open Report 📄',
          actionType: 'report',
          completed: false
        },
        {
          id: 'rem_timer',
          title: t.reminder3Title || 'Follow 20-20-20 Rule',
          meta: t.reminder3Meta || 'Every 20 mins: Look 20 ft away for 20s',
          icon: 'red',
          category: 'screen',
          categoryLabel: 'Eye Rest',
          actionTag: 'Start 20s Rest 👁️',
          actionType: 'timer',
          completed: false
        }
      ];
    } else {
      return [
        {
          id: 'rem_first_appt',
          title: t.newReminder1Title || 'Book Baseline Retinal Scan',
          meta: t.newReminder1Meta || 'Annual screening recommended for diabetes',
          icon: 'amber',
          category: 'screening',
          categoryLabel: 'Screening',
          actionTag: 'Book Scan 📅',
          actionType: 'appointment',
          completed: false
        },
        {
          id: 'rem_profile',
          title: t.newReminder2Title || 'Complete Health Profile',
          meta: t.newReminder2Meta || 'Confirm contact and health centre info',
          icon: 'teal',
          category: 'profile',
          categoryLabel: 'Profile',
          actionTag: 'Update Profile 👤',
          actionType: 'profile',
          completed: false
        },
        {
          id: 'rem_timer',
          title: t.newReminder3Title || 'Try 20-20-20 Screen Rest',
          meta: t.newReminder3Meta || 'Take regular breaks during screen work',
          icon: 'red',
          category: 'screen',
          categoryLabel: 'Eye Rest',
          actionTag: 'Start 20s Rest 👁️',
          actionType: 'timer',
          completed: false
        }
      ];
    }
  }

  function savePatientReminders(patient, reminders) {
    const pId = patient ? (patient.id || 'demo') : 'demo';
    localStorage.setItem(`netra_reminders_${pId}`, JSON.stringify(reminders));
  }

  function renderRemindersCard() {
    if (!elements.cardRemindersContainer) return;
    const patient = state.activePatient || DEMO_PATIENT;
    const reminders = getPatientReminders(patient);
    const t = translations[state.language] || translations.en;

    let itemsHtml = '';
    reminders.forEach((r) => {
      const completedClass = r.completed ? ' completed' : '';
      const checkContent = r.completed ? '✓' : '';
      const iconSvg = getReminderIconSvg(r.icon, r.category);

      itemsHtml += `
        <div class="reminder-item${completedClass}" data-reminder-id="${r.id}">
          <div class="reminder-left-group">
            <button type="button" class="btn-reminder-check" data-check-reminder="${r.id}" title="Mark complete">
              ${checkContent}
            </button>
            <div class="reminder-icon ${r.icon}">${iconSvg}</div>
            <div class="reminder-text" data-trigger-action="${r.actionType}">
              <h5>${r.title}</h5>
              <p>${r.meta}</p>
            </div>
          </div>
          <button type="button" class="reminder-action-tag" data-trigger-action="${r.actionType}">
            ${r.actionTag || 'Open'}
          </button>
        </div>
      `;
    });

    elements.cardRemindersContainer.innerHTML = `
      <div class="card-header-line">
        <h4 class="card-title">${t.remindersTitle || 'Reminders'}</h4>
        <a href="#" class="card-link" id="linkViewReminders">${t.viewAll || 'View All'}</a>
      </div>
      <div class="reminders-list">
        ${itemsHtml}
      </div>
      <div class="reminders-bottom-actions">
        <button type="button" class="btn-add-reminder-link" id="btnAddCustomReminderCard">
          <span>+ Add Reminder</span>
        </button>
        <button type="button" class="btn-start-2020-chip" id="btnLaunch2020Chip">
          <span>👁️ 20-20-20 Eye Break</span>
        </button>
      </div>
    `;

    bindReminderItemInteractions();
  }

  function renderRemindersManagerModal() {
    if (!elements.remindersManagerListContainer) return;
    const patient = state.activePatient || DEMO_PATIENT;
    const reminders = getPatientReminders(patient);

    if (elements.remindersCountLabel) {
      elements.remindersCountLabel.textContent = `${reminders.length} item${reminders.length !== 1 ? 's' : ''}`;
    }

    if (reminders.length === 0) {
      elements.remindersManagerListContainer.innerHTML = `
        <div style="text-align: center; padding: 24px; color: var(--text-secondary); font-size: 0.85rem;">
          🎉 All reminders completed! You can add a new one below.
        </div>
      `;
      return;
    }

    let rowsHtml = '';
    reminders.forEach((r) => {
      const completedClass = r.completed ? ' completed' : '';
      const checkContent = r.completed ? '✓' : '';
      rowsHtml += `
        <div class="reminder-manager-row${completedClass}">
          <div class="reminder-mgr-info">
            <button type="button" class="btn-reminder-check" data-check-reminder="${r.id}" title="Toggle complete">
              ${checkContent}
            </button>
            <div>
              <div style="display: flex; align-items: center; gap: 8px;">
                <strong class="mgr-title" style="font-size: 0.85rem; color: var(--text-primary);">${r.title}</strong>
                <span class="reminder-mgr-category-tag">${r.categoryLabel || r.category}</span>
              </div>
              <span style="font-size: 0.75rem; color: var(--text-secondary);">${r.meta}</span>
            </div>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <button type="button" class="reminder-action-tag" data-trigger-action="${r.actionType}">
              ${r.actionTag || 'Open'}
            </button>
            <button type="button" class="btn-delete-reminder" data-delete-reminder="${r.id}" title="Delete reminder">
              🗑️
            </button>
          </div>
        </div>
      `;
    });

    elements.remindersManagerListContainer.innerHTML = rowsHtml;
    bindReminderItemInteractions();
  }

  function bindReminderItemInteractions() {
    // Checkboxes to toggle completion
    document.querySelectorAll('[data-check-reminder]').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const id = btn.getAttribute('data-check-reminder');
        toggleReminderComplete(id);
      };
    });

    // Action triggers (buttons and reminder text)
    document.querySelectorAll('[data-trigger-action]').forEach(el => {
      el.onclick = (e) => {
        e.stopPropagation();
        const action = el.getAttribute('data-trigger-action');
        handleReminderAction(action);
      };
    });

    // Delete buttons in manager modal
    document.querySelectorAll('[data-delete-reminder]').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const id = btn.getAttribute('data-delete-reminder');
        deleteReminder(id);
      };
    });

    // Reminders Card header "View All"
    const linkView = document.getElementById('linkViewReminders');
    if (linkView) {
      linkView.onclick = (e) => {
        e.preventDefault();
        openRemindersManager();
      };
    }

    // Reminders Card "+ Add Reminder"
    const btnAddCard = document.getElementById('btnAddCustomReminderCard');
    if (btnAddCard) {
      btnAddCard.onclick = () => {
        openRemindersManager();
      };
    }

    // Reminders Card "👁️ 20-20-20 Eye Break"
    const btnChip2020 = document.getElementById('btnLaunch2020Chip');
    if (btnChip2020) {
      btnChip2020.onclick = () => {
        openEyeRestTimer();
      };
    }
  }

  function toggleReminderComplete(id) {
    const patient = state.activePatient || DEMO_PATIENT;
    const reminders = getPatientReminders(patient);
    const target = reminders.find(r => r.id === id);
    if (target) {
      target.completed = !target.completed;
      savePatientReminders(patient, reminders);
      renderRemindersCard();
      renderRemindersManagerModal();
    }
  }

  function deleteReminder(id) {
    const patient = state.activePatient || DEMO_PATIENT;
    let reminders = getPatientReminders(patient);
    reminders = reminders.filter(r => r.id !== id);
    savePatientReminders(patient, reminders);
    renderRemindersCard();
    renderRemindersManagerModal();
  }

  function handleReminderAction(actionType) {
    const patient = state.activePatient || DEMO_PATIENT;
    if (actionType === 'appointment') {
      if (elements.modalAppointment) elements.modalAppointment.classList.add('open');
    } else if (actionType === 'report') {
      if (patient.screening) {
        if (elements.modalReport) {
          elements.modalReport.classList.add('open');
          setFundusLayer('original');
        }
      } else {
        openSimulateScanModal();
      }
    } else if (actionType === 'timer') {
      openEyeRestTimer();
    } else if (actionType === 'profile') {
      if (elements.userProfileChipBtn) elements.userProfileChipBtn.click();
    } else if (actionType === 'meds') {
      alert('💧 Reminder: Lubricating eye drops help maintain corneal tear film during prolonged screen usage. Take 1-2 drops as prescribed.');
    } else if (actionType === 'sugar') {
      alert('🩸 Reminder: Record your fasting / postprandial glucose. Keeping HbA1c < 7.0% protects retinal microvessels.');
    } else {
      openRemindersManager();
    }
  }

  function openRemindersManager() {
    if (elements.modalRemindersManager) {
      renderRemindersManagerModal();
      elements.modalRemindersManager.classList.add('open');
    }
  }

  function openEyeRestTimer() {
    if (elements.modalEyeRestTimer) {
      elements.modalEyeRestTimer.classList.add('open');
      resetEyeRestTimer();
    }
  }

  function startEyeRestTimer() {
    if (isTimerRunning) {
      clearInterval(timerInterval);
      isTimerRunning = false;
      if (elements.btnToggleTimer) {
        elements.btnToggleTimer.textContent = '▶ Resume 20s Break';
      }
      if (elements.timerStatusInstruction) {
        elements.timerStatusInstruction.textContent = 'Timer paused. Relax your eyes and look far away.';
      }
      return;
    }

    isTimerRunning = true;
    if (elements.btnToggleTimer) {
      elements.btnToggleTimer.textContent = '⏸ Pause Break';
    }
    if (elements.timerStatusInstruction) {
      elements.timerStatusInstruction.textContent = 'Focus on an object 20 feet away across the room or out a window...';
    }

    timerInterval = setInterval(() => {
      timerRemaining--;
      updateTimerUI();

      if (timerRemaining <= 0) {
        clearInterval(timerInterval);
        isTimerRunning = false;
        playTimerCompleteChime();
        if (elements.timerStatusInstruction) {
          elements.timerStatusInstruction.innerHTML = '✨ <strong>Great Job!</strong> Your ciliary muscles are relaxed and tear film restored.';
        }
        if (elements.btnToggleTimer) {
          elements.btnToggleTimer.textContent = '▶ Start Another Break';
        }
        if (elements.checkRepeatTimer && elements.checkRepeatTimer.checked) {
          scheduleNextBreakReminder();
        }
      }
    }, 1000);
  }

  function resetEyeRestTimer() {
    clearInterval(timerInterval);
    isTimerRunning = false;
    timerRemaining = TIMER_TOTAL;
    updateTimerUI();
    if (elements.btnToggleTimer) {
      elements.btnToggleTimer.textContent = '▶ Start 20s Break';
    }
    if (elements.timerStatusInstruction) {
      elements.timerStatusInstruction.textContent = 'Ready to begin? Focus on an object 20 feet away.';
    }
  }

  function updateTimerUI() {
    if (elements.timerSecondsCount) {
      elements.timerSecondsCount.textContent = timerRemaining;
    }
    if (elements.timerCircleProgress) {
      const progress = (TIMER_TOTAL - timerRemaining) / TIMER_TOTAL;
      const offset = CIRCUMFERENCE * (1 - progress);
      elements.timerCircleProgress.style.strokeDashoffset = offset;
    }
  }

  function playTimerCompleteChime() {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gain = ctx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(587.33, ctx.currentTime);
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(880, ctx.currentTime + 0.15);
      gain.gain.setValueAtTime(0.2, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.7);
      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);
      osc1.start();
      osc1.stop(ctx.currentTime + 0.3);
      osc2.start(ctx.currentTime + 0.15);
      osc2.stop(ctx.currentTime + 0.7);
    } catch (e) {}
  }

  function scheduleNextBreakReminder() {
    setTimeout(() => {
      alert('🔔 20-20-20 Rule Reminder: You have been on your screen for 20 minutes! Take a 20-second eye break to prevent strain.');
    }, 20 * 60 * 1000);
  }

  // =========================================================================
  // EVENT LISTENERS BINDING
  // =========================================================================
  function setupEventListeners() {
    // Theme Switchers
    if (elements.themeToggleBtn) {
      elements.themeToggleBtn.addEventListener('click', toggleTheme);
    }
    if (elements.themeToggleDashBtn) {
      elements.themeToggleDashBtn.addEventListener('click', toggleTheme);
    }

    // Language Dropdown Toggle
    if (elements.langDropdownBtn && elements.langDropdownMenu) {
      elements.langDropdownBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        elements.langDropdownMenu.classList.toggle('open');
      });
    }

    document.addEventListener('click', () => {
      if (elements.langDropdownMenu) elements.langDropdownMenu.classList.remove('open');
      if (elements.userProfileDropdown) elements.userProfileDropdown.classList.remove('open');
    });

    document.querySelectorAll('.lang-option').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const lang = btn.getAttribute('data-lang');
        if (lang) {
          setupLanguage(lang);
          if (elements.langDropdownMenu) elements.langDropdownMenu.classList.remove('open');
        }
      });
    });

    // User Profile Dropdown Toggle in Dashboard
    if (elements.userProfileChipBtn && elements.userProfileDropdown) {
      elements.userProfileChipBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        elements.userProfileDropdown.classList.toggle('open');
      });
    }

    // User Profile Dropdown Menu Actions
    if (elements.btnMenuSimulateScan) {
      elements.btnMenuSimulateScan.addEventListener('click', (e) => {
        e.stopPropagation();
        if (elements.userProfileDropdown) elements.userProfileDropdown.classList.remove('open');
        openSimulateScanModal();
      });
    }

    if (elements.btnMenuResetUser) {
      elements.btnMenuResetUser.addEventListener('click', (e) => {
        e.stopPropagation();
        if (elements.userProfileDropdown) elements.userProfileDropdown.classList.remove('open');
        resetActivePatientToFresh();
      });
    }

    if (elements.btnSwitchDemoUser) {
      elements.btnSwitchDemoUser.addEventListener('click', (e) => {
        e.stopPropagation();
        setStoredPatient(DEMO_PATIENT);
        renderDashboardForActivePatient();
        if (elements.userProfileDropdown) elements.userProfileDropdown.classList.remove('open');
      });
    }

    if (elements.btnSignOutLink) {
      elements.btnSignOutLink.addEventListener('click', handleSignOut);
    }

    // First-Time Welcome Banner Actions
    if (elements.btnWelcomeBook) {
      elements.btnWelcomeBook.addEventListener('click', () => {
        if (elements.modalAppointment) elements.modalAppointment.classList.add('open');
      });
    }

    if (elements.btnWelcomeSimulateScan) {
      elements.btnWelcomeSimulateScan.addEventListener('click', openSimulateScanModal);
    }

    if (elements.btnDismissWelcomeBanner) {
      elements.btnDismissWelcomeBanner.addEventListener('click', () => {
        if (elements.newPatientWelcomeBanner) elements.newPatientWelcomeBanner.style.display = 'none';
      });
    }

    if (elements.btnStartScanSequence) {
      elements.btnStartScanSequence.addEventListener('click', runScanSimulation);
    }

    // Role Switcher: Patient Portal vs Doctor / Clinician Portal (login.html)
    if (elements.btnRolePatient && elements.btnRoleDoctor) {
      elements.btnRolePatient.addEventListener('click', () => {
        elements.btnRolePatient.classList.add('active');
        elements.btnRoleDoctor.classList.remove('active');
        if (elements.patientPortalSection) elements.patientPortalSection.style.display = 'block';
        if (elements.doctorPortalSection) elements.doctorPortalSection.style.display = 'none';
        const titleEl = document.getElementById('loginAuthTitle');
        if (titleEl) {
          const t = translations[state.language] || translations.en;
          titleEl.textContent = t.loginTitle || 'Welcome to Netra';
        }
      });

      elements.btnRoleDoctor.addEventListener('click', () => {
        elements.btnRoleDoctor.classList.add('active');
        elements.btnRolePatient.classList.remove('active');
        if (elements.patientPortalSection) elements.patientPortalSection.style.display = 'none';
        if (elements.doctorPortalSection) elements.doctorPortalSection.style.display = 'block';
        const titleEl = document.getElementById('loginAuthTitle');
        if (titleEl) {
          titleEl.textContent = 'Clinician Portal';
        }
      });
    }

    // Auth Sub-Tabs (Patient: Sign In vs Sign Up)
    if (elements.authTabSignIn && elements.authTabSignUp) {
      elements.authTabSignIn.addEventListener('click', () => {
        elements.authTabSignIn.classList.add('active');
        elements.authTabSignUp.classList.remove('active');
        if (elements.signInForm) elements.signInForm.style.display = 'flex';
        if (elements.signUpForm) elements.signUpForm.style.display = 'none';
      });

      elements.authTabSignUp.addEventListener('click', () => {
        elements.authTabSignUp.classList.add('active');
        elements.authTabSignIn.classList.remove('active');
        if (elements.signInForm) elements.signInForm.style.display = 'none';
        if (elements.signUpForm) elements.signUpForm.style.display = 'flex';
      });
    }

    if (elements.linkSwitchToSignUp) {
      elements.linkSwitchToSignUp.addEventListener('click', (e) => {
        e.preventDefault();
        elements.authTabSignUp.click();
      });
    }
    if (elements.linkSwitchToSignIn) {
      elements.linkSwitchToSignIn.addEventListener('click', (e) => {
        e.preventDefault();
        elements.authTabSignIn.click();
      });
    }

    // Patient Sign In Submission
    if (elements.signInForm) {
      elements.signInForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const entered = elements.inputSignInId ? elements.inputSignInId.value.trim() : '';
        if (!entered) return;

        const submitBtn = elements.btnSignInSubmit || elements.signInForm.querySelector('button[type="submit"]');
        if (submitBtn) {
          submitBtn.disabled = true;
          submitBtn.innerHTML = `<span class="spinner-inline"></span> Authenticating Credentials...`;
        }

        // Demo Ananya
        if (entered.toLowerCase().startsWith('ananya')) {
          localStorage.setItem('netra_active_role', 'patient');
          if (elements.authStatusAlert) {
            elements.authStatusAlert.className = "auth-status-alert success";
            elements.authStatusAlert.style.display = "flex";
            elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Authenticated!</strong> Welcome back, Ananya Sharma. Loading your patient record...</div>`;
          }
          setStoredPatient(DEMO_PATIENT);
          setTimeout(() => {
            window.location.href = "dashboard.html";
          }, 600);
          return;
        }

        const rawRegistered = localStorage.getItem('netra_registered_patients');
        const registeredList = rawRegistered ? JSON.parse(rawRegistered) : [];
        const found = registeredList.find(p => 
          p.name.toLowerCase() === entered.toLowerCase() || 
          p.id.toLowerCase() === entered.toLowerCase() || 
          p.mobile === entered
        );

        if (found) {
          localStorage.setItem('netra_active_role', 'patient');
          setStoredPatient(found);
          if (elements.authStatusAlert) {
            elements.authStatusAlert.className = "auth-status-alert success";
            elements.authStatusAlert.style.display = "flex";
            elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Authenticated!</strong> Welcome back, ${found.name}. Opening your dashboard...</div>`;
          }
        } else {
          localStorage.setItem('netra_active_role', 'patient');
          // New patient account
          const newPatient = {
            name: entered,
            id: "NETRA-2026-" + Math.floor(1000 + Math.random() * 9000),
            isDemo: false,
            screening: null,
            appointment: null,
            overview: null,
            journey: []
          };
          registeredList.push(newPatient);
          localStorage.setItem('netra_registered_patients', JSON.stringify(registeredList));
          setStoredPatient(newPatient);

          if (elements.authStatusAlert) {
            elements.authStatusAlert.className = "auth-status-alert success";
            elements.authStatusAlert.style.display = "flex";
            elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Authenticated!</strong> Welcome to Netra, ${entered}. Opening your dashboard...</div>`;
          }
        }

        setTimeout(() => {
          window.location.href = "dashboard.html";
        }, 650);
      });
    }

    // Instant Demo Button (Ananya Sharma)
    if (elements.btnDemoPatient) {
      elements.btnDemoPatient.addEventListener('click', () => {
        if (elements.authStatusAlert) {
          elements.authStatusAlert.className = "auth-status-alert success";
          elements.authStatusAlert.style.display = "flex";
          elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Authenticated!</strong> Loading patient record (Ananya Sharma)...</div>`;
        }
        setStoredPatient(DEMO_PATIENT);
        localStorage.setItem('netra_active_role', 'patient');
        setTimeout(() => {
          window.location.href = "dashboard.html";
        }, 550);
      });
    }

    // Sign Up Submission (Full Registration Form)
    if (elements.signUpForm) {
      elements.signUpForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const nameInput = document.getElementById('inputSignUpName');
        const mobileInput = document.getElementById('inputSignUpMobile');
        const ageInput = document.getElementById('inputSignUpAge');
        const genderSelect = document.getElementById('inputSignUpGender');
        const diabetesSelect = document.getElementById('inputSignUpDiabetes');
        const districtInput = document.getElementById('inputSignUpDistrict');

        const enteredName = nameInput ? nameInput.value.trim() : "Patient";
        const newPatient = {
          name: enteredName,
          id: "NETRA-2026-" + Math.floor(1000 + Math.random() * 9000),
          mobile: mobileInput ? mobileInput.value.trim() : "",
          age: ageInput ? ageInput.value : "",
          gender: genderSelect ? genderSelect.value : "Other",
          diabetes: diabetesSelect ? diabetesSelect.value : "Type 2",
          district: districtInput ? districtInput.value.trim() : "Karnataka",
          isDemo: false,
          screening: null,
          appointment: null,
          overview: null,
          journey: []
        };

        const rawRegistered = localStorage.getItem('netra_registered_patients');
        const registeredList = rawRegistered ? JSON.parse(rawRegistered) : [];
        registeredList.push(newPatient);
        localStorage.setItem('netra_registered_patients', JSON.stringify(registeredList));

        setStoredPatient(newPatient);
        localStorage.setItem('netra_active_role', 'patient');

        if (elements.authStatusAlert) {
          elements.authStatusAlert.className = "auth-status-alert success";
          elements.authStatusAlert.style.display = "flex";
          elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Account Created!</strong> Welcome to Netra, ${enteredName}. Opening your dashboard...</div>`;
        }

        setTimeout(() => {
          window.location.href = "dashboard.html";
        }, 650);
      });
    }

    // Doctor / Clinician Portal Login Form
    if (elements.doctorLoginForm) {
      elements.doctorLoginForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const docIdInput = document.getElementById('inputDoctorId');
        const docHospSelect = document.getElementById('selectDoctorHospital');
        const docId = docIdInput ? docIdInput.value.trim() : 'DOC-KA-2026-4412';
        const hospital = docHospSelect ? docHospSelect.value : 'Christ University Health Centre (Bengaluru)';

        const submitBtn = elements.btnDoctorSubmit || elements.doctorLoginForm.querySelector('button[type="submit"]');
        if (submitBtn) {
          submitBtn.disabled = true;
          submitBtn.innerHTML = `<span class="spinner-inline"></span> Verifying Medical Credentials...`;
        }

        const clinicianProfile = {
          name: 'Dr. Meera Iyer, MBBS, MS (Ophth)',
          role: 'Senior Ophthalmologist & Triage Lead',
          regNo: docId || 'DOC-KA-2026-4412',
          facility: hospital
        };
        localStorage.setItem('netra_active_doctor', JSON.stringify(clinicianProfile));
        localStorage.setItem('netra_active_role', 'specialist');

        if (elements.authStatusAlert) {
          elements.authStatusAlert.className = 'auth-status-alert success';
          elements.authStatusAlert.style.display = 'flex';
          elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Clinician Authenticated!</strong> Welcome, Dr. Meera Iyer. Loading triage worklist...</div>`;
        }

        setTimeout(() => {
          window.location.href = 'index.html';
        }, 600);
      });
    }

    // Demo Clinician Access Button (Dr. Meera Iyer)
    if (elements.btnDemoDoctor) {
      elements.btnDemoDoctor.addEventListener('click', () => {
        const clinicianProfile = {
          name: 'Dr. Meera Iyer, MBBS, MS (Ophth)',
          role: 'Senior Ophthalmologist & Triage Lead',
          regNo: 'DOC-KA-2026-4412',
          facility: 'Christ University Health Centre (Bengaluru)'
        };
        localStorage.setItem('netra_active_doctor', JSON.stringify(clinicianProfile));
        localStorage.setItem('netra_active_role', 'specialist');

        if (elements.authStatusAlert) {
          elements.authStatusAlert.className = 'auth-status-alert success';
          elements.authStatusAlert.style.display = 'flex';
          elements.authStatusAlert.innerHTML = `<span>✓</span><div><strong>Clinician Authenticated!</strong> Welcome, Dr. Meera Iyer. Opening Triage Portal...</div>`;
        }

        setTimeout(() => {
          window.location.href = 'index.html';
        }, 550);
      });
    }

    // Appointment Booking Form inside Dashboard
    if (elements.appointmentBookingForm) {
      elements.appointmentBookingForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const locSelect = document.getElementById('selectApptLocation');
        const docSelect = document.getElementById('selectApptDoctor');
        const dateInput = document.getElementById('inputApptDate');
        const timeSelect = document.getElementById('selectApptTime');

        const loc = locSelect ? locSelect.value : "Christ University Health Centre";
        const doc = docSelect ? docSelect.value : "Dr. Meera Iyer";
        const rawDate = dateInput ? dateInput.value : "2026-09-25";
        const time = timeSelect ? timeSelect.value : "10:30 AM";

        let formattedDate = rawDate;
        try {
          const d = new Date(rawDate);
          formattedDate = d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
        } catch (err) {}

        const active = state.activePatient || DEMO_PATIENT;
        active.appointment = {
          type: "Retinal Screening",
          doctor: doc,
          date: `${formattedDate} • ${time}`,
          location: loc
        };

        setStoredPatient(active);
        elements.modalAppointment.classList.remove('open');
        renderDashboardForActivePatient();
        alert(`✓ Appointment successfully scheduled for ${active.name} on ${formattedDate} at ${loc}!`);
      });
    }

    // Close Modals
    document.querySelectorAll('[data-close-modal]').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.modal-backdrop').forEach(m => m.classList.remove('open'));
      });
    });

    // Layer Toggles in Modal
    document.querySelectorAll('.btn-layer-toggle').forEach(btn => {
      btn.addEventListener('click', () => {
        const layer = btn.getAttribute('data-layer');
        setFundusLayer(layer);
      });
    });

    // Carousel Controls
    const prevTipBtn = document.getElementById('prevTipBtn');
    const nextTipBtn = document.getElementById('nextTipBtn');
    if (prevTipBtn) {
      prevTipBtn.addEventListener('click', () => {
        const nextIdx = (state.currentTipIndex - 1 + state.tips.length) % state.tips.length;
        renderTipsCarousel(nextIdx);
      });
    }
    if (nextTipBtn) {
      nextTipBtn.addEventListener('click', () => {
        const nextIdx = (state.currentTipIndex + 1) % state.tips.length;
        renderTipsCarousel(nextIdx);
      });
    }

    // Appointment Modal Triggers
    const btnBookBanner = document.getElementById('btnBookBanner');
    const actionBookTile = document.getElementById('actionBookTile');
    if (btnBookBanner && elements.modalAppointment) {
      btnBookBanner.addEventListener('click', () => elements.modalAppointment.classList.add('open'));
    }
    if (actionBookTile && elements.modalAppointment) {
      actionBookTile.addEventListener('click', () => elements.modalAppointment.classList.add('open'));
    }

    // Reports trigger
    const actionReportsTile = document.getElementById('actionReportsTile');
    const navItemReports = document.getElementById('navItemReports');
    if (actionReportsTile && elements.modalReport) {
      actionReportsTile.addEventListener('click', () => {
        const patient = state.activePatient || DEMO_PATIENT;
        if (patient.isDemo) {
          elements.modalReport.classList.add('open');
          setFundusLayer('original');
        } else {
          alert('No clinical reports on file yet. Please schedule a baseline retinal screening.');
        }
      });
    }
    if (navItemReports && elements.modalReport) {
      navItemReports.addEventListener('click', () => {
        const patient = state.activePatient || DEMO_PATIENT;
        if (patient.isDemo) {
          elements.modalReport.classList.add('open');
          setFundusLayer('original');
        } else {
          alert('No clinical reports on file yet. Please schedule a baseline retinal screening.');
        }
      });
    }

    // Contact Support Modal Trigger
    const btnContactSupport = document.getElementById('btnContactSupport');
    if (btnContactSupport && elements.modalSupport) {
      btnContactSupport.addEventListener('click', () => {
        const patient = state.activePatient || DEMO_PATIENT;
        const msg = document.getElementById('supportWelcomeMessage');
        if (msg) {
          msg.textContent = `Hello ${patient.name}! 👋 How can I help you today regarding your eye health check-ups, appointments, or understanding your retinal screening results?`;
        }
        elements.modalSupport.classList.add('open');
      });
    }

    // Reminders Left Sidebar Menu Trigger
    if (elements.navItemReminders) {
      elements.navItemReminders.addEventListener('click', () => {
        openRemindersManager();
      });
    }

    // Patient sidebar navigation: keep the active state and reveal the matching dashboard area.
    document.querySelectorAll('.dash-menu-item').forEach((item) => {
      item.addEventListener('click', () => {
        document.querySelectorAll('.dash-menu-item').forEach((menuItem) => menuItem.classList.remove('active'));
        item.classList.add('active');

        if (item.id === 'navItemAppointments' && elements.modalAppointment) {
          elements.modalAppointment.classList.add('open');
          return;
        }
        if (item.id === 'navItemReports' || item.id === 'navItemReminders') return;

        const target = document.getElementById(item.dataset.target || '');
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        if (item.id === 'navItemProfile' && elements.userProfileChipBtn) elements.userProfileChipBtn.click();
      });
    });

    // 20-20-20 Timer Modal Controls
    if (elements.btnToggleTimer) {
      elements.btnToggleTimer.addEventListener('click', startEyeRestTimer);
    }
    if (elements.btnResetTimer) {
      elements.btnResetTimer.addEventListener('click', resetEyeRestTimer);
    }

    // Add Custom Reminder Form Submission
    if (elements.formAddReminder) {
      elements.formAddReminder.addEventListener('submit', (e) => {
        e.preventDefault();
        const title = elements.inputNewReminderTitle ? elements.inputNewReminderTitle.value.trim() : '';
        const cat = elements.selectReminderCategory ? elements.selectReminderCategory.value : 'meds';
        const time = elements.inputReminderTime ? elements.inputReminderTime.value.trim() : 'Daily';
        if (!title) return;

        const catConfig = {
          meds: { label: 'Eye Drops', icon: 'teal', actionTag: 'Take Drops 💧', actionType: 'meds' },
          screen: { label: 'Eye Rest', icon: 'red', actionTag: 'Start 20s Rest 👁️', actionType: 'timer' },
          screening: { label: 'Screening', icon: 'amber', actionTag: 'Book Scan 📸', actionType: 'appointment' },
          sugar: { label: 'Glucose Check', icon: 'amber', actionTag: 'Record 🩸', actionType: 'sugar' },
          doctor: { label: 'Doctor Visit', icon: 'teal', actionTag: 'View Appt 🩺', actionType: 'appointment' }
        };
        const cfg = catConfig[cat] || catConfig.meds;

        const patient = state.activePatient || DEMO_PATIENT;
        const reminders = getPatientReminders(patient);
        reminders.unshift({
          id: 'custom_' + Date.now(),
          title: title,
          meta: time,
          icon: cfg.icon,
          category: cat,
          categoryLabel: cfg.label,
          actionTag: cfg.actionTag,
          actionType: cfg.actionType,
          completed: false
        });
        savePatientReminders(patient, reminders);
        renderRemindersCard();
        renderRemindersManagerModal();

        if (elements.inputNewReminderTitle) elements.inputNewReminderTitle.value = '';
        if (elements.inputReminderTime) elements.inputReminderTime.value = '';
        alert(`✓ New reminder "${title}" added to your schedule!`);
      });
    }

    // Window Resize listener for Journey Chart redraw
    window.addEventListener('resize', () => {
      if (elements.canvasJourney) {
        renderJourneyChart();
      }
    });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
