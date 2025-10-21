import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'bottom_nav.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  static const Color kGreen = Color(0xFF6AA56F);

  int _selectedTab = 0; // 0 = ฉันส่ง, 1 = ฉันได้รับ
  int _selectedStatus = 0; // 0 = กำลังขนส่ง (1..3), 1 = ส่งเสร็จ (4)
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const BottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            // ======= แถบแท็บ =======
            Container(
              color: kGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: _tabButton('📦 ฉันส่ง', _selectedTab == 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: _tabButton('📬 ฉันได้รับ', _selectedTab == 1),
                    ),
                  ),
                ],
              ),
            ),

            // ======= ช่องค้นหา =======
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.search, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'ค้นหา OID / ชื่อผู้รับ / เบอร์ผู้รับ',
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black45),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
            ),

            // ======= ปุ่มสถานะ =======
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStatus = 0),
                      child: _statusButton(
                        'อยู่ระหว่างจัดส่ง',
                        _selectedStatus == 0,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStatus = 1),
                      child: _statusButton(
                        'จัดส่งสำเร็จ',
                        _selectedStatus == 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(child: _buildParcelList()),
          ],
        ),
      ),
    );
  }

  /// โหลดข้อมูลตามแท็บ แล้วฟิลเตอร์สถานะ/ค้นหา & sort ฝั่ง client
  Widget _buildParcelList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบก่อนดูข้อมูล'));
    }

    final uid = user.uid;
    final field = _selectedTab == 0 ? 'Uid_sender' : 'Uid_receiver';

    final query = FirebaseFirestore.instance
        .collection('orders')
        .where(field, isEqualTo: uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawDocs = snap.data?.docs ?? [];
        if (rawDocs.isEmpty) {
          return Center(
            child: Text(
              _selectedTab == 0
                  ? 'ยังไม่มีพัสดุที่คุณส่ง'
                  : 'ยังไม่มีพัสดุที่คุณได้รับ',
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
          );
        }

        // ฟิลเตอร์สถานะ: 1..3 = กำลังขนส่ง, 4 = ส่งเสร็จ
        Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> list = rawDocs
            .where((d) {
              final s = _asStatusInt(d.data()['Status_order']);
              return _selectedStatus == 0 ? (s >= 1 && s <= 3) : (s == 4);
            });

        // ฟิลเตอร์ค้นหา (OID/ชื่อ/เบอร์)
        final q = _query.toLowerCase();
        if (q.isNotEmpty) {
          list = list.where((doc) {
            final m = doc.data();
            final name = (m['Name'] ?? '').toString().toLowerCase();
            final phone = (m['receiver_phone'] ?? '').toString().toLowerCase();
            final oid = (m['oid'] ?? doc.id).toString().toLowerCase();
            return name.contains(q) || phone.contains(q) || oid.contains(q);
          });
        }

        // จัดเรียงเวลาใหม่ก่อน (ถ้า created_at เป็น null ให้ไปท้าย)
        final docs = list.toList()
          ..sort((a, b) {
            final ta = a.data()['created_at'];
            final tb = b.data()['created_at'];
            final da = (ta is Timestamp)
                ? ta.toDate().millisecondsSinceEpoch
                : -1;
            final db = (tb is Timestamp)
                ? tb.toDate().millisecondsSinceEpoch
                : -1;
            return db.compareTo(da);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('ไม่พบพัสดุตามเงื่อนไข/สถานะ'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final id = docs[i].id;
            return InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/order_detail', arguments: id);
              },
              child: _parcelCard(data, id),
            );
          },
        );
      },
    );
  }

  /// การ์ดพัสดุ (จุดรับดึงจากผู้ส่ง)
  Widget _parcelCard(Map<String, dynamic> data, String id) {
    final name = data['Name'] ?? '-';
    final phone = data['receiver_phone'] ?? '-';
    final addr =
        data['delivery_address']?['addressText'] ?? 'ไม่พบที่อยู่ผู้รับ';
    final desc = data['description'] ?? '';
    final img = data['img_status_1'] ?? '';
    final status = _asStatusInt(data['Status_order']);
    final createdAt = _formatDate(data['created_at']);
    final senderUid = data['Uid_sender'] ?? data['senderUid'];

    // ✅ ดึงที่อยู่ของผู้ส่งจาก Firestore
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(senderUid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get(),
      builder: (context, snap) {
        String pickupText = 'กำลังโหลด...';
        if (snap.connectionState == ConnectionState.done) {
          if (snap.hasData && snap.data!.docs.isNotEmpty) {
            pickupText =
                snap.data!.docs.first.data()['addressText'] ??
                'ไม่พบที่อยู่ผู้ส่ง';
          } else {
            pickupText = 'ไม่พบที่อยู่ผู้ส่ง';
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    size: 32,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _statusChip(status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "📞 เบอร์ผู้รับ: $phone",
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                "📦 วันที่สร้าง: $createdAt",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                "🚚 จุดรับของผู้ส่ง: $pickupText",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                "🏠 ที่อยู่จัดส่ง: $addr",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  "📝 หมายเหตุ: $desc",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
              if (img.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ======= ส่วน UI ย่อย =======
  Widget _statusChip(int status) {
    String text;
    Color color;
    switch (status) {
      case 1:
        text = 'รอไรเดอร์';
        color = Colors.orange;
        break;
      case 2:
        text = 'กำลังมารับ';
        color = Colors.blue;
        break;
      case 3:
        text = 'กำลังไปส่ง';
        color = Colors.indigo;
        break;
      case 4:
        text = 'ส่งสำเร็จ';
        color = Colors.green;
        break;
      default:
        text = 'ไม่ทราบ';
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusButton(String text, bool active) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87),
        color: active ? Colors.black.withOpacity(0.05) : Colors.white,
      ),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _tabButton(String text, bool active) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
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

  int _asStatusInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
