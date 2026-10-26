import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/translation_models.dart';

/// One row of the app-tracked usage counter.
class UsageEntry {
  UsageEntry({required this.calls, required this.characters, required this.lastUsed});

  int calls;
  int characters;
  DateTime lastUsed;

  Map<String, dynamic> toJson() => {
        'calls': calls,
        'characters': characters,
        'last_used': lastUsed.toIso8601String(),
      };

  factory UsageEntry.fromJson(Map<String, dynamic> json) => UsageEntry(
        calls: (json['calls'] as num?)?.toInt() ?? 0,
        characters: (json['characters'] as num?)?.toInt() ?? 0,
        lastUsed: DateTime.tryParse(json['last_used'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Local, best-effort usage tracking.
///
/// Providers do not expose reliable quota/usage for BYOK keys (Gemini's free
/// tier especially), and this app deliberately never queries them. Instead it
/// counts its own translate calls and estimates the characters it sent, per
/// provider + key, in the same local storage the library uses. Everything
/// shown from this is an APP-TRACKED ESTIMATE, not an account balance.
class UsageService {
  UsageService._();

  static const _storageKey = 'lumina_usage';

  /// Groups entries per provider *and* key without ever storing the key:
  /// only its last four characters are used as the discriminator.
  static String labelFor({required String provider, String? apiKey}) {
    if (apiKey == null || apiKey.isEmpty) return provider;
    final suffix = apiKey.length <= 4 ? apiKey : apiKey.substring(apiKey.length - 4);
    return '$provider (…$suffix)';
  }

  /// Rough count of the characters handled by one translation, used as the
  /// "sent" estimate. The client never sees the raw source text (the backend
  /// extracts it), so the rendered translated text is the closest proxy.
  static int estimateCharacters(TranslationResult result) {
    var characters = 0;
    for (final page in result.pages) {
      for (final span in page.spans) {
        characters += span.text.length;
      }
    }
    return characters;
  }

  static Future<Map<String, UsageEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (label, value) => MapEntry(label, UsageEntry.fromJson(value as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> record({
    required String provider,
    String? apiKey,
    required int characters,
  }) async {
    final label = labelFor(provider: provider, apiKey: apiKey);
    final prefs = await SharedPreferences.getInstance();
    final all = await load();
    final entry = all[label] ?? UsageEntry(calls: 0, characters: 0, lastUsed: DateTime.now());
    entry.calls += 1;
    entry.characters += characters;
    entry.lastUsed = DateTime.now();
    all[label] = entry;
    await prefs.setString(_storageKey, jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));
  }

  /// Clears everything, or a single provider/key row when [label] is given.
  static Future<void> reset({String? label}) async {
    final prefs = await SharedPreferences.getInstance();
    if (label == null) {
      await prefs.remove(_storageKey);
      return;
    }
    final all = await load();
    all.remove(label);
    if (all.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }
    await prefs.setString(_storageKey, jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
