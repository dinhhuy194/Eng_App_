const admin = require("firebase-admin");
const { onCall } = require("firebase-functions/v2/https");
const { apiKey } = require("./src/gemini");

admin.initializeApp();

// Import handlers
const { generateQuizHandler } = require("./src/generateQuiz");
const { pronunciationFeedbackHandler } = require("./src/pronunciationFeedback");
const { askQuestionHandler } = require("./src/askQuestion");
const { parseDocxHandler } = require("./src/parseDocx");

// Export Cloud Functions
exports.generateQuiz = onCall(
  { secrets: [apiKey], timeoutSeconds: 120, memory: "256MiB" },
  (request) => generateQuizHandler(request.data, request)
);

exports.pronunciationFeedback = onCall(
  { secrets: [apiKey], timeoutSeconds: 60 },
  (request) => pronunciationFeedbackHandler(request.data, request)
);

exports.askQuestion = onCall(
  { secrets: [apiKey], timeoutSeconds: 120, memory: "256MiB" },
  (request) => askQuestionHandler(request.data, request)
);

exports.parseDocx = onCall(
  { timeoutSeconds: 60, memory: "256MiB" },
  (request) => parseDocxHandler(request.data, request)
);
