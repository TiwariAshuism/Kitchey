Here's what's pending to get Kitzz running end-to-end on your machine:

### Must Do (Blocking)

| # | Task | Command/Action |
|---|------|----------------|
| 1 | **Install Docker Desktop** | If not installed already |
| 2 | **Start Postgres + Redis** | `docker-compose up -d` |
| 3 | **Run database migrations** | `make migrate-up` |
| 4 | **Start backend** | `make run` |
| 5 | **Start Alexa skill local server** | `cd alexa-skill && npm start` |
| 6 | **Flutter pub get** | `cd frontend && flutter pub get` |
| 7 | **Run Flutter app** | `cd frontend && flutter run` |
| 8 | **Install ngrok** | `choco install ngrok` (Win) / `brew install ngrok` (mac) |
| 9 | **Expose backend (one tunnel only)** | `ngrok http 8080` |
| 10 | **Amazon Developer account** | Sign up at developer.amazon.com (free) |
| 11 | **Create Alexa skill** | Paste interaction model + set endpoint |
| 12 | **Configure Account Linking** | Set OAuth URLs in Alexa console |
| 13 | **Enable skill on your Echo** | Via Alexa app → Skills → Dev |

### One ngrok tunnel covers both servers

ngrok's free plan only allows a single HTTP tunnel. The Go backend on
`:8080` reverse-proxies `/alexa` to the Node skill server on `:3000`, so
one tunnel exposes the whole stack:

| Public URL (via ngrok)                | Routed to                       | Used by                  |
|---------------------------------------|---------------------------------|--------------------------|
| `https://<ngrok>.app/oauth/authorize` | Go backend `:8080`              | Alexa account linking    |
| `https://<ngrok>.app/oauth/token`     | Go backend `:8080`              | Alexa account linking    |
| `https://<ngrok>.app/api/...`         | Go backend `:8080`              | Flutter app              |
| `https://<ngrok>.app/alexa`           | Node skill server `:3000` (POST `/`) | Alexa skill endpoint |

Plug these into the Alexa Developer Console:

- **Endpoint → HTTPS → Default region** → `https://<ngrok>.app/alexa`
- **Account Linking → Authorization URI** → `https://<ngrok>.app/oauth/authorize`
- **Account Linking → Access Token URI** → `https://<ngrok>.app/oauth/token`

Override the upstream by setting `ALEXA_SKILL_URL` in `.env` if the Node
server runs on a non-default host or port (default is
`http://localhost:3000`).

### Should Do (Important but not blocking basic test)

| # | Task | Why |
|---|------|-----|
| 1 | **Add Firebase project** | For push notifications to phone |
| 2 | **Add `google-services.json`** | Android FCM config |
| 3 | **Add `GoogleService-Info.plist`** | iOS FCM config |
| 4 | **Set `OAUTH_CLIENT_SECRET`** in backend `.env` | Secure the account linking |
| 5 | **Fix OAuth token endpoint** | Currently returns simplified tokens, needs proper JWT |

### Can Skip For Now

- App icons/splash screens
- Play Store / App Store listings
- Privacy policy
- Production Docker setup
- Unit tests
- Subscription/payments

### Quick Start (minimum commands to test):

```bash
# Terminal 1 — Infrastructure
docker-compose up -d

# Terminal 2 — Backend (Go, :8080)
make migrate-up
make run

# Terminal 3 — Alexa skill (Node, :3000)
cd alexa-skill && npm install && npm start

# Terminal 4 — Flutter app
cd frontend && flutter pub get && flutter run

# Terminal 5 — Single ngrok tunnel for everything
ngrok http 8080
```

After that it's all Alexa Developer Console configuration (no more code
needed).
