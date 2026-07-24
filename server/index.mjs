import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';

const positiveInteger = (value, fallback, minimum = 1) => {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed >= minimum ? parsed : fallback;
};
const port = positiveInteger(process.env.PORT, 8787);
const host = process.env.HOST || '127.0.0.1';
const openAiApiKey = process.env.OPENAI_API_KEY;
const openAiModel = process.env.OPENAI_MODEL || 'gpt-5.6-luna';
const appToken = process.env.NORI_APP_TOKEN;
const isProduction = process.env.NODE_ENV === 'production';
const allowedOrigin = process.env.ALLOWED_ORIGIN;
const requestTimeoutMs = positiveInteger(process.env.REQUEST_TIMEOUT_MS, 30_000, 5_000);
const rateLimitWindowMs = 60_000;
const rateLimitMax = positiveInteger(process.env.RATE_LIMIT_PER_MINUTE, 30);

if (isProduction && (!appToken || appToken.length < 32)) {
  throw new Error('NORI_APP_TOKEN must contain at least 32 characters when NODE_ENV=production');
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

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

const json = (response, status, payload, requestId = randomUUID()) => {
  const headers = {
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Request-Id': requestId,
  };
  if (allowedOrigin) {
    headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, X-User-Id';
    headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
    headers['Access-Control-Allow-Origin'] = allowedOrigin;
    headers.Vary = 'Origin';
  }
  response.writeHead(status, headers);
  response.end(JSON.stringify(payload));
};

const readBody = async (request) => {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 128_000) throw new HttpError(413, 'Request body is too large');
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
  } catch {
    throw new HttpError(400, 'Request body must be valid JSON');
  }
};

export const isAuthorizedValue = (authorization, expectedToken = appToken) => {
  if (!expectedToken) return true;
  if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) return false;
  const received = Buffer.from(authorization.slice(7));
  const expected = Buffer.from(expectedToken);
  return received.length === expected.length && timingSafeEqual(received, expected);
};

const authorized = (request) => {
  if (!appToken) return true;
  return isAuthorizedValue(request.headers.authorization);
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

const cleanString = (value, field, maxLength, required = false) => {
  if (value == null && !required) return '';
  if (typeof value !== 'string') throw new HttpError(400, `${field} must be a string`);
  const clean = value.trim();
  if (required && !clean) throw new HttpError(400, `${field} is required`);
  if (clean.length > maxLength) throw new HttpError(400, `${field} is too long`);
  return clean;
};

export const validateAction = (input) => {
  if (!input || typeof input !== 'object') throw new HttpError(400, 'A valid action is required');
  const id = cleanString(input.id, 'action.id', 128, true);
  if (input.kind === 'email') {
    const to = cleanString(input.to, 'action.to', 320, true).replace(/[\r\n]/g, ' ');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) throw new HttpError(400, 'action.to must be a valid email address');
    return {
      id,
      kind: 'email',
      to,
      subject: cleanString(input.subject || 'Quick follow-up', 'action.subject', 200, true).replace(/[\r\n]/g, ' '),
      body: cleanString(input.body, 'action.body', 20_000),
    };
  }
  if (input.kind === 'calendar' || input.kind === 'meeting') {
    const start = new Date(input.start);
    if (Number.isNaN(start.getTime())) throw new HttpError(400, 'action.start must be a valid date');
    const durationMinutes = Number(input.durationMinutes);
    if (!Number.isInteger(durationMinutes) || durationMinutes < 15 || durationMinutes > 480) {
      throw new HttpError(400, 'action.durationMinutes must be a whole number between 15 and 480');
    }
    const attendees = Array.isArray(input.attendees) ? input.attendees.slice(0, 50).map((email) => cleanString(email, 'attendee', 320, true)) : [];
    if (attendees.some((email) => !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) throw new HttpError(400, 'attendees must contain valid email addresses');
    return {
      id,
      kind: input.kind,
      title: cleanString(input.title, 'action.title', 300, true),
      start: start.toISOString(),
      durationMinutes,
      notes: cleanString(input.notes, 'action.notes', 5_000),
      attendees,
    };
  }
  throw new HttpError(400, 'Only calendar, meeting, and email actions can be executed');
};

const planWithOpenAi = async (request, body) => {
  if (!openAiApiKey) throw new Error('OPENAI_API_KEY is not configured');
  const message = cleanString(body.message, 'message', 4_000, true);
  if (body.context?.tasks?.length > 200 || body.context?.calendar?.length > 200) throw new HttpError(400, 'Assistant context is too large');
  const apiResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openAiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: openAiModel,
      instructions: assistantInstructions,
      input: JSON.stringify({ message, context: body.context }),
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
    signal: AbortSignal.timeout(requestTimeoutMs),
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
    signal: AbortSignal.timeout(requestTimeoutMs),
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
    signal: AbortSignal.timeout(requestTimeoutMs),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error?.message || 'Calendar event creation failed');
  return { id: payload.id, link: payload.htmlLink, provider: 'google-calendar' };
};

const executeEmail = async (action) => {
  const token = await googleAccessToken();
  const message = [
    `To: ${action.to}`,
    `Subject: ${action.subject}`,
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
    signal: AbortSignal.timeout(requestTimeoutMs),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error?.message || 'Email send failed');
  return { id: payload.id, threadId: payload.threadId, provider: 'gmail' };
};

const executionReceipts = new Map();
const executionPromises = new Map();
const receiptTtlMs = 24 * 60 * 60_000;

const cachedReceipt = (id) => {
  const cached = executionReceipts.get(id);
  if (!cached) return undefined;
  if (cached.expiresAt <= Date.now()) {
    executionReceipts.delete(id);
    return undefined;
  }
  return cached.receipt;
};

const storeReceipt = (id, receipt) => {
  if (executionReceipts.size >= 1_000) {
    executionReceipts.delete(executionReceipts.keys().next().value);
  }
  executionReceipts.set(id, { receipt, expiresAt: Date.now() + receiptTtlMs });
};

const executeAction = async (body) => {
  if (!body || typeof body !== 'object') throw new HttpError(400, 'A valid request is required');
  if (body.approved !== true) throw new HttpError(400, 'Explicit approval is required');
  const action = validateAction(body.action);
  const existingReceipt = cachedReceipt(action.id);
  if (existingReceipt) return existingReceipt;
  const existingPromise = executionPromises.get(action.id);
  if (existingPromise) return existingPromise;
  const execution = (async () => {
    let receipt;
    if (action.kind === 'calendar' || action.kind === 'meeting') receipt = await executeCalendar(action);
    else if (action.kind === 'email') receipt = await executeEmail(action);
    storeReceipt(action.id, receipt);
    return receipt;
  })();
  executionPromises.set(action.id, execution);
  try {
    return await execution;
  } finally {
    executionPromises.delete(action.id);
  }
};

const rateLimits = new Map();

const rateLimited = (request) => {
  const identity = request.socket.remoteAddress || 'anonymous';
  const key = createHash('sha256').update(identity).digest('hex');
  const now = Date.now();
  if (rateLimits.size > 1_000) {
    for (const [candidate, entry] of rateLimits) {
      if (entry.resetAt <= now) rateLimits.delete(candidate);
    }
  }
  const current = rateLimits.get(key);
  if (!current || current.resetAt <= now) {
    rateLimits.set(key, { count: 1, resetAt: now + rateLimitWindowMs });
    return false;
  }
  current.count += 1;
  return current.count > rateLimitMax;
};

const server = createServer(async (request, response) => {
  const requestId = randomUUID();
  if (request.method === 'OPTIONS') return json(response, 204, {}, requestId);
  const url = new URL(request.url || '/', `http://${request.headers.host || 'localhost'}`);
  if (request.method === 'GET' && url.pathname === '/health') {
    return json(response, 200, { status: 'ok' }, requestId);
  }
  if (request.method === 'GET' && url.pathname === '/ready') {
    const googleConfigured = Boolean(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET && process.env.GOOGLE_REFRESH_TOKEN);
    const ready = Boolean(openAiApiKey && (!isProduction || appToken));
    return json(response, ready ? 200 : 503, {
      status: ready ? 'ready' : 'not_ready',
      capabilities: { assistant: Boolean(openAiApiKey), google: googleConfigured },
    }, requestId);
  }
  if (!authorized(request)) return json(response, 401, { error: 'Unauthorized', requestId }, requestId);
  if (rateLimited(request)) return json(response, 429, { error: 'Rate limit exceeded', requestId }, requestId);
  if (request.method === 'POST' && !String(request.headers['content-type'] || '').toLowerCase().startsWith('application/json')) {
    return json(response, 415, { error: 'Content-Type must be application/json', requestId }, requestId);
  }

  try {
    if (request.method === 'POST' && url.pathname === '/assistant') {
      const body = await readBody(request);
      return json(response, 200, await planWithOpenAi(request, body), requestId);
    }
    if (request.method === 'POST' && url.pathname === '/execute') {
      return json(response, 200, { receipt: await executeAction(await readBody(request)) }, requestId);
    }
    return json(response, 404, { error: 'Not found', requestId }, requestId);
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 502;
    const publicMessage = error instanceof HttpError || !isProduction ? error.message : 'Upstream request failed';
    process.stderr.write(`${JSON.stringify({ level: 'error', requestId, status, message: error instanceof Error ? error.message : 'Request failed' })}\n`);
    return json(response, status, { error: publicMessage, requestId }, requestId);
  }
});

server.requestTimeout = requestTimeoutMs + 5_000;
server.headersTimeout = 10_000;
server.keepAliveTimeout = 5_000;

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  server.listen(port, host, () => {
    process.stdout.write(`Nori server listening on http://${host}:${port}\n`);
  });
  const shutdown = () => server.close(() => process.exit(0));
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}
