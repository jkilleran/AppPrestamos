import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';

/// Raw response of one loan-option HTTP operation. The page layer decides
/// success versus failure and extracts safe user-facing messages.
class LoanOptionApiResponse {
  const LoanOptionApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Small injectable boundary over the four loan-option operations so widget
/// tests can supply fakes (exact call counts, controlled failures) without
/// real network access. Production behavior is provided by
/// [HttpLoanOptionsAdminApi].
abstract class LoanOptionsAdminApi {
  Future<LoanOptionApiResponse> fetchOptions();

  Future<LoanOptionApiResponse> createOption(Map<String, dynamic> payload);

  Future<LoanOptionApiResponse> updateOption(
    int id,
    Map<String, dynamic> payload,
  );

  Future<LoanOptionApiResponse> deleteOption(int id);
}

/// Production implementation: the preexisting `http` + `SharedPreferences`
/// behavior, unchanged — same `ApiConfig` URIs, same `Content-Type` header,
/// same `jwt_token` key, `Authorization: Bearer` only when a token exists.
/// Missing tokens are never invented or logged.
class HttpLoanOptionsAdminApi implements LoanOptionsAdminApi {
  const HttpLoanOptionsAdminApi();

  /// Same header construction the page used before the injectable boundary:
  /// JSON content type plus a bearer token only when one is stored.
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<LoanOptionApiResponse> fetchOptions() async {
    final response = await http.get(
      ApiConfig.uri('loan-options'),
      headers: await _headers(),
    );
    return LoanOptionApiResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<LoanOptionApiResponse> createOption(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      ApiConfig.uri('loan-options'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return LoanOptionApiResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<LoanOptionApiResponse> updateOption(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      ApiConfig.uri('loan-options/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return LoanOptionApiResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<LoanOptionApiResponse> deleteOption(int id) async {
    final response = await http.delete(
      ApiConfig.uri('loan-options/$id'),
      headers: await _headers(),
    );
    return LoanOptionApiResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}
