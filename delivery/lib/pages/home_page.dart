import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'bottom_nav.dart';
import '../services/service.dart'; // SimpleAuthService

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

      body: SafeArea(
        child: FutureBuilder(
          future: SimpleAuthService().currentUser(),
          builder: (context, snapUser) {
            if (snapUser.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapUser.hasData || snapUser.data == null) {
              return _emptyState(
                green,
                title: 'ยังไม่ได้เข้าสู่ระบบ',
                subtitle: 'กรุณาเข้าสู่ระบบก่อนเพื่อดูออเดอร์ของคุณ',
                action: () => Navigator.pushReplacementNamed(context, '/'),
              );
            }

            final me = snapUser.data!;
            final query = FirebaseFirestore.instance
                .collection('orders')
                .where('Uid_sender', isEqualTo: me.uid)
                .orderBy('created_at', descending: true);

            return Column(
              children: [
                // ====== Header สีเขียว + โลโก้ ======
                Container(
                  width: double.infinity,
                  height: 112,
                  color: green,
                  alignment: Alignment.center,
                  child: Image.asset('assets/images/logo.png', height: 100, fit: BoxFit.contain),
                ),

                // ====== เนื้อหา ======
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
                          subtitle: 'กดปุ่ม + ด้านล่างขวาเพื่อสร้างออเดอร์แรกของคุณ',
                        );
                      }

                      // ค้นหาในฝั่ง client จากข้อความในช่อง search
                      final docs = snap.data!.docs.where((d) {
                        if (_q.isEmpty) return true;
                        final m = d.data();
                        final name = (m['Name'] ?? '').toString().toLowerCase();
                        final phone = (m['receiver_phone'] ?? '').toString().toLowerCase();
                        final addr = (m['delivery_address']?['addressText'] ?? '').toString().toLowerCase();
                        final oid = (m['oid'] ?? d.id).toString().toLowerCase();
                        final q = _q.toLowerCase();
                        return name.contains(q) || phone.contains(q) || addr.contains(q) || oid.contains(q);
                      }).toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _searchBox(),
                            const SizedBox(height: 18),
                            ...docs.map((doc) => _orderCard(doc.data(), doc.id)).toList(),
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

  // ---------- UI helpers ----------

  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
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
              onPressed: () { _searchCtrl.clear(); setState(() => _q = ''); },
            ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> m, String id) {
    final title = (m['item_name'] ?? 'ชื่อพัสดุที่ส่ง').toString(); // ถ้าไม่มี field ใช้ชื่อดีฟอลต์
    final recvName = (m['Name'] ?? '-').toString();
    final addr = (m['delivery_address']?['addressText'] ?? '-').toString();
    final status = (m['Status_order'] ?? 1) as int;
    final dt = m['created_at'];
    final created = _formatDate(dt);
    final statusChip = _statusChip(status);
    final status1Img = (m['img_status_1'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หัว
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/box.png', width: 46, height: 46, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              statusChip,
            ],
          ),
          const SizedBox(height: 10),

          // รายละเอียด 3 ช่อง
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _labelValue('ชื่อผู้รับ :', recvName)),
              Expanded(child: _labelValue('วันที่สร้าง :', created)),
              Expanded(child: _labelValue('OID :', (m['oid'] ?? id).toString())),
            ],
          ),
          const SizedBox(height: 10),

          // ที่อยู่
          Text('ที่อยู่ : $addr', style: const TextStyle(fontSize: 14)),

          // รูปสถานะ [1] (ถ้ามี)
          if (status1Img != null && status1Img.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(status1Img, height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          ],

          const SizedBox(height: 8),

          // ปุ่มดูรายละเอียด/ติดตาม
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // TODO: ไปหน้า Track/รายละเอียดออเดอร์
                  // Navigator.pushNamed(context, '/order_detail', arguments: id);
                },
                icon: const Icon(Icons.assistant_direction),
                label: const Text('ติดตาม'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return RichText(
      text: TextSpan(
        text: '$label ',
        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
        children: [
          TextSpan(text: value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _statusChip(int s) {
    String text;
    Color bg;
    switch (s) {
      case 1: text = 'รอไรเดอร์'; bg = Colors.orange.shade200; break;
      case 2: text = 'ไรเดอร์กำลังมา'; bg = Colors.blue.shade200; break;
      case 3: text = 'กำลังไปส่ง'; bg = Colors.indigo.shade200; break;
      case 4: text = 'ส่งแล้ว'; bg = Colors.green.shade300; break;
      default: text = 'ไม่ทราบสถานะ'; bg = Colors.grey.shade300;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${_two(d.day)}/${_two(d.month)}/${d.year + 543}"; // พ.ศ.
    }
    return '-';
    }
  String _two(int n) => n.toString().padLeft(2, '0');

  Widget _emptyState(Color green, {required String title, String? subtitle, VoidCallback? action}) {
    return Column(
      children: [
       
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: 10),
                ElevatedButton(onPressed: action, child: const Text('ไปหน้าเข้าสู่ระบบ')),
              ]
            ]),
          ),
        ),
      ],
    );
  }
}
