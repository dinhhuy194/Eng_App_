import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Kết quả parse PDF
class PdfParseResult {
  final String text;
  final int pageCount;

  const PdfParseResult({required this.text, required this.pageCount});
}

/// Service parse PDF sử dụng Syncfusion Flutter PDF
/// Parse trực tiếp trên client (không cần server)
class PdfParserService {
  /// Parse PDF từ bytes → text
  static PdfParseResult parsePdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();
    final pageCount = document.pages.count;

    for (int i = 0; i < pageCount; i++) {
      final pageText = extractor.extractText(
        startPageIndex: i,
        endPageIndex: i,
      );
      if (pageText.isNotEmpty) {
        buffer.writeln(pageText);
        buffer.writeln(); // Khoảng cách giữa các trang
      }
    }

    document.dispose();
    return PdfParseResult(
      text: buffer.toString().trim(),
      pageCount: pageCount,
    );
  }
}
