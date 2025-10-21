import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/pages/rider_parcel_status_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiderAcceptedOrdersPage extends StatelessWidget {
  const RiderAcceptedOrdersPage({super.key});

  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("กรุณาเข้าสู่ระบบก่อน")));
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('assignedRiderId', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        elevation: 0,
        title: const Text(
          "ออเดอร์ที่รับไว้แล้ว",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snap.data?.docs ?? [];
          debugPrint('🔥 Orders fetched: ${allDocs.length}');

          if (allDocs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีออเดอร์ที่คุณรับไว้",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            );
          }

          // 🟢 แยก "งานที่ยังไม่จบ" กับ "งานที่จบแล้ว"
          final unfinishedOrders = allDocs.where((d) {
            final s = d.data()['Status_order'] ?? 1;
            return s != 5; // ยังไม่จบ
          }).toList();

          final finishedOrders = allDocs.where((d) {
            final s = d.data()['Status_order'] ?? 1;
            return s == 5; // จบงานแล้ว
          }).toList();

          // รวมเข้าด้วยกัน (ให้จบแล้วไปอยู่ล่าง)
          final orderedList = [...unfinishedOrders, ...finishedOrders];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orderedList.length,
            itemBuilder: (context, i) {
              final doc = orderedList[i];
              final m = doc.data();
              final oid = doc.id;

              final receiver = (m['Name'] ?? '-').toString();
              final phone = (m['receiver_phone'] ?? '-').toString();
              final address = (m['delivery_address']?['addressText'] ?? '-')
                  .toString();
              final status = (m['Status_order'] ?? 1) as int;
              final created = _formatDate(m['created_at']);
              final isFinished = status == 5;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isFinished
                      ? Colors.grey.shade200
                      : Colors.white, // งานจบแล้วให้สีซีดลง
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📦 Order ID: $oid",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("ผู้รับ: $receiver"),
                    Text("เบอร์: $phone"),
                    Text("ที่อยู่: $address"),
                    Text("วันที่สร้าง: $created"),
                    const SizedBox(height: 8),
                    _statusChip(status),

                    const SizedBox(height: 12),

                    // 🟢 ถ้างานยังไม่จบ -> ปุ่มสีเขียว, ถ้างานจบแล้ว -> ปุ่มสีเทา
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFinished ? Colors.grey : kGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: Icon(
                          isFinished
                              ? Icons.check_circle_outline
                              : Icons.local_shipping_rounded,
                        ),
                        label: Text(
                          isFinished
                              ? "งานนี้เสร็จสิ้นแล้ว"
                              : "อัปเดตสถานะออเดอร์",
                          style: const TextStyle(fontSize: 15),
                        ),
                        onPressed: isFinished
                            ? null // ❌ กดไม่ได้ถ้างานจบแล้ว
                            : () {
                                debugPrint(
                                  '➡ ไปหน้าอัปเดตสถานะของออเดอร์ $oid',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RiderParcelStatusPage(
                                      orderId: oid,
                                      currentStatus: status,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 🟢 Widget แสดงสถานะออเดอร์
  Widget _statusChip(int s) {
    String text;
    Color color;
    switch (s) {
      case 1:
        text = 'รอไรเดอร์รับของ';
        color = Colors.orange;
        break;
      case 2:
        text = 'กำลังมารับของ';
        color = Colors.blue;
        break;
      case 3:
        text = 'กำลังไปส่ง';
        color = Colors.indigo;
        break;
      case 4:
        text = 'จัดส่งสำเร็จ';
        color = Colors.green;
        break;
      default:
        text = 'ไม่ทราบสถานะ';
        color = Colors.black45;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}";
    }
    return "-";
  }
}
