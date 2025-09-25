import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Icon(Icons.pedal_bike_rounded, size: 64, color: Colors.white),
      const SizedBox(height: 8),
      const Text('DELIVERY', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('สะดวกทันใจ ส่งไวถึงที่',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
    ]);
  }
}
