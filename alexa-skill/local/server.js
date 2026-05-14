const fs = require('fs');
const path = require('path');

function findRepoRoot(startDir) {
    let dir = path.resolve(startDir);
    for (let i = 0; i < 12; i += 1) {
        if (fs.existsSync(path.join(dir, 'docker-compose.yml'))) {
            return dir;
        }
        const parent = path.dirname(dir);
        if (parent === dir) {
            break;
        }
        dir = parent;
    }
    return path.resolve(__dirname, '..', '..');
}

require('dotenv').config({ path: path.join(findRepoRoot(__dirname), '.env') });

const express = require('express');
const Alexa = require('ask-sdk-core');
const LaunchRequestHandler = require('../lambda/handlers/LaunchHandler');
const SendMessageIntentHandler = require('../lambda/handlers/MessageHandler');
const ContinueMessageIntentHandler = require('../lambda/handlers/ContinueHandler');
const CheckRepliesIntentHandler = require('../lambda/handlers/CheckRepliesHandler');
const {
    HelpIntentHandler,
    CancelAndStopIntentHandler,
    FallbackIntentHandler,
    RepeatIntentHandler,
    LastMessageIntentHandler,
    YesIntentHandler,
    NoIntentHandler,
    SessionEndedRequestHandler,
} = require('../lambda/handlers/CommonHandlers');
const ErrorHandler = require('../lambda/handlers/ErrorHandler');

const app = express();
app.use(express.json());

// --- Interceptors (same as lambda/index.js) ---

const RequestLogger = {
    process(handlerInput) {
        const request = handlerInput.requestEnvelope.request;
        console.log(`[REQ] ${request.type}${request.intent ? ` / ${request.intent.name}` : ''}`);
    },
};

const ResponseLogger = {
    process(handlerInput, response) {
        if (response) {
            const speech = response.outputSpeech?.ssml || response.outputSpeech?.text || '';
            const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
            sessionAttributes.lastSpeechOutput = speech;
            handlerInput.attributesManager.setSessionAttributes(sessionAttributes);
            console.log(`[RES] Speech length: ${speech.length} chars`);
        }
    },
};

const skill = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        SendMessageIntentHandler,
        ContinueMessageIntentHandler,
        CheckRepliesIntentHandler,
        LastMessageIntentHandler,
        RepeatIntentHandler,
        YesIntentHandler,
        NoIntentHandler,
        HelpIntentHandler,
        CancelAndStopIntentHandler,
        FallbackIntentHandler,
        SessionEndedRequestHandler
    )
    .addErrorHandlers(ErrorHandler)
    .addRequestInterceptors(RequestLogger)
    .addResponseInterceptors(ResponseLogger)
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
