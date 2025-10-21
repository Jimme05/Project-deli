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
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          "📦 รายละเอียดออเดอร์",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF6AA56F),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('❌ ไม่พบออเดอร์นี้'));
          }

          final m = snap.data!.data()!;
          final status = _asStatusInt(m['Status_order']);
          final riderId =
              (m['assignedRiderId'] ?? m['assignedRiderID'] ?? m['rid'])
                  ?.toString();
          final hasLiveRider =
              riderId != null && riderId.isNotEmpty && status < 4;

          final pickup = m['pickup_address'] as Map<String, dynamic>?;
          final delivery = m['delivery_address'] as Map<String, dynamic>?;

          final pickupLatLng = _toLatLng(pickup);
          final deliveryLatLng = _toLatLng(delivery);

          final header = _OrderHeader(
            name: (m['Name'] ?? '-').toString(),
            phone: (m['receiver_phone'] ?? '-').toString(),
            status: status,
            pickupText: pickup?['addressText'] ?? '-',
            deliveryText: delivery?['addressText'] ?? '-',
            createdAt: m['created_at'],
            imgStatus1: m['img_status_1'],
          );

          // แสดงแผนที่แบบ realtime ถ้ามีไรเดอร์
          if (hasLiveRider) {
            final riderRef = FirebaseFirestore.instance
                .collection('riders')
                .doc(riderId);
            return Column(
              children: [
                Expanded(child: header),
                Container(
                  height: 340,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                      final center =
                          riderLatLng ??
                          deliveryLatLng ??
                          pickupLatLng ??
                          const LatLng(13.7563, 100.5018);

                      final markers = <Marker>[
                        if (pickupLatLng != null)
                          _marker(pickupLatLng, Colors.orange, 'รับ'),
                        if (deliveryLatLng != null)
                          _marker(deliveryLatLng, Colors.redAccent, 'ส่ง'),
                        if (riderLatLng != null)
                          _marker(riderLatLng, Colors.blueAccent, 'ไรเดอร์'),
                      ];

                      return _LiveMap(center: center, markers: markers);
                    },
                  ),
                ),
              ],
            );
          }

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
    width: 50,
    height: 50,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c.withOpacity(0.8), c]),
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.4), blurRadius: 6, spreadRadius: 2),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
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

// 🗺️ Live Map widget
class _LiveMap extends StatelessWidget {
  final LatLng center;
  final List<Marker> markers;
  const _LiveMap({required this.center, required this.markers});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

// 🧾 Order Header
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
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF6AA56F),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            _kv('เบอร์ผู้รับ', phone),
            _kv('สถานะ', _statusText(status)),
            _kv('วันที่สร้าง', _dateStr(createdAt)),
            const Divider(height: 24, thickness: 1.1),
            const Text(
              "📍 เส้นทางการจัดส่ง",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _locationCard(
              Icons.store_mall_directory_rounded,
              'จุดรับสินค้า',
              pickupText,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _locationCard(
              Icons.location_on_rounded,
              'ที่อยู่ผู้รับ',
              deliveryText,
              Colors.redAccent,
            ),
            if (imgStatus1 != null && imgStatus1!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "📷 ภาพสินค้าขณะจัดส่ง",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imgStatus1!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _locationCard(
    IconData icon,
    String title,
    String desc,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
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
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(
            text: v,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    ),
  );

  static String _statusText(int s) {
    switch (s) {
      case 1:
        return 'รอไรเดอร์';
      case 2:
        return 'ไรเดอร์กำลังมารับ';
      case 3:
        return 'กำลังไปส่ง';
      case 4:
        return 'ส่งสำเร็จ';
      default:
        return 'ไม่ทราบ';
    }
  }

  static Widget _statusChip(int s) {
    Color c;
    String t;
    switch (s) {
      case 1:
        c = Colors.orange;
        t = 'รอไรเดอร์';
        break;
      case 2:
        c = Colors.blue;
        t = 'กำลังมารับ';
        break;
      case 3:
        c = Colors.indigo;
        t = 'กำลังไปส่ง';
        break;
      case 4:
        c = Colors.green;
        t = 'ส่งสำเร็จ';
        break;
      default:
        c = Colors.grey;
        t = 'ไม่ทราบ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
