import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  static const Color kGreen = Color(0xFF6AA56F);
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _locationCtrl.clear();
    _descCtrl.clear();
    setState(() => _selectedImage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'เพิ่มที่อยู่ผู้รับใหม่',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === ตัวช่วยที่อยู่ ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('ตัวช่วยที่อยู่', style: TextStyle(fontSize: 16)),
                  Text(
                    'เลือกจากแผนที่',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 12),

              // === ช่องกรอกข้อมูล ===
              _buildTextField(_nameCtrl, 'ชื่อผู้รับ', TextInputType.name),
              const SizedBox(height: 10),
              _buildTextField(_phoneCtrl, 'เบอร์โทรศัพท์', TextInputType.phone),
              const SizedBox(height: 10),
              _buildTextField(
                _locationCtrl,
                'โปรดเลือกตำแหน่ง',
                TextInputType.text,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _descCtrl,
                'ระบุที่อยู่ผู้รับ',
                TextInputType.multiline,
              ),
              const SizedBox(height: 20),

              // === ปุ่มเลือกรูป ===
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _selectedImage == null
                            ? const Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'เลือกรูปจากมือถือ / แกลเลอรี่',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // === ปุ่มบันทึก / ล้าง ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.black),
                      SizedBox(width: 6),
                      Text('บันทึกข้อมูล', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _clearForm,
                    child: const Text(
                      'ล้างข้อมูล',
                      style: TextStyle(color: Colors.red, fontSize: 15),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // === ปุ่มสำเร็จ ===
              Center(
                child: SizedBox(
                  width: 120,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('บันทึกสำเร็จ')),
                      );
                    },
                    child: const Text(
                      'สำเร็จ',
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
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    TextInputType type,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      enableSuggestions: true,
      autocorrect: true,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade300,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
