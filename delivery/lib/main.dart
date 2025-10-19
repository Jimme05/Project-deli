import 'package:delivery/pages/add_address_page.dart';
import 'package:delivery/pages/edit_address_page.dart';
import 'package:delivery/pages/home_page.dart';
import 'package:delivery/pages/manage_addresses_page.dart';
import 'package:delivery/pages/profile_page.dart';
import 'package:delivery/pages/rider_accepted_orders_page.dart';
import 'package:delivery/pages/rider_parcel_status_page.dart';
import 'package:delivery/pages/rider_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'firebase_options.dart';
import 'pages/delivery_page.dart';

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
      home: const AuthGate(), // ✅ จุดเริ่มใหม่
      routes: {
        '/register': (_) => const RegisterPage(),
        '/rider': (_) => const RiderProfilePage(),
        '/home': (_) => const DeliveryHomePage(),
        '/delivery': (_) => const DeliveryPage(),
        '/profile': (_) => const ProfilePage(),
        '/add_address': (_) => const AddAddressPage(),
        '/rider_parcel_status': (_) =>
            const RiderParcelStatusPage(orderId: '', currentStatus: 1),
        '/edit_address': (_) => const EditAddressPage(),
        '/editaddresss': (_) => const ManageAddressesPage(),
        '/rider_accepted_orders': (_) => const RiderAcceptedOrdersPage(),
      },
    );
  }
}

/// ✅ ตรวจสถานะล็อกอิน + เช็ก Role ก่อนเข้าแอป
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) {
          // ยังไม่ได้ล็อกอิน
          return const LoginPage();
        } else {
          // ✅ เมื่อเข้าสู่ระบบแล้ว → ตรวจ role จาก Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!userSnap.hasData || !userSnap.data!.exists) {
                // ถ้าไม่มีข้อมูลผู้ใช้ใน Firestore
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'ไม่พบข้อมูลผู้ใช้ในระบบ Firestore',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                );
              }

              final data = userSnap.data!.data() as Map<String, dynamic>;
              final role = data['role'] ?? 'user'; // ค่าปกติคือ user

              if (role == 'rider') {
                // 🛵 หน้าของไรเดอร์
                return const RiderProfilePage();
              } else {
                // 👤 หน้าของ user ทั่วไป
                return const DeliveryHomePage();
              }
            },
          );
        }
      },
    );
  }
}
