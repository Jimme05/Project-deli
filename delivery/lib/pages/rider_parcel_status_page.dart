import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/http_upload_service.dart';

class RiderParcelStatusPage extends StatefulWidget {
  final String orderId;
  final int
  currentStatus; // 1=รอไรเดอร์, 2=กำลังมารับ, 3=รับแล้วกำลังไปส่ง, 4=ส่งแล้ว

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
  StreamSubscription<Position>? _posSub;

  final List<String> _steps = ['กำลังมารับของ', 'กำลังไปส่ง', 'ส่งสินค้าแล้ว'];

  int _stepIndexFromStatus(int status) {
    final idx = status - 2;
    if (idx < 0) return 0;
    if (idx >= _steps.length) return _steps.length - 1;
    return idx;
  }

  Future<void> _openDirectionsTo(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เปิดแอปแผนที่ไม่สำเร็จ')));
    }
  }

  Future<void> _navigateByStatus(Map<String, dynamic> m, int status) async {
    if (status == 2) {
      final p = m['pickup_address'] as Map<String, dynamic>?;
      final lat = (p?['Latitude'] as num?)?.toDouble();
      final lng = (p?['Longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่พบพิกัดจุดรับของ')));
        return;
      }
      await _openDirectionsTo(lat, lng);
    } else if (status == 3) {
      final d = m['delivery_address'] as Map<String, dynamic>?;
      final lat = (d?['Latitude'] as num?)?.toDouble();
      final lng = (d?['Longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบพิกัดที่อยู่ผู้รับ')),
        );
        return;
      }
      await _openDirectionsTo(lat, lng);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('งานนี้เสร็จสิ้นหรือยังไม่พร้อมนำทาง')),
      );
    }
  }

  Future<void> _pickImageAndAdvance(int currentStatus) async {
    if (currentStatus >= 4) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _working = true);
    try {
      final file = File(picked.path);
      final up = await HttpUploadService().uploadFile(
        file,
        customName: "order_${widget.orderId}_s${currentStatus + 1}.jpg",
      );

      final nextStatus = currentStatus + 1;
      final imgField = nextStatus == 3 ? 'img_status_3' : 'img_status_4';
      final nameField = nextStatus == 3
          ? 'img_status_3_name'
          : 'img_status_4_name';

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
        SnackBar(
          content: Text(
            'อัปเดตสถานะเป็น "${_steps[_stepIndexFromStatus(nextStatus)]}" สำเร็จ',
          ),
        ),
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

  Future<void> _completeJob() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _working = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
            'Status_order': 4,
            'job_done': true,
            'completed_at': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance.collection('riders').doc(uid).set({
        'Status-rider': 'idle',
        'current_order_id': FieldValue.delete(),
        'latitude': FieldValue.delete(),
        'longitude': FieldValue.delete(),
        'last_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _posSub?.cancel();
      _posSub = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 งานนี้เสร็จสิ้นแล้ว และคุณกลับไปสถานะ “ว่าง”'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ปิดงานไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId);

    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'สถานะพัสดุ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          final jobDone = (m['job_done'] ?? false) as bool;

          final img1 = (m['img_status_1'] ?? '') as String?;
          final img3 = (m['img_status_3'] ?? '') as String?;
          final img4 = (m['img_status_4'] ?? '') as String?;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepper(stepIndex),
                    const SizedBox(height: 12),
                    if (status == 2) _riderPickupBanner(),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _infoRow('สถานะปัจจุบัน', _steps[stepIndex]),
                    _infoRow('ผู้รับ', (m['Name'] ?? '-').toString()),
                    _infoRow(
                      'เบอร์ผู้รับ',
                      (m['receiver_phone'] ?? '-').toString(),
                    ),
                    _infoRow(
                      'ที่อยู่ปลายทาง',
                      (m['delivery_address']?['addressText'] ?? '-').toString(),
                    ),
                    _infoRow(
                      'รับงานจากผู้ส่ง',
                      (m['pickup_address']?['addressText'] ?? '-').toString(),
                    ),
                    _infoRow('สร้างเมื่อ', _formatDate(m['created_at'])),
                    const SizedBox(height: 16),
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
                    if (jobDone)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🎉 งานนี้จัดส่งเสร็จสิ้นแล้ว',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isDelivered)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(
                              color: Colors.black.withOpacity(0.4),
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.navigation_rounded),
                          label: Text(
                            status == 2
                                ? 'นำทางไปจุดรับของ'
                                : 'นำทางไปที่อยู่ผู้รับ',
                          ),
                          onPressed: () => _navigateByStatus(m, status),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: jobDone
                              ? Colors.grey.shade500
                              : (isDelivered ? Colors.red.shade600 : kGreen),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          jobDone
                              ? Icons.lock_rounded
                              : (isDelivered
                                    ? Icons.flag_rounded
                                    : Icons.add_a_photo),
                        ),
                        label: Text(
                          jobDone
                              ? 'งานนี้เสร็จสิ้นแล้ว (กดไม่ได้)'
                              : (isDelivered
                                    ? 'จบงาน และกลับไปว่าง'
                                    : (status == 2
                                          ? 'อัปเดตเป็นสถานะ [3] แนบรูป'
                                          : 'อัปเดตเป็นสถานะ [4] แนบรูป')),
                        ),
                        onPressed: _working || jobDone
                            ? null
                            : (isDelivered
                                  ? _completeJob
                                  : () => _pickImageAndAdvance(status)),
                      ),
                    ),
                  ],
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

  Widget _stepper(int activeIndex) {
    final icons = <IconData>[
      Icons.directions_bike_rounded,
      Icons.local_shipping_rounded,
      Icons.check_circle_rounded,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_steps.length, (i) {
        final on = i <= activeIndex;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? Colors.green : Colors.white,
                border: Border.all(
                  color: on ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: Icon(
                icons[i],
                size: 24,
                color: on ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 100,
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

  Widget _riderPickupBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_bike_rounded,
            size: 48,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ไรเดอร์กำลังไปรับของจากผู้ส่ง โปรดรอสักครู่…',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: '$k: ',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: v,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
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
