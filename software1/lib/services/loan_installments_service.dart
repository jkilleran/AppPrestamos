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
      return jsonDecode(resp.body) as List<dynamic>;
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
    if (resp.statusCode == 200)
      return jsonDecode(resp.body) as Map<String, dynamic>;
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
      if (body is Map && body['installments'] is List)
        return body['installments'] as List<dynamic>;
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

  static Future<void> uploadReceipt({required int installmentId}) async {
    final t = await _token();
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return; // cancelado
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
    final resp = await req.send();
    if (resp.statusCode != 200) {
      final full = await http.Response.fromStream(resp);
      throw Exception('Error subiendo recibo ${resp.statusCode} ${full.body}');
    }
  }

  // Cliente: mis préstamos (reusa endpoint existente loan-requests/mine)
  static Future<List<dynamic>> myLoans() async {
    final t = await _token();
    final uri = Uri.parse('$baseUrl/loan-requests/mine');
    final resp = await http.get(
      uri,
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
    throw Exception('Error ${resp.statusCode} obteniendo mis préstamos');
  }
}
