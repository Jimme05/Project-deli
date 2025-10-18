import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UploadResult {
  final String url;
  final String filename;
  UploadResult({required this.url, required this.filename});
}

class HttpUploadService {
  static const String _baseUrl = "http://202.28.34.203:30000/upload";

  Future<UploadResult?> uploadFile(File file, {String? customName}) async {
    try {
      final uri = Uri.parse(_baseUrl);
      final request = http.MultipartRequest('POST', uri);

      // ตั้งชื่อไฟล์เองถ้าอยากให้ชื่อไม่ซ้ำ
      final filename = customName ??
          "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: filename));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = json.decode(resBody);

      if (response.statusCode == 200) {
        final url = data['url'] ?? data['path'] ?? '';
        return UploadResult(url: url, filename: filename);
      } else {
        print('Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}
