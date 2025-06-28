import 'package:flutter/material.dart';

class LoanRequestPage extends StatelessWidget {
  const LoanRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de Préstamo')),
      body: const Center(
        child: Text(
          'Aquí irá el formulario para solicitar un préstamo.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
