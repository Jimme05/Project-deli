// lib/services/http_upload_service.dart
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

  Future<UploadResult> uploadFile(File file, {String? customName}) async {
    final uri = Uri.parse(_baseUrl);
    final filename = customName ??
        "${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}";

    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: filename));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception("Upload failed ${streamed.statusCode}: $body");
    }

    // ปรับให้รองรับหลายรูปแบบ JSON ของ backend
    final data = json.decode(body);
    final url = (data['url'] ?? data['path'] ?? data['data']?['url'])?.toString();
    if (url == null || url.isEmpty) {
      throw Exception("Upload ok but no URL in response: $body");
    }
    return UploadResult(url: url, filename: filename);
  }
}
