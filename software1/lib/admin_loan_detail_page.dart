import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/loan_installments_service.dart';
import 'brand_theme.dart';
import 'widgets/installment_row.dart';

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
                      Text(
                        'Dueño:  ${loan['user_name'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                        String msg;
                        if (status == 'pagado') {
                          msg = 'Cuota marcada como pagada.';
                        } else if (status == 'rechazado') {
                          msg = 'Cuota rechazada.';
                        } else {
                          msg = 'Estado de cuota actualizado.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                        }
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
