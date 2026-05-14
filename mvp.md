Here's a candid breakdown of what Kitzz involves, what's achievable, and in what order — starting with the most important technical flag.

**Critical constraint to flag first:** Alexa's ASK (Alexa Skills Kit) does not expose the raw audio recording to your skill. You get the text transcript only. The "audio playback" requirement in the PRD needs a workaround strategy — either store a TTS re-synthesis of the transcript, or redesign the feature around transcript-only, or explore Alexa's AudioPlayer interface (limited). This decision gates the GCS/audio architecture.

Here's the system map first, then a phased plan:---

**Tech stack I'd recommend given your background:** Go + Gin for the backend (your home turf), Flutter for mobile (Android first), PostgreSQL on Cloud SQL (GCP), Firebase for FCM, Node.js for the Alexa skill (ASK SDK is Node-only and well-documented). Deploy backend on Cloud Run (auto HTTPS, pay-per-use, scales to zero).

---

## Phase 1 — Backend foundation (weeks 1–4)

This is the core of the product. Build it first because everything else plugs into it.

The Go backend should be structured in hexagonal architecture (which you already know well): a `domain` layer for users, devices, messages, subscriptions; a `ports` layer for the Alexa webhook handler, FCM trigger, and subscription checker; and `adapters` for PostgreSQL, GCS, and Firebase. Start with just three tables: `users`, `device_pairings` (device_id → user_id), and `messages` (transcript + audio URL + timestamps). Subscription and plan tables come in phase 3.

Ship a working auth system first — registration, login, JWT issuance with refresh tokens, and a `/health` endpoint. Get it deployed on Cloud Run with a real domain and HTTPS (Cloud Run gives you this for free). This public HTTPS URL is a hard dependency for Alexa — you can't test the skill at all without it.

**Deliverable:** A live HTTPS Go server with `/api/auth/register`, `/api/auth/login`, and `/api/message/incoming` (stub). Firebase project created, FCM server key in hand.

---

## Phase 2 — Alexa skill + account linking (weeks 5–8)

This is the trickiest part of the whole product and deserves its own phase. The Alexa skill has a certification process that can take 2–4 weeks, so you want to submit early.

Build the skill in Node.js using the ASK SDK. The skill needs a single `LaunchRequest` handler that opens a long listening window using `Dialog.ElicitSlot` with a large `AMAZON.SearchQuery` slot — this is how you capture free-form speech up to ~30 seconds per turn. For the 90–180 second requirement, you'll need to chain sessions, which means the skill needs to recognise a continuation intent and stitch transcripts on the backend. This is doable but not trivial.

Account linking uses OAuth 2.0 Authorization Code flow. You'll build a `/oauth/authorize` and `/oauth/token` endpoint in Go that Alexa calls when a user enables the skill. The user logs into your Kitzz web page (or a simple webview in the app), gets redirected back with an auth code, your server exchanges it for an access token, and from that point every Alexa request carries that token in the `accessToken` field — that's how you identify the user on the backend.

The `device_id` is available in every request as `context.System.device.deviceId`. This is the key that maps Echo Dot → registered user → recipient phone.

**Deliverable:** Skill deployed on your developer account, account linking working in the Alexa app, transcript POSTed to your backend with valid token and device ID. Submit for certification.

---

## Phase 3 — Message pipeline end-to-end (weeks 9–12)

With the skill posting to your backend and the device mapping in place, build the full message routing loop:

The `/api/message/incoming` handler validates the JWT, checks subscription status, looks up `device_pairings` to find the recipient user ID, saves the transcript to `messages`, then calls Firebase FCM with the recipient's push token. The FCM payload should carry the transcript text and a message ID (the Flutter app fetches the full message on open).

For the audio constraint: at this stage, decide your strategy. The pragmatic path is to have your backend call a TTS API (Google Cloud TTS or AWS Polly) to synthesise the transcript back into speech, store that MP3 in GCS, and serve it via a signed URL that expires in 24 hours. This isn't the original sender's voice, but it lets you ship the "play" feature while the audio API constraint exists. Put a flag in the UI ("voice reconstructed") and revisit if Alexa ever exposes raw audio through future APIs. The alternative — transcript-only — is simpler but weakens the product.

Rate limiting: use a Redis-backed token bucket per `device_id` (5 messages per minute should be safe for kitchen use). Cloud Memorystore is the managed option on GCP.

**Deliverable:** Full pipeline working — speak into Echo Dot, receive push notification on Android test device with transcript and playable audio. End-to-end latency should be under 5 seconds.

---

## Phase 4 — Flutter app (weeks 9–14, overlapping Phase 3)

Android is priority. The app has four core screens: register/login, the Alexa account linking webview, a message inbox, and settings.

The inbox is the most important screen. Use BLoC for state management (your existing pattern). The `MessageBloc` has three states: loading, loaded (list of messages), and error. Each message tile shows sender label (device name or custom nickname), timestamp, transcript preview, and a play button. Tapping play downloads the signed audio URL and plays it with `just_audio`.

FCM integration in Flutter: `firebase_messaging` package handles foreground and background notifications. Background message handling needs a top-level Dart function (not a closure) — a common gotcha. When a notification arrives and the app is closed, tapping it should deep link directly to the relevant message.

Secure token storage: use `flutter_secure_storage` (uses Keystore on Android, Keychain on iOS). Never use `SharedPreferences` for the JWT.

**Deliverable:** Working Android APK installable via direct download (before Play Store submission). Covers register, link Alexa, receive messages, play audio, view history.

---

## Phase 5 — Subscription management (weeks 13–15)

Build this on the backend first, then surface it in the app. The data model: a `subscriptions` table with `user_id`, `plan_id`, `status` (active/expired/trial), `expires_at`. Every call to `/api/message/incoming` checks `status = active AND expires_at > NOW()` before processing.

For the payment layer at MVP, Razorpay is the pragmatic choice for India (supports UPI, cards, subscriptions). You don't need to build a full billing portal — just a webhook handler that Razorpay calls when a payment succeeds or fails, updating the subscription row accordingly.

Trial periods: set `status = trial`, `expires_at = now + 14 days` on registration. After expiry, the backend rejects messages and sends a FCM push prompting renewal.

---

## Phase 6 — Security hardening + launch (weeks 16–18)

Before production: validate that every Alexa request signature is from Amazon (the ASK SDK does this if you enable `verifyApplicationId` and `verifyTimestamp`). Implement DPDP compliance — an in-app data deletion request endpoint, a clear privacy policy, and ensure your Cloud SQL instance is in `asia-south1` (Mumbai). Audio files in GCS should be encrypted with customer-managed encryption keys (CMEK) or at minimum Google's default server-side encryption.

Submit the Flutter app to the Play Store (internal track first, then production). The Alexa skill should already be in certification from Phase 2 — follow up with Amazon on any feedback.

---

## Realistic timeline

A two-person team (one backend-focused, one mobile-focused) could ship a working MVP in 4–5 months. Solo, you're looking at 6–7 months to something you'd put in front of real users. The Alexa certification clock is the variable you can't control — factor in 3–6 weeks of back-and-forth with Amazon.

The riskiest unknowns in order: (1) Alexa certification getting rejected for UX reasons — mitigate by reading Amazon's certification checklist early, (2) the audio constraint — decide your TTS strategy before building the Flutter audio player so you don't have to redo the UI, (3) latency — GCP asia-south1 is your best bet for Indian users, but end-to-end voice → push involves 3–4 network hops and you should test this aggressively before launch.

Want me to go deep on any specific piece — the Go backend structure, the Flutter BLoC setup, or the Alexa skill implementation?