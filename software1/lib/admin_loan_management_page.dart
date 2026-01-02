import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'brand_theme.dart';
import 'services/loan_installments_service.dart';
// snackbar_helper ya no es necesario aquí (se removieron botones manuales)
import 'widgets/installment_row.dart';

class AdminLoanManagementPage extends StatefulWidget {
  const AdminLoanManagementPage({super.key});
  @override
  State<AdminLoanManagementPage> createState() =>
      _AdminLoanManagementPageState();
}

class _AdminLoanManagementPageState extends State<AdminLoanManagementPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _loans = [];
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  int _visibleCount = 0;
  final _currency = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$');
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
    if (!silent)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      // Marca atrasadas de forma silenciosa antes de refrescar (ignora errores)
      try {
        await LoanInstallmentsService.adminMarkOverdue();
      } catch (_) {}
      final data = await LoanInstallmentsService.adminActiveLoans();
      if (mounted)
        setState(() {
          _loans = data;
          if (_visibleCount == 0) {
            _visibleCount = data.length > _pageSize ? _pageSize : data.length;
          } else {
            _visibleCount = _visibleCount.clamp(0, data.length);
          }
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  // _markOverdue removido: la marcación se hace automáticamente en _fetch.

  void _openLoanDetail(Map<String, dynamic> loan) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AdminLoanDetailPage(loan: loan)));
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
        // Sin acciones (reloj / refrescar) según nueva especificación.
      ),
      body: _loading
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
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                itemCount:
                    _visibleCount + (_visibleCount < _loans.length ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= _visibleCount) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visibleCount = (_visibleCount + _pageSize).clamp(
                                0,
                                _loans.length,
                              );
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Cargar más'),
                        ),
                      ),
                    );
                  }
                  final loan = _loans[i] as Map<String, dynamic>;
                  double parseNum(dynamic v) {
                    if (v == null) return 0;
                    if (v is num) return v.toDouble();
                    if (v is String)
                      return double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    return 0;
                  }

                  final total = parseNum(loan['total_programado']);
                  final pagado = parseNum(loan['total_pagado']);
                  final porcentaje = total <= 0
                      ? 0.0
                      : (pagado / total).clamp(0, 1).toDouble();
                  final cuotasTotal = loan['cuotas_total'] ?? 0;
                  final cuotasPag = loan['cuotas_pagadas'] ?? 0;
                  return _LoanCard(
                    onTap: () => _openLoanDetail(loan),
                    currency: _currency,
                    loan: loan,
                    porcentaje: porcentaje,
                    cuotasDesc: '$cuotasPag / $cuotasTotal',
                    onLiquidate: (loan['status'] ?? '').toLowerCase() != 'liquidado'
                        ? () async {
                            try {
                              await LoanInstallmentsService.adminUpdateLoanStatus(
                                loanId: loan['loan_id'] ?? loan['id'],
                                status: 'liquidado',
                              );
                              if (mounted) _fetch();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        : null,
                  );
                },
              ),
            ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onTap;
  final NumberFormat currency;
  final double porcentaje;
  final String cuotasDesc;
  final void Function()? onLiquidate;
  const _LoanCard({
    required this.loan,
    required this.onTap,
    required this.currency,
    required this.porcentaje,
    required this.cuotasDesc,
    this.onLiquidate,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currency.format(loan['amount'] ?? 0),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: BrandPalette.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: BrandPalette.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (loan['user_name'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(6),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        color: porcentaje >= 1
                            ? Colors.green
                            : BrandPalette.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(porcentaje * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _pill('${loan['months']} meses', Icons.calendar_month),
                    _pill('Interés ${loan['interest']}%', Icons.percent),
                    _pill('Cuotas $cuotasDesc', Icons.list_alt),
                  ],
                ),
                const SizedBox(height: 12),
                if ((loan['status'] ?? '').toLowerCase() != 'liquidado' && onLiquidate != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all),
                    label: const Text('Marcar como liquidado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Liquidar préstamo'),
                          content: const Text('¿Confirmas marcar este préstamo como liquidado? Esta acción es irreversible.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Confirmar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        onLiquidate!();
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: BrandPalette.blue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BrandPalette.blue),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class AdminLoanDetailPage extends StatefulWidget {
  final Map<String, dynamic> loan;
  const AdminLoanDetailPage({super.key, required this.loan});
  @override
  State<AdminLoanDetailPage> createState() => _AdminLoanDetailPageState();
}

class _AdminLoanDetailPageState extends State<AdminLoanDetailPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _installments = [];
  Map<String, dynamic>? _progress;
  final _currency = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = widget.loan['loan_id'] ?? widget.loan['id'];
      final prog = await LoanInstallmentsService.loanProgress(id);
      final list = await LoanInstallmentsService.loanInstallments(id);
      if (mounted)
        setState(() {
          _progress = prog;
          _installments = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _changeStatus(dynamic inst, String newStatus) async {
    try {
      await LoanInstallmentsService.adminUpdateInstallmentStatus(
        installmentId: inst['id'] as int,
        status: newStatus,
        paidAmount: newStatus == 'pagado'
            ? (inst['total_due'] as num?)?.toDouble()
            : null,
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final id = loan['loan_id'] ?? loan['id'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Préstamo #$id'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandPalette.blue, BrandPalette.navy],
            ),
          ),
        ),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Datos del dueño del préstamo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dueño: 	${loan['user_name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Email:   ${loan['user_email'] ?? '-'}'),
                      Text('Cédula:  ${loan['user_cedula'] ?? '-'}'),
                      const SizedBox(height: 12),
                    ],
                  ),
                  Text(
                    _currency.format(loan['amount'] ?? 0),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Meses ${loan['months']}', Icons.calendar_month),
                      _pill('Interés ${loan['interest']}%', Icons.percent),
                      if (_progress != null)
                        _pill(
                          'Pagadas ${_progress!['cuotas_pagadas']}/${_progress!['cuotas_total']}',
                          Icons.check_circle,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cuotas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final inst in _installments)
                    InstallmentRow(
                      installment: inst as Map<String, dynamic>,
                      currency: _currency,
                      mode: InstallmentRowMode.admin,
                      onAdminUpdate: (i, status) async {
                        await _changeStatus(i, status);
                        await _fetch(); // Refresca cuotas tras aprobar/rechazar
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _pill(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: BrandPalette.blue.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BrandPalette.blue),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

// Replaced _InstallmentAdminRow with shared InstallmentRow widget.
// NOTE: Any future percentage or monetary math should parse dynamic JSON values safely as done in the list builder above.
