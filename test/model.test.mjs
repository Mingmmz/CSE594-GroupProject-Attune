import test from 'node:test';
import assert from 'node:assert/strict';
import { DEMO_START, SCENARIOS } from '../app/scenarios.mjs';
import {
  changeAdjustment, coaching, defaultDraft, effectiveEnd, estimate, fromDraft, matching, measurementConflict,
  recorded, repeatedReason, status, withAdjustment,
} from '../app/model.mjs';

const day = (n) => '2026-11-' + String(n).padStart(2, '0');

function draft(scenario, props) {
  return { ...defaultDraft(scenario, DEMO_START), explanation: SCENARIOS[scenario].options[0][2], ...props };
}

test('sleep proposal recalculates the baseline independently of the 62 score and includes the final date', () => {
  const corrected = fromDraft(draft('sleep'), 'deadline');
  assert.deepEqual(estimate('sleep', DEMO_START, []), { value: 76, included: 9, total: 9 });
  assert.deepEqual(estimate('sleep', DEMO_START, [corrected]), { value: 82, included: 5, total: 9 });
  assert.equal(recorded('sleep', DEMO_START).at(-1).value, 62);
  assert.deepEqual(matching([corrected], 'sleep', day(13)), [corrected]);
  assert.deepEqual(matching([corrected], 'sleep', day(14)), []);
  assert.equal(status(corrected, day(14)), 'Completed');
});

test('ending early restores the chosen and future dates, while overlaps remain independent', () => {
  const deadline = fromDraft(draft('sleep', { pause: true }), 'deadline');
  const travel = fromDraft(draft('sleep', { reason: 'travel', start: day(11), end: day(12) }), 'travel');
  const ended = changeAdjustment(deadline, 'end', day(12), day(12));
  assert.equal(effectiveEnd(ended), day(11));
  assert.equal(status(ended, day(12)), 'Ended early');
  assert.deepEqual(matching([ended, travel], 'sleep', day(11)), [ended, travel]);
  assert.deepEqual(matching([ended, travel], 'sleep', day(12)), [travel]);
  assert.equal(coaching('sleep', day(11), [ended, travel]).paused, true);
  assert.equal(coaching('sleep', day(12), [ended, travel]).paused, false);
  const undone = changeAdjustment(ended, 'undo', day(12));
  assert.deepEqual(matching([undone, travel], 'sleep', day(7)), []);
  assert.deepEqual(matching([undone, travel], 'sleep', day(11)), [travel]);
  assert.equal(status(undone, day(12)), 'Undone');
});

test('extending applies coaching to new days and edits replace a rule by ID', () => {
  const injury = fromDraft(draft('activity', { pause: true }), 'injury');
  const extended = changeAdjustment(injury, 'extend', day(12), day(15));
  assert.equal(changeAdjustment(injury, 'extend', day(12), day(12)), null);
  assert.equal(coaching('activity', day(15), [extended]).paused, true);
  assert.match(coaching('activity', day(15), [extended]).tip, /make up missed steps/);
  assert.equal(coaching('activity', day(16), [extended]).paused, false);
  const edited = fromDraft(draft('activity', { reason: 'travel', explanation: 'Flight', storeNote: true }), extended.id, extended);
  const list = withAdjustment([extended], edited);
  assert.deepEqual(list, [edited]);
  assert.equal(list[0].note, 'Flight');
  assert.equal(injury.note, '');
  assert.equal(recorded('activity', DEMO_START).at(-1).value, 3200);
});

test('cycle values change the average by date without altering dates or the latest interval', () => {
  const before = recorded('cycle', DEMO_START);
  const correction = fromDraft(draft('cycle'), 'cycle-adjustment');
  assert.equal(estimate('cycle', DEMO_START, []).value, 27);
  assert.equal(estimate('cycle', DEMO_START, [correction]).value, 29);
  assert.deepEqual(recorded('cycle', DEMO_START), before);
  assert.deepEqual(before.at(-1), { date: DEMO_START, value: 22 });
  assert.equal(estimate('cycle', DEMO_START, [{ ...correction, mode: 'routine' }]).value, 27);
});

test('only distinct earlier periods trigger a recurring context check-in', () => {
  const older = fromDraft(draft('sleep', { start: day(2), end: day(3) }), 'earlier');
  const second = { ...older, id: 'second', start: day(4), end: day(5) };
  const proposed = fromDraft(draft('sleep'), 'new');
  assert.equal(repeatedReason([older, second], proposed), true);
  assert.equal(repeatedReason([older, { ...second, start: day(3) }], proposed), false);
  assert.equal(repeatedReason([older, { ...second, undone: true }], proposed), false);
});

test('matching adjustments never double-count excluded records or spill across scenarios', () => {
  const adjustment = fromDraft(draft('sleep'), 'first');
  const overlap = { ...adjustment, id: 'second', reason: 'travel' };
  assert.deepEqual(estimate('sleep', DEMO_START, [adjustment, overlap]), estimate('sleep', DEMO_START, [adjustment]));
  assert.deepEqual(estimate('activity', DEMO_START, [adjustment, overlap]), estimate('activity', DEMO_START, []));
});

test('an explicit conflicting measurement receives a verification cue without changing the log', () => {
  const steps = recorded('activity', DEMO_START).at(-1);
  assert.deepEqual(measurementConflict('activity', 'I walked 8,000 steps.', steps), { date: DEMO_START, claimed: '8,000' });
  assert.equal(measurementConflict('activity', 'I walked 3,200 steps.', steps), null);
  assert.equal(measurementConflict('activity', 'My goal is 8,000 steps.', steps), null);
  assert.equal(steps.value, 3200);
});
