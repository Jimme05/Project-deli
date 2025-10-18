import 'dart:io';
import '../models/address.dart';

class OrderCreateRequest {
  final String senderUid;           // uid ผู้ส่ง (ปัจจุบันล็อกอิน)
  final String receiverUid;         // uid ผู้รับ (หาได้จากเบอร์)
  final String receiverPhone;       // เผื่อผู้รับยังไม่มี uid
  final String? receiverName;       // แสดงผลในรายการ
  final Address pickupAddress;      // ที่อยู่/พิกัดรับ
  final Address deliveryAddress;    // ที่อยู่/พิกัดส่ง
  final String? description;        // คำอธิบาย
  final File? status1ImageFile;     // รูปแนบสถานะ [1]

  OrderCreateRequest({
    required this.senderUid,
    required this.receiverUid,
    required this.receiverPhone,
    this.receiverName,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.description,
    this.status1ImageFile,
  });
}
