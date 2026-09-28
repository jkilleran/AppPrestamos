import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionData {
  const AuthSessionData({
    required this.token,
    required this.role,
    required this.name,
  });

  final String token;
  final String role;
  final String name;
}

class AuthSession {
  AuthSession._();

  static const authPreferenceKeys = <String>{
    'jwt_token',
    'token',
    'user_role',
    'user_name',
    'user_email',
    'user_cedula',
    'user_telefono',
    'user_domicilio',
    'user_salario',
    'foto',
    'categoria',
    'prestamos_aprobados',
  };

  static Map<String, String> loginPayload({
    required String email,
    required String password,
  }) {
    return {'email': email.trim().toLowerCase(), 'password': password};
  }

  static AuthSessionData? readValid(
    SharedPreferences preferences, {
    DateTime? now,
  }) {
    try {
      final token = preferences.getString('jwt_token')?.trim();
      final role = preferences.getString('user_role');
      final name = preferences.getString('user_name');

      if (token == null ||
          token.isEmpty ||
          role == null ||
          role.trim().isEmpty ||
          name == null ||
          name.trim().isEmpty ||
          !isJwtUnexpired(token, now: now)) {
        return null;
      }

      return AuthSessionData(token: token, role: role, name: name);
    } catch (_) {
      return null;
    }
  }

  static bool isJwtUnexpired(String token, {DateTime? now}) {
    final expiration = jwtExpiration(token);
    if (expiration == null) return false;
    return expiration.isAfter((now ?? DateTime.now()).toUtc());
  }

  static DateTime? jwtExpiration(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3 || parts.any((part) => part.isEmpty)) return null;

      final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
      final payload = jsonDecode(utf8.decode(payloadBytes));
      if (payload is! Map<String, dynamic>) return null;

      final exp = payload['exp'];
      if (exp is! num || !exp.isFinite) return null;

      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * Duration.millisecondsPerSecond,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(SharedPreferences preferences) async {
    for (final key in authPreferenceKeys) {
      await preferences.remove(key);
    }
  }
}
