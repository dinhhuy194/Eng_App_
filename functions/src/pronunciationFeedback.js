const { callGemini } = require("./gemini");
const { checkRateLimit } = require("./rateLimit");

/**
 * Phân tích phát âm và cho feedback chi tiết
 */
async function pronunciationFeedbackHandler(data, context) {
  if (!context.auth) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("unauthenticated", "Cần đăng nhập");
  }

  await checkRateLimit(context.auth.uid, "pronunciationFeedback");

  const { originalText, recognizedText, language = "en-US" } = data;

  const prompt = `Bạn là giáo viên ngôn ngữ chuyên nghiệp.
Ngôn ngữ: ${language}
Câu gốc:  "${originalText}"
Người dùng nói: "${recognizedText}"

Hãy phân tích và cho feedback theo format JSON (KHÔNG markdown, KHÔNG backticks):
{
  "score": 0-100,
  "pronunciation_errors": [{"word": "...", "issue": "...", "correct_ipa": "..."}],
  "general_feedback": "...",
  "improvement_tips": ["tip1", "tip2"]
}
Chỉ trả về JSON, không thêm text khác.`;

  const geminiRes = await callGemini(prompt, 1024);

  try {
    const jsonMatch = geminiRes.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
    return JSON.parse(geminiRes);
  } catch (e) {
    return {
      score: 0,
      pronunciation_errors: [],
      general_feedback: "Không thể phân tích phát âm lúc này.",
      improvement_tips: ["Vui lòng thử lại"],
    };
  }
}

module.exports = { pronunciationFeedbackHandler };
