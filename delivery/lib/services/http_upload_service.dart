// lib/services/http_upload_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class UploadResult {
  final String filename;
  final String? url;
  UploadResult({required this.filename, this.url});
}

class HttpUploadService {
  // ปรับให้แก้ได้ง่าย
  static const String _base = 'http://202.28.34.203:30000';
  static const String _uploadEndpoint = '$_base/upload';

  // สมมติไฟล์ static เปิดดูได้ที่ /uploads/<filename>
  // ถ้าเซิร์ฟเวอร์คุณเสิร์ฟคนละ path แค่แก้ค่านี้ให้ตรง
  static const String _publicPrefix = '$_base/upload/';

  Future<UploadResult> uploadFile(File file, {String? customName}) async {
    final req = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));
    final multipart = await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: customName ?? file.uri.pathSegments.last,
    );
    req.files.add(multipart);

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // พยายาม parse JSON ถ้าเป็น text/plain ก็กันพัง
      Map<String, dynamic>? json;
      try { json = jsonDecode(body) as Map<String, dynamic>; } catch (_) {}

      // รองรับหลายคีย์ที่อาจเจอ
      final filename =
          json?['filename'] ?? json?['name'] ?? customName ?? file.uri.pathSegments.last;

      // ถ้าได้ url/path มาก็ใช้เลย
      final url = json?['url'] ??
          json?['path'] ??
          // ถ้าไม่มี ให้สร้างเองจาก prefix + filename
          (_publicPrefix.isNotEmpty ? '$_publicPrefix$filename' : null);

      if (filename == null) {
        throw Exception('Upload ok but response has no filename. body=$body');
      }
      return UploadResult(filename: filename, url: url);
    }

    throw Exception('Upload failed ${res.statusCode}: $body');
  }
}
