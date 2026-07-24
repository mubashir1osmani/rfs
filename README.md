# Nori — autonomous personal assistant

Nori is an Expo / React Native assistant for students and working professionals. It turns natural language into tasks, protected focus time, meeting invites, and reviewable email drafts.

## Run

Use Node.js 20.19.4 or newer.

```bash
npm install
npm run ios
```

For a clean demo session, run `npm run demo`, open the app, and tap **Watch a 20-second action demo** on Home.

To verify the project:

```bash
npm run typecheck
npm run test:server
npm run build:ios
```

## Assistant capabilities

- Converts natural language into tasks and adds safe local actions automatically.
- Plans a day around open priorities and proposes multiple time blocks.
- Creates Google Calendar events with titles, times, durations, notes, and guests.
- Builds meeting invites from requests such as `Book a 30 minute meeting with alex@example.com tomorrow at 3 PM`.
- Produces reviewable email drafts and sends approved messages through Gmail.
- Supports spoken requests through iOS keyboard dictation.
- Keeps all external communication behind a visible approval boundary.

The app includes a deterministic local planner and native Calendar/Mail handoffs, so every workflow remains demonstrable without an account or API key.

## Run the AI and Google backend

The repository includes a dependency-free Node server using the OpenAI Responses API, structured action outputs, Google Calendar API, and Gmail API.

```bash
cp .env.example .env
# Fill in the server credentials in .env
npm run server:env
```

In a second terminal, start the app with the same `.env` file:

```bash
npm start
```

`OPENAI_API_KEY` enables model-backed planning. Without it, the mobile app automatically uses its local planner. `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `GOOGLE_REFRESH_TOKEN` enable direct execution; without them, the app opens Google Calendar or Mail for manual confirmation.

For Google, authorize these scopes when generating the refresh token:

- `https://www.googleapis.com/auth/calendar.events`
- `https://www.googleapis.com/auth/gmail.send`

Use a LAN or deployed HTTPS server URL instead of `localhost` on a physical iPhone.

## Production integrations

The included server is suitable for a single-user prototype. A multi-user production deployment must:

1. Complete Google OAuth with Calendar and Gmail scopes.
2. Store encrypted refresh tokens per user.
3. Authenticate every mobile request with a user session rather than a public app token.
4. Persist execution receipts and idempotency keys in a database.
5. Preserve the review step for messages, guests, and destructive calendar changes.
