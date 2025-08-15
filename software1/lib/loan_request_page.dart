import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LoanRequestPage extends StatefulWidget {
  const LoanRequestPage({super.key});

  @override
  State<LoanRequestPage> createState() => _LoanRequestPageState();
}

class _LoanRequestPageState extends State<LoanRequestPage> {
  // Opciones dinámicas
  List<dynamic> _loanOptions = [];
  String? _userCategoria;
  double? _userSalario;
  bool _isLoadingOptions = true; // <-- nuevo estado
  bool _isAdmin = false;
  late NumberFormat _f0; // #,##0
  late NumberFormat _f2; // #,##0.00

  @override
  void initState() {
    super.initState();
    _f0 = NumberFormat('#,##0');
    _f2 = NumberFormat('#,##0.00');
    _loadUserCategoria();
    _loadUserSalario();
    _loadUserRole();
  }

  Future<void> _loadUserCategoria() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userCategoria = prefs.getString('categoria') ?? 'Hierro';
    });
  }

  Future<void> _loadUserSalario() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('user_salario');
    setState(() {
      _userSalario = s != null ? double.tryParse(s) : null;
    });
    // Al tener salario, aplicar filtro volviendo a cargar opciones
    await _fetchLoanOptions();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    setState(() {
      _isAdmin = (role == 'admin');
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
          // No filtrar globalmente por ingreso aquí; lo validamos por opción en el UI
          _loanOptions = options as List<dynamic>;
          _isLoadingOptions = false;
        });
      } else {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingOptions = false;
      });
    }
  }

  // Eliminados métodos y campos no usados del flujo anterior

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
                    _userSalario == null
                        ? 'No hay préstamos disponibles en este momento'
                        : 'No hay préstamos disponibles para tu ingreso actual',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userSalario == null
                        ? 'Por favor, contacta al administrador o vuelve a intentarlo más tarde.'
                        : 'Incrementa tu ingreso o consulta con el administrador otras opciones.',
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
                final categorias = [
                  'Hierro',
                  'Plata',
                  'Oro',
                  'Platino',
                  'Diamante',
                  'Esmeralda',
                ];
                final userCatIndex = categorias.indexWhere(
                  (c) =>
                      c.toLowerCase() ==
                      (_userCategoria ?? 'Hierro').toLowerCase(),
                );
                final minCatIndex = categorias.indexWhere(
                  (c) =>
                      c.toLowerCase() ==
                      (opt['categoria_minima'] ?? 'Hierro').toLowerCase(),
                );
                final cumpleCategoria = userCatIndex >= minCatIndex;
                // Regla por opción: ingreso mínimo (si está definido)
                final ingresoMinOpt = opt['ingreso_minimo'];
                final cumpleIngreso =
                    (_userSalario == null || ingresoMinOpt == null)
                    ? true
                    : (_userSalario! >=
                          (ingresoMinOpt is num
                              ? ingresoMinOpt.toDouble()
                              : double.tryParse(ingresoMinOpt.toString()) ??
                                    double.infinity));
                double selectedAmount = double.parse(
                  opt['min_amount'].toString(),
                );
                final minAmount = double.parse(opt['min_amount'].toString());
                final maxAmount = double.parse(opt['max_amount'].toString());
                // Variables no necesarias aquí, se calculan al confirmar
                return Opacity(
                  opacity: (cumpleCategoria && cumpleIngreso) ? 1.0 : 0.5,
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
                          if (_isAdmin && ingresoMinOpt != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.visibility_off_outlined,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Oculto para usuarios con ingreso < '
                                      '${_f0.format((ingresoMinOpt is num ? ingresoMinOpt.toDouble() : double.tryParse(ingresoMinOpt.toString()) ?? 0))}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Mostrar monto de forma más clara
                          if (minAmount == maxAmount)
                            Text(
                              'Monto: ${_f0.format(minAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            )
                          else
                            Text(
                              'Monto permitido: ${_f0.format(minAmount)} - ${_f0.format(maxAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.percent,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Interés: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${opt['interest']}%',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Plazo: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${opt['months']} meses',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Categoría mínima: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              Text(
                                '${opt['categoria_minima'] ?? 'Hierro'}',
                                style: TextStyle(
                                  color: _categoriaColor(
                                    opt['categoria_minima'] ?? 'Hierro',
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
                                            _f0.format(minAmount),
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
                                                (maxAmount - minAmount)
                                                        .toInt() >
                                                    0
                                                ? (maxAmount - minAmount)
                                                      .toInt()
                                                : null,
                                            label: _f0.format(selectedAmount),
                                            onChanged:
                                                (maxAmount - minAmount)
                                                        .toInt() >
                                                    0
                                                ? (v) => setStateCard(
                                                    () => selectedAmount = v,
                                                  )
                                                : null,
                                          ),
                                          Text(
                                            'Monto seleccionado: ${_f0.format(selectedAmount)}',
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: (cumpleCategoria && cumpleIngreso)
                                      ? () => _showLoanRequestDialog(
                                          opt,
                                          selectedAmount,
                                        )
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cumpleCategoria
                                        ? _categoriaColor(
                                            opt['categoria_minima'] ?? 'Hierro',
                                          )
                                        : Colors.grey.shade400,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: Text(
                                    'Solicitar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!cumpleCategoria)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Tu categoría actual es ${_userCategoria ?? 'Hierro'}. Necesitas al menos ${opt['categoria_minima'] ?? 'Hierro'} para solicitar este préstamo.',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (cumpleCategoria && !cumpleIngreso)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Tu ingreso actual no cumple el mínimo requerido (${_f0.format((ingresoMinOpt is num ? ingresoMinOpt.toDouble() : double.tryParse(ingresoMinOpt?.toString() ?? '') ?? 0))}).',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
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
        final double interestVal = double.parse(opt['interest'].toString());
        final int monthsVal = opt['months'] is String
            ? int.parse(opt['months'])
            : opt['months'];
        final cuota = _calculateMonthlyPayment(amount, interestVal, monthsVal);
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
                Text('Monto: ${_f0.format(amount)}'),
                Text('Interés: ${_f2.format(interestVal)}%'),
                Text('Plazo: $monthsVal meses'),
                Text('Cuota estimada: ${_f2.format(cuota)}'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $errorMsg')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de red o inesperado: $e')));
    }
  }

  Color _categoriaColor(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'hierro':
        return Colors.grey;
      case 'plata':
        return Colors.blueGrey;
      case 'oro':
        return Colors.amber;
      case 'platino':
        return Colors.blue;
      case 'diamante':
        return Colors.deepPurple;
      case 'esmeralda':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}
