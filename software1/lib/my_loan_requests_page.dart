import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'loan_request_page.dart';
import 'loan_request_details_page.dart';
import 'brand_theme.dart';

class MyLoanRequestsPage extends StatefulWidget {
  const MyLoanRequestsPage({super.key});

  @override
  State<MyLoanRequestsPage> createState() => _MyLoanRequestsPageState();
}

class _MyLoanRequestsPageState extends State<MyLoanRequestsPage> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  final _currency = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-requests/mine',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red o inesperado: $e';
        _loading = false;
      });
    }
  }

  // ===== Helpers de presentación =====
  String _money(dynamic v) {
    final num? n = v is num ? v : num.tryParse(v?.toString() ?? '');
    if (n == null) return 'RD\$ 0.00';
    return _currency.format(n);
  }

  String _date(dynamic s) {
    try {
      DateTime dt;
      if (s is String) {
        dt = DateTime.parse(s).toLocal();
      } else if (s is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(s).toLocal();
      } else {
        return '';
      }
      return _dateFmt.format(dt);
    } catch (_) {
      return '';
    }
  }

  ({String label, Color color, Color bg, IconData icon}) _statusStyle(
    String? status,
  ) {
    final s = (status ?? '').toLowerCase();
    if (s == 'aprobado' || s == 'approved') {
      return (
        label: 'Aprobado',
        color: Colors.green.shade700,
        bg: Colors.green.withValues(alpha: 0.12),
        icon: Icons.check_circle,
      );
    }
    if (s == 'rechazado' || s == 'denied' || s == 'rejected') {
      return (
        label: 'Rechazado',
        color: Colors.red.shade700,
        bg: Colors.red.withValues(alpha: 0.12),
        icon: Icons.cancel,
      );
    }
    return (
      label: 'Pendiente',
      color: const Color(0xFFB7791F), // amber-700 like
      bg: const Color(0xFFFFB020).withValues(alpha: 0.16),
      icon: Icons.hourglass_top,
    );
  }

  void _showDetailsBottomSheet(Map<String, dynamic> req) {
    final status = _statusStyle(req['status']?.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: status.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(status.icon, color: status.color, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            status.label,
                            style: TextStyle(
                              color: status.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _money(req['amount']),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('${req['months']} meses', Icons.calendar_month),
                    if (req['interest'] != null)
                      _pill('Interés ${req['interest']}%', Icons.percent),
                    if ((req['created_at'] ?? req['createdAt']) != null)
                      _pill(
                        _date(req['created_at'] ?? req['createdAt']),
                        Icons.schedule,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((req['purpose'] ?? '').toString().trim().isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Propósito',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(req['purpose'].toString()),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pill(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BrandPalette.blue),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandPalette.blue, BrandPalette.navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Mis Solicitudes de Préstamo'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 56,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _fetchRequests,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _requests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 72, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    const Text(
                      'No tienes solicitudes de préstamo',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoanRequestPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.touch_app_outlined),
                      label: const Text('Pedir mi préstamo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandPalette.gold,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: _requests.length,
                itemBuilder: (context, i) {
                  final r = _requests[i] as Map<String, dynamic>;
                  final status = _statusStyle(r['status']?.toString());
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    curve: Curves.easeOut,
                    duration: Duration(milliseconds: 350 + i * 40),
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LoanRequestDetailsPage(loan: r),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: (() {
                              final statusStr = (r['status'] ?? '').toString().toLowerCase();
                              final hasSignature =
                                  (r['signature_status'] == 'firmada') ||
                                  (r['signature_data'] != null && (r['signature_data'] as String).isNotEmpty) ||
                                  (r['signed_at'] != null);
                              final isApprovedSigned = statusStr == 'aprobado' && hasSignature;
                              if (isApprovedSigned) {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                return isDark
                                    ? Colors.green.withValues(alpha: 0.22)
                                    : const Color(0xFFE6F9EE);
                              }
                              return Theme.of(context).cardColor;
                            })(),
                            borderRadius: BorderRadius.circular(18),
                            border: (() {
                              final statusStr = (r['status'] ?? '').toString().toLowerCase();
                              final hasSignature =
                                  (r['signature_status'] == 'firmada') ||
                                  (r['signature_data'] != null && (r['signature_data'] as String).isNotEmpty) ||
                                  (r['signed_at'] != null);
                              final isApprovedSigned = statusStr == 'aprobado' && hasSignature;
                              return isApprovedSigned
                                  ? Border.all(
                                      color: Colors.green.shade400,
                                      width: 1.3,
                                    )
                                  : null;
                            })(),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -16,
                                top: -16,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: BrandPalette.blue.withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: -10,
                                bottom: -20,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: BrandPalette.navy.withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: BrandPalette.blue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.monetization_on,
                                        color: BrandPalette.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _money(r['amount']),
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: status.bg,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      status.icon,
                                                      size: 16,
                                                      color: status.color,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      status.label,
                                                      style: TextStyle(
                                                        color: status.color,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _smallPill('${r['months']} meses', Icons.calendar_month),
                                              if (r['interest'] != null)
                                                _smallPill('Interés ${r['interest']}%', Icons.percent),
                                              if ((r['created_at'] ?? r['createdAt']) != null)
                                                _smallPill(_date(r['created_at'] ?? r['createdAt']), Icons.schedule),
                                            ],
                                          ),
                                          if ((r['purpose'] ?? '').toString().trim().isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              r['purpose'].toString(),
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

extension _CardBits on _MyLoanRequestsPageState {
  Widget _smallPill(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: BrandPalette.blue),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
