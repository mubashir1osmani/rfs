import assert from 'node:assert/strict';
import test from 'node:test';
import { isAuthorizedValue, normalizeActions, validateAction } from './index.mjs';

test('normalizes model actions into the mobile contract', () => {
  const result = normalizeActions({
    message: 'I prepared two actions.',
    actions: [
      { id: 'task-1', kind: 'task', title: 'Study chapter four', dueLabel: null, category: 'School' },
      { id: 'event-1', kind: 'meeting', title: 'Project sync', start: '2026-08-01T15:00:00-07:00', durationMinutes: 30, notes: null, attendees: ['alex@example.com'] },
    ],
  });

  assert.equal(result.actions.length, 2);
  assert.deepEqual(result.actions[0], {
    id: 'task-1',
    kind: 'task',
    title: 'Study chapter four',
    dueLabel: 'Today',
    category: 'School',
  });
  assert.deepEqual(result.actions[1], {
    id: 'event-1',
    kind: 'meeting',
    title: 'Project sync',
    start: '2026-08-01T15:00:00-07:00',
    durationMinutes: 30,
    notes: 'Planned with Nori',
    attendees: ['alex@example.com'],
  });
});

test('applies safe defaults and duration limits', () => {
  const result = normalizeActions({ message: null, actions: [{ kind: 'calendar', durationMinutes: 900 }] });
  assert.equal(result.message, 'I prepared a plan for you.');
  assert.equal(result.actions[0].durationMinutes, 480);
  assert.equal(result.actions[0].title, 'Focus block');
});

test('compares bearer credentials without accepting malformed values', () => {
  const token = 'correct-horse-battery-staple-token';
  assert.equal(isAuthorizedValue(`Bearer ${token}`, token), true);
  assert.equal(isAuthorizedValue(`Bearer ${token}x`, token), false);
  assert.equal(isAuthorizedValue(token, token), false);
  assert.equal(isAuthorizedValue(undefined, token), false);
});

test('validates and sanitizes email actions', () => {
  const action = validateAction({
    id: 'email-1',
    kind: 'email',
    to: 'alex@example.com',
    subject: 'Hello\r\nBcc: attacker@example.com',
    body: 'Checking in.',
  });

  assert.equal(action.subject, 'Hello  Bcc: attacker@example.com');
  assert.throws(
    () => validateAction({ id: 'email-2', kind: 'email', to: 'not-an-email', subject: 'Hi', body: '' }),
    /valid email address/,
  );
});

test('validates calendar dates, attendees, and whole-minute durations', () => {
  const action = validateAction({
    id: 'event-1',
    kind: 'meeting',
    title: 'Project sync',
    start: '2026-08-01T15:00:00-07:00',
    durationMinutes: 30,
    attendees: ['alex@example.com'],
  });

  assert.equal(action.start, '2026-08-01T22:00:00.000Z');
  assert.throws(
    () => validateAction({ ...action, durationMinutes: 30.5 }),
    /whole number/,
  );
  assert.throws(
    () => validateAction({ ...action, attendees: ['invalid'] }),
    /valid email addresses/,
  );
});
