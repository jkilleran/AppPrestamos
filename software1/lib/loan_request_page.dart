import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoanRequestPage extends StatefulWidget {
  const LoanRequestPage({super.key});

  @override
  State<LoanRequestPage> createState() => _LoanRequestPageState();
}

class _LoanRequestPageState extends State<LoanRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  int _months = 12;
  double _interest = 10.0;
  String? _purpose;
  bool _loading = false;
  String? _result;

  double get _monthlyPayment {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final r = _interest / 100 / 12;
    final n = _months;
    if (amount == 0 || r == 0 || n == 0) return 0;
    return amount * r / (1 - pow(1 + r, -n));
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _result = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse('https://<TU_BACKEND_URL>/loan-requests'); // Reemplaza <TU_BACKEND_URL>
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': double.parse(_amountController.text),
          'months': _months,
          'interest': _interest,
          'purpose': _purpose,
        }),
      );
      if (response.statusCode == 201) {
        setState(() {
          _loading = false;
          _result = '¡Solicitud enviada correctamente!';
        });
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Error desconocido';
        setState(() {
          _loading = false;
          _result = 'Error: $error';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _result = 'Error de red o inesperado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de Préstamo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Completa los datos para solicitar tu préstamo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto solicitado',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  if (value == null || value <= 0) return 'Ingresa un monto válido';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Plazo:'),
                  Expanded(
                    child: Slider(
                      value: _months.toDouble(),
                      min: 6,
                      max: 48,
                      divisions: 7,
                      label: '$_months meses',
                      onChanged: (v) => setState(() => _months = v.round()),
                    ),
                  ),
                  Text('$_months meses'),
                ],
              ),
              Row(
                children: [
                  const Text('Interés:'),
                  Expanded(
                    child: Slider(
                      value: _interest,
                      min: 5,
                      max: 30,
                      divisions: 25,
                      label: '${_interest.toStringAsFixed(1)}%',
                      onChanged: (v) => setState(() => _interest = v),
                    ),
                  ),
                  Text('${_interest.toStringAsFixed(1)}%'),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _purpose,
                decoration: const InputDecoration(
                  labelText: 'Motivo del préstamo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Educación', child: Text('Educación')),
                  DropdownMenuItem(value: 'Negocio', child: Text('Negocio')),
                  DropdownMenuItem(value: 'Salud', child: Text('Salud')),
                  DropdownMenuItem(value: 'Viaje', child: Text('Viaje')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                ],
                onChanged: (v) => setState(() => _purpose = v),
                validator: (v) => v == null ? 'Selecciona un motivo' : null,
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resumen:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Monto: ${_amountController.text.isEmpty ? '-' : _amountController.text}'),
                      Text('Plazo: $_months meses'),
                      Text('Interés: ${_interest.toStringAsFixed(1)}%'),
                      Text('Motivo: ${_purpose ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Cuota estimada: ${_amountController.text.isEmpty ? '-' : _monthlyPayment.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (_result != null)
                Text(_result!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading ? const CircularProgressIndicator() : const Text('Solicitar Préstamo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
