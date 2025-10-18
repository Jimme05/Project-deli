import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UploadResult {
  final String url;
  final String filename;
  UploadResult({required this.url, required this.filename});
}

class HttpUploadService {
  // ← ชี้ไปเซิร์ฟเวอร์ของคุณ
  static const String _endpoint = "http://202.28.34.203:30000/upload";

  Future<UploadResult> uploadFile(File file, {String? customName}) async {
    final uri = Uri.parse(_endpoint);
    final name = customName ??
        "${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}";

    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: name));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception("Upload failed: ${res.statusCode} $body");
    }
    final jsonBody = json.decode(body);
    // รองรับทั้ง {url: "..."} หรือ {path: "..."}
    final url = (jsonBody['url'] ?? jsonBody['path'])?.toString();
    if (url == null || url.isEmpty) {
      throw Exception("Upload ok but no url/path in response: $body");
    }
    return UploadResult(url: url, filename: name);
  }
}
