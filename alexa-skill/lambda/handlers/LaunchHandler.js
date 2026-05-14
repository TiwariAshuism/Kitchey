const { getPendingReplies, markRepliesDelivered } = require('../utils/api');
const { SOUNDS, ssml, pause, prosody, getTimeOfDayGreeting, getRandomItem, CONTINUE_PROMPTS } = require('../utils/speech');

const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return handlerInput.requestEnvelope.request.type === 'LaunchRequest';
    },
    async handle(handlerInput) {
        const accessToken = handlerInput.requestEnvelope.context.System.user.accessToken;
        if (!accessToken) {
            const speech = ssml(
                `${SOUNDS.WELCOME}${pause(300)}` +
                `Welcome to Rasoi! ${pause(200)}` +
                `To send messages to your family, you'll need to link your account first. ` +
                `Open the Alexa app and tap "Link Account" on the Rasoi skill page.`
            );
            return handlerInput.responseBuilder
                .speak(speech)
                .withLinkAccountCard()
                .getResponse();
        }

        const deviceId = handlerInput.requestEnvelope.context.System.device.deviceId;
        const sessionAttributes = handlerInput.attributesManager.getSessionAttributes();
        const greeting = getTimeOfDayGreeting();
        let replySection = '';
        let replyCount = 0;

        // Check for pending replies from family
        try {
            const data = await getPendingReplies(accessToken, deviceId);
            if (data.replies && data.replies.length > 0) {
                const replies = data.replies;
                const ids = replies.map((r) => r.id);
                replyCount = replies.length;

                replySection += `${SOUNDS.RECEIVE}${pause(200)}`;

                if (replies.length === 1) {
                    const r = replies[0];
                    replySection += `You have a message from ${r.sender_name || 'your family'}. ${pause(300)}`;
                    replySection += `They said: ${pause(200)}${prosody(r.text_content, { rate: '95%' })}${pause(400)}`;
                } else {
                    replySection += `You have ${replies.length} messages from your family! ${pause(400)}`;
                    for (let i = 0; i < replies.length; i++) {
                        const r = replies[i];
                        replySection += `${r.sender_name || 'Someone'} said: ${pause(200)}`;
                        replySection += `${prosody(r.text_content, { rate: '95%' })}${pause(500)}`;
                    }
                }

                // Mark as delivered
                await markRepliesDelivered(accessToken, ids);

                // Track in session for context
                sessionAttributes.lastReplyCount = replyCount;
                handlerInput.attributesManager.setSessionAttributes(sessionAttributes);
            }
        } catch (error) {
            console.error('Error checking replies:', error.message);
        }

        let speech;
        if (replySection) {
            speech = ssml(
                `${greeting}! ${pause(200)}${replySection}` +
                `Would you like to send a reply?`
            );
        } else {
            speech = ssml(
                `${SOUNDS.WELCOME}${pause(200)}` +
                `${greeting}! Welcome to Rasoi. ${pause(200)}` +
                `What message would you like to send to your family?`
            );
        }

        return handlerInput.responseBuilder
            .speak(speech)
            .reprompt('Go ahead, say your message. Or say "check messages" to hear replies.')
            .getResponse();
    },
};

module.exports = LaunchRequestHandler;
