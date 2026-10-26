import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/translation_models.dart';

/// Assembles the already-rendered translated page images back into one PDF,
/// one page per image, in the original page order.
///
/// Each page PNG already has the Visual-Sync overlay baked in (original text
/// redacted, translated text painted at the same coordinates), so this only
/// re-packages what the client already holds -- no backend round trip and no
/// re-rendering.
class PdfExportService {
  const PdfExportService._();

  /// PDF points for a US Letter portrait page, used when the backend did not
  /// report usable page dimensions.
  static const double _fallbackWidth = 612;
  static const double _fallbackHeight = 792;

  /// "book.pdf" -> "book (translated).pdf"
  static String exportFileName(String sourceFileName) {
    final lower = sourceFileName.toLowerCase();
    final base = lower.endsWith('.pdf')
        ? sourceFileName.substring(0, sourceFileName.length - 4)
        : sourceFileName;
    return '$base (translated).pdf';
  }

  static Future<Uint8List> buildPdf(TranslationResult result, {String? title}) async {
    final doc = pw.Document(
      title: title,
      producer: 'LuminaRead AI',
    );

    for (final page in result.pages) {
      final imageBytes = page.imageBytes;
      doc.addPage(
        pw.Page(
          pageFormat: _pageFormat(page),
          margin: pw.EdgeInsets.zero,
          build: (context) {
            if (imageBytes == null) {
              // Keep page numbering aligned with the original document even
              // if a page had no rendered image.
              return pw.SizedBox();
            }
            return pw.Image(
              pw.MemoryImage(imageBytes),
              fit: pw.BoxFit.fill,
            );
          },
        ),
      );
    }

    return doc.save();
  }

  static PdfPageFormat _pageFormat(TranslatedPage page) {
    final width = page.width;
    final height = page.height;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return const PdfPageFormat(_fallbackWidth, _fallbackHeight);
    }
    return PdfPageFormat(width, height);
  }
}
