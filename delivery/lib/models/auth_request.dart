import 'dart:io';

import 'package:delivery/models/address.dart';

class LoginRequest {
  final String phone;
  final String password;
  LoginRequest({required this.phone, required this.password});
}

class UserSignUpRequest {
  final String phone;
  final String password;
  final String name;
  final String? photoUrl;
  final Address primaryAddress;
  final File? profileFile;

  UserSignUpRequest({
    required this.phone,
    required this.password,
    required this.name,
    required this.primaryAddress,
    this.photoUrl,
    this.profileFile,
  });
}

class RiderSignUpRequest {
  final String phone;
  final String password;
  final String name;
  final String vehiclePlate;
  final File? profileFile;   // ✅ ส่งไฟล์ให้ service
  final File? vehicleFile;   // ✅ ส่งไฟล์ให้ service
  final String? profileUrl;  // (optional) ถ้ามีอยู่แล้ว
  final String? vehicleUrl;  // (optional)

  RiderSignUpRequest({
    required this.phone,
    required this.password,
    required this.name,
    required this.vehiclePlate,
    this.profileFile,
    this.vehicleFile,
    this.profileUrl,
    this.vehicleUrl,
  });
}