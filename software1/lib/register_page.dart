import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'config/api_config.dart';

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
      var uri = ApiConfig.uri('register');
      var request = http.MultipartRequest('POST', uri);
      request.fields['name'] = _nameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['password'] = _passwordController.text.trim();
      request.fields['cedula'] = _cedulaController.text.trim();
      request.fields['telefono'] = _telefonoController.text.trim();
      request.fields['domicilio'] = _domicilioController.text.trim();
      request.fields['salario'] = _salarioController.text.trim();
      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      if (kDebugMode) {
        debugPrint('Respuesta backend: $respStr');
      }
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text.trim());
        await prefs.setString('user_email', _emailController.text.trim());
        await prefs.setString('user_cedula', _cedulaController.text.trim());
        await prefs.setString('user_telefono', _telefonoController.text.trim());
        await prefs.setString(
          'user_domicilio',
          _domicilioController.text.trim(),
        );
        await prefs.setString('user_salario', _salarioController.text.trim());
        setState(() {
          _success = 'Registro exitoso. Ahora puedes iniciar sesión.';
        });
        if (widget.onRegisterSuccess != null) {
          widget.onRegisterSuccess!();
        }
      } else {
        final data = respStr.isNotEmpty ? jsonDecode(respStr) : {};
        setState(() {
          _error = data['error'] ?? respStr ?? 'Error al registrar';
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
    final theme = Theme.of(context);

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
        title: const Text('App Préstamos'),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final horizontalPadding = isWide ? 32.0 : 20.0;
            final verticalPadding = isWide ? 40.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: isWide ? 3 : 0,
                    color: isWide ? null : Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isWide ? 40 : 4),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Crear cuenta',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Completa tus datos para comenzar.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v != null && v.length >= 2
                                  ? null
                                  : 'Nombre muy corto',
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v != null && v.contains('@')
                                  ? null
                                  : 'Correo inválido',
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
                                String numbers = v.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
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
                                String numbers = v.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
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
                              validator: (v) => v != null && v.length >= 5
                                  ? null
                                  : 'Domicilio muy corto',
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
                                if (v == null || v.isEmpty) {
                                  return 'Campo requerido';
                                }
                                final n = num.tryParse(v);
                                if (n == null || n < 0) {
                                  return 'Debe ser un número positivo';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 18),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            if (_success != null) ...[
                              const SizedBox(height: 18),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _success!,
                                  style: TextStyle(
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          _register();
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandPalette.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Registrarse'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                '¿Ya tienes cuenta? Inicia sesión',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
