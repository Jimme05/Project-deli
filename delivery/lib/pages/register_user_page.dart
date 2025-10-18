import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/address.dart';
import '../models/auth_request.dart';
import '../services/firebase_auth_service.dart'; // 👈 ใช้ FirebaseAuthService ใหม่

class RegisterUserTab extends StatefulWidget {
  const RegisterUserTab({super.key});
  @override
  State<RegisterUserTab> createState() => _RegisterUserTabState();
}

class _RegisterUserTabState extends State<RegisterUserTab> {
  final _form = GlobalKey<FormState>();

  final _email = TextEditingController(); // 👈 ใหม่: ใช้สมัครด้วย Email/Password
  final _phone = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();
  final _addr  = TextEditingController();

  final _picker = ImagePicker();
  File? _img;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _name.dispose();
    _addr.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _img = File(x.path));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // ✅ เตรียม request สำหรับโปรไฟล์ + ที่อยู่แรก (ส่วนของรูปให้อัปโหลดที่ service)
      final req = UserSignUpRequest(
        phone: _phone.text.trim(),
        password: _pass.text,         // ใช้สร้างบัญชีกับ FirebaseAuth
        name: _name.text.trim(),
        primaryAddress: Address(
          label: "บ้าน",
          addressText: _addr.text.trim(),
          latitude: 13.75,            // TODO: ต่อ map picker
          longitude: 100.5,
        ),
        profileFile: _img,
      );

      // ✅ สมัครด้วย Email/Password ที่ FirebaseAuth
      final auth = FirebaseAuthService();
      final res = await auth.signUpUserWithEmail(
        email: _email.text.trim(),
        req: req,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สมัคร User สำเร็จ: ${res.user!.uid}')),
        );
        Navigator.pop(context); // กลับหน้าก่อนหน้า
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'สมัครไม่สำเร็จ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Form(
        key: _form,
        child: Column(children: [
          // รูปโปรไฟล์
          GestureDetector(
            onTap: _pick,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              backgroundImage: _img != null ? FileImage(_img!) : null,
              child: _img == null
                  ? const Icon(Icons.camera_alt_rounded, color: Colors.black45, size: 30)
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // Email (สมัคร/ล็อกอินหลัก)
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: "Email", prefixIcon: Icon(Icons.email_rounded)),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'กรอกอีเมล';
              final ok = RegExp(r"^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$").hasMatch(v.trim());
              return ok ? null : 'รูปแบบอีเมลไม่ถูกต้อง';
            },
          ),
          const SizedBox(height: 10),

          // Phone (เก็บในโปรไฟล์)
          TextFormField(
            controller: _phone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: "Phone", prefixIcon: Icon(Icons.phone_rounded)),
            validator: (v) => v == null || v.isEmpty ? 'กรอกเบอร์โทร' : null,
          ),
          const SizedBox(height: 10),

          // Password (ใช้กับ FirebaseAuth)
          TextFormField(
            controller: _pass, obscureText: true,
            decoration: const InputDecoration(hintText: "Password", prefixIcon: Icon(Icons.lock_rounded)),
            validator: (v) => v == null || v.length < 6 ? 'อย่างน้อย 6 ตัว' : null,
          ),
          const SizedBox(height: 10),

          // Display name
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(hintText: "Name", prefixIcon: Icon(Icons.person_rounded)),
            validator: (v) => v == null || v.isEmpty ? 'กรอกชื่อ' : null,
          ),
          const SizedBox(height: 10),

          // Default address
          TextFormField(
            controller: _addr,
            decoration: const InputDecoration(hintText: "Address", prefixIcon: Icon(Icons.location_on_rounded)),
            validator: (v) => v == null || v.isEmpty ? 'กรอกที่อยู่' : null,
          ),
          const SizedBox(height: 16),

          // ปุ่มสมัคร
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DeliveryApp.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Sign Up", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
