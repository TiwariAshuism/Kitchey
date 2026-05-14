const { postMessage } = require('../utils/api');
const { SOUNDS, ssml, pause, prosody, buildSentResponse, getRandomItem, CONTINUE_PROMPTS } = require('../utils/speech');

const SendMessageIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'SendMessageIntent'
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
                .speak("I didn't catch that. What message would you like to send?")
                .reprompt('Say the message you want to send to your family.')
                .addElicitSlotDirective('message')
                .getResponse();
        }

        // Store in session for confirmation context
        const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
        sessionAttributes.lastMessage = transcript;
        sessionAttributes.messageCount = (sessionAttributes.messageCount || 0) + 1;
        handlerInput.attributesManager.setSessionAttributes(sessionAttributes);

        try {
            const result = await postMessage(accessToken, deviceId, transcript);
            const count = result.count || 0;

            if (count === 0) {
                const speech = ssml(
                    `${SOUNDS.ERROR}${pause(200)}` +
                    `Your message was saved, but there are no other family members paired to this Echo yet. ` +
                    `They should sign into the Rasoi app with their account and use Devices, then Pair Echo, with the same device id.`
                );
                return handlerInput.responseBuilder.speak(speech).getResponse();
            }

            const { confirmation, continuePrompt } = buildSentResponse(count);
            const speech = ssml(
                `${SOUNDS.SENT}${pause(200)}` +
                `${confirmation}${pause(300)}` +
                `${continuePrompt}`
            );

            return handlerInput.responseBuilder
                .speak(speech)
                .reprompt('Say another message, or say "check messages" to hear replies.')
                .getResponse();
        } catch (error) {
            console.error('Error sending message:', error.response?.data || error.message);

            if (error.response?.status === 402) {
                return handlerInput.responseBuilder
                    .speak(ssml(
                        `${SOUNDS.ERROR}${pause(200)}` +
                        `Your Rasoi subscription has expired. Please renew it in the Rasoi app to keep sending messages.`
                    ))
                    .getResponse();
            }

            if (error.response?.status === 404) {
                const cardBody =
                    '1) Open the Rasoi app (same email as Alexa account linking).\n' +
                    '2) Devices → Pair Echo.\n' +
                    '3) Paste this id (works for a real Echo or the developer test simulator):\n\n' +
                    deviceId;
                return handlerInput.responseBuilder
                    .speak(ssml(
                        `${SOUNDS.ERROR}${pause(200)}` +
                        `This Alexa session is not registered in Rasoi yet. ${pause(200)}` +
                        `Linking the skill in the Alexa app only connects your login. ` +
                        `You still need to register this device id in the Rasoi app under Devices, Pair Echo. ` +
                        `That includes the Alexa developer test simulator: copy the id from the card in the test panel, or from your server logs, then pair it like a real Echo.`
                    ))
                    .withSimpleCard('Pair device in Rasoi app', cardBody)
                    .getResponse();
            }

            return handlerInput.responseBuilder
                .speak(ssml(
                    `${SOUNDS.ERROR}${pause(200)}` +
                    `Sorry, I had trouble sending your message. ${pause(200)}Please try again in a moment.`
                ))
                .reprompt('Would you like to try sending your message again?')
                .getResponse();
        }
    },
};

module.exports = SendMessageIntentHandler;
