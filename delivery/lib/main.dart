import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

void main() => runApp(const DeliveryApp());

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  static const Color kGreen = Color(0xFF66A36C);
  static const Color kBlue  = Color(0xFF2D7BF0);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kGreen,
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: kGreen, foregroundColor: Colors.white, elevation: 0),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routes: {
        '/': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
      initialRoute: '/',
    );
  }
}
