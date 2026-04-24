import '../constants/api_constants.dart';

/// Chia text thành các chunks có overlap
/// Chiến lược: chia theo paragraph, không cắt giữa câu
/// Mỗi chunk ~1500 token (~2000 từ), overlap 100 từ
class TextChunker {
  /// Chia text thành danh sách chunks
  /// Trả về list of Maps sẵn sàng lưu Firestore
  static List<Map<String, dynamic>> chunkText(String text) {
    if (text.trim().isEmpty) return [];

    final paragraphs = _splitIntoParagraphs(text);
    final chunks = <Map<String, dynamic>>[];
    
    String currentChunk = '';
    int currentTokenCount = 0;
    int chunkIndex = 0;

    for (final paragraph in paragraphs) {
      final paragraphTokens = _estimateTokenCount(paragraph);

      // Nếu thêm paragraph này vượt quá limit → lưu chunk hiện tại
      if (currentTokenCount + paragraphTokens > ApiConstants.maxTokensPerChunk &&
          currentChunk.isNotEmpty) {
        chunks.add({
          'index': chunkIndex,
          'text': currentChunk.trim(),
          'tokenCount': currentTokenCount,
        });
        chunkIndex++;

        // Overlap: giữ lại 100 từ cuối
        currentChunk = _getOverlapText(currentChunk);
        currentTokenCount = _estimateTokenCount(currentChunk);
      }

      currentChunk += '\n\n$paragraph';
      currentTokenCount += paragraphTokens;
    }

    // Lưu chunk cuối cùng
    if (currentChunk.trim().isNotEmpty) {
      chunks.add({
        'index': chunkIndex,
        'text': currentChunk.trim(),
        'tokenCount': currentTokenCount,
      });
    }

    return chunks;
  }

  /// Tách text thành các paragraphs
  static List<String> _splitIntoParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Ước tính số token (1 token ≈ 0.75 từ tiếng Anh, ≈ 1 từ tiếng Việt)
  static int _estimateTokenCount(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words * 1.3).ceil(); // Ước tính an toàn hơn
  }

  /// Lấy ~100 từ cuối cùng làm overlap
  static String _getOverlapText(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= ApiConstants.chunkOverlapWords) return text;

    // Tìm vị trí bắt đầu câu gần nhất trong khoảng overlap
    final overlapWords =
        words.sublist(words.length - ApiConstants.chunkOverlapWords);
    final overlapText = overlapWords.join(' ');

    // Cắt từ đầu câu nếu có
    final sentenceStart = overlapText.indexOf(RegExp(r'[.!?]\s'));
    if (sentenceStart != -1 && sentenceStart < overlapText.length ~/ 2) {
      return overlapText.substring(sentenceStart + 2);
    }

    return overlapText;
  }

  /// Ước tính số trang dựa trên số từ
  static int estimatePages(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words / 300).ceil(); // ~300 từ/trang
  }
}
