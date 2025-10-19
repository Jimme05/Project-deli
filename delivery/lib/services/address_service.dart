
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/address.dart';

class AddressService {
  final _db = FirebaseFirestore.instance;

  Future<List<Address>> list(String uid) async {
    final snap = await _db
        .collection('users').doc(uid)
        .collection('addresses')
        .orderBy('isDefault', descending: true)
        .get();

    return snap.docs
        .map((d) => Address.fromMap(d.id, d.data()))
        .toList();
  }

  Future<Address?> getDefault(String uid) async {
    final snap = await _db
        .collection('users').doc(uid)
        .collection('addresses')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Address.fromMap(d.id, d.data());
  }

  Future<String> add(String uid, Address a, {bool makeDefault = false}) async {
    final col = _db.collection('users').doc(uid).collection('addresses');
    final doc = col.doc();
    final batch = _db.batch();

    batch.set(doc, {
      'Uaid': doc.id,
      'label': a.label,
      'addressText': a.addressText,
      'Latitude': a.latitude,
      'Longitude': a.longitude,
      'isDefault': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (makeDefault) {
      final others = await col.where('isDefault', isEqualTo: true).get();
      for (final o in others.docs) {
        batch.update(o.reference, {'isDefault': false, 'updatedAt': FieldValue.serverTimestamp()});
      }
      batch.update(doc, {'isDefault': true});
    }

    await batch.commit();
    return doc.id;
  }

  Future<void> update(String uid, Address a) async {
    await _db.collection('users').doc(uid)
      .collection('addresses').doc(a.id).update({
        'label': a.label,
        'addressText': a.addressText,
        'Latitude': a.latitude,
        'Longitude': a.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  Future<void> delete(String uid, String addressId) async {
    await _db.collection('users').doc(uid)
      .collection('addresses').doc(addressId).delete();
  }

  Future<void> setDefault(String uid, String addressId) async {
    final col = _db.collection('users').doc(uid).collection('addresses');
    final cur = await col.get();
    final batch = _db.batch();
    for (final d in cur.docs) {
      batch.update(d.reference, {
        'isDefault': d.id == addressId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
