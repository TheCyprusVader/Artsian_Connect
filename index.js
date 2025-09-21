const functions = require("firebase-functions");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const vision = require("@google-cloud/vision");
const admin = require("firebase-admin");
const { SessionsClient } = require("@google-cloud/dialogflow-cx");

admin.initializeApp();
const db = admin.firestore();

const dialogflow = functions.config().dialogflow || {};
const AGENT_ID = dialogflow.agent_id || "default-agent-id";
const LOCATION = dialogflow.location || "us-central1";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const visionClient = new vision.ImageAnnotatorClient();
const dialogflowClient = new SessionsClient();

// ---------- 1. Extract Labels ----------
exports.extractLabels = functions.https.onRequest(async (req, res) => {
  try {
    const imageUrl = req.body.imageUrl;
    if (!imageUrl) {
      return res.status(400).json({ error: "Missing imageUrl" });
    }

    const [result] = await visionClient.labelDetection(imageUrl);
    const labels = result.labelAnnotations.map((l) => l.description);

    return res.status(200).json({ labels });
  } catch (err) {
    console.error("Error in extractLabels:", err);
    return res.status(500).json({ error: err.message });
  }
});

// ---------- 2. Generate Product Description ----------
exports.generateProductDescription = functions.https.onRequest(
  async (req, res) => {
    try {
      const productInfo = req.body.productInfo || "A new product";
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

      const prompt =
        "Write a creative and engaging product description for: " +
        productInfo;

      const response = await model.generateContent(prompt);

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

      return res.status(200).json({ description });
    } catch (err) {
      console.error("Error in generateProductDescription:", err);
      return res.status(500).json({ error: err.message });
    }
  }
);

// ---------- 3. Save to Firestore ----------
exports.saveToFirestore = functions.https.onRequest(async (req, res) => {
  try {
    const collection = req.body.collection;
    const data = req.body.data;

    if (!collection || !data) {
      return res.status(400).json({ error: "Missing collection or data" });
    }

    const docRef = await db.collection(collection).add(data);
    return res.status(200).json({
      id: docRef.id,
      message: "Saved successfully",
    });
  } catch (err) {
    console.error("Error in saveToFirestore:", err);
    return res.status(500).json({ error: err.message });
  }
});

// ---------- 4. Chat with Dialogflow CX ----------
exports.chatWithDialogflow = functions.https.onRequest(async (req, res) => {
  try {
    const sessionId = req.body.sessionId || Date.now().toString();
    const text = req.body.text || "Hello";

    const sessionPath = dialogflowClient.projectLocationAgentSessionPath(
      process.env.GCLOUD_PROJECT,
      LOCATION,
      AGENT_ID,
      sessionId
    );

    const request = {
      session: sessionPath,
      queryInput: {
        text: { text },
        languageCode: "en",
      },
    };

    const [response] = await dialogflowClient.detectIntent(request);

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

    return res.status(200).json({ reply });
  } catch (err) {
    console.error("Error in chatWithDialogflow:", err);
    return res.status(500).json({ error: err.message });
  }
});

