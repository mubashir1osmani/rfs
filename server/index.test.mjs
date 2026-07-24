import assert from 'node:assert/strict';
import test from 'node:test';
import { normalizeActions } from './index.mjs';

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
