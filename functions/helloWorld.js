const functions = require("firebase-functions");

exports.helloWorld = functions.https.onRequest((req, res) => {
  res.status(200).send("Hello, World!");
});
