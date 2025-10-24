import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OrderMapPage extends StatefulWidget {
  const OrderMapPage({super.key});

  @override
  State<OrderMapPage> createState() => _OrderMapPageState();
}

class _OrderMapPageState extends State<OrderMapPage> {
  final _map = MapController();

  // layer toggle: 0 = OSM (street), 1 = Topo (กึ่งภูมิประเทศ)
  int _tileIndex = 0;

  // focus toggle: 'pickup' | 'delivery'
  String _focus = 'pickup';

  // geometry
  LatLng? _pickup;
  LatLng? _delivery;
  LatLng? _rider;

  // view
  double _zoom = 14;

  @override
  Widget build(BuildContext context) {
    // รับ args: {'oid': String, 'focus': 'pickup'|'delivery'}
    final args = ModalRoute.of(context)!.settings.arguments;
    final mapArgs = (args is Map) ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final oid = (mapArgs['oid'] ?? '') as String;
    final initialFocus = (mapArgs['focus'] ?? 'pickup') as String;
    _focus = (initialFocus == 'delivery') ? 'delivery' : 'pickup';

    final orderRef = FirebaseFirestore.instance.collection('orders').doc(oid);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6AA56F),
        title: const Text('แผนที่การจัดส่ง'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data!.data()!;
          final riderId = (m['assignedRiderId'] ?? m['rid'])?.toString();
          _pickup   = _toLatLng(m['pickup_address']);
          _delivery = _toLatLng(m['delivery_address']);

          // จุดเริ่มต้น
          final fallbackCenter = _pickup ?? _delivery ?? const LatLng(13.7563, 100.5018);

          return Stack(
            children: [
              // ---- แผนที่หลัก ----
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: fallbackCenter,
                  initialZoom: _zoom,
                ),
                children: [
                  // ฟรี ไม่ต้องผูกบัตร
                  if (_tileIndex == 0)
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.delivery',
                      tileProvider: NetworkTileProvider(), // default
                    )
                  else
                    TileLayer(
                      // OpenTopoMap ฟรี (มีภาพทาง/อาคารพอสมควร)
                      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.delivery',
                    ),

                  // เส้นทาง pickup -> delivery (ถ้ามีทั้งคู่)
                  if (_pickup != null && _delivery != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_pickup!, _delivery!],
                          strokeWidth: 4,
                          color: Colors.indigo.withOpacity(0.6),
                        ),
                      ],
                    ),

                  // มาร์คเกอร์
                  MarkerLayer(
                    markers: [
                      if (_pickup != null)
                        _pin(_pickup!, Colors.orange, 'รับ'),
                      if (_delivery != null)
                        _pin(_delivery!, Colors.redAccent, 'ส่ง'),
                      if (_rider != null)
                        _pin(_rider!, Colors.blueAccent, 'ไรเดอร์'),
                    ],
                  ),
                ],
              ),

              // ---- panel คำอธิบายสั้น ๆ ----
              Positioned(
                left: 12,
                right: 12,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _focus == 'pickup' ? Icons.store_mall_directory_rounded : Icons.location_on_rounded,
                        color: _focus == 'pickup' ? Colors.orange : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _focus == 'pickup' ? 'ฉันคือ: จุดรับสินค้า (ผู้ส่ง)' : 'ฉันคือ: ที่อยู่ผู้รับ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _swapFocus,
                       
                        label: const Text('ดู'),
                      )
                    ],
                  ),
                ),
              ),

              // ---- ปุ่มลอยควบคุม ----
              Positioned(
                right: 12,
                top: 16,
                child: Column(
                  children: [
                    _roundBtn(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'ไปยังจุดโฟกัส',
                      onTap: () {
                        final p = _focus == 'pickup' ? _pickup : _delivery;
                        if (p != null) _animateTo(p, _zoom);
                      },
                    ),
                    const SizedBox(height: 10),
                    _roundBtn(
                      icon: Icons.travel_explore_rounded,
                      tooltip: 'ติดตามไรเดอร์',
                      onTap: () {
                        if (_rider != null) _animateTo(_rider!, max(_zoom, 15));
                      },
                    ),
                    const SizedBox(height: 10),
                    _roundBtn(
                      icon: Icons.add,
                      tooltip: 'ซูมเข้า',
                      onTap: () {
                        _zoom = (_map.camera.zoom + 0.5).clamp(3, 19);
                        _map.move(_map.camera.center, _zoom);
                      },
                    ),
                    const SizedBox(height: 10),
                    _roundBtn(
                      icon: Icons.remove,
                      tooltip: 'ซูมออก',
                      onTap: () {
                        _zoom = (_map.camera.zoom - 0.5).clamp(3, 19);
                        _map.move(_map.camera.center, _zoom);
                      },
                    ),
                    const SizedBox(height: 10),
                    _roundBtn(
                      icon: Icons.layers_rounded,
                      tooltip: 'สลับแผนที่',
                      onTap: () => setState(() => _tileIndex = (_tileIndex + 1) % 2),
                    ),
                  ],
                ),
              ),

              // ---- ติดตามไรเดอร์แบบเรียลไทม์ ----
              if (riderId != null && riderId.isNotEmpty)
                Positioned.fill(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('riders').doc(riderId).snapshots(),
                    builder: (context, rSnap) {
                      if (rSnap.hasData && rSnap.data!.exists) {
                        final r = rSnap.data!.data()!;
                        final lat = (r['latitude'] as num?)?.toDouble();
                        final lng = (r['longitude'] as num?)?.toDouble();
                        if (lat != null && lng != null) {
                          _rider = LatLng(lat, lng);
                        }
                        // ไม่ต้องวาดซ้ำที่นี่ เพราะ MarkerLayer อ่านจาก _rider (setState เมื่อ coords เปลี่ยน)
                        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------- helpers ----------
  void _swapFocus() {
    setState(() => _focus = (_focus == 'pickup') ? 'delivery' : 'pickup');
    final p = _focus == 'pickup' ? _pickup : _delivery;
    if (p != null) _animateTo(p, max(_map.camera.zoom, 14));
  }

  void _animateTo(LatLng p, double zoom) {
    _map.move(p, zoom);
  }

  static LatLng? _toLatLng(dynamic m) {
    if (m is! Map) return null;
    final lat = (m['Latitude'] as num?)?.toDouble();
    final lng = (m['Longitude'] as num?)?.toDouble();
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  Marker _pin(LatLng p, Color c, String label) => Marker(
        point: p,
        width: 70,
        height: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(label, c),
            const SizedBox(height: 4),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8)],
              ),
              child: Icon(
                label == 'ไรเดอร์'
                    ? Icons.motorcycle_rounded
                    : (label == 'รับ'
                        ? Icons.store_mall_directory_rounded
                        : Icons.location_on_rounded),
                color: c,
              ),
            ),
          ],
        ),
      );

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: c.withOpacity(0.25), blurRadius: 8)],
        ),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _roundBtn({required IconData icon, String? tooltip, required VoidCallback onTap}) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Tooltip(
            message: tooltip ?? '',
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: Colors.black87),
            ),
          ),
        ),
      );
}
