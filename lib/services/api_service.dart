import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/translation_models.dart';

enum TranslationProvider { offline, gemini, openai, deepl }

extension TranslationProviderX on TranslationProvider {
  String get apiValue {
    switch (this) {
      case TranslationProvider.offline:
        return 'offline';
      case TranslationProvider.gemini:
        return 'gemini';
      case TranslationProvider.openai:
        return 'openai';
      case TranslationProvider.deepl:
        return 'deepl';
    }
  }

  String get label {
    switch (this) {
      case TranslationProvider.offline:
        return 'Offline (no key needed)';
      case TranslationProvider.gemini:
        return 'Google Gemini';
      case TranslationProvider.openai:
        return 'OpenAI GPT-4o';
      case TranslationProvider.deepl:
        return 'DeepL';
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

  final String baseUrl;

  Future<bool> ping() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches just the first page as a PNG -- fast, used to theme the UI
  /// with a color extracted from the book's cover before translating.
  Future<Uint8List> fetchCover({required Uint8List pdfBytes, required String fileName}) async {
    final uri = Uri.parse('$baseUrl/pdf/cover');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', pdfBytes, filename: fileName));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw ApiException('Could not read the PDF cover (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final b64 = decoded['image_png_base64'] as String;
    return base64Decode(b64);
  }

  Future<TranslationResult> translatePdf({
    required Uint8List pdfBytes,
    required String fileName,
    required String targetLang,
    String sourceLang = 'auto',
    TranslationProvider provider = TranslationProvider.offline,
    String? apiKey,
    double zoom = 2.0,
  }) async {
    final uri = Uri.parse('$baseUrl/translate');
    final request = http.MultipartRequest('POST', uri)
      ..fields['target_lang'] = targetLang
      ..fields['source_lang'] = sourceLang
      ..fields['provider'] = provider.apiValue
      ..fields['zoom'] = zoom.toString()
      ..fields['render_images'] = 'true'
      ..files.add(http.MultipartFile.fromBytes('file', pdfBytes, filename: fileName));

    if (apiKey != null && apiKey.isNotEmpty) {
      request.fields['api_key'] = apiKey;
    }

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {}
      throw ApiException('Translation failed (${response.statusCode}): $detail');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return TranslationResult.fromJson(decoded);
  }
}
