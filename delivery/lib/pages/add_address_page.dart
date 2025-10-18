import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/services/firebase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/address.dart';
import '../models/order_create_request.dart';
import '../services/address_service.dart';
import '../services/order_service.dart';// ✅ ใช้ FirebaseAuth
import 'map_picker_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  static const Color kGreen = Color(0xFF6AA56F);

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  LatLng? _picked;
  File? _selectedImage;
  final _picker = ImagePicker();
  bool _loading = false;

  final _addressService = AddressService();
  final _auth = FirebaseAuthService();

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _openMapPicker() async {
    final LatLng initial = _picked ?? const LatLng(13.7563, 100.5018);
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage(initial: initial)),
    );
    if (result != null) {
      setState(() {
        _picked = result;
        _locationCtrl.text =
            "${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}";
      });
    }
  }

  Future<void> _submit() async {
  if (_nameCtrl.text.trim().isEmpty ||
      _phoneCtrl.text.trim().isEmpty ||
      _picked == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรอกชื่อ/เบอร์/เลือกพิกัดให้ครบ')),
    );
    return;
  }

  setState(() => _loading = true);
  try {
    // ✅ ใช้ FirebaseAuth ตรง ๆ
    final u = fa.FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception("ยังไม่ได้ล็อกอิน");
    debugPrint("👤 current uid = ${u.uid}");

    // ✅ ดึงที่อยู่ default ของผู้ส่ง
    final addrSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('addresses')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (addrSnap.docs.isEmpty) {
      throw Exception("ไม่พบบ้าน/จุดรับของผู้ส่ง (โปรดเพิ่มที่อยู่หลักก่อน)");
    }

    final a = addrSnap.docs.first.data();
    final pickup = Address(
      label: a['label'] ?? 'บ้าน',
      addressText: a['addressText'] ?? '',
      latitude: (a['Latitude'] as num).toDouble(),
      longitude: (a['Longitude'] as num).toDouble(),
    );

    // ✅ ปลายทางจากฟอร์ม
    final delivery = Address(
      label: "ปลายทาง",
      addressText: _descCtrl.text.trim(),
      latitude: _picked!.latitude,
      longitude: _picked!.longitude,
    );

    // ✅ หา UID ของผู้รับจากเบอร์
    final phone = _phoneCtrl.text.trim();
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    final receiverUid = q.docs.isNotEmpty ? q.docs.first.id : "";

    final req = OrderCreateRequest(
      senderUid: u.uid,
      receiverUid: receiverUid,
      receiverPhone: phone,
      receiverName: _nameCtrl.text.trim(),
      pickupAddress: pickup,
      deliveryAddress: delivery,
      description: _descCtrl.text.trim(),
      status1ImageFile: _selectedImage,
    );

    final oid = await OrderService().createOrder(req);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ สร้างออเดอร์สำเร็จ (OID: $oid)')),
    );
    _clearForm();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚠️ เกิดข้อผิดพลาด: $e')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  void _clearForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _locationCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _selectedImage = null;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'เพิ่มที่อยู่ผู้รับใหม่',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ตัวช่วยที่อยู่', style: TextStyle(fontSize: 16)),
                  InkWell(
                    onTap: _openMapPicker,
                    child: const Text(
                      'เลือกจากแผนที่',
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 12),
              _buildTextField(_nameCtrl, 'ชื่อผู้รับ', TextInputType.name),
              const SizedBox(height: 10),
              _buildTextField(_phoneCtrl, 'เบอร์โทรศัพท์', TextInputType.phone),
              const SizedBox(height: 10),
              _buildTextField(_locationCtrl, 'โปรดเลือกพิกัดปลายทาง',
                  TextInputType.text,
                  readOnly: true),
              const SizedBox(height: 10),
              _buildTextField(_descCtrl, 'รายละเอียดที่อยู่ผู้รับ',
                  TextInputType.multiline,
                  maxLines: 3),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _selectedImage == null
                            ? const Icon(Icons.add_a_photo,
                                size: 40, color: Colors.grey)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_selectedImage!,
                                    fit: BoxFit.cover)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('แนบรูป (สถานะ [1] รอไรเดอร์มารับ)'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('สำเร็จ',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      TextInputType type,
      {bool readOnly = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: type,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade300,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
