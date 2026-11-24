import { CONTEXT, DEMO_START, SCENARIO_KEYS, SCENARIOS } from './scenarios.mjs';

export function freshState() {
  return { scenario: 'sleep', today: DEMO_START, adjustments: [], drafts: {}, dismissed: [], skipped: {}, pins: [...SCENARIO_KEYS] };
}

export function shiftDate(date, days) {
  const value = new Date(date + 'T12:00:00Z');
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

export function formatDate(date, options = { month: 'short', day: 'numeric' }) {
  return new Intl.DateTimeFormat('en-US', { timeZone: 'UTC', ...options }).format(new Date(date + 'T12:00:00Z'));
}

export const effectiveEnd = (adjustment) => adjustment.endedOn && adjustment.endedOn < adjustment.end
  ? adjustment.endedOn : adjustment.end;

export function status(adjustment, today) {
  if (adjustment.undone) return 'Undone';
  if (adjustment.endedOn) return 'Ended early';
  if (today < adjustment.start) return 'Scheduled';
  if (today > effectiveEnd(adjustment)) return 'Completed';
  return 'Active';
}

export function matching(adjustments, scenario, date) {
  return adjustments.filter((a) => a.scenario === scenario && !a.undone && a.start <= date && date <= effectiveEnd(a));
}

export function recorded(scenario, today) {
  return SCENARIOS[scenario].records.filter((r) => r.date <= today);
}

export function estimate(scenario, today, adjustments) {
  const records = recorded(scenario, today).filter((r) => r.value !== null);
  const included = records.filter((r) => !matching(adjustments, scenario, r.date).some((a) => a.mode === 'context'));
  return {
    value: included.length ? Math.round(included.reduce((sum, r) => sum + r.value, 0) / included.length) : null,
    included: included.length,
    total: records.length,
  };
}

export function defaultDraft(scenario, today) {
  const config = SCENARIOS[scenario];
  const latest = recorded(scenario, today).at(-1)?.date ?? config.focus;
  const [start, end] = latest === config.focus ? config.period : [latest, shiftDate(latest, 2)];
  return { scenario, explanation: '', reason: '', start, end, storeNote: false, pause: false, mode: 'context' };
}

const keywords = {
  deadline: /deadline|assignment|project|exam|study/i,
  travel: /travel|flight|jet lag|time zone/i,
  care: /caregiv|caring for|sick child/i,
  injury: /injur|recover|ankle|sprain|hurt/i,
  busy: /busy|work schedule|overtime/i,
  routine: /routin|travel|schedule/i,
  stress: /stress|anxious/i,
  'other-change': /timing|irregul|repeat/i,
};

export function inferReason(draft) {
  if (Object.hasOwn(CONTEXT, draft.reason)) return draft.reason;
  return SCENARIOS[draft.scenario].options.find(([key]) => keywords[key].test(draft.explanation))?.[0] ?? 'other';
}

export function measurementConflict(scenario, explanation, record) {
  if (!record || record.value === null) return null;
  const claim = {
    sleep: /(?:my |the )?sleep score (?:was|is) (\d{1,3})\b/i,
    activity: /(?:i walked|i logged|i took) (\d[\d,]*) steps\b/i,
    cycle: /(?:my |the )?cycle interval (?:was|is) (\d{1,3}) days\b/i,
  }[scenario].exec(explanation);
  if (!claim || Number(claim[1].replaceAll(',', '')) === record.value) return null;
  return { date: record.date, claimed: claim[1] };
}

export function fromDraft(draft, id, existing) {
  return {
    id, scenario: draft.scenario, reason: inferReason(draft), start: draft.start, end: draft.end,
    pause: draft.pause, mode: draft.mode,
    note: draft.storeNote ? draft.explanation.trim() : '',
    endedOn: existing?.endedOn ?? null, undone: false,
  };
}

export function withAdjustment(adjustments, change) {
  return adjustments.some((a) => a.id === change.id)
    ? adjustments.map((a) => a.id === change.id ? change : a)
    : [...adjustments, change];
}

export function changeAdjustment(a, action, today, date) {
  if (action === 'undo' && !a.undone) return { ...a, undone: true };
  if (!['Active', 'Scheduled'].includes(status(a, today))) return null;
  if (action === 'extend' && date > a.end) return { ...a, end: date };
  if (action === 'end' && status(a, today) === 'Active' && today < a.end) {
    const resumeOn = date ?? shiftDate(today, 1);
    if (resumeOn > a.start && resumeOn <= a.end && [today, shiftDate(today, 1)].includes(resumeOn)) {
      return { ...a, endedOn: shiftDate(resumeOn, -1) };
    }
  }
  return null;
}

export function repeatedReason(adjustments, proposed) {
  if (proposed.reason === 'other') return false;
  const earlier = adjustments.filter((a) => a.id !== proposed.id && !a.undone && a.mode === 'context'
    && a.scenario === proposed.scenario && a.reason === proposed.reason && effectiveEnd(a) < proposed.start);
  return earlier.some((a, index) => earlier.slice(index + 1).some((b) => effectiveEnd(a) < b.start || effectiveEnd(b) < a.start));
}

export function coaching(scenario, date, adjustments) {
  const applied = matching(adjustments, scenario, date);
  const context = [...new Set(applied.filter((a) => a.mode === 'context').map((a) => a.reason))];
  const record = SCENARIOS[scenario].records.find((r) => r.date === date);
  let initial = SCENARIOS[scenario].initial;
  if (scenario === 'sleep' && date !== DEMO_START) {
    initial = !record ? 'Sleep records from this date are not available in the demo.'
      : record.value < 75 ? 'The sleep score was lower than the usual range in this example.'
      : 'This score is in the usual range in this example.';
  }
  if (scenario === 'activity') {
    initial = !record ? 'Activity records from this date are not available in the demo.'
      : record.value < 8000 ? 'The recorded step total was below the 8,000-step goal. The log alone does not explain why.'
      : 'The recorded step total met the 8,000-step goal.';
  }
  if (scenario === 'cycle' && date !== DEMO_START) {
    initial = !record ? 'No period start is logged on this date in the demo.'
      : record.value === null ? 'This is the first logged period start in the demo.'
      : 'This interval was ' + record.value + ' days between logged period starts.';
  }
  return {
    interpretation: context.length
      ? context.map((key) => CONTEXT[key].during).join(' ')
      : initial,
    tip: context.length ? context.map((key) => CONTEXT[key].tip).join(' ') : SCENARIOS[scenario].generalTip,
    paused: applied.some((a) => a.pause),
  };
}
