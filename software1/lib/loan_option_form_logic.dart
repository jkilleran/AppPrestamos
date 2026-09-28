import 'dart:convert';

/// Pure validation/normalization and safe-error logic for the admin
/// loan-option form. Mirrors the backend contract implemented in
/// `backend/controllers/loan_option.controller.js`
/// (`parseStrictNumber`, `parseStrictPositiveInt`, `validateLoanOptionPayload`)
/// so the UI rejects exactly what the API rejects and never coerces invalid
/// input. No Flutter/UI imports: this file is exercised by pure unit tests.

/// JS `Number.MAX_SAFE_INTEGER`. The backend rejects unsafe integers for
/// `months`, so the form must too. No monetary caps are imposed here.
const int maxSafeInteger = 9007199254740991;

/// The six canonical category values, in the established order.
const List<String> kLoanOptionCategories = [
  'Hierro',
  'Plata',
  'Oro',
  'Platino',
  'Diamante',
  'Esmeralda',
];

// Form field error messages (concise Spanish guidance).
const String kFieldRequiredMessage = 'Requerido';
const String kFieldInvalidNumberMessage = 'Número inválido';
const String kMustBePositiveMessage = 'Debe ser mayor que 0';
const String kMaxBelowMinMessage = 'El máximo debe ser mayor o igual al mínimo';
const String kValueOutOfRangeMessage = 'Número fuera de rango';
const String kInvalidCategoryMessage = 'Categoría inválida';

// Operation-specific fallbacks shown when the response body carries no safe
// `{ "error": <string> }` message, or when the request throws.
const String kFetchFallbackError = 'No se pudieron cargar las opciones';
const String kCreateFallbackError = 'No se pudo crear la opción';
const String kEditFallbackError = 'No se pudo actualizar la opción';
const String kDeleteFallbackError = 'No se pudo eliminar la opción';

// Backend grammar `^\d+(\.\d+)$` equivalent: digits with an optional
// fractional part. Rejects blank, sign, exponent, hex, leading/trailing dot,
// multiple dots and any trailing junk.
final RegExp _decimalGrammar = RegExp(r'^\d+(\.\d+)?$');

// Backend grammar `^\d+$` for integers.
final RegExp _integerGrammar = RegExp(r'^\d+$');

/// Content that must never reach the user even if a server (or a non-JSON
/// error page routed through the `error` field) embeds it in an `error`
/// string: SQL fragments, SQLSTATE/detail/constraint/query diagnostics,
/// stack traces and file/stack-frame locations, credentials/tokens and
/// transport internals (tasks A4 and A1.4).
final RegExp _unsafeErrorContent = RegExp(
  r'\bselect\b|\binsert\b|\bupdate\b|\bdelete\b|\bdrop\b|\balter\b|'
  r'\bcreate\b\s+\btable\b|\btruncate\b|\bgrant\b|'
  // A1.4: SQL/runtime diagnostics and database query failures.
  r'sqlstate|detail\s*[=:]|constraint\s*[=:]|\bsql\b|\bquery\b|'
  r'relation|syntax error|does not exist|duplicate key|violat|'
  r'stack|trace|exception|at\s+\w+\.|'
  // A1.4: file-location forms — scheme URI, Unix roots (superset that
  // includes the former /proc/ and /etc/ entries), Windows drive paths and
  // file:line:col stack frames.
  r'\bfile:|/(?:users|home|var|private|proc|etc|tmp)/|[a-z]:\\|\.\w{1,6}:\d+|'
  r'https?://|\bbearer\b|authorization|password|passwd|secret|\btoken\b|'
  r'econnrefused|etimedout|econnreset|epipe|socket|postgresql|\bpg_',
  caseSensitive: false,
);

/// ASCII control characters (NUL..US and DEL: CR, LF, tab, backspace, etc.)
/// must never appear in a user-facing message: they enable multi-line
/// diagnostic dumps and log injection (A1.4).
final RegExp _asciiControlChars = RegExp(r'[\x00-\x1F\x7F]');

/// Strict decimal parse mirroring backend `parseStrictNumber`: trimmed input,
/// digits-only grammar, finite value. Returns `null` for blank, malformed
/// (exponent, hex, `1..2`, `.5`, `1.`, trailing junk, sign) or non-finite
/// input. Never coerces invalid text to zero.
double? strictParseDecimal(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!_decimalGrammar.hasMatch(text)) return null;
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Strict integer parse for `months`: trimmed digits-only grammar (mirrors
/// backend `parseStrictPositiveInt`). Returns `null` for blank or malformed
/// input, including decimals (`1.5`), exponents, signs and trailing junk.
int? strictParseInteger(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!_integerGrammar.hasMatch(text)) return null;
  return int.tryParse(text); // null when the value exceeds the native int range
}

/// Outcome of a full form validation: per-field Spanish messages when
/// invalid, or the normalized JSON payload when valid. The payload is built
/// ONLY from successfully validated values (task A3).
class LoanOptionFormResult {
  const LoanOptionFormResult({required this.fieldErrors, this.payload});

  /// field key (payload key) -> Spanish message; empty when valid.
  final Map<String, String> fieldErrors;

  /// Normalized payload; non-null only when [fieldErrors] is empty.
  final Map<String, dynamic>? payload;

  bool get isValid => payload != null && fieldErrors.isEmpty;
}

/// Normalizes a validated finite number for JSON: integral values become
/// `int` (so `100`, `0`, `1` serialize without decimals) and non-integral
/// values stay `double` (`99.99`). Values beyond the JS safe-integer range
/// remain `double` instead of being capped (no new financial caps).
num _normalizeNum(double value) {
  if (value == value.truncateToDouble() && value.abs() <= maxSafeInteger) {
    return value.toInt();
  }
  return value;
}

/// Validates the raw dialog texts against the backend loan-option contract.
///
/// Rules: `min_amount` finite and >= 0; `max_amount` finite, > 0 and
/// >= min; `interest` finite and >= 0; `months` a positive safe integer;
/// optional `ingreso_minimo` null when blank, otherwise finite and >= 0;
/// `categoria_minima` one of the six canonical values. Invalid input yields
/// per-field messages and a null payload — never a silent conversion.
LoanOptionFormResult validateLoanOptionForm({
  required String minAmount,
  required String maxAmount,
  required String interest,
  required String months,
  required String ingresoMinimo,
  required String categoriaMinima,
}) {
  final errors = <String, String>{};

  double? min;
  final minText = minAmount.trim();
  if (minText.isEmpty) {
    errors['min_amount'] = kFieldRequiredMessage;
  } else {
    // The digits-only grammar already guarantees a finite, non-negative
    // value (mirrors backend parseStrictNumber + `min < 0` rejection).
    min = strictParseDecimal(minAmount);
    if (min == null) {
      errors['min_amount'] = kFieldInvalidNumberMessage;
    }
  }

  double? max;
  final maxText = maxAmount.trim();
  if (maxText.isEmpty) {
    errors['max_amount'] = kFieldRequiredMessage;
  } else {
    max = strictParseDecimal(maxAmount);
    if (max == null) {
      errors['max_amount'] = kFieldInvalidNumberMessage;
    } else if (max <= 0) {
      errors['max_amount'] = kMustBePositiveMessage;
    }
  }

  // Cross-field relation: only when both sides parse successfully.
  if (errors['max_amount'] == null &&
      errors['min_amount'] == null &&
      min != null &&
      max != null &&
      max < min) {
    errors['max_amount'] = kMaxBelowMinMessage;
  }

  double? rate;
  final interestText = interest.trim();
  if (interestText.isEmpty) {
    errors['interest'] = kFieldRequiredMessage;
  } else {
    rate = strictParseDecimal(interest);
    if (rate == null) {
      errors['interest'] = kFieldInvalidNumberMessage;
    }
  }

  int? monthCount;
  final monthsText = months.trim();
  if (monthsText.isEmpty) {
    errors['months'] = kFieldRequiredMessage;
  } else {
    monthCount = strictParseInteger(months);
    if (monthCount == null) {
      errors['months'] = kFieldInvalidNumberMessage;
    } else if (monthCount <= 0) {
      errors['months'] = kMustBePositiveMessage;
    } else if (monthCount > maxSafeInteger) {
      errors['months'] = kValueOutOfRangeMessage;
    }
  }

  double? income;
  final incomeText = ingresoMinimo.trim();
  if (incomeText.isEmpty) {
    income = null; // optional: blank stays JSON null
  } else {
    income = strictParseDecimal(ingresoMinimo);
    if (income == null) {
      errors['ingreso_minimo'] = kFieldInvalidNumberMessage;
    }
  }

  if (!kLoanOptionCategories.contains(categoriaMinima)) {
    errors['categoria_minima'] = kInvalidCategoryMessage;
  }

  if (errors.isNotEmpty || min == null || max == null || rate == null) {
    return LoanOptionFormResult(fieldErrors: errors);
  }

  return LoanOptionFormResult(
    fieldErrors: const {},
    payload: <String, dynamic>{
      'min_amount': _normalizeNum(min),
      'max_amount': _normalizeNum(max),
      'interest': _normalizeNum(rate),
      'months': monthCount,
      'categoria_minima': categoriaMinima,
      'ingreso_minimo': income == null ? null : _normalizeNum(income),
    },
  );
}

/// Returns the safe backend `{ "error": <string> }` message when [body] is a
/// JSON object with a concise, single-line, content-safe string; otherwise
/// returns [fallback]. Never throws and never returns raw bodies, stack
/// traces, SQL, credentials, tokens or transport internals to the UI (A4).
String safeApiErrorMessage({required String body, required String fallback}) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is String) {
        final message = error.trim();
        if (message.isNotEmpty &&
            message.length <= 200 &&
            !_asciiControlChars.hasMatch(message) &&
            !_unsafeErrorContent.hasMatch(message)) {
          return message;
        }
      }
    }
  } catch (_) {
    // Malformed/empty body: fall through to the operation-specific fallback.
  }
  return fallback;
}
