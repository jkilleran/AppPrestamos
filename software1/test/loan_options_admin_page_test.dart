import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1/loan_option_form_logic.dart';
import 'package:software1/loan_options_admin_page.dart';
import 'package:software1/loan_options_admin_api.dart';

/// In-memory fake: records exact call counts/payloads and can hold a request
/// pending via [Completer] gates to prove duplicate-mutation prevention.
class FakeLoanOptionsAdminApi implements LoanOptionsAdminApi {
  int fetchCount = 0;
  int fetchStatus = 200;
  String fetchBody = '[]';

  final List<String> mutationCalls = [];
  final List<Map<String, dynamic>> createdPayloads = [];
  final List<Map<String, dynamic>> updatedPayloads = [];
  final List<int> updatedIds = [];
  final List<int> deletedIds = [];

  int createStatus = 201;
  String createBody = '{}';
  Completer<LoanOptionApiResponse>? createGate;

  int updateStatus = 200;
  String updateBody = '{}';
  Completer<LoanOptionApiResponse>? updateGate;

  int deleteStatus = 200;
  String deleteBody = '{"success":true}';
  Completer<LoanOptionApiResponse>? deleteGate;

  @override
  Future<LoanOptionApiResponse> fetchOptions() async {
    fetchCount += 1;
    return LoanOptionApiResponse(statusCode: fetchStatus, body: fetchBody);
  }

  @override
  Future<LoanOptionApiResponse> createOption(Map<String, dynamic> payload) {
    mutationCalls.add('create');
    createdPayloads.add(payload);
    final gate = createGate;
    if (gate != null) return gate.future;
    return Future.value(
      LoanOptionApiResponse(statusCode: createStatus, body: createBody),
    );
  }

  @override
  Future<LoanOptionApiResponse> updateOption(
    int id,
    Map<String, dynamic> payload,
  ) {
    mutationCalls.add('update');
    updatedIds.add(id);
    updatedPayloads.add(payload);
    final gate = updateGate;
    if (gate != null) return gate.future;
    return Future.value(
      LoanOptionApiResponse(statusCode: updateStatus, body: updateBody),
    );
  }

  @override
  Future<LoanOptionApiResponse> deleteOption(int id) {
    mutationCalls.add('delete');
    deletedIds.add(id);
    final gate = deleteGate;
    if (gate != null) return gate.future;
    return Future.value(
      LoanOptionApiResponse(statusCode: deleteStatus, body: deleteBody),
    );
  }
}

const String _rowBody =
    '[{"id":7,"min_amount":100,"max_amount":500,"interest":7,"months":12,'
    '"categoria_minima":"Oro","ingreso_minimo":250.5}]';

const String _rowTitle = 'Monto: 100 - 500';
const String _rowSubtitle =
    'Interés: 7% | Plazo: 12 meses | Ingreso mín.: 250.5';

Widget _app(LoanOptionsAdminApi api) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoanOptionsAdminPage(api: api),
  );
}

/// Bounded pumps: indeterminate progress indicators never settle, so
/// pumpAndSettle must not be used with this page.
Future<void> _pump(WidgetTester tester, [int frames = 5]) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openCreateDialog(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await _pump(tester, 6);
  expect(find.text('Agregar Opción'), findsOneWidget);
}

Future<void> _fillValidForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '100'); // monto mínimo
  await tester.enterText(fields.at(1), '100'); // monto máximo
  await tester.enterText(fields.at(2), '0'); // interés
  await tester.enterText(fields.at(3), '1'); // meses
  await tester.enterText(fields.at(4), '0'); // ingreso mínimo
}

Future<void> _tapGuardar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
  await _pump(tester, 8); // dialog close animation + mutation start
}

/// A1.1/A1.2: completes every other field with a valid value, puts
/// [malformed] into the field at [index], submits, and proves the raw text
/// reaches the validator untransformed, concise feedback is shown, the
/// dialog stays open and no mutation/refresh occurs.
Future<void> _expectRejectedMalformed(
  WidgetTester tester,
  FakeLoanOptionsAdminApi fake, {
  required int index,
  required String malformed,
}) async {
  await _openCreateDialog(tester);
  await _fillValidForm(tester);
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(index), malformed);
  await _tapGuardar(tester);

  expect(find.text('Agregar Opción'), findsOneWidget); // dialog stays open
  expect(find.text('Número inválido'), findsOneWidget);
  final controller = tester.widget<TextFormField>(fields.at(index)).controller;
  expect(
    controller!.text,
    malformed,
    reason: 'raw input must reach the validator untransformed',
  );
  expect(fake.mutationCalls, isEmpty);
  expect(fake.createdPayloads, isEmpty);
  expect(fake.fetchCount, 1); // initial fetch only: no refresh, no mutation
}

void main() {
  group('A4 errores seguros en UI', () {
    testWidgets('fetch fallido muestra fallback sin detalles crudos', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()
        ..fetchStatus = 500
        ..fetchBody = 'relation "usuarios" does not exist';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);

      expect(find.text(kFetchFallbackError), findsOneWidget);
      expect(find.textContaining('relation'), findsNothing);
      expect(find.textContaining('500'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(fake.fetchCount, 1);
    });

    testWidgets('fetch 200 con cuerpo no-lista malformado usa el fallback', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '{"not": "a list"';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);

      expect(find.text(kFetchFallbackError), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(find.textContaining('{"not"'), findsNothing);
    });

    testWidgets(
      'fetch 200 con error JSON seguro muestra el mensaje del backend',
      (tester) async {
        final fake = FakeLoanOptionsAdminApi()
          ..fetchBody = '{"error":"No autorizado"}';
        await tester.pumpWidget(_app(fake));
        await _pump(tester);

        expect(find.text('No autorizado'), findsOneWidget);
        expect(find.text(kFetchFallbackError), findsNothing);
      },
    );

    testWidgets('fallo al guardar con cuerpo inseguro muestra fallback', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = _rowBody;
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);
      await _fillValidForm(tester);
      fake.createStatus = 500;
      fake.createBody = 'SELECT * FROM loan_options';
      await _tapGuardar(tester);

      expect(find.text(kCreateFallbackError), findsOneWidget);
      expect(find.textContaining('SELECT'), findsNothing);
      expect(fake.mutationCalls, ['create']);
      expect(fake.fetchCount, 1); // sin refresh en fallo
    });

    testWidgets('fallo al guardar con error JSON seguro muestra el backend', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()
        ..fetchBody = _rowBody
        ..createStatus = 400
        ..createBody = '{"error":"Datos inválidos"}';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);
      await _fillValidForm(tester);
      await _tapGuardar(tester);

      expect(find.text('Datos inválidos'), findsOneWidget);
      expect(find.text(kCreateFallbackError), findsNothing);
    });
  });

  group('A1/A2/A3/A7 validación y payload en el diálogo', () {
    testWidgets('max 0: diálogo abierto, error visible, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '0');
      await tester.enterText(fields.at(1), '0');
      await tester.enterText(fields.at(2), '0');
      await tester.enterText(fields.at(3), '1');
      await _tapGuardar(tester);

      expect(find.text('Agregar Opción'), findsOneWidget); // sigue abierto
      expect(find.text('Debe ser mayor que 0'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // entrada conservada, visible
      expect(fake.mutationCalls, isEmpty);
      expect(fake.fetchCount, 1);
    });

    testWidgets('relación min 100 > max 99.99: error, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '100');
      await tester.enterText(fields.at(1), '99.99');
      await tester.enterText(fields.at(2), '0');
      await tester.enterText(fields.at(3), '1');
      await _tapGuardar(tester);

      expect(find.text('Agregar Opción'), findsOneWidget);
      expect(
        find.text('El máximo debe ser mayor o igual al mínimo'),
        findsOneWidget,
      );
      expect(fake.mutationCalls, isEmpty);
    });

    testWidgets('meses 0: rechazado con diálogo abierto y sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);
      await _fillValidForm(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(3), '0');
      await _tapGuardar(tester);

      expect(find.text('Agregar Opción'), findsOneWidget);
      expect(find.text('Debe ser mayor que 0'), findsOneWidget);
      expect(fake.mutationCalls, isEmpty);
    });

    testWidgets('múltiples puntos (1..2): rechazado sin coerción', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);
      await _fillValidForm(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '1..2');
      await _tapGuardar(tester);

      expect(find.text('Agregar Opción'), findsOneWidget);
      expect(find.text('Número inválido'), findsOneWidget);
      expect(find.text('1..2'), findsWidgets); // la entrada inválida se ve
      expect(fake.mutationCalls, isEmpty);
      expect(fake.createdPayloads, isEmpty);
    });

    testWidgets('campos requeridos en blanco: "Requerido", sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);
      await _tapGuardar(tester);

      expect(find.text('Agregar Opción'), findsOneWidget);
      expect(find.text('Requerido'), findsNWidgets(4));
      expect(fake.mutationCalls, isEmpty);
    });

    testWidgets('submit válido: un create con payload normalizado exacto', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      expect(fake.fetchCount, 1);
      await _openCreateDialog(tester);
      await _fillValidForm(tester);
      await _tapGuardar(tester);

      expect(find.text('Agregar Opción'), findsNothing); // cerró
      expect(fake.mutationCalls, ['create']);
      expect(fake.createdPayloads, [
        {
          'min_amount': 100,
          'max_amount': 100,
          'interest': 0,
          'months': 1,
          'categoria_minima': 'Hierro',
          'ingreso_minimo': 0,
        },
      ]);
      expect(fake.fetchCount, 2); // exactamente un refresh tras el éxito
      expect(find.text(kCreateFallbackError), findsNothing);
    });

    testWidgets('ingreso vacío en submit válido se envía como null', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '100');
      await tester.enterText(fields.at(1), '100');
      await tester.enterText(fields.at(2), '0');
      await tester.enterText(fields.at(3), '1');
      await tester.enterText(fields.at(4), ''); // opcional en blanco
      await _tapGuardar(tester);

      expect(fake.mutationCalls, ['create']);
      expect(fake.createdPayloads.single.containsKey('ingreso_minimo'), isTrue);
      expect(fake.createdPayloads.single['ingreso_minimo'], isNull);
    });

    testWidgets('categoría seleccionada en el dropdown llega al payload', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _pump(tester, 6);
      await tester.tap(find.text('Esmeralda'));
      await _pump(tester, 6);
      await _fillValidForm(tester);
      await _tapGuardar(tester);

      expect(fake.mutationCalls, ['create']);
      expect(fake.createdPayloads.single['categoria_minima'], 'Esmeralda');
    });
  });

  group('A1.1/A1.2 entrada malformada conservada y rechazada', () {
    testWidgets('decimal 1e3: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(tester, fake, index: 0, malformed: '1e3');
    });

    testWidgets('decimal 0x10: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(tester, fake, index: 1, malformed: '0x10');
    });

    testWidgets('decimal -3: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(tester, fake, index: 2, malformed: '-3');
    });

    testWidgets('decimal 12abc: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(
        tester,
        fake,
        index: 4,
        malformed: '12abc',
      );
    });

    testWidgets('meses 1.5: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(tester, fake, index: 3, malformed: '1.5');
    });

    testWidgets('meses 1e3: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(tester, fake, index: 3, malformed: '1e3');
    });

    testWidgets('meses -3: texto intacto, rechazo, sin mutación', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = '[]';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _expectRejectedMalformed(tester, fake, index: 3, malformed: '-3');
    });

    testWidgets('error SQLSTATE del backend en create: fallback en UI', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()
        ..fetchBody = _rowBody
        ..createStatus = 500
        ..createBody =
            '{"error":"SQLSTATE[23503] detail: Key (loan_option_id)=(7) not present"}';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await _openCreateDialog(tester);
      await _fillValidForm(tester);
      await _tapGuardar(tester);

      expect(find.text(kCreateFallbackError), findsOneWidget);
      expect(find.textContaining('SQLSTATE'), findsNothing);
      expect(find.textContaining('detail'), findsNothing);
      expect(fake.mutationCalls, ['create']); // failed attempt recorded
      expect(fake.fetchCount, 1); // sin refresh en fallo
    });
  });

  group('A5 prevención de duplicados y restauración de controles', () {
    testWidgets(
      'tap repetido con create pendiente: una sola mutación, retry exacto',
      (tester) async {
        final fake = FakeLoanOptionsAdminApi()..fetchBody = _rowBody;
        fake.createGate = Completer<LoanOptionApiResponse>();
        await tester.pumpWidget(_app(fake));
        await _pump(tester);
        await _openCreateDialog(tester);
        await _fillValidForm(tester);
        await _tapGuardar(tester);

        // Mutación pendiente: exactamente una llamada.
        expect(fake.mutationCalls, ['create']);

        // Controles no disponibles + progreso visible.
        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        expect(fab.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final icons = tester.widgetList<IconButton>(find.byType(IconButton));
        expect(icons, hasLength(2));
        for (final icon in icons) {
          expect(icon.onPressed, isNull);
        }

        // Taps sobre controles deshabilitados: ninguna llamada adicional.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.tap(find.byIcon(Icons.edit));
        await tester.tap(find.byIcon(Icons.delete));
        await _pump(tester);
        expect(fake.mutationCalls, ['create']); // sigue exactamente una

        // El request falla → fallback seguro y controles restaurados.
        fake.createGate!.complete(
          const LoanOptionApiResponse(
            statusCode: 500,
            body: 'connection refused econnrefused127.0.0.1:3000',
          ),
        );
        fake.createGate = null;
        await _pump(tester, 8);
        expect(find.text(kCreateFallbackError), findsOneWidget);
        expect(find.textContaining('econnrefused'), findsNothing);
        final restored = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        expect(restored.onPressed, isNotNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Retry: exactamente una mutación nueva (total 2).
        await tester.tap(find.byType(FloatingActionButton));
        await _pump(tester, 6);
        await _fillValidForm(tester);
        await _tapGuardar(tester);
        expect(fake.mutationCalls, ['create', 'create']);
        expect(fake.createdPayloads, hasLength(2));
        expect(fake.fetchCount, 2); // 1 inicial + 1 del retry exitoso
      },
    );

    testWidgets(
      'delete: confirmación intacta, pendiente bloquea íconos, un solo refresh',
      (tester) async {
        final fake = FakeLoanOptionsAdminApi()..fetchBody = _rowBody;
        fake.deleteGate = Completer<LoanOptionApiResponse>();
        await tester.pumpWidget(_app(fake));
        await _pump(tester);
        await tester.tap(find.byIcon(Icons.delete));
        await _pump(tester, 6);

        // Confirmación preservada y aún sin mutación.
        expect(find.text('Eliminar opción'), findsOneWidget);
        expect(find.textContaining('¿Deseas continuar?'), findsOneWidget);
        expect(fake.mutationCalls, isEmpty);

        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await _pump(tester, 6);
        expect(fake.mutationCalls, ['delete']);
        expect(fake.deletedIds, [7]);

        // Con la mutación pendiente, los íconos quedan no disponibles.
        final icons = tester.widgetList<IconButton>(find.byType(IconButton));
        for (final icon in icons) {
          expect(icon.onPressed, isNull);
        }
        await tester.tap(find.byIcon(Icons.edit));
        await tester.tap(find.byIcon(Icons.delete));
        await _pump(tester);
        expect(fake.mutationCalls, ['delete']); // sin llamadas adicionales

        // Éxito → exactamente un refresh y controles restaurados.
        fake.deleteGate!.complete(
          const LoanOptionApiResponse(
            statusCode: 200,
            body: '{"success":true}',
          ),
        );
        fake.deleteGate = null;
        await _pump(tester, 8);
        expect(fake.fetchCount, 2);
        final restoredIcons = tester.widgetList<IconButton>(
          find.byType(IconButton),
        );
        for (final icon in restoredIcons) {
          expect(icon.onPressed, isNotNull);
        }
      },
    );

    testWidgets('delete fallido inseguro: fallback del backend, sin refresh', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()
        ..fetchBody = _rowBody
        ..deleteStatus = 500
        ..deleteBody = '{"error":"DELETE FROM loan_options WHERE id=7"}';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.delete));
      await _pump(tester, 6);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await _pump(tester, 8);

      expect(find.text(kDeleteFallbackError), findsOneWidget);
      expect(find.textContaining('DELETE'), findsNothing);
      expect(fake.mutationCalls, ['delete']);
      expect(fake.fetchCount, 1); // sin refresh en fallo
    });

    testWidgets('delete fallido con error JSON seguro muestra el backend', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()
        ..fetchBody = _rowBody
        ..deleteStatus = 404
        ..deleteBody = '{"error":"Opción no encontrada"}';
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.delete));
      await _pump(tester, 6);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await _pump(tester, 8);

      expect(find.text('Opción no encontrada'), findsOneWidget);
      expect(find.text(kDeleteFallbackError), findsNothing);
      expect(fake.fetchCount, 1);
    });
  });

  group('flujo de edición (A3/A5)', () {
    testWidgets('editar produce un update con id y payload exactos', (
      tester,
    ) async {
      final fake = FakeLoanOptionsAdminApi()..fetchBody = _rowBody;
      await tester.pumpWidget(_app(fake));
      await _pump(tester);
      expect(find.text(_rowTitle), findsOneWidget);
      expect(find.text(_rowSubtitle), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      await _pump(tester, 6);
      expect(find.text('Editar Opción'), findsOneWidget);
      expect(find.text('500'), findsWidgets); // prefijo cargado

      await _tapGuardar(tester);

      expect(find.text('Editar Opción'), findsNothing);
      expect(fake.mutationCalls, ['update']);
      expect(fake.updatedIds, [7]);
      expect(fake.updatedPayloads, [
        {
          'min_amount': 100,
          'max_amount': 500,
          'interest': 7,
          'months': 12,
          'categoria_minima': 'Oro',
          'ingreso_minimo': 250.5,
        },
      ]);
      expect(fake.fetchCount, 2); // un solo refresh tras éxito
    });
  });
}
