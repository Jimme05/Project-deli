import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// ผลลัพธ์ที่จะส่งกลับไปหน้าก่อนหน้า
class MapPickerResult {
  final LatLng latlng;
  final String? address;
  MapPickerResult({required this.latlng, this.address});
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key, this.initial});

  /// จุดเริ่มต้นของแผนที่ (ถ้าไม่ส่งมา จะไปที่ กทม.)
  final LatLng? initial;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  static const _defaultCenter = LatLng(13.7563, 100.5018); // กทม.
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  LatLng _pos = _defaultCenter;    // ตำแหน่งหมุด
  String? _address;                // ข้อความที่อยู่ (reverse / search)
  bool _locating = false;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _pos = widget.initial ?? _defaultCenter;
    // ลอง reverse geocode จุดตั้งต้นสั้น ๆ (ไม่บังคับ)
    _reverseGeocode(_pos);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- Geocoding helpers (Nominatim) ----------

  /// forward geocode: จากข้อความ → latlng
  Future<void> _searchByText(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _geocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(q)}'
        '&format=json&addressdetails=1&limit=1'
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'deli-app/1.0 (edu example)'
      });
      if (res.statusCode == 200) {
        final arr = jsonDecode(res.body) as List;
        if (arr.isNotEmpty) {
          final m = arr.first as Map<String, dynamic>;
          final lat = double.tryParse(m['lat']?.toString() ?? '');
          final lon = double.tryParse(m['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final ll = LatLng(lat, lon);
            setState(() {
              _pos = ll;
              _address = m['display_name']?.toString();
            });
            _mapController.move(ll, 16);
          }
        } else {
          _snack('ไม่พบผลลัพธ์ที่อยู่ "$q"');
        }
      } else {
        _snack('ค้นหาที่อยู่ไม่สำเร็จ (${res.statusCode})');
      }
    } catch (e) {
      _snack('ค้นหาที่อยู่ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  /// reverse geocode: จาก latlng → ข้อความที่อยู่
  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _geocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${p.latitude}&lon=${p.longitude}'
        '&format=json&addressdetails=1'
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'deli-app/1.0 (edu example)'
      });
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _address = m['display_name']?.toString());
      } else {
        _snack('ดึงที่อยู่ไม่สำเร็จ (${res.statusCode})');
      }
    } catch (e) {
      _snack('ดึงที่อยู่ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  // ---------- Current location ----------

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final p2 = await Geolocator.requestPermission();
        if (p2 == LocationPermission.denied || p2 == LocationPermission.deniedForever) {
          _snack('ไม่ได้รับสิทธิ์ตำแหน่ง');
          setState(() => _locating = false);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _pos = ll);
      _mapController.move(ll, 16);
      _reverseGeocode(ll);
    } catch (e) {
      _snack('อ่านตำแหน่งปัจจุบันไม่ได้: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------- UI ----------

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    setState(() => _pos = latlng);
    _reverseGeocode(latlng);
  }

  void _confirm() {
    Navigator.pop<MapPickerResult>(
      context,
      MapPickerResult(latlng: _pos, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF6AA56F);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: green,
        title: const Text('เลือกตำแหน่งบนแผนที่',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _locating ? null : _goToMyLocation,
            icon: _locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: Colors.black),
          )
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ที่อยู่/สถานที่ เพื่อค้นหา',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: (_searchCtrl.text.isNotEmpty || _geocoding)
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _searchByText,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _geocoding ? null : () => _searchByText(_searchCtrl.text),
                  child: _geocoding
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ค้นหา'),
                ),
              ],
            ),
          ),

          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pos,
                initialZoom: 15,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.deliapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pos,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // แถบแสดงที่อยู่ + ปุ่มยืนยัน
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12 + 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_address ?? 'แตะที่แผนที่เพื่อเลือกตำแหน่ง',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('ละติจูด: ${_pos.latitude.toStringAsFixed(6)}  '
                     'ลองจิจูด: ${_pos.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('ใช้ตำแหน่งนี้'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
