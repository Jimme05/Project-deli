import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() { _phone.dispose(); _password.dispose(); super.dispose(); }

  void _submit() {
    if (_form.currentState!.validate()) {
      // TODO: ต่อ Firebase Auth
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logging in...')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(children: [
            const SizedBox(height: 12),
            const AppLogo(),
            const SizedBox(height: 24),
            const Text('Login', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _phone, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'หมายเลขโทรศัพท์', prefixIcon: Icon(Icons.phone_rounded)),
                  validator: (v) => (v==null || v.isEmpty) ? 'กรอกเบอร์โทร' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password, obscureText: true,
                  decoration: const InputDecoration(hintText: 'รหัสผ่าน', prefixIcon: Icon(Icons.lock_rounded)),
                  validator: (v) => (v==null || v.length<6) ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D7BF0), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _submit, child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
