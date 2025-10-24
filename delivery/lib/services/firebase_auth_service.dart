import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/address.dart';
import '../models/auth_request.dart';
import '../models/auth_response.dart';
import 'http_upload_service.dart';

class FirebaseAuthService {
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ------------- Session helpers -------------
  Future<UserResponse?> currentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final snap = await _db.collection('users').doc(u.uid).get();
    if (!snap.exists) {
      return UserResponse(uid: u.uid, phone: u.phoneNumber ?? '', name: u.displayName ?? '', role: 'user', photoUrl: u.photoURL);
    }
    return UserResponse.fromFirestore(u.uid, snap.data()!);
  }

  Future<void> logout() => _auth.signOut();

  // ------------- Email/Password -------------
    Future<AuthResult> signUpUserWithEmail({
    required String email,
    required UserSignUpRequest req,
  }) async {
    try {
      // 1) สมัครด้วย Email/Password
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: req.password,
      );
      final uid = cred.user!.uid;

      // 2) อัปโหลดรูปโปรไฟล์ไป HTTP (ถ้ามี)
      String? photoUrl, photoName;
      if (req.profileFile != null) {
        final up = await HttpUploadService()
            .uploadFile(req.profileFile!, customName: "user_${uid}_profile.jpg");
        photoUrl = up.url;
        photoName = up.filename;
      } else if (req.photoUrl != null) {
        photoUrl = req.photoUrl;
      }

      // 3) บันทึกโปรไฟล์ + ที่อยู่แรกใน Firestore
      final userRef = _db.collection('users').doc(uid);
      final addrRef = userRef.collection('addresses').doc();

      final userData = {
        'phone': req.phone.trim(),
        'email': email.trim(),
        'name': req.name,
        'role': 'user',
        'photoUrl': photoUrl,
        'photoName': photoName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final addrMap = {
        'Uaid': addrRef.id,
        'label': req.primaryAddress.label,
        'addressText': req.primaryAddress.addressText,
        'Latitude': req.primaryAddress.latitude,
        'Longitude': req.primaryAddress.longitude,
        'isDefault': true,
      };

      final batch = _db.batch();
      batch.set(userRef, userData);
      batch.set(addrRef, addrMap);
      await batch.commit();

      final user = UserResponse.fromFirestore(uid, userData);
      return AuthResult(success: true, user: user);
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }


 Future<AuthResult> signUpRiderWithEmail({
  required String email,
  required RiderSignUpRequest req,
}) async {
  try {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: req.password,
    );
    final uid = cred.user!.uid;

    String? profileUrl, profileName, vehicleUrl, vehicleName;
    if (req.profileFile != null) {
      final up = await HttpUploadService()
          .uploadFile(req.profileFile!, customName: "rider_${uid}_profile.jpg");
      profileUrl = up.url; profileName = up.filename;
    } else if (req.profileUrl != null) {
      profileUrl = req.profileUrl;
    }

    if (req.vehicleFile != null) {
      final up = await HttpUploadService()
          .uploadFile(req.vehicleFile!, customName: "rider_${uid}_vehicle.jpg");
      vehicleUrl = up.url; vehicleName = up.filename;
    } else if (req.vehicleUrl != null) {
      vehicleUrl = req.vehicleUrl;
    }

    final userData = {
      'phone': req.phone.trim(),
      'name': req.name,
      'role': 'rider',
      'photoUrl': profileUrl,
      'photoName': profileName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final riderData = {
      'Rid': uid,
      'Name': req.name,
      'email': email.trim(),
      'img_profile': profileUrl,
      'img_profile_name': profileName,
      'phone': req.phone.trim(),
      'Vehicle_img': vehicleUrl,
      'Vehicle_img_name': vehicleName,
      'vehicle_plate': req.vehiclePlate,
      'Status-rider': 'idle',
      'role': 'rider',
      'latitude': null,
      'longitude': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(_db.collection('users').doc(uid), userData);
    batch.set(_db.collection('riders').doc(uid), riderData);
    await batch.commit();

    final user = UserResponse.fromFirestore(uid, userData);
    return AuthResult(success: true, user: user);
  } catch (e) {
    return AuthResult(success: false, message: e.toString());
  }
}



  Future<AuthResult> loginWithEmail({required String email, required String password}) async {
  try {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    final u = cred.user!;
    final snap = await _db.collection('users').doc(u.uid).get();
    if (!snap.exists) {
      await _db.collection('users').doc(u.uid).set({'role': 'user'}, SetOptions(merge: true));
    }
    final profile = await currentUser();
    return AuthResult(success: true, user: profile);
  } on fa.FirebaseAuthException catch (e) {
    String msg;
    switch (e.code) {
      case 'user-not-found':   msg = 'ไม่พบบัญชีอีเมลนี้'; break;
      case 'wrong-password':   msg = 'รหัสผ่านไม่ถูกต้อง'; break;
      case 'invalid-credential': msg = 'ข้อมูลล็อกอินไม่ถูกต้อง/หมดอายุ กรุณาลองใหม่'; break;
      case 'invalid-email':    msg = 'รูปแบบอีเมลไม่ถูกต้อง'; break;
      case 'user-disabled':    msg = 'บัญชีนี้ถูกปิดการใช้งาน'; break;
      default:                 msg = e.message ?? 'เกิดข้อผิดพลาด (${e.code})';
    }
    return AuthResult(success: false, message: msg);
  } catch (e) {
    return AuthResult(success: false, message: e.toString());
  }
}


  // ------------- Phone (OTP) -------------
  String? _verificationId;

  Future<AuthResult> startPhoneSignIn(String phoneE164) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164, // รูปแบบ +66xxxxxxxxx
        verificationCompleted: (fa.PhoneAuthCredential cred) async {
          // Android auto-retrieval อาจยืนยันให้เอง
          final res = await _auth.signInWithCredential(cred);
          if (res.user == null) throw Exception('signInWithCredential failed');
        },
        verificationFailed: (fa.FirebaseAuthException e) {
          throw Exception(e.message ?? 'verificationFailed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
      return AuthResult(success: true, message: 'ส่งรหัสแล้ว');
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  Future<AuthResult> confirmOtpAndEnsureProfile({
    required String smsCode,
    required String roleIfNew,   // 'user' | 'rider'
    File? profileFile,           // อัปโหลดถ้าเป็นการสมัครครั้งแรก
    String? nameIfNew,
    Address? defaultAddressIfUser, // ถ้า role=user และสมัครใหม่
    String? vehiclePlateIfRider,
    File? vehicleFileIfRider,
  }) async {
    try {
      if (_verificationId == null) {
        throw Exception('ยังไม่ได้ขอรหัส OTP');
      }
      final cred = fa.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final res = await _auth.signInWithCredential(cred);
      final uid = res.user!.uid;

      // มีโปรไฟล์อยู่แล้วหรือยัง?
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final profile = UserResponse.fromFirestore(uid, userDoc.data()!);
        return AuthResult(success: true, user: profile);
      }

      // สมัครใหม่ (ครั้งแรกหลังยืนยันเบอร์)
      String? photoUrl, photoName, vehicleUrl, vehicleName;
      if (profileFile != null) {
        final up = await HttpUploadService()
            .uploadFile(profileFile, customName: "${roleIfNew}_${uid}_profile.jpg");
        photoUrl = up.url; photoName = up.filename;
      }
      if (roleIfNew == 'rider' && vehicleFileIfRider != null) {
        final up = await HttpUploadService()
            .uploadFile(vehicleFileIfRider, customName: "rider_${uid}_vehicle.jpg");
        vehicleUrl = up.url; vehicleName = up.filename;
      }

      final data = {
        'phone': res.user!.phoneNumber ?? '',
        'name': nameIfNew ?? '',
        'role': roleIfNew,
        'photoUrl': photoUrl,
        'photoName': photoName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      final userRef = _db.collection('users').doc(uid);
      batch.set(userRef, data);

      if (roleIfNew == 'user' && defaultAddressIfUser != null) {
        final addrRef = userRef.collection('addresses').doc();
        batch.set(addrRef, {
          'Uaid': addrRef.id,
          'label': defaultAddressIfUser.label,
          'addressText': defaultAddressIfUser.addressText,
          'Latitude': defaultAddressIfUser.latitude,
          'Longitude': defaultAddressIfUser.longitude,
          'isDefault': true,
        });
      }

      if (roleIfNew == 'rider') {
        final riderRef = _db.collection('riders').doc(uid);
        batch.set(riderRef, {
          'Rid': uid,
          'Name': nameIfNew ?? '',
          'img_profile': photoUrl,
          'img_profile_name': photoName,
          'phone': res.user!.phoneNumber ?? '',
          'Vehicle_img': vehicleUrl,
          'Vehicle_img_name': vehicleName,
          'vehicle_plate': vehiclePlateIfRider ?? '',
          'Status-rider': 'idle',
          'latitude': null,
          'longitude': null,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      final profile = await currentUser();
      return AuthResult(success: true, user: profile);
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }
}
