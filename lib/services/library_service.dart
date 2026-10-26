import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/translation_models.dart';

class LibraryEntry {
  LibraryEntry({
    required this.id,
    required this.title,
    required this.targetLang,
    required this.provider,
    required this.accentColorValue,
    required this.pageCount,
    required this.lastPage,
    required this.savedAt,
    required this.result,
  });

  final String id;
  final String title;
  final String targetLang;
  final String provider;
  final int accentColorValue;
  final int pageCount;
  final int lastPage;
  final DateTime savedAt;
  final TranslationResult result;

  LibraryEntry copyWith({int? lastPage}) => LibraryEntry(
        id: id,
        title: title,
        targetLang: targetLang,
        provider: provider,
        accentColorValue: accentColorValue,
        pageCount: pageCount,
        lastPage: lastPage ?? this.lastPage,
        savedAt: savedAt,
        result: result,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'target_lang': targetLang,
        'provider': provider,
        'accent': accentColorValue,
        'page_count': pageCount,
        'last_page': lastPage,
        'saved_at': savedAt.toIso8601String(),
        'result': result.toJson(),
      };

  factory LibraryEntry.fromJson(Map<String, dynamic> json) => LibraryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        targetLang: json['target_lang'] as String,
        provider: json['provider'] as String,
        accentColorValue: json['accent'] as int,
        pageCount: json['page_count'] as int,
        lastPage: json['last_page'] as int,
        savedAt: DateTime.parse(json['saved_at'] as String),
        result: TranslationResult.fromJson(json['result'] as Map<String, dynamic>),
      );
}

class LibraryException implements Exception {
  LibraryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LibraryService {
  LibraryService._();

  static const _indexKey = 'lumina_library_index';
  static String _entryKey(String id) => 'lumina_library_entry_$id';

  static Future<List<String>> _ids() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_indexKey) ?? [];
  }

  static Future<void> _saveIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_indexKey, ids);
  }

  static Future<List<LibraryEntry>> listEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _ids();
    final entries = <LibraryEntry>[];
    for (final id in ids) {
      final raw = prefs.getString(_entryKey(id));
      if (raw == null) continue;
      try {
        entries.add(LibraryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  static Future<void> save(LibraryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entry.toJson());
    try {
      final ok = await prefs.setString(_entryKey(entry.id), encoded);
      if (!ok) {
        throw LibraryException('Could not save this book to your library (it may be too large).');
      }
    } catch (e) {
      if (e is LibraryException) rethrow;
      throw LibraryException(
        'Could not save this book to your library -- it is probably too large for browser storage.',
      );
    }
    final ids = await _ids();
    if (!ids.contains(entry.id)) {
      ids.add(entry.id);
      await _saveIds(ids);
    }
  }

  static Future<void> updateLastPage(String id, int lastPage) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entryKey(id));
    if (raw == null) return;
    try {
      final entry = LibraryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final updated = entry.copyWith(lastPage: lastPage);
      await prefs.setString(_entryKey(id), jsonEncode(updated.toJson()));
    } catch (_) {}
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entryKey(id));
    final ids = await _ids();
    ids.remove(id);
    await _saveIds(ids);
  }
}
