import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;

import '../models/address.dart';
import '../models/order_create_request.dart';
import '../services/address_service.dart';
import '../services/order_service.dart';
import '../services/receiver_service.dart';
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

  LatLng? _picked;
  File? _selectedImage;
  final _picker = ImagePicker();
  bool _loading = false;

  final _addressService = AddressService();
  final _receiverService = ReceiverService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _openMapPicker() async {
    final initial = _picked ?? const LatLng(13.7563, 100.5018);

    // ⬇️ รับเป็น MapPickerResult ไม่ใช่ LatLng
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage(initial: initial)),
    );

    if (result != null) {
      setState(() {
        _picked = result.latlng;
        _locationCtrl.text =
            "${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}";

        // ถ้า MapPicker ส่ง address มาด้วย และช่องรายละเอียดว่างอยู่ — ใส่ให้เลย
        if ((result.address ?? '').isNotEmpty &&
            _descCtrl.text.trim().isEmpty) {
          _descCtrl.text = result.address!;
        }
      });
    }
  }

  Future<void> _chooseReceiverAddress() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกเบอร์ผู้รับก่อน')));
      return;
    }

    try {
      final receiver = await _receiverService.findReceiverByPhone(phone);
      if (receiver == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ไม่พบข้อมูลของเบอร์ $phone')));
        return;
      }
      if (receiver.addresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ผู้รับยังไม่มีที่อยู่บันทึกไว้')),
        );
        return;
      }

      final chosen = await showModalBottomSheet<Address>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: receiver.addresses.length,
          itemBuilder: (_, i) {
            final a = receiver.addresses[i];
            return ListTile(
              leading: Icon(
                a.isDefault ? Icons.star_rounded : Icons.place_rounded,
                color: a.isDefault ? Colors.amber : Colors.black54,
              ),
              title: Text(a.label),
              subtitle: Text(a.addressText),
              trailing: Text(
                '${a.latitude.toStringAsFixed(5)}, ${a.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.black54),
              ),
              onTap: () => Navigator.pop(context, a),
            );
          },
        ),
      );

      if (chosen != null) {
        setState(() {
          _picked = LatLng(chosen.latitude, chosen.longitude);
          _locationCtrl.text =
              "${chosen.latitude.toStringAsFixed(6)}, ${chosen.longitude.toStringAsFixed(6)}";
          _descCtrl.text = chosen.addressText;
          if (_nameCtrl.text.isEmpty && receiver.name.isNotEmpty) {
            _nameCtrl.text = receiver.name;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ดึงที่อยู่ผู้รับไม่สำเร็จ: $e')));
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
      final u = fa.FirebaseAuth.instance.currentUser;
      if (u == null) throw Exception("ยังไม่ได้ล็อกอิน");

      // pickup: default address ของผู้ส่ง
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
        id: addrSnap.docs.first.id,
        label: a['label'] ?? 'บ้าน',
        addressText: a['addressText'] ?? '',
        latitude: (a['Latitude'] as num).toDouble(),
        longitude: (a['Longitude'] as num).toDouble(),
      );

      // delivery: จากฟอร์ม/ที่เลือก
      final delivery = Address(
        id: '',
        label: "ปลายทาง",
        addressText: _descCtrl.text.trim(),
        latitude: _picked!.latitude,
        longitude: _picked!.longitude,
      );

      // หา UID ผู้รับจากเบอร์
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

      // ✅ แสดงข้อความและกลับไปหน้า Home
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade600,
          content: Text('✅ สร้างออเดอร์สำเร็จ (OID: $oid)'),
          duration: const Duration(seconds: 2),
        ),
      );

      _clearForm();

      // ✅ กลับหน้า Home หลังแสดง snackbar เล็กน้อย
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home', // 🏠 route ของหน้า Home
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⚠️ เกิดข้อผิดพลาด: $e')));
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

  // ----------------- UI -----------------
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
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 12),

              _buildTextField(_nameCtrl, 'ชื่อผู้รับ', TextInputType.name),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _phoneCtrl,
                      'เบอร์โทรศัพท์ผู้รับ',
                      TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _chooseReceiverAddress,
                    child: const Text('ใช้ที่อยู่ผู้รับจากเบอร์'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildTextField(
                _locationCtrl,
                'โปรดเลือกพิกัดปลายทาง',
                TextInputType.text,
                readOnly: true,
              ),
              const SizedBox(height: 10),

              _buildTextField(
                _descCtrl,
                'รายละเอียดที่อยู่ผู้รับ',
                TextInputType.multiline,
                maxLines: 3,
              ),

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
                            ? const Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'สำเร็จ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
