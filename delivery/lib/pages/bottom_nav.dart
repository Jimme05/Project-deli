import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const BottomNav({super.key, this.currentIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0: // หน้า Home
            Navigator.pushNamed(context, '/home');
            break;
          case 1: // ✅ ปุ่มกลาง -> ไปหน้า delivery_page
            Navigator.pushNamed(context, '/delivery');
            break;
          case 2: // หน้าโปรไฟล์ไรเดอร์
            Navigator.pushNamed(context, '/profile');
            break;
        }
        if (onTap != null) onTap!(index);
      },
      backgroundColor: const Color(0xFF5BA16C),
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded, size: 28),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_rounded, size: 28),
          label: 'Parcel',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded, size: 28),
          label: 'Profile',
        ),
        
      ],
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    );
  }
}
