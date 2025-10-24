import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter_map/flutter_map.dart';

import '../models/address.dart';
import '../models/order_create_request.dart';
import '../services/address_service.dart';
import '../services/order_service.dart';
import 'map_picker_page.dart';

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  static const Color kGreen = Color(0xFF6AA56F);

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  LatLng? _picked;              // จุดปลายทาง (ผู้รับ)
  LatLng? _pickupPoint;         // จุดรับ (ผู้ส่ง - default address)
  String? _pickupText;          // ข้อความที่อยู่ผู้ส่ง

  final _map = MapController(); // คุมกล้องแผนที่พรีวิว
  File? _selectedImage;
  final _picker = ImagePicker();
  bool _loading = false;

  final _addressService = AddressService();

  @override
  void initState() {
    super.initState();
    _loadDefaultPickup(); // โหลดบ้าน/จุดรับของผู้ส่ง เพื่อแสดงบนแผนที่
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ---------- utils ----------
  /// แปลงเบอร์เป็นมาตรฐานไทยไม่ใส่ + (E.164 without +)
  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return digits;
    if (digits.startsWith('66')) return digits;
    if (digits.startsWith('0')) return '66${digits.substring(1)}';
    if (digits.length == 9 || digits.length == 10) return '66$digits';
    return digits;
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _openMapPicker() async {
    final initial = _picked ?? _pickupPoint ?? const LatLng(13.7563, 100.5018);
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage(initial: initial)),
    );

    if (result != null) {
      setState(() {
        _picked = result.latlng;
        _locationCtrl.text =
            "${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}";
        if ((result.address ?? '').isNotEmpty &&
            _descCtrl.text.trim().isEmpty) {
          _descCtrl.text = result.address!;
        }
      });
      // ปรับกล้องให้เห็นทั้ง pickup และ delivery
      _fitMapToPins();
    }
  }

  /// โหลดที่อยู่ default ของผู้ส่งไว้โชว์บนแผนที่
  Future<void> _loadDefaultPickup() async {
    try {
      final u = fa.FirebaseAuth.instance.currentUser;
      if (u == null) return;

      final addrSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (addrSnap.docs.isNotEmpty) {
        final a = addrSnap.docs.first.data();
        final lat = (a['Latitude'] as num?)?.toDouble();
        final lng = (a['Longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() {
            _pickupPoint = LatLng(lat, lng);
            _pickupText = (a['addressText'] ?? 'ที่อยู่ผู้ส่ง').toString();
          });
          // ถ้ายังไม่มีปลายทาง ให้ซูมไปที่จุดรับก่อน
          if (_picked == null) {
            _map.move(_pickupPoint!, 13);
          } else {
            _fitMapToPins();
          }
        }
      }
    } catch (_) {
      // เงียบไว้ก็ได้
    }
  }

  /// ปรับกล้องให้เห็นทั้ง pickup + delivery
  void _fitMapToPins() {
    if (_pickupPoint == null && _picked == null) return;
    if (_pickupPoint != null && _picked != null) {
      final south = _pickupPoint!.latitude <= _picked!.latitude ? _pickupPoint! : _picked!;
      final north = _pickupPoint!.latitude >  _picked!.latitude ? _pickupPoint! : _picked!;
      final west  = _pickupPoint!.longitude <= _picked!.longitude ? _pickupPoint! : _picked!;
      final east  = _pickupPoint!.longitude >  _picked!.longitude ? _pickupPoint! : _picked!;
      final center = LatLng(
        (south.latitude + north.latitude) / 2,
        (west.longitude + east.longitude) / 2,
      );
      _map.move(center, 12);
    } else {
      _map.move((_pickupPoint ?? _picked)!, 13);
    }
  }

  // ✅ เลือกรายชื่อผู้รับ (รายชื่อ user ทั้งหมด)
  Future<void> _chooseReceiverFromUsers() async {
    try {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ยังไม่ได้เข้าสู่ระบบ')));
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();

      final filteredDocs =
          snapshot.docs.where((doc) => doc.id != currentUser.uid).toList();

      if (filteredDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีผู้ใช้ User คนอื่นในระบบ')),
        );
        return;
      }

      final chosenUser = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'เลือกรายชื่อผู้รับ (เฉพาะ User)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final data = filteredDocs[i].data();
                      final name = data['name'] ?? '-';
                      final phone = data['phone'] ?? '-';
                      final img = data['photoUrl'] ?? data['profileUrl'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              img != null ? NetworkImage(img) : null,
                          child: img == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                          backgroundColor: Colors.grey.shade400,
                        ),
                        title: Text(name),
                        subtitle: Text('เบอร์: $phone'),
                        onTap: () => Navigator.pop(context, {
                          'uid': filteredDocs[i].id,
                          'name': name,
                          'phone': phone,
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (chosenUser == null) return;

      final addressSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(chosenUser['uid'])
          .collection('addresses')
          .get();

      if (addressSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ผู้ใช้ ${chosenUser['name']} ยังไม่มีที่อยู่')),
        );
        return;
      }

      final chosenAddress = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'เลือกที่อยู่ผู้รับ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    itemCount: addressSnap.docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = addressSnap.docs[i].data();
                      final lat = (a['Latitude'] as num?)?.toDouble();
                      final lng = (a['Longitude'] as num?)?.toDouble();
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.teal),
                        title: Text(a['label'] ?? 'ที่อยู่'),
                        subtitle: Text(a['addressText'] ?? '-'),
                        trailing: Text(
                          lat != null && lng != null
                              ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                              : '-',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(context, a),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (chosenAddress == null) return;

      setState(() {
        _nameCtrl.text = chosenUser['name'];
        _phoneCtrl.text = chosenUser['phone'];
        _descCtrl.text = chosenAddress['addressText'] ?? '';
        final lat = (chosenAddress['Latitude'] as num?)?.toDouble();
        final lng = (chosenAddress['Longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _picked = LatLng(lat, lng);
          _locationCtrl.text =
              "${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}";
        }
      });
      _fitMapToPins();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  /// ✅ ค้นหาผู้รับจาก “เบอร์โทร” โดยตรง
  Future<void> _findReceiverByPhone() async {
    final phoneRaw = _phoneCtrl.text.trim();
    if (phoneRaw.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรอกเบอร์ผู้รับก่อน')));
      return;
    }

    try {
      final phoneNorm = _normalizePhone(phoneRaw);

      QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .where('phone_norm', isEqualTo: phoneNorm)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phoneRaw)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบผู้ใช้ที่ลงทะเบียนด้วยเบอร์นี้')),
        );
        return;
      }

      final userDoc = snap.docs.first;
      final userData = userDoc.data();
      final displayName = (userData['name'] ?? '-').toString();
      final displayPhone = (userData['phone'] ?? phoneRaw).toString();

      final addrSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('addresses')
          .get();

      if (addrSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ผู้ใช้ $displayName ยังไม่มีที่อยู่')));
        return;
      }

      final chosenAddress = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('เลือกที่อยู่ของ $displayName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    itemCount: addrSnap.docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = addrSnap.docs[i].data();
                      final lat = (a['Latitude'] as num?)?.toDouble();
                      final lng = (a['Longitude'] as num?)?.toDouble();
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.teal),
                        title: Text(a['label'] ?? 'ที่อยู่'),
                        subtitle: Text(a['addressText'] ?? '-'),
                        trailing: Text(
                          lat != null && lng != null
                              ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                              : '-',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(context, a),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (chosenAddress == null) return;

      setState(() {
        _nameCtrl.text = displayName;
        _phoneCtrl.text = displayPhone;
        _descCtrl.text = chosenAddress['addressText'] ?? '';
        final lat = (chosenAddress['Latitude'] as num?)?.toDouble();
        final lng = (chosenAddress['Longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _picked = LatLng(lat, lng);
          _locationCtrl.text =
              "${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}";
        }
      });
      _fitMapToPins();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ค้นหาจากเบอร์ล้มเหลว: $e')));
    }
  }

  // ---------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final hasPickup = _pickupPoint != null;
    final hasDelivery = _picked != null;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'เพิ่มที่อยู่ผู้รับใหม่',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // แผนที่พรีวิว (แสดงจุดรับ + จุดผู้รับ + เส้นเชื่อม)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _pickupPoint ?? _picked ?? const LatLng(13.7563, 100.5018),
                    initialZoom: 12,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      // ไม่ใช้ subdomains เพื่อลด warning ของ OSM
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.delivery',
                    ),
                    if (hasPickup && hasDelivery)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_pickupPoint!, _picked!],
                            strokeWidth: 3.0,
                            color: Colors.indigo.withOpacity(0.55),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (hasPickup)
                          Marker(
                            point: _pickupPoint!,
                            width: 56,
                            height: 56,
                            child: _pin(
                              color: Colors.orange,
                              icon: Icons.store_mall_directory_rounded,
                              label: 'รับ',
                            ),
                          ),
                        if (hasDelivery)
                          Marker(
                            point: _picked!,
                            width: 56,
                            height: 56,
                            child: _pin(
                              color: Colors.redAccent,
                              icon: Icons.location_on_rounded,
                              label: 'ส่ง',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (_pickupText != null)
                Text('🚚 จุดรับ: $_pickupText', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (_locationCtrl.text.isNotEmpty)
                Text('📍 ปลายทาง: ${_locationCtrl.text}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ตัวช่วยที่อยู่', style: TextStyle(fontSize: 16)),
                  InkWell(
                    onTap: _openMapPicker,
                    child: const Text(
                      'เลือกจากแผนที่',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 12),

              _buildTextField(_nameCtrl, 'ชื่อผู้รับ', TextInputType.name),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'เบอร์โทรศัพท์ผู้รับ',
                        filled: true,
                        fillColor: Colors.grey.shade300,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'ค้นหาผู้รับจากเบอร์',
                          icon: const Icon(Icons.search),
                          onPressed: _findReceiverByPhone,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _chooseReceiverFromUsers,
                    child: const Text('เลือกรายชื่อผู้รับ'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildTextField(
                _locationCtrl,
                'โปรดเลือกพิกัดปลายทาง',
                TextInputType.text,
                readOnly: true,
              ),
              const SizedBox(height: 10),

              _buildTextField(
                _descCtrl,
                'รายละเอียดที่อยู่ผู้รับ',
                TextInputType.multiline,
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _selectedImage == null
                            ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('แนบรูป (สถานะ [1] รอไรเดอร์มารับ)'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('สำเร็จ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _picked == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรอกชื่อ/เบอร์/เลือกพิกัดให้ครบ')));
      return;
    }

    setState(() => _loading = true);
    try {
      final u = fa.FirebaseAuth.instance.currentUser;
      if (u == null) throw Exception("ยังไม่ได้ล็อกอิน");

      // จุดรับของผู้ส่ง
      final addrSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();
      if (addrSnap.docs.isEmpty) {
        throw Exception("ไม่พบบ้าน/จุดรับของผู้ส่ง (โปรดเพิ่มที่อยู่หลักก่อน)");
      }

      final a = addrSnap.docs.first.data();
      final pickup = Address(
        id: addrSnap.docs.first.id,
        label: a['label'] ?? 'บ้าน',
        addressText: a['addressText'] ?? '',
        latitude: (a['Latitude'] as num).toDouble(),
        longitude: (a['Longitude'] as num).toDouble(),
      );

      // ปลายทาง "ผู้รับ"
      final delivery = Address(
        id: '',
        label: "ปลายทาง",
        addressText: _descCtrl.text.trim(),
        latitude: _picked!.latitude,
        longitude: _picked!.longitude,
      );

      // หา Uid_receiver จากเบอร์ผู้รับ
      final phoneRaw = _phoneCtrl.text.trim();
      final phoneNorm = _normalizePhone(phoneRaw);

      String receiverUid = "";
      String receiverName = _nameCtrl.text.trim();

      final usersByNorm = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_norm', isEqualTo: phoneNorm)
          .limit(1)
          .get();

      if (usersByNorm.docs.isNotEmpty) {
        receiverUid = usersByNorm.docs.first.id;
        receiverName =
            (usersByNorm.docs.first.data()['name'] ?? receiverName).toString();
      } else {
        final usersByPhone = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phoneRaw)
            .limit(1)
            .get();
        if (usersByPhone.docs.isNotEmpty) {
          receiverUid = usersByPhone.docs.first.id;
          receiverName =
              (usersByPhone.docs.first.data()['name'] ?? receiverName).toString();
        }
      }

      final req = OrderCreateRequest(
        senderUid: u.uid,
        receiverUid: receiverUid,
        receiverPhone: phoneRaw,
        receiverName: receiverName,
        pickupAddress: pickup,
        deliveryAddress: delivery,
        description: _descCtrl.text.trim(),
        status1ImageFile: _selectedImage,
      );

      final oid = await OrderService().createOrder(req);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade600,
          content: Text('✅ สร้างออเดอร์สำเร็จ (OID: $oid)'),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    TextInputType type, {
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: type,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade300,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ----- small UI helpers -----
  Widget _pin({required Color color, required IconData icon, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8)],
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8)],
          ),
          child: Icon(icon, color: color),
        ),
      ],
    );
  }
}
