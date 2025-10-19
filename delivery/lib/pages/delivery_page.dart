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

  int _selectedTab = 0; // 0 = ส่ง, 1 = ได้รับ
  int _selectedStatus = 0; // 0 = อยู่ระหว่างจัดส่ง, 1 = จัดส่งสำเร็จ
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: _tabButton(
                        'รายการพัสดุที่จัดส่ง',
                        _selectedTab == 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: _tabButton(
                        'รายการพัสดุที่ได้รับ',
                        _selectedTab == 1,
                      ),
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
                          hintText: 'ค้นหาเลขพัสดุ / ชื่อผู้รับ / เบอร์โทร',
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
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

  // ✅ โหลดข้อมูลพัสดุจาก Firestore (เฉพาะของที่เราส่ง)
  Widget _buildParcelList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบก่อนดูข้อมูล'));
    }

    final uid = user.uid;

    // ดึงเฉพาะออเดอร์ที่เราส่ง
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('orders')
        .where('Uid_sender', isEqualTo: uid);

    // แยกสถานะ (อยู่ระหว่างจัดส่ง / ส่งสำเร็จ)
    if (_selectedStatus == 0) {
      query = query.where('Status_order', isLessThan: 4);
    } else {
      query = query.where('Status_order', isEqualTo: 4);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy('created_at', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'ยังไม่มีพัสดุที่คุณส่ง',
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
          );
        }

        // 🔎 ฟิลเตอร์การค้นหา
        final docs = snap.data!.docs.where((doc) {
          if (_query.isEmpty) return true;
          final data = doc.data();
          final q = _query.toLowerCase();
          return (data['Name'] ?? '').toString().toLowerCase().contains(q) ||
              (data['oid'] ?? '').toString().toLowerCase().contains(q) ||
              (data['receiver_phone'] ?? '').toString().toLowerCase().contains(
                q,
              );
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('ไม่พบพัสดุตามคำค้นหา'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            return _parcelCard(data);
          },
        );
      },
    );
  }

  // ✅ การ์ดพัสดุให้ตรงกับ OrderService
  Widget _parcelCard(Map<String, dynamic> data) {
    final name = data['Name'] ?? '-';
    final phone = data['receiver_phone'] ?? '-';
    final addr =
        data['delivery_address']?['addressText'] ?? 'ไม่พบที่อยู่ผู้รับ';
    final pickup = data['pickup_address']?['addressText'] ?? 'ไม่พบจุดรับ';
    final desc = data['description'] ?? '';
    final img = data['img_status_1'] ?? '';
    final status = (data['Status_order'] ?? 0) as int;
    final createdAt = _formatDate(data['created_at']);

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
              const Icon(Icons.local_shipping, size: 32, color: Colors.green),
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
          Text("📞 เบอร์ผู้รับ: $phone", style: const TextStyle(fontSize: 13)),
          Text(
            "📦 วันที่ส่ง: $createdAt",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Text(
            "🚚 จุดรับของผู้ส่ง: $pickup",
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
          if (img.isNotEmpty) ...[
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
  }

  // ======= UI ส่วนย่อย =======
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
}
