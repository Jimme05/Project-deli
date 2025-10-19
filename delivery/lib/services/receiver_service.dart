import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/address.dart';
import 'address_service.dart';

class ReceiverService {
  final _db = FirebaseFirestore.instance;
  final _addressService = AddressService();

  /// ค้นหาผู้รับจากเบอร์โทร — คืนค่า (uid, ชื่อ, รายชื่อที่อยู่)
  Future<ReceiverData?> findReceiverByPhone(String phone) async {
    if (phone.trim().isEmpty) return null;

    // หา user จากเบอร์
    final uq = await _db.collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (uq.docs.isEmpty) return null;

    final uid = uq.docs.first.id;
    final data = uq.docs.first.data();
    final name = (data['name'] ?? '').toString();

    // ดึง addresses ของผู้รับทั้งหมด
    final addresses = await _addressService.list(uid);

    return ReceiverData(uid: uid, name: name, addresses: addresses);
  }
}

/// Struct สำหรับเก็บข้อมูลผู้รับ
class ReceiverData {
  final String uid;
  final String name;
  final List<Address> addresses;
  ReceiverData({
    required this.uid,
    required this.name,
    required this.addresses,
  });
}
