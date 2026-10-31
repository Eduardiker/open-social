import 'dart:convert';

class GamePackInfo {
  final String id;
  final String name;
  final String language;
  final String rating;
  final int version;
  final String file;

  GamePackInfo({
    required this.id,
    required this.name,
    required this.language,
    required this.rating,
    required this.version,
    required this.file,
  });

  factory GamePackInfo.fromJson(Map<String, dynamic> json) {
    return GamePackInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      language: json['language'] ?? 'es',
      rating: json['rating'] ?? 'all-ages',
      version: json['version'] ?? 1,
      file: json['file'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'language': language,
    'rating': rating,
    'version': version,
    'file': file,
  };
}

class GameDefinition {
  final String id;
  final String name;
  final String icon;
  final String description;
  final List<GamePackInfo> packs;

  GameDefinition({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.packs,
  });

  factory GameDefinition.fromJson(Map<String, dynamic> json) {
    return GameDefinition(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'sports_esports',
      description: json['description'] ?? '',
      packs: (json['packs'] as List<dynamic>? ?? [])
          .map((p) => GamePackInfo.fromJson(p))
          .toList(),
    );
  }
}

class ContentManifest {
  final String name;
  final String version;
  final List<String> languages;
  final List<GameDefinition> games;

  ContentManifest({
    required this.name,
    required this.version,
    required this.languages,
    required this.games,
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    return ContentManifest(
      name: json['name'] ?? '',
      version: json['version'] ?? '1.0.0',
      languages: List<String>.from(json['languages'] ?? ['es']),
      games: (json['games'] as List<dynamic>? ?? [])
          .map((g) => GameDefinition.fromJson(g))
          .toList(),
    );
  }

  static ContentManifest fromRawJson(String str) =>
      ContentManifest.fromJson(json.decode(str));
}
