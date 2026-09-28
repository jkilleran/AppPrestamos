import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:software1/utils/auth_session.dart';

String _jwtWithExpiration(DateTime expiration) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'exp': expiration.millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthSession', () {
    final now = DateTime.utc(2026, 8, 17, 12);

    test('normaliza el email sin alterar la contraseña', () {
      final payload = AuthSession.loginPayload(
        email: '  Admin@Example.COM  ',
        password: '  contraseña con espacios  ',
      );

      expect(payload['email'], 'admin@example.com');
      expect(payload['password'], '  contraseña con espacios  ');
    });

    test('acepta una sesión completa con JWT vigente', () async {
      final token = _jwtWithExpiration(now.add(const Duration(minutes: 5)));
      SharedPreferences.setMockInitialValues({
        'jwt_token': token,
        'user_role': 'admin',
        'user_name': 'Administrador',
      });
      final preferences = await SharedPreferences.getInstance();

      final session = AuthSession.readValid(preferences, now: now);

      expect(session, isNotNull);
      expect(session!.token, token);
      expect(session.role, 'admin');
      expect(session.name, 'Administrador');
    });

    test('rechaza JWT expirados, incompletos o corruptos', () async {
      final expired = _jwtWithExpiration(
        now.subtract(const Duration(seconds: 1)),
      );
      SharedPreferences.setMockInitialValues({
        'jwt_token': expired,
        'user_role': 'admin',
        'user_name': 'Administrador',
      });
      var preferences = await SharedPreferences.getInstance();
      expect(AuthSession.readValid(preferences, now: now), isNull);

      SharedPreferences.setMockInitialValues({
        'jwt_token': 'no-es-un-jwt',
        'user_role': 'admin',
        'user_name': 'Administrador',
      });
      preferences = await SharedPreferences.getInstance();
      expect(AuthSession.readValid(preferences, now: now), isNull);

      SharedPreferences.setMockInitialValues({
        'jwt_token': _jwtWithExpiration(now.add(const Duration(minutes: 5))),
        'user_role': 'admin',
      });
      preferences = await SharedPreferences.getInstance();
      expect(AuthSession.readValid(preferences, now: now), isNull);
    });

    test('limpia solo datos de autenticación y perfil del usuario', () async {
      final initialValues = <String, Object>{
        for (final key in AuthSession.authPreferenceKeys) key: 'dato',
        'prestamos_aprobados': 3,
        'fcm_token': 'token-del-dispositivo',
        'preferencia_no_relacionada': 'conservar',
      };
      SharedPreferences.setMockInitialValues(initialValues);
      final preferences = await SharedPreferences.getInstance();

      await AuthSession.clear(preferences);

      for (final key in AuthSession.authPreferenceKeys) {
        expect(preferences.containsKey(key), isFalse, reason: key);
      }
      expect(preferences.getString('fcm_token'), 'token-del-dispositivo');
      expect(preferences.getString('preferencia_no_relacionada'), 'conservar');
    });
  });
}
