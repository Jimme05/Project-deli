import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/image_pick_box.dart';

class RegisterRiderPage extends StatefulWidget {
  const RegisterRiderPage({super.key});
  @override
  State<RegisterRiderPage> createState() => _RegisterRiderPageState();
}

class _RegisterRiderPageState extends State<RegisterRiderPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _plate = TextEditingController();

  File? _profileImage;
  File? _vehicleImage;

  @override
  void dispose() { _phone.dispose(); _password.dispose(); _name.dispose(); _plate.dispose(); super.dispose(); }

  Future<void> _pickProfile() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _profileImage = File(x.path));
  }

  Future<void> _pickVehicle() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _vehicleImage = File(x.path));
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      // TODO: สร้างบัญชี Rider + บันทึกรถ/รูป
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signing up (Rider)...')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Form(
          key: _form,
          child: Column(children: [
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ImagePickBox(label: 'รูปผู้ขับ', file: _profileImage, onTap: _pickProfile),
              const SizedBox(width: 16),
              ImagePickBox(label: 'รูปยานพาหนะ', file: _vehicleImage, onTap: _pickVehicle),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)),
              validator: (v)=> (v==null||v.isEmpty)?'กรอกเบอร์โทร':null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password, obscureText: true,
              decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_rounded)),
              validator: (v)=> (v==null||v.length<6)?'รหัสผ่านอย่างน้อย 6 ตัว':null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Name', prefixIcon: Icon(Icons.person_rounded)),
              validator: (v)=> (v==null||v.isEmpty)?'กรอกชื่อ':null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              decoration: const InputDecoration(hintText: 'license plate', prefixIcon: Icon(Icons.confirmation_num_rounded)),
              validator: (v)=> (v==null||v.isEmpty)?'กรอกทะเบียนรถ':null,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7BF0), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit, child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
