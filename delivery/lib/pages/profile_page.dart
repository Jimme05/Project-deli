import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:delivery/pages/bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? name;
  String? phone;
  String? photoUrl;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          name = "ไม่พบผู้ใช้";
          phone = "-";
          _loading = false;
        });
        return;
      }

      final uid = user.uid;
      final snap = await _db.collection('users').doc(uid).get();

      if (snap.exists) {
        final data = snap.data()!;
        setState(() {
          name = data['name'] ?? 'ไม่ระบุชื่อ';
          phone = data['phone'] ?? '-';
          photoUrl = data['photoUrl'];
          _loading = false;
        });
      } else {
        // ถ้าไม่มีใน users ลองเช็ก collection riders
        final riderSnap = await _db.collection('riders').doc(uid).get();
        if (riderSnap.exists) {
          final data = riderSnap.data()!;
          setState(() {
            name = data['name'] ?? 'ไม่ระบุชื่อ';
            phone = data['phone'] ?? '-';
            photoUrl = data['profileUrl'];
            _loading = false;
          });
        } else {
          setState(() {
            name = "ไม่พบข้อมูลในระบบ";
            phone = "-";
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Load profile error: $e');
      setState(() {
        name = "โหลดข้อมูลผิดพลาด";
        phone = "-";
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ออกจากระบบเรียบร้อย')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageGrey,
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ===== ส่วนหัวโปรไฟล์ =====
                Container(
                  color: kGreen,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white54,
                        backgroundImage:
                            (photoUrl != null && photoUrl!.isNotEmpty)
                            ? NetworkImage(photoUrl!)
                            : null,
                        child: (photoUrl == null || photoUrl!.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name ?? 'ชื่อของผู้ใช้',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        phone ?? 'เบอร์โทร',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/editaddresss');
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
                      onPressed: _logout,
                      child: const Text(
                        'ออกจากระบบ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
