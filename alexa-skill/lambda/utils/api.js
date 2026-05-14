const axios = require('axios');

/**
 * Public base URL of the Kitzz Go API (no trailing slash).
 * Must match the host the Flutter app uses (same tunnel or LAN IP).
 *
 * Local: http://127.0.0.1:8080
 * ngrok: https://<subdomain>.ngrok-free.app
 */
const BACKEND_URL = (process.env.BACKEND_URL || 'http://127.0.0.1:8080').replace(
    /\/$/,
    ''
);

const isNgrokHost = /\.ngrok(-free)?\.(app|dev)\b/i.test(BACKEND_URL) || /\.ngrok\.io\b/i.test(BACKEND_URL);

const backendHttp = axios.create({
    baseURL: BACKEND_URL,
    timeout: 10000,
    headers: {
        'Content-Type': 'application/json',
        ...(isNgrokHost ? { 'ngrok-skip-browser-warning': 'true' } : {}),
    },
});

async function postMessage(accessToken, deviceId, transcript) {
    const response = await backendHttp.post(
        '/api/message/incoming',
        {
            device_id: deviceId,
            transcript: transcript,
        },
        {
            headers: {
                Authorization: `Bearer ${accessToken}`,
            },
        }
    );
    return response.data;
}

async function getPendingReplies(accessToken, deviceId) {
    const response = await backendHttp.get('/api/replies/pending', {
        params: { device_id: deviceId },
        headers: {
            Authorization: `Bearer ${accessToken}`,
        },
    });
    return response.data;
}

async function markRepliesDelivered(accessToken, ids) {
    const response = await backendHttp.put(
        '/api/replies/delivered',
        { ids: ids },
        {
            headers: {
                Authorization: `Bearer ${accessToken}`,
            },
        }
    );
    return response.data;
}

module.exports = { postMessage, getPendingReplies, markRepliesDelivered, BACKEND_URL };
