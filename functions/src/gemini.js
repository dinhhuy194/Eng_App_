const { defineSecret } = require("firebase-functions/params");
const apiKey = defineSecret("GEMINI_API_KEY");

/**
 * Wrapper gọi Gemini 1.5 Flash API
 * Dùng chung cho tất cả Cloud Functions
 */
async function callGemini(prompt, maxTokens = 2048) {
  const fetch = require("node-fetch");
  const url =
    "https://generativelanguage.googleapis.com/v1beta/" +
    `models/gemini-1.5-flash:generateContent?key=${apiKey.value()}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        maxOutputTokens: maxTokens,
        temperature: 0.3,
      },
    }),
  });

  if (!res.ok) {
    const error = await res.text();
    throw new Error(`Gemini API error: ${res.status} - ${error}`);
  }

  const data = await res.json();

  if (!data.candidates || data.candidates.length === 0) {
    throw new Error("Gemini không trả về kết quả");
  }

  return data.candidates[0].content.parts[0].text;
}

module.exports = { callGemini, apiKey };
