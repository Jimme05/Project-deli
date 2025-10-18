import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/address.dart';

class AddressService {
  final _db = FirebaseFirestore.instance;

  /// ดึงที่อยู่ต้นทาง (isDefault == true) ของ user ตาม uid
  Future<Address?> getDefaultPickupAddress(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final a = snap.docs.first.data();
      return Address(
        label: a['label'] ?? 'บ้าน',
        addressText: a['addressText'] ?? '',
        latitude: (a['Latitude'] as num).toDouble(),
        longitude: (a['Longitude'] as num).toDouble(),
      );
    } catch (e) {
      print('⚠️ AddressService.getDefaultPickupAddress error: $e');
      return null;
    }
  }
}
