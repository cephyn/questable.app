const functions = require("firebase-functions");
const admin = require("firebase-admin");
const pdf2md = require("@opendocsg/pdf2md");
const axios = require("axios");

admin.initializeApp();

exports.convertToMarkdown = functions.https.onCall(async (data, context) => {
    console.log("convertToMarkdown: Received call.");

    // Safely extract and log information about 'data'
    const outerDataType = typeof data;
    let pdfUrlFromData = null;
    let outerDataKeysInfo = "N/A";
    let actualPayload = null;

    if (data && outerDataType === 'object') {
        outerDataKeysInfo = Object.keys(data).join(', ');
        console.log("Outer data object keys:", outerDataKeysInfo);

        // Check if the actual payload is nested within data.data
        if (data.hasOwnProperty('data') && typeof data.data === 'object' && data.data !== null) {
            actualPayload = data.data;
            console.log("Actual payload found in data.data.");
        } else {
            // If not nested, assume 'data' itself is the payload (less common for onCall)
            actualPayload = data;
            console.log("Assuming outer 'data' object is the payload.");
        }

        const payloadDataType = typeof actualPayload;
        if (actualPayload && payloadDataType === 'object') {
            if (actualPayload.hasOwnProperty('url')) {
                pdfUrlFromData = actualPayload.url;
                console.log("Payload contains 'url' property. URL:", pdfUrlFromData);
            } else {
                console.log("'url' property missing in the payload:", actualPayload);
            }
            const payloadKeys = Object.keys(actualPayload).join(', ');
            console.log("Keys in payload object:", payloadKeys);
        } else {
            console.log("Payload is not a typical object or is null/undefined. Type:", payloadDataType, "Value:", String(actualPayload));
        }

    } else {
        console.log("Outer data received is not a typical object or is null/undefined. Type:", outerDataType, "Value:", String(data));
    }

    if (!pdfUrlFromData || typeof pdfUrlFromData !== 'string') {
        console.error("Bad Request: Missing or invalid 'url' in payload. Received outer data type:", outerDataType, "Outer data keys:", outerDataKeysInfo);
        throw new functions.https.HttpsError(
            'invalid-argument',
            "Bad Request: Missing or invalid 'url' in payload."
        );
    }

    const pdfUrl = pdfUrlFromData;

    try {
        // 1. Fetch PDF from URL
        console.log(`Fetching PDF from URL: ${pdfUrl}`);
        const response = await axios.get(pdfUrl, { responseType: 'arraybuffer' });
        const pdfBuffer = Buffer.from(response.data);

        // 2. Convert PDF buffer to Markdown
        console.log("Converting PDF to Markdown...");
        const markdownText = await pdf2md(pdfBuffer);
        console.log("Conversion successful. Markdown length:", markdownText ? markdownText.length : 'N/A');

        // 3. Return Markdown text directly
        return markdownText;

    } catch (error) {
        console.error(`Error converting PDF from URL "${pdfUrl}" to Markdown. Error message:`, error.message);
        if (axios.isAxiosError(error)) {
            let code = 'internal';
            let message = `Error fetching PDF from URL: ${error.message}`;
            if (error.response) {
                console.error("Axios error response status:", error.response.status);
                // Avoid logging error.response.data directly if it could be very large or complex
                console.error("Axios error response headers:", error.response.headers);
                if (error.response.status === 404) code = 'not-found';
                else if (error.response.status === 400) code = 'invalid-argument';
            }
            throw new functions.https.HttpsError(code, message);
        } else if (error.message && error.message.includes("Invalid PDF structure")) {
            console.error("Invalid PDF structure detected for URL:", pdfUrl);
            throw new functions.https.HttpsError(
                'invalid-argument',
                "Invalid PDF structure or corrupted file."
            );
        }
        // For other errors, log the error object cautiously or just its message/stack
        console.error("Generic error during conversion. Error stack:", error.stack);
        throw new functions.https.HttpsError(
            'internal',
            "Error converting PDF to Markdown."
        );
    }
});