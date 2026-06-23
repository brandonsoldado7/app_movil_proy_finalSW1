import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/config/app_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  // ─── Login ────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/api/auth/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _storage.write(key: 'access_token', value: data['access']);
        await _storage.write(key: 'refresh_token', value: data['refresh']);

        if (data['user'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(data['user']));
        }

        // ─── Enviar token FCM al backend ──────────────────
        await _sendFcmToken(data['access']);

        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Enviar FCM token al backend ──────────────────────────
  static Future<void> _sendFcmToken(String accessToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      await http.post(
        Uri.parse("${AppConfig.baseUrl}/api/auth/fcm-token/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({"fcm_token": fcmToken}),
      );
    } catch (e) {
      // Si falla no interrumpe el login
    }
  }

  // ─── Getters ──────────────────────────────────────────────
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return null;
    return jsonDecode(userStr);
  }

  // ─── Logout ───────────────────────────────────────────────
  static Future<void> logout() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── Headers autenticados ─────────────────────────────────
  static Future<Map<String, String>> authHeaders() async {
    final token = await getAccessToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }
}