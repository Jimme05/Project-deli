// lib/pages/user_all_orders_map_page.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class UserAllOrdersMapPage extends StatefulWidget {
  const UserAllOrdersMapPage({super.key});

  /// ส่ง args เป็น { "mode": "sender" | "receiver" } เพื่อเลือกดู “ฉันส่ง/ฉันได้รับ”
  /// ถ้าไม่ส่งมา จะ default = "sender"
  @override
  State<UserAllOrdersMapPage> createState() => _UserAllOrdersMapPageState();
}

class _UserAllOrdersMapPageState extends State<UserAllOrdersMapPage> {
  final _map = MapController();
  int _tileIndex = 0; // 0=osm, 1=opentopo
  double _zoom = 13;

  String _mode = 'sender'; // sender | receiver
  bool _showPickup = true;
  bool _showDelivery = true;
  bool _showRider = true;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is Map && args['mode'] is String) {
      _mode = (args['mode'] == 'receiver') ? 'receiver' : 'sender';
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('กรุณาเข้าสู่ระบบ')));
    }

    final field = _mode == 'receiver' ? 'Uid_receiver' : 'Uid_sender';

    // ✅ คัดเฉพาะออเดอร์ที่ยังไม่จบงาน Status_order < 4 (ต้องมี composite index คู่กับ field ด้านบน)
    final ordersQ = FirebaseFirestore.instance
        .collection('orders')
        .where(field, isEqualTo: uid)
        .where('Status_order', isLessThan: 4)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6AA56F),
        title: Text(
          _mode == 'receiver'
              ? 'แมพรวมออเดอร์ (ฉันได้รับ)'
              : 'แมพรวมออเดอร์ (ฉันส่ง)',
        ),
        actions: [
          IconButton(
            tooltip: 'สลับโหมด ฉันส่ง/ฉันได้รับ',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () => setState(
                () => _mode = _mode == 'receiver' ? 'sender' : 'receiver'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersQ,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          // ---- เก็บข้อมูลออเดอร์ไว้ใช้ผูกกับไรเดอร์ ----
          final pickupMarkers = <Marker>[];
          final deliveryMarkers = <Marker>[];
          final riderIds = <String>[];
          final straightPolylines = <Polyline>[];

          // โครงสร้างช่วยจำของแต่ละออเดอร์ (ไว้จับคู่กับตำแหน่งไรเดอร์)
          final orders = <_OrderPoint>[];

          for (final d in docs) {
            final m = d.data();

            final pickup = _toLatLng(m['pickup_address']);
            final delivery = _toLatLng(m['delivery_address']);
            final status = _asStatusInt(m['Status_order']);

            final rid =
                (m['assignedRiderId'] ?? m['rid'])?.toString().trim() ?? '';

            orders.add(_OrderPoint(
              oid: d.id,
              riderId: rid.isEmpty ? null : rid,
              pickup: pickup,
              delivery: delivery,
              status: status,
            ));

            if (pickup != null && _showPickup) {
              pickupMarkers.add(_poiMarker(
                p: pickup,
                color: Colors.orange,
                label: 'รับ',
                icon: Icons.store_mall_directory_rounded,
              ));
            }
            if (delivery != null && _showDelivery) {
              deliveryMarkers.add(_poiMarker(
                p: delivery,
                color: Colors.redAccent,
                label: 'ส่ง',
                icon: Icons.location_on_rounded,
              ));
            }

            // เส้นตรงเชื่อม pickup→delivery (ตัวอย่าง) สีต่างกันตามโหมด
            if (pickup != null && delivery != null) {
              final lineColor = _mode == 'sender'
                  ? Colors.indigo
                  : Colors.teal; // sender=คราม, receiver=เขียวอมฟ้า
              straightPolylines.add(Polyline(
                points: [pickup, delivery],
                strokeWidth: 2.6,
                color: lineColor.withValues(alpha: 0.5),
              ));
            }

            if (rid.isNotEmpty) riderIds.add(rid);
          }

          // คำนวณ center
          final allBaseMarkers = [...pickupMarkers, ...deliveryMarkers];
          final center = _fitCenter(allBaseMarkers) ??
              const LatLng(13.7563, 100.5018); // BKK fallback

          // แบ่ง riderIds เป็นชุด ๆ ละ ≤10 (ข้อจำกัด whereIn)
          final riderIdChunks = <List<String>>[];
          for (var i = 0; i < riderIds.length; i += 10) {
            riderIdChunks.add(
                riderIds.sublist(i, min(i + 10, riderIds.length)));
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoom,
                ),
                children: [
                  if (_tileIndex == 0)
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.delivery',
                    )
                  else
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.delivery',
                    ),

                  // เส้นเชื่อม pickup→delivery (ของแต่ละออเดอร์)
                  if (straightPolylines.isNotEmpty)
                    PolylineLayer(polylines: straightPolylines),

                  // จุด pickup/delivery
                  if (_showPickup && pickupMarkers.isNotEmpty)
                    MarkerLayer(markers: pickupMarkers),
                  if (_showDelivery && deliveryMarkers.isNotEmpty)
                    MarkerLayer(markers: deliveryMarkers),

                  // ✅ เลเยอร์ไรเดอร์ (เรียลไทม์) + เส้น "ไรเดอร์ → จุดที่ควรไปตอนนี้" ต่อออเดอร์
                  if (_showRider && riderIdChunks.isNotEmpty)
                    ...riderIdChunks.map((ids) {
                      return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('riders')
                            .where(FieldPath.documentId, whereIn: ids)
                            .snapshots(),
                        builder: (context, rSnap) {
                          if (!rSnap.hasData || rSnap.data!.docs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final riderMarkers = <Marker>[];
                          final riderLines = <Polyline>[];

                          for (final doc in rSnap.data!.docs) {
                            final r = doc.data();
                            final lat =
                                (r['latitude'] as num?)?.toDouble();
                            final lng =
                                (r['longitude'] as num?)?.toDouble();
                            if (lat == null || lng == null) continue;

                            final rp = LatLng(lat, lng);
                            riderMarkers.add(_riderMarker(
                              id: doc.id,
                              p: rp,
                            ));

                            // หาออเดอร์ที่ไรเดอร์นี้ดูแล
                            final owned = orders
                                .where((o) => o.riderId == doc.id)
                                .toList();
                            for (final o in owned) {
                              // จุดเป้าหมาย: ถ้าสถานะ 2 → pickup, ถ้า 3 → delivery
                              LatLng? target;
                              if (o.status == 2) {
                                target = o.pickup;
                              } else if (o.status == 3) {
                                target = o.delivery;
                              }
                              if (target == null) continue;

                              riderLines.add(Polyline(
                                points: [rp, target],
                                strokeWidth: 2.2,
                                color: Colors.blueAccent
                                    .withValues(alpha: 0.65),
                              ));
                            }
                          }

                          // วาดเส้นก่อน แล้วค่อย Marker ของไรเดอร์
                          return Stack(
                            children: [
                              if (riderLines.isNotEmpty)
                                PolylineLayer(polylines: riderLines),
                              if (riderMarkers.isNotEmpty)
                                MarkerLayer(markers: riderMarkers),
                            ],
                          );
                        },
                      );
                    }).toList(),
                ],
              ),

              // ปุ่มควบคุมด้านขวา
              Positioned(
                right: 12,
                top: 16,
                child: Column(
                  children: [
                    _roundBtn(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'มองรวมทั้งหมด',
                      onTap: () {
                        final allM = [
                          ...pickupMarkers,
                          ...deliveryMarkers,
                        ];
                        final c = _fitCenter(allM) ?? _map.camera.center;
                        _zoom = 13;
                        _map.move(c, _zoom);
                      },
                    ),
                    const SizedBox(height: 10),
                    _roundBtn(
                      icon: Icons.layers_rounded,
                      tooltip: 'สลับพื้นหลังแผนที่',
                      onTap: () => setState(
                          () => _tileIndex = (_tileIndex + 1) % 2),
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
                  ],
                ),
              ),

              // สวิตช์ซ้าย: แสดง/ซ่อนเลเยอร์
              Positioned(
                left: 12,
                top: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _layerSwitch(
                          color: Colors.orange,
                          label: 'จุดรับ',
                          value: _showPickup,
                          onChanged: (v) => setState(() => _showPickup = v),
                        ),
                        _layerSwitch(
                          color: Colors.redAccent,
                          label: 'ผู้รับ',
                          value: _showDelivery,
                          onChanged: (v) =>
                              setState(() => _showDelivery = v),
                        ),
                        _layerSwitch(
                          color: Colors.blueAccent,
                          label: 'ไรเดอร์',
                          value: _showRider,
                          onChanged: (v) => setState(() => _showRider = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------- helpers --------

  static LatLng? _toLatLng(dynamic m) {
    if (m is! Map) return null;
    final lat = (m['Latitude'] as num?)?.toDouble();
    final lng = (m['Longitude'] as num?)?.toDouble();
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  static int _asStatusInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Marker _poiMarker({
    required LatLng p,
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return Marker(
      point: p,
      width: 70,
      height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(label, color),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                )
              ],
            ),
            child: Icon(icon, color: color),
          ),
        ],
      ),
    );
  }

  Marker _riderMarker({required String id, required LatLng p}) {
    return Marker(
      key: ValueKey('rider_$id'),
      point: p,
      width: 70,
      height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.25),
                  blurRadius: 8,
                )
              ],
            ),
            child: const Text(
              'ไรเดอร์',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                )
              ],
            ),
            child: const Icon(Icons.motorcycle_rounded,
                color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 8)],
        ),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );

  LatLng? _fitCenter(List<Marker> markers) {
    if (markers.isEmpty) return null;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final m in markers) {
      minLat = min(minLat, m.point.latitude);
      maxLat = max(maxLat, m.point.latitude);
      minLng = min(minLng, m.point.longitude);
      maxLng = max(maxLng, m.point.longitude);
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  Widget _roundBtn({
    required IconData icon,
    String? tooltip,
    required VoidCallback onTap,
  }) =>
      Material(
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

  Widget _layerSwitch({
    required Color color,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _OrderPoint {
  final String oid;
  final String? riderId;
  final LatLng? pickup;
  final LatLng? delivery;
  final int status;
  _OrderPoint({
    required this.oid,
    required this.riderId,
    required this.pickup,
    required this.delivery,
    required this.status,
  });
}
