import 'dart:io';
import 'package:flutter/material.dart';

class ImagePickBox extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const ImagePickBox({super.key, required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120, height: 110,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (file == null) const Icon(Icons.add_a_photo_rounded, size: 28)
          else ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(file!, width: 96, height: 68, fit: BoxFit.cover)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
