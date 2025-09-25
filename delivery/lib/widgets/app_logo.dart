import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(children: const [
      SizedBox(height: 8),
      Icon(Icons.pedal_bike_rounded, size: 64, color: Colors.white),
      SizedBox(height: 6),
      Text("DELIVERY", style: TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }
}
