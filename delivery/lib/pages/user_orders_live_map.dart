// lib/pages/user_orders_live_map.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum MapRole { sender, receiver }

class UserOrdersLiveMap extends StatelessWidget {
  const UserOrdersLiveMap({super.key, required this.role});

  final MapRole role;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('โปรดเข้าสู่ระบบ')));
    }

    // งานที่ยังไม่จบ (Status < 4) ของ user ตามบทบาท
    final q = FirebaseFirestore.instance
        .collection('orders')
        .where(
          role == MapRole.sender ? 'Uid_sender' : 'Uid_receiver',
          isEqualTo: uid,
        )
        .where('Status_order', isLessThan: 4);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6AA56F),
        title: Text(
          role == MapRole.sender
              ? 'แผนที่งานของฉัน (ผู้ส่ง)'
              : 'แผนที่งานของฉัน (ผู้รับ)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data?.docs ?? const [];

          // จุดของตัวเอง (sender = pickup, receiver = delivery)
          final ownPoints = <LatLng>[];
          final riderIds = <String>{};

          for (final d in orders) {
            final m = d.data();
            final addr = (role == MapRole.sender)
                ? (m['pickup_address'] as Map<String, dynamic>?)
                : (m['delivery_address'] as Map<String, dynamic>?);
            final lat = (addr?['Latitude'] as num?)?.toDouble();
            final lng = (addr?['Longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              ownPoints.add(LatLng(lat, lng));
            }
            final rid =
                (m['assignedRiderId'] ?? m['assignedRiderID'] ?? m['rid'])
                    ?.toString();
            if (rid != null && rid.isNotEmpty) riderIds.add(rid);
          }

          // ศูนย์กลางแผนที่: จุดแรกของตัวเอง หรือกรุงเทพ
          final center = ownPoints.isNotEmpty
              ? ownPoints.first
              : const LatLng(13.7563, 100.5018);

          return _RidersMap(
            center: center,
            ownPoints: ownPoints,
            riderIds: riderIds.toList(),
            role: role,
          );
        },
      ),
    );
  }
}

/// แผนที่ + รวมสตรีมไรเดอร์หลายคน (whereIn แบ่งเป็น batch ≤10)
class _RidersMap extends StatefulWidget {
  const _RidersMap({
    required this.center,
    required this.ownPoints,
    required this.riderIds,
    required this.role,
  });

  final LatLng center;
  final List<LatLng> ownPoints;
  final List<String> riderIds;
  final MapRole role;

  @override
  State<_RidersMap> createState() => _RidersMapState();
}

class _RidersMapState extends State<_RidersMap> {
  late final Stream<List<LatLng>> _ridersStream;

  @override
  void initState() {
    super.initState();
    _ridersStream = _mergeRiderStreams(widget.riderIds);
  }

  @override
  void didUpdateWidget(covariant _RidersMap old) {
    super.didUpdateWidget(old);
    if (old.riderIds.join(',') != widget.riderIds.join(',')) {
      _ridersStream = _mergeRiderStreams(widget.riderIds);
      setState(() {});
    }
  }

  // รวมตำแหน่งไรเดอร์จากหลายสตรีม (batch whereIn ≤ 10)
  Stream<List<LatLng>> _mergeRiderStreams(List<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    final streams = chunks.map((batch) {
      return FirebaseFirestore.instance
          .collection('riders')
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .map((snap) {
            final pts = <LatLng>[];
            for (final d in snap.docs) {
              final m = d.data();
              final lat = (m['latitude'] as num?)?.toDouble();
              final lng = (m['longitude'] as num?)?.toDouble();
              if (lat != null && lng != null) pts.add(LatLng(lat, lng));
            }
            return pts;
          });
    }).toList();

    // merge แบบง่าย: ฟังทุก stream แล้วรวมผล
    return StreamZip<List<LatLng>>(streams).map((lists) {
      final all = <LatLng>[];
      for (final l in lists) {
        all.addAll(l);
      }
      return all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = widget.role == MapRole.sender
        ? Colors.orange
        : Colors.redAccent;
    final roleLabel = widget.role == MapRole.sender ? 'รับ' : 'ส่ง';

    return LayoutBuilder(
      builder: (context, c) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.center,
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                  flags: ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                // พื้นหลังแผนที่ OSM สวย/อ่านง่าย
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),

                // เส้นทาง “ตามถนน” (เลือกใส่เพิ่มภายหลังได้ด้วย OSRM)

                // จุดของตัวเอง (รับ/ส่ง) — แสดงเฉพาะบทบาทนั้น ๆ
                MarkerLayer(
                  markers: widget.ownPoints
                      .map((p) => _dotMarker(p, roleColor, roleLabel))
                      .toList(),
                ),

                // ไรเดอร์หลายคน
                StreamBuilder<List<LatLng>>(
                  stream: _ridersStream,
                  builder: (context, snap) {
                    final riders = snap.data ?? const <LatLng>[];
                    if (riders.isEmpty) return const SizedBox.shrink();
                    return MarkerLayer(
                      markers: riders
                          .map(
                            (p) =>
                                _riderMarker(p, Colors.blueAccent, 'ไรเดอร์'),
                          )
                          .toList(),
                    );
                  },
                ),

                // ปุ่มยูทิลิตี้ข้างขวา
                _rightButtons(
                  context: context,
                  recenter: widget.ownPoints.isNotEmpty
                      ? () => _moveTo(widget.ownPoints.first)
                      : () => _moveTo(widget.center),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final _mapCtrl = MapController();

  void _moveTo(LatLng p) => _mapCtrl.move(p, 15.5);

  // ปุ่มด้านขวา
  Widget _rightButtons({
    required BuildContext context,
    required VoidCallback recenter,
  }) {
    return Positioned(
      right: 10,
      top: 10,
      child: Column(
        children: [
          _roundBtn(Icons.my_location, recenter),
          const SizedBox(height: 8),
          _roundBtn(
            Icons.add,
            () =>
                _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1),
          ),
          const SizedBox(height: 8),
          _roundBtn(
            Icons.remove,
            () =>
                _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData i, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(i, size: 22, color: Colors.black87),
        ),
      ),
    );
  }

  // Marker: จุดของฉัน (รับ/ส่ง)
  Marker _dotMarker(LatLng p, Color c, String label) => Marker(
    point: p,
    width: 72,
    height: 72,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.location_pin, color: c, size: 26),
        ),
      ],
    ),
  );

  // Marker: ไรเดอร์ (หลายคน)
  Marker _riderMarker(LatLng p, Color c, String label) => Marker(
    point: p,
    width: 72,
    height: 72,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.pedal_bike_rounded,
            color: Colors.blueAccent,
            size: 22,
          ),
        ),
      ],
    ),
  );
}

/// ===== StreamZip helper (รวมหลาย stream) =====
/// ถ้าโครงการคุณมี package rxdart แล้วใช้ Rx.combineLatestList แทนได้เลย
class StreamZip<T> extends Stream<List<T>> {
  StreamZip(this._streams);
  final List<Stream<T>> _streams;

  @override
  StreamSubscription<List<T>> listen(
    void Function(List<T>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = StreamController<List<T>>();
    final latest = List<T?>.filled(_streams.length, null);
    final received = List<bool>.filled(_streams.length, false);
    int doneCount = 0;

    final subs = <StreamSubscription<T>>[];
    for (var i = 0; i < _streams.length; i++) {
      subs.add(
        _streams[i].listen(
          (value) {
            latest[i] = value;
            received[i] = true;
            if (received.every((e) => e)) {
              controller.add(List<T>.from(latest));
            }
          },
          onError: controller.addError,
          onDone: () {
            doneCount++;
            if (doneCount == _streams.length) controller.close();
          },
        ),
      );
    }

    // ตั้ง onCancel ที่ controller แทน
    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    // แล้ว return การ listen ปกติ
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
