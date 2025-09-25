import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/auth_request.dart';
import '../services/storage_service.dart';
import '../services/service.dart';

class RegisterRiderTab extends StatefulWidget {
  const RegisterRiderTab({super.key});
  @override
  State<RegisterRiderTab> createState() => _RegisterRiderTabState();
}

class _RegisterRiderTabState extends State<RegisterRiderTab> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();
  final _plate = TextEditingController();

  final _picker = ImagePicker();
  File? _profile, _vehicle;
  bool _loading = false;

  Future<void> _pickProfile() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _profile = File(x.path));
  }

  Future<void> _pickVehicle() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _vehicle = File(x.path));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    String? pUrl, vUrl;
    if (_profile != null) {
      pUrl = await StorageService()
          .uploadFile(_profile!, "riders/${DateTime.now().millisecondsSinceEpoch}_profile.jpg");
    }
    if (_vehicle != null) {
      vUrl = await StorageService()
          .uploadFile(_vehicle!, "riders/${DateTime.now().millisecondsSinceEpoch}_vehicle.jpg");
    }

    final req = RiderSignUpRequest(
      phone: _phone.text.trim(),
      password: _pass.text,
      name: _name.text.trim(),
      vehiclePlate: _plate.text.trim(),
      profileUrl: pUrl,
      vehicleImgUrl: vUrl,
    );

    final res = await SimpleAuthService().signUpRider(req);
    setState(() => _loading = false);

    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สมัคร Rider สำเร็จ: ${res.user!.uid}')));
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
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ImageBox(label: "รูปผู้ขับ", file: _profile, onTap: _pickProfile),
            const SizedBox(width: 14),
            _ImageBox(label: "รูปยานพาหนะ", file: _vehicle, onTap: _pickVehicle),
          ]),
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
            controller: _plate,
            decoration: const InputDecoration(hintText: "license plate", prefixIcon: Icon(Icons.confirmation_num_rounded)),
            validator: (v)=> v==null||v.isEmpty ? 'กรอกทะเบียนรถ' : null,
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

class _ImageBox extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  const _ImageBox({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120, height: 110,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (file == null)
            const Icon(Icons.add_a_photo_rounded, size: 28, color: Colors.black54)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file!, width: 96, height: 70, fit: BoxFit.cover),
            ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
