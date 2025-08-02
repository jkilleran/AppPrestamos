import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  final void Function(String token, String role, String name) onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('https://appprestamos-f5wz.onrender.com/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );
      print('LOGIN RESPONSE BODY: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Guardar token, rol y datos completos en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        await prefs.setString('token', data['token']); // Unificación para documentos_page.dart
        await prefs.setString('user_role', data['role']);
        await prefs.setString('user_name', data['name']);
        if (data['email'] != null) {
          await prefs.setString('user_email', data['email']);
        }
        if (data['cedula'] != null) {
          await prefs.setString('user_cedula', data['cedula']);
        }
        if (data['telefono'] != null) {
          await prefs.setString('user_telefono', data['telefono']);
        }
        if (data['domicilio'] != null) {
          await prefs.setString('user_domicilio', data['domicilio']);
        }
        if (data['salario'] != null) {
          await prefs.setString('user_salario', data['salario'].toString());
        }
        // NUEVO: obtener datos actualizados del usuario (incluyendo foto)
        try {
          var uri = Uri.parse('https://appprestamos-f5wz.onrender.com/profile');
          var profileResp = await http.get(
            uri,
            headers: {'Authorization': 'Bearer ${data['token']}'},
          );
          if (profileResp.statusCode == 200) {
            final user = jsonDecode(profileResp.body);
            if (user is Map && user.containsKey('foto')) {
              await prefs.setString('foto', user['foto'] ?? '');
            }
          }
        } catch (_) {}
        widget.onLoginSuccess(data['token'], data['role'], data['name']);
      } else {
        String backendError = 'Credenciales incorrectas';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) backendError = data['error'];
        } catch (_) {}
        setState(() {
          _error = backendError;
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
                  'Iniciar Sesión',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 24),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _login();
                            }
                          },
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
