import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_application_1/config/app_config.dart';
import 'package:flutter_application_1/models/song.dart';

class SongService {
  static const _storage = FlutterSecureStorage();

  // ─── Headers autenticados ─────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ─── Biblioteca del usuario ───────────────────────────────
  static Future<List<LibrarySong>> getLibrary() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/api/songs/library/"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((j) => LibrarySong.fromJson(j)).toList();
      }
      print("Error en getLibrary (Status ${response.statusCode}): ${response.body}");
      return [];
    } catch (e, stack) {
      print("Excepción en getLibrary: $e");
      print(stack);
      return [];
    }
  }

  // ─── URL firmada para reproducir ─────────────────────────
  static Future<String?> getPlayUrl(String songId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/api/songs/$songId/play-url/"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['url'];
      }
      return null;
    } catch (e) {
      print("Excepción en getPlayUrl: $e");
      return null;
    }
  }

  // ─── URL firmada para thumbnail ───────────────────────────
  static Future<String?> getThumbnailUrl(String songId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/api/songs/$songId/thumbnail-url/"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['url'];
      }
      return null;
    } catch (e) {
      print("Excepción en getThumbnailUrl: $e");
      return null;
    }
  }

  // ─── Eliminar canción ─────────────────────────────────────
  static Future<bool> deleteSong(String songId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse("${AppConfig.baseUrl}/api/songs/$songId/"),
        headers: headers,
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print("Excepción en deleteSong: $e");
      return false;
    }
  }

  // ─── Publicar / despublicar ───────────────────────────────
  static Future<bool> togglePublic(String songId, bool isPublic) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse("${AppConfig.baseUrl}/api/songs/$songId/"),
        headers: headers,
        body: jsonEncode({"is_public": isPublic}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Excepción en togglePublic: $e");
      return false;
    }
  }
}