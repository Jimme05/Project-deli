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
        title: const Text("📦 รายละเอียดออเดอร์",
            style: TextStyle(fontWeight: FontWeight.w700)),
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
            imgStatus1: (m['img_status_1'] ?? '')?.toString(),
          );

          final hasLiveRider =
              riderId != null && riderId.isNotEmpty && status < 4;

          // ถ้ามีไรเดอร์ -> แสดงแผนที่ live ใต้ Header
          if (hasLiveRider) {
            final riderRef =
                FirebaseFirestore.instance.collection('riders').doc(riderId);
            return Column(
              children: [
                Expanded(child: header),
                Container(
                  height: 360,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
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

                        final center = riderLatLng ??
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
                ),
              ],
            );
          }

          // ถ้าไม่มีไรเดอร์ -> แสดง Header อย่างเดียว
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

  /// ✅ Marker ที่ “ไม่ล้น” และดูดีขึ้น
  static Marker _marker(LatLng p, Color c, String label) => Marker(
  point: p,
  width: 60,
  height: 72,                          // เผื่อพื้นที่ให้ป้าย + หมุด
  alignment: Alignment.topCenter,      // ⬅️ ใช้ alignment แทน anchorPos
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // ป้ายข้อความ
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.95),                     // ⬅️ แทน withOpacity
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 6),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 4),
      // หมุด
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),       // ⬅️
              blurRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(Icons.location_pin, color: c, size: 22),
      ),
    ],
  ),
);

  static int _asStatusInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

// 🗺️ Live Map widget + ปุ่มลอยสวย ๆ
class _LiveMap extends StatefulWidget {
  final LatLng center;
  final List<Marker> markers;
  const _LiveMap({required this.center, required this.markers});

  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  final _controller = MapController();
  double _zoom = 14;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: _zoom,
            minZoom: 3,
            maxZoom: 18,
          ),
          children: [
            // โทนแผนที่อ่านง่าย
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: widget.markers),
          ],
        ),

        // ปุ่มลอยด้านขวา
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              _mapFab(
                icon: Icons.my_location,
                tooltip: 'ไปตำแหน่ง',
                onTap: () => _controller.move(widget.center, _zoom),
              ),
              const SizedBox(height: 8),
              _mapFab(
                icon: Icons.add,
                tooltip: 'ซูมเข้า',
                onTap: () {
                  _zoom = (_zoom + 1).clamp(3, 18);
                  _controller.move(_controller.camera.center, _zoom);
                },
              ),
              const SizedBox(height: 8),
              _mapFab(
                icon: Icons.remove,
                tooltip: 'ซูมออก',
                onTap: () {
                  _zoom = (_zoom - 1).clamp(3, 18);
                  _controller.move(_controller.camera.center, _zoom);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapFab({required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Material(
      color: Colors.black87.withOpacity(0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// 🧾 Header (ข้อมูลออเดอร์)
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
                  child: const Icon(Icons.inventory_2_rounded,
                      size: 24, color: Colors.white),
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
            const Text("📍 เส้นทางการจัดส่ง",
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _locationCard(Icons.store_mall_directory_rounded, 'จุดรับสินค้า',
                pickupText, Colors.orange),
            const SizedBox(height: 8),
            _locationCard(Icons.location_on_rounded, 'ที่อยู่ผู้รับ',
                deliveryText, Colors.redAccent),
            if (imgStatus1 != null && imgStatus1!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("📷 ภาพสินค้าขณะจัดส่ง",
                  style: TextStyle(fontWeight: FontWeight.w700)),
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
      IconData icon, String title, String desc, Color color) {
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
            child: Text(
              '$title\n$desc',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13.5,
                height: 1.35,
              ),
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
      child: Text(t,
          style:
              TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
