import { Linking } from 'react-native';
import { AssistantAction, CalendarAction, EmailAction } from '../types';

declare const process: { env: Record<string, string | undefined> };

const executeEndpoint = process.env.EXPO_PUBLIC_NORI_EXECUTE_URL;
const appToken = process.env.EXPO_PUBLIC_NORI_APP_TOKEN;

const calendarDate = (value: Date) => value.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');

export const buildGoogleCalendarUrl = (action: CalendarAction) => {
  const start = new Date(action.start);
  const end = new Date(start.getTime() + action.durationMinutes * 60_000);
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: action.title,
    dates: `${calendarDate(start)}/${calendarDate(end)}`,
    details: action.notes || 'Planned with Nori',
  });

  if (action.attendees.length) {
    params.set('add', action.attendees.join(','));
  }

  return `https://calendar.google.com/calendar/render?${params.toString()}`;
};

export const openCalendarAction = async (action: CalendarAction) => {
  await Linking.openURL(buildGoogleCalendarUrl(action));
};

export const openEmailAction = async (action: EmailAction) => {
  const params = new URLSearchParams({ subject: action.subject, body: action.body });
  await Linking.openURL(`mailto:${encodeURIComponent(action.to)}?${params.toString()}`);
};

export const executeConnectedAction = async (action: AssistantAction) => {
  if (!executeEndpoint || action.kind === 'task') return false;
  try {
    const response = await fetch(executeEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(appToken ? { Authorization: `Bearer ${appToken}` } : {}),
      },
      body: JSON.stringify({ action, approved: true }),
    });
    return response.ok;
  } catch {
    return false;
  }
};
