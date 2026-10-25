import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/translation_models.dart';

/// Which engine performs the translation. `offline` needs no key and
/// simply returns the original text — useful for trying the overlay UI
/// before wiring up a real provider (Zero-Config Onboarding).
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

/// Thin client for the LuminaRead FastAPI backend.
///
/// [baseUrl] defaults to `http://localhost:8000`, which is what the backend
/// listens on via `uvicorn main:app --reload` from inside `backend/`.
/// Override it for a deployed backend or a forwarded Codespaces port with:
/// `flutter run --dart-define=API_BASE_URL=https://your-host`.
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
      } catch (_) {
        // keep the raw body as the detail
      }
      throw ApiException('Translation failed (${response.statusCode}): $detail');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return TranslationResult.fromJson(decoded);
  }
}
