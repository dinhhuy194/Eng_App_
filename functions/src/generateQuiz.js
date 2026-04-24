const admin = require("firebase-admin");
const { callGemini } = require("./gemini");
const { checkRateLimit } = require("./rateLimit");
const db = admin.firestore();

/**
 * Tạo quiz từ tài liệu bằng Gemini
 */
async function generateQuizHandler(data, context) {
  if (!context.auth) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("unauthenticated", "Cần đăng nhập");
  }

  const userId = context.auth.uid;
  await checkRateLimit(userId, "generateQuiz");

  const { documentId, numQuestions = 10, difficulty = "mixed" } = data;

  // Lấy chunks từ Firestore
  const chunksSnap = await db
    .collection("users")
    .doc(userId)
    .collection("documents")
    .doc(documentId)
    .collection("chunks")
    .orderBy("index")
    .limit(3)
    .get();

  if (chunksSnap.empty) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Không tìm thấy nội dung tài liệu");
  }

  const contextText = chunksSnap.docs.map((d) => d.data().text).join("\n\n");

  // Check cache
  const cacheKey = `quiz_${documentId}_${numQuestions}_${difficulty}`;
  const cached = await db.collection("quizCache").doc(cacheKey).get();
  if (cached.exists) {
    const data = cached.data();
    const age = Date.now() - data.createdAt.toMillis();
    if (age < 24 * 60 * 60 * 1000) {
      return { questions: data.questions, fromCache: true };
    }
  }

  const prompt = `Từ nội dung sau, tạo ${numQuestions} câu hỏi trắc nghiệm.
Độ khó: ${difficulty}. Trả về JSON hợp lệ (KHÔNG markdown, KHÔNG backticks) với format:
[{"question": "...", "options": ["A","B","C","D"], "correctIndex": 0, "explanation": "...", "difficulty": "${difficulty === "mixed" ? "easy|medium|hard" : difficulty}"}]
Chỉ trả về JSON array, không thêm text khác.

Nội dung: ${contextText}`;

  const geminiRes = await callGemini(prompt, 4096);

  // Extract JSON từ response
  let questions;
  try {
    const jsonMatch = geminiRes.match(/\[[\s\S]*\]/);
    if (jsonMatch) {
      questions = JSON.parse(jsonMatch[0]);
    } else {
      questions = JSON.parse(geminiRes);
    }
  } catch (e) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("internal", "Không parse được kết quả AI: " + e.message);
  }

  // Lưu cache
  await db.collection("quizCache").doc(cacheKey).set({
    questions,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { questions };
}

module.exports = { generateQuizHandler };
