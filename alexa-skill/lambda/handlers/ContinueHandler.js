const { postMessage } = require('../utils/api');
const { SOUNDS, ssml, pause, buildSentResponse } = require('../utils/speech');

// Handles chaining longer messages across multiple turns.
// After sending one message, the user can say "add more" or "continue"
// to append additional content.
const ContinueMessageIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'ContinueMessageIntent'
        );
    },
    async handle(handlerInput) {
        const accessToken = handlerInput.requestEnvelope.context.System.user.accessToken;
        if (!accessToken) {
            return handlerInput.responseBuilder
                .speak(ssml(`Please link your Rasoi account in the Alexa app first.`))
                .withLinkAccountCard()
                .getResponse();
        }

        const deviceId = handlerInput.requestEnvelope.context.System.device.deviceId;
        const messageSlot = handlerInput.requestEnvelope.request.intent.slots.message;
        const transcript = messageSlot && messageSlot.value ? messageSlot.value : null;

        if (!transcript) {
            return handlerInput.responseBuilder
                .speak('What else would you like to add?')
                .reprompt('Go ahead, say the rest of your message.')
                .addElicitSlotDirective('message')
                .getResponse();
        }

        // Get any previously stored partial message from session attributes
        const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
        const previousMessage = sessionAttributes.lastMessage || '';
        const fullTranscript = previousMessage ? `${previousMessage}. ${transcript}` : transcript;

        try {
            const result = await postMessage(accessToken, deviceId, fullTranscript);
            // Update session with the full message
            sessionAttributes.lastMessage = fullTranscript;
            sessionAttributes.messageCount = (sessionAttributes.messageCount || 0) + 1;
            handlerInput.attributesManager.setSessionAttributes(sessionAttributes);

            const count = result.count || 0;
            const { confirmation, continuePrompt } = buildSentResponse(count);

            const speech = ssml(
                `${SOUNDS.SENT}${pause(200)}` +
                `${confirmation}${pause(300)}` +
                `${continuePrompt}`
            );

            return handlerInput.responseBuilder
                .speak(speech)
                .reprompt('Say another message, or say stop to exit.')
                .getResponse();
        } catch (error) {
            console.error('Error sending continued message:', error.response?.data || error.message);
            if (error.response?.status === 404) {
                const cardBody =
                    'Rasoi app → Devices → Pair Echo. Paste this id (simulator or real Echo):\n\n' + deviceId;
                return handlerInput.responseBuilder
                    .speak(ssml(
                        `${SOUNDS.ERROR}${pause(200)}` +
                        `This Alexa session is not registered in Rasoi yet. ` +
                        `Open the Rasoi app, Devices, Pair Echo, and paste the device id from the test card or your API logs. ` +
                        `The developer test simulator counts as its own device.`
                    ))
                    .withSimpleCard('Pair in Rasoi app', cardBody)
                    .reprompt('Would you like to try again?')
                    .getResponse();
            }
            return handlerInput.responseBuilder
                .speak(ssml(
                    `${SOUNDS.ERROR}${pause(200)}Sorry, I had trouble sending that. ${pause(200)}Please try again.`
                ))
                .reprompt('Would you like to try again?')
                .getResponse();
        }
    },
};

module.exports = ContinueMessageIntentHandler;
