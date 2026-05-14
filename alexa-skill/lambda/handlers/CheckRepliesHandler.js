const { getPendingReplies, markRepliesDelivered } = require('../utils/api');
const { SOUNDS, ssml, pause, prosody, getRandomItem, NO_REPLIES } = require('../utils/speech');

const CheckRepliesIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === 'IntentRequest' &&
            handlerInput.requestEnvelope.request.intent.name === 'CheckRepliesIntent'
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

        try {
            const data = await getPendingReplies(accessToken, deviceId);

            if (!data.replies || data.replies.length === 0) {
                const noReply = getRandomItem(NO_REPLIES);
                return handlerInput.responseBuilder
                    .speak(ssml(`${noReply} ${pause(300)}Would you like to send a message instead?`))
                    .reprompt('Say your message, or say stop to exit.')
                    .getResponse();
            }

            const replies = data.replies;
            const ids = replies.map((r) => r.id);
            let speechParts = `${SOUNDS.RECEIVE}${pause(300)}`;

            if (replies.length === 1) {
                const r = replies[0];
                speechParts += `You have a message from ${r.sender_name || 'your family'}. ${pause(300)}`;
                speechParts += `They said: ${pause(200)}${prosody(r.text_content, { rate: '95%' })}${pause(400)}`;
            } else {
                speechParts += `You have ${replies.length} messages! ${pause(400)}`;
                for (let i = 0; i < replies.length; i++) {
                    const r = replies[i];
                    const ordinal = replies.length > 2 ? `Message ${i + 1}: ` : '';
                    speechParts += `${ordinal}${r.sender_name || 'Someone'} said: ${pause(200)}`;
                    speechParts += `${prosody(r.text_content, { rate: '95%' })}${pause(500)}`;
                }
            }

            // Mark as delivered
            await markRepliesDelivered(accessToken, ids);

            speechParts += `${pause(300)}Would you like to reply?`;

            return handlerInput.responseBuilder
                .speak(ssml(speechParts))
                .reprompt('Say your reply message, or say stop to exit.')
                .getResponse();
        } catch (error) {
            console.error('Error checking replies:', error.response?.data || error.message);
            return handlerInput.responseBuilder
                .speak(ssml(
                    `${SOUNDS.ERROR}${pause(200)}Sorry, I couldn't check your messages right now. Please try again in a moment.`
                ))
                .getResponse();
        }
    },
};

module.exports = CheckRepliesIntentHandler;
