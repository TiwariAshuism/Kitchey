const Alexa = require('ask-sdk-core');
const LaunchRequestHandler = require('./handlers/LaunchHandler');
const SendMessageIntentHandler = require('./handlers/MessageHandler');
const ContinueMessageIntentHandler = require('./handlers/ContinueHandler');
const CheckRepliesIntentHandler = require('./handlers/CheckRepliesHandler');
const {
    HelpIntentHandler,
    CancelAndStopIntentHandler,
    FallbackIntentHandler,
    RepeatIntentHandler,
    LastMessageIntentHandler,
    YesIntentHandler,
    NoIntentHandler,
    SessionEndedRequestHandler,
} = require('./handlers/CommonHandlers');
const ErrorHandler = require('./handlers/ErrorHandler');

// --- Interceptors ---

// Log every incoming request
const RequestLogger = {
    process(handlerInput) {
        const request = handlerInput.requestEnvelope.request;
        console.log(`[REQ] ${request.type}${request.intent ? ` / ${request.intent.name}` : ''}`);
    },
};

// Save every Alexa speech output to session so RepeatIntent works
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

const skillBuilder = Alexa.SkillBuilders.custom();

exports.handler = skillBuilder
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
    .lambda();
