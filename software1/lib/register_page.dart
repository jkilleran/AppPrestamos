import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  final void Function()? onRegisterSuccess;
  const RegisterPage({super.key, this.onRegisterSuccess});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _domicilioController = TextEditingController();
  final TextEditingController _salarioController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await http.post(
        Uri.parse('https://appprestamos-f5wz.onrender.com/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'cedula': _cedulaController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'domicilio': _domicilioController.text.trim(),
          'salario': _salarioController.text.trim(),
        }),
      );
      print('Respuesta backend: \\${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _success = 'Registro exitoso. Ahora puedes iniciar sesión.';
        });
        if (widget.onRegisterSuccess != null) widget.onRegisterSuccess!();
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['error'] ?? response.body ?? 'Error al registrar';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Registro',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 2 ? null : 'Nombre muy corto',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Correo inválido',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => v != null && v.length >= 4
                      ? null
                      : 'Contraseña muy corta',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _cedulaController,
                  decoration: const InputDecoration(
                    labelText: 'Cédula (xxx-xxxxxxx-x)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    String numbers = v.replaceAll(RegExp(r'[^0-9]'), '');
                    String formatted = '';
                    if (numbers.length > 3) {
                      formatted += '${numbers.substring(0, 3)}-';
                      if (numbers.length > 10) {
                        formatted += '${numbers.substring(3, 10)}-';
                        formatted += numbers.substring(
                          10,
                          numbers.length > 11 ? 11 : numbers.length,
                        );
                      } else if (numbers.length > 3) {
                        formatted += numbers.substring(
                          3,
                          numbers.length > 10 ? 10 : numbers.length,
                        );
                      }
                    } else {
                      formatted = numbers;
                    }
                    if (formatted != v) {
                      _cedulaController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                  validator: (v) {
                    final regex = RegExp(r'^\d{3}-\d{7}-\d{1}$');
                    if (v == null || !regex.hasMatch(v)) {
                      return 'Formato: xxx-xxxxxxx-x';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (xxx-xxx-xxxx)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    String numbers = v.replaceAll(RegExp(r'[^0-9]'), '');
                    String formatted = '';
                    if (numbers.length > 3) {
                      formatted += '${numbers.substring(0, 3)}-';
                      if (numbers.length > 6) {
                        formatted += '${numbers.substring(3, 6)}-';
                        formatted += numbers.substring(
                          6,
                          numbers.length > 10 ? 10 : numbers.length,
                        );
                      } else if (numbers.length > 3) {
                        formatted += numbers.substring(
                          3,
                          numbers.length > 6 ? 6 : numbers.length,
                        );
                      }
                    } else {
                      formatted = numbers;
                    }
                    if (formatted != v) {
                      _telefonoController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                  validator: (v) {
                    final regex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
                    if (v == null || !regex.hasMatch(v)) {
                      return 'Formato: xxx-xxx-xxxx';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _domicilioController,
                  decoration: const InputDecoration(
                    labelText: 'Domicilio',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 5 ? null : 'Domicilio muy corto',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _salarioController,
                  decoration: const InputDecoration(
                    labelText: 'Salario o ingreso mensual',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    final n = num.tryParse(v);
                    if (n == null || n < 0)
                      return 'Debe ser un número positivo';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_success != null)
                  Text(_success!, style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _register();
                            }
                          },
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Registrarse'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
