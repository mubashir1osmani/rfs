import { AssistantAction, AssistantContext, AssistantReply, CalendarAction, Task } from '../types';

declare const process: { env: Record<string, string | undefined> };

const endpoint = process.env.EXPO_PUBLIC_NORI_API_URL;
const appToken = process.env.EXPO_PUBLIC_NORI_APP_TOKEN;
const userId = process.env.EXPO_PUBLIC_NORI_USER_ID || 'nori-mobile-user';

const identifier = (prefix: string) => `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;

const dateAt = (hour: number, minute = 0, dayOffset = 0) => {
  const value = new Date();
  value.setDate(value.getDate() + dayOffset);
  value.setHours(hour, minute, 0, 0);
  return value.toISOString();
};

const extractTime = (input: string, fallbackHour = 14) => {
  const match = input.match(/(?:at|around)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
  if (!match) return { hour: fallbackHour, minute: 0 };
  let hour = Number(match[1]);
  const minute = Number(match[2] || 0);
  const meridiem = match[3]?.toLowerCase();
  if (meridiem === 'pm' && hour < 12) hour += 12;
  if (meridiem === 'am' && hour === 12) hour = 0;
  if (!meridiem && hour < 8) hour += 12;
  return { hour: Math.min(hour, 23), minute };
};

const extractDuration = (input: string, fallback = 60) => {
  const minuteMatch = input.match(/(\d+)\s*(?:min|minute)/i);
  if (minuteMatch) return Number(minuteMatch[1]);
  const hourMatch = input.match(/(\d+(?:\.\d+)?)\s*(?:h|hour)/i);
  if (hourMatch) return Number(hourMatch[1]) * 60;
  return fallback;
};

const cleanTitle = (input: string, fallback: string) => {
  const cleaned = input
    .replace(/\b(add|create|schedule|block|book|set up|please|for me|on my calendar|to my calendar)\b/gi, '')
    .replace(/\b(today|tomorrow|tonight|this afternoon|this morning)\b/gi, '')
    .replace(/\b(?:at|around)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?/gi, '')
    .replace(/\bfor\s+\d+(?:\.\d+)?\s*(?:min(?:ute)?s?|h(?:ou)?rs?)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
  return cleaned || fallback;
};

const categoryFor = (input: string): Task['category'] => {
  if (/study|class|lecture|exam|assignment|homework|school/i.test(input)) return 'School';
  if (/work|client|team|project|brief|report/i.test(input)) return 'Work';
  return 'Personal';
};

const calendarAction = (input: string, kind: CalendarAction['kind']): CalendarAction => {
  const time = extractTime(input, kind === 'meeting' ? 15 : 14);
  const isTomorrow = /tomorrow/i.test(input);
  const attendee = input.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0];
  return {
    id: identifier(kind),
    kind,
    title: cleanTitle(input, kind === 'meeting' ? 'Meeting' : 'Focus block'),
    start: dateAt(time.hour, time.minute, isTomorrow ? 1 : 0),
    durationMinutes: extractDuration(input, kind === 'meeting' ? 30 : 60),
    notes: kind === 'meeting' ? 'Meeting organized with Nori' : 'Protected focus time planned with Nori',
    attendees: attendee ? [attendee] : [],
  };
};

const planDay = (context: AssistantContext): AssistantReply => {
  const openTasks = context.tasks.filter((task) => !task.completed).slice(0, 3);
  const starts = [9, 11, 14];
  const actions: AssistantAction[] = openTasks.map((task, index) => ({
    id: identifier('plan'),
    kind: 'calendar',
    title: task.title,
    start: dateAt(starts[index], index === 1 ? 30 : 0),
    durationMinutes: task.category === 'Personal' ? 30 : 60,
    notes: `Time block for ${task.category.toLowerCase()} priority`,
    attendees: [],
  }));
  return {
    message: actions.length
      ? `I made a realistic ${actions.length}-block plan with breathing room. Review it, then add the blocks you want to Google Calendar.`
      : 'Your task list is clear. Add a priority and I’ll build the day around it.',
    actions,
  };
};

const demoReply = (): AssistantReply => {
  const tomorrow = 1;
  return {
    message: 'Here’s Nori in action: one priority, a focus block, a meeting invite, and an email draft. Safe local work is handled automatically; anything external stays ready for your approval.',
    actions: [
      { id: identifier('demo-task'), kind: 'task', title: 'Review tomorrow’s priorities', dueLabel: 'Today · 10 min', category: 'Personal' },
      {
        id: identifier('demo-focus'),
        kind: 'calendar',
        title: 'Deep work · Project brief',
        start: dateAt(9, 30, tomorrow),
        durationMinutes: 90,
        notes: 'Protected focus block planned by Nori',
        attendees: [],
      },
      {
        id: identifier('demo-meeting'),
        kind: 'meeting',
        title: 'Weekly project sync',
        start: dateAt(14, 0, tomorrow),
        durationMinutes: 30,
        notes: 'Weekly project check-in',
        attendees: ['alex@example.com'],
      },
      {
        id: identifier('demo-email'),
        kind: 'email',
        to: 'alex@example.com',
        subject: 'Tomorrow’s project sync',
        body: 'Hi Alex,\n\nI’ve set aside time tomorrow for our project sync. Does 2:00 PM work for you?\n\nBest,\nMubashir',
      },
    ],
  };
};

const fallbackReply = (input: string, context: AssistantContext): AssistantReply => {
  if (/nori demo|show me.*demo|demo.*nori/i.test(input)) return demoReply();
  if (/plan|organize|time.?block my day|schedule my day/i.test(input)) return planDay(context);

  if (/\b(email|write to|message)\b/i.test(input)) {
    const email = input.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0] || '';
    const recipient = input.match(/(?:email|write to|message)\s+([\w .'-]+)/i)?.[1]?.split(/\s+(?:that|about|at)\b/i)[0].trim();
    const bodySeed = input.match(/\bthat\s+(.+)/i)?.[1] || 'Hi,\n\nJust following up. Let me know what works for you.\n\nBest,';
    return {
      message: `I drafted the email${recipient ? ` to ${recipient}` : ''}. I’ll always let you review communication before it leaves your device.`,
      actions: [{ id: identifier('email'), kind: 'email', to: email, subject: 'Quick follow-up', body: bodySeed }],
    };
  }

  if (/\b(meet|meeting|call with|book)\b/i.test(input)) {
    return { message: 'I prepared the meeting with a calendar invite. Add an email address if you want the guest included automatically.', actions: [calendarAction(input, 'meeting')] };
  }

  if (/\b(schedule|calendar|time block|focus block|study session)\b/i.test(input)) {
    return { message: 'I found a clean spot and prepared a protected calendar block.', actions: [calendarAction(input, 'calendar')] };
  }

  const taskTitle = cleanTitle(input, 'New priority');
  return {
    message: 'Got it. I turned that into a priority so it does not get lost.',
    actions: [{ id: identifier('task'), kind: 'task', title: taskTitle, dueLabel: /tomorrow/i.test(input) ? 'Tomorrow' : 'Today', category: categoryFor(input) }],
  };
};

const isReply = (value: unknown): value is AssistantReply => {
  if (!value || typeof value !== 'object') return false;
  const candidate = value as AssistantReply;
  return typeof candidate.message === 'string' && Array.isArray(candidate.actions);
};

export const askAssistant = async (input: string, context: AssistantContext): Promise<AssistantReply> => {
  if (endpoint) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId,
          ...(appToken ? { Authorization: `Bearer ${appToken}` } : {}),
        },
        body: JSON.stringify({ message: input, context }),
      });
      if (response.ok) {
        const reply: unknown = await response.json();
        if (isReply(reply)) return reply;
      }
    } catch {}
  }
  return fallbackReply(input, context);
};

export const hasRemoteAssistant = Boolean(endpoint);
