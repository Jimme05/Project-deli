import 'package:flutter/material.dart';
import 'bottom_nav.dart';

class DeliveryHomePage extends StatelessWidget {
  const DeliveryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF5BA16C); // สีหัวบน/ล่างใกล้ภาพ
    final pageBg = const Color(0xFFE5E3E3); // เทาพื้นหลัง

    return Scaffold(
      backgroundColor: pageBg,
      // ปุ่ม + ชมพู มุมขวาล่าง
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE9C6F2), // ชมพูอ่อนแบบการ์ด
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
        child: IconButton(
          icon: const Icon(Icons.add, size: 32, color: Colors.black87),
          onPressed: () {},
        ),
      ),
      // แถบล่าง แยกไฟล์แล้ว
      bottomNavigationBar: const BottomNav(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            // ====== หัวสีเขียว + โลโก้ ======
            Container(
              width: double.infinity,
              height: 112,
              color: green,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/logo.png', // ใส่โลโก้ของคุณ
                height: 100,
                fit: BoxFit.contain,
              ),
            ),

            // ====== ส่วนเนื้อหา ======
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ช่องค้นหาโค้ง
                    Container(
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
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Colors.black45),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ตรวจสอบสถานะพัสดุ',
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // การ์ดพัสดุ
                    Container(
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
                          // แถวไอคอนกล่อง + หัวข้อ
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ไอคอนกล่อง
                              Image.asset(
                                'assets/images/box.png', // ใส่ภาพกล่องของคุณ
                                width: 46,
                                height: 46,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'ชื่อพัสดุที่ส่ง',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 3 คอลัมน์: ชื่อผู้รับ | วันที่จัดส่ง | สถานะ
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _labelValue('ชื่อผู้รับ :', 'ทิวย์'),
                              ),
                              Expanded(
                                child: _labelValue(
                                  'วันที่จัดส่ง :',
                                  '26/09/2568',
                                ),
                              ),
                              Expanded(
                                child: _labelValue('สถานะ :', 'กำลังจัดส่ง'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ที่อยู่
                          const Text(
                            'ที่อยู่ : มหาสารคาม ตำบลขามเฒ่า กันทรวิชัย 45170',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // helper แสดง label: value ในบรรทัดเดียว
  Widget _labelValue(String label, String value) {
    return RichText(
      text: TextSpan(
        text: '$label ',
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
}
