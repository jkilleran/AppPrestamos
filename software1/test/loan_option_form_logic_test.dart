import 'package:flutter_test/flutter_test.dart';
import 'package:software1/loan_option_form_logic.dart';

void main() {
  group('A2 gramática estricta (espejo del backend)', () {
    test('rechaza vacío, chatarra y parses parciales de números decimales', () {
      const invalid = [
        '',
        '   ',
        '1e3',
        '0x10',
        '1..2',
        '.5',
        '1.',
        '12abc',
        'abc',
        'Infinity',
        'NaN',
        '-5',
        '+5',
        '5e-3',
        '1,5',
        '0b101',
        '1 2',
        '٣', // non-ASCII digit
      ];
      for (final raw in invalid) {
        expect(strictParseDecimal(raw), isNull, reason: 'input: "$raw"');
      }
    });

    test(
      'acepta enteros y decimales válidos, incluidos espacios alrededor',
      () {
        expect(strictParseDecimal('0'), 0);
        expect(strictParseDecimal('100'), 100);
        expect(strictParseDecimal(' 100 '), 100);
        expect(strictParseDecimal('99.99'), closeTo(99.99, 1e-9));
        expect(strictParseDecimal('0.5'), 0.5);
      },
    );

    test('enteros estrictos rechazan decimal, signo, exponente y desborde', () {
      const invalid = [
        '',
        '1.5',
        '3.0',
        '-2',
        '+2',
        '1e3',
        '12abc',
        '0x10',
        '99999999999999999999', // fuera del rango int nativo
      ];
      for (final raw in invalid) {
        expect(strictParseInteger(raw), isNull, reason: 'input: "$raw"');
      }
      expect(strictParseInteger('1'), 1);
      expect(strictParseInteger('007'), 7);
      expect(strictParseInteger('9007199254740991'), 9007199254740991);
    });
  });

  group('A1 reglas del contrato backend', () {
    LoanOptionFormResult run({
      String min = '100',
      String max = '500',
      String interest = '7',
      String months = '12',
      String income = '',
      String category = 'Hierro',
    }) {
      return validateLoanOptionForm(
        minAmount: min,
        maxAmount: max,
        interest: interest,
        months: months,
        ingresoMinimo: income,
        categoriaMinima: category,
      );
    }

    test('min 0 con max 0 es inválido por el máximo, sin payload', () {
      final result = run(min: '0', max: '0', interest: '0', months: '1');
      expect(result.isValid, isFalse);
      expect(result.payload, isNull);
      expect(result.fieldErrors['max_amount'], 'Debe ser mayor que 0');
      expect(result.fieldErrors['min_amount'], isNull);
    });

    test('min 100 con max 99.99 viola la relación min <= max', () {
      final result = run(min: '100', max: '99.99');
      expect(result.isValid, isFalse);
      expect(result.payload, isNull);
      expect(
        result.fieldErrors['max_amount'],
        'El máximo debe ser mayor o igual al mínimo',
      );
    });

    test('meses: 0, decimal, negativo, exponente e inseguros rechazados', () {
      expect(run(months: '0').fieldErrors['months'], 'Debe ser mayor que 0');
      expect(run(months: '1.5').fieldErrors['months'], 'Número inválido');
      expect(run(months: '-3').fieldErrors['months'], 'Número inválido');
      expect(run(months: '1e3').fieldErrors['months'], 'Número inválido');
      expect(
        run(months: '9007199254740993').fieldErrors['months'],
        'Número fuera de rango',
      );
      expect(
        run(months: '99999999999999999999').fieldErrors['months'],
        'Número inválido',
      );
      expect(run(months: '1').isValid, isTrue);
      expect(run(months: '9007199254740991').isValid, isTrue);
    });

    test('campos requeridos en blanco dan "Requerido"', () {
      final result = run(min: '  ', max: '', interest: '', months: '');
      expect(result.fieldErrors['min_amount'], 'Requerido');
      expect(result.fieldErrors['max_amount'], 'Requerido');
      expect(result.fieldErrors['interest'], 'Requerido');
      expect(result.fieldErrors['months'], 'Requerido');
      expect(result.payload, isNull);
    });

    test('valores negativos se rechazan (nunca se coercen)', () {
      expect(run(min: '-1').fieldErrors['min_amount'], 'Número inválido');
      expect(run(interest: '-1').fieldErrors['interest'], 'Número inválido');
      expect(
        run(income: '-5').fieldErrors['ingreso_minimo'],
        'Número inválido',
      );
      expect(run(max: '-0.01').fieldErrors['max_amount'], 'Número inválido');
    });

    test('fronteras válidas: interés 0, min == max, un mes, ingreso 0', () {
      final result = run(
        min: '100',
        max: '100',
        interest: '0',
        months: '1',
        income: '0',
        category: 'Oro',
      );
      expect(result.isValid, isTrue);
      expect(result.fieldErrors, isEmpty);
    });

    test('las seis categorías canónicas son válidas; otras se rechazan', () {
      expect(kLoanOptionCategories, [
        'Hierro',
        'Plata',
        'Oro',
        'Platino',
        'Diamante',
        'Esmeralda',
      ]);
      for (final category in kLoanOptionCategories) {
        expect(
          run(category: category).isValid,
          isTrue,
          reason: 'categoría: $category',
        );
      }
      final result = run(category: 'platino');
      expect(result.isValid, isFalse);
      expect(result.fieldErrors['categoria_minima'], 'Categoría inválida');
    });
  });

  group('A3 payload numérico normalizado', () {
    test('límite válido exacto: min 0, interés 0, un mes, ingreso 0', () {
      final result = validateLoanOptionForm(
        minAmount: '0',
        maxAmount: '100',
        interest: '0',
        months: '1',
        ingresoMinimo: '0',
        categoriaMinima: 'Hierro',
      );
      expect(result.isValid, isTrue);
      expect(result.payload, {
        'min_amount': 0,
        'max_amount': 100,
        'interest': 0,
        'months': 1,
        'categoria_minima': 'Hierro',
        'ingreso_minimo': 0,
      });
      expect(result.payload!['min_amount'], isA<int>());
      expect(result.payload!['months'], isA<int>());
    });

    test('min == max exacto con ingreso vacío serializa null', () {
      final result = validateLoanOptionForm(
        minAmount: '100',
        maxAmount: '100',
        interest: '0',
        months: '1',
        ingresoMinimo: '',
        categoriaMinima: 'Oro',
      );
      expect(result.isValid, isTrue);
      expect(result.payload, {
        'min_amount': 100,
        'max_amount': 100,
        'interest': 0,
        'months': 1,
        'categoria_minima': 'Oro',
        'ingreso_minimo': null,
      });
      expect(result.payload!.containsKey('ingreso_minimo'), isTrue);
      expect(result.payload!['ingreso_minimo'], isNull);
      expect(result.payload!.keys.toSet(), {
        'min_amount',
        'max_amount',
        'interest',
        'months',
        'categoria_minima',
        'ingreso_minimo',
      });
    });

    test('decimales no integrales se conservan como double', () {
      final result = validateLoanOptionForm(
        minAmount: '100.50',
        maxAmount: '999.99',
        interest: '7.5',
        months: '12',
        ingresoMinimo: '250.5',
        categoriaMinima: 'Plata',
      );
      expect(result.isValid, isTrue);
      expect(result.payload!['min_amount'], 100.5);
      expect(result.payload!['min_amount'], isA<double>());
      expect(result.payload!['max_amount'], 999.99);
      expect(result.payload!['interest'], 7.5);
      expect(result.payload!['ingreso_minimo'], 250.5);
      expect(result.payload!['months'], 12);
    });

    test('entrada inválida nunca produce payload (sin ceros silenciosos)', () {
      final result = validateLoanOptionForm(
        minAmount: '1..2',
        maxAmount: '1e3',
        interest: '0x10',
        months: '0',
        ingresoMinimo: '12abc',
        categoriaMinima: 'Hierro',
      );
      expect(result.isValid, isFalse);
      expect(result.payload, isNull);
      expect(result.fieldErrors.length, 5);
    });
  });

  group('A4 selección segura de errores de API', () {
    const fallback = 'FALLBACK-DE-PRUEBA';
    String pick(String body) =>
        safeApiErrorMessage(body: body, fallback: fallback);

    test('prefiere el error JSON no vacío del backend', () {
      expect(pick('{"error":"Datos inválidos"}'), 'Datos inválidos');
      expect(pick('{"error":"No autorizado"}'), 'No autorizado');
      expect(pick('{"error":"Opción no encontrada"}'), 'Opción no encontrada');
      expect(pick('{"error":"Error interno"}'), 'Error interno');
      expect(
        pick('  {"error":"Opción no encontrada"}  '),
        'Opción no encontrada',
      );
    });

    test('cuerpos malformados, vacíos o sin error usan el fallback', () {
      const bodies = [
        '',
        '   ',
        'texto plano',
        '{"error":""}',
        '{"error":"   "}',
        '{"error":123}',
        '{"error":null}',
        '{"error":{"nested":true}}',
        '{}',
        '[1,2]',
        '{"error":',
        '<html>error</html>',
        'null',
        '42',
        '"error"',
      ];
      for (final body in bodies) {
        expect(pick(body), fallback, reason: 'body: $body');
      }
    });

    test('detalles inseguros dentro de "error" usan el fallback', () {
      const unsafe = [
        '{"error":"relation \\"loan_options\\" does not exist"}',
        '{"error":"SELECT * FROM usuarios"}',
        '{"error":"syntax error at or near \\"x\\""}',
        '{"error":"duplicate key value violates unique constraint"}',
        '{"error":"stack trace at Object.<anonymous>"}',
        '{"error":"Bearer abc.def.ghi"}',
        '{"error":"token expirado jwt_token=abc"}',
        '{"error":"econnrefused 127.0.0.1:3000"}',
        '{"error":"https://internals.example.com/debug"}',
        '{"error":"linea1\\nlinea2"}',
      ];
      for (final body in unsafe) {
        expect(pick(body), fallback, reason: 'body: $body');
      }
    });

    test('diagnósticos SQL, restricciones y rutas usan el fallback (A1.4)', () {
      const unsafe = [
        '{"error":"SQLSTATE[23503] detail: Key (id)=(7) not present"}',
        '{"error":"SQLSTATE 08006 connection failure"}',
        '{"error":"constraint=loan_options_pkey rejected"}',
        '{"error":"database query timeout after 30s"}',
        '{"error":"permission denied /Users/dev/logs/app.log"}',
        r'{"error":"C:\\logs\\app.txt could not be read"}',
        '{"error":"file:///private/var/tmp/debug.json missing"}',
        '{"error":"main.dart:10:5 during build"}',
      ];
      for (final body in unsafe) {
        expect(pick(body), fallback, reason: 'body: $body');
      }
    });

    test(
      'caracteres de control ASCII (CR, tab, retroceso) usan el fallback (A1.4)',
      () {
        // JSON-escaped controls decode into real ASCII control characters,
        // so the candidates reach the message-level control check.
        const unsafe = [
          r'{"error":"Datos inválidos\rintentar de nuevo"}',
          r'{"error":"campo\tvalor interno"}',
          r'{"error":"mensaje\binvisible"}',
        ];
        for (final body in unsafe) {
          expect(pick(body), fallback, reason: 'body: $body');
        }
      },
    );

    test('límite de longitud: 200 caracteres pasa, 201 usa el fallback', () {
      final twoHundred = 'x' * 200;
      final twoHundredOne = 'x' * 201;
      expect(pick('{"error":"$twoHundred"}'), twoHundred);
      expect(pick('{"error":"$twoHundredOne"}'), fallback);
    });

    test('los cuatro fallbacks por operación son distintos y no vacíos', () {
      final fallbacks = {
        kFetchFallbackError,
        kCreateFallbackError,
        kEditFallbackError,
        kDeleteFallbackError,
      };
      expect(fallbacks.length, 4);
      for (final message in fallbacks) {
        expect(message.trim().isNotEmpty, isTrue);
      }
      expect(kFetchFallbackError, 'No se pudieron cargar las opciones');
      expect(kCreateFallbackError, 'No se pudo crear la opción');
      expect(kEditFallbackError, 'No se pudo actualizar la opción');
      expect(kDeleteFallbackError, 'No se pudo eliminar la opción');
    });
  });
}
