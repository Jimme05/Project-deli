import 'package:delivery/pages/bottom_nav.dart';
import 'package:flutter/material.dart';


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ ใช้ BottomNav ที่คุณสร้าง
      bottomNavigationBar: const BottomNav(currentIndex: 1),

      body: SafeArea(
        child: Column(
          children: [
            // ======= แถบแท็บด้านบน =======
            Container(
              color: kGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ปุ่ม "รายการพัสดุที่จัดส่ง"
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? Colors.white
                              : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'รายการพัสดุที่จัดส่ง',
                          style: TextStyle(
                            color: _selectedTab == 0
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ปุ่ม "รายการพัสดุที่ได้รับ"
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? Colors.white
                              : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'รายการพัสดุที่ได้รับ',
                          style: TextStyle(
                            color: _selectedTab == 1
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
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
                          hintText: 'ค้นหาเลขพัสดุ',
                          border: InputBorder.none,
                        ),
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
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black87),
                          color: _selectedStatus == 0
                              ? Colors.black.withOpacity(0.05)
                              : Colors.white,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'อยู่ระหว่างจัดส่ง',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStatus = 1),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black87),
                          color: _selectedStatus == 1
                              ? Colors.black.withOpacity(0.05)
                              : Colors.white,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'จัดส่งสำเร็จ',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ======= เนื้อหา (ลิสต์พัสดุ) =======
            Expanded(
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Text(
                  _selectedTab == 0
                      ? 'ยังไม่มีพัสดุที่จัดส่ง'
                      : 'ยังไม่มีพัสดุที่ได้รับ',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
