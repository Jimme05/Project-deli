import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'bottom_nav.dart';

class DeliveryHomePage extends StatefulWidget {
  const DeliveryHomePage({super.key});

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF5BA16C);
    final pageBg = const Color(0xFFE5E3E3);

    return Scaffold(
      backgroundColor: pageBg,
      floatingActionButton: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/add_address'),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE9C6F2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          width: 64,
          height: 64,
          child: const Icon(Icons.add, size: 32, color: Colors.black87),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),

      // 🔥 ฟัง Auth state เพื่อให้แน่ใจว่ามี uid ก่อน query
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapAuth) {
            if (snapAuth.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = snapAuth.data;
            if (user == null) {
              return _emptyState(
                green,
                title: 'ยังไม่ได้เข้าสู่ระบบ',
                subtitle: 'กรุณาเข้าสู่ระบบก่อนเพื่อดูออเดอร์ของคุณ',
                action: () => Navigator.pushReplacementNamed(context, '/'),
              );
            }

            final uid = user.uid;

            // ✅ query ด้วย uid ของ Firebase
            final query = FirebaseFirestore.instance
                .collection('orders')
                .where('Uid_sender', isEqualTo: uid);

            return Column(
              children: [
                // ====== Header ======
                Container(
                  width: double.infinity,
                  height: 112,
                  color: green,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),

                // ====== รายการออเดอร์ ======
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return _emptyState(
                          green,
                          title: 'ยังไม่มีออเดอร์',
                          subtitle:
                              'กดปุ่ม + ด้านล่างขวาเพื่อสร้างออเดอร์แรกของคุณ ',
                        );
                      }

                      // ✅ กรองออเดอร์ที่ยังไม่เสร็จ (Status_order != 4)
                      final docs = snap.data!.docs.where((d) {
                        final m = d.data();
                        final status = (m['Status_order'] ?? 1) as int;
                        if (status == 4)
                          return false; // ซ่อนออเดอร์ที่เสร็จสิ้นแล้ว

                        if (_q.isEmpty) return true;
                        final q = _q.toLowerCase();
                        return (m['Name'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(q) ||
                            (m['receiver_phone'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(q) ||
                            (m['delivery_address']?['addressText'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(q) ||
                            (m['oid'] ?? d.id)
                                .toString()
                                .toLowerCase()
                                .contains(q);
                      }).toList();

                      if (docs.isEmpty) {
                        return _emptyState(
                          green,
                          title: 'ไม่มีออเดอร์ที่ยังไม่เสร็จสิ้น',
                          subtitle: 'ออเดอร์ที่ส่งแล้วจะถูกซ่อนไว้อัตโนมัติ',
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _searchBox(),
                            const SizedBox(height: 18),
                            ...docs.map((d) => _orderCard(d.data(), d.id)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🔎 ช่องค้นหา
  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 44,
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ค้นหาออเดอร์ (ชื่อผู้รับ / เบอร์ / ที่อยู่ / OID)',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black45),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _q = '');
              },
            ),
        ],
      ),
    );
  }

  // 📦 แสดงออเดอร์แต่ละรายการ
  Widget _orderCard(Map<String, dynamic> m, String id) {
    final name = (m['Name'] ?? '-').toString();
    final addr = (m['delivery_address']?['addressText'] ?? '-').toString();
    final created = _formatDate(m['created_at']);
    final status = (m['Status_order'] ?? 1) as int;
    final img = (m['img_status_1'] ?? '') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/box.png',
                width: 46,
                height: 46,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 10),
          _labelValue('วันที่สร้าง', created),
          _labelValue('ที่อยู่จัดส่ง', addr),
          if (img.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  img,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${_two(d.day)}/${_two(d.month)}/${d.year + 543}";
    }
    return '-';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Widget _emptyState(
    Color green, {
    required String title,
    String? subtitle,
    VoidCallback? action,
  }) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center),
                ],
                if (action != null) ...[
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: action,
                    child: const Text('ไปหน้าเข้าสู่ระบบ'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
