import { createHash, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';

const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || '127.0.0.1';
const openAiApiKey = process.env.OPENAI_API_KEY;
const openAiModel = process.env.OPENAI_MODEL || 'gpt-5.6-luna';
const appToken = process.env.NORI_APP_TOKEN;

const actionSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    message: { type: 'string' },
    actions: {
      type: 'array',
      maxItems: 5,
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          id: { type: 'string' },
          kind: { type: 'string', enum: ['task', 'calendar', 'meeting', 'email'] },
          title: { type: ['string', 'null'] },
          dueLabel: { type: ['string', 'null'] },
          category: { type: ['string', 'null'], enum: ['Work', 'School', 'Personal', null] },
          start: { type: ['string', 'null'] },
          durationMinutes: { type: ['number', 'null'] },
          notes: { type: ['string', 'null'] },
          attendees: { type: ['array', 'null'], items: { type: 'string' } },
          to: { type: ['string', 'null'] },
          subject: { type: ['string', 'null'] },
          body: { type: ['string', 'null'] },
        },
        required: ['id', 'kind', 'title', 'dueLabel', 'category', 'start', 'durationMinutes', 'notes', 'attendees', 'to', 'subject', 'body'],
      },
    },
  },
  required: ['message', 'actions'],
};

const assistantInstructions = `You are Nori, an action-oriented personal assistant for students and working professionals.
Turn requests into a short helpful response and zero or more typed actions.
Use the supplied current date and calendar context. Use ISO 8601 timestamps with timezone offsets.
Make practical assumptions for low-risk planning, but mention material assumptions in the response.
Tasks are safe local actions. Calendar changes, meeting invitations, and emails require approval in the mobile app.
Never claim an external action has happened; only propose it. Draft concise, professional emails in the user's voice.
For day planning, protect focused blocks, include breathing room, and avoid overlapping supplied calendar events.`;

const json = (response, status, payload) => {
  response.writeHead(status, {
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-User-Id',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'application/json; charset=utf-8',
  });
  response.end(JSON.stringify(payload));
};

const readBody = async (request) => {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1_000_000) throw new Error('Request body is too large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
};

const authorized = (request) => {
  if (!appToken) return true;
  return request.headers.authorization === `Bearer ${appToken}`;
};

const safetyIdentifier = (request) => {
  const userId = request.headers['x-user-id'] || request.socket.remoteAddress || 'anonymous';
  return createHash('sha256').update(String(userId)).digest('hex');
};

const outputText = (response) => {
  for (const item of response.output || []) {
    if (item.type !== 'message') continue;
    for (const content of item.content || []) {
      if (content.type === 'output_text') return content.text;
    }
  }
  throw new Error('The model returned no structured response');
};

export const normalizeActions = (value) => {
  const actions = Array.isArray(value.actions) ? value.actions : [];
  return {
    message: typeof value.message === 'string' ? value.message : 'I prepared a plan for you.',
    actions: actions.map((action) => {
      const id = action.id || randomUUID();
      if (action.kind === 'task') {
        return {
          id,
          kind: 'task',
          title: action.title || 'New priority',
          dueLabel: action.dueLabel || 'Today',
          category: ['Work', 'School', 'Personal'].includes(action.category) ? action.category : 'Personal',
        };
      }
      if (action.kind === 'email') {
        return {
          id,
          kind: 'email',
          to: action.to || '',
          subject: action.subject || 'Quick follow-up',
          body: action.body || '',
        };
      }
      return {
        id,
        kind: action.kind === 'meeting' ? 'meeting' : 'calendar',
        title: action.title || (action.kind === 'meeting' ? 'Meeting' : 'Focus block'),
        start: action.start || new Date(Date.now() + 60 * 60_000).toISOString(),
        durationMinutes: Math.max(15, Math.min(Number(action.durationMinutes) || 60, 480)),
        notes: action.notes || 'Planned with Nori',
        attendees: Array.isArray(action.attendees) ? action.attendees : [],
      };
    }),
  };
};

const planWithOpenAi = async (request, body) => {
  if (!openAiApiKey) throw new Error('OPENAI_API_KEY is not configured');
  const apiResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openAiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: openAiModel,
      instructions: assistantInstructions,
      input: JSON.stringify({ message: body.message, context: body.context }),
      reasoning: { effort: 'low' },
      safety_identifier: safetyIdentifier(request),
      store: false,
      text: {
        verbosity: 'low',
        format: {
          type: 'json_schema',
          name: 'nori_action_plan',
          strict: true,
          schema: actionSchema,
        },
      },
    }),
  });
  const payload = await apiResponse.json();
  if (!apiResponse.ok) throw new Error(payload.error?.message || 'OpenAI request failed');
  return normalizeActions(JSON.parse(outputText(payload)));
};

let cachedGoogleToken;

const googleAccessToken = async () => {
  if (cachedGoogleToken && cachedGoogleToken.expiresAt > Date.now() + 60_000) return cachedGoogleToken.value;
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const refreshToken = process.env.GOOGLE_REFRESH_TOKEN;
  if (!clientId || !clientSecret || !refreshToken) throw new Error('Google OAuth credentials are not configured');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error_description || 'Google token refresh failed');
  cachedGoogleToken = { value: payload.access_token, expiresAt: Date.now() + payload.expires_in * 1000 };
  return cachedGoogleToken.value;
};

const executeCalendar = async (action) => {
  const token = await googleAccessToken();
  const start = new Date(action.start);
  const end = new Date(start.getTime() + action.durationMinutes * 60_000);
  const response = await fetch('https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=all', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      summary: action.title,
      description: action.notes || 'Planned with Nori',
      start: { dateTime: start.toISOString() },
      end: { dateTime: end.toISOString() },
      attendees: (action.attendees || []).map((email) => ({ email })),
    }),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error?.message || 'Calendar event creation failed');
  return { id: payload.id, link: payload.htmlLink, provider: 'google-calendar' };
};

const executeEmail = async (action) => {
  if (!action.to) throw new Error('An email recipient is required');
  const token = await googleAccessToken();
  const recipient = String(action.to).replace(/[\r\n]/g, ' ').trim();
  const subject = String(action.subject || 'Quick follow-up').replace(/[\r\n]/g, ' ').trim();
  const message = [
    `To: ${recipient}`,
    `Subject: ${subject}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    '',
    action.body,
  ].join('\r\n');
  const raw = Buffer.from(message).toString('base64url');
  const response = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ raw }),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error?.message || 'Email send failed');
  return { id: payload.id, threadId: payload.threadId, provider: 'gmail' };
};

const executionReceipts = new Map();

const executeAction = async (body) => {
  if (body.approved !== true) throw new Error('Explicit approval is required');
  const action = body.action;
  if (!action || typeof action.kind !== 'string') throw new Error('A valid action is required');
  if (action.id && executionReceipts.has(action.id)) return executionReceipts.get(action.id);
  let receipt;
  if (action.kind === 'calendar' || action.kind === 'meeting') receipt = await executeCalendar(action);
  else if (action.kind === 'email') receipt = await executeEmail(action);
  else throw new Error('Only external actions are accepted by this endpoint');
  if (action.id) executionReceipts.set(action.id, receipt);
  return receipt;
};

const server = createServer(async (request, response) => {
  if (request.method === 'OPTIONS') return json(response, 204, {});
  const url = new URL(request.url || '/', `http://${request.headers.host || 'localhost'}`);
  if (request.method === 'GET' && url.pathname === '/health') {
    return json(response, 200, {
      status: 'ok',
      aiConfigured: Boolean(openAiApiKey),
      googleConfigured: Boolean(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET && process.env.GOOGLE_REFRESH_TOKEN),
    });
  }
  if (!authorized(request)) return json(response, 401, { error: 'Unauthorized' });

  try {
    if (request.method === 'POST' && url.pathname === '/assistant') {
      const body = await readBody(request);
      if (typeof body.message !== 'string' || !body.message.trim()) return json(response, 400, { error: 'A message is required' });
      return json(response, 200, await planWithOpenAi(request, body));
    }
    if (request.method === 'POST' && url.pathname === '/execute') {
      return json(response, 200, { receipt: await executeAction(await readBody(request)) });
    }
    return json(response, 404, { error: 'Not found' });
  } catch (error) {
    return json(response, 502, { error: error instanceof Error ? error.message : 'Request failed' });
  }
});

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  server.listen(port, host, () => {
    process.stdout.write(`Nori server listening on http://${host}:${port}\n`);
  });
}
