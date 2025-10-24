import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/auth_request.dart';
import '../services/firebase_auth_service.dart'; // 👈 ใช้ FirebaseAuth + อัปโหลดใน service
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 เพิ่มเพื่อเช็คเบอร์ซ้ำใน Firestore

class RegisterRiderTab extends StatefulWidget {
  const RegisterRiderTab({super.key});
  @override
  State<RegisterRiderTab> createState() => _RegisterRiderTabState();
}

class _RegisterRiderTabState extends State<RegisterRiderTab> {
  final _form = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _plate = TextEditingController();

  final _picker = ImagePicker();
  File? _profile, _vehicle;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _pickProfile() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _profile = File(x.path));
  }

  Future<void> _pickVehicle() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _vehicle = File(x.path));
  }

  /// 🔎 เช็คเบอร์ซ้ำในคอลเล็กชัน riders (และกันชนกับ users ด้วย)
  Future<bool> _isPhoneDuplicate(String rawPhone) async {
    // normalize ง่าย ๆ: ตัดช่องว่าง/ขีด/วงเล็บ
    final phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    final db = FirebaseFirestore.instance;

    // ซ้ำกับไรเดอร์หรือไม่
    final riderSnap = await db
        .collection('riders')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (riderSnap.docs.isNotEmpty) return true;


    return false;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final normalizedPhone = _phone.text.trim().replaceAll(RegExp(r'[^\d+]'), '');

      // ❗ เช็คเบอร์ซ้ำก่อนสมัคร
      if (await _isPhoneDuplicate(normalizedPhone)) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เบอร์นี้ถูกใช้แล้ว (ซ้ำกับไรเดอร์/ผู้ใช้คนอื่น)')),
        );
        return;
      }
    

      final req = RiderSignUpRequest(
        phone: normalizedPhone,
        password: _pass.text,
        name: _name.text.trim(),
        vehiclePlate: _plate.text.trim(),
        profileFile: _profile,
        vehicleFile: _vehicle,
      );

      final auth = FirebaseAuthService();
      final res = await auth.signUpRiderWithEmail(
        email: _email.text.trim(),
        req: req,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สมัคร Rider สำเร็จ: ${res.user!.uid}')),
        );

        // ✅ ไปที่หน้าหลักของ Rider ทันที
        Navigator.pushNamedAndRemoveUntil(context, '/rider', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'สมัครไม่สำเร็จ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Form(
        key: _form,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ImageBox(
                  label: "รูปผู้ขับ",
                  file: _profile,
                  onTap: _pickProfile,
                ),
                const SizedBox(width: 14),
                _ImageBox(
                  label: "รูปยานพาหนะ",
                  file: _vehicle,
                  onTap: _pickVehicle,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: "Email",
                prefixIcon: Icon(Icons.email_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'กรอกอีเมล';
                final ok =
                    RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v.trim());
                return ok ? null : 'รูปแบบอีเมลไม่ถูกต้อง';
              },
            ),
            const SizedBox(height: 10),

            // Phone
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: "Phone",
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'กรอกเบอร์โทร';
                final p = v.replaceAll(RegExp(r'[^\d+]'), '');
                // ไทยมัก 9–10 หลัก (หรือเบอร์สากลเริ่ม +)
                if (!(RegExp(r'^\+?\d{6,12}$').hasMatch(p))) {
                  return 'กรอกเบอร์ให้ถูกต้อง (6–12 หลัก)';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Password
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Password",
                prefixIcon: Icon(Icons.lock_rounded),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'อย่างน้อย 6 ตัว' : null,
            ),
            const SizedBox(height: 10),

            // Name
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: "Name",
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'กรอกชื่อ' : null,
            ),
            const SizedBox(height: 10),

            // License plate
            TextFormField(
              controller: _plate,
              decoration: const InputDecoration(
                hintText: "license plate",
                prefixIcon: Icon(Icons.confirmation_num_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'กรอกทะเบียนรถ' : null,
            ),
            const SizedBox(height: 16),

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
                        "Sign Up",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  const _ImageBox({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (file == null)
              const Icon(
                Icons.add_a_photo_rounded,
                size: 28,
                color: Colors.black54,
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file!,
                  width: 96,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
