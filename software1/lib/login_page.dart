import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'config/api_config.dart';
import 'utils/auth_session.dart';

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

  String? _requiredString(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        ApiConfig.uri('login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          AuthSession.loginPayload(
            email: _emailController.text,
            password: _passwordController.text,
          ),
        ),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw const FormatException('Respuesta de login inválida');
        }
        final data = Map<String, dynamic>.from(decoded);
        final token = _requiredString(data['token']);
        final role = _requiredString(data['role']);
        final name = _requiredString(data['name']);
        if (token == null ||
            role == null ||
            name == null ||
            !AuthSession.isJwtUnexpired(token)) {
          throw const FormatException('Sesión recibida inválida');
        }

        // Guardar token, rol y datos completos en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await AuthSession.clear(prefs);
        await prefs.setString('jwt_token', token);
        await prefs.setString('token', token);
        await prefs.setString('user_role', role);
        await prefs.setString('user_name', name);
        if (data['email'] is String) {
          await prefs.setString('user_email', data['email'] as String);
        }
        if (data['cedula'] is String) {
          await prefs.setString('user_cedula', data['cedula'] as String);
        }
        if (data['telefono'] is String) {
          await prefs.setString('user_telefono', data['telefono'] as String);
        }
        if (data['domicilio'] is String) {
          await prefs.setString('user_domicilio', data['domicilio'] as String);
        }
        if (data['salario'] != null) {
          await prefs.setString('user_salario', data['salario'].toString());
        }
        if (data['categoria'] is String) {
          await prefs.setString('categoria', data['categoria'] as String);
        }
        if (data['prestamos_aprobados'] is num) {
          await prefs.setInt(
            'prestamos_aprobados',
            (data['prestamos_aprobados'] as num).toInt(),
          );
        }
        if (!mounted) return;

        // NUEVO: obtener datos actualizados del usuario (incluyendo foto)
        try {
          final uri = ApiConfig.uri('profile');
          final profileResp = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          );
          if (!mounted) return;
          if (profileResp.statusCode == 200) {
            final user = jsonDecode(profileResp.body);
            if (user is Map && user['foto'] is String) {
              await prefs.setString('foto', user['foto'] as String);
            }
          }
        } catch (_) {}
        if (!mounted) return;
        widget.onLoginSuccess(token, role, name);
      } else {
        String backendError = 'Credenciales incorrectas';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) backendError = data['error'];
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _error = backendError;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Respuesta inválida del servidor';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            final minimumHeight = constraints.maxHeight > verticalPadding * 2
                ? constraints.maxHeight - verticalPadding * 2
                : 0.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumHeight),
                child: Align(
                  alignment: isWide ? Alignment.center : Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
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
                                'Iniciar Sesión',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Accede a tu cuenta para continuar.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) => v != null && v.contains('@')
                                    ? null
                                    : 'Correo inválido',
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Contraseña',
                                  border: OutlineInputBorder(),
                                ),
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: (v) => v != null && v.length >= 4
                                    ? null
                                    : 'Contraseña muy corta',
                                onFieldSubmitted: (_) {
                                  if (!_loading &&
                                      (_formKey.currentState?.validate() ??
                                          false)) {
                                    _login();
                                  }
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
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          if (_formKey.currentState
                                                  ?.validate() ??
                                              false) {
                                            _login();
                                          }
                                        },
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text('Entrar'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  '¿No tienes cuenta? Regístrate',
                                ),
                              ),
                            ],
                          ),
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
