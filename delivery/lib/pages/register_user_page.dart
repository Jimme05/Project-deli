import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/address.dart';
import '../models/auth_request.dart';
import '../services/storage_service.dart';
import '../services/service.dart';

class RegisterUserTab extends StatefulWidget {
  const RegisterUserTab({super.key});
  @override
  State<RegisterUserTab> createState() => _RegisterUserTabState();
}

class _RegisterUserTabState extends State<RegisterUserTab> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();
  final _addr  = TextEditingController();
  final _picker = ImagePicker();
  File? _img;
  bool _loading = false;

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _img = File(x.path));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    String? url;
    if (_img != null) {
      url = await StorageService()
          .uploadFile(_img!, "users/${DateTime.now().millisecondsSinceEpoch}_profile.jpg");
    }

    final req = UserSignUpRequest(
      phone: _phone.text.trim(),
      password: _pass.text,
      name: _name.text.trim(),
      photoUrl: url,
      primaryAddress: Address(
        label: "บ้าน",
        addressText: _addr.text.trim(),
        latitude: 13.75, // TODO: ต่อ map picker
        longitude: 100.5,
      ),
    );

    final res = await SimpleAuthService().signUpUser(req);
    setState(() => _loading = false);

    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สมัคร User สำเร็จ: ${res.user!.uid}')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'สมัครไม่สำเร็จ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Form(
        key: _form,
        child: Column(children: [
          GestureDetector(
            onTap: _pick,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              backgroundImage: _img!=null ? FileImage(_img!) : null,
              child: _img==null ? const Icon(Icons.camera_alt_rounded, color: Colors.black45, size: 30) : null,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: "Phone", prefixIcon: Icon(Icons.phone_rounded)),
            validator: (v)=> v==null||v.isEmpty ? 'กรอกเบอร์โทร' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pass, obscureText: true,
            decoration: const InputDecoration(hintText: "Password", prefixIcon: Icon(Icons.lock_rounded)),
            validator: (v)=> v==null||v.length<6 ? 'อย่างน้อย 6 ตัว' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(hintText: "Name", prefixIcon: Icon(Icons.person_rounded)),
            validator: (v)=> v==null||v.isEmpty ? 'กรอกชื่อ' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _addr,
            decoration: const InputDecoration(hintText: "Address", prefixIcon: Icon(Icons.location_on_rounded)),
            validator: (v)=> v==null||v.isEmpty ? 'กรอกที่อยู่' : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DeliveryApp.blue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Sign Up", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
