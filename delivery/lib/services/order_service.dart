import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_create_request.dart';
import '../services/http_upload_service.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  Future<String> createOrder(OrderCreateRequest req) async {
    final orderRef = _db.collection('orders').doc(); // oid

    String? imgUrl1;
    String? imgName1;
    final File? f1 = req.status1ImageFile;
    if (f1 != null) {
      final up = await HttpUploadService()
          .uploadFile(f1, customName: "order_${orderRef.id}_status1.jpg");
      imgUrl1 = up.url;
      imgName1 = up.filename;
    }

    final data = {
      'oid': orderRef.id,
      'rid': null,                        // ยังไม่มีไรเดอร์
      'Name': req.receiverName,           // ชื่อผู้รับ (โชว์ในลิสต์)
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
      'Status_order': 1,                  // [1] รอไรเดอร์
      'created_at': FieldValue.serverTimestamp(),
      'Uid_sender': req.senderUid,
      'Uid_receiver': req.receiverUid,
      'receiver_phone': req.receiverPhone,
      'description': req.description,
      'img_status_1': imgUrl1,            // URL รูปสถานะ [1]
      'img_status_1_name': imgName1,      // ชื่อไฟล์
      'img_status_3': null,
      'img_status_4': null,
      'assignedRiderId': null,
    };

    await orderRef.set(data);
    return orderRef.id;
  }
}
