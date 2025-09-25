import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import '../models/auth_request.dart';
import '../services/service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _phone.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await SimpleAuthService().login(LoginRequest(
      phone: _phone.text.trim(), password: _pass.text));
    setState(() => _loading = false);

    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยินดีต้อนรับ ${res.user!.name} (${res.user!.role})')));
      // TODO: นำทางไปหน้า Home ตาม role
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Login ผิดพลาด')));
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
              const Text("Login", style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(children: [
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "หมายเลขโทรศัพท์",
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v)=> v==null||v.isEmpty ? 'กรอกเบอร์โทร' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass, obscureText: true,
                    decoration: const InputDecoration(
                      hintText: "รหัสผ่าน",
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                    validator: (v)=> v==null||v.length<6 ? 'อย่างน้อย 6 ตัว' : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DeliveryApp.blue, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: _loading ? null : _submit,
                      child: _loading ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: ()=> Navigator.pushNamed(context, '/register'),
                    child: const Text("ยังไม่มีบัญชี? สมัครสมาชิก", style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
