import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../main.dart';

class RegisterUserTab extends StatefulWidget {
  const RegisterUserTab({super.key});

  @override
  State<RegisterUserTab> createState() => _RegisterUserTabState();
}

class _RegisterUserTabState extends State<RegisterUserTab> {
  final _form = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _search = TextEditingController();

  final _picker = ImagePicker();
  final _mapController = MapController();

  File? _img;
  bool _loading = false;

  LatLng? _selectedPoint;
  String? _addressText;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _img = File(x.path));
  }

  // 🔎 ค้นหาสถานที่ (Forward Geocoding) — Nominatim
  Future<void> _searchPlace() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(q)}&format=json&limit=1&addressdetails=1',
    );

    try {
      final res = await http.get(
        url,
        headers: {'User-Agent': 'delivery-app/1.0 (edu-example)'},
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
          final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
          final displayName = data[0]['display_name']?.toString();

          if (lat != null && lon != null) {
            setState(() {
              _selectedPoint = LatLng(lat, lon);
              _addressText = displayName ?? 'ไม่พบชื่อสถานที่';
            });
            _mapController.move(_selectedPoint!, 15);
          } else {
            _toast('ข้อมูลพิกัดไม่ถูกต้องจากผลการค้นหา');
          }
        } else {
          _toast('ไม่พบสถานที่ที่ค้นหา');
        }
      } else {
        _toast('ค้นหาล้มเหลว (${res.statusCode})');
      }
    } catch (e) {
      _toast('เกิดข้อผิดพลาดในการค้นหา: $e');
    }
  }

  // 🔁 Reverse Geocoding — แปลงพิกัดเป็นชื่อสถานที่
  Future<void> _getAddressFromLatLng(LatLng point) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=${point.latitude}&lon=${point.longitude}'
      '&zoom=18&addressdetails=1',
    );

    try {
      final res = await http.get(
        url,
        headers: {'User-Agent': 'delivery-app/1.0 (edu-example)'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final displayName = data['display_name']?.toString();
        setState(() {
          _addressText = displayName ??
              'ตำแหน่ง (${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)})';
        });
      } else {
        setState(() {
          _addressText =
              'ตำแหน่ง (${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)})';
        });
      }
    } catch (e) {
      setState(() {
        _addressText =
            'ตำแหน่ง (${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)})';
      });
    }
  }

  // ✅ ตรวจสอบอีเมล/เบอร์ซ้ำ
  Future<bool> _isDuplicate(String email, String phone) async {
    final userRef = FirebaseFirestore.instance.collection('users');
    final checkEmail =
        await userRef.where('email', isEqualTo: email).limit(1).get();
    final checkPhone =
        await userRef
        
        .where('phone', isEqualTo: phone)
        .where('role',isNotEqualTo: 'rider')
        .limit(1).get();
    return checkEmail.docs.isNotEmpty || checkPhone.docs.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedPoint == null) {
      _toast('กรุณาปักหมุดที่อยู่ก่อนสมัคร');
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final phone = _phone.text.trim();
      final pass = _pass.text.trim();
      final name = _name.text.trim();

      if (await _isDuplicate(email, phone)) {
        setState(() => _loading = false);
        _toast('อีเมลหรือเบอร์นี้ถูกใช้แล้ว');
        return;
      }

      // 🧾 สมัครผู้ใช้งาน
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      final user = credential.user;
      if (user == null) throw Exception('สร้างผู้ใช้ไม่สำเร็จ');

      final lat = _selectedPoint!.latitude;
      final lng = _selectedPoint!.longitude;
      final text = _addressText ?? 'ไม่ทราบที่อยู่';

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // 1) เก็บใน users/{uid} (มีฟิลด์ address แบบย่อย)
      await userDoc.set({
        'uid': user.uid,
        'email': email,
        'phone': phone,
        'name': name,
        'role': 'user',
        'address': {
          // เก็บแบบตัวเล็กไว้ด้วย
          'label': 'บ้าน',
          'addressText': text,
          'latitude': lat,
          'longitude': lng,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) สร้าง subcollection users/{uid}/addresses/default
      //    ใช้โครงเดียวกับส่วนอื่นของแอป (คีย์ตัวใหญ่ + isDefault)
      await userDoc.collection('addresses').doc('default').set({
        'label': 'บ้าน',
        'addressText': text,
        'Latitude': lat,   // 👈 ตัวใหญ่
        'Longitude': lng,  // 👈 ตัวใหญ่
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _loading = false);
      if (!mounted) return;

      _toast('✅ สมัคร User สำเร็จ');
      Navigator.pop(context, '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('เกิดข้อผิดพลาด: $e');
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Form(
        key: _form,
        child: Column(
          children: [
            GestureDetector(
              onTap: _pick,
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                backgroundImage: _img != null ? FileImage(_img!) : null,
                child: _img == null
                    ? const Icon(Icons.camera_alt_rounded,
                        color: Colors.black45, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 12),

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
                    RegExp(r"^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$").hasMatch(v.trim());
                return ok ? null : 'รูปแบบอีเมลไม่ถูกต้อง';
              },
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: "Phone",
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'กรอกเบอร์โทร' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Password",
                prefixIcon: Icon(Icons.lock_rounded),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: "Name",
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'กรอกชื่อผู้ใช้' : null,
            ),
            const SizedBox(height: 20),

            // ช่องค้นหา
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาสถานที่ เช่น Central World...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _searchPlace(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _searchPlace,
                  icon: const Icon(Icons.location_searching, size: 18),
                  label: const Text("ค้นหา"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 🗺️ แผนที่
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(13.7563, 100.5018),
                  initialZoom: 12,
                  onTap: (tapPos, point) async {
                    setState(() => _selectedPoint = point);
                    await _getAddressFromLatLng(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.delivery',
                  ),
                  if (_selectedPoint != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPoint!,
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _addressText != null
                  ? "📍 $_addressText"
                  : "แตะบนแผนที่หรือค้นหาสถานที่เพื่อเลือกที่อยู่",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 20),

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
