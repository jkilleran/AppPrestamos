import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';

class LoanOptionsAdminPage extends StatefulWidget {
  const LoanOptionsAdminPage({super.key});

  @override
  State<LoanOptionsAdminPage> createState() => _LoanOptionsAdminPageState();
}

class _LoanOptionsAdminPageState extends State<LoanOptionsAdminPage> {
  List<dynamic> _options = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    setState(() {
      _loading = true;
      _error = null;
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
      if (response.statusCode == 200) {
        setState(() {
          _options = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red o inesperado: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addOrEditOption({Map<String, dynamic>? option}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _LoanOptionDialog(option: option),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final isEdit = option != null;
      final url = isEdit
          ? Uri.parse(
              'https://appprestamos-f5wz.onrender.com/loan-options/${option['id']}',
            )
          : Uri.parse('https://appprestamos-f5wz.onrender.com/loan-options');
      try {
        final response = await (isEdit
            ? http.put(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: jsonEncode(result),
              )
            : http.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: jsonEncode(result),
              ));
        print('RESPUESTA OPCION: status: [32m${response.statusCode}[0m');
        print('BODY: ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          _fetchOptions();
        } else {
          String msg = 'Error al guardar opción';
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body['error'] != null) msg = body['error'];
          } catch (_) {}
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (e) {
        print('ERROR OPCION: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red o inesperado: $e')),
        );
      }
    }
  }

  Future<void> _deleteOption(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final url = Uri.parse(
      'https://appprestamos-f5wz.onrender.com/loan-options/$id',
    );
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      _fetchOptions();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar opción')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandPalette.blue, BrandPalette.navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
  title: const Text('Opciones de Préstamo (Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditOption(),
        tooltip: 'Agregar opción',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            )
          : _options.isEmpty
          ? Center(child: Text('No hay opciones de préstamo'))
          : ListView.builder(
              itemCount: _options.length,
              itemBuilder: (context, i) {
                final opt = _options[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      'Monto: ${opt['min_amount']} - ${opt['max_amount']}',
                    ),
                    subtitle: Text(
                      'Interés: ${double.parse(opt['interest'].toString())}% | Plazo: ${opt['months']} meses${opt['ingreso_minimo'] != null ? ' | Ingreso mín.: ${opt['ingreso_minimo']}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: BrandPalette.blue),
                          onPressed: () => _addOrEditOption(option: opt),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteOption(opt['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LoanOptionDialog extends StatefulWidget {
  final Map<String, dynamic>? option;
  const _LoanOptionDialog({this.option});

  @override
  State<_LoanOptionDialog> createState() => _LoanOptionDialogState();
}

class _LoanOptionDialogState extends State<_LoanOptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;
  late TextEditingController _interestController;
  late TextEditingController _monthsController;
  late TextEditingController _ingresoMinimoController;
  late String _categoriaMinima;
  final List<String> _categorias = [
    'Hierro',
    'Plata',
    'Oro',
    'Platino',
    'Diamante',
    'Esmeralda',
  ];

  @override
  void initState() {
    super.initState();
    _minAmountController = TextEditingController(
      text: widget.option?['min_amount']?.toString() ?? '',
    );
    _maxAmountController = TextEditingController(
      text: widget.option?['max_amount']?.toString() ?? '',
    );
    _interestController = TextEditingController(
      text: widget.option?['interest']?.toString() ?? '',
    );
    _monthsController = TextEditingController(
      text: widget.option?['months']?.toString() ?? '',
    );
    _ingresoMinimoController = TextEditingController(
      text: widget.option?['ingreso_minimo']?.toString() ?? '',
    );
    _categoriaMinima =
        widget.option?['categoria_minima']?.toString() ?? 'Hierro';
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _interestController.dispose();
    _monthsController.dispose();
    _ingresoMinimoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.option == null ? 'Agregar Opción' : 'Editar Opción'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _minAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              decoration: const InputDecoration(labelText: 'Monto mínimo'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _maxAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              decoration: const InputDecoration(labelText: 'Monto máximo'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _interestController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              decoration: const InputDecoration(labelText: 'Interés (%)'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _monthsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Plazo (meses)'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _ingresoMinimoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Ingreso mínimo mensual',
                helperText: 'Solo números (usar punto como decimal). Opcional.',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // opcional
                return double.tryParse(v.trim()) == null
                    ? 'Número inválido'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoriaMinima,
              items: _categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _categoriaMinima = v);
              },
              decoration: const InputDecoration(
                labelText: 'Categoría mínima',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'min_amount': double.parse(_minAmountController.text),
                'max_amount': double.parse(_maxAmountController.text),
                'interest': double.parse(_interestController.text),
                'months': int.parse(_monthsController.text),
                'categoria_minima': _categoriaMinima,
                'ingreso_minimo': (_ingresoMinimoController.text.trim().isEmpty)
                    ? null
                    : double.parse(_ingresoMinimoController.text.trim()),
              });
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
