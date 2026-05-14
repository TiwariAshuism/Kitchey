# Kitzz — Production & Scale Features Roadmap

## Phase 1: Core Hardening (Before Launch)

### Security
- [ ] Alexa request signature verification (validate requests actually come from Amazon)
- [ ] Rate limiting per user (not just per IP)
- [ ] Input sanitization on all transcript/reply text (XSS, SQL injection)
- [ ] Proper OAuth2 token generation with JWT (replace simplified version)
- [ ] HTTPS everywhere — enforce TLS 1.3
- [ ] Secrets management (AWS Secrets Manager / HashiCorp Vault, not .env files)
- [ ] CORS lockdown — whitelist specific origins only
- [ ] JWT token rotation — invalidate old refresh tokens on use
- [ ] Password policy enforcement (min 8 chars, complexity check)
- [ ] Brute force protection — account lockout after 5 failed attempts

### Reliability
- [ ] Health check endpoint with dependency checks (Postgres, Redis, FCM)
- [ ] Graceful degradation when Redis is down (skip rate limiting, don't crash)
- [ ] Database connection pooling tuning (min/max connections, idle timeout)
- [ ] Request timeout middleware (kill slow requests after 30s)
- [ ] Circuit breaker for FCM calls (don't block if Firebase is down)
- [ ] Retry logic with exponential backoff for push notifications
- [ ] Database query timeouts (context with deadline)

### Data Integrity
- [ ] Database transactions for multi-table operations (register + create subscription)
- [ ] Idempotency keys on message creation (prevent duplicates from Alexa retries)
- [ ] Soft delete everywhere (users, messages, devices) — never hard delete
- [ ] Audit log table — track who did what and when

---

## Phase 2: User Experience (First Month)

### Notifications
- [ ] Rich push notifications with sender name + preview text
- [ ] Notification grouping — stack multiple messages from same sender
- [ ] Notification tap deep links to specific message
- [ ] Silent push for background data sync
- [ ] Notification preferences — per-device mute, quiet hours
- [ ] iOS critical alerts support (for urgent kitchen messages)

### Messaging
- [ ] Message reactions (❤️ 👍 😂) — lightweight response without typing
- [ ] Message forwarding — share a kitchen message with someone not on the app
- [ ] Read receipts — sender sees "Delivered" → "Read" on Alexa status
- [ ] Message search — full-text search across all messages
- [ ] Pinned messages — pin important ones to top of inbox
- [ ] Message categories — auto-tag: "Food", "Reminder", "General"

### Family Management
- [ ] Family groups — create a family, invite members via link/QR code
- [ ] Family roles — Admin (can manage devices), Member (receive only)
- [ ] Per-device routing — "Kitchen Echo sends to everyone, Bedroom Echo sends to parents only"
- [ ] Family member profiles with avatars
- [ ] Invite flow — share link via WhatsApp/SMS, one-tap join

### Alexa Enhancements
- [ ] Multi-language support — Hindi, Tamil, Telugu (not just English)
- [ ] Voice profiles — Alexa recognizes who is speaking, tags the message
- [ ] Sound effects — play a pleasant chime when reply is read
- [ ] Scheduled messages — "Alexa, tell Kitzz to remind everyone at 7 PM dinner is ready"
- [ ] Message priority — "urgent" keyword triggers high-priority notification
- [ ] Alexa proactive events — Alexa announces replies without being opened

---

## Phase 3: Scale & Infrastructure (Months 2-3)

### Backend Scale
- [ ] Horizontal scaling — stateless backend behind load balancer
- [ ] Database read replicas — route GET queries to replica
- [ ] Connection pooling with PgBouncer
- [ ] Redis Cluster for rate limiting and caching
- [ ] Message queue (RabbitMQ / SQS) for async notification delivery
- [ ] Background workers — decouple FCM sending from HTTP request
- [ ] CDN for static assets (OAuth login page, etc.)
- [ ] API versioning — /api/v1/, /api/v2/

### Database
- [ ] Table partitioning on messages (by month) — queries stay fast at scale
- [ ] Archival strategy — move messages older than 90 days to cold storage
- [ ] Database indexing review — EXPLAIN ANALYZE on all common queries
- [ ] Auto-vacuum tuning for high-write tables
- [ ] Point-in-time recovery backups (every 15 minutes)
- [ ] Read-only replica for analytics queries

### Caching
- [ ] Cache user profiles in Redis (invalidate on update)
- [ ] Cache device pairings (rarely change, frequently queried)
- [ ] Cache subscription status (check once per hour, not every request)
- [ ] HTTP response caching headers for GET endpoints
- [ ] Stale-while-revalidate pattern for non-critical data

### Observability
- [ ] Structured JSON logging (zerolog or zap, not default log)
- [ ] Request ID propagation (X-Request-ID header through all layers)
- [ ] Distributed tracing (OpenTelemetry → Jaeger/Tempo)
- [ ] Metrics (Prometheus) — request latency, error rates, queue depth
- [ ] Alerting (PagerDuty/Grafana) — error spike, high latency, DB connection pool exhaustion
- [ ] Dashboard — Grafana with key business + infra metrics
- [ ] Error tracking (Sentry) — capture panics with stack traces
- [ ] Uptime monitoring — external ping every 60s

---

## Phase 4: Monetization (Month 3+)

### Subscription
- [ ] Stripe/Razorpay integration for payments
- [ ] Plans: Free (5 messages/day), Pro (unlimited, ₹99/month), Family (₹199/month, 10 members)
- [ ] Trial to paid conversion flow — gentle nudges, not hard blocks
- [ ] Subscription webhook handling (payment success, failure, cancellation)
- [ ] Grace period — 3 days after expiry before blocking
- [ ] Annual plan discount (₹999/year = 2 months free)
- [ ] In-app purchase for iOS (Apple requires IAP for digital goods)
- [ ] Receipt validation server-side (prevent fake purchases)

### Growth
- [ ] Referral system — "Invite a family, get 1 month free"
- [ ] Share card — beautiful image card of a message, shareable to Instagram/WhatsApp
- [ ] App Store rating prompt — after 10 messages, ask for review
- [ ] Onboarding tutorial — interactive walkthrough on first launch
- [ ] Email onboarding sequence — Day 1, 3, 7 tips

---

## Phase 5: Platform Expansion (Months 4-6)

### Multi-Platform
- [ ] Web app (Flutter Web) — view messages from browser
- [ ] Google Home / Nest Hub support (Google Actions)
- [ ] Apple HomePod support (if API available)
- [ ] Wear OS widget — see latest message on smartwatch
- [ ] iOS widget — latest message on home screen (WidgetKit)
- [ ] Android widget — same

### Smart Features
- [ ] AI summary — "Today: 3 messages about dinner, 1 reminder"
- [ ] Smart reply suggestions — ML-powered quick replies based on message content
- [ ] Sentiment analysis — emoji mood indicator on messages
- [ ] Daily digest — optional end-of-day summary notification
- [ ] Recipe detection — if message mentions a dish, show recipe link
- [ ] Auto-translate — family members in different countries get messages in their language

### Integrations
- [ ] Google Calendar — "dinner at 7" auto-creates calendar event
- [ ] Grocery list sync — "we need milk" adds to shared grocery list (Google Keep / Todoist)
- [ ] WhatsApp bridge — forward kitchen messages to WhatsApp group (for non-app family)
- [ ] Zapier/IFTTT webhooks — trigger automations from kitchen messages

---

## Phase 6: Enterprise / B2B (Month 6+)

### Multi-Tenant
- [ ] Restaurant use case — kitchen speaks to waitstaff devices
- [ ] Office pantry — "Coffee is ready" to the floor
- [ ] Elderly care — simple voice messages from grandparents to family
- [ ] School cafeteria — menu announcements to parents

### Admin
- [ ] Admin dashboard (web) — user management, analytics, support
- [ ] Usage analytics — messages/day, active users, retention curves
- [ ] Content moderation — flag inappropriate messages (ML + manual review)
- [ ] Customer support — in-app chat or ticket system
- [ ] A/B testing framework — test different flows, copy, features

---

## Non-Functional Requirements (Always)

| Requirement | Target |
|-------------|--------|
| API response time | p95 < 200ms |
| Push notification delivery | < 3 seconds |
| Uptime | 99.9% (8.7 hours downtime/year) |
| App cold start | < 2 seconds |
| Database query time | p95 < 50ms |
| Concurrent users | 10,000+ |
| Message throughput | 1,000 messages/minute |
| Data retention | 90 days (free), unlimited (pro) |
| Backup RPO | 15 minutes |
| Backup RTO | 1 hour |

---

## Tech Debt to Address

- [ ] Unit tests — auth, message, device services (aim for 80% coverage)
- [ ] Integration tests — API endpoint tests with test database
- [ ] E2E tests — Flutter integration tests for critical flows
- [ ] CI/CD pipeline — GitHub Actions: lint → test → build → deploy
- [ ] Multi-stage Docker build — smaller production images
- [ ] Database migration strategy — zero-downtime migrations
- [ ] API documentation — OpenAPI/Swagger spec auto-generated
- [ ] Dependency audit — automated vulnerability scanning (Dependabot/Snyk)
- [ ] Code signing — Android keystore + iOS certificates managed properly
- [ ] Feature flags — LaunchDarkly or custom — toggle features without deployment
