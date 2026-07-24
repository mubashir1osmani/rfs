export type Tab = 'home' | 'assistant' | 'day' | 'settings';

export type Task = {
  id: string;
  title: string;
  dueLabel: string;
  category: 'Work' | 'School' | 'Personal';
  completed: boolean;
};

export type CalendarBlock = {
  id: string;
  title: string;
  start: string;
  durationMinutes: number;
  color: string;
  source: 'seed' | 'nori';
  attendees?: string[];
};

export type TaskAction = {
  id: string;
  kind: 'task';
  title: string;
  dueLabel: string;
  category: Task['category'];
};

export type CalendarAction = {
  id: string;
  kind: 'calendar' | 'meeting';
  title: string;
  start: string;
  durationMinutes: number;
  notes: string;
  attendees: string[];
};

export type EmailAction = {
  id: string;
  kind: 'email';
  to: string;
  subject: string;
  body: string;
};

export type AssistantAction = TaskAction | CalendarAction | EmailAction;

export type ChatMessage = {
  id: string;
  role: 'assistant' | 'user';
  text: string;
  actions?: AssistantAction[];
};

export type AssistantContext = {
  tasks: Task[];
  calendar: CalendarBlock[];
  currentDate: string;
};

export type AssistantReply = {
  message: string;
  actions: AssistantAction[];
};

export type ConnectionState = {
  calendar: boolean;
  gmail: boolean;
};
