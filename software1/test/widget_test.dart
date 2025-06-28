// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:software1/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(
      themeMode: ThemeMode.light,
      onToggleTheme: () {},
    ));
    // Verifica que la pantalla de novedades esté presente
    expect(find.text('Novedades del Administrador'), findsOneWidget);
    expect(find.text('Bienvenido al sistema de préstamos. Aquí aparecerán las novedades y avisos importantes del administrador.'), findsOneWidget);
    // Verifica que el botón del menú esté presente
    expect(find.byType(Drawer), findsNothing); // Drawer solo aparece al abrir el menú
  });
}
