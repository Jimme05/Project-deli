import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/http_upload_service.dart'; // <- อัปโหลดรูปไป http://202.28.34.203:30000/upload

class RiderParcelStatusPage extends StatefulWidget {
  final String orderId;
  final int currentStatus; // 1=รอไรเดอร์, 2=กำลังมารับ, 3=รับแล้วกำลังไปส่ง, 4=ส่งแล้ว

  const RiderParcelStatusPage({
    super.key,
    required this.orderId,
    required this.currentStatus,
  });

  @override
  State<RiderParcelStatusPage> createState() => _RiderParcelStatusPageState();
}

class _RiderParcelStatusPageState extends State<RiderParcelStatusPage> {
  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);

  final ImagePicker _picker = ImagePicker();
  bool _working = false;

  /// ขั้นตอนสำหรับไรเดอร์ (เราเริ่มนับจากสถานะ 2)
  /// index 0 -> status 2, index 1 -> status 3, index 2 -> status 4
  final List<String> _steps = ['กำลังมารับของ', 'กำลังไปส่ง', 'ส่งสินค้าแล้ว'];

  int _stepIndexFromStatus(int status) {
    // 2 -> 0, 3 -> 1, 4 -> 2, ต่ำกว่า 2 ปัดขึ้นเป็น 0
    final idx = status - 2;
    if (idx < 0) return 0;
    if (idx >= _steps.length) return _steps.length - 1;
    return idx;
  }

  int _statusFromStepIndex(int idx) => idx + 2;

  /// อัปโหลดรูปและขยับสถานะ (2->3 / 3->4)
  Future<void> _pickImageAndAdvance(int currentStatus) async {
    // อนุญาตอัปโหลดเฉพาะจาก 2 ไป 3 (รูปเก็บที่ img_status_3) และ 3 ไป 4 (img_status_4)
    if (currentStatus >= 4) return;

    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _working = true);
    try {
      final file = File(picked.path);

      // อัปโหลดไป HTTP server ที่กำหนด
      final up = await HttpUploadService()
          .uploadFile(file, customName: "order_${widget.orderId}_s${currentStatus + 1}.jpg");

      final nextStatus = currentStatus + 1;
      final imgField =
          nextStatus == 3 ? 'img_status_3' : 'img_status_4'; // ตามสเปค
      final nameField =
          nextStatus == 3 ? 'img_status_3_name' : 'img_status_4_name';

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'Status_order': nextStatus,
        imgField: up.url,
        nameField: up.filename,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตสถานะเป็น "${_steps[_stepIndexFromStatus(nextStatus)]}" สำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดรูป/อัปเดตสถานะไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text('สถานะพัสดุ',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ใช้ StreamBuilder เพื่ออัปเดตแบบเรียลไทม์ (สถานะ/รูป)
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data!.data() ?? {};
          final status = (m['Status_order'] ?? widget.currentStatus) as int;
          final stepIndex = _stepIndexFromStatus(status);
          final isDelivered = status >= 4;

          final img1 = (m['img_status_1'] ?? '') as String?;
          final img3 = (m['img_status_3'] ?? '') as String?;
          final img4 = (m['img_status_4'] ?? '') as String?;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // แถบขั้นตอน
                    _stepper(stepIndex),

                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    const SizedBox(height: 16),
                    _infoRow('สถานะปัจจุบัน', _steps[stepIndex]),
                    _infoRow('ผู้รับ', (m['Name'] ?? '-').toString()),
                    _infoRow('เบอร์ผู้รับ',
                        (m['receiver_phone'] ?? '-').toString()),
                    _infoRow('ที่อยู่ปลายทาง',
                        (m['delivery_address']?['addressText'] ?? '-').toString()),
                    _infoRow('รับงานจากผู้ส่ง',
                        (m['pickup_address']?['addressText'] ?? '-').toString()),
                    _infoRow('สร้างเมื่อ', _formatDate(m['created_at'])),

                    const SizedBox(height: 16),

                    // รูปที่แนบในแต่ละสถานะ (ถ้ามี)
                    if ((img1 ?? '').isNotEmpty) ...[
                      const Text('รูปสถานะ [1] (ผู้ส่งแนบ):'),
                      const SizedBox(height: 8),
                      _netImage(img1!),
                      const SizedBox(height: 16),
                    ],
                    if ((img3 ?? '').isNotEmpty) ...[
                      const Text('รูปสถานะ [3] (ไรเดอร์รับของแล้ว):'),
                      const SizedBox(height: 8),
                      _netImage(img3!),
                      const SizedBox(height: 16),
                    ],
                    if ((img4 ?? '').isNotEmpty) ...[
                      const Text('รูปสถานะ [4] (ส่งสำเร็จ):'),
                      const SizedBox(height: 8),
                      _netImage(img4!),
                      const SizedBox(height: 16),
                    ],

                    if (isDelivered)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'งานนี้จัดส่งเสร็จสิ้นแล้ว',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ปุ่มล่าง (อัปเดตสถานะด้วยรูป)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDelivered ? Colors.grey : kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      isDelivered
                          ? Icons.check_circle_outline
                          : Icons.add_a_photo,
                    ),
                    label: Text(
                      isDelivered
                          ? 'ส่งสำเร็จแล้ว'
                          : (status == 2
                              ? 'อัปเดตเป็นสถานะ [3] แนบรูป'
                              : 'อัปเดตเป็นสถานะ [4] แนบรูป'),
                    ),
                    onPressed: (isDelivered || _working)
                        ? null
                        : () => _pickImageAndAdvance(status),
                  ),
                ),
              ),

              if (_working)
                Container(
                  color: Colors.black.withOpacity(0.15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- UI Helpers ----------------

  Widget _stepper(int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_steps.length, (i) {
        final on = i <= activeIndex;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? Colors.green : Colors.white,
                border: Border.all(color: on ? Colors.green : Colors.grey, width: 2),
              ),
              child: Icon(on ? Icons.check : Icons.circle_outlined,
                  size: 22, color: on ? Colors.white : Colors.grey),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 90,
              child: Text(
                _steps[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: on ? Colors.black87 : Colors.grey.shade600,
                  fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: '$k: ',
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 14),
          children: [
            TextSpan(
              text: v,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _netImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 180,
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Text('โหลดรูปไม่สำเร็จ'),
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';
    }
    return '-';
  }
}
