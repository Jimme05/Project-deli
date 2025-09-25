import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});
  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  File? _image;

  @override
  void dispose() { _phone.dispose(); _password.dispose(); _name.dispose(); _address.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _image = File(x.path));
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      // TODO: สร้างบัญชี User + บันทึกโปรไฟล์/ที่อยู่
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signing up (User)...')));
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
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                backgroundImage: _image != null ? FileImage(_image!) : null,
                child: _image == null ? const Icon(Icons.camera_alt_rounded, size: 32, color: Colors.black54) : null,
              ),
            ),
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
              controller: _address,
              decoration: const InputDecoration(hintText: 'Address', prefixIcon: Icon(Icons.location_on_rounded)),
              validator: (v)=> (v==null||v.isEmpty)?'กรอกที่อยู่':null,
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
