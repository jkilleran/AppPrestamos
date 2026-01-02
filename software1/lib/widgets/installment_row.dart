import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ...existing code...
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../brand_theme.dart';

enum InstallmentRowMode { admin, client }

class InstallmentRow extends StatelessWidget {
  final Map<String, dynamic> installment;
  final NumberFormat currency;
  final InstallmentRowMode mode;
  final void Function(Map<String, dynamic> inst, String status)? onAdminUpdate;
  final void Function(Map<String, dynamic> inst)? onClientUpload;
  final bool showReceiptsButton; // (placeholder desactivado por defecto)
  final bool
  showClientPayButton; // mantener compatibilidad si en el futuro se quiere mostrar dentro de la fila

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

  // Distintivo visual para cuotas pendientes de aprobación (admin)
  Widget? _pendingBadge(String status) {
    if (mode == InstallmentRowMode.admin && status == 'reportado') {
      return Row(
        children: [
          const Icon(Icons.hourglass_top, color: Colors.orange, size: 18),
          const SizedBox(width: 4),
          Text(
            'Pendiente de aprobación',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    return null;
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
    // Coerciones seguras: algunos campos pueden venir como String ("10300.00")
    double _toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
      return 0;
    }

    final totalDue = _toDouble(installment['total_due']);
    final capital = _toDouble(installment['capital']);
    final interest = _toDouble(installment['interest']);
    final pendingBadge = _pendingBadge(status);
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
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _friendlyStatus(status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (pendingBadge != null) ...[
              const SizedBox(height: 4),
              pendingBadge,
            ],
            const SizedBox(height: 4),
            Text(_dueDateText(), style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(
              'Total: ${currency.format(totalDue)}  (Capital ${currency.format(capital)} / Int. ${currency.format(interest)})',
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
    final installmentId = installment['id']?.toString();
    // Usar el endpoint backend para visualizar el recibo (sin /api)
    Future<String?> _buildReceiptUrl() async {
      if (installmentId == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null && token.isNotEmpty) {
        return 'https://appprestamos-f5wz.onrender.com/loan-installments/installment/$installmentId/receipt?token=$token';
      }
      return 'https://appprestamos-f5wz.onrender.com/loan-installments/installment/$installmentId/receipt';
    }

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
        TextButton.icon(
          icon: const Icon(Icons.receipt_long),
          label: const Text('Ver comprobante'),
          onPressed: () async {
            final url = await _buildReceiptUrl();
            if (url == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo construir la URL del comprobante.'),
                ),
              );
              return;
            }
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo abrir el comprobante.'),
                ),
              );
            }
          },
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
