import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../brand_theme.dart';

enum InstallmentRowMode { admin, client }

class InstallmentRow extends StatelessWidget {
  final Map<String, dynamic> installment;
  final NumberFormat currency;
  final InstallmentRowMode mode;
  final void Function(Map<String, dynamic> inst, String status)? onAdminUpdate;
  final void Function(Map<String, dynamic> inst)? onClientUpload;
  final bool showReceiptsButton; // (placeholder desactivado por defecto)
  final bool showClientPayButton; // mantener compatibilidad si en el futuro se quiere mostrar dentro de la fila

  const InstallmentRow({
    super.key,
    required this.installment,
    required this.currency,
    required this.mode,
    this.onAdminUpdate,
    this.onClientUpload,
    this.showReceiptsButton = false,
    this.showClientPayButton = true,
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

  String _dueDateText() {
    final due = (installment['due_date'] ?? '').toString();
    final gd = installment['grace_days'];
    if (gd is int && gd > 0) return 'Vence: $due (+$gd días gracia)';
    return 'Vence: $due';
  }

  String _friendlyStatus(String raw) {
    if (raw == 'reportado') return 'Pend. Aprobación';
    return raw;
  }

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
                    _friendlyStatus(status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_dueDateText(), style: TextStyle(color: Colors.grey.shade700)),
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
    // Solo acciones cuando el cliente subió comprobante (reportado)
    if (status != 'reportado') return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => onAdminUpdate?.call(installment, 'pagado'),
          icon: const Icon(Icons.verified),
          label: const Text('Aprobar pago'),
        ),
        OutlinedButton.icon(
          onPressed: () => onAdminUpdate?.call(installment, 'rechazado'),
          icon: const Icon(Icons.close),
          label: const Text('Rechazar'),
        ),
      ],
    );
  }

  Widget _buildClientActions(BuildContext context, String status) {
    // El flujo de pago del cliente ahora se inicia desde un botón global fuera de cada fila.
    // Si en algún escenario futuro se requiere reactivar el botón por fila, se deja la opción.
    if (showClientPayButton && _clientCanUpload(status)) {
      return ElevatedButton.icon(
        onPressed: () => onClientUpload?.call(installment),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Pagar cuota'),
      );
    }
    return const SizedBox.shrink();
  }

  // Se eliminó el botón de recibos; esta función queda como recordatorio para futura implementación.
}
