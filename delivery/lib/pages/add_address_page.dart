import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/address.dart';
import '../models/order_create_request.dart';
import '../services/order_service.dart';
import '../services/service.dart'; // SimpleAuthService สำหรับ currentUser
import 'map_picker_page.dart';

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

  LatLng? _picked; // พิกัดที่เลือกจากแผนที่ (ปลายทาง)
  File? _selectedImage; // รูปสถานะ [1]
  final _picker = ImagePicker();
  bool _loading = false;

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
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

  Future<void> _openMapPicker() async {
    final LatLng initial = _picked ?? const LatLng(13.7563, 100.5018);
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage(initial: initial)),
    );
    if (result != null) {
      setState(() {
        _picked = result;
        _locationCtrl.text = "${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}";
      });
    }
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().isEmpty ||
        _nameCtrl.text.trim().isEmpty ||
        _picked == null ||
        _locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกชื่อ/เบอร์/เลือกพิกัดให้ครบ')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) ผู้ส่ง = current user
      final user = await SimpleAuthService().currentUser();
      if (user == null) {
        throw Exception("ยังไม่ได้ล็อกอิน");
      }

      // 2) หาผู้รับจากเบอร์ (ถ้ามี)
      final phone = _phoneCtrl.text.trim();
      final q = await FirebaseFirestore.instance
          .collection('users').where('phone', isEqualTo: phone).limit(1).get();
      final receiverUid = q.docs.isNotEmpty ? q.docs.first.id : ""; // อนุญาตว่างได้

      // 3) สร้าง Address pickup จากที่อยู่ default ของผู้ส่ง (ดึงจาก subcollection addresses ตัวแรก)
      // ถ้าคุณมีระบบเลือกหลายที่อยู่ ให้แก้ส่วนนี้ตามจริง
      final addrSnap = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('addresses')
          .limit(1).get();
      if (addrSnap.docs.isEmpty) {
        throw Exception("ไม่พบบ้าน/จุดรับของผู้ส่ง (โปรดเพิ่มที่อยู่ก่อน)");
      }
      final a = addrSnap.docs.first.data();
      final pickup = Address(
        label: a['label'] ?? 'บ้าน',
        addressText: a['addressText'] ?? '',
        latitude: (a['Latitude'] as num).toDouble(),
        longitude: (a['Longitude'] as num).toDouble(),
      );

      // 4) delivery address จากฟอร์มนี้
      final delivery = Address(
        label: "ปลายทาง",
        addressText: _descCtrl.text.trim(),
        latitude: _picked!.latitude,
        longitude: _picked!.longitude,
      );

      // 5) build request + call service
      final req = OrderCreateRequest(
        senderUid: user.uid,
        receiverUid: receiverUid,      // อาจจะว่างได้
        receiverPhone: phone,
        receiverName: _nameCtrl.text.trim(),
        pickupAddress: pickup,
        deliveryAddress: delivery,
        description: _descCtrl.text.trim(),
        status1ImageFile: _selectedImage, // แนบรูป [1] ได้
      );

      final oid = await OrderService().createOrder(req);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้างออเดอร์สำเร็จ (OID: $oid)')),
      );
      _clearForm();

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
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text('เพิ่มที่อยู่ผู้รับใหม่',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
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
              // === ตัวช่วยที่อยู่ ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ตัวช่วยที่อยู่', style: TextStyle(fontSize: 16)),
                  InkWell(
                    onTap: _openMapPicker,
                    child: const Text('เลือกจากแผนที่',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 15)),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 12),

              _buildTextField(_nameCtrl, 'ชื่อผู้รับ', TextInputType.name),
              const SizedBox(height: 10),
              _buildTextField(_phoneCtrl, 'เบอร์โทรศัพท์', TextInputType.phone),
              const SizedBox(height: 10),
              _buildTextField(_locationCtrl, 'โปรดเลือกตำแหน่ง', TextInputType.text, readOnly: true),
              const SizedBox(height: 10),
              _buildTextField(_descCtrl, 'ระบุที่อยู่ผู้รับ', TextInputType.multiline, maxLines: 3),
              const SizedBox(height: 20),

              // รูปแนบสถานะ [1]
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _selectedImage == null
                            ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('แนบรูป (สถานะ [1] รอไรเดอร์มารับ)'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: const [
                    Icon(Icons.check_circle, color: Colors.black),
                    SizedBox(width: 6),
                    Text('บันทึกข้อมูล', style: TextStyle(fontSize: 15)),
                  ]),
                  GestureDetector(
                    onTap: _clearForm,
                    child: const Text('ล้างข้อมูล', style: TextStyle(color: Colors.red, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Center(
                child: SizedBox(
                  width: 140, height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('สำเร็จ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    TextInputType type, {
    bool readOnly = false,
    int maxLines = 1,
  }) {
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
