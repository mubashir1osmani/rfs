import { CalendarBlock, ChatMessage, Task } from './types';
import { colors } from './theme';

const todayAt = (hour: number, minute = 0) => {
  const value = new Date();
  value.setHours(hour, minute, 0, 0);
  return value.toISOString();
};

export const initialTasks: Task[] = [
  { id: 'task-1', title: 'Finish product brief', dueLabel: 'Today · 4:00 PM', category: 'Work', completed: false },
  { id: 'task-2', title: 'Review lecture notes', dueLabel: 'Tonight · 30 min', category: 'School', completed: false },
  { id: 'task-3', title: 'Call Mom', dueLabel: 'Tonight', category: 'Personal', completed: true },
];

export const initialCalendar: CalendarBlock[] = [
  { id: 'event-1', title: 'Deep work', start: todayAt(9), durationMinutes: 90, color: colors.mint, source: 'seed' },
  { id: 'event-2', title: 'Team standup', start: todayAt(11), durationMinutes: 30, color: colors.violet, source: 'seed' },
  { id: 'event-3', title: 'Lunch reset', start: todayAt(12, 30), durationMinutes: 45, color: colors.yellow, source: 'seed' },
];

export const initialMessages: ChatMessage[] = [
  {
    id: 'welcome',
    role: 'assistant',
    text: "Good morning — I’m Nori. Tell me what needs to happen, and I’ll turn it into tasks, calendar blocks, meetings, or ready-to-send emails.",
  },
];
