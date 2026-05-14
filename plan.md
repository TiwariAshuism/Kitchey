The key design decision that makes the bidirectional flow work is the **reply queue pattern**. Alexa can't receive pushes — it's not a connected device waiting for your server to call it. So replies from the mobile app are stored in your database as `status = pending`, and every time someone opens the Kitzz skill, the very first thing Alexa does is fetch and read any queued replies aloud before asking for a new message. This is exactly how voice reply systems like this work in production.

The two flows in simple terms:
- **Alexa → Mobile:** Real-time. Message arrives on phone within 1–2 seconds of speaking.
- **Mobile → Alexa:** Next-session delivery. Reply plays the next time anyone opens the skill in that kitchen.

The biggest external dependency you can't control is **Amazon's certification review** — that's the clock to start immediately. Everything else is fully in your hands with your existing Go + Flutter stack.

Want me to start building a specific piece — the Go backend schema and API, the Alexa skill Node.js code, or the Flutter BLoC structure?