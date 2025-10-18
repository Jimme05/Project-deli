import 'package:flutter/material.dart';
import 'package:delivery/pages/bottom_nav.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageGrey,
      bottomNavigationBar: const BottomNav(currentIndex: 2), // 📱 ปุ่มคนสีดำ
      body: Column(
        children: [
          // ===== ส่วนหัวโปรไฟล์ =====
          Container(
            color: kGreen,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white54,
                  child: Icon(Icons.person, size: 60, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'ชื่อของผู้ใช้',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '0123456789',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ===== ปุ่มแก้ไขที่อยู่ =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 28,
                ),
                title: const Text(
                  'แก้ไขที่อยู่ของฉัน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  // TODO: เปิดหน้าแก้ไขที่อยู่
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เปิดหน้าแก้ไขที่อยู่')),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ===== ปุ่มออกจากระบบ =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ออกจากระบบเรียบร้อย')),
                  );
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
