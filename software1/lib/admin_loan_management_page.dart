import 'dart:async';
import 'package:flutter/material.dart';
import 'brand_theme.dart';
import 'package:intl/intl.dart';
import 'admin_loan_detail_page.dart';
import 'services/loan_installments_service.dart';
// snackbar_helper ya no es necesario aquí (se removieron botones manuales)

// ...existing code...

class AdminLoanManagementPage extends StatefulWidget {
  const AdminLoanManagementPage({super.key});
  @override
  State<AdminLoanManagementPage> createState() =>
      _AdminLoanManagementPageState();
}

class _AdminLoanManagementPageState extends State<AdminLoanManagementPage> {
  // Mover la función aquí para evitar referencia antes de declaración y fuera del builder
  Widget _buildIndicator(String label, Color color, IconData icon, int count) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  final NumberFormat _moneyFormat = NumberFormat(
    '#,##0',
    'en_US',
  ); // Usar coma como separador
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetch(); // Fuerza refresco cada vez que la página se muestra
  }

  // Marca el préstamo como liquidado

  // Helper to safely parse numbers from dynamic values
  num parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  // Helper to create pill widgets for card details
  bool _loading = true;
  String? _error;
  List<dynamic> _loans = [];
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  int _visibleCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 40),
      (_) => _fetch(silent: true),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (_visibleCount < _loans.length) {
        setState(() {
          _visibleCount = (_visibleCount + _pageSize).clamp(0, _loans.length);
        });
      }
    }
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Marca atrasadas de forma silenciosa antes de refrescar (ignora errores)
      try {
        await LoanInstallmentsService.adminMarkOverdue();
      } catch (_) {}
      final data = await LoanInstallmentsService.adminActiveLoans();
      if (mounted) {
        setState(() {
          _loans = data;
          if (_visibleCount == 0) {
            _visibleCount = data.length > _pageSize ? _pageSize : data.length;
          } else {
            _visibleCount = _visibleCount.clamp(0, data.length);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // _markOverdue removido: la marcación se hace automáticamente en _fetch.

  void _openLoanDetail(Map<String, dynamic> loan) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => AdminLoanDetailPage(loan: loan)),
        )
        .then((_) => _fetch());
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
        title: const Text('Manejo de Préstamos'),
      ),
      body: Container(
        color: const Color(0xFFF7F9FB),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(_error ?? '', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: _visibleCount,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemBuilder: (context, idx) {
                  final loan = _loans[idx];
                  final cuotasPagadas =
                      int.tryParse(loan['cuotas_pagadas']?.toString() ?? '0') ??
                      0;
                  final cuotasTotal =
                      int.tryParse(loan['cuotas_total']?.toString() ?? '0') ??
                      0;
                  final cuotasReportadas =
                      int.tryParse(
                        loan['cuotas_reportadas']?.toString() ?? '0',
                      ) ??
                      0;
                  final cuotasAtrasadas =
                      int.tryParse(
                        loan['cuotas_atrasadas']?.toString() ?? '0',
                      ) ??
                      0;
                  final formattedAmount = _moneyFormat.format(
                    parseNum(loan['amount']),
                  );
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openLoanDetail(loan),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: BrandPalette.blue,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'RD\$$formattedAmount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.event_note,
                                  color: BrandPalette.navy,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cuotas: $cuotasPagadas / $cuotasTotal',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF263238),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (cuotasReportadas > 0)
                                  _buildIndicator(
                                    'Reportadas',
                                    Colors.orange,
                                    Icons.pending_actions,
                                    cuotasReportadas,
                                  ),
                                if (cuotasAtrasadas > 0)
                                  _buildIndicator(
                                    'Atrasadas',
                                    Colors.red,
                                    Icons.warning_amber_rounded,
                                    cuotasAtrasadas,
                                  ),
                                if (cuotasPagadas > 0)
                                  _buildIndicator(
                                    'Pagadas',
                                    Colors.green,
                                    Icons.check_circle,
                                    cuotasPagadas,
                                  ),
                                if (cuotasReportadas == 0 &&
                                    cuotasAtrasadas == 0 &&
                                    cuotasPagadas == 0)
                                  _buildIndicator(
                                    'Sin cuotas reportadas',
                                    Colors.grey,
                                    Icons.info_outline,
                                    0,
                                  ),
                              ],
                            ),
                          ],
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
