import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'main_home_page.dart';
import 'push_service.dart';
import 'brand_theme.dart';
import 'utils/auth_session.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppThemeSwitcher());
}

class AppThemeSwitcher extends StatefulWidget {
  const AppThemeSwitcher({super.key});

  @override
  State<AppThemeSwitcher> createState() => _AppThemeSwitcherState();
}

class _AppThemeSwitcherState extends State<AppThemeSwitcher> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyApp(themeMode: _themeMode, onToggleTheme: _toggleTheme);
  }
}

class MyApp extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  const MyApp({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _checking = true;
  bool _loggedIn = false;
  String? _token;
  String? _role;
  String? _name;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = AuthSession.readValid(prefs);
    if (session == null) {
      await AuthSession.clear(prefs);
    }
    if (!mounted) return;

    setState(() {
      _loggedIn = session != null;
      _token = session?.token;
      _role = session?.role;
      _name = session?.name;
      _checking = false;
    });

    if (session != null) {
      // Intenta registrar el token guardado (si existe)
      unawaited(PushService.registerSavedTokenWithBackend());
    }
  }

  void _handleLoginSuccess(String token, String role, String name) {
    if (!mounted) return;
    setState(() {
      _loggedIn = true;
      _token = token;
      _role = role;
      _name = name;
    });

    // Intentar registrar el token FCM si ya existe en preferencias.
    unawaited(PushService.registerSavedTokenWithBackend());
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (context) => const MainHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        title: 'App Préstamos',
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'App Préstamos',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: widget.themeMode,
      routes: {
        '/login': (context) => LoginPage(onLoginSuccess: _handleLoginSuccess),
        '/home': (context) => const MainHomePage(),
        '/novedades': (context) => MyHomePage(
          onToggleTheme: () {},
          token: _token ?? '',
          role: _role ?? '',
          name: _name ?? '',
        ),
      },
      home: _loggedIn
          ? const MainHomePage()
          : LoginPage(onLoginSuccess: _handleLoginSuccess),
    );
  }
}
