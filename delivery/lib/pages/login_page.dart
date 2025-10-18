import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import '../models/auth_response.dart';
import '../services/firebase_auth_service.dart'; // 👈 ใช้ FirebaseAuth แทน SimpleAuthService
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
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = FirebaseAuthService();
    final res = await auth.loginWithEmail(
      email: _email.text.trim(),
      password: _pass.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      final UserResponse user = res.user!;
      final target = _routeForRole(user.role);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยินดีต้อนรับ ${user.name.isEmpty ? user.uid : user.name} (${user.role})')),
      );

      // 🔑 นำทางและล้างสแตกไม่ให้กดย้อนกลับมาที่ login
      Navigator.of(context).pushNamedAndRemoveUntil(target, (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง')),
      );
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
                    // Email
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "อีเมล",
                        prefixIcon: Icon(Icons.email_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'กรอกอีเมล';
                        final ok = RegExp(r"^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$").hasMatch(v.trim());
                        return ok ? null : 'รูปแบบอีเมลไม่ถูกต้อง';
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

                    // (ตัวเลือก) ลืมรหัสผ่าน
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot_password'); // ถ้ามีหน้า reset
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
