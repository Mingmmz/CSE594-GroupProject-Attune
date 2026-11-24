import { CONTEXT, DEMO_END, DEMO_START, SCENARIO_KEYS, SCENARIOS } from './scenarios.mjs';
import {
  changeAdjustment, coaching, defaultDraft, effectiveEnd, estimate, formatDate, freshState,
  fromDraft, matching, measurementConflict, recorded, repeatedReason, shiftDate, status, withAdjustment,
} from './model.mjs';

const app = document.querySelector('#app');
const announcement = document.querySelector('#announcement');
const storageKey = 'attune.stage3.v1';
let state = freshState();
let storageAvailable = true;
try {
  const saved = JSON.parse(localStorage.getItem(storageKey));
  if (saved && SCENARIOS[saved.scenario] && Array.isArray(saved.adjustments) && saved.drafts && saved.dismissed) state = { ...freshState(), ...saved };
} catch {
  storageAvailable = false;
}
let view = { name: 'summary' };
let recordDate = '';
let mobileDemoOpen = false;
const formatNumber = new Intl.NumberFormat('en-US');
const glyphs = {
  pulse: '<path d="M3 14c4 0 4-7 8-7s4 7 8 7c1.3 0 2.2-1 3-2"/><circle cx="20.5" cy="6" r="1" fill="currentColor" stroke="none"/>',
  moon: '<path d="M21 13.2A8.6 8.6 0 1 1 10.8 3a7 7 0 0 0 10.2 10.2Z"/>',
  activity: '<path d="M2 13h5l3-7 4 13 3-6h5"/>',
  cycle: '<path d="M20 8a8 8 0 0 0-14.2-2L4 8m0-4v4h4m-4 8a8 8 0 0 0 14.2 2L20 16m0 4v-4h-4"/>',
  sliders: '<path d="M5 3v7m0 4v7m7-18v12m0 4v2m7-18v3m0 4v11M2 10h6m1 5h6m1-9h6"/>',
  arrow: '<path d="M4 12h15m-6-6 6 6-6 6"/>',
  back: '<path d="M20 12H5m6-6-6 6 6 6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  sparkle: '<path d="M12 2c1.5 6 4 8.5 10 10-6 1.5-8.5 4-10 10C10.5 16 8 13.5 2 12c6-1.5 8.5-4 10-10Z"/>',
  date: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4m8-4v4"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 4v3"/>',
  reset: '<path d="M3 11a9 9 0 1 1 2.5 7M3 5v6h6"/>',
  edit: '<path d="m4 15-1 6 6-1L20 9l-5-5L4 15Zm9-9 5 5"/>',
  circle: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5m0-8v.2"/>',
  heart: '<path d="M12 21s-8.5-5.2-8.5-11a4.5 4.5 0 0 1 8.5-2.1 4.5 4.5 0 0 1 8.5 2.1c0 5.8-8.5 11-8.5 11Z" fill="currentColor" stroke="none"/>',
  bed: '<path d="M3 19V7m18 12v-6a2 2 0 0 0-2-2H3m0 5h18M7 11V8h4a2 2 0 0 1 2 2v1"/>',
  rings: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.5"/><circle cx="12" cy="12" r="2"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  chevron: '<path d="m9 6 6 6-6 6"/>',
  steps: '<path d="M6 13a3 3 0 0 0 4-2l1-4a3 3 0 0 0-6-1l-1 4a3 3 0 0 0 2 3Zm10 5a3 3 0 0 0 4-2l1-4a3 3 0 0 0-6-1l-1 4a3 3 0 0 0 2 3ZM6 17v2m10 2v1"/>',
  droplet: '<path d="M12 3c3 4 6.5 7.6 6.5 11.3a6.5 6.5 0 0 1-13 0C5.5 10.6 9 7 12 3Z"/>',
};

const icon = (name, size = 19) => '<svg aria-hidden="true" viewBox="0 0 24 24" width="' + size + '" height="' + size + '" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + glyphs[name] + '</svg>';
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const number = (value) => value === null ? '—' : formatNumber.format(value);
const cfg = (scenario = state.scenario) => SCENARIOS[scenario];
const countLabel = (count, scenario) => count + ' ' + cfg(scenario)[count === 1 ? 'singular' : 'plural'];
const unit = (scenario) => ({ cycle: 'days', sleep: 'points', activity: 'steps' })[scenario];
const dates = (start, end) => start === end ? formatDate(start) : formatDate(start) + ' – ' + formatDate(end);
const rawName = (scenario) => ({ sleep: 'Original sleep scores', activity: 'Original step counts', cycle: 'Original period start dates' })[scenario];
const find = (id) => state.adjustments.find((a) => a.id === id);
const categoryIcon = { sleep: 'bed', activity: 'steps', cycle: 'droplet' };

function save() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(state));
  } catch {
    storageAvailable = false;
  }
}

function tell(message) {
  announcement.textContent = message;
}

function go(name, data = {}) {
  if (name !== view.name) mobileDemoOpen = false;
  view = { name, ...data };
  render();
  document.querySelector('#page-title')?.focus();
  window.scrollTo(0, 0);
}

function currentDraft() {
  const key = view.id || state.scenario;
  return state.drafts[key] ?? defaultDraft(state.scenario, state.today);
}

function putDraft(patch) {
  state.drafts[view.id || state.scenario] = { ...currentDraft(), ...patch };
  save();
}

function shell(body) {
  const managing = ['manage', 'detail'].includes(view.name) || !!view.id && ['context', 'proposal'].includes(view.name);
  const currentCount = state.adjustments.filter((a) => status(a, state.today) === 'Active').length;
  const onSummary = view.name === 'summary';
  const onBrowse = view.name === 'browse' || !managing && !onSummary;
  const controls = '<div class="demo-date">' + icon('date', 15) + '<span>Demo day: <strong>' + formatDate(state.today) + '</strong></span></div>'
    + '<button class="rail-button" data-action="advance"' + (state.today >= DEMO_END ? ' disabled' : '') + '>Advance one day ' + icon('arrow', 15) + '</button>'
    + '<button class="rail-button reset" data-action="dialog" data-key="reset">' + icon('reset', 14) + ' Reset demo</button>';
  const navButton = (name, symbol, action, selected) => '<button class="nav-link' + (selected ? ' selected' : '') + '" data-action="' + action + '"' + (selected ? ' aria-current="page"' : '') + '>' + icon(symbol) + '<span>' + name + '</span></button>';
  return '<div class="shell">'
    + '<aside class="rail"><button class="brand" data-action="home" aria-label="ATTUNE home"><span class="brand-mark">' + icon('pulse', 23) + '</span><span>Attune</span></button>'
    + '<nav aria-label="Attune navigation">' + navButton('Summary', 'heart', 'home', onSummary)
    + '<p class="rail-label">Health Categories</p>' + SCENARIO_KEYS.map((key) => {
      const here = onBrowse && view.name !== 'browse' && state.scenario === key;
      return '<button class="nav-link ' + (here ? 'selected' : '') + '" data-action="scenario" data-key="' + key + '"' +
        (here ? ' aria-current="page"' : '') + '><span class="category-glyph ' + key + '">' + icon(categoryIcon[key], 17) + '</span><span>' + (key === 'cycle' ? 'Cycle Tracking' : cfg(key).name) + '</span></button>';
    }).join('')
    + '<p class="rail-label second-label">Attune</p><button class="nav-link ' + (managing ? 'selected' : '') + '" data-action="manage"' + (managing ? ' aria-current="page"' : '') + '>'
    + icon('sliders') + '<span>Adjustments</span>' + (currentCount ? '<small class="nav-count">' + currentCount + '</small>' : '') + '</button></nav>'
    + '<div class="rail-foot"><div class="demo-label">Study Prototype</div>' + controls + '</div></aside>'
    + '<div class="workspace"><div class="topbar"><span class="top-name">Attune</span><span class="sample">Fictional Data</span>'
    + '<details class="mobile-demo"' + (mobileDemoOpen ? ' open' : '') + '><summary>' + icon('date', 16) + '<span>' + formatDate(state.today) + '</span></summary>'
    + '<div class="mobile-demo-pop"><div class="demo-label">Demo Controls</div>' + controls + '</div></details></div>'
    + '<main id="main" class="' + (onSummary ? 'summary-view' : '') + '" tabindex="-1">' + body + '</main><footer><span>Attune · Study Prototype</span><span>' +
      (storageAvailable ? 'Changes stay in this browser' : 'Browser storage unavailable; changes last for this page') + '</span></footer></div>'
    + '<nav class="tab-bar" aria-label="Attune tabs">' + navButton('Summary', 'heart', 'home', onSummary) + navButton('Browse', 'grid', 'browse', onBrowse)
    + navButton('Adjustments', 'sliders', 'manage', managing) + '</nav>'
    + '<dialog id="confirm-dialog" aria-labelledby="dialog-title"></dialog></div>';
}

function header(kicker, title, description, back, steps) {
  return '<header class="page-header">' + (back ? '<button class="text-button back" data-action="' + back[0] + '">' + icon('back', 16) + ' ' + back[1] + '</button>' : '')
    + (steps ? '<ol class="steps" aria-label="Correction progress">' + ['Add context', 'Review changes', 'Verify result'].map((label, index) => '<li'
      + (index + 1 === steps ? ' aria-current="step"' : '') + ' class="' + (index + 1 < steps ? 'done' : '') + '"><span>' +
      (index + 1 < steps ? icon('check', 12) : index + 1) + '</span>' + label + '</li>').join('') + '</ol>' : '')
    + '<p class="eyebrow">' + kicker + '</p><h1 id="page-title" tabindex="-1">' + title + '</h1><p class="subhead">' + description + '</p></header>';
}

function asideMessage(title, copy, glyph = 'circle') {
  return '<div class="aside-message">' + icon(glyph, 20) + '<div><strong>' + title + '</strong><p>' + copy + '</p></div></div>';
}

function rawValue(record, scenario) {
  if (scenario === 'cycle') return record.value === null ? 'Period start' : record.value + '-day interval';
  return number(record.value) + (scenario === 'activity' ? ' steps' : ' / 100');
}

function estimateValue(e, scenario) {
  return e.value === null ? 'Insufficient data' : number(e.value) + (scenario === 'cycle' ? ' days' : scenario === 'activity' ? ' steps' : '');
}

function timeline(scenario, start, end, adjust, label = 'In selected range', options = {}) {
  const config = cfg(scenario);
  const all = config.records;
  const candidates = scenario === 'cycle' ? [...new Set([...all.map((r) => r.date), start, end])].sort() : all.map((r) => r.date);
  const scope = candidates.filter((date) => date >= start && date <= end);
  let display = candidates;
  if (display.length > 8) {
    const first = candidates.indexOf(scope[0]);
    const last = candidates.indexOf(scope.at(-1));
    let begin = first === -1 ? candidates.indexOf(state.today) - 3 : Math.max(0, first - 2);
    let finish = first === -1 ? begin + 7 : Math.min(candidates.length, last + 3);
    if (finish - begin < 6) begin = Math.max(0, finish - 6);
    display = candidates.slice(begin, finish);
  }
  const existing = scope.filter((date) => (!options.endedOn || date <= options.endedOn) && date <= state.today && all.some((r) => r.date === date)).length;
  return '<div class="timeline" aria-label="Records in date range">' + display.map((date) => {
    const r = all.find((row) => row.date === date);
    const inRange = date >= start && date <= end;
    const future = date > state.today;
    const overlaps = adjust && matching(state.adjustments, scenario, date).filter((a) => a.id !== adjust.id);
    const still = overlaps?.length && overlaps.some((a) => a.mode === 'context');
    const raw = r && !future ? rawValue(r, scenario) : scenario === 'cycle' ? 'No log' : 'Upcoming';
    const restored = inRange && (options.undone || options.endedOn && date > options.endedOn);
    const tag = restored ? (still ? 'Other adjustment' : 'Counts again') : inRange ? label : still ? 'Other adjustment' : 'Outside range';
    return '<div class="timeline-cell' + (restored ? ' restored' : inRange ? ' affected' : '') + (future ? ' future' : '') + '"><strong>' + formatDate(date) + '</strong><span>' + raw + '</span><small>' + tag + '</small></div>';
  }).join('') + '</div>' + (options.undone ? '' : '<p class="helper">' + countLabel(existing, scenario) + ' already recorded in ' +
    (options.endedOn ? 'the retained range.' : 'this range. Future records in the range will use the same setting if they are logged.') + '</p>');
}

function miniChart(scenario, rows, showSleepMinutes = true) {
  const bars = rows.filter((r) => r.value !== null).slice(-7);
  const useMinutes = scenario === 'sleep' && showSleepMinutes;
  const max = useMinutes ? 480 : cfg(scenario).max;
  return '<span class="mini-chart" aria-hidden="true">' + bars.map((r, i) => '<i' + (i === bars.length - 1 ? ' class="latest"' : '') + ' style="--size:'
    + Math.max(7, Math.min(100, Math.round(100 * (useMinutes ? r.minutes : r.value) / max))) + '%"></i>').join('') + '</span>';
}

function summary() {
  const sleepRows = recorded('sleep', state.today);
  const stepRows = recorded('activity', state.today);
  const cycleRows = recorded('cycle', state.today);
  const [sleep, steps, cycle] = [sleepRows.at(-1), stepRows.at(-1), cycleRows.at(-1)];
  const baseline = estimate('sleep', state.today, state.adjustments);
  const changed = baseline.included < baseline.total;
  const progress = Math.round(steps.value / 8000 * 100);
  const summaries = {
    sleep: ['Time Asleep', Math.floor(sleep.minutes / 60) + ' <small>hr</small> ' + sleep.minutes % 60 + ' <small>min</small>',
      'Sleep score ' + sleep.value + ' / 100', sleepRows, sleep.date],
    activity: ['Steps', number(steps.value) + ' <small>steps</small>', 'Daily goal: 8,000 steps', stepRows, steps.date],
    cycle: ['Cycle Length', cycle.value + ' <small>days</small>', 'Latest logged interval', cycleRows, cycle.date],
  };
  const pinned = state.pins.filter((key) => SCENARIO_KEYS.includes(key)).map((key) => {
    const [label, value, note, rows, date] = summaries[key];
    return '<button class="summary-card pin-card ' + key + '" data-action="scenario" data-key="' + key + '">'
      + '<span class="pin-top"><span class="pin-label">' + icon(categoryIcon[key], 19) + label + '</span>'
      + '<span class="pin-date">' + formatDate(date) + icon('chevron', 15) + '</span></span>'
      + '<span class="pin-content"><span><strong>' + value + '</strong><span class="pin-note">' + note + '</span></span>'
      + miniChart(key, rows) + '</span></button>';
  }).join('');
  const lastAdjustment = state.adjustments.at(-1);
  const draft = SCENARIO_KEYS.find((key) => state.drafts[key]);
  return '<header class="summary-header"><div><p class="summary-date">' + formatDate(state.today, { weekday: 'long', month: 'long', day: 'numeric' })
    + '</p><h1 id="page-title" tabindex="-1">Summary</h1></div><span class="summary-mark" aria-hidden="true">' + icon('pulse', 26) + '</span></header>'
    + '<div class="summary-grid"><section class="summary-group" aria-labelledby="pinned-title"><div class="group-heading"><h2 id="pinned-title">Pinned</h2>'
    + '<button class="text-button" data-action="dialog" data-key="pins" aria-label="Edit pinned categories">Edit</button></div>'
    + '<div class="summary-stack">' + (pinned || '<p class="summary-card summary-empty">Choose Edit to pin the health information you want to see here.</p>') + '</div></section>'
    + '<section class="summary-group" aria-labelledby="highlight-title"><div class="group-heading"><h2 id="highlight-title">Highlights</h2></div><div class="summary-stack">'
    + '<button class="summary-card highlight-card sleep" data-action="scenario" data-key="sleep"><span class="pin-top"><span class="pin-label">' + icon(categoryIcon.sleep, 19)
    + 'Sleep</span>' + icon('chevron', 15) + '</span><strong>' + (changed ? 'Your usual sleep score was updated' : 'Your recent sleep scores') + '</strong>'
    + '<span class="highlight-copy">' + (changed ? (baseline.value === null ? 'No scores are currently included in your usual estimate.' : 'Your usual score is now ' + baseline.value + '. The logged scores remain available.')
      : 'Your latest score was ' + sleep.value + '. Your usual score is ' + baseline.value + ' across ' + countLabel(baseline.included, 'sleep') + '.') + '</span>'
    + '<span class="sleep-highlight-plot"><span>Scores across 7 nights</span>' + miniChart('sleep', sleepRows, false) + '</span></button>'
    + '<button class="summary-card highlight-card activity" data-action="scenario" data-key="activity"><span class="pin-top"><span class="pin-label">' + icon('rings', 19)
    + 'Activity</span>' + icon('chevron', 15) + '</span><span class="step-highlight"><svg class="progress-ring" width="74" height="74" viewBox="0 0 74 74" aria-hidden="true">'
    + '<circle class="ring-track" cx="37" cy="37" r="29"/><circle class="ring-fill" cx="37" cy="37" r="29" pathLength="100" stroke-dasharray="'
    + Math.min(100, progress) + ' 100" transform="rotate(-90 37 37)"/><path d="M29 37h16m-6-6 6 6-6 6"/></svg>'
    + '<span><strong>' + progress + '% of your step goal</strong><span class="highlight-copy">' + number(steps.value) + ' of 8,000 steps logged</span></span></span></button>'
    + '</div></section></div>'
    + '<section class="summary-group recent" aria-labelledby="history-title"><div class="group-heading"><h2 id="history-title">Adjustments</h2>'
    + '<button class="text-button" data-action="manage">Show All</button></div><div class="summary-list">'
    + (draft ? summaryRow(draft, 'Resume ' + cfg(draft).name.toLowerCase() + ' draft', 'Continue your unfinished adjustment', 'resume', draft) : '')
    + (lastAdjustment ? summaryRow(lastAdjustment.scenario, CONTEXT[lastAdjustment.reason].name,
      dates(lastAdjustment.start, effectiveEnd(lastAdjustment)) + ' · ' + status(lastAdjustment, state.today), 'detail', lastAdjustment.id)
      : '<p class="summary-empty">Your saved adjustments will appear here.</p>') + '</div></section>';
}

function summaryRow(scenario, title, description, action, key) {
  return '<button class="summary-row" data-action="' + action + '" data-key="' + key + '"><span class="category-glyph ' + scenario + '">'
    + icon(categoryIcon[scenario], 20) + '</span><span><strong>' + esc(title) + '</strong><small>' + esc(description) + '</small></span>'
    + icon('chevron', 15) + '</button>';
}

function browse() {
  return header('', 'Browse', 'Health Categories')
    + '<div class="summary-list">' + SCENARIO_KEYS.map((key) => summaryRow(key, key === 'cycle' ? 'Cycle Tracking' : cfg(key).name,
      { sleep: 'Time asleep, scores, and trends', activity: 'Daily steps, goals, and trends', cycle: 'Logged dates and cycle length' }[key],
      'scenario', key)).join('') + '</div>';
}

function tracking() {
  const scenario = state.scenario;
  const config = cfg();
  const rows = recorded(scenario, state.today);
  const latest = rows.at(-1);
  const selected = rows.find((r) => r.date === recordDate) ?? latest;
  const skippedInsight = state.skipped[scenario] === selected.date;
  const adjusted = matching(state.adjustments, scenario, selected.date);
  const latestSettings = coaching(scenario, state.today, state.adjustments);
  const reading = coaching(scenario, selected.date, state.adjustments);
  const base = estimate(scenario, state.today, state.adjustments);
  const before = estimate(scenario, state.today, []);
  const skipped = base.total - base.included;
  const barRows = rows.slice(-7);
  return header(icon(categoryIcon[scenario], 17) + ' ' + config.name.toUpperCase() + ' OVERVIEW',
    scenario === 'cycle' ? 'Cycle Tracking' : config.name, config.intro, ['home', 'Summary'])
    + '<div class="dashboard ' + scenario + '">'
    + '<section class="hero panel"><div class="section-top"><span class="micro">' + config.metric + '</span><span class="pill soft">' + formatDate(selected.date, { weekday: 'short', month: 'short', day: 'numeric' }) + '</span></div>'
    + '<div class="metric">' + number(selected.value) + '<span>' + (selected.value !== null ? config.suffix : 'first log') + '</span></div>'
    + '<div class="metric-caption"><span class="point"></span>' + config.source + ' <span class="divider-dot">·</span> ' + (selected.date === latest.date ? 'Latest record' : 'Past record') + '</div>'
    + (selected.detail ? '<p class="raw-detail">' + esc(selected.detail) + '</p>'
      : selected.minutes ? '<p class="raw-detail">' + Math.floor(selected.minutes / 60) + 'h ' + String(selected.minutes % 60).padStart(2, '0') + 'm asleep</p>' : '')
    + (skippedInsight ? '<div class="interpretation"><div><strong>Insight skipped</strong><p>Your records and usual pattern are unchanged.</p><button class="text-button" data-action="restore-insight">Show insight</button></div></div>'
      : '<div class="interpretation"><div class="mini-icon">' + icon('sparkle', 16) + '</div><div><strong>AI interpretation <span class="inline-flag">SIMULATED</span></strong><p>' + esc(reading.interpretation) + '</p></div></div>')
    + (adjusted.length ? '<p class="applied-note">' + icon('check', 15) + ' ' + adjusted.map((a) => esc(CONTEXT[a.reason].name)).join(' · ') + '</p>' : '')
    + '<div class="actions"><button class="button primary" data-action="new">' + (state.drafts[scenario] ? 'Resume correction draft' : 'Add context') + ' ' + icon('arrow', 17) + '</button>'
    + (!adjusted.length && !skippedInsight ? '<button class="text-button" data-action="skip-insight" data-key="' + selected.date + '">Skip this adjustment</button>' : '') + '</div></section>'
    + '<section class="panel pattern"><div class="section-top"><span class="micro">Your usual pattern</span>' + icon('activity', 20) + '</div><h2>' + config.baseline + '</h2>'
    + '<div class="pattern-value">' + number(base.value) + ' <span>' + unit(scenario) + '</span></div>'
    + '<p>' + (base.value === null ? 'No included values yet.' : 'Average of ' + countLabel(base.included, scenario) + ' in this demo.') + '</p>'
    + (skipped ? '<div class="insight-note"><strong>' + estimateValue(before, scenario) + ' using all records</strong><br>' + countLabel(skipped, scenario) + ' set aside from this average.</div>'
      : '<div class="insight-note">The average uses all logged values. You can set aside an unusual period when you add context.</div>')
    + '<button class="text-button" data-action="manage">Manage adjustments ' + icon('arrow', 15) + '</button></section>'
    + '<section class="panel records"><div class="section-top"><div><p class="eyebrow">RECORDED DATA</p><h2>' + config.chartTitle + '</h2></div><span class="pill soft">' + formatDate(barRows[0].date) + ' – ' + formatDate(barRows.at(-1).date) + '</span></div>'
    + '<p class="helper">Select a record to see its interpretation.</p><div class="chart" aria-label="' + config.chartTitle + '">' + barRows.map((r) => {
      const excluded = matching(state.adjustments, scenario, r.date).some((a) => a.mode === 'context');
      return '<button class="bar-item' + (r.date === selected.date ? ' current' : '') + (excluded ? ' excluded' : '') + '" data-action="record" data-key="' + r.date + '" aria-pressed="' + (r.date === selected.date)
        + '" aria-label="' + formatDate(r.date) + ': ' + rawValue(r, scenario) + (excluded ? ', excluded from average' : ', counts toward average') + '">'
        + '<span class="bar-val">' + number(r.value) + '</span><span class="bar-track"><span class="bar-fill" style="--height:' + Math.max(5, Math.min(100, (r.value ?? 0) / config.max * 100)) + '%"></span></span><span class="bar-label">' + formatDate(r.date) + '</span></button>';
    }).join('') + '</div><div class="legend"><span><i></i> Counts toward average when a value is available</span><span><i class="legend-excluded"></i> Set aside</span></div></section>'
    + '<section class="panel coach"><span class="round-icon">' + icon('sparkle', 23) + '</span><p class="eyebrow">FOR YOUR NEXT CHECK-IN</p><h2>Coaching & reminders</h2>'
    + '<p>' + esc(latestSettings.tip) + '</p><div class="reminder"><span>' + config.reminder + '</span><span class="pill ' + (latestSettings.paused ? 'gold' : 'soft') + '">' + (latestSettings.paused ? 'Paused' : 'On') + '</span></div>'
    + '<button class="text-button" data-action="new">Adjust this advice ' + icon('arrow', 15) + '</button></section></div>';
}

function dateError(draft, existing) {
  const earliest = cfg(draft.scenario).records[0].date;
  if (!draft.start || !draft.end) return 'Choose both a start and an end date.';
  if (draft.start < earliest) return 'Choose a start date on or after ' + formatDate(earliest) + '.';
  if (draft.start > draft.end) return 'The end date must be on or after the start date.';
  if (existing?.endedOn && draft.start > existing.endedOn) return 'This adjustment ended on ' + formatDate(existing.endedOn) + '. Choose an earlier start date.';
  return '';
}

function context() {
  const draft = currentDraft();
  const config = cfg(draft.scenario);
  return header(icon(config.icon, 16) + ' ' + config.name.toUpperCase() + ' CORRECTION', view.id ? 'Edit your adjustment' : 'What was different?',
    'Share the circumstances and choose which dates they apply to.', view.id ? ['detail-back', 'Adjustment details'] : ['home', 'Back to Home'], 1)
    + '<form id="context-form" class="flow-grid" novalidate><div class="flow-stack"><section class="panel flow-card">'
    + '<div class="title-line"><span class="step-number">01</span><h2>Your explanation</h2></div><p class="helper">Start with an example, or describe what happened in your own words.</p>'
    + '<div class="templates">' + config.options.map(([key, name]) => '<button type="button" class="template' + (draft.reason === key ? ' chosen' : '') + '" data-action="template" data-key="' + key + '">' + esc(name) + '</button>').join('') + '</div>'
    + '<label class="field-label" for="explanation">Context</label><textarea id="explanation" name="explanation" rows="4" maxlength="500" placeholder="' + esc(config.placeholder) + '">' + esc(draft.explanation) + '</textarea>'
    + '<label class="check-row"><input type="checkbox" name="storeNote"' + (draft.storeNote ? ' checked' : '') + '><span>Retain my exact wording after I apply the correction <small>Optional. You can clear this later by editing the adjustment.</small></span></label></section>'
    + '<section class="panel flow-card"><div class="title-line"><span class="step-number">02</span><h2>Affected dates</h2></div><p class="helper">The start and end dates are both included.</p>'
    + '<div class="date-fields"><label>Start date<input type="date" name="start" required min="' + config.records[0].date + '" value="' + esc(draft.start) + '"></label>'
    + '<label>End date<input type="date" name="end" required min="' + config.records[0].date + '" value="' + esc(draft.end) + '"></label></div>'
    + '<div id="scope-preview">' + scopePreview(draft) + '</div>'
    + '<label class="check-row"><input type="checkbox" name="pause"' + (draft.pause ? ' checked' : '') + '><span>Pause the ' + config.reminder.toLowerCase() + ' during this range</span></label></section>'
    + '<p id="form-error" class="error" role="alert"></p><div class="actions"><button class="button primary" type="submit">See AI-suggested changes ' + icon('arrow', 17) + '</button>'
    + '<button class="button secondary" type="button" data-action="' + (view.id ? 'detail-back' : 'tracking-back') + '">Save draft & exit</button></div></div>'
    + '<div class="flow-stack"><section class="panel side-card"><p class="eyebrow">A LITTLE GUIDANCE</p><h2>Start with what happened.</h2><p>Describe the situation instead of changing the numbers. Before applying, you’ll see what the assistant understood and how the results would change.</p>'
    + asideMessage('Your dates, your decision', 'The example proposes a range. You can change either date.', 'date')
    + asideMessage('Drafts stay here', 'While you work, the draft, including typed context, is saved in this browser. Applying clears the draft. You can also discard it now.', 'lock')
    + '<button type="button" class="text-button" data-action="discard">Discard draft</button></section></div></form>';
}

function scopePreview(draft) {
  const error = dateError(draft, find(view.id));
  if (error) return '<p class="helper" role="status">' + esc(error) + '</p>';
  const end = effectiveEnd({ end: draft.end, endedOn: find(view.id)?.endedOn });
  return timeline(draft.scenario, draft.start, end, null);
}

function comparison(scenario, beforeList, afterList, date) {
  const before = estimate(scenario, state.today, beforeList);
  const after = estimate(scenario, state.today, afterList);
  const previous = coaching(scenario, date, beforeList);
  const next = coaching(scenario, date, afterList);
  return '<div class="comparison"><div class="compare-before"><span class="micro">Before</span><strong>' + estimateValue(before, scenario) + '</strong><small>' + countLabel(before.included, scenario) + ' in the average</small></div>'
    + '<div class="comparison-arrow">' + icon('arrow', 17) + '</div><div class="compare-after"><span class="micro">After</span><strong>' + estimateValue(after, scenario) + '</strong><small>' + countLabel(after.included, scenario) + ' in the average</small></div></div>'
    + '<div class="text-comparison"><p><strong>Before:</strong> ' + esc(previous.interpretation) + '</p><p><strong>After:</strong> ' + esc(next.interpretation) + '</p></div>'
    + '<div class="coaching-preview"><span class="micro">Coaching during the selected period</span><p>' + esc(next.tip) + '</p>'
    + '<p class="helper">' + cfg(scenario).reminder + ': <strong>' + (previous.paused ? 'paused' : 'on') + ' → ' + (next.paused ? 'paused' : 'on') + '</strong>.</p></div>';
}

function proposal() {
  const draft = currentDraft();
  const existing = find(view.id);
  const proposed = fromDraft(draft, view.id || 'preview', existing);
  const list = withAdjustment(state.adjustments, proposed);
  const config = cfg(draft.scenario);
  const end = effectiveEnd(proposed);
  const checkKey = draft.scenario + ':' + proposed.reason;
  const recurring = !state.dismissed.includes(checkKey) && repeatedReason(state.adjustments, proposed);
  const covered = recorded(draft.scenario, state.today).filter((r) => r.date >= proposed.start && r.date <= end);
  const comparisonDay = covered.at(-1)?.date ?? proposed.start;
  const conflict = measurementConflict(draft.scenario, draft.explanation, covered.length === 1 ? covered[0] : null);
  const other = list.filter((a) => a.id !== proposed.id && a.scenario === proposed.scenario && !a.undone && a.start <= end && effectiveEnd(a) >= proposed.start);
  return header(icon(config.icon, 16) + ' ' + config.name.toUpperCase() + ' CORRECTION', 'Review suggested changes',
    'Check the interpretation, the affected records, and when the change ends.', ['context-back', 'Edit context or dates'], 2)
    + '<div class="flow-grid"><div class="flow-stack"><section class="panel flow-card"><div class="section-top"><span class="micro">What the assistant understood</span><span class="pill lavender">Simulated AI</span></div>'
    + '<h2 class="reason-title">' + esc(CONTEXT[proposed.reason].name) + '</h2>'
    + (draft.explanation.trim() ? '<p class="quote">“' + esc(draft.explanation.trim()) + '”</p>' : '')
    + '<p class="helper">' + esc(CONTEXT[proposed.reason].during) + ' The records alone cannot verify the cause.</p>'
    + (conflict ? asideMessage('Check the recorded value', 'Your note says ' + esc(conflict.claimed) + '. The ' + formatDate(conflict.date)
      + ' log shows ' + rawValue(covered[0], draft.scenario) + '. You can edit your note or apply the context while keeping the original log.') : '')
    + '<button class="text-button" data-action="context-back">' + icon('edit', 15) + ' Edit my explanation</button>'
    + (recurring || draft.mode === 'routine' ? '<div class="routine"><strong>Has this become part of your routine?</strong><p>Similar context appeared on separate occasions. You choose how to count this period.</p><div class="templates">'
      + '<button class="template' + (draft.mode === 'context' ? ' chosen' : '') + '" aria-pressed="' + (draft.mode === 'context') + '" data-action="mode" data-key="context">Keep this temporary</button>'
      + '<button class="template' + (draft.mode === 'routine' ? ' chosen' : '') + '" aria-pressed="' + (draft.mode === 'routine') + '" data-action="mode" data-key="routine">Count in usual pattern</button>'
      + (recurring && draft.mode === 'context' ? '<button class="text-button" data-action="dismiss" data-key="' + checkKey + '">Dismiss</button>' : '') + '</div></div>' : '')
    + '</section><section class="panel flow-card"><p class="eyebrow">BEFORE AND AFTER</p><h2>' + config.baseline + '</h2>'
    + comparison(draft.scenario, state.adjustments, list, comparisonDay) + '</section>'
    + '<section class="panel flow-card"><div class="section-top"><h2>Affected records</h2><span class="pill lavender">' + dates(proposed.start, end) + '</span></div>'
    + '<p class="helper">Includes ' + formatDate(end) + '. This change stops before ' + formatDate(shiftDate(end, 1)) + '.</p>'
    + timeline(proposed.scenario, proposed.start, end, proposed, draft.mode === 'context' ? 'Set aside' : 'Keep in average')
    + (!covered.length ? asideMessage('No logged records in this range yet', 'The current average does not change. Previewed coaching applies if a record is added within these dates.') : '')
    + (other.length ? asideMessage('Other adjustments overlap', 'These reasons remain independent: ' + other.map((a) => esc(CONTEXT[a.reason].name) + ' (' + dates(a.start, effectiveEnd(a)) + ')').join(', ') + '.') : '')
    + '</section><div class="actions"><button class="button primary" data-action="apply">' + (view.id ? 'Save adjustment changes' : 'Apply adjustment') + ' ' + icon('check', 18) + '</button>'
    + '<button class="button secondary" data-action="context-back">Edit proposal</button></div></div>'
    + '<div class="flow-stack"><section class="panel side-card"><p class="eyebrow">AT A GLANCE</p><h2>What changes / stays</h2>'
    + asideMessage('Changes', (draft.mode === 'context' ? 'The usual-pattern average sets aside values in the selected period. Coaching uses your context.' : 'Your reason is saved and the selected values keep counting toward your usual pattern.') + (draft.pause ? ' The selected reminder is paused during the period.' : ''), 'sparkle')
    + asideMessage('Stays', rawName(draft.scenario) + ' and all raw records remain visible.', 'check')
    + asideMessage('What will be saved?', 'This browser keeps the category, dates, reminder preference and adjustment history. ' + (draft.storeNote ? 'Your exact wording is included.' : 'Your exact wording is cleared when you apply.'), 'lock')
    + '</section></div></div>';
}

function receipt() {
  const a = find(view.appliedId);
  const config = cfg(a.scenario);
  const end = effectiveEnd(a);
  const day = recorded(a.scenario, state.today).filter((r) => r.date >= a.start && r.date <= end).at(-1)?.date ?? a.start;
  return header(icon('check', 16) + ' SAVED TO THIS BROWSER', 'Adjustment saved',
    'Verify the change below. You can revisit this adjustment whenever your situation changes.', ['home', 'Back to Home'], 3)
    + '<div class="flow-grid"><div class="flow-stack"><section class="panel flow-card"><div class="section-top"><p class="eyebrow">CORRECTION RECEIPT</p><span class="pill lavender">' + esc(status(a, state.today)) + '</span></div>'
    + '<h2>' + config.baseline + '</h2>' + comparison(a.scenario, view.before, state.adjustments, day) + '</section>'
    + '<section class="panel flow-card"><h2>Applied to ' + dates(a.start, end) + '</h2><p class="helper">' + formatDate(end) + ' is included. The adjustment stops before ' + formatDate(shiftDate(end, 1)) + '.</p>'
    + timeline(a.scenario, a.start, end, a, a.mode === 'context' ? 'Set aside' : 'Keep in average') + '</section>'
    + '<div class="actions"><button class="button primary" data-action="home">Back to Home ' + icon('arrow', 17) + '</button><button class="button secondary" data-action="detail" data-key="' + a.id + '">View adjustment</button></div></div>'
    + '<div class="flow-stack"><section class="panel side-card"><p class="eyebrow">VERIFIED</p><h2>Your records are intact.</h2>'
    + asideMessage(rawName(a.scenario), a.scenario === 'sleep' && a.start <= DEMO_START && end >= DEMO_START
      ? 'Nov 10: 5h 02m asleep · 2:10 a.m. bedtime · Score 62.'
      : 'The recorded values are the same. The comparison shows how the assistant now reads them.', 'check')
    + asideMessage('Saved context', esc(CONTEXT[a.reason].name) + '. ' + (a.note ? 'Your exact wording was retained.' : 'Your exact wording was cleared.'), 'lock') + '</section></div></div>';
}

function manage() {
  const current = state.adjustments.filter((a) => ['Active', 'Scheduled'].includes(status(a, state.today))).reverse();
  const history = state.adjustments.filter((a) => !['Active', 'Scheduled'].includes(status(a, state.today))).reverse();
  function entries(list, empty) {
    return list.length ? '<div class="entry-list">' + list.map((a) => '<button class="entry" data-action="detail" data-key="' + a.id + '"><span class="round-icon">'
      + icon(cfg(a.scenario).icon, 21) + '</span><span><strong>' + esc(CONTEXT[a.reason].name) + '</strong><small>' + cfg(a.scenario).name + ' · '
      + dates(a.start, effectiveEnd(a)) + ' inclusive</small></span><span class="pill ' + (status(a, state.today) === 'Active' ? 'lavender' : 'soft') + '">'
      + status(a, state.today) + '</span>' + icon('arrow', 17) + '</button>').join('') + '</div>' : '<p class="helper empty">' + empty + '</p>';
  }
  return header(icon('sliders', 16) + ' YOUR CONTROLS', 'Manage adjustments', 'Review the context, dates, and status of each correction.', ['home', 'Back to Home'])
    + '<div class="flow-grid"><div class="flow-stack"><section class="panel flow-card"><h2>Active and scheduled</h2>'
    + entries(current, 'No active adjustments yet. Add context from a tracking overview to get started.') + '</section>'
    + '<section class="panel flow-card"><h2>Past adjustments</h2>' + entries(history, 'Completed, ended, and undone adjustments will appear here.') + '</section>'
    + '<div class="actions"><button class="button primary" data-action="new">New ' + cfg().name.toLowerCase() + ' adjustment ' + icon('arrow', 17) + '</button></div></div>'
    + '<div class="flow-stack"><section class="panel side-card"><p class="eyebrow">YOU ARE IN CONTROL</p><h2>Plans change.</h2>'
    + asideMessage('End early', 'Choose when your usual settings resume. The effect on earlier dates stays in your history.', 'date')
    + asideMessage('Undo', 'Remove this adjustment from all calculations and recommendations. Other overlapping reasons still apply.', 'reset')
    + '</section></div></div>';
}

function detail() {
  const a = find(view.id);
  const config = cfg(a.scenario);
  const end = effectiveEnd(a);
  const shortened = a.endedOn && a.endedOn < a.end;
  const stateLabel = status(a, state.today);
  const other = state.adjustments.filter((b) => b.id !== a.id && b.scenario === a.scenario && !b.undone && b.start <= a.end && effectiveEnd(b) >= a.start);
  return header(icon(config.icon, 16) + ' ' + config.name.toUpperCase() + ' ADJUSTMENT', esc(CONTEXT[a.reason].name), dates(a.start, end) + ' inclusive · ' + stateLabel, ['manage', 'All adjustments'])
    + '<div class="flow-grid"><div class="flow-stack"><section class="panel flow-card"><div class="section-top"><h2>Saved context</h2><span class="pill lavender">' + stateLabel + '</span></div>'
    + (a.note ? '<p class="quote">“' + esc(a.note) + '”</p>' : '<p class="helper">Only the context category was retained.</p>')
    + '<p>' + (a.mode === 'routine' ? esc(config.normalized) : 'Values in the selected period are set aside from your usual-pattern average while this adjustment applies.') + '</p>'
    + '<p class="helper">' + config.reminder + ': ' + (a.pause ? 'paused during the affected dates.' : 'uses the usual setting.') + '</p>'
    + (!a.undone ? '<div class="actions"><button class="button secondary" data-action="edit-adjustment">' + icon('edit', 16) + ' Edit</button>'
      + (['Active', 'Scheduled'].includes(stateLabel) ? '<button class="button secondary" data-action="dialog" data-key="extend">Extend</button>' : '')
      + (stateLabel === 'Active' && state.today < a.end ? '<button class="button secondary" data-action="dialog" data-key="end">End early</button>' : '')
      + '<button class="button ghost danger-text" data-action="dialog" data-key="undo">Undo</button></div>' : '<p class="applied-note">This adjustment no longer affects any record.</p>')
    + '</section><section class="panel flow-card"><h2>' + (a.undone ? 'Previously selected records' : 'Affected records') + '</h2>'
    + '<p class="helper">' + (shortened ? 'Originally scheduled through ' + formatDate(a.end) + '. ' : '')
    + (a.undone ? 'The selected period is shown for reference.' : 'The effect runs through ' + formatDate(end) + ' and stops before ' + formatDate(shiftDate(end, 1)) + '.') + '</p>'
    + timeline(a.scenario, a.start, shortened ? a.end : end, a, a.mode === 'routine' ? 'Keep in average' : 'Set aside', { undone: a.undone, endedOn: a.endedOn })
    + (shortened && !a.undone ? '<div class="split-end"><strong>From ' + formatDate(shiftDate(end, 1)) + ' through ' + formatDate(a.end) + ':</strong> this adjustment no longer applies; other adjustments may still apply.</div>' : '')
    + '</section></div><div class="flow-stack"><section class="panel side-card"><p class="eyebrow">OVERLAPPING CONTEXT</p><h2>Related adjustments</h2>'
    + (other.length ? '<ul class="related">' + other.map((b) => '<li><button class="text-button" data-action="detail" data-key="' + b.id + '">'
      + esc(CONTEXT[b.reason].name) + ' ' + icon('arrow', 14) + '</button><small>' + dates(b.start, effectiveEnd(b)) + ' · ' + status(b, state.today) + '</small></li>').join('') + '</ul>'
      : '<p>No other contexts overlap these dates.</p>')
    + '</section></div></div>';
}

function render() {
  const screens = { summary, browse, tracking, context, proposal, receipt, manage, detail };
  app.innerHTML = shell(screens[view.name]());
}

function openDialog(action) {
  const a = find(view.id);
  const dialog = document.querySelector('#confirm-dialog');
  let title, description, field = '', submitText;
  if (action === 'pins') {
    title = 'Edit Pinned';
    description = 'Choose the categories you want to see in Summary. All categories are still available in Browse.';
    const labels = { sleep: 'Time Asleep', activity: 'Steps', cycle: 'Cycle Length' };
    field = '<fieldset class="pin-options"><legend class="visually-hidden">Health categories</legend>' + SCENARIO_KEYS.map((key) =>
      '<label class="check-row"><input type="checkbox" name="pins" value="' + key + '"' + (state.pins.includes(key) ? ' checked' : '')
      + '><span class="category-glyph ' + key + '">' + icon(categoryIcon[key], 17) + '</span><span>' + labels[key] + '</span></label>').join('') + '</fieldset>';
    submitText = 'Done';
  } else if (action === 'reset') {
    title = 'Reset the demo?';
    description = 'This clears all saved adjustments and drafts and returns to ' + formatDate(DEMO_START) + '.';
    submitText = 'Reset demo';
  } else if (action === 'extend' && a) {
    title = 'Extend this adjustment';
    description = 'Choose a later end date. The context and reminder preference will also apply to the new dates.';
    field = '<label class="field-label" for="extend-date">New end date (inclusive)</label><input id="extend-date" type="date" name="end" required min="' + shiftDate(a.end, 1) + '" value="' + shiftDate(a.end, 1) + '">';
    submitText = 'Save new end date';
  } else if (action === 'end' && a) {
    title = 'End this adjustment early?';
    const nextDay = shiftDate(state.today, 1);
    description = 'Earlier dates stay affected. Dates from the one you choose count again unless another adjustment applies.';
    field = '<label class="field-label" for="resume-date">Resume usual settings on</label><select id="resume-date" name="end">'
      + (state.today > a.start ? '<option value="' + state.today + '">' + formatDate(state.today) + ' (includes today’s log)</option>' : '')
      + '<option value="' + nextDay + '" selected>' + formatDate(nextDay) + ' (after today’s log)</option></select>';
    submitText = 'End early';
  } else if (action === 'undo' && a) {
    title = 'Undo this adjustment?';
    description = 'Restore the original handling of the selected dates, except where another adjustment applies. This entry will stay in your history as undone.';
    submitText = 'Undo adjustment';
  } else {
    return;
  }
  dialog.innerHTML = '<form id="action-form" data-key="' + action + '"><h2 id="dialog-title">' + title + '</h2><p>' + description + '</p>' + field
    + '<div class="actions"><button type="button" data-action="close-dialog" class="button secondary" autofocus>Cancel</button><button type="submit" class="button primary">' + submitText + '</button></div></form>';
  dialog.showModal();
}

app.addEventListener('input', (event) => {
  if (event.target.form?.id !== 'context-form') return;
  const input = event.target;
  if (input.name === 'explanation') {
    const reason = input.value.trim() ? '' : find(view.id)?.reason ?? '';
    putDraft({ explanation: input.value, reason });
    document.querySelectorAll('.template.chosen').forEach((b) => b.classList.remove('chosen'));
  } else if (input.name === 'start' || input.name === 'end') {
    putDraft({ [input.name]: input.value });
    document.querySelector('#scope-preview').innerHTML = scopePreview(currentDraft());
  } else if (input.name === 'pause' || input.name === 'storeNote') {
    putDraft({ [input.name]: input.checked });
  }
  document.querySelector('#form-error').textContent = '';
});

app.addEventListener('submit', (event) => {
  event.preventDefault();
  const form = event.target;
  if (form.id === 'context-form') {
    const draft = currentDraft();
    const error = dateError(draft, find(view.id)) || (!draft.explanation.trim() && !draft.reason ? 'Enter a short explanation or select an example.' : '');
    if (error) {
      document.querySelector('#form-error').textContent = error;
      (dateError(draft, find(view.id)) ? form.elements.start : form.elements.explanation).focus();
      return;
    }
    go('proposal', { id: view.id });
  } else if (form.id === 'action-form') {
    const action = form.dataset.key;
    document.querySelector('#confirm-dialog').close();
    if (action === 'pins') {
      state.pins = new FormData(form).getAll('pins');
      save(); go('summary'); tell('Pinned categories updated.'); return;
    }
    if (action === 'reset') {
      state = freshState(); recordDate = ''; mobileDemoOpen = false; save(); go('summary');
      tell('Demo reset.');
      return;
    }
    const a = find(view.id);
    const next = a && changeAdjustment(a, action, state.today, form.elements.end?.value);
    if (next) {
      state.adjustments = withAdjustment(state.adjustments, next);
      delete state.drafts[a.id];
      save();
      go('detail', { id: a.id });
      tell({ extend: 'Dates extended.', end: 'Adjustment ended early.', undo: 'Adjustment undone.' }[action]);
    }
  }
});

app.addEventListener('click', (event) => {
  const button = event.target.closest('[data-action]');
  if (!button) return;
  const { action, key } = button.dataset;
  switch (action) {
    case 'home': go('summary'); break;
    case 'browse': go('browse'); break;
    case 'tracking-back': go('tracking'); break;
    case 'scenario':
      state.scenario = key; recordDate = ''; save(); go('tracking'); break;
    case 'resume':
      state.scenario = key; recordDate = ''; save(); go('context'); break;
    case 'record':
      recordDate = key; render();
      document.querySelector('.bar-item.current')?.focus();
      break;
    case 'skip-insight':
      state.skipped[state.scenario] = key; save(); render();
      document.querySelector('[data-action="restore-insight"]').focus(); break;
    case 'restore-insight':
      delete state.skipped[state.scenario]; save(); render();
      document.querySelector('[data-action="skip-insight"]')?.focus(); break;
    case 'manage': go('manage'); break;
    case 'detail':
      if (find(key)) go('detail', { id: key });
      break;
    case 'detail-back': go('detail', { id: view.id }); break;
    case 'new':
      if (!state.drafts[state.scenario]) {
        const draft = defaultDraft(state.scenario, state.today);
        if (recordDate && recordDate !== recorded(state.scenario, state.today).at(-1)?.date) draft.start = draft.end = recordDate;
        state.drafts[state.scenario] = draft; save();
      }
      go('context');
      break;
    case 'template': {
      const option = cfg(currentDraft().scenario).options.find(([id]) => id === key);
      putDraft({ reason: key, explanation: option[2] }); render();
      document.querySelector('#explanation').focus();
      break;
    }
    case 'context-back': go('context', { id: view.id }); break;
    case 'discard': {
      const id = view.id;
      delete state.drafts[id || state.scenario]; save();
      if (id) go('detail', { id }); else go('tracking');
      tell('Draft discarded.');
      break;
    }
    case 'edit-adjustment': {
      const a = find(view.id);
      state.drafts[a.id] ??= { scenario: a.scenario, explanation: a.note, reason: a.reason, start: a.start, end: a.end, storeNote: !!a.note, pause: a.pause, mode: a.mode };
      save();
      go('context', { id: a.id });
      break;
    }
    case 'mode': putDraft({ mode: key }); render(); document.querySelector('[data-action="mode"][aria-pressed="true"]')?.focus(); break;
    case 'dismiss': state.dismissed.push(key); save(); go('proposal', { id: view.id }); break;
    case 'apply': {
      const draft = currentDraft();
      const existing = find(view.id);
      if (dateError(draft, existing)) { go('context', { id: view.id }); break; }
      const applied = fromDraft(draft, view.id || crypto.randomUUID(), existing);
      const before = state.adjustments;
      state.adjustments = withAdjustment(before, applied);
      delete state.drafts[view.id || state.scenario];
      state.scenario = applied.scenario; recordDate = ''; save();
      go('receipt', { appliedId: applied.id, before });
      tell('Adjustment saved.');
      break;
    }
    case 'advance':
      if (state.today >= DEMO_END) break;
      mobileDemoOpen = document.querySelector('.mobile-demo').open;
      state.today = shiftDate(state.today, 1); recordDate = ''; save();
      go(view.name, view);
      tell('Demo date advanced to ' + formatDate(state.today) + '.');
      break;
    case 'dialog': openDialog(key); break;
    case 'close-dialog': document.querySelector('#confirm-dialog').close(); break;
  }
});

render();
