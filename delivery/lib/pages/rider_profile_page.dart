import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/pages/rider_accepted_orders_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiderProfilePage extends StatefulWidget {
  const RiderProfilePage({super.key});

  @override
  State<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends State<RiderProfilePage> {
  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);
  static const Color kPrimaryBlue = Color(0xFF2D7BF0);

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ออกจากระบบเรียบร้อย'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e')),
      );
    }
  }

  /// 🟢 รับออเดอร์ — อัปเดต Firestore ให้มี assignedRiderId + สถานะใหม่
  Future<void> _acceptOrder(String orderId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('orders').doc(orderId).update({
        'assignedRiderId': uid,
        'Status_order': 2, // เปลี่ยนสถานะเป็น "กำลังมารับของ"
        'accepted_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ รับออเดอร์สำเร็จ')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ รับออเดอร์ไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('กรุณาเข้าสู่ระบบก่อน')));
    }

    final riderProfileFuture = _db.collection('users').doc(uid).get();

    // 🔹 ดึงออเดอร์ทั้งหมดที่ยังไม่มี assignedRiderId (คือยังรอไรเดอร์)
    final waitingOrdersStream = _db
        .collection('orders')
        .where('Status_order', isEqualTo: 1)
        .where('assignedRiderId', isNull: true)
        .snapshots();

    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Rider',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // 🔴 ปุ่มออกจากระบบ
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text(
              'ออกจากระบบ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: riderProfileFuture,
          builder: (context, riderSnap) {
            if (riderSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final riderData = riderSnap.data?.data() ?? {};
            final name = (riderData['name'] ?? 'ชื่อไรเดอร์').toString();
            final phone = (riderData['phone'] ?? 'ไม่ระบุเบอร์').toString();
            final license =
                (riderData['license'] ??
                        riderData['vehiclePlate'] ??
                        'ไม่ระบุทะเบียน')
                    .toString();
            final photoUrl =
                (riderData['photoUrl'] ??
                        'https://cdn-icons-png.flaticon.com/512/147/147142.png')
                    .toString();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: waitingOrdersStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allOrders = snap.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // ==== โปรไฟล์ส่วนบน ====
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(photoUrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$name\nเบอร์ : $phone\nทะเบียนรถ : $license',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 🔹 ปุ่มดูออเดอร์ที่รับแล้ว
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RiderAcceptedOrdersPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_turned_in_rounded),
                        label: const Text("ดูออเดอร์ที่รับแล้ว"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'รายการออเดอร์ทั้งหมด (รอไรเดอร์)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (allOrders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            'ยังไม่มีออเดอร์รอรับในตอนนี้',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      ...allOrders.map((doc) {
                        final data = doc.data();
                        final oid = doc.id;
                        final receiver = (data['Name'] ?? '-').toString();
                        final phone = (data['receiver_phone'] ?? '-')
                            .toString();
                        final addr =
                            (data['delivery_address']?['addressText'] ?? '-')
                                .toString();
                        final created = _formatDate(data['created_at']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
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
                              const SizedBox(height: 4),
                              Text("ผู้รับ: $receiver"),
                              Text("เบอร์: $phone"),
                              Text("ที่อยู่: $addr"),
                              Text("วันที่สร้าง: $created"),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: () => _acceptOrder(oid),
                                  child: const Text(
                                    "รับออเดอร์นี้",
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
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
