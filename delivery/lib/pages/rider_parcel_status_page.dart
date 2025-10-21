import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RiderParcelStatusPage extends StatefulWidget {
  final String orderId;
  final int currentStatus;

  const RiderParcelStatusPage({
    super.key,
    required this.orderId,
    required this.currentStatus,
  });

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
    'กำลังไปรับของ', // 1
    'กำลังไปส่ง', // 3
    'ส่งสินค้าแล้ว', // 4
  ];

  final List<File> _chatImages = [];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.currentStatus - 1;
  }

  // 📸 เลือกรูปแล้วอัปเดตสถานะ
  Future<void> _pickImageAndUpdateStatus() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _chatImages.add(_selectedImage!);
      });

      final nextStep = (_currentStep + 1).clamp(0, steps.length - 1);
      final newStatus = nextStep + 1;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
            'Status_order': newStatus,
            'img_status_$newStatus': picked.path,
            'updated_at': FieldValue.serverTimestamp(),
          });

      setState(() {
        _currentStep = nextStep;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ อัปเดตสถานะเป็น "${steps[nextStep]}" สำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ✅ กดยืนยันจบงาน
  Future<void> _completeJob() async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
          'Status_order': 5,
          'job_done': true,
          'completed_at': FieldValue.serverTimestamp(),
        });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 งานนี้เสร็จสิ้นเรียบร้อยแล้ว!'),
        backgroundColor: Colors.green,
      ),
    );

    // กลับไปหน้าก่อนหน้า
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isJobCompleted = _currentStep >= 3; // index 3 = "ส่งสินค้าแล้ว"

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

      // 🟢 ปุ่มล่างเปลี่ยนตามสถานะ
      floatingActionButton: isJobCompleted
          ? FloatingActionButton.extended(
              backgroundColor: Colors.green.shade800,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('จบงาน (ส่งเสร็จแล้ว)'),
              onPressed: _completeJob,
            )
          : FloatingActionButton.extended(
              backgroundColor: kGreen,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('อัปเดตสถานะด้วยรูปภาพ'),
              onPressed: _pickImageAndUpdateStatus,
            ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 ขั้นตอนสถานะ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(steps.length, (index) {
                final isActive = index <= _currentStep;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.white,
                        border: Border.all(
                          color: isActive ? Colors.green : Colors.grey,
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
                          color: isActive
                              ? Colors.black87
                              : Colors.grey.shade600,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, color: Colors.black38),
            const SizedBox(height: 20),

            if (_chatImages.isNotEmpty)
              Column(
                children: _chatImages.map((file) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
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
