import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/pages/rider_accepted_orders_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// map
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RiderProfilePage extends StatefulWidget {
  const RiderProfilePage({super.key});

  @override
  State<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends State<RiderProfilePage> {
  static const Color kGreen = Color(0xFF6AA56F);
  static const Color kPageGrey = Color(0xFFE5E5E5);
  static const Color kPrimaryBlue = Color(0xFF2D7BF0);

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  StreamSubscription<Position>? _posSub;
  bool _startingShare = false;

  @override
  void dispose() {
    _stopLocationStream();
    super.dispose();
  }

  Future<bool> ensureLocationPermission(BuildContext context) async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเปิด Location Service')),
      );
      return false;
    }

    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่ได้รับสิทธิ์ตำแหน่ง')),
      );
      return false;
    }
    return true;
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ออกจากระบบเรียบร้อย'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e')),
      );
    }
  }

  Future<void> _startLocationStream(String orderId) async {
    if (_posSub != null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่ได้รับสิทธิ์ตำแหน่ง: ไม่สามารถแชร์พิกัดได้')),
        );
        return;
      }
    }

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเปิด Location Service')),
      );
      return;
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      await _db.collection('riders').doc(uid).set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'last_update': FieldValue.serverTimestamp(),
        'current_order_id': orderId,
        'Status-rider': 'busy',
      }, SetOptions(merge: true));
    });
  }

  Future<void> _stopLocationStream() async {
    await _posSub?.cancel();
    _posSub = null;
  }

  Future<void> _acceptOrder(String orderId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ok = await ensureLocationPermission(context);
    if (!ok) return;

    setState(() => _startingShare = true);
    try {
      final riderDoc = await _db.collection('riders').doc(uid).get();
      final r = riderDoc.data() ?? {};
      final status = (r['Status-rider'] ?? 'idle').toString();
      final currentOrder = (r['current_order_id'] ?? '').toString();

      if (status != 'idle' || currentOrder.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('คุณมีงานค้างอยู่ กรุณาส่งงานเดิมให้เสร็จก่อนรับงานใหม่'),
          ),
        );
        return;
      }

      await _db.collection('orders').doc(orderId).update({
        'assignedRiderId': uid,
        'Status_order': 2,
        'accepted_at': FieldValue.serverTimestamp(),
      });

      await _db.collection('riders').doc(uid).set({
        'Status-rider': 'busy',
        'current_order_id': orderId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _startLocationStream(orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ รับออเดอร์สำเร็จ และเริ่มแชร์พิกัดเรียลไทม์')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ รับออเดอร์ไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _startingShare = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('กรุณาเข้าสู่ระบบก่อน')));
    }

    final riderProfileFuture = _db.collection('users').doc(uid).get();
    final waitingOrdersStream = _db
        .collection('orders')
        .where('Status_order', isEqualTo: 1)
        .where('assignedRiderId', isNull: true)
        .snapshots();

    return Scaffold(
      backgroundColor: kPageGrey,
      appBar: AppBar(
        backgroundColor: kGreen,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile Rider',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _db.collection('riders').doc(uid).snapshots(),
            builder: (context, snap) {
              final status = (snap.data?.data()?['Status-rider'] ?? 'idle').toString();
              final busy = status != 'idle';
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: busy ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  busy ? 'สถานะ: ไม่ว่าง' : 'สถานะ: ว่าง',
                  style: TextStyle(
                    color: busy ? Colors.orange.shade800 : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text(
              'ออกจากระบบ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: riderProfileFuture,
          builder: (context, riderSnap) {
            if (riderSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final riderData = riderSnap.data?.data() ?? {};
            final name = (riderData['name'] ?? 'ชื่อไรเดอร์').toString();
            final phone = (riderData['phone'] ?? 'ไม่ระบุเบอร์').toString();
            final license =
                (riderData['license'] ?? riderData['vehiclePlate'] ?? 'ไม่ระบุทะเบียน').toString();
            final photoUrl = (riderData['photoUrl'] ??
                    'https://cdn-icons-png.flaticon.com/512/147/147142.png')
                .toString();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: waitingOrdersStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allOrders = snap.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(photoUrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$name\nเบอร์ : $phone\nทะเบียนรถ : $license',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RiderAcceptedOrdersPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_turned_in_rounded),
                        label: const Text("ดูออเดอร์ที่รับแล้ว"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'รายการออเดอร์ทั้งหมด (รอไรเดอร์)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (allOrders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text('ยังไม่มีออเดอร์รอรับในตอนนี้',
                              style: TextStyle(color: Colors.black54)),
                        ),
                      )
                    else
                      ...allOrders.map((doc) => _OrderCard(
                            orderDoc: doc,
                            onAccept: _startingShare ? null : () => _acceptOrder(doc.id),
                            accepting: _startingShare,
                          )),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// การ์ดออเดอร์ (มีชื่อผู้ส่ง/ผู้รับ + ที่อยู่ละเอียด + แผนที่ + ปุ่มรับงาน)
class _OrderCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> orderDoc;
  final VoidCallback? onAccept;
  final bool accepting;

  const _OrderCard({
    required this.orderDoc,
    required this.onAccept,
    required this.accepting,
  });

  @override
  Widget build(BuildContext context) {
    final m = orderDoc.data();
    final oid = orderDoc.id;

    final senderUid = (m['Uid_sender'] ?? m['senderUid'] ?? '').toString();
    final receiverUid = (m['Uid_receiver'] ?? '').toString();

    final pickup = (m['pickup_address'] ?? {}) as Map<String, dynamic>;
    final delivery = (m['delivery_address'] ?? {}) as Map<String, dynamic>;
    final created = _formatDate(m['created_at']);

    // default (เผื่อไม่เจอ users)
    final orderReceiverName = (m['Name'] ?? '-').toString();
    final orderReceiverPhone = (m['receiver_phone'] ?? '-').toString();

    final pickupText = _addressTextOrCoord(pickup);
    final deliveryText = _addressTextOrCoord(delivery);

    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait([
        senderUid.isNotEmpty
            ? FirebaseFirestore.instance.collection('users').doc(senderUid).get().then((d) => d.data())
            : Future.value(null),
        receiverUid.isNotEmpty
            ? FirebaseFirestore.instance.collection('users').doc(receiverUid).get().then((d) => d.data())
            : Future.value(null),
      ]),
      builder: (context, snap) {
        final senderData = (snap.data != null && snap.data!.isNotEmpty) ? snap.data![0] : null;
        final receiverData = (snap.data != null && snap.data!.length > 1) ? snap.data![1] : null;

        final senderName = (senderData?['name'] ?? '-').toString();
        final senderPhone = (senderData?['phone'] ?? '-').toString();

        final receiverName = (receiverData?['name'] ?? orderReceiverName).toString();
        final receiverPhone = (receiverData?['phone'] ?? orderReceiverPhone).toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.15 * 255).round()),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📦 Order ID: $oid",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 6),

              Text("ผู้ส่ง: $senderName  (${senderPhone == '-' ? '' : senderPhone})"),
              Text("ผู้รับ: $receiverName  (${receiverPhone == '-' ? '' : receiverPhone})"),
              Text("วันที่สร้าง: $created"),
              const SizedBox(height: 8),

              // ที่อยู่แบบละเอียด (การ์ดเล็ก ๆ สองใบ)
              const Text("📍 เส้นทางจัดส่ง", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _addrCard(
                icon: Icons.store_mall_directory_rounded,
                title: 'จุดรับสินค้า (ผู้ส่ง)',
                text: pickupText,
                color: Colors.orange,
              ),
              const SizedBox(height: 6),
              _addrCard(
                icon: Icons.location_on_rounded,
                title: 'ปลายทาง (ผู้รับ)',
                text: deliveryText,
                color: Colors.redAccent,
              ),

              const SizedBox(height: 8),
              _OrderMiniMap(pickup: pickup, delivery: delivery),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _RiderProfilePageState.kPrimaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: onAccept,
                  child: accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("รับออเดอร์นี้", style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _addrCard({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title\n$text',
              style: const TextStyle(fontSize: 13.5, height: 1.35, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  static String _addressTextOrCoord(Map<String, dynamic> m) {
    final txt = (m['addressText'] ??
            m['AddressText'] ??
            m['address_text'] ??
            '')
        .toString()
        .trim();
    if (txt.isNotEmpty) return txt;

    final lat = (m['Latitude'] ?? m['latitude']) as num?;
    final lng = (m['Longitude'] ?? m['longitude']) as num?;
    if (lat != null && lng != null) {
      return '(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
    }
    return '-';
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}";
    }
    return "-";
  }
}

/// แผนที่ย่อของออเดอร์ (หมุดรับ/ส่ง + เส้นเชื่อม)
class _OrderMiniMap extends StatelessWidget {
  final Map<String, dynamic> pickup;
  final Map<String, dynamic> delivery;

  const _OrderMiniMap({
    required this.pickup,
    required this.delivery,
  });

  LatLng? _toLatLng(Map<String, dynamic> m) {
    final lat = (m['Latitude'] ?? m['latitude']) as num?;
    final lng = (m['Longitude'] ?? m['longitude']) as num?;
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final p1 = _toLatLng(pickup);
    final p2 = _toLatLng(delivery);
    final initial = p1 ?? p2 ?? const LatLng(13.7563, 100.5018);

    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: initial,
          initialZoom: 12,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.delivery',
          ),
          if (p1 != null && p2 != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [p1, p2],
                  strokeWidth: 3,
                  color: Colors.indigo.withAlpha((0.55 * 255).round()),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (p1 != null)
                Marker(
                  point: p1,
                  width: 44,
                  height: 44,
                  child: _pin(
                    color: Colors.orange,
                    icon: Icons.store_mall_directory_rounded,
                  ),
                ),
              if (p2 != null)
                Marker(
                  point: p2,
                  width: 44,
                  height: 44,
                  child: _pin(
                    color: Colors.redAccent,
                    icon: Icons.location_on_rounded,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pin({required Color color, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.18 * 255).round()),
            blurRadius: 8,
          )
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}
