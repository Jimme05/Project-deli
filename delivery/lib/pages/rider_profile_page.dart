import 'package:flutter/material.dart';

class RiderProfilePage extends StatelessWidget {
  const RiderProfilePage({super.key});

  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);
  static const Color kPrimaryBlue = Color(0xFF2D7BF0);

  @override
  Widget build(BuildContext context) {
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
          'profile Rider',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // โปรไฟล์ไรเดอร์
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.account_circle_rounded,
                    size: 56,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ชื่อไรเดอร์\nเบอร์ : 0123456789\nทะเบียนรถ : กด 234',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'รายการ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // การ์ดออเดอร์
            Container(
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
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แถวผู้ส่ง
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFEDE7F6),
                        child: Icon(Icons.person, color: Colors.black87),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: 'ผู้ส่ง : ',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: 'ทิวย์\n'),
                              TextSpan(
                                text: 'เบอร์ : ',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: '0999999999'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Colors.black54),

                  const SizedBox(height: 10),

                  // ผู้รับ + ที่อยู่
                  const Text(
                    'ผู้รับ : เฟิร์ส',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ที่อยู่ : ที่อยู่ : มหาสารคาม ตำบลขามเฒ่า กันทรวิชัย 45170',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ปุ่มรับออเดอร์
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
                        elevation: 0,
                      ),
                      onPressed: () {
                        // TODO: ใส่ลอจิกรับออเดอร์ที่นี่
                      },
                      child: const Text(
                        'รับออเดอร์',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
