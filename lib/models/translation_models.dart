import 'dart:convert';
import 'dart:typed_data';

class TranslatedSpan {
  const TranslatedSpan({required this.text, required this.bbox});

  final String text;
  final List<double> bbox;

  double get left => bbox[0];
  double get top => bbox[1];
  double get right => bbox[2];
  double get bottom => bbox[3];
  double get width => (right - left).clamp(0.0, 1.0).toDouble();
  double get height => (bottom - top).clamp(0.0, 1.0).toDouble();

  factory TranslatedSpan.fromJson(Map<String, dynamic> json) {
    final rawBbox = json['bbox'] as List<dynamic>;
    return TranslatedSpan(
      text: json['text'] as String? ?? '',
      bbox: rawBbox.map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'bbox': bbox};
}

class TranslatedPage {
  const TranslatedPage({
    required this.page,
    required this.width,
    required this.height,
    required this.spans,
    this.imageBytes,
  });

  final int page;
  final double width;
  final double height;
  final List<TranslatedSpan> spans;
  final Uint8List? imageBytes;

  factory TranslatedPage.fromJson(Map<String, dynamic> json) {
    final imageB64 = json['image_png_base64'] as String?;
    final rawSpans = json['spans'] as List<dynamic>;
    return TranslatedPage(
      page: json['page'] as int,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      spans: rawSpans.map((e) => TranslatedSpan.fromJson(e as Map<String, dynamic>)).toList(),
      imageBytes: imageB64 != null ? base64Decode(imageB64) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'width': width,
        'height': height,
        'spans': spans.map((s) => s.toJson()).toList(),
        if (imageBytes != null) 'image_png_base64': base64Encode(imageBytes!),
      };
}

class TranslationResult {
  const TranslationResult({required this.pages, required this.targetLang, required this.provider});

  final List<TranslatedPage> pages;
  final String targetLang;
  final String provider;

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>;
    return TranslationResult(
      pages: rawPages.map((e) => TranslatedPage.fromJson(e as Map<String, dynamic>)).toList(),
      targetLang: json['target_lang'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'target_lang': targetLang,
        'provider': provider,
        'pages': pages.map((p) => p.toJson()).toList(),
      };
}
