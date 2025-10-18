
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'bottom_nav.dart';

class DeliveryHomePage extends StatelessWidget {
  const DeliveryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF5BA16C);
    final pageBg = const Color(0xFFE5E3E3);

    return Scaffold(
      backgroundColor: pageBg,
      bottomNavigationBar: const BottomNav(currentIndex: 0),
      appBar: AppBar(
        backgroundColor: green,
        title: const Text(
          "รายการออเดอร์ทั้งหมด (Admin)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีออเดอร์ในระบบ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            );
          }

          final docs = snap.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final m = docs[i].data();
              return _orderCard(m, docs[i].id);
            },
          );
        },
      ),
    );
  }

  // ---------- UI helpers ----------

  Widget _orderCard(Map<String, dynamic> m, String id) {
    final name = (m['Name'] ?? '-').toString();
    final sender = (m['Uid_sender'] ?? '-').toString();
    final receiver = (m['Uid_receiver'] ?? '-').toString();
    final addr = (m['delivery_address']?['addressText'] ?? '-').toString();
    final created = _formatDate(m['created_at']);
    final status = (m['Status_order'] ?? 0) as int;
    final statusChip = _statusChip(status);
    final statusImg = (m['img_status_1'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หัว
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping_rounded, size: 36, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.isEmpty ? "ไม่ระบุชื่อพัสดุ" : name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              statusChip,
            ],
          ),
          const SizedBox(height: 10),

          // รายละเอียด
          _labelValue('รหัสออเดอร์', id),
          _labelValue('ผู้ส่ง', sender),
          _labelValue('ผู้รับ', receiver),
          _labelValue('วันที่สร้าง', created),
          _labelValue('ที่อยู่จัดส่ง', addr),

          if (statusImg != null && statusImg.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                statusImg,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // TODO: ไปหน้า track รายละเอียด
                },
                icon: const Icon(Icons.assistant_direction),
                label: const Text('รายละเอียด'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(int s) {
    String text;
    Color bg;
    switch (s) {
      case 1:
        text = 'รอไรเดอร์';
        bg = Colors.orange.shade200;
        break;
      case 2:
        text = 'กำลังมารับ';
        bg = Colors.blue.shade200;
        break;
      case 3:
        text = 'กำลังไปส่ง';
        bg = Colors.indigo.shade200;
        break;
      case 4:
        text = 'ส่งแล้ว';
        bg = Colors.green.shade300;
        break;
      default:
        text = 'ไม่ทราบสถานะ';
        bg = Colors.grey.shade300;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${_two(d.day)}/${_two(d.month)}/${d.year + 543}";
    }
    return "-";
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
