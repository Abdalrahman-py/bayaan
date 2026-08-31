/* =============================================================================
   BAYAAN (بيان) — Presentation engine
   Vanilla JS, no dependencies, no framework, no build step.
   ========================================================================== */
(function () {
  'use strict';

  const $ = (sel, ctx) => (ctx || document).querySelector(sel);
  const $$ = (sel, ctx) => Array.from((ctx || document).querySelectorAll(sel));
  const reduceMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const tpl = document.createElement('template');
  function h(str) {
    tpl.innerHTML = str.trim();
    return tpl.content.firstElementChild;
  }
  function icon(name, extra) {
    return `<svg viewBox="0 0 24 24"${extra ? ' class="' + extra + '"' : ''}><use href="#i-${name}"/></svg>`;
  }
  function stagger(container, step) {
    Array.from(container.children).forEach((el, i) => {
      el.classList.add('reveal');
      el.style.setProperty('--d', (i * (step || 80)) + 'ms');
    });
  }
  function esc(s) { return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;'); }

  /* ---------------------------------------------------------- Icon lookup by id used in data.js */
  const ICONS = {
    teacher: 'teacher', play: 'play', waveform: 'waveform', book: 'book',
    seedling: 'seedling', reader: 'reader', users: 'users', mushaf: 'mushaf',
    letters: 'letters', sparkles: 'sparkles', tajweed: 'tajweed', flame: 'flame',
    lock: 'lock', key: 'key', server: 'server', 'eye-off': 'eye-off',
    'mic-off': 'mic-off', shield: 'shield', database: 'database', cpu: 'cpu',
    phone: 'phone', kotlin: 'kotlin'
  };

  /* ================================================================ 01 HERO */
  function renderHero() {
    $('#heroEyebrow').innerHTML = `<span class="eyebrow__num">${esc(BAYAAN.hero.year)}</span> ${esc(BAYAAN.hero.eyebrow)}`;
    $('#heroTitle').textContent = BAYAAN.hero.title;
    $('#heroSub').textContent = BAYAAN.hero.sub;
    $('#heroTag').innerHTML = BAYAAN.hero.tag;
    const chips = $('#heroChips');
    BAYAAN.hero.chips.forEach(c => {
      chips.appendChild(h(`<span class="chip">${icon(c.icon)}<span class="en">${esc(c.label)}</span></span>`));
    });
    buildMock($('#heroPhone'), 'splash');
  }

  /* ================================================================ 02 TEAM */
  function renderTeam() {
    $('#masthead').innerHTML = `
      <span>${esc(BAYAAN.team.institution[0])}</span>
      <span>${esc(BAYAAN.team.institution[1])}</span>`;
    const grid = $('#teamGrid');
    BAYAAN.team.members.forEach((m, i) => {
      const initials = m.name.split(' ').map(w => w[0]).slice(0, 2).join('');
      grid.appendChild(h(`
        <article class="card card--hover card--glow member">
          <div class="member__mono">${esc(initials)}</div>
          <div class="member__name en">${esc(m.name)}</div>
          <div class="member__ar">${esc(m.ar)}</div>
          <span class="member__role">${esc(m.role)}</span>
        </article>`));
    });
    stagger(grid, 90);
    const c = BAYAAN.team.credits;
    $('#creditsBanner').innerHTML = `
      <div class="credits-col">
        <span class="credits-label">${esc(c.submitted.label)}</span>
        <div class="credits-en en">${esc(c.submitted.en)}</div>
        <div class="credits-ar">${esc(c.submitted.ar)}</div>
      </div>
      <div class="credits-div"></div>
      <div class="credits-col">
        <span class="credits-label">${esc(c.supervised.label)}</span>
        <div class="credits-en en">${esc(c.supervised.en)}</div>
        <div class="credits-ar">${esc(c.supervised.ar)}</div>
      </div>`;
  }

  /* ============================================================= 03 PROBLEM */
  function renderProblem() {
    const colL = $('#probColL'), colR = $('#probColR');
    BAYAAN.problems.forEach((p, i) => {
      const card = h(`
        <div class="problem-card reveal ${i < 2 ? 'reveal--right' : 'reveal--left'}" data-d="${i * 110}">
          <div class="problem-card__ico">${icon(ICONS[p.icon] || 'sparkles')}</div>
          <div><h3>${esc(p.title)}</h3><p>${esc(p.body)}</p></div>
        </div>`);
      (i < 2 ? colL : colR).appendChild(card);
    });
  }

  /* ================================================================= 04 WHY */
  function renderWhy() {
    $('#whyQuestion').innerHTML = BAYAAN.why.question;
    $('#whyBody').innerHTML = BAYAAN.why.body;
  }

  /* ============================================================ 05 AUDIENCE */
  function renderAudience() {
    const grid = $('#audGrid');
    const icoMap = { seedling: 'seedling', reader: 'reader', users: 'users' };
    BAYAAN.audience.forEach(a => {
      grid.appendChild(h(`
        <article class="card card--hover card--glow aud-card">
          <span class="aud-card__tag">${esc(a.tag)}</span>
          <div class="aud-card__ico icon-tile icon-tile--ghost">${icon(icoMap[a.icon] || 'users')}</div>
          <h3>${esc(a.title)}</h3>
          <p>${esc(a.body)}</p>
          ${a.note ? `<span class="aud-card__note">${esc(a.note)}</span>` : ''}
        </article>`));
    });
    stagger(grid, 100);
    $('#audNote').innerHTML = `<h4>${esc(BAYAAN.audienceNote.title)}</h4><p>${esc(BAYAAN.audienceNote.body)}</p>`;
  }

  /* ============================================================== 06 MARKET */
  function renderMarket() {
    const t = $('#cmpTable');
    const thead = `<thead><tr><th></th>${BAYAAN.comparison.columns.map((c, i) =>
      `<th class="${i === 2 ? 'is-bayaan' : ''}">${esc(c)}</th>`).join('')}</tr></thead>`;
    const rows = BAYAAN.comparison.rows.map((r, ri) => `
      <tr data-i="${ri}">
        <td class="cmp__feat"><b>${esc(r.feature)}</b><span>${esc(r.note)}</span></td>
        ${r.values.map((v, ci) => `<td class="${ci === 2 ? 'is-bayaan-col' : ''}">
          <span class="mark mark--${v ? 'yes' : 'no'}">${icon(v ? 'check' : 'x')}</span>
        </td>`).join('')}
      </tr>`).join('');
    t.innerHTML = thead + `<tbody>${rows}</tbody>`;

    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => { if (en.isIntersecting) { en.target.classList.add('is-in'); io.unobserve(en.target); } });
    }, { threshold: 0.4 });
    $$('tbody tr', t).forEach((tr, i) => { tr.style.transitionDelay = (i * 60) + 'ms'; io.observe(tr); });
  }

  /* ================================================================= 07 GAP */
  /* Pure CSS radial layout (clock-hand rotate/translate technique) — driven
     entirely by the same reveal-on-scroll engine as every other section.
     No runtime position computation, no lock/replay state machine. */
  function renderGap() {
    const spokes = $('#gapSpokes');
    const angles = [-90, -30, 30, 90, 150, 210];
    BAYAAN.gaps.forEach((g, i) => {
      const angle = angles[i];
      const spoke = h(`
        <div class="gap-spoke" style="--angle:${angle}deg">
          <span class="gap-spoke__line" data-d="${i * 90}"><i class="gap-spoke__dot"></i></span>
          <div class="gap-spoke__node" data-d="${i * 90 + 260}">
            <div class="gap-node__ico">${icon(ICONS[g.icon] || g.icon)}</div>
            <div class="gap-node__ar">${esc(g.ar)}</div>
            <div class="gap-node__en en">${esc(g.label)}</div>
          </div>
        </div>`);
      spokes.appendChild(spoke);
    });
    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => { if (en.isIntersecting) en.target.classList.add('is-in'); });
    }, { threshold: 0.2 });
    $$('.gap-spoke__line, .gap-spoke__node, .gap-hub', spokes.closest('.gap-map')).forEach(el => {
      if (el.dataset.d) el.style.transitionDelay = el.dataset.d + 'ms';
      io.observe(el);
    });
  }

  /* ============================================================ 08 SOLUTION */
  function renderSolution() {
    const grid = $('#modulesGrid');
    BAYAAN.modules.forEach((m, i) => {
      grid.appendChild(h(`
        <article class="card card--hover card--glow module">
          <span class="module__idx">${String(i + 1).padStart(2, '0')}</span>
          <div class="module__body">
            <div class="icon-tile" style="margin-bottom:16px">${icon(ICONS[m.icon] || 'sparkles')}</div>
            <span class="module__en en">${esc(m.en)}</span>
            <h3>${esc(m.ar)}</h3>
            <p>${esc(m.body)}</p>
          </div>
        </article>`));
    });
    stagger(grid, 90);
  }

  /* =========================================================== 09 CURRICULUM */
  function renderCurriculum() {
    const track = $('#unitTrack'), detail = $('#unitDetail');
    function paint(idx) {
      const u = BAYAAN.curriculumUnits[idx];
      detail.innerHTML = `
        <span class="unit-detail__id en">UNIT ${u.n}</span>
        <div class="unit-detail__title">${esc(u.en)}</div>
        <div class="unit-detail__title-ar">${esc(u.title)}</div>
        <p class="unit-detail__focus">${esc(u.focus)}</p>
        <div class="unit-detail__stats">
          <div class="unit-detail__stat"><b>${u.lessons}</b><span>دروس</span></div>
          <div class="unit-detail__stat"><b>${u.items}</b><span>عنصرًا</span></div>
        </div>
        <div class="unit-detail__examples">
          <span class="unit-detail__examples-label">${idx === 7 ? 'السور المدروسة في هذه الوحدة' : 'أمثلة توضيحية من هذه الوحدة'}</span>
          <div class="unit-detail__examples-grid">
            ${u.examples.map(x => `<span class="ex-chip ${idx === 7 ? 'ex-chip--surah' : ''}">${esc(x)}</span>`).join('')}
          </div>
        </div>`;
      $$('.unit-row', track).forEach((r, i) => r.classList.toggle('is-active', i === idx));
    }
    BAYAAN.curriculumUnits.forEach((u, i) => {
      const row = h(`
        <div class="unit-row reveal" data-d="${i * 55}">
          <div class="unit-row__n">${u.n}</div>
          <div class="unit-row__title">${esc(u.title)}<span class="en">${esc(u.en)}</span></div>
          <div class="unit-row__meta"><span class="chip"><b>${u.lessons}</b>&nbsp;دروس</span></div>
        </div>`);
      row.addEventListener('click', () => paint(i));
      track.appendChild(row);
    });
    paint(0);

    $('#currTotals').innerHTML = `
      <div class="curr-totals__item"><b>${BAYAAN.curriculumTotals.units}</b><span>وحدات</span></div>
      <div class="curr-totals__item"><b>${BAYAAN.curriculumTotals.lessons}</b><span>درسًا</span></div>
      <div class="curr-totals__item"><b>${BAYAAN.curriculumTotals.items}</b><span>عنصر تدريب</span></div>
      <div class="curr-totals__item"><b>${BAYAAN.curriculumTotals.checkpoints}</b><span>اختبار محطّة</span></div>`;

    const tj = $('#tjGrid');
    BAYAAN.tajweedTrack.forEach(t => {
      tj.appendChild(h(`<div class="card tj-card"><h4>${esc(t.title)}</h4><span class="en">${esc(t.en)}</span><p>${esc(t.body)}</p></div>`));
    });
    stagger(tj, 90);
  }

  /* ============================================================= 10/11 MOCKS */
  const SHOTS = {
    splash: 'img/splash.png', auth: 'img/auth.jpg', tabs: 'img/tabs.jpg',
    roadmap: 'img/roadmap.jpg', teach: 'img/teach.jpg', record: 'img/record.jpg',
    result: 'img/result.jpg', mushaf: 'img/mushaf.jpg', analysis: 'img/analysis.jpg',
    progress: 'img/progress.jpg'
  };
  function buildMock(container, key) {
    if (!container) return;
    if (SHOTS[key]) {
      container.innerHTML = `<img class="mock-shot" src="${SHOTS[key]}" alt="" loading="lazy">`;
      return;
    }
    const map = {
      splash: `<div class="mock is-shown mock--splash"><svg class="bayaan-mark" viewBox="0 0 100 100"><path d="M25 62V32c0-6 4-10 12-10h6c7 0 12 5 12 11 0 5-3 8-7 9 5 1 9 5 9 11 0 7-5 12-13 12H25z" fill="#fff"/></svg><span>بيان</span></div>`,
      auth: `<div class="mock is-shown mock--auth"><div class="mock__topbar"><b>تسجيل الدخول</b></div><div class="mock__field"></div><div class="mock__field"></div><div class="mock__btn"></div></div>`,
      tabs: `<div class="mock is-shown mock--roadmap"><div class="mock__topbar"><b>بيان</b></div>${mockNodes(3)}</div>`,
      roadmap: `<div class="mock is-shown mock--roadmap"><div class="mock__topbar"><b>مسار التعلّم</b></div>${mockNodes(5)}</div>`,
      teach: `<div class="mock is-shown mock--teach"><span class="mock__badge">تعليم</span><p class="quran">بِسْمِ</p><div class="mock__btn" style="width:70%"></div></div>`,
      record: `<div class="mock is-shown mock--record"><span class="mock__badge">استمع وكرّر</span><div class="mock__wave">${mockBars()}</div><div class="mock__mic">${icon('mic')}</div></div>`,
      result: `<div class="mock is-shown mock--result"><div class="mock__ring"><i>78٪</i></div><span class="mock__badge">إعادة بلا عقوبة</span></div>`,
      mushaf: `<div class="mock is-shown mock--mushaf"><div class="mock__topbar"><b class="en">Al-Fatihah</b></div><div class="mock__mushaf-lines">${mockLines(9)}</div></div>`,
      analysis: `<div class="mock is-shown mock--analysis"><div class="mock__topbar"><b>تحليل الآية</b></div>
        <p class="mock__analysis-line">الْحَمْدُ لِلَّهِ <mark>رَبِّ</mark> الْعَالَمِينَ</p>
        <p class="mock__analysis-line">الرَّحْمَٰنِ <mark class="m2">الرَّحِيمِ</mark></p>
        <p class="mock__analysis-line">مَالِكِ <mark class="m3">يَوْمِ</mark> الدِّينِ</p></div>`,
      progress: `<div class="mock is-shown mock--progress"><div class="mock__topbar"><b>التقدّم</b></div><div class="mock__stat-row"><div class="mock__stat"><b>12</b><span>تتابع</span></div><div class="mock__stat"><b>640</b><span>نقاط</span></div><div class="mock__stat"><b>٪78</b><span>دقّة</span></div></div><div class="mock__mushaf-lines">${mockLines(4)}</div></div>`
    };
    container.innerHTML = map[key] || map.splash;
  }
  function mockNodes(n) {
    let out = '';
    for (let i = 0; i < n; i++) out += `<div class="mock-node${i > n - 2 ? ' mock-node--locked' : ''}"><div class="mock-node__dot"></div><div class="mock-node__bar"></div></div>`;
    return out;
  }
  function mockLines(n) {
    let out = '';
    for (let i = 0; i < n; i++) out += `<span style="width:${60 + Math.random() * 35}%"></span>`;
    return out;
  }
  function mockBars() {
    let out = '';
    for (let i = 0; i < 14; i++) out += `<i style="height:${8 + Math.random() * 16}px"></i>`;
    return out;
  }

  /* ================================================================ 10 JOURNEY */
  function renderJourney() {
    const steps = $('#journeySteps');
    BAYAAN.journey.forEach((s, i) => {
      steps.appendChild(h(`
        <div class="jstep" data-shot="${s.shot}">
          <span class="jstep__n en">${s.n}</span>
          <div class="jstep__title">${esc(s.title)}</div>
          <div class="jstep__body">${esc(s.body)}</div>
        </div>`));
    });
    const items = $$('.jstep', steps);
    const phone = $('#journeyPhone');
    buildMock(phone, BAYAAN.journey[0].shot);
    let active = 0;
    function activate(i) {
      if (i === active && items[i].classList.contains('is-active')) return;
      active = i;
      items.forEach((el, idx) => el.classList.toggle('is-active', idx === i));
      $('#jtrackFill').style.height = (((i + 1) / items.length) * 100) + '%';
      buildMock(phone, items[i].dataset.shot);
    }
    items.forEach((el, i) => el.addEventListener('click', () => activate(i)));
    activate(0);

    let ticking = false;
    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const line = window.innerHeight * 0.5;
        let closest = 0, closestDist = Infinity;
        items.forEach((el, i) => {
          const r = el.getBoundingClientRect();
          const mid = r.top + r.height / 2;
          const d = Math.abs(mid - line);
          if (d < closestDist && r.top < window.innerHeight && r.bottom > 0) { closestDist = d; closest = i; }
        });
        const journeySection = $('#journey');
        const jr = journeySection.getBoundingClientRect();
        if (jr.top < window.innerHeight && jr.bottom > 0) activate(closest);
        ticking = false;
      });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  /* =================================================================== 11 APP */
  function renderApp() {
    const track = $('#galleryTrack');
    BAYAAN.screens.forEach(s => {
      const item = h(`
        <div class="gallery-item">
          <div class="phone"><div class="phone__notch"></div><div class="phone__screen"></div><div class="phone__glare"></div></div>
          <div class="gallery-item__label">${esc(s.ar)}<span class="en">${esc(s.title)}</span></div>
        </div>`);
      buildMock($('.phone__screen', item), s.key);
      track.appendChild(item);
    });
    initDragScroll($('#galleryWrap'));
  }

  /* ==================================================================== 12 AI */
  function renderAI() {
    const svg = $('#aiDiagram');
    const nodes = BAYAAN.architecture.map((a, i) => a); // reuse three-box concept visually distinct diagram below
    svg.innerHTML = `
      <path class="flow-line" d="M120 70 C 200 70, 220 150, 240 180" />
      <path class="flow-line" d="M120 180 C 190 180, 210 180, 240 180" />
      <path class="flow-line" d="M120 290 C 200 290, 220 210, 240 180" />
      <circle class="core-ring r1" cx="240" cy="180" r="30"/>
      <circle class="core-ring r2" cx="240" cy="180" r="30"/>
      <rect class="node-box" x="20" y="42" width="110" height="56" rx="12" data-tab="0"/>
      <text class="node-title" x="75" y="66" text-anchor="middle">النطق</text>
      <text class="node-sub en" x="75" y="82" text-anchor="middle">Pronunciation</text>
      <rect class="node-box" x="20" y="152" width="110" height="56" rx="12" data-tab="1"/>
      <text class="node-title" x="75" y="176" text-anchor="middle">النطق القصير</text>
      <text class="node-sub en" x="75" y="192" text-anchor="middle">Arbitrary text</text>
      <rect class="node-box" x="20" y="262" width="110" height="56" rx="12" data-tab="2"/>
      <text class="node-title" x="75" y="286" text-anchor="middle">التجويد</text>
      <text class="node-sub en" x="75" y="302" text-anchor="middle">Tajweed</text>
      <circle cx="240" cy="180" r="26" fill="#06191C" stroke="#D9A441" stroke-width="1.6"/>
      <text x="240" y="177" text-anchor="middle" font-size="9.5" fill="#F7F4EE" font-weight="700">Muaalem</text>
      <text x="240" y="189" text-anchor="middle" font-size="8" fill="rgba(230, 224, 210,.6)">wav2vec2</text>
      <rect class="node-box" x="350" y="152" width="110" height="56" rx="12"/>
      <text class="node-title" x="405" y="176" text-anchor="middle">النتيجة</text>
      <text class="node-sub en" x="405" y="192" text-anchor="middle">Verdict + offset</text>
      <path class="flow-line" d="M270 180 C 300 180, 320 180, 350 180"/>
      <circle class="pulse-dot" r="3.2"><animateMotion dur="2.6s" repeatCount="indefinite" path="M120 70 C 200 70, 220 150, 240 180"/></circle>
      <circle class="pulse-dot" r="3.2"><animateMotion dur="2.6s" begin="0.9s" repeatCount="indefinite" path="M120 180 C 190 180, 210 180, 240 180"/></circle>
      <circle class="pulse-dot" r="3.2"><animateMotion dur="2.6s" begin="1.7s" repeatCount="indefinite" path="M120 290 C 200 290, 220 210, 240 180"/></circle>
      <circle class="pulse-dot" r="3" fill="#A9C888"><animateMotion dur="1.8s" repeatCount="indefinite" path="M270 180 C 300 180, 320 180, 350 180"/></circle>`;

    const engine = BAYAAN.aiEngine;
    const tabsDef = [
      { t: 'مدرّب النطق', body: `<p>${esc(engine.name)} — ${esc(engine.license)}</p><p style="margin-top:10px">${esc(engine.heads)}</p>` },
      { t: 'تقييم النطق القصير', body: `<div class="ai-contrib"><h4>${esc(engine.contribution.title)}</h4><p>${esc(engine.contribution.body)}</p><span class="ai-contrib__stat">${esc(engine.contribution.stat)}</span></div>` },
      { t: 'مسار التجويد', body: `<p>يُستخدم المحرّك نفسه لتقييم أحكام الغُنّة والقلقلة والمدّ على آيات مختارة من مصحف بيان، بنفس منطق تحديد الموضع الحرفي.</p>` }
    ];
    const tabsEl = $('#aiTabs'), panelEl = $('#aiPanel');
    tabsDef.forEach((t, i) => tabsEl.appendChild(h(`<button class="ai-tab${i === 0 ? ' is-active' : ''}" data-i="${i}">${esc(t.t)}</button>`)));
    function selectTab(i) {
      $$('.ai-tab', tabsEl).forEach((b, idx) => b.classList.toggle('is-active', idx === i));
      $$('.node-box', svg).forEach(b => b.classList.toggle('is-active', b.dataset.tab === String(i)));
      panelEl.innerHTML = '';
      const p = h(`<div class="ai-panel">${tabsDef[i].body}</div>`);
      panelEl.appendChild(p);
    }
    tabsEl.addEventListener('click', (e) => { const b = e.target.closest('.ai-tab'); if (b) selectTab(+b.dataset.i); });
    $$('.node-box[data-tab]', svg).forEach(n => n.addEventListener('click', () => selectTab(+n.dataset.tab)));
    selectTab(0);

    const tolT = $('#tolTable');
    tolT.innerHTML = `<thead><tr><th>الحالة</th><th>القرار</th><th class="en">Score</th></tr></thead><tbody>${
      engine.tolerancePolicy.map(r => `<tr><td>${esc(r.cond)}</td><td><span class="tol-verdict ${r.color}">${esc(r.verdict)}</span></td><td class="en">${esc(r.score)}</td></tr>`).join('')
    }</tbody>`;

    $('#spikeBox').innerHTML = `
      <h4>${esc(engine.spike.title)}</h4>
      <div class="spike-stats">
        <div><b>${engine.spike.clips}</b><span>مقطعًا مُختبَرًا</span></div>
        <div><b>${engine.spike.speakers}</b><span>متحدّثَين</span></div>
        <div><b>${esc(engine.spike.localized)}</b><span>${esc(engine.spike.localizedNote)}</span></div>
      </div>
      <p>${esc(engine.spike.caveat)}</p>`;
  }

  /* ================================================================ 13 GAMIFY */
  function renderGamify() {
    const cards = $('#gamifyCards');
    BAYAAN.gamification.forEach(g => {
      cards.appendChild(h(`
        <div class="card gcard reveal">
          <div class="gcard__ico">${icon(ICONS[g.icon] || 'sparkles')}</div>
          <div><h4>${esc(g.title)}</h4><p>${esc(g.body)}</p></div>
        </div>`));
    });
    const ladder = $('#ladderList');
    BAYAAN.srsLadder.forEach(r => {
      ladder.appendChild(h(`
        <div class="ladder__rung">
          <div class="ladder__num">${r.rung}</div>
          <div><div class="ladder__interval">${esc(r.interval)}</div></div>
          <span class="ladder__label">${esc(r.label)}</span>
        </div>`));
    });
  }

  /* =========================================================== 14 ARCHITECTURE */
  function renderArchitecture() {
    const boxes = $('#archBoxes');
    BAYAAN.architecture.forEach((a, i) => {
      boxes.appendChild(h(`
        <div class="card arch-box reveal" data-d="${i * 100}">
          <div class="arch-box__badge en">${i + 1}</div>
          <div class="arch-box__layer en">${esc(a.box)}</div>
          <h3>${esc(a.ar)}</h3>
          <h4 class="en">${esc(a.layer)}</h4>
          <p>${esc(a.desc)}</p>
          <div class="arch-box__stack">${a.stack.map(s => `<span class="chip en">${esc(s)}</span>`).join('')}</div>
        </div>`));
    });
    const dep = $('#deployGrid');
    BAYAAN.deployment.forEach(d => {
      dep.appendChild(h(`
        <div class="card deploy-card reveal">
          <div class="deploy-card__ico">${icon(ICONS[d.icon] || d.icon)}</div>
          <div><h4>${esc(d.title)}</h4><p>${esc(d.body)}</p></div>
        </div>`));
    });
    stagger(dep, 80);
  }

  /* ================================================================= 15 STACK */
  function renderStack() {
    const filters = $('#stackFilters');
    const groups = [['all', 'الكل'], ['client', 'العميل'], ['server', 'الخادم'], ['data', 'البيانات والذكاء'], ['ops', 'التشغيل']];
    groups.forEach(([g, label], i) => filters.appendChild(h(`<button class="sfilter${i === 0 ? ' is-active' : ''}" data-g="${g}">${label}</button>`)));

    const grid = $('#techGrid');
    BAYAAN.tech.forEach(t => {
      grid.appendChild(h(`
        <div class="card tech" data-g="${t.group}">
          <div class="tech__mark">${techMark(t.name)}</div>
          <div class="tech__name en">${esc(t.name)}</div>
          <div class="tech__ver en">${esc(t.ver)}</div>
          <div class="tech__purpose">${esc(t.purpose)}</div>
        </div>`));
    });
    stagger(grid, 40);

    filters.addEventListener('click', (e) => {
      const b = e.target.closest('.sfilter'); if (!b) return;
      $$('.sfilter', filters).forEach(x => x.classList.toggle('is-active', x === b));
      const g = b.dataset.g;
      $$('.tech', grid).forEach(card => card.classList.toggle('is-dim', g !== 'all' && card.dataset.g !== g));
    });
  }
  function techMark(name) {
    const common = 'width="40" height="40" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg"';
    const tile = (inner, bg) => `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="${bg || '#F3F1E7'}" stroke="rgba(20,20,20,0.06)"/>${inner}</svg>`;
    const marks = {
      /* Kotlin — official folded-ribbon mark, purple→orange gradient */
      'Kotlin': `<svg ${common}><defs><linearGradient id="kt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E44857"/><stop offset=".5" stop-color="#C711E1"/><stop offset="1" stop-color="#7F52FF"/></linearGradient></defs><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><path d="M9 9h11L9 21V9z" fill="#7F52FF"/><path d="M9 21L20.5 9H31L20 20 31 31H9z" fill="url(#kt)"/></svg>`,
      /* Flutter — official two-flag folded mark, blue gradient */
      'Flutter': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><path d="M15 22L27 10H33L21 22Z" fill="#42A5F5"/><path d="M15 22L21 28L27 22L21 16Z" fill="#0D47A1"/><path d="M21 28L27 34H33L21 22Z" fill="#42A5F5" opacity="0.55"/></svg>`,
      /* Dart — official rounded dart/leaf mark, teal-to-blue gradient */
      'Dart': `<svg ${common}><defs><linearGradient id="dt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#00D2B8"/><stop offset="1" stop-color="#0175C2"/></linearGradient></defs><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><path d="M8 24L20 9l12 6-12 15z" fill="url(#dt)"/><path d="M8 24l12 7 12-10-12-4z" fill="#0175C2" opacity="0.85"/></svg>`,
      /* Material Design — 4-facet colour diamond */
      'Material 3': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><path d="M20 6l9 9-4 4-9-9z" fill="#EA4335"/><path d="M20 6l-9 9 4 4 9-9z" fill="#4285F4"/><path d="M20 34l9-9-4-4-9 9z" fill="#34A853"/><path d="M20 34l-9-9 4-4 9 9z" fill="#FBBC05"/></svg>`,
      /* go_router — declarative route path with destination pin, Flutter-blue */
      'go_router': tile(`<path d="M9 28c4-9 8-3 11-9s5-9 11-9" stroke="#0175C2" stroke-width="2.4" fill="none" stroke-dasharray="1 4.6" stroke-linecap="round"/><circle cx="31" cy="10" r="3.4" fill="#0175C2"/><path d="M9 28a3 3 0 106 0 3 3 0 00-6 0z" fill="#42A5F5"/>`),
      /* Ktor — JetBrains dark navy square with pale arrow */
      'Ktor Server': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#0B1727"/><path d="M12 10h4v9l9-9h5.5L19.5 20.5 31 31h-5.5L16 21.5V31h-4z" fill="#F2F7FF"/></svg>`,
      'Exposed ORM': tile(`<rect x="10" y="11" width="20" height="4.5" rx="1.6" fill="var(--primary)"/><rect x="10" y="17.7" width="20" height="4.5" rx="1.6" fill="#7C9A54"/><rect x="10" y="24.5" width="13" height="4.5" rx="1.6" fill="#D9A441"/>`),
      /* HikariCP — light-bulb (Hikari = "light" in Japanese) */
      'HikariCP': tile(`<path d="M20 9a7.5 7.5 0 00-4 13.9c.7.5 1 1.1 1 1.9v1h6v-1c0-.8.3-1.4 1-1.9A7.5 7.5 0 0020 9z" fill="none" stroke="#E8863C" stroke-width="2"/><path d="M17.5 29h5M18 32h4" stroke="#E8863C" stroke-width="2" stroke-linecap="round"/>`),
      /* PostgreSQL — simplified Slonik elephant head, official blue */
      'PostgreSQL': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#336791"/><path d="M13 26v-8c0-4.4 3.6-8 8-8 3.9 0 7.1 2.8 7.8 6.5.5.1 1.2.4 1.2 1.5 0 1.3-1 1.8-1.7 1.9-.4 2.7-2.1 5-4.5 6.1l.2 3H21l-.3-2.3c-.6.1-1.1.2-1.7.2H17v2.1h-3V26z" fill="#fff"/><circle cx="24.5" cy="17.5" r="1" fill="#336791"/></svg>`,
      /* Supabase — official green lightning mark */
      'Supabase': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#1C1C1C"/><path d="M22 9L11 23.5h8L18 31l11-14.5h-8L22 9z" fill="#3ECF8E"/></svg>`,
      /* Modal — purple/pink gradient abstract M */
      'Modal': `<svg ${common}><defs><linearGradient id="md" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7A5CFA"/><stop offset="1" stop-color="#F45B8D"/></linearGradient></defs><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><path d="M11 28V13l9 9 9-9v15" fill="none" stroke="url(#md)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
      'Muaalem': tile(`<rect x="12" y="17" width="2.6" height="7" rx="1.3" fill="var(--primary)"/><rect x="16.5" y="12" width="2.6" height="17" rx="1.3" fill="var(--primary)"/><rect x="21" y="15" width="2.6" height="11" rx="1.3" fill="#7C9A54"/><rect x="25.5" y="9" width="2.6" height="23" rx="1.3" fill="#7C9A54"/>`),
      /* Render — indigo rounded triangle */
      'Render': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#111"/><path d="M20 11l8.5 14.5h-17z" fill="none" stroke="#7A7CFF" stroke-width="2.6" stroke-linejoin="round"/></svg>`,
      /* FastAPI — teal bolt, official style */
      'FastAPI': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#009485"/><circle cx="20" cy="20" r="10.5" fill="none" stroke="#fff" stroke-width="1.6"/><path d="M22 11.5l-7 10h5l-1 8 7-10.5h-5z" fill="#fff"/></svg>`,
      /* JWT — pink/magenta token */
      'JWT · ES256': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#FB015B"/><circle cx="15" cy="20" r="5.2" fill="none" stroke="#fff" stroke-width="2.2"/><path d="M19.5 20H29M24.5 20v3.5M28 20v3.5" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></svg>`,
      /* Docker — official blue whale with containers */
      'Docker': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><g fill="#2496ED"><rect x="9" y="18" width="4.5" height="4.5"/><rect x="14" y="18" width="4.5" height="4.5"/><rect x="14" y="12.5" width="4.5" height="4.5"/><rect x="19" y="18" width="4.5" height="4.5"/><rect x="19" y="12.5" width="4.5" height="4.5"/><rect x="24" y="18" width="4.5" height="4.5"/></g><path d="M7 22.5c0 4.4 5 7.5 13 7.5 7.5 0 12-3.7 13.5-7.5-1.2-1-2.8-1-3.8 0" fill="none" stroke="#2496ED" stroke-width="1.7" stroke-linecap="round"/></svg>`,
      /* GitHub — simplified circular cat-silhouette mark */
      'GitHub': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#171515"/><path d="M20 9c-6.6 0-12 5.4-12 12 0 5.3 3.4 9.7 8.2 11.3.6.1.8-.3.8-.6v-2.2c-3.3.7-4-1.6-4-1.6-.5-1.4-1.3-1.8-1.3-1.8-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1.1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.7-1.6-2.6-.3-5.4-1.3-5.4-5.8 0-1.3.5-2.3 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2 1-.3 2-.4 3-.4s2 .1 3 .4c2.3-1.5 3.3-1.2 3.3-1.2.6 1.7.2 2.9.1 3.2.8.9 1.2 1.9 1.2 3.2 0 4.5-2.8 5.5-5.4 5.8.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6C28.6 30.7 32 26.3 32 21c0-6.6-5.4-12-12-12z" fill="#fff"/></svg>`,
      /* H2 Database */
      'H2 Database': `<svg ${common}><rect x="1" y="1" width="38" height="38" rx="11" fill="#fff" stroke="rgba(20,20,20,0.06)"/><ellipse cx="16" cy="13.5" rx="7" ry="2.8" fill="#0F4C81"/><path d="M9 13.5V25c0 1.5 3.1 2.8 7 2.8s7-1.3 7-2.8V13.5" fill="none" stroke="#0F4C81" stroke-width="1.8"/><text x="26" y="27" font-size="12" font-weight="800" fill="#FF6B4A" font-family="Segoe UI, sans-serif">2</text></svg>`,
      'AGENTS.md': tile(`<rect x="12" y="14" width="16" height="13" rx="4" fill="none" stroke="var(--primary)" stroke-width="2"/><circle cx="17" cy="20.5" r="1.6" fill="var(--primary)"/><circle cx="23" cy="20.5" r="1.6" fill="var(--primary)"/><path d="M20 14v-3" stroke="var(--primary)" stroke-width="2" stroke-linecap="round"/><circle cx="20" cy="9.5" r="1.6" fill="#D9A441"/>`)
    };
    if (marks[name]) return marks[name];
    const initial = name.replace(/[^A-Za-z]/g, '')[0] || '•';
    return tile(`<text x="20" y="26" text-anchor="middle" font-size="16" font-weight="800" fill="var(--primary)" font-family="Segoe UI, sans-serif">${initial}</text>`);
  }

  /* ============================================================== 16 SECURITY */
  function renderSecurity() {
    const grid = $('#secGrid');
    BAYAAN.security.forEach((s, i) => {
      const emphasis = s.icon === 'sparkles';
      grid.appendChild(h(`
        <div class="card sec-item reveal${emphasis ? ' sec-item--emphasis' : ''}" data-d="${i * 60}">
          <div class="sec-item__ico">${icon(ICONS[s.icon] || s.icon)}</div>
          <div><h4>${esc(s.title)}</h4><p>${esc(s.body)}</p></div>
        </div>`));
    });
  }

  /* =============================================================== 17 TESTING */
  function renderTesting() {
    const cov = $('#testCoverage');
    BAYAAN.testing.coverage.forEach(c => {
      cov.appendChild(h(`<div class="test-row reveal"><span class="test-row__check">${icon('check')}</span><span>${esc(c)}</span></div>`));
    });
    $('#harnessNote').textContent = BAYAAN.testing.harness;
    $('#pipelineNote').textContent = BAYAAN.testing.pipeline;
    $('#deviceNote').textContent = BAYAAN.testing.device;

    const p = $('#perfStats');
    const t = BAYAAN.testing.backend;
    p.innerHTML = `
      <div class="perf-stat"><b class="cnt en" data-to="${t.classes}">0</b><span>فئة اختبار</span></div>
      <div class="perf-stat"><b class="cnt en" data-to="${t.methods}">0</b><span>اختبارًا آليًا</span></div>
      <div class="perf-stat"><b class="cnt en" data-to="${t.lines}">0</b><span>سطر اختبار</span></div>`;
  }

  /* =============================================================== 18 ACHIEVED */
  function renderAchieved() {
    const grid = $('#achGrid');
    BAYAAN.achievements.forEach((a, i) => {
      grid.appendChild(h(`
        <div class="card ach reveal" data-d="${i * 55}">
          <div class="ach__check">${icon('check')}</div>
          <em class="en">${esc(a.en)}</em>
          <h4>${esc(a.title)}</h4>
          <p>${esc(a.body)}</p>
        </div>`));
    });
  }

  /* ================================================================ 19 LIMITS */
  function renderLimits() {
    const list = $('#limitsList');
    BAYAAN.limitations.forEach((l, i) => {
      list.appendChild(h(`
        <div class="card limit-item reveal" data-d="${i * 60}">
          <div class="limit-item__n en">${String(i + 1).padStart(2, '0')}</div>
          <div><h4>${esc(l.title)}</h4><p>${esc(l.body)}</p></div>
        </div>`));
    });
  }

  /* =============================================================== 20 ROADMAP */
  function renderRoadmap() {
    const track = $('#rmTrack');
    BAYAAN.roadmap.forEach((r, i) => {
      track.appendChild(h(`
        <div class="rm-card${i < 3 ? ' rm-card--p0' : ''}">
          <div class="rm-node"></div>
          <span class="rm-card__pri en">${i < 3 ? 'P0 · Priority' : 'P' + (Math.min(4, Math.ceil((i - 2) / 2)))}</span>
          <div class="rm-card__title">${esc(r.title)}</div>
          <div class="rm-card__en en">${esc(r.en)}</div>
          <p>${esc(r.body)}</p>
        </div>`));
    });
    initDragScroll($('#rmScroll'));
  }

  /* ================================================================= 21 FINAL */
  function renderFinal() {
    $('#finalMsg').textContent = BAYAAN.final.msg;
    $('#finalThanks').textContent = BAYAAN.final.thanks;
    $('#finalQ').textContent = BAYAAN.final.q;
    $('#finalFoot').innerHTML = `${esc(BAYAAN.team.institution[0])} · ${esc(BAYAAN.team.institution[1])}<br>${esc(BAYAAN.team.date)}`;
  }

  /* ============================================================ Card glow (mouse-follow) */
  function initCardGlow() {
    document.addEventListener('pointermove', (e) => {
      const card = e.target.closest('.card--glow');
      if (!card) return;
      const r = card.getBoundingClientRect();
      card.style.setProperty('--mx', ((e.clientX - r.left) / r.width * 100) + '%');
      card.style.setProperty('--my', ((e.clientY - r.top) / r.height * 100) + '%');
    });
  }

  /* ============================================================ Drag-to-scroll (galleries) */
  function initDragScroll(wrap) {
    if (!wrap) return;
    let isDown = false, startX = 0, startScroll = 0, moved = false;
    wrap.addEventListener('pointerdown', (e) => {
      isDown = true; moved = false; wrap.classList.add('is-dragging');
      startX = e.clientX; startScroll = wrap.scrollLeft;
      wrap.setPointerCapture(e.pointerId);
    });
    wrap.addEventListener('pointermove', (e) => {
      if (!isDown) return;
      const dx = e.clientX - startX;
      if (Math.abs(dx) > 4) moved = true;
      wrap.scrollLeft = startScroll - dx;
    });
    function up() { isDown = false; wrap.classList.remove('is-dragging'); }
    wrap.addEventListener('pointerup', up);
    wrap.addEventListener('pointerleave', up);
    wrap.addEventListener('click', (e) => { if (moved) { e.preventDefault(); e.stopPropagation(); } }, true);
    wrap.addEventListener('wheel', (e) => {
      if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) { wrap.scrollLeft += e.deltaY; e.preventDefault(); }
    }, { passive: false });
  }

  /* ============================================================ Reveal-on-scroll engine */
  function initReveal() {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => { if (en.isIntersecting) en.target.classList.add('is-in'); });
    }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
    $$('.reveal').forEach(el => io.observe(el));
    // Late-added nodes (rendered after this call in some paths) — observe on a slight delay too.
    setTimeout(() => $$('.reveal:not(.is-in)').forEach(el => io.observe(el)), 50);
  }

  /* ============================================================ Animated counters */
  function initCounters() {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => {
        if (!en.isIntersecting) return;
        io.unobserve(en.target);
        const el = en.target;
        const to = parseFloat(el.dataset.to);
        if (reduceMotion() || isNaN(to)) { el.textContent = el.dataset.to; return; }
        const dur = 1100, start = performance.now();
        function tick(now) {
          const p = Math.min(1, (now - start) / dur);
          const eased = 1 - Math.pow(1 - p, 3);
          el.textContent = Math.round(to * eased);
          if (p < 1) requestAnimationFrame(tick); else el.textContent = to;
        }
        requestAnimationFrame(tick);
      });
    }, { threshold: 0.6 });
    $$('.cnt[data-to]').forEach(el => io.observe(el));
  }

  /* ============================================================ Particle field (hero) */
  function initParticles() {
    const canvas = $('#particles');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let w, h2, dpr = Math.min(2, window.devicePixelRatio || 1), particles = [], raf = null, running = false;
    const hero = $('#hero');

    function size() {
      w = hero.clientWidth; h2 = hero.clientHeight;
      canvas.width = w * dpr; canvas.height = h2 * dpr;
      canvas.style.width = w + 'px'; canvas.style.height = h2 + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    function seed() {
      const n = Math.min(60, Math.round((w * h2) / 26000));
      particles = Array.from({ length: n }, () => ({
        x: Math.random() * w, y: Math.random() * h2,
        vx: (Math.random() - 0.5) * 0.28, vy: (Math.random() - 0.5) * 0.28, r: 1 + Math.random() * 1.6
      }));
    }
    function step() {
      ctx.clearRect(0, 0, w, h2);
      particles.forEach(p => {
        p.x += p.vx; p.y += p.vy;
        if (p.x < 0) p.x = w; if (p.x > w) p.x = 0;
        if (p.y < 0) p.y = h2; if (p.y > h2) p.y = 0;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(14, 124, 134,0.28)'; ctx.fill();
      });
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const a = particles[i], b = particles[j];
          const d = Math.hypot(a.x - b.x, a.y - b.y);
          if (d < 110) {
            ctx.strokeStyle = 'rgba(95, 163, 156,' + (0.12 * (1 - d / 110)) + ')';
            ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
          }
        }
      }
      raf = requestAnimationFrame(step);
    }
    function start() { if (running || reduceMotion()) return; running = true; raf = requestAnimationFrame(step); }
    function stop() { running = false; if (raf) cancelAnimationFrame(raf); ctx.clearRect(0, 0, w, h2); }

    size(); seed();
    window.addEventListener('resize', () => { size(); seed(); });
    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => en.isIntersecting ? start() : stop());
    }, { threshold: 0.05 });
    io.observe(hero);
  }

  /* ============================================================ Navigation system */
  function initNav() {
    const sections = BAYAAN.sections.map(s => $('#' + s.id)).filter(Boolean);
    const rail = $('#rail');
    BAYAAN.sections.forEach((s, i) => {
      const dot = h(`<button class="rail__dot" data-i="${i}" aria-label="${esc(s.label)}">
        <span class="rail__label"><b class="en">${s.short}</b>${esc(s.label)}</span>
      </button>`);
      dot.addEventListener('click', () => goTo(i));
      rail.appendChild(dot);
    });
    const dots = $$('.rail__dot', rail);
    const hudCount = $('#hudCount');
    const progFill = $('#progFill');
    let current = 0;

    function isDarkSection(sec) { return sec.classList.contains('section--dark'); }

    function setActive(i) {
      current = i;
      dots.forEach((d, idx) => d.classList.toggle('is-active', idx === i));
      hudCount.textContent = String(i + 1).padStart(2, '0') + ' / ' + String(sections.length).padStart(2, '0');
      const dark = isDarkSection(sections[i]);
      rail.classList.toggle('is-over-dark', dark);
      $('#hud').classList.toggle('is-over-dark', dark);
    }

    function goTo(i) {
      i = Math.max(0, Math.min(sections.length - 1, i));
      document.documentElement.classList.add('is-navigating');
      sections[i].scrollIntoView({ behavior: reduceMotion() ? 'auto' : 'smooth', block: 'start' });
      setActive(i);
      let settleTimer = null, lastY = window.scrollY;
      function check() {
        if (window.scrollY === lastY) {
          document.documentElement.classList.remove('is-navigating');
          window.removeEventListener('scroll', onScrollSettle);
          return;
        }
        lastY = window.scrollY;
        settleTimer = setTimeout(check, 80);
      }
      function onScrollSettle() { lastY = window.scrollY; }
      window.addEventListener('scroll', onScrollSettle, { passive: true });
      settleTimer = setTimeout(check, 260);
    }

    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => {
        if (en.isIntersecting && en.intersectionRatio > 0.5) {
          const idx = sections.indexOf(en.target);
          if (idx > -1) setActive(idx);
        }
      });
    }, { threshold: [0.5] });
    sections.forEach(sec => io.observe(sec));

    $('#btnPrev').addEventListener('click', () => goTo(current - 1));
    $('#btnNext').addEventListener('click', () => goTo(current + 1));

    document.addEventListener('keydown', (e) => {
      if ($('.help.is-open') || $('.lightbox.is-open')) {
        if (e.key === 'Escape') { closeHelp(); closeLightbox(); }
        return;
      }
      if (e.key === 'ArrowDown' || e.key === 'PageDown') { e.preventDefault(); goTo(current + 1); }
      else if (e.key === 'ArrowUp' || e.key === 'PageUp') { e.preventDefault(); goTo(current - 1); }
      else if (e.key.toLowerCase() === 'f') { toggleFullscreen(); }
      else if (e.key === '?' || (e.key.toLowerCase() === 'h' && !e.metaKey && !e.ctrlKey)) { openHelp(); }
    });

    window.addEventListener('scroll', () => {
      const doc = document.documentElement;
      const pct = (doc.scrollTop / (doc.scrollHeight - doc.clientHeight)) * 100;
      progFill.style.width = Math.min(100, Math.max(0, pct)) + '%';
    }, { passive: true });

    setActive(0);
  }

  /* ============================================================ Fullscreen */
  function toggleFullscreen() {
    const d = document, el = d.documentElement;
    const fsEl = d.fullscreenElement || d.webkitFullscreenElement;
    if (!fsEl) {
      (el.requestFullscreen || el.webkitRequestFullscreen).call(el).catch(() => {});
    } else {
      (d.exitFullscreen || d.webkitExitFullscreen).call(d).catch(() => {});
    }
  }
  function initFullscreenBtn() {
    const btn = $('#btnFs');
    btn.addEventListener('click', toggleFullscreen);
    document.addEventListener('fullscreenchange', updateFsIcon);
    document.addEventListener('webkitfullscreenchange', updateFsIcon);
    function updateFsIcon() {
      const isFs = document.fullscreenElement || document.webkitFullscreenElement;
      btn.innerHTML = icon(isFs ? 'compress' : 'expand');
    }
  }

  /* ============================================================ Help sheet */
  function openHelp() { $('#help').classList.add('is-open'); }
  function closeHelp() { $('#help').classList.remove('is-open'); }
  function initHelp() {
    $('#btnHelp').addEventListener('click', openHelp);
    $('#help').addEventListener('click', (e) => { if (e.target.id === 'help') closeHelp(); });
  }

  /* ============================================================ Lightbox (reserved for future diagram zoom) */
  function closeLightbox() { $('#lightbox').classList.remove('is-open'); }
  function initLightbox() {
    $('#lbClose').addEventListener('click', closeLightbox);
    $('#lightbox').addEventListener('click', (e) => { if (e.target.id === 'lightbox') closeLightbox(); });
  }

  /* ============================================================ Boot */
  function boot() {
    renderHero(); renderTeam(); renderProblem(); renderWhy(); renderAudience();
    renderMarket(); renderGap(); renderSolution(); renderCurriculum(); renderJourney();
    renderApp(); renderAI(); renderGamify(); renderArchitecture(); renderStack();
    renderSecurity(); renderTesting(); renderAchieved(); renderLimits(); renderRoadmap(); renderFinal();

    initNav(); initCardGlow(); initReveal(); initCounters(); initParticles();
    initFullscreenBtn(); initHelp(); initLightbox();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
