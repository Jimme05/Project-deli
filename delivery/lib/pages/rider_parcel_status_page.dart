import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RiderParcelStatusPage extends StatefulWidget {
  const RiderParcelStatusPage({super.key});

  @override
  State<RiderParcelStatusPage> createState() => _RiderParcelStatusPageState();
}

class _RiderParcelStatusPageState extends State<RiderParcelStatusPage>
    with SingleTickerProviderStateMixin {
  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);

  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  int _currentStep = 0;

  final List<String> steps = [
    'กำลังจัดส่ง',
    'รอไรเดอร์รับของ',
    'กำลังเดินทางไปส่ง',
    'ส่งสินค้าแล้ว',
  ];

  // เก็บแชทรูปภาพ
  final List<File> _chatImages = [];

  Future<void> _pickImageAndUpdateStatus() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery, // แกเลอรี่
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _chatImages.add(_selectedImage!);
      });

      // เมื่อเลือกรูปแล้ว → อัปเดตสถานะ
      if (_currentStep < steps.length - 1) {
        setState(() {
          _currentStep++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปเดตสถานะเป็น "${steps[_currentStep]}" สำเร็จ!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'สถานะพัสดุ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ปุ่มล่าง: อัปเดตสถานะ (จะเปิดกล้อง/แกลเลอรี่)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGreen,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('อัปเดตสถานะด้วยรูปภาพ'),
        onPressed: _pickImageAndUpdateStatus,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ======= จุดสถานะ =======
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length, (index) {
                final isActive = index <= _currentStep;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.white,
                        border: Border.all(
                          color: isActive ? Colors.green : Colors.grey.shade400,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.check : Icons.circle_outlined,
                        color: isActive ? Colors.white : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 80,
                      child: Text(
                        steps[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          color: isActive ? Colors.black87 : Colors.black54,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 30),
            const Divider(height: 1, color: Colors.black38),
            const SizedBox(height: 20),

            // ======= แชทรูปภาพ =======
            if (_chatImages.isNotEmpty)
              Column(
                children: _chatImages.map((file) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.deepPurpleAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'อัปเดต: ${steps[_currentStep]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    file,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              const Text(
                'ยังไม่มีการอัปเดตรูปภาพ',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}
