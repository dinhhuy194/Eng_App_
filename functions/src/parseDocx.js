const mammoth = require("mammoth");
const fetch = require("node-fetch");

/**
 * Parse DOCX file — trích xuất text từ URL
 */
async function parseDocxHandler(data, context) {
  if (!context.auth) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("unauthenticated", "Cần đăng nhập");
  }

  const { fileUrl } = data;

  const response = await fetch(fileUrl);
  const buffer = await response.buffer();
  const result = await mammoth.extractRawText({ buffer });

  return { text: result.value };
}

module.exports = { parseDocxHandler };
