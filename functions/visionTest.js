const functions = require("firebase-functions");
const vision = require("@google-cloud/vision");

exports.visionTest = functions.https.onRequest((req, res) => {
  res.status(200).send("Vision module loaded!");
});
