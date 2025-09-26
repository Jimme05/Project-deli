import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const BottomNav({super.key, this.currentIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: const Color(0xFF5BA16C), // เขียวท้องฟ้าตามภาพล่าง
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
