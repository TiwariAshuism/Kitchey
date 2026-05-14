const { SOUNDS, ssml, pause } = require('../utils/speech');

const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        console.error('--- UNHANDLED ERROR ---');
        console.error('Error:', error.message);
        console.error('Stack:', error.stack);
        console.error('Request type:', handlerInput.requestEnvelope.request.type);
        if (handlerInput.requestEnvelope.request.intent) {
            console.error('Intent:', handlerInput.requestEnvelope.request.intent.name);
        }
        console.error('--- END ERROR ---');

        const speech = ssml(
            `${SOUNDS.ERROR}${pause(200)}` +
            `Oops, something went wrong on my end. ${pause(200)}` +
            `Let's try that again. What message would you like to send?`
        );

        return handlerInput.responseBuilder
            .speak(speech)
            .reprompt('Say your message, or say stop to exit.')
            .getResponse();
    },
};

module.exports = ErrorHandler;
