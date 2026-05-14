const { SOUNDS, ssml, pause, getRandomItem, GOODBYES } = require('../utils/speech');

const HelpIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'AMAZON.HelpIntent'
        );
    },
    handle(handlerInput) {
        const speech = ssml(
            `Here's what you can do with Rasoi. ${pause(300)}` +
            `Say something like ${pause(100)}"tell my family dinner is ready" ${pause(200)}to send a message. ${pause(300)}` +
            `Say ${pause(100)}"check messages" ${pause(200)}to hear replies from your family. ${pause(300)}` +
            `Say ${pause(100)}"what did I say last" ${pause(200)}to hear your last message. ${pause(300)}` +
            `And you can always say ${pause(100)}"add more" ${pause(200)}to send a follow-up. ${pause(300)}` +
            `What would you like to do?`
        );

        return handlerInput.responseBuilder
            .speak(speech)
            .reprompt('Say your message, check replies, or say stop to exit.')
            .getResponse();
    },
};

const CancelAndStopIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            (handlerInput.requestEnvelope.request.intent.name === 'AMAZON.CancelIntent' ||
                handlerInput.requestEnvelope.request.intent.name === 'AMAZON.StopIntent')
        );
    },
    handle(handlerInput) {
        const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
        const messageCount = sessionAttributes.messageCount || 0;
        const goodbye = getRandomItem(GOODBYES);

        let speech;
        if (messageCount > 0) {
            const plural = messageCount === 1 ? 'message' : 'messages';
            speech = ssml(
                `${SOUNDS.GOODBYE}${pause(200)}` +
                `You sent ${messageCount} ${plural} today. ${pause(200)}${goodbye}`
            );
        } else {
            speech = ssml(`${SOUNDS.GOODBYE}${pause(200)}${goodbye}`);
        }

        return handlerInput.responseBuilder
            .speak(speech)
            .withShouldEndSession(true)
            .getResponse();
    },
};

const FallbackIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'AMAZON.FallbackIntent'
        );
    },
    handle(handlerInput) {
        const speech = ssml(
            `Hmm, I didn't get that. ${pause(200)}` +
            `Try saying something like "send a message dinner is ready" ${pause(200)}` +
            `or "check my messages". ${pause(200)}What would you like to do?`
        );

        return handlerInput.responseBuilder
            .speak(speech)
            .reprompt('Say the message you want to send, or say help for more options.')
            .getResponse();
    },
};

// Repeat the last thing Alexa said
const RepeatIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'AMAZON.RepeatIntent'
        );
    },
    handle(handlerInput) {
        const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
        const lastSpeech = sessionAttributes.lastSpeechOutput;

        if (lastSpeech) {
            return handlerInput.responseBuilder
                .speak(lastSpeech)
                .reprompt('What would you like to do?')
                .getResponse();
        }

        return handlerInput.responseBuilder
            .speak("I don't have anything to repeat. What would you like to do?")
            .reprompt('Say your message, or say help.')
            .getResponse();
    },
};

// "What did I say last?" — recall the last sent message
const LastMessageIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'LastMessageIntent'
        );
    },
    handle(handlerInput) {
        const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
        const lastMessage = sessionAttributes.lastMessage;

        if (lastMessage) {
            const speech = ssml(
                `Your last message was: ${pause(200)}"${lastMessage}"${pause(300)} ` +
                `Would you like to send another?`
            );
            return handlerInput.responseBuilder
                .speak(speech)
                .reprompt('Say your next message, or say stop to exit.')
                .getResponse();
        }

        return handlerInput.responseBuilder
            .speak("You haven't sent any messages yet this session. What would you like to say?")
            .reprompt('Go ahead, say your message.')
            .getResponse();
    },
};

const SessionEndedRequestHandler = {
    canHandle(handlerInput) {
        return handlerInput.requestEnvelope.request.type === 'SessionEndedRequest';
    },
    handle(handlerInput) {
        const reason = handlerInput.requestEnvelope.request.reason;
        if (reason === 'ERROR') {
            console.error('Session ended with error:', handlerInput.requestEnvelope.request.error);
        }
        console.log(`Session ended: ${reason}`);
        return handlerInput.responseBuilder.getResponse();
    },
};

// AMAZON.YesIntent — context-aware yes handler
const YesIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'AMAZON.YesIntent'
        );
    },
    handle(handlerInput) {
        // User said yes — prompt them to say their message
        return handlerInput.responseBuilder
            .speak('Great! Go ahead, say your message.')
            .reprompt('What message would you like to send?')
            .getResponse();
    },
};

// AMAZON.NoIntent — polite exit when user says no
const NoIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'AMAZON.NoIntent'
        );
    },
    handle(handlerInput) {
        const goodbye = getRandomItem(GOODBYES);
        return handlerInput.responseBuilder
            .speak(ssml(`${SOUNDS.GOODBYE}${pause(200)}${goodbye}`))
            .withShouldEndSession(true)
            .getResponse();
    },
};

module.exports = {
    HelpIntentHandler,
    CancelAndStopIntentHandler,
    FallbackIntentHandler,
    RepeatIntentHandler,
    LastMessageIntentHandler,
    YesIntentHandler,
    NoIntentHandler,
    SessionEndedRequestHandler,
};
