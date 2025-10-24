import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 เพิ่ม
import 'package:flutter/material.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final oid = ModalRoute.of(context)!.settings.arguments as String;
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(oid);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          "📦 รายละเอียดออเดอร์",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF6AA56F),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('❌ ไม่พบออเดอร์นี้'));
          }

          final m = snap.data!.data()!;
          final status = _asStatusInt(m['Status_order']);

          final pickup = m['pickup_address'] as Map<String, dynamic>?;
          final delivery = m['delivery_address'] as Map<String, dynamic>?;

          // รวมรูปทุกสถานะ
          final imageList = _allImages(m);

          // ใครกำลังดูอยู่?
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final uidSender = (m['Uid_sender'] ?? m['senderUid'])?.toString();
          final uidReceiver = (m['Uid_receiver'] ?? m['receiverUid'])?.toString();

          final isViewerReceiver = currentUid != null && currentUid == uidReceiver;
          final isViewerSender  = currentUid != null && currentUid == uidSender;

          // เตรียม label + ข้อมูลคนอีกฝั่ง
          final counterpartLabel = isViewerReceiver ? 'ผู้ส่ง' : 'ผู้รับ';

          // ถ้าคนดูเป็น "ผู้ส่ง" → ใช้ข้อมูลผู้รับจากออเดอร์โดยตรง
          if (isViewerSender || !isViewerReceiver) {
            final header = _OrderHeader(
              personLabel: counterpartLabel,            // ผู้รับ
              name: (m['Name'] ?? '-').toString(),
              phone: (m['receiver_phone'] ?? '-').toString(),
              status: status,
              pickupText: pickup?['addressText'] ?? '-',
              deliveryText: delivery?['addressText'] ?? '-',
              createdAt: m['created_at'],
              images: imageList,
            );
            return header;
          }

          // ถ้าคนดูเป็น "ผู้รับ" → ต้องดึงข้อมูลผู้ส่งจาก users/{Uid_sender}
          if (uidSender == null || uidSender.isEmpty) {
            // ไม่มี uid ผู้ส่งในเอกสาร ก็ fallback เป็นเดิม
            final header = _OrderHeader(
              personLabel: counterpartLabel,
              name: (m['sender_name'] ?? '-').toString(),
              phone: (m['sender_phone'] ?? '-').toString(),
              status: status,
              pickupText: pickup?['addressText'] ?? '-',
              deliveryText: delivery?['addressText'] ?? '-',
              createdAt: m['created_at'],
              images: imageList,
            );
            return header;
          }

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').doc(uidSender).get(),
            builder: (context, uSnap) {
              String senderName = (m['sender_name'] ?? '').toString();
              String senderPhone = (m['sender_phone'] ?? '').toString();

              if (uSnap.hasData && uSnap.data!.exists) {
                final u = uSnap.data!.data()!;
                if (senderName.isEmpty) {
                  senderName = (u['name'] ?? '').toString();
                }
                if (senderPhone.isEmpty) {
                  senderPhone = (u['phone'] ?? '').toString();
                }
              }

              return _OrderHeader(
                personLabel: counterpartLabel,      // ผู้ส่ง
                name: senderName.isEmpty ? '-' : senderName,
                phone: senderPhone.isEmpty ? '-' : senderPhone,
                status: status,
                pickupText: pickup?['addressText'] ?? '-',
                deliveryText: delivery?['addressText'] ?? '-',
                createdAt: m['created_at'],
                images: imageList,
              );
            },
          );
        },
      ),
    );
  }

  /// รวมรูปทุกสถานะ 1→4
  static List<Map<String, dynamic>> _allImages(Map<String, dynamic> m) {
    final list = <Map<String, dynamic>>[];
    void addImg(String? url, int s) {
      if (url != null && url.isNotEmpty) list.add({'url': url, 'status': s});
    }
    addImg(m['img_status_1'], 1);
    addImg(m['img_status_2'], 2);
    addImg(m['img_status_3'], 3);
    addImg(m['img_status_4'], 4);
    return list;
  }

  static int _asStatusInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

// ---------------- Header ----------------

class _OrderHeader extends StatelessWidget {
  final String personLabel; // <- 'ผู้ส่ง' หรือ 'ผู้รับ' ตามผู้ที่เข้าดู
  final String name;
  final String phone;
  final int status;
  final String pickupText;
  final String deliveryText;
  final dynamic createdAt;
  final List<Map<String, dynamic>> images;

  const _OrderHeader({
    required this.personLabel,
    required this.name,
    required this.phone,
    required this.status,
    required this.pickupText,
    required this.deliveryText,
    required this.createdAt,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF6AA56F),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'รายละเอียดออเดอร์',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),

            // แสดงข้อมูลของ "อีกฝั่ง" ตามบทบาทผู้ที่เข้าดู
            _kv('ชื่อ$personLabel', name),
            _kv('เบอร์$personLabel', phone),

            _kv('สถานะ', _statusText(status)),
            _kv('วันที่สร้าง', _dateStr(createdAt)),
            const Divider(height: 24, thickness: 1.1),

            const Text("📍 เส้นทางการจัดส่ง", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _locationCard(
              Icons.store_mall_directory_rounded,
              'จุดรับสินค้า',
              pickupText,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _locationCard(
              Icons.location_on_rounded,
              'ที่อยู่ผู้รับ',
              deliveryText,
              Colors.redAccent,
            ),

            if (images.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("📷 ภาพสินค้าขณะจัดส่ง (อัปเดตเรียลไทม์)",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Column(
                children: images.map((img) {
                  final s = img['status'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${_statusText(s)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _statusColor(s),
                            )),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            img['url'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _statusColor(int s) {
    switch (s) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.indigo;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static Widget _locationCard(
    IconData icon,
    String title,
    String desc,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title\n$desc',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateStr(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            text: '$k: ',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(
                text: v,
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      );

  static String _statusText(int s) {
    switch (s) {
      case 1:
        return 'รอไรเดอร์';
      case 2:
        return 'ไรเดอร์กำลังมารับ';
      case 3:
        return 'กำลังไปส่ง';
      case 4:
        return 'ส่งสำเร็จ';
      default:
        return 'ไม่ทราบ';
    }
  }

  static Widget _statusChip(int s) {
    final c = _statusColor(s);
    final t = _statusText(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
