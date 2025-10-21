import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_create_request.dart';
import '../services/http_upload_service.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String> createOrder(OrderCreateRequest req) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ยังไม่ได้เข้าสู่ระบบ');
      }

      final uid = user.uid;
      print('🟢 Creating order by user: $uid');

      // 📦 ดึงที่อยู่ของผู้ใช้จาก Firestore
      final userSnap = await _db.collection('users').doc(uid).get();
      if (!userSnap.exists) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final addrSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (addrSnap.docs.isEmpty) {
        throw Exception('ไม่พบบ้าน/จุดรับของผู้ส่ง (โปรดเพิ่มที่อยู่ก่อน)');
      }
      final pickupAddr = addrSnap.docs.first.data();

      // ถ้าเก็บใน subcollection เช่น users/{uid}/addresses/{main}
      // ให้เปลี่ยนเป็นตัวนี้แทน
      /*
      final addrSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .limit(1)
          .get();

      if (addrSnap.docs.isEmpty) {
        throw Exception('ไม่พบบ้าน/จุดรับของผู้ส่ง (โปรดเพิ่มที่อยู่ก่อน)');
      }
      final pickupAddr = addrSnap.docs.first.data();
      */

      final orderRef = _db.collection('orders').doc();

      // 🔹 อัปโหลดรูป (ถ้ามี)
      String? imgUrl1;
      String? imgName1;
      final File? f1 = req.status1ImageFile;
      if (f1 != null) {
        final up = await HttpUploadService().uploadFile(
          f1,
          customName: "order_${orderRef.id}_status1.jpg",
        );
        imgUrl1 = up.url;
        imgName1 = up.filename;
      }

      // 🔸 สร้างข้อมูลออเดอร์ใหม่
      final data = {
        'oid': orderRef.id,
        'Uid_sender': uid,
        'Uid_receiver': req.receiverUid ?? '',
        'Name': req.receiverName,
        'receiver_phone': req.receiverPhone,
        'pickup_address': pickupAddr, // ✅ ดึงจาก user โดยตรง
        'delivery_address': {
          'label': req.deliveryAddress.label,
          'addressText': req.deliveryAddress.addressText,
          'Latitude': req.deliveryAddress.latitude,
          'Longitude': req.deliveryAddress.longitude,
        },
        'Status_order': 1, // รอไรเดอร์
        'created_at': FieldValue.serverTimestamp(),
        'description': req.description,
        'img_status_1': imgUrl1,
        'img_status_1_name': imgName1,
        'img_status_3': null,
        'img_status_4': null,
        'assignedRiderId': null,
      };

      await orderRef.set(data);
      print('✅ Order created successfully: ${orderRef.id}');
      return orderRef.id;
    } catch (e, st) {
      print('❌ ERROR createOrder: $e');
      print(st);
      rethrow;
    }
  }
}
