import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../brand_theme.dart';
import '../utils/snackbar_helper.dart';

enum InstallmentRowMode { admin, client }

class InstallmentRow extends StatelessWidget {
  final Map<String, dynamic> installment;
  final NumberFormat currency;
  final InstallmentRowMode mode;
  final void Function(Map<String, dynamic> inst, String status)? onAdminUpdate;
  final void Function(Map<String, dynamic> inst)? onClientUpload;
  final bool showReceiptsButton;

  const InstallmentRow({
    super.key,
    required this.installment,
    required this.currency,
    required this.mode,
    this.onAdminUpdate,
    this.onClientUpload,
    this.showReceiptsButton = true,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'pagado':
        return Colors.green;
      case 'atrasado':
        return Colors.red;
      case 'reportado':
        return Colors.orange;
      case 'rechazado':
        return Colors.red.shade700;
      default:
        return BrandPalette.blue;
    }
  }

  bool _clientCanUpload(String status) =>
      ['pendiente', 'atrasado', 'reportado', 'rechazado'].contains(status);

  @override
  Widget build(BuildContext context) {
    final status = (installment['status'] ?? '').toString();
    final color = _statusColor(status);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cuota ${installment['installment_number']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Vence: ${installment['due_date'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${currency.format(installment['total_due'] ?? 0)}  (Capital ${currency.format(installment['capital'] ?? 0)} / Int. ${currency.format(installment['interest'] ?? 0)})',
            ),
            const SizedBox(height: 8),
            if (mode == InstallmentRowMode.admin)
              _buildAdminActions(context, status)
            else
              _buildClientActions(context, status),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, String status) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status != 'pagado')
          ElevatedButton.icon(
            onPressed: () => onAdminUpdate?.call(installment, 'pagado'),
            icon: const Icon(Icons.check),
            label: const Text('Marcar pagado'),
          ),
        if (status != 'rechazado' && status != 'pagado')
          OutlinedButton.icon(
            onPressed: () => onAdminUpdate?.call(installment, 'rechazado'),
            icon: const Icon(Icons.close),
            label: const Text('Rechazar'),
          ),
        if (status == 'atrasado')
          OutlinedButton.icon(
            onPressed: () => onAdminUpdate?.call(installment, 'pendiente'),
            icon: const Icon(Icons.undo),
            label: const Text('Revertir'),
          ),
        if (showReceiptsButton)
          OutlinedButton.icon(
            onPressed: () => _showReceiptsPlaceholder(context),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Ver Recibos Enviados'),
          ),
      ],
    );
  }

  Widget _buildClientActions(BuildContext context, String status) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_clientCanUpload(status))
          OutlinedButton.icon(
            onPressed: () => onClientUpload?.call(installment),
            icon: const Icon(Icons.upload_file),
            label: const Text('Subir recibo'),
          ),
        if (showReceiptsButton && status != 'pendiente')
          TextButton.icon(
            onPressed: () => _showReceiptsPlaceholder(context),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Ver Recibos Enviados'),
          ),
      ],
    );
  }

  void _showReceiptsPlaceholder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recibos Enviados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Próximamente podrás ver aquí los recibos / comprobantes asociados a esta cuota.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
    showAppSnack(context, 'Placeholder sin backend aún');
  }
}
