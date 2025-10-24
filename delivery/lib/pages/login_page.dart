import 'package:delivery/services/firebase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/app_logo.dart';
import '../models/auth_response.dart'; // ถ้ามีใช้อยู่ที่อื่นได้ ไม่บังคับในหน้านี้
import '../main.dart';

/// mapping ของ role -> route
class RoleRoutes {
  static const rider = '/rider';
  static const customer = '/home'; // หน้าโฮมลูกค้า
  static const admin = '/admin';
  static const fallback = '/home';
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController(); // อีเมลหรือเบอร์
  final _pass = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _routeForRole(String? roleRaw) {
    final role = (roleRaw ?? '').toLowerCase().trim();
    switch (role) {
      case 'rider':
      case 'driver':
      case 'courier':
        return RoleRoutes.rider;
      case 'admin':
      case 'staff':
        return RoleRoutes.admin;
      case 'user':
      case 'customer':
      case 'member':
        return RoleRoutes.customer;
      default:
        return RoleRoutes.fallback;
    }
  }

 
  bool _looksLikeEmail(String v) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v.trim());
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final id = _identifier.text.trim();
    final password = _pass.text;

    try {
      if (_looksLikeEmail(id)) {
        // ====== ล็อกอินด้วยอีเมลปกติ ======
        await FirebaseAuthService().loginWithEmail(email: id, password: password);

        return;
      }

      // ====== ล็อกอินด้วยเบอร์โทร ======
      final phone = id;

      // หา candidates จาก users และ riders
      final usersQ = await db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .where('role', isNotEqualTo: 'rider')
          .limit(1)
          .get();
      final ridersQ = await db
          .collection('riders')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      final candidates = <_Candidate>[];

      if (usersQ.docs.isNotEmpty) {
        final m = usersQ.docs.first.data();
        final email = (m['email'] ?? '').toString().trim();
        if (email.isNotEmpty) {
          candidates.add(_Candidate(
            role: (m['role'] ?? 'user').toString(),
            email: email,
          ));
        }
      }
      if (ridersQ.docs.isNotEmpty) {
        final m = ridersQ.docs.first.data();
        final email = (m['email'] ?? '').toString().trim();
        if (email.isNotEmpty) {
          candidates.add(_Candidate(
            role: (m['role'] ?? 'rider').toString(),
            email: email,
          ));
        }
      }

      if (candidates.isEmpty) {
        throw Exception('ไม่พบบัญชีที่ลงทะเบียนด้วยเบอร์นี้');
      }

      // ลอง sign-in ทีละ candidate เพื่อเช็คว่ารหัสผ่านถูกกับอีเมลไหนบ้าง
      final successes = <_Candidate>[];
      for (final c in candidates) {
        try {
          await FirebaseAuthService().loginWithEmail(
              email: c.email, password: password);
          successes.add(c);
        } catch (e) {
           throw Exception('เบอร์หรือรหัสผ่านไม่ถูกต้อง');
        }
      }

      

      if (successes.isEmpty) {
        throw Exception('เบอร์หรือรหัสผ่านไม่ถูกต้อง');
      }

     


    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppLogo(),
              const SizedBox(height: 18),
              const Text(
                "Login",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Form(
                key: _form,
                child: Column(
                  children: [
                    // Email หรือ เบอร์โทร
                    TextFormField(
                      controller: _identifier,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "อีเมล หรือ เบอร์โทร",
                        prefixIcon: Icon(Icons.account_circle_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'กรอกอีเมลหรือเบอร์โทร';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextFormField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "รหัสผ่าน",
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'อย่างน้อย 6 ตัว' : null,
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DeliveryApp.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Login",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      child: const Text("ยังไม่มีบัญชี? สมัครสมาชิก", style: TextStyle(color: Colors.white)),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot_password');
                      },
                      child: const Text("ลืมรหัสผ่าน?", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Candidate {
  final String role;
  final String email;
  _Candidate({
    required this.role,
    required this.email,

  });
}
