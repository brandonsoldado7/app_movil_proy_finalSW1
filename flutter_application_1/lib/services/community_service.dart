import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_application_1/config/app_config.dart';

// Importa los modelos desde main_tabs_page.dart (o muévelos a un archivo
// separado models/community_song.dart si prefieres más orden).
import 'package:flutter_application_1/pages/main_tabs_page.dart'
    show CommunitySongModel, CommunityFeedResult, CommunityStatsModel, LikeResult;

class CommunityService {
  static const _storage = FlutterSecureStorage();

  // ── Headers ───────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Feed público ──────────────────────────────────────────────────────────
  static Future<CommunityFeedResult?> getFeed({
    int page = 1,
    String tag = '',
    String search = '',
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.baseUrl}/api/community/feed/').replace(
        queryParameters: {
          'page': '$page',
          if (tag.isNotEmpty) 'tag': tag,
          if (search.isNotEmpty) 'search': search,
        },
      );
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final results = (body['results'] as List)
            .map((j) => CommunitySongModel.fromJson(j))
            .toList();
        return CommunityFeedResult(
          results: results,
          hasNext: body['has_next'] ?? false,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Estadísticas ──────────────────────────────────────────────────────────
  static Future<CommunityStatsModel?> getStats() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/community/stats/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return CommunityStatsModel.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── URL firmada para reproducir ───────────────────────────────────────────
  static Future<String?> getPlayUrl(String songId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/songs/$songId/play-url/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── URL firmada para thumbnail ────────────────────────────────────────────
  static Future<String?> getThumbnailUrl(String songId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/songs/$songId/thumbnail-url/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Toggle like ───────────────────────────────────────────────────────────
  static Future<LikeResult?> toggleLike(String songId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/community/$songId/like/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return LikeResult(
          liked: body['liked'] ?? false,
          likeCount: body['like_count'] ?? 0,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Registrar reproducción ────────────────────────────────────────────────
  static Future<void> recordPlay(String songId,
      {int durationSeconds = 0}) async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/community/$songId/play/'),
        headers: headers,
        body: jsonEncode({'duration_seconds': durationSeconds}),
      );
    } catch (_) {}
  }
}