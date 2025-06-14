const functions = require("firebase-functions");
const admin = require("firebase-admin");
const pdf2md = require("@opendocsg/pdf2md");
const axios = require("axios");

admin.initializeApp();

exports.convertToMarkdown = functions.https.onCall(async (data, context) => {
    console.log("convertToMarkdown: Received call.");
    console.log("Type of data:", typeof data);
    if (data && typeof data === 'object') {
        console.log("Keys in data object:", Object.keys(data));
        if (data.hasOwnProperty('url')) {
            console.log("data.url value:", data.url);
        } else {
            console.log("data.url property not found.");
        }
    } else {
        console.log("Data is not a typical object or is null/undefined. Data:", data);
    }

    if (!data || !data.url) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            "Bad Request: Missing 'url' in payload."
        );
    }

    const pdfUrl = data.url;

    try {
        // 1. Fetch PDF from URL
        const response = await axios.get(pdfUrl, { responseType: 'arraybuffer' });
        const pdfBuffer = Buffer.from(response.data);

        // 2. Convert PDF buffer to Markdown
        const markdownText = await pdf2md(pdfBuffer);

        // 3. Return Markdown text directly
        return markdownText;

    } catch (error) {
        console.error(`Error converting PDF from URL "${pdfUrl}" to Markdown:`, error);
        if (axios.isAxiosError(error)) {
            let code = 'internal';
            let message = `Error fetching PDF from URL: ${error.message}`;
            if (error.response) {
                if (error.response.status === 404) code = 'not-found';
                else if (error.response.status === 400) code = 'invalid-argument';
            }
            throw new functions.https.HttpsError(code, message);
        } else if (error.message && error.message.includes("Invalid PDF structure")) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                "Invalid PDF structure or corrupted file."
            );
        }
        throw new functions.https.HttpsError(
            'internal',
            "Error converting PDF to Markdown."
        );
    }
});