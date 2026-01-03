import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoanInstallmentsService {
  static const String baseUrl = 'https://appprestamos-f5wz.onrender.com';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<List<dynamic>> adminActiveLoans() async {
    final t = await _token();
    final uri = Uri.parse('$baseUrl/loan-installments/admin/active');
    final resp = await http.get(
      uri,
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    if (resp.statusCode == 200) {
      final raw = jsonDecode(resp.body);
      if (raw is List) {
        return raw.map((e) => _normalizeLoanAggregate(e)).toList();
      }
      return [];
    }
    throw Exception('Error ${resp.statusCode} obteniendo préstamos activos');
  }

  static Future<Map<String, dynamic>> loanProgress(int loanId) async {
    final t = await _token();
    final uri = Uri.parse('$baseUrl/loan-installments/$loanId/progress');
    final resp = await http.get(
      uri,
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      return _normalizeProgress(map);
    }
    throw Exception('Error ${resp.statusCode} progreso');
  }

  static Future<List<dynamic>> loanInstallments(int loanId) async {
    final t = await _token();
    final uri = Uri.parse('$baseUrl/loan-installments/$loanId');
    final resp = await http.get(
      uri,
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body is Map && body['installments'] is List) {
        return (body['installments'] as List)
            .map((e) => _normalizeInstallment(e))
            .toList();
      }
      return [];
    }
    throw Exception('Error ${resp.statusCode} cuotas');
  }

  static Future<void> adminMarkOverdue() async {
    final t = await _token();
    final uri = Uri.parse('$baseUrl/loan-installments/admin/mark-overdue');
    final resp = await http.post(
      uri,
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    if (resp.statusCode != 200) {
      throw Exception('No se marcaron atrasadas (${resp.statusCode})');
    }
  }

  static Future<void> adminUpdateInstallmentStatus({
    required int installmentId,
    required String status,
    double? paidAmount,
  }) async {
    final t = await _token();
    final uri = Uri.parse(
      '$baseUrl/loan-installments/installment/$installmentId/status',
    );
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (t != null) 'Authorization': 'Bearer $t',
      },
      body: jsonEncode({
        'status': status,
        if (paidAmount != null) 'paid_amount': paidAmount,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Error cambiando estado cuota (${resp.statusCode}) ${resp.body}',
      );
    }
  }

  static Future<Map<String, dynamic>?> uploadReceipt({
    required int installmentId,
  }) async {
    final t = await _token();
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null; // cancelado
    final file = result.files.single;
    final uri = Uri.parse(
      '$baseUrl/loan-installments/installment/$installmentId/report',
    );
    final req = http.MultipartRequest('POST', uri);
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    if (!kIsWeb && file.path != null) {
      req.files.add(await http.MultipartFile.fromPath('document', file.path!));
    } else if (file.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'document',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else {
      throw Exception('Archivo inválido');
    }
    final streamed = await req.send();
    final full = await http.Response.fromStream(streamed);
    if (full.statusCode != 200) {
      // Intentar parsear JSON de error para mostrar mensaje más claro
      try {
        final data = jsonDecode(full.body);
        if (data is Map && data['error'] != null) {
          final reason = data['reason'] ?? data['details'] ?? '';
          throw Exception(
            'Error recibo: ${data['error']}${reason != '' ? ' - $reason' : ''}',
          );
        }
      } catch (_) {
        // ignorar parse error, lanzamos genérico abajo
      }
      throw Exception('Error subiendo recibo ${full.statusCode}');
    }
    // Éxito: validar payload para ver si ok == true
    try {
      final data = jsonDecode(full.body);
      if (data is Map && data['ok'] == true) {
        if (data['installment'] is Map<String, dynamic>) {
          // Normalizamos para asegurar que los campos numéricos sean double/int y no String
          return _normalizeInstallment(data['installment']);
        }
        return {'ok': true}; // fallback mínimo
      }
      // Si no hay ok true pero status 200, lo aceptamos igual.
    } catch (_) {
      // Ignorar parse si no es JSON válido.
    }
    return {'ok': true};
  }

  // Cliente: mis préstamos (reusa endpoint existente loan-requests/mine)
  static Future<List<dynamic>> myLoans() async {
    final t = await _token();
    final uri = Uri.parse('$baseUrl/loan-requests/mine');
    final resp = await http.get(
      uri,
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    if (resp.statusCode == 200) {
      final raw = jsonDecode(resp.body);
      if (raw is List) return raw.map((e) => _normalizeLoanBasic(e)).toList();
    }
    throw Exception('Error ${resp.statusCode} obteniendo mis préstamos');
  }

  // -------------------- Normalization helpers --------------------
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String)
      return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
    return 0;
  }

  static Map<String, dynamic> _normalizeLoanAggregate(dynamic raw) {
    if (raw is! Map) return {};
    return {
      ...raw,
      'loan_id': raw['loan_id'],
      'amount': _toDouble(raw['amount']),
      'months': _toInt(raw['months']),
      'interest': _toDouble(raw['interest']),
      'cuotas_total': _toInt(raw['cuotas_total']),
      'cuotas_pagadas': _toInt(raw['cuotas_pagadas']),
      'total_programado': _toDouble(raw['total_programado']),
      'total_pagado': _toDouble(raw['total_pagado']),
    };
  }

  static Map<String, dynamic> _normalizeInstallment(dynamic raw) {
    if (raw is! Map) return {};
    return {
      ...raw,
      'capital': _toDouble(raw['capital']),
      'interest': _toDouble(raw['interest']),
      'total_due': _toDouble(raw['total_due']),
      'paid_amount': _toDouble(raw['paid_amount']),
      'installment_number': _toInt(raw['installment_number']),
      'id': raw['id'],
    };
  }

  static Map<String, dynamic> _normalizeProgress(Map<String, dynamic> raw) {
    return {
      ...raw,
      'cuotas_total': _toInt(raw['cuotas_total']),
      'cuotas_pagadas': _toInt(raw['cuotas_pagadas']),
      'cuotas_reportadas': _toInt(raw['cuotas_reportadas']),
      'cuotas_pendientes': _toInt(raw['cuotas_pendientes']),
      'cuotas_atrasadas': _toInt(raw['cuotas_atrasadas']),
      'total_programado': _toDouble(raw['total_programado']),
      'total_pagado': _toDouble(raw['total_pagado']),
      'porcentaje_pagado': _toDouble(raw['porcentaje_pagado']),
    };
  }

  static Map<String, dynamic> _normalizeLoanBasic(dynamic raw) {
    if (raw is! Map) return {};
    return {
      ...raw,
      'amount': _toDouble(raw['amount']),
      'months': _toInt(raw['months']),
      'interest': _toDouble(raw['interest']),
    };
  }
}
