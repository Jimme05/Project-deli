import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/address.dart';
import '../models/auth_request.dart';
import '../models/auth_response.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SimpleAuthService {
  final _db = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();

  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<bool> _phoneExists(String phone) async {
    final qs = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
    return qs.docs.isNotEmpty;
  }

  // ---------- USER ----------

// helper แยกอัปโหลด
Future<String?> _uploadUserProfile(String uid, File? file) async {
  if (file == null) return null;
  final path = 'users/$uid/profile.jpg';            // <— path คงที่
  final ref  = FirebaseStorage.instance.ref(path);  // ใช้ ref(path) หรือ ref().child(path) ก็ได้

  try {
    final meta = SettableMetadata(contentType: 'image/jpeg');
    final task = await ref.putFile(file, meta);
    final url  = await task.ref.getDownloadURL();
    // debug
    // ignore: avoid_print
    print('[storage] uploaded -> $path');
    return url;
  } on FirebaseException catch (e) {
    // ignore: avoid_print
    print('[storage] upload failed ($path): ${e.code}  ${e.message}');
    rethrow;
  }
}

Future<AuthResult> signUpUser(UserSignUpRequest req) async {
  try {
    if (await _phoneExists(req.phone)) {
      return AuthResult(success: false, message: 'เบอร์นี้ถูกใช้ไปแล้ว');
    }

    // สร้าง doc ก่อนเพื่อได้ uid ไปทำ path storage
    final userDoc = _db.collection('users').doc();   // auto id (uid)

    // อัปโหลดรูป (ถ้ามีไฟล์) -> ได้ URL
    //  await _uploadUserProfile(userDoc.id, req.profileFile ?? null);
    final photoUrl = null;
    // เขียน Firestore
    final userData = {
      'phone': req.phone,
      'passwordHash': _hash(req.password),
      'name': req.name,
      'role': 'user',
      'photoUrl': photoUrl,                       // <— URL ที่ได้จริง
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

      final riderDoc = _db.collection('riders').doc();
      final riderData = {
        'Rider_id': riderDoc.id,
        'Name': req.name,
        'passwordHash': _hash(req.password),
        'img_profile': req.profileUrl,
        'phone': req.phone,
        'role': 'rider',
        'Vehicle_img': req.vehicleImgUrl,
        'vehicle_plate': req.vehiclePlate,
        'Status-rider': 'idle',
        'latitude': null,
        'longitude': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      batch.set(riderDoc, riderData);
      await batch.commit();

      final user = UserResponse.fromFirestore(riderDoc.id, riderData);
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
  Future<AuthResult> loginRider(LoginRequest req) async {
    try {
      final qs = await _db
          .collection('riders')
          .where('phone', isEqualTo: req.phone)
          .where('passwordHash', isEqualTo: _hash(req.password))
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        return AuthResult(success: false, message: 'เบอร์หรือรหัสผ่านไม่ถูกต้อง');
      }
      final doc = qs.docs.first;
      final riders = UserResponse.fromFirestore(doc.id, doc.data());
      await _persistUser(riders);
      return AuthResult(success: true, user: riders);
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
