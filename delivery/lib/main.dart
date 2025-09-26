import 'package:delivery/pages/home_page.dart';
import 'package:delivery/pages/rider_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'firebase_options.dart'; // สร้างจาก flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});
  static const green = Color(0xFF6AA56F);
  static const blue = Color(0xFF2D7BF0);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: green,
      appBarTheme: const AppBarTheme(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: Colors.black45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routes: {
        '/': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/rider': (_) => const RiderProfilePage(),
        '/home': (_) => const DeliveryHomePage(),
      },
    );
  }
}
