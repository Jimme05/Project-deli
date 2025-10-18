// lib/pages/map_picker_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapPickerPage extends StatefulWidget {
  final LatLng initial;
  const MapPickerPage({super.key, required this.initial});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();

  LatLng? _picked;
  Timer? _debounce;
  bool _searching = false;
  List<_Place> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(q)}&format=json&limit=8',
    );
    // ใส่ User-Agent ตามข้อกำหนดของ Nominatim
    final res = await http.get(uri, headers: {'User-Agent': 'delivery-app/1.0 (example@example.com)'});
    if (res.statusCode == 200) {
      final List data = json.decode(res.body) as List;
      final list = data.map((e) => _Place(
        displayName: e['display_name'] ?? '',
        lat: double.parse(e['lat']),
        lon: double.parse(e['lon']),
      )).toList();
      setState(() {
        _results = list;
        _searching = false;
      });
    } else {
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  void _onChangedSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _searchPlaces(v));
  }

  void _selectPlace(_Place p) {
    final pos = LatLng(p.lat, p.lon);
    setState(() {
      _picked = pos;
      _searchCtrl.text = p.displayName;
      _results = [];
    });
    _map.move(pos, 16);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (_picked != null) {
      markers.add(Marker(
        width: 40, height: 40, point: _picked!,
        child: const Icon(Icons.location_on, color: Colors.red, size: 36),
      ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("เลือกตำแหน่ง")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 15,
              onTap: (tapPos, latlng) => setState(() => _picked = latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.your.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // กล่องค้นหา
          Positioned(
            left: 12, right: 12, top: 12,
            child: Column(
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onChangedSearch,
                    decoration: InputDecoration(
                      hintText: "ค้นหาที่อยู่/สถานที่ (OSM)",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching ? const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ) : (_searchCtrl.text.isEmpty ? null : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: (){
                          _searchCtrl.clear();
                          setState(() => _results = []);
                        },
                      )),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // รายการผลลัพธ์
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _results[i];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            p.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectPlace(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ปุ่มยืนยัน
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('ยืนยันตำแหน่งนี้'),
              onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
            ),
          ),
        ],
      ),
    );
  }
}

class _Place {
  final String displayName;
  final double lat;
  final double lon;
  _Place({required this.displayName, required this.lat, required this.lon});
}
