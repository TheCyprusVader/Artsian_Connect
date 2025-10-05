// Firebase Functions and Dialogflow CX integration

const functions = require("firebase-functions");
const {SessionsClient} = require("@google-cloud/dialogflow-cx");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const vision = require("@google-cloud/vision");
const admin = require("firebase-admin");
const helloWorld = require("./helloWorld");
const visionTest = require("./visionTest");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

const dialogflow = functions.config().dialogflow || {};
const AGENT_ID = dialogflow.agent_id || "default-agent-id";
const LOCATION = dialogflow.location || "us-central1";

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || functions.config().gemini?.api_key;
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const visionClient = new vision.ImageAnnotatorClient();
const dialogflowClient = new SessionsClient();

// Limit max instances (cost control)
functions.setGlobalOptions({maxInstances : 10});

// Your Firebase/Google Cloud project ID
const projectId = "gen-ai-hackathon-3a0d4";

// Agent location (example: "us-central1" or "global")
const location = "global";

// Replace with your Dialogflow CX Agent ID
const agentId = "YOUR_AGENT_ID";

const languageCode = "en";

// Cloud Function: connects Flutter app <-> Dialogflow CX Agent
// exports.chatWithAgent = onCall(async(request) => {
//   const text = request.data.text || "";

//   const client = new SessionsClient();
//   const sessionId = Date.now().toString();

//   const sessionPath = client.projectLocationAgentSessionPath(
//     projectId,
//     location,
//     agentId,
//     sessionId,
//   );

//   const detectIntentRequest = {
//     session: sessionPath,
//     queryInput: {
//       text: {text},
//       languageCode,
//     },
//   };

//   const [response] = await client.detectIntent(detectIntentRequest);

//   let reply = "Sorry, I didn’t understand.";
//   if (response.queryResult && response.queryResult.responseMessages) {
//     const messages = response.queryResult.responseMessages;
//     const texts = messages
//       .map((m) => (m.text && m.text.text ? m.text.text : []))
//       .flat();
//     if (texts.length > 0) {
//       reply = texts.join(" ");
//     }
//   }

//   return {reply};
// });

// ---------- 1. Extract Labels ----------
exports.extractLabels = functions.https.onRequest(async(req, res) => {
  try {
    const imageUrl = req.body.imageUrl;
    if (!imageUrl) {
      return res.status(400).json({error : "Missing imageUrl"});
    }
    const resultArr = await visionClient.labelDetection(imageUrl);
    const result = resultArr[0];
    const labels = result.labelAnnotations.map((l) => l.description);
    return res.status(200).json({labels : labels});
  } catch (err) {
    console.error("Error in extractLabels:", err);
    return res.status(500).json({error : err.message});
  }
});

// ---------- 2. Chat with GenAI ----------
exports.chatWithGenAI = functions.https.onCall(async(data, context) => {
  const userInput = data.text || "";
  if (!userInput) return {reply : "Please ask me something!"};
  try {
    const model = genAI.getGenerativeModel({model : "gemini-1.5-flash"});
    const response = await model.generateContent(userInput);
    let reply = "No response from AI.";
    if (
      response &&
      response.candidates &&
      response.candidates[0] &&
      response.candidates[0].content &&
      response.candidates[0].content.parts &&
      response.candidates[0].content.parts[0] &&
      response.candidates[0].content.parts[0].text
    ) {
      reply = response.candidates[0].content.parts[0].text;
    }
    return {reply : reply};
  } catch (err) {
    return {reply : `Error: ${err.message}`};
  }
});

// ---------- 3. Detect Intent ----------
exports.detectIntent = functions.https.onCall(async(data, context) => {
  const sessionId = data.sessionId || Date.now().toString();
  const text = data.text || "Hello";
  const sessionPath = dialogflowClient.projectLocationAgentSessionPath(
    process.env.GCLOUD_PROJECT,
    LOCATION,
    AGENT_ID,
    sessionId,
  );
  const request = {
    session : sessionPath,
    queryInput : {
      text : {text : text},
      languageCode : "en",
    },
  };
  const responseArr = await dialogflowClient.detectIntent(request);
  const response = responseArr[0];
  let reply = "No response from agent";
  if (
    response &&
    response.queryResult &&
    response.queryResult.responseMessages &&
    response.queryResult.responseMessages[0] &&
    response.queryResult.responseMessages[0].text &&
    response.queryResult.responseMessages[0].text.text &&
    response.queryResult.responseMessages[0].text.text[0]
  ) {
    reply = response.queryResult.responseMessages[0].text.text[0];
  }
  return {reply : reply};
});

// ---------- 4. Analyze Image ----------
exports.analyzeImage = functions.https.onRequest(async(req, res) => {
  try {
    const imageUrl = req.body.imageUrl;
    if (!imageUrl) {
      return res.status(400).json({error : "Missing imageUrl"});
    }
    const resultArr = await visionClient.labelDetection(imageUrl);
    const result = resultArr[0];
    const labels = result.labelAnnotations.map((l) => l.description);
    return res.status(200).json({labels : labels});
  } catch (err) {
    console.error("Error in analyzeImage:", err);
    return res.status(500).json({error : err.message});
  }
});

exports.visionTest = functions.https.onRequest((req, res) => {
  res.send("Hello from visionTest!");
});

exports.addProductAI = functions.https.onCall(async(data, context) => {
  const imageUrl = data.imageUrl;
  const name = data.name;
  const price = data.price;
  const prompt = data.prompt || "Generate a product description.";
  // Call Gemini for description
  const model = genAI.getGenerativeModel({model : "gemini-1.5-flash"});
  const response = await model.generateContent(
    `Write a creative product description for ${name} (price: ${price}). ${prompt} Image: ${imageUrl}`,
  );
  let description = "No description generated";
  if (
    response &&
    response.candidates &&
    response.candidates[0] &&
    response.candidates[0].content &&
    response.candidates[0].content.parts &&
    response.candidates[0].content.parts[0] &&
    response.candidates[0].content.parts[0].text
  ) {
    description = response.candidates[0].content.parts[0].text;
  }
  return {description : description};
});

// 2. Generate: generateContent (Gen 1 style)
exports.generateContent = functions.https.onCall(async(data, context) => {
  const name = data.name || "Product";
  const price = data.price || "";
  const prompt = data.prompt || "";
  try {
    const model = genAI.getGenerativeModel({model : "gemini-1.5-flash"});
    const input = `Write a creative product description for ${name} (price: ${price}). ${prompt}`;
    const response = await model.generateContent(input);
    let generated = "No description generated.";
    if (
      response &&
      response.candidates &&
      response.candidates[0] &&
      response.candidates[0].content &&
      response.candidates[0].content.parts &&
      response.candidates[0].content.parts[0] &&
      response.candidates[0].content.parts[0].text
    ) {
      generated = response.candidates[0].content.parts[0].text;
    }
    return {generated : generated};
  } catch (err) {
    return {generated : `Error: ${err.message}`};
  }
});

// 3. Save: saveData (Gen 1 style)
exports.saveData = functions.https.onCall(async(data, context) => {
  try {
    const collection = "userData";
    const payload = data.payload || {};
    const docRef = await admin.firestore().collection(collection).add(payload);
    return {id : docRef.id, message : "Saved successfully"};
  } catch (err) {
    return {error : err.message};
  }
});

// ========================================
// AI Product Listing Generator
// Added by: TheCyprusVader
// ========================================

exports.generateProductListing = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    try {
      // Validate input
      if (!data.imageUrls || data.imageUrls.length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'At least one image URL is required'
        );
      }

      if (!data.price) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Price is required'
        );
      }

      const imageUrls = data.imageUrls;
      const price = data.price;
      const language = data.language || 'english';

      // Download images from Firebase Storage
      const imageParts = await Promise.all(
        imageUrls.map(async (url) => {
          const bucket = admin.storage().bucket();
          const file = bucket.file(url.replace('gs://' + bucket.name + '/', ''));
          const [buffer] = await file.download();
          
          return {
            inlineData: {
              data: buffer.toString('base64'),
              mimeType: 'image/jpeg'
            }
          };
        })
      );

      // Language configuration
      const languageGuide = {
        english: 'Write entirely in English. Keep it casual and friendly.',
        hindi: 'Write entirely in Hindi (Devanagari script). Keep it casual.',
        hinglish: 'Write in Hinglish (Hindi + English mix). Natural and casual.',
        tamil: 'Write entirely in Tamil script. Keep it casual.',
        bengali: 'Write entirely in Bengali script. Keep it casual.'
      };

      // Create prompt
      const prompt = `You are helping an Indian artisan list their product online.

**LANGUAGE:** ${languageGuide[language] || languageGuide.english}

**TONE:** Casual, friendly, conversational.

${imageUrls.length} image(s) provided.

Create a simple product listing with ONLY these fields:

{
  "title": "Catchy, SEO-friendly title in ${language} (60-80 characters)",
  "region": "Which part of India is this craft from? (Just state/region name)",
  "description": "2-3 engaging sentences in ${language} (150 chars max)",
  "features": [
    "List 5-7 specific features in ${language}",
    "Keep each point short and clear"
  ]
}

Analyze the images and describe what you see. Focus on colors, patterns, materials, craftsmanship.

**CRITICAL:** Return ONLY valid JSON with these 4 fields. No extra text.
Price: ₹${price}`;

      // Call Gemini API (using existing genAI instance)
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
      
      const result = await model.generateContent([
        prompt,
        ...imageParts
      ]);

      const response = await result.response;
      let text = response.text();

      // Clean and parse JSON
      const startIdx = text.indexOf('{');
      const endIdx = text.lastIndexOf('}');
      
      if (startIdx !== -1 && endIdx !== -1) {
        text = text.substring(startIdx, endIdx + 1);
      }

      text = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();

      const listing = JSON.parse(text);

      // Return result
      return {
        success: true,
        data: {
          title: listing.title || '',
          region: listing.region || '',
          description: listing.description || '',
          features: listing.features || [],
          price: `₹${price}`,
          language: language
        }
      };

    } catch (error) {
      console.error('Error generating listing:', error);
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to generate listing: ' + error.message
      );
    }
  });