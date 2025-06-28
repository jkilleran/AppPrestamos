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

  // Opciones dinámicas
  List<dynamic> _loanOptions = [];
  double? _minAmount;
  double? _maxAmount;
  double? _minInterest;
  double? _maxInterest;
  int? _minMonths;
  int? _maxMonths;

  @override
  void initState() {
    super.initState();
    _fetchLoanOptions();
  }

  Future<void> _fetchLoanOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-options',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final options = jsonDecode(response.body);
        setState(() {
          _loanOptions = options;
          if (options.isNotEmpty) {
            _minAmount = options
                .map((o) => (o['min_amount'] as num).toDouble())
                .reduce((a, b) => a < b ? a : b);
            _maxAmount = options
                .map((o) => (o['max_amount'] as num).toDouble())
                .reduce((a, b) => a > b ? a : b);
            _minInterest = options
                .map((o) => (o['interest'] as num).toDouble())
                .reduce((a, b) => a < b ? a : b);
            _maxInterest = options
                .map((o) => (o['interest'] as num).toDouble())
                .reduce((a, b) => a > b ? a : b);
            _minMonths = options
                .map((o) => (o['months'] as int))
                .reduce((a, b) => a < b ? a : b);
            _maxMonths = options
                .map((o) => (o['months'] as int))
                .reduce((a, b) => a > b ? a : b);
            // Ajustar valores actuales si están fuera de rango
            if (_amountController.text.isEmpty ||
                double.tryParse(_amountController.text)! < _minAmount!) {
              _amountController.text = _minAmount!.toStringAsFixed(0);
            }
            if (_interest < _minInterest!) _interest = _minInterest!;
            if (_interest > _maxInterest!) _interest = _maxInterest!;
            if (_months < _minMonths!) _months = _minMonths!;
            if (_months > _maxMonths!) _months = _maxMonths!;
          }
        });
      }
    } catch (_) {}
  }

  double get _monthlyPayment {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final r = _interest / 100 / 12;
    final n = _months;
    if (amount == 0 || r == 0 || n == 0) return 0;
    return amount * r / (1 - pow(1 + r, -n));
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-requests',
      );
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
        final error =
            jsonDecode(response.body)['message'] ?? 'Error desconocido';
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
      body: _loanOptions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Completa los datos para solicitar tu préstamo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monto solicitado',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: const OutlineInputBorder(),
                        helperText: _minAmount != null && _maxAmount != null
                            ? 'Entre ${_minAmount!.toStringAsFixed(0)} y ${_maxAmount!.toStringAsFixed(0)}'
                            : null,
                      ),
                      validator: (v) {
                        final value = double.tryParse(v ?? '');
                        if (value == null || value <= 0)
                          return 'Ingresa un monto válido';
                        if (_minAmount != null && value < _minAmount!)
                          return 'Monto mínimo: ${_minAmount!.toStringAsFixed(0)}';
                        if (_maxAmount != null && value > _maxAmount!)
                          return 'Monto máximo: ${_maxAmount!.toStringAsFixed(0)}';
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
                            min: (_minMonths ?? 6).toDouble(),
                            max: (_maxMonths ?? 48).toDouble(),
                            divisions:
                                (_maxMonths != null && _minMonths != null)
                                ? (_maxMonths! - _minMonths! > 0
                                      ? _maxMonths! - _minMonths!
                                      : 1)
                                : 7,
                            label: '$_months meses',
                            onChanged: (v) =>
                                setState(() => _months = v.round()),
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
                            min: _minInterest ?? 5,
                            max: _maxInterest ?? 30,
                            divisions:
                                ((_maxInterest ?? 30) - (_minInterest ?? 5))
                                    .round(),
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
                        DropdownMenuItem(
                          value: 'Educación',
                          child: Text('Educación'),
                        ),
                        DropdownMenuItem(
                          value: 'Negocio',
                          child: Text('Negocio'),
                        ),
                        DropdownMenuItem(value: 'Salud', child: Text('Salud')),
                        DropdownMenuItem(value: 'Viaje', child: Text('Viaje')),
                        DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                      ],
                      onChanged: (v) => setState(() => _purpose = v),
                      validator: (v) =>
                          v == null ? 'Selecciona un motivo' : null,
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
                            const Text(
                              'Resumen:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Monto: [32m${_amountController.text.isEmpty ? '-' : _amountController.text}[0m',
                            ),
                            Text('Plazo: ${_months} meses'),
                            Text('Inter e9s: ${_interest.toStringAsFixed(1)}%'),
                            Text('Motivo: [32m${_purpose ?? '-'}[0m'),
                            const SizedBox(height: 8),
                            Text(
                              'Cuota estimada: ${_amountController.text.isEmpty ? '-' : _monthlyPayment.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_result != null)
                      Text(
                        _result!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Solicitar Préstamo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
