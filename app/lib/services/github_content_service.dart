import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';

class GitHubContentService {
  // Repositorio de GitHub por defecto para el contenido comunitario
  static const String defaultRepoOwner = "open-social-app";
  static const String defaultRepoName = "open-social-content";
  static const String defaultBranch = "main";

  static String get rawContentBaseUrl =>
      "https://raw.githubusercontent.com/$defaultRepoOwner/$defaultRepoName/$defaultBranch";

  final SharedPreferences prefs;

  GitHubContentService({required this.prefs});

  static Future<GitHubContentService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return GitHubContentService(prefs: preferences);
  }

  /// Carga el manifiesto del índice (primero intenta cache local, luego bundled asset o remoto)
  Future<ContentManifest?> getManifest({bool forceRefresh = false}) async {
    final cached = prefs.getString('cached_manifest');

    if (!forceRefresh && cached != null && cached.isNotEmpty) {
      try {
        return ContentManifest.fromRawJson(cached);
      } catch (e) {
        // Fallback si la cache estaba corrupta
      }
    }

    // Intentar sincronizar desde GitHub
    if (forceRefresh || cached == null) {
      try {
        final url = Uri.parse("$rawContentBaseUrl/index.json");
        final response = await http.get(url).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          await prefs.setString('cached_manifest', response.body);
          return ContentManifest.fromRawJson(response.body);
        }
      } catch (_) {
        // En caso de estar offline o no haber conexión
      }
    }

    // Fallback de emergencia a assets integrados en el binario
    try {
      final localAsset = await rootBundle.loadString('assets/content/index.json');
      return ContentManifest.fromRawJson(localAsset);
    } catch (_) {
      return null;
    }
  }

  /// Carga el contenido de un pack específico (Offline-first)
  Future<Map<String, dynamic>?> loadPackContent(String filePath, {bool forceRefresh = false}) async {
    final cacheKey = 'pack_$filePath';
    final cachedData = prefs.getString(cacheKey);

    if (!forceRefresh && cachedData != null) {
      try {
        return json.decode(cachedData) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Intentar descargar desde GitHub
    try {
      final url = Uri.parse("$rawContentBaseUrl/$filePath");
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, response.body);
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Fallback a asset local en la app
    try {
      final localData = await rootBundle.loadString('assets/content/$filePath');
      return json.decode(localData) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
