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
  String? _userCategoria;
  double? _minAmount;
  double? _maxAmount;
  double? _minInterest;
  double? _maxInterest;
  int? _minMonths;
  int? _maxMonths;
  bool _isLoadingOptions = true; // <-- nuevo estado

  @override
  void initState() {
    super.initState();
    _fetchLoanOptions();
    _loadUserCategoria();
  }

  Future<void> _loadUserCategoria() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userCategoria = prefs.getString('categoria') ?? 'Hierro';
    });
  }

  Future<void> _fetchLoanOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });
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
      print('RESPUESTA LOAN-OPTIONS: status: [1m${response.statusCode}[0m');
      print('BODY: ${response.body}');
      if (response.statusCode == 200) {
        final options = jsonDecode(response.body);
        setState(() {
          _loanOptions = options;
          if (options.isEmpty) {
            _result =
                'No hay opciones de préstamo configuradas. Contacta al administrador.';
          }
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
          _isLoadingOptions = false;
        });
      } else {
        setState(() {
          _result =
              'Error al obtener opciones de préstamo: Código ${response.statusCode}';
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error de red o inesperado: $e';
        _isLoadingOptions = false;
      });
    }
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
      appBar: AppBar(title: const Text('Solicitar Préstamo')),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _loanOptions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay préstamos disponibles en este momento',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por favor, contacta al administrador o vuelve a intentarlo más tarde.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _loanOptions.length,
              itemBuilder: (context, i) {
                final opt = _loanOptions[i];
                final categorias = ['Hierro', 'Plata', 'Oro', 'Platino', 'Diamante', 'Esmeralda'];
                final userCatIndex = categorias.indexWhere((c) => c.toLowerCase() == (_userCategoria ?? 'Hierro').toLowerCase());
                final minCatIndex = categorias.indexWhere((c) => c.toLowerCase() == (opt['categoria_minima'] ?? 'Hierro').toLowerCase());
                final cumpleCategoria = userCatIndex >= minCatIndex;
                double selectedAmount = double.parse(
                  opt['min_amount'].toString(),
                );
                final minAmount = double.parse(opt['min_amount'].toString());
                final maxAmount = double.parse(opt['max_amount'].toString());
                final interest = double.parse(opt['interest'].toString());
                final months = opt['months'] is String
                    ? int.parse(opt['months'])
                    : opt['months'];
                return Opacity(
                  opacity: cumpleCategoria ? 1.0 : 0.5,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Préstamo disponible',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Monto permitido: ${opt['min_amount']} - ${opt['max_amount']}'),
                          Text('Interés: ${opt['interest']}%'),
                          Text('Plazo: ${opt['months']} meses'),
                          Text('Categoría mínima: ${opt['categoria_minima'] ?? 'Hierro'}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                          const SizedBox(height: 12),
                          StatefulBuilder(
                            builder: (context, setStateCard) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                (minAmount == maxAmount)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Monto a solicitar:'),
                                          const SizedBox(height: 8),
                                          Text(
                                            minAmount.toStringAsFixed(0),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Selecciona el monto a solicitar:',
                                          ),
                                          Slider(
                                            value: selectedAmount,
                                            min: minAmount,
                                            max: maxAmount,
                                            divisions:
                                                (maxAmount - minAmount).toInt() >
                                                        0
                                                    ? (maxAmount - minAmount).toInt()
                                                    : null,
                                            label: selectedAmount.toStringAsFixed(
                                              0,
                                            ),
                                            onChanged:
                                                (maxAmount - minAmount).toInt() >
                                                        0
                                                    ? (v) => setStateCard(
                                                        () => selectedAmount = v,
                                                      )
                                                    : null,
                                          ),
                                          Text(
                                            'Monto seleccionado:  24${selectedAmount.toStringAsFixed(0)}',
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: cumpleCategoria ? () => _showLoanRequestDialog(opt, double.parse(opt['min_amount'].toString())) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cumpleCategoria ? Theme.of(context).primaryColor : Colors.grey,
                                  ),
                                  child: Text(cumpleCategoria ? 'Solicitar este préstamo' : 'No calificas'),
                                ),
                                if (!cumpleCategoria)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Tu categoría actual es ${_userCategoria ?? 'Hierro'}. Necesitas al menos ${opt['categoria_minima'] ?? 'Hierro'} para solicitar este préstamo.',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showLoanRequestDialog(Map<String, dynamic> opt, double amount) {
    showDialog(
      context: context,
      builder: (context) {
        final interest = double.parse(opt['interest'].toString());
        final months = opt['months'] is String
            ? int.parse(opt['months'])
            : opt['months'];
        final cuota = _calculateMonthlyPayment(amount, interest, months);
        String? purpose;
        String? selectedMotivo;
        TextEditingController otroController = TextEditingController();
        final motivos = [
          'Negocio',
          'Estudios',
          'Salud',
          'Viaje',
          'Hogar',
          'Otro',
        ];
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Confirmar Solicitud'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monto: ${amount.toStringAsFixed(0)}'),
                Text('Interés: $interest%'),
                Text('Plazo: $months meses'),
                Text('Cuota estimada: ${cuota.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMotivo,
                  items: motivos
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    setStateDialog(() {
                      selectedMotivo = v;
                      if (v != 'Otro') {
                        otroController.clear();
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Motivo del préstamo',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Selecciona un motivo' : null,
                ),
                if (selectedMotivo == 'Otro')
                  TextField(
                    controller: otroController,
                    decoration: const InputDecoration(
                      labelText: 'Especifica el motivo',
                    ),
                    onChanged: (v) {},
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  String? motivoFinal;
                  if (selectedMotivo == null ||
                      (selectedMotivo?.isEmpty ?? true)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Debes seleccionar un motivo.'),
                      ),
                    );
                    return;
                  }
                  if (selectedMotivo == 'Otro') {
                    if (otroController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debes especificar el motivo.'),
                        ),
                      );
                      return;
                    }
                    motivoFinal = otroController.text;
                  } else {
                    motivoFinal = selectedMotivo;
                  }
                  await _submitLoanRequest(opt, amount, motivoFinal!);
                  Navigator.of(context).pop();
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateMonthlyPayment(double amount, double interest, int months) {
    final r = interest / 100 / 12;
    if (amount == 0 || r == 0 || months == 0) return 0;
    return amount * r / (1 - pow(1 + r, -months));
  }

  Future<void> _submitLoanRequest(
    Map<String, dynamic> opt,
    double amount,
    String purpose,
  ) async {
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
          'amount': amount,
          'months': opt['months'],
          'interest': opt['interest'],
          'purpose': purpose,
          'loan_option_id': opt['id'], // <-- importante para backend
        }),
      );
      if (response.statusCode == 201) {
        setState(() {
          _loading = false;
          _result = '¡Solicitud enviada correctamente!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Solicitud enviada correctamente!')),
        );
      } else {
        String errorMsg = 'Error desconocido';
        try {
          final errorJson = jsonDecode(response.body);
          errorMsg = errorJson['error'] ?? errorJson['message'] ?? errorMsg;
        } catch (_) {
          errorMsg = response.body;
        }
        setState(() {
          _loading = false;
          _result = 'Error: $errorMsg';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $errorMsg')));
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _result = 'Error de red o inesperado: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de red o inesperado: $e')));
    }
  }
}
