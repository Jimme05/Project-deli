import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  /// อัปโหลดไฟล์รูปขึ้น Storage
  /// [path] เช่น "users/{uid}/profile.jpg"
  Future<String> uploadFile(File file, String path) async {
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();
    return url;
  }

  /// ลบไฟล์ (ถ้าต้องการ)
  Future<void> deleteFile(String path) async {
    final ref = _storage.ref().child(path);
    await ref.delete();
  }
}
