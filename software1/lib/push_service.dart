import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PushService {
  // NOTE: This only registers an already-known push token.
  // Obtaining the FCM token requires Firebase Messaging integration.
  static const String _apiBase = 'https://appprestamos-f5wz.onrender.com/api';

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? prefs.getString('token');
  }

  static Future<void> registerTokenWithBackend(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;

    final auth = await _getAuthToken();
    if (auth == null || auth.trim().isEmpty) return;

    try {
      await http.post(
        Uri.parse('$_apiBase/push/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $auth',
        },
        body: jsonEncode({'token': t, 'platform': _platformLabel()}),
      );
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> registerSavedTokenWithBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      if (token == null || token.trim().isEmpty) return;
      await registerTokenWithBackend(token);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    await registerTokenWithBackend(token);
  }
}
