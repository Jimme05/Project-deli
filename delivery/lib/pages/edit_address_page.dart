import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:latlong2/latlong.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import 'map_picker_page.dart'; // ✅ ใช้ MapPickerPage + MapPickerResult

class EditAddressPage extends StatefulWidget {
  const EditAddressPage({super.key});

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);

  final _labelCtrl = TextEditingController(text: 'บ้าน');
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController(text: '13.7563');
  final _lngCtrl = TextEditingController(text: '100.5018');

  bool _loading = false;
  final _svc = AddressService();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    // จุดเริ่มต้นของแผนที่ (อ่านจากฟอร์ม ถ้าแปลงไม่ได้จะใช้ กทม.)
    final init = LatLng(
      double.tryParse(_latCtrl.text.trim()) ?? 13.7563,
      double.tryParse(_lngCtrl.text.trim()) ?? 100.5018,
    );

    final res = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage(initial: init)),
    );

    if (res != null) {
      setState(() {
        _latCtrl.text = res.latlng.latitude.toStringAsFixed(6);
        _lngCtrl.text = res.latlng.longitude.toStringAsFixed(6);
        if ((res.address ?? '').isNotEmpty) {
          _addressCtrl.text = res.address!;
        }
      });
    }
  }

  Future<void> _save() async {
    final u = fa.FirebaseAuth.instance.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่ได้เข้าสู่ระบบ')),
      );
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกที่อยู่')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = u.uid;

      // ถ้ายังไม่เคยมีที่อยู่เลย → อันแรกจะตั้ง default อัตโนมัติ
      final hasAny = (await _svc.list(uid)).isNotEmpty;

      final a = Address(
        id: 'new', // service จะสร้าง doc id ให้เอง
        label: _labelCtrl.text.trim(),
        addressText: _addressCtrl.text.trim(),
        latitude: double.tryParse(_latCtrl.text.trim()) ?? 13.7563,
        longitude: double.tryParse(_lngCtrl.text.trim()) ?? 100.5018,
      );

      await _svc.add(uid, a, makeDefault: !hasAny);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกที่อยู่สำเร็จ')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'เพิ่ม/แก้ไขที่อยู่',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _tf(_labelCtrl, 'ป้ายชื่อที่อยู่ (บ้าน/ที่ทำงาน)'),
                  const SizedBox(height: 12),
                  _tf(_addressCtrl, 'ที่อยู่จัดส่ง', maxLines: 3),
                  const SizedBox(height: 12),

                  // แถวพิกัด + ปุ่มเลือกจากแผนที่
                  Row(
                    children: [
                      Expanded(child: _tf(_latCtrl, 'ละติจูด 13.xxxxx')),
                      const SizedBox(width: 8),
                      Expanded(child: _tf(_lngCtrl, 'ลองจิจูด 100.xxxxx')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('เลือกจากแผนที่'),
                      onPressed: _openMapPicker,
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'บันทึกข้อมูล',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tf(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
