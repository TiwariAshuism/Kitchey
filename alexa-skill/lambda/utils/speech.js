// SSML helpers and sound effects for a polished Alexa experience

const SOUNDS = {
    SENT: '<audio src="soundbank://soundlibrary/ui/gameshow/amzn_ui_sfx_gameshow_positive_response_01"/>',
    RECEIVE: '<audio src="soundbank://soundlibrary/ui/gameshow/amzn_ui_sfx_gameshow_bridge_01"/>',
    ERROR: '<audio src="soundbank://soundlibrary/ui/gameshow/amzn_ui_sfx_gameshow_negative_response_01"/>',
    WELCOME: '<audio src="soundbank://soundlibrary/musical/amzn_sfx_bell_short_chime_02"/>',
    GOODBYE: '<audio src="soundbank://soundlibrary/ui/gameshow/amzn_ui_sfx_gameshow_outro_01"/>',
};

function ssml(text) {
    return `<speak>${text}</speak>`;
}

function pause(ms) {
    return `<break time="${ms}ms"/>`;
}

function emphasis(text, level = 'moderate') {
    return `<emphasis level="${level}">${text}</emphasis>`;
}

function prosody(text, { rate, pitch, volume } = {}) {
    const attrs = [];
    if (rate) attrs.push(`rate="${rate}"`);
    if (pitch) attrs.push(`pitch="${pitch}"`);
    if (volume) attrs.push(`volume="${volume}"`);
    return `<prosody ${attrs.join(' ')}>${text}</prosody>`;
}

function sayAs(text, interpretAs = 'cardinal') {
    return `<say-as interpret-as="${interpretAs}">${text}</say-as>`;
}

function getTimeOfDayGreeting() {
    // IST offset (UTC+5:30)
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istTime = new Date(now.getTime() + istOffset);
    const hour = istTime.getUTCHours();

    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Hey there';
}

function getRandomItem(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

// Friendly confirmation phrases after sending
const SENT_CONFIRMATIONS = [
    "Done! Message sent to {count}.",
    "Got it! {count} will see your message.",
    "Sent! {count} notified.",
    "All done! Your message is on its way to {count}.",
    "Message delivered to {count}!",
];

// Friendly prompts to keep the session going
const CONTINUE_PROMPTS = [
    "Want to send another one?",
    "Anything else to say?",
    "Would you like to send another message?",
    "Shall I send another?",
];

// Friendly goodbyes
const GOODBYES = [
    "Bye! Your family knows where to find you.",
    "See you next time! Happy cooking.",
    "Goodbye! The kitchen is in good hands.",
    "Take care! Your messages are delivered.",
    "Bye bye! Enjoy your meal.",
];

// No-reply responses
const NO_REPLIES = [
    "No new messages from your family right now.",
    "All quiet! No messages waiting.",
    "Nothing new at the moment.",
    "No replies yet. Your family might be busy!",
];

function formatRecipientCount(count) {
    if (count === 1) return '1 family member';
    return `${count} family members`;
}

function buildSentResponse(count) {
    const recipient = formatRecipientCount(count);
    const confirmation = getRandomItem(SENT_CONFIRMATIONS).replace('{count}', recipient);
    const continuePrompt = getRandomItem(CONTINUE_PROMPTS);
    return { confirmation, continuePrompt };
}

module.exports = {
    SOUNDS,
    ssml,
    pause,
    emphasis,
    prosody,
    sayAs,
    getTimeOfDayGreeting,
    getRandomItem,
    SENT_CONFIRMATIONS,
    CONTINUE_PROMPTS,
    GOODBYES,
    NO_REPLIES,
    formatRecipientCount,
    buildSentResponse,
};
