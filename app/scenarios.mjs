export const DEMO_START = '2026-11-10';
export const DEMO_END = '2026-11-16';
const daily = (values) => values.map((value, i) => ({ date: '2026-11-' + String(i + 2).padStart(2, '0'), value }));

export const SCENARIOS = {
  sleep: {
    name: 'Sleep', icon: 'moon', title: 'Your sleep, in context.', intro: 'One short night can tell you what happened. It takes context to understand why.',
    metric: 'Sleep score', suffix: '/ 100', baseline: 'Usual sleep score', chartTitle: 'Sleep scores by night',
    singular: 'night', plural: 'nights', source: 'Wearable demo data', max: 100,
    focus: DEMO_START, period: ['2026-11-07', '2026-11-13'],
    records: daily([83, 81, 85, 79, 82, 78, 67, 65, 62, 64, 72, 80, 86, 81, 84]).map((r, i) => ({
      ...r, minutes: [446, 431, 460, 421, 439, 403, 359, 334, 302, 324, 390, 431, 465, 440, 454][i],
      ...(r.date === DEMO_START ? { detail: '5h 02m asleep · 2:10 a.m. bedtime' } : {}),
    })),
    placeholder: 'What was different about these nights?',
    options: [
      ['deadline', 'Working toward a deadline', 'I’ve been staying up late to meet a Friday deadline. I expect my usual sleep to return after that.'],
      ['travel', 'Travel or a schedule shift', 'I was traveling and sleeping at different hours.'],
      ['care', 'Caring for someone', 'I was up during the night caring for someone.'],
    ],
    initial: 'Three recent nights were shorter and later than usual. The wearable can show a change in sleep, but it cannot explain the reason.',
    generalTip: 'If your evenings have changed, you can note what feels different and review your sleep pattern again.',
    reminder: 'Bedtime routine prompt',
    normalized: 'The selected nights count toward your usual sleep pattern.',
  },
  activity: {
    name: 'Activity', icon: 'activity', title: 'Your activity, in context.', intro: 'A missed step goal shows what you logged. Your circumstances can explain the rest.',
    metric: 'Daily steps', suffix: '/ 8,000', baseline: 'Usual daily steps', chartTitle: 'Steps by day',
    singular: 'day', plural: 'days', source: 'Wearable demo data', max: 10000,
    focus: DEMO_START, period: ['2026-11-08', '2026-11-13'],
    records: daily([8600, 9100, 8200, 8740, 7950, 8300, 4620, 3520, 3200, 3840, 4500, 7200, 8110, 8600, 8930]),
    placeholder: 'What affected your activity during this time?',
    options: [
      ['injury', 'Recovering from an injury', 'I was recovering from a leg injury and walking less.'],
      ['travel', 'Travel or a schedule shift', 'Travel changed how much I could walk each day.'],
      ['busy', 'An unusually busy week', 'I had an unusually busy week with less time to walk.'],
    ],
    initial: 'Recent step totals were below your goal. The log alone does not explain why.',
    generalTip: 'Review your step totals alongside your schedule and decide whether the daily goal still fits your routine.',
    reminder: 'Step goal prompt',
    normalized: 'The selected days count toward your usual activity pattern.',
  },
  cycle: {
    name: 'Cycle', icon: 'cycle', title: 'Your cycle, in context.', intro: 'Add your own explanation to a change in timing while keeping the dates you logged.',
    metric: 'Latest cycle interval', suffix: 'days', baseline: 'Usual interval', chartTitle: 'Logged period starts',
    singular: 'period start', plural: 'period starts', source: 'Example period log', max: 35,
    focus: DEMO_START, period: ['2026-11-10', '2026-11-13'],
    records: [
      { date: '2026-08-22', value: null }, { date: '2026-09-20', value: 29 },
      { date: '2026-10-19', value: 29 }, { date: DEMO_START, value: 22 },
    ],
    placeholder: 'What context would you like to attach to these dates?',
    options: [
      ['routine', 'Temporary routine change', 'My routine changed during travel and I want to note the timing.'],
      ['stress', 'An unusually stressful period', 'I had more stress than usual around these dates.'],
      ['other-change', 'Other change I noticed', 'The timing was different and I want to track whether it repeats.'],
    ],
    initial: 'The latest interval is shorter than the two earlier intervals in this example.',
    generalTip: 'You can keep logging dates and use your own notes to reflect on changes over time.',
    reminder: 'Cycle reflection prompt',
    normalized: 'Intervals ending in the selected dates count toward your usual cycle pattern.',
  },
};

export const SCENARIO_KEYS = Object.keys(SCENARIOS);

export const CONTEXT = {
  deadline: { name: 'Deadline', during: 'Treat the lower scores as part of a deadline period you described.', tip: 'If useful, revisit your usual evening routine when the deadline passes.' },
  travel: { name: 'Travel or schedule shift', during: 'Read these records alongside the travel or schedule change you described.', tip: 'Check your usual pattern again after your schedule settles.' },
  care: { name: 'Caregiving', during: 'Read the disrupted nights in light of the caregiving context you shared.', tip: 'When your schedule allows, reflect on what changed in your evening routine.' },
  injury: { name: 'Injury recovery', during: 'Read the missed step goal in light of your reported recovery.', tip: 'You can review your records without a prompt to make up missed steps.' },
  busy: { name: 'Busy period', during: 'Read the lower step totals in light of the schedule you described.', tip: 'Revisit your usual activity pattern when your schedule settles.' },
  routine: { name: 'Routine change', during: 'Keep the timing as logged and attach your reported routine change as context.', tip: 'Keep logging dates to see whether the timing change repeats.' },
  stress: { name: 'Stressful period', during: 'Keep the timing as logged alongside the stressful period you described.', tip: 'You can review changes in timing alongside the context you chose to share.' },
  'other-change': { name: 'Timing change', during: 'Keep the timing as logged alongside the change you noticed.', tip: 'Review upcoming logs when you have enough records to compare.' },
  other: { name: 'Personal context', during: 'Read the selected records alongside the context you shared.', tip: 'Revisit your usual pattern after this period and decide if it still reflects your routine.' },
};
