const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const express = require('express');
const Alexa = require('ask-sdk-core');
const LaunchRequestHandler = require('../lambda/handlers/LaunchHandler');
const SendMessageIntentHandler = require('../lambda/handlers/MessageHandler');
const ContinueMessageIntentHandler = require('../lambda/handlers/ContinueHandler');
const {
    HelpIntentHandler,
    CancelAndStopIntentHandler,
    FallbackIntentHandler,
    SessionEndedRequestHandler,
} = require('../lambda/handlers/CommonHandlers');
const ErrorHandler = require('../lambda/handlers/ErrorHandler');

const app = express();
app.use(express.json());

const skill = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        SendMessageIntentHandler,
        ContinueMessageIntentHandler,
        HelpIntentHandler,
        CancelAndStopIntentHandler,
        FallbackIntentHandler,
        SessionEndedRequestHandler
    )
    .addErrorHandlers(ErrorHandler)
    .create();

app.post('/', async (req, res) => {
    try {
        const response = await skill.invoke(req.body);
        res.json(response);
    } catch (error) {
        console.error('Skill invocation error:', error);
        res.status(500).json({ error: 'Skill invocation failed' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'kitzz-alexa-skill' });
});

const PORT = process.env.SKILL_PORT || 3000;
app.listen(PORT, () => {
    const { BACKEND_URL: resolvedBackend } = require('../lambda/utils/api');
    console.log(`Kitzz Alexa Skill local server running on port ${PORT}`);
    console.log(`POST http://localhost:${PORT}/ to invoke the skill`);
    console.log(`Backend URL (Alexa -> Go -> FCM -> phone): ${resolvedBackend}`);
});
