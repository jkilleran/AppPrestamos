import 'package:flutter/material.dart';
import 'home_page.dart';

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
      home: MyHomePage(onToggleTheme: onToggleTheme),
    );
  }
}
