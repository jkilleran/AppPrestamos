import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'main_home_page.dart';
import 'push_service.dart';

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
    final token = prefs.getString('jwt_token');
    final role = prefs.getString('user_role');
    final name = prefs.getString('user_name');
    setState(() {
      _loggedIn = token != null && token.isNotEmpty;
      _token = token;
      _role = role;
      _name = name;
      _checking = false;
    });
    if (_loggedIn) {
      // Intenta registrar el token guardado (si existe)
      PushService.registerSavedTokenWithBackend();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: widget.themeMode,
      routes: {
        '/login': (context) => LoginPage(
          onLoginSuccess: (token, role, name) {
            setState(() {
              _loggedIn = true;
              _token = token;
              _role = role;
              _name = name;
            });
            // Intentar registrar el token FCM si ya existe en preferencias
            PushService.registerSavedTokenWithBackend();
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (context) => MainHomePage()),
            );
          },
        ),
        '/home': (context) => MainHomePage(),
        '/novedades': (context) => MyHomePage(
          onToggleTheme: () {},
          token: _token ?? '',
          role: _role ?? '',
          name: _name ?? '',
        ),
      },
      home: _loggedIn
          ? MainHomePage()
          : LoginPage(
              onLoginSuccess: (token, role, name) {
                setState(() {
                  _loggedIn = true;
                  _token = token;
                  _role = role;
                  _name = name;
                });
                // Intentar registrar el token FCM si ya existe en preferencias
                PushService.registerSavedTokenWithBackend();
                navigatorKey.currentState!.pushReplacement(
                  MaterialPageRoute(builder: (context) => MainHomePage()),
                );
              },
            ),
    );
  }
}
