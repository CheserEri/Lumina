import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const OpenCodeLuminaApp());
}

class OpenCodeLuminaApp extends StatefulWidget {
  const OpenCodeLuminaApp({super.key});

  @override
  State<OpenCodeLuminaApp> createState() => _OpenCodeLuminaAppState();
}

class _OpenCodeLuminaAppState extends State<OpenCodeLuminaApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCodeLumina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: const ChatScreen(),
            floatingActionButton: FloatingActionButton(
              mini: true,
              onPressed: _toggleTheme,
              backgroundColor: const Color(0xFF10A37F),
              child: Icon(
                _themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
