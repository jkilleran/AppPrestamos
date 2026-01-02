import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LoanRequestDetailsPage extends StatelessWidget {
  final Map<String, dynamic> loan;
  const LoanRequestDetailsPage({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final f2 = NumberFormat('#,##0.00');
    num? parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Solicitud')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            ListTile(
              title: const Text('ID de Solicitud'),
              subtitle: Text(loan['id']?.toString() ?? '-'),
            ),
            ListTile(
              title: const Text('Estado'),
              subtitle: Text(loan['status']?.toString() ?? '-'),
            ),
            ListTile(
              title: const Text('Monto solicitado'),
              subtitle: Text(
                parseNum(loan['amount']) != null
                    ? f2.format(parseNum(loan['amount']))
                    : '-',
              ),
            ),
            ListTile(
              title: const Text('Plazo (meses)'),
              subtitle: Text(parseNum(loan['months'])?.toString() ?? '-'),
            ),
            ListTile(
              title: const Text('Interés (%)'),
              subtitle: Text(parseNum(loan['interest'])?.toString() ?? '-'),
            ),
            if (loan['created_at'] != null)
              ListTile(
                title: const Text('Fecha de solicitud'),
                subtitle: Text(loan['created_at'].toString()),
              ),
            if (loan['notes'] != null)
              ListTile(
                title: const Text('Notas'),
                subtitle: Text(loan['notes'].toString()),
              ),
            // Puedes agregar más campos aquí según lo que tenga el objeto loan
          ],
        ),
      ),
    );
  }
}
