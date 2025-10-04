import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'brand_theme.dart';
import 'services/loan_installments_service.dart';
import 'utils/snackbar_helper.dart';
import 'widgets/installment_row.dart';

class MyActiveLoanPage extends StatefulWidget {
  const MyActiveLoanPage({super.key});
  @override
  State<MyActiveLoanPage> createState() => _MyActiveLoanPageState();
}

class _MyActiveLoanPageState extends State<MyActiveLoanPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _approvedLoans = [];
  int? _selectedLoanId;
  List<dynamic> _installments = [];
  Map<String, dynamic>? _progress;
  final _currency = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$');
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _fetchLoans();
    _autoTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_selectedLoanId != null) {
        _fetchInstallments(_selectedLoanId!, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLoans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loans = await LoanInstallmentsService.myLoans();
      final approved = loans
          .where(
            (l) => (l['status'] ?? '').toString().toLowerCase() == 'aprobado',
          )
          .toList();
      int? chosen;
      if (approved.length == 1)
        chosen = approved.first['id'] as int; // seleccionar directo
      if (mounted)
        setState(() {
          _approvedLoans = approved;
          _selectedLoanId = chosen;
          _loading = false;
        });
      if (chosen != null) _fetchInstallments(chosen);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _fetchInstallments(int loanId, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await LoanInstallmentsService.loanInstallments(loanId);
      final prog = await LoanInstallmentsService.loanProgress(loanId);
      if (mounted) {
        setState(() {
          _installments = list;
          _progress = prog;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _upload(dynamic inst) async {
    try {
      await LoanInstallmentsService.uploadReceipt(
        installmentId: inst['id'] as int,
      );
      if (!mounted) return;
      showAppSnack(context, 'Recibo enviado');
      if (_selectedLoanId != null) _fetchInstallments(_selectedLoanId!);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Error: $e', error: true);
    }
  }

  List<Map<String, dynamic>> _payableInstallments() {
    final statuses = {'pendiente', 'atrasado', 'rechazado', 'reportado'};
    return _installments
        .where((i) => statuses.contains((i['status'] ?? '').toString()))
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _openPaySheet() async {
    final list = _payableInstallments();
    if (list.isEmpty) {
      showAppSnack(context, 'No hay cuotas pendientes');
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Selecciona la cuota a pagar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final inst = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: BrandPalette.blue.withValues(
                        alpha: 0.15,
                      ),
                      child: Text('${inst['installment_number']}'),
                    ),
                    title: Text('Cuota #${inst['installment_number']}'),
                    subtitle: Text(
                      'Total ${_currency.format(inst['total_due'] ?? 0)} - Estado ${(inst['status'] ?? '')}',
                    ),
                    onTap: () => Navigator.pop(c, inst),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (selected == null) return;
    // Confirmación final
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
          'Subir comprobante para la cuota #${selected['installment_number']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Subir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _upload(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandPalette.blue, BrandPalette.navy],
            ),
          ),
        ),
        title: const Text('Mi Préstamo Activo'),
        // Se eliminan acciones manuales; refresco automático
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _selectedLoanId == null
          ? _buildLoanSelector()
          : RefreshIndicator(
              onRefresh: () => _fetchInstallments(_selectedLoanId!),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_progress != null) _buildProgressCard(),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _openPaySheet,
                      icon: const Icon(Icons.payments),
                      label: const Text('Pagar cuota'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cuotas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  for (final inst in _installments)
                    InstallmentRow(
                      installment: inst as Map<String, dynamic>,
                      currency: _currency,
                      mode: InstallmentRowMode.client,
                      onClientUpload: (i) => _upload(i),
                      showClientPayButton: false, // ocultamos botones por fila
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoanSelector() {
    if (_approvedLoans.isEmpty) {
      return const Center(
        child: Text('No tienes préstamos aprobados actualmente'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _approvedLoans.length,
      itemBuilder: (ctx, i) {
        final loan = _approvedLoans[i] as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(
              _currency.format(loan['amount'] ?? 0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Meses: ${loan['months']} - Interés ${loan['interest']}%',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () {
              setState(() {
                _selectedLoanId = loan['id'] as int;
              });
              _fetchInstallments(loan['id'] as int);
            },
          ),
        );
      },
    );
  }

  Widget _buildProgressCard() {
    final p = _progress!;
    final prog = (p['porcentaje_pagado'] ?? 0).toDouble();
    final ratio = (prog / 100).clamp(0, 1).toDouble();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progreso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey.withValues(alpha: 0.25),
              color: ratio >= 1 ? Colors.green : BrandPalette.blue,
            ),
            const SizedBox(height: 6),
            Text(
              '${prog.toStringAsFixed(1)}% pagado',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  'Pagadas ${p['cuotas_pagadas']}/${p['cuotas_total']}',
                  Icons.check_circle,
                  Colors.green,
                ),
                _chip(
                  'Reportadas ${p['cuotas_reportadas']}',
                  Icons.pending_actions,
                  Colors.orange,
                ),
                _chip(
                  'Atrasadas ${p['cuotas_atrasadas']}',
                  Icons.warning_amber_rounded,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// Replaced client installment row with shared InstallmentRow.
