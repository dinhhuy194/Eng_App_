import 'dart:math';

/// Tính similarity giữa 2 đoạn text
/// Dùng cho: kiểm tra phát âm (so sánh recognized vs original)
class SimilarityCalculator {
  /// Tính word-level similarity (0.0 - 1.0)
  /// Dùng cho pronunciation checking
  static double wordSimilarity(String original, String recognized) {
    if (original.isEmpty || recognized.isEmpty) return 0.0;

    final aWords = _normalize(original);
    final bWords = _normalize(recognized);

    if (aWords.isEmpty) return 0.0;

    int matches = 0;
    for (final word in aWords) {
      if (bWords.contains(word)) matches++;
    }

    return matches / aWords.length;
  }

  /// Tính Levenshtein distance (edit distance) giữa 2 strings
  static int levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Normalized Levenshtein similarity (0.0 - 1.0)
  static double normalizedSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (levenshteinDistance(a, b) / maxLen);
  }

  /// Tính điểm phát âm tổng hợp (0-100)
  /// Kết hợp word similarity và Levenshtein
  static double pronunciationScore(String original, String recognized) {
    final wordSim = wordSimilarity(original, recognized);
    final charSim = normalizedSimilarity(
      original.toLowerCase().trim(),
      recognized.toLowerCase().trim(),
    );

    // Trọng số: 60% word match, 40% character match
    return ((wordSim * 0.6 + charSim * 0.4) * 100).clamp(0.0, 100.0);
  }

  /// Normalize text: lowercase, tách từ, bỏ punctuation
  static List<String> _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.length > 1)
        .toList();
  }

  /// Tìm các từ khác biệt giữa original và recognized
  static List<String> findMismatchedWords(
      String original, String recognized) {
    final origWords = _normalize(original);
    final recogWords = _normalize(recognized).toSet();

    return origWords.where((w) => !recogWords.contains(w)).toList();
  }
}
