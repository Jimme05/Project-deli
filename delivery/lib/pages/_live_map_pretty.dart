// lib/widgets/_live_map_pretty.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LiveMapPretty extends StatefulWidget {
  final LatLng fallbackCenter;   // ใช้เมื่อไม่มีจุดใดเลย
  final LatLng? pickup;          // จุดรับ
  final LatLng? delivery;        // จุดส่ง
  final LatLng? rider;           // ตำแหน่งไรเดอร์ (อัปเดตเรียลไทม์จาก Firestore)

  const LiveMapPretty({
    super.key,
    required this.fallbackCenter,
    this.pickup,
    this.delivery,
    this.rider,
  });

  @override
  State<LiveMapPretty> createState() => _LiveMapPrettyState();
}

class _LiveMapPrettyState extends State<LiveMapPretty>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  LatLng _defaultCenter() =>
      widget.rider ?? widget.delivery ?? widget.pickup ?? widget.fallbackCenter;

  @override
  Widget build(BuildContext context) {
    final center = _defaultCenter();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 14),
            children: [
              // 🔹 HOT OSM (ฟรี, ไม่ต้องผูกบัตร)
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.delivery',
                maxZoom: 19,
              ),
              if (_routeLines().isNotEmpty)
                PolylineLayer(polylines: _routeLines()),
              MarkerLayer(markers: _markers()),
            ],
          ),

          // 🔘 ปุ่มลอย
          Positioned(
            right: 10,
            top: 10,
            child: Column(
              children: [
                _roundBtn(icon: Icons.center_focus_strong, onTap: _fitBounds, tooltip: 'แสดงทุกจุด'),
                const SizedBox(height: 8),
                _roundBtn(
                  icon: Icons.my_location,
                  onTap: () {
                    final r = widget.rider ?? center;
                    _map.move(r, 16);
                  },
                  tooltip: 'ไปที่ไรเดอร์',
                ),
                const SizedBox(height: 8),
                _roundBtn(icon: Icons.add, onTap: () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
                const SizedBox(height: 8),
                _roundBtn(icon: Icons.remove, onTap: () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Markers & Lines ----------

  List<Marker> _markers() {
    final list = <Marker>[];
    if (widget.pickup != null) {
      list.add(_pin(widget.pickup!,
          color: Colors.orange, label: 'รับ', icon: Icons.store_mall_directory_rounded));
    }
    if (widget.delivery != null) {
      list.add(_pin(widget.delivery!,
          color: Colors.redAccent, label: 'ส่ง', icon: Icons.location_on_rounded));
    }
    if (widget.rider != null) list.add(_riderMarker(widget.rider!));
    return list;
  }

  List<Polyline> _routeLines() {
    if (widget.pickup != null && widget.delivery != null) {
      return [
        Polyline( // เงาเส้น
          points: [widget.pickup!, widget.delivery!],
          color: Colors.indigo.withOpacity(.35),
          strokeWidth: 6,
        ),
        Polyline( // เส้นหลัก
          points: [widget.pickup!, widget.delivery!],
          color: Colors.indigo.withOpacity(.9),
          strokeWidth: 2,
        ),
      ];
    }
    return const [];
  }

  Marker _pin(LatLng p,
      {required Color color, required String label, required IconData icon}) {
    return Marker(
      point: p,
      width: 84,
      height: 84,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          // ป้ายบับเบิล
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: color.withOpacity(.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(height: 6),
          // หัวหมุด
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 6)],
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ],
      ),
    );
  }

  Marker _riderMarker(LatLng p) {
    return Marker(
      point: p,
      width: 90,
      height: 90,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final t = _pulse.value; // 0..1
          final radius = 16 + 8 * math.sin(t * math.pi); // pulse
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: radius * 2, height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(.15),
                ),
              ),
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: Colors.blueAccent, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(.35), blurRadius: 8)],
                ),
              ),
              const Positioned(
                bottom: -18,
                child: Text('ไรเดอร์',
                    style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _fitBounds() {
    final pts = <LatLng>[
      if (widget.pickup != null) widget.pickup!,
      if (widget.delivery != null) widget.delivery!,
      if (widget.rider != null) widget.rider!,
    ];
    if (pts.isEmpty) return;

    var sw = LatLng(90, 180);
    var ne = LatLng(-90, -180);
    for (final p in pts) {
      sw = LatLng(math.min(sw.latitude, p.latitude), math.min(sw.longitude, p.longitude));
      ne = LatLng(math.max(ne.latitude, p.latitude), math.max(ne.longitude, p.longitude));
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(sw, ne),
      padding: const EdgeInsets.all(30),
    ));
  }

  Widget _roundBtn({
  required IconData icon,
  required VoidCallback onTap,
  String? tooltip,
}) {
  return Material(
    color: Colors.white.withOpacity(0.9), // 🔹 โปร่งนิด ๆ ดูไม่จ้า
    shape: const CircleBorder(),
    elevation: 4,
    shadowColor: Colors.black26,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 22,
            color: const Color(0xFF4A4A4A), // 🔹 สีเทาเข้มอ่านง่าย
          ),
        ),
      ),
    ),
  );
}

}
