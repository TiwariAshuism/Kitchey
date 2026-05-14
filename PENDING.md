# Kitzz — Pending Tasks

## Backend
- [ ] Run `docker-compose up -d` and verify Postgres + Redis start
- [ ] Run `make migrate-up` to apply all 5 migrations
- [ ] Run `make run` and test `/health` endpoint
- [ ] Test auth endpoints: register, login, refresh
- [ ] Add proper JWT-based OAuth2 token generation (currently simplified in `oauth_handler.go`)
- [ ] Add Alexa request signature validation middleware
- [ ] Add structured JSON logging (replace default `log` calls)
- [ ] Add input sanitization for transcript field
- [ ] Add 30-day message auto-delete cron job
- [ ] Add `GET /api/auth/data-export` endpoint
- [ ] Add `PUT /api/subscription/extend` admin endpoint
- [ ] Write unit tests for auth_service, message_service, device_service

## Flutter
- [ ] Run `flutter pub get` to install dependencies
- [ ] Add Firebase project config (`google-services.json` for Android, `GoogleService-Info.plist` for iOS)
- [ ] Implement FCM initialization and token sync in `main.dart`
- [ ] Implement foreground + background notification handlers
- [ ] Implement notification tap deep linking to specific message
- [ ] Wire `MessageDetailScreen` to fetch message from repository
- [ ] Build device pairing BLoC + connect to `DeviceListScreen`
- [ ] Implement Alexa account linking webview in device pairing flow
- [ ] Add subscription status banner on inbox screen
- [ ] Configure APNs for iOS push notifications
- [ ] Remove unused `_baseUrlKey` constant in `api_client.dart`
- [ ] Make API base URL configurable per environment (dev/staging/prod)

## Alexa Skill
- [ ] Scaffold `alexa-skill/` Node.js project
- [ ] Implement LaunchHandler, MessageHandler, ContinueHandler
- [ ] Create interaction model (`en-IN` + `en-US`)
- [ ] Configure account linking in `skill.json`
- [ ] Set up local testing with Express wrapper + ngrok
- [ ] Submit for Amazon certification

## Launch Prep
- [ ] App icons and splash screens (Android + iOS)
- [ ] Privacy policy page (static HTML)
- [ ] Play Store listing + internal testing track
- [ ] App Store listing + TestFlight
- [ ] Multi-stage Dockerfile for Go backend
- [ ] Docker Compose production profile
