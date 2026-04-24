const admin = require("firebase-admin");
const { callGemini } = require("./gemini");
const { checkRateLimit } = require("./rateLimit");
const db = admin.firestore();

/**
 * Q&A thông minh (RAG) — tìm chunks liên quan rồi gọi Gemini
 */
async function askQuestionHandler(data, context) {
  if (!context.auth) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("unauthenticated", "Cần đăng nhập");
  }

  await checkRateLimit(context.auth.uid, "askQuestion");

  const { question, documentId, conversationHistory = [] } = data;
  const userId = context.auth.uid;

  // Bước 1: Lấy tất cả chunks
  const chunksSnap = await db
    .collection("users")
    .doc(userId)
    .collection("documents")
    .doc(documentId)
    .collection("chunks")
    .orderBy("index")
    .get();

  const chunks = chunksSnap.docs.map((d) => ({ ...d.data() }));

  // Bước 2: Tìm chunks liên quan (keyword search)
  const relevant = findRelevantChunks(question, chunks, 3);
  const contextText = relevant.map((c) => c.text).join("\n\n");

  // Bước 3: Build conversation history
  const history = conversationHistory
    .slice(-6)
    .map((m) => `${m.role}: ${m.content}`)
    .join("\n");

  const prompt = `Bạn là trợ lý học tập. Chỉ trả lời dựa trên tài liệu được cung cấp.
Nếu không có đủ thông tin, hãy nói rõ.

TÀI LIỆU:
${contextText}

LỊCH SỬ HỘI THOẠI:
${history}

CÂU HỎI: ${question}

Trả lời ngắn gọn, chính xác. Nếu trích dẫn, ghi rõ nguồn.`;

  const answer = await callGemini(prompt, 1024);
  return { answer, sourcesUsed: relevant.map((c) => c.index) };
}

/**
 * Tìm chunks liên quan bằng keyword matching
 */
function findRelevantChunks(question, chunks, topK = 3) {
  const qWords = question
    .toLowerCase()
    .split(" ")
    .filter((w) => w.length > 3);

  return chunks
    .map((chunk) => ({
      ...chunk,
      score: qWords.filter((w) => chunk.text.toLowerCase().includes(w)).length,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

module.exports = { askQuestionHandler };
