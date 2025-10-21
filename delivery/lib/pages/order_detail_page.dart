import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final oid = ModalRoute.of(context)!.settings.arguments as String;
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(oid);

    return Scaffold(
      appBar: AppBar(title: Text('รายละเอียดออเดอร์ ($oid)')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('ไม่พบออเดอร์นี้'));
          }

          final m = snap.data!.data()!;
          final status = _asStatusInt(m['Status_order']);
          final riderId = (m['assignedRiderId'] ?? m['assignedRiderID'] ?? m['rid'])?.toString();
          final hasLiveRider = riderId != null && riderId.isNotEmpty && status < 4;

          final pickup = m['pickup_address'] as Map<String, dynamic>?;
          final delivery = m['delivery_address'] as Map<String, dynamic>?;

          final pickupLatLng = _toLatLng(pickup);
          final deliveryLatLng = _toLatLng(delivery);

          // ส่วนหัวข้อมูล
          final header = _OrderHeader(
            name: (m['Name'] ?? '-').toString(),
            phone: (m['receiver_phone'] ?? '-').toString(),
            status: status,
            pickupText: pickup?['addressText'] ?? '-',
            deliveryText: delivery?['addressText'] ?? '-',
            createdAt: m['created_at'],
            imgStatus1: m['img_status_1'],
          );

          // ถ้ายังขนส่ง + มีไรเดอร์ → แสดงแผนที่แบบ realtime
          if (hasLiveRider) {
            final riderRef = FirebaseFirestore.instance.collection('riders').doc(riderId);
            return Column(
              children: [
                Expanded(child: header),
                SizedBox(
                  height: 340,
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: riderRef.snapshots(),
                    builder: (context, rSnap) {
                      LatLng? riderLatLng;
                      if (rSnap.hasData && rSnap.data!.exists) {
                        final r = rSnap.data!.data()!;
                        final lat = (r['latitude'] as num?)?.toDouble();
                        final lng = (r['longitude'] as num?)?.toDouble();
                        if (lat != null && lng != null) {
                          riderLatLng = LatLng(lat, lng);
                        }
                      }
                      // เลือก center
                      final center = riderLatLng ??
                          deliveryLatLng ??
                          pickupLatLng ??
                          const LatLng(13.7563, 100.5018);

                      final markers = <Marker>[];
                      if (pickupLatLng != null) {
                        markers.add(_marker(pickupLatLng, Colors.orange, 'P'));
                      }
                      if (deliveryLatLng != null) {
                        markers.add(_marker(deliveryLatLng, Colors.red, 'D'));
                      }
                      if (riderLatLng != null) {
                        markers.add(_marker(riderLatLng, Colors.blue, 'R'));
                      }

                      return _LiveMap(center: center, markers: markers);
                    },
                  ),
                ),
              ],
            );
          }

          // ถ้าส่งเสร็จ หรือยังไม่มีไรเดอร์ → ไม่มีแผนที่ live
          return header;
        },
      ),
    );
  }

  // ---------- helpers ----------
  static LatLng? _toLatLng(Map<String, dynamic>? m) {
    if (m == null) return null;
    final lat = (m['Latitude'] as num?)?.toDouble();
    final lng = (m['Longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static Marker _marker(LatLng p, Color c, String label) => Marker(
  point: p,
  width: 44,
  height: 44,
  child: Container(
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
);
  static int _asStatusInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class _LiveMap extends StatelessWidget {
  final LatLng center;
  final List<Marker> markers;
  const _LiveMap({required this.center, required this.markers});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  final String name;
  final String phone;
  final int status;
  final String pickupText;
  final String deliveryText;
  final dynamic createdAt;
  final String? imgStatus1;

  const _OrderHeader({
    required this.name,
    required this.phone,
    required this.status,
    required this.pickupText,
    required this.deliveryText,
    required this.createdAt,
    required this.imgStatus1,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.inventory_2_rounded, size: 28, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            _statusChip(status),
          ]),
          const SizedBox(height: 8),
          _kv('เบอร์ผู้รับ', phone),
          _kv('สถานะ', _statusText(status)),
          _kv('วันที่สร้าง', _dateStr(createdAt)),
          const Divider(height: 20),
          _kv('จุดรับ (ผู้ส่ง)', pickupText),
          _kv('ที่อยู่ผู้รับ', deliveryText),
          if (imgStatus1 != null && imgStatus1!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imgStatus1!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          ]
        ],
      ),
    );
  }

  static String _dateStr(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            text: '$k: ',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            children: [TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w400))],
          ),
        ),
      );

  static String _statusText(int s) {
    switch (s) {
      case 1: return 'รอไรเดอร์';
      case 2: return 'ไรเดอร์กำลังมารับ';
      case 3: return 'กำลังไปส่ง';
      case 4: return 'ส่งสำเร็จ';
      default: return 'ไม่ทราบ';
    }
  }

  static Widget _statusChip(int s) {
    Color c;
    String t;
    switch (s) {
      case 1: c = Colors.orange; t = 'รอไรเดอร์'; break;
      case 2: c = Colors.blue;   t = 'กำลังมารับ'; break;
      case 3: c = Colors.indigo; t = 'กำลังไปส่ง'; break;
      case 4: c = Colors.green;  t = 'ส่งสำเร็จ'; break;
      default: c = Colors.grey;  t = 'ไม่ทราบ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
    );
  }
}
