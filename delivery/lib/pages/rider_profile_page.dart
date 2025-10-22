import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/pages/rider_accepted_orders_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
    if (!await Geolocator.isLocationServiceEnabled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเปิด Location Service')),
      );
      return false;
    }

    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่ได้รับสิทธิ์ตำแหน่ง')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e')),
      );
    }
  }

  Future<void> _startLocationStream(String orderId) async {
    if (_posSub != null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final p2 = await Geolocator.requestPermission();
      if (p2 == LocationPermission.denied ||
          p2 == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่ได้รับสิทธิ์ตำแหน่ง: ไม่สามารถแชร์พิกัดได้'),
          ),
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
    }

    _posSub =
        Geolocator.getPositionStream(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'คุณมีงานค้างอยู่ กรุณาส่งงานเดิมให้เสร็จก่อนรับงานใหม่',
            ),
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
        const SnackBar(
          content: Text('✅ รับออเดอร์สำเร็จ และเริ่มแชร์พิกัดเรียลไทม์'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ รับออเดอร์ไม่สำเร็จ: $e')));
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
        automaticallyImplyLeading: false, // ❌ ไม่ให้แสดงปุ่มย้อนกลับ
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
              final status = (snap.data?.data()?['Status-rider'] ?? 'idle')
                  .toString();
              final busy = status != 'idle';
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: busy ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  busy ? 'สถานะ: ไม่ว่าง' : 'สถานะ: ว่าง',
                  style: TextStyle(
                    color: busy
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // Logout ปุ่มล่าง
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

      // เนื้อหา
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
                (riderData['license'] ??
                        riderData['vehiclePlate'] ??
                        'ไม่ระบุทะเบียน')
                    .toString();
            final photoUrl =
                (riderData['photoUrl'] ??
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
                    // Profile header
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

                    // ปุ่มไปดูออเดอร์ที่รับแล้ว
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
                          child: Text(
                            'ยังไม่มีออเดอร์รอรับในตอนนี้',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      ...allOrders.map((doc) {
                        final data = doc.data();
                        final oid = doc.id;
                        final receiver = (data['Name'] ?? '-').toString();
                        final phone = (data['receiver_phone'] ?? '-')
                            .toString();
                        final addr =
                            (data['delivery_address']?['addressText'] ?? '-')
                                .toString();
                        final created = _formatDate(data['created_at']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "📦 Order ID: $oid",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("ผู้รับ: $receiver"),
                              Text("เบอร์: $phone"),
                              Text("ที่อยู่: $addr"),
                              Text("วันที่สร้าง: $created"),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: _startingShare
                                      ? null
                                      : () => _acceptOrder(oid),
                                  child: _startingShare
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "รับออเดอร์นี้",
                                          style: TextStyle(fontSize: 15),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}";
    }
    return "-";
  }
}
