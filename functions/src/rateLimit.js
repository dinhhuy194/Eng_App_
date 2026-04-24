const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");
const db = admin.firestore();

const DAILY_LIMITS = {
  generateQuiz: 20,
  askQuestion: 50,
  pronunciationFeedback: 30,
};

/**
 * Kiểm tra rate limit per user per day
 */
async function checkRateLimit(userId, action) {
  const today = new Date().toISOString().split("T")[0];
  const key = `rateLimit:${userId}:${today}:${action}`;
  const ref = db.collection("rateLimits").doc(key);

  return db.runTransaction(async (t) => {
    const doc = await t.get(ref);
    const count = doc.exists ? doc.data().count : 0;
    const limit = DAILY_LIMITS[action] || 10;

    if (count >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        `Đã đạt giới hạn ${limit} lần/ngày cho ${action}`
      );
    }
    t.set(ref, { count: count + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  });
}

module.exports = { checkRateLimit };
