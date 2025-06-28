import 'package:flutter/material.dart';
import 'home_page.dart';
import 'login_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
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

class MyApp extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  const MyApp({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
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
      themeMode: themeMode,
      home: LoginPage(
        onLoginSuccess: (token, role, name) {
          try {
            print('Login callback ejecutado: ' + token + ', ' + role + ', ' + name);
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(
                builder: (context) => MyHomePage(
                  onToggleTheme: onToggleTheme,
                  token: token,
                  role: role,
                  name: name,
                ),
              ),
            );
          } catch (e, st) {
            print('Error en onLoginSuccess: ' + e.toString() + '\n' + st.toString());
          }
        },
      ),
    );
  }
}
