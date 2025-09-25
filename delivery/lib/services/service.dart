import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/address.dart';
import '../models/auth_request.dart';
import '../models/auth_response.dart';

class SimpleAuthService {
  final _db = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();

  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<bool> _phoneExists(String phone) async {
    final qs = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
    return qs.docs.isNotEmpty;
  }

  // ---------- USER ----------
  Future<AuthResult> signUpUser(UserSignUpRequest req) async {
    try {
      if (await _phoneExists(req.phone)) {
        return AuthResult(success: false, message: 'เบอร์นี้ถูกใช้ไปแล้ว');
      }
      final userDoc = _db.collection('users').doc(); // auto id
      final userData = {
        'phone': req.phone,
        'passwordHash': _hash(req.password),
        'name': req.name,
        'role': 'user',
        'photoUrl': req.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      batch.set(userDoc, userData);
      final addrRef = userDoc.collection('addresses').doc();
      batch.set(addrRef, {'Uaid': addrRef.id, ...req.primaryAddress.toMap()});
      await batch.commit();

      final user = UserResponse.fromFirestore(userDoc.id, userData);
      await _persistUser(user);
      return AuthResult(success: true, user: user);
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // ---------- RIDER ----------
  Future<AuthResult> signUpRider(RiderSignUpRequest req) async {
    try {
      if (await _phoneExists(req.phone)) {
        return AuthResult(success: false, message: 'เบอร์นี้ถูกใช้ไปแล้ว');
      }
      final userDoc = _db.collection('users').doc(); // uid
      final userData = {
        'phone': req.phone,
        'passwordHash': _hash(req.password),
        'name': req.name,
        'role': 'rider',
        'photoUrl': req.profileUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final riderDoc = _db.collection('riders').doc(userDoc.id);
      final riderData = {
        'Rid': userDoc.id,
        'Name': req.name,
        'img_profile': req.profileUrl,
        'phone': req.phone,
        'Vehicle_img': req.vehicleImgUrl,
        'vehicle_plate': req.vehiclePlate,
        'Status-rider': 'idle',
        'latitude': null,
        'longitude': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      batch.set(userDoc, userData);
      batch.set(riderDoc, riderData);
      await batch.commit();

      final user = UserResponse.fromFirestore(userDoc.id, userData);
      await _persistUser(user);
      return AuthResult(success: true, user: user);
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // ---------- LOGIN ----------
  Future<AuthResult> login(LoginRequest req) async {
    try {
      final qs = await _db
          .collection('users')
          .where('phone', isEqualTo: req.phone)
          .where('passwordHash', isEqualTo: _hash(req.password))
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        return AuthResult(success: false, message: 'เบอร์หรือรหัสผ่านไม่ถูกต้อง');
      }
      final doc = qs.docs.first;
      final user = UserResponse.fromFirestore(doc.id, doc.data());
      await _persistUser(user);
      return AuthResult(success: true, user: user);
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // ---------- Session ----------
  Future<void> logout() => _storage.deleteAll();

  Future<UserResponse?> currentUser() async {
    final uid = await _storage.read(key: 'uid');
    final phone = await _storage.read(key: 'phone');
    final name = await _storage.read(key: 'name');
    final role = await _storage.read(key: 'role');
    final photo = await _storage.read(key: 'photoUrl');
    if ([uid, phone, name, role].any((e) => e == null)) return null;
    return UserResponse(uid: uid!, phone: phone!, name: name!, role: role!, photoUrl: photo);
  }

  Future<void> _persistUser(UserResponse u) async {
    await _storage.write(key: 'uid', value: u.uid);
    await _storage.write(key: 'phone', value: u.phone);
    await _storage.write(key: 'name', value: u.name);
    await _storage.write(key: 'role', value: u.role);
    if (u.photoUrl != null) await _storage.write(key: 'photoUrl', value: u.photoUrl!);
  }
}
