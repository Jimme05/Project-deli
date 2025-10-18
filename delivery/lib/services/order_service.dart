import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_create_request.dart';
import '../services/http_upload_service.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// สร้างออเดอร์ใหม่
  Future<String> createOrder(OrderCreateRequest req) async {
    try {
      // ✅ ดึง UID จาก Firebase Auth
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ยังไม่ได้เข้าสู่ระบบ');
      }

      final senderUid = user.uid;
      print('🟢 Creating order by UID: $senderUid');

      // สร้างเอกสารใหม่
      final orderRef = _db.collection('orders').doc();
      print('📦 New order ID: ${orderRef.id}');

      // === อัปโหลดรูป (ถ้ามี) ===
      String? imgUrl1;
      String? imgName1;

      final File? f1 = req.status1ImageFile;
      if (f1 != null) {
        final up = await HttpUploadService()
            .uploadFile(f1, customName: "order_${orderRef.id}_status1.jpg");

        imgUrl1 = up.url;
        imgName1 = up.filename;
        print('✅ Uploaded image: $imgName1');
      }

      // === เตรียมข้อมูล ===
      final data = {
        'oid': orderRef.id,
        'rid': null, // รอไรเดอร์
        'Name': req.receiverName,
        'pickup_address': {
          'label': req.pickupAddress.label,
          'addressText': req.pickupAddress.addressText,
          'Latitude': req.pickupAddress.latitude,
          'Longitude': req.pickupAddress.longitude,
        },
        'delivery_address': {
          'label': req.deliveryAddress.label,
          'addressText': req.deliveryAddress.addressText,
          'Latitude': req.deliveryAddress.latitude,
          'Longitude': req.deliveryAddress.longitude,
        },
        'Status_order': 1, // [1] รอไรเดอร์
        'created_at': FieldValue.serverTimestamp(),
        'Uid_sender': senderUid, // ✅ ดึงจาก Firebase Auth
        'Uid_receiver': req.receiverUid ?? '',
        'receiver_phone': req.receiverPhone,
        'description': req.description,
        'img_status_1': imgUrl1,
        'img_status_1_name': imgName1,
        'img_status_3': null,
        'img_status_4': null,
        'assignedRiderId': null,
      };

      await orderRef.set(data);
      print('🔥 Order created successfully');
      return orderRef.id;
    } catch (e, st) {
      print('❌ ERROR createOrder: $e');
      print(st);
      rethrow;
    }
  }
}
