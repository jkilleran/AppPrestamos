import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:software1/main.dart';

String _expiredJwt() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'exp': 1})}.'
      'signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('arranca sin sesión y muestra el inicio de sesión', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AppThemeSwitcher());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('descarta una sesión expirada y conserva otras preferencias', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': _expiredJwt(),
      'token': _expiredJwt(),
      'user_role': 'admin',
      'user_name': 'Administrador',
      'user_email': 'admin@example.com',
      'fcm_token': 'token-del-dispositivo',
      'preferencia_no_relacionada': 'conservar',
    });

    await tester.pumpWidget(const AppThemeSwitcher());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar Sesión'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('jwt_token'), isNull);
    expect(preferences.getString('token'), isNull);
    expect(preferences.getString('user_role'), isNull);
    expect(preferences.getString('user_email'), isNull);
    expect(preferences.getString('fcm_token'), 'token-del-dispositivo');
    expect(preferences.getString('preferencia_no_relacionada'), 'conservar');
  });
}
