import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/address.dart';
import '../services/address_service.dart';

class ManageAddressesPage extends StatefulWidget {
  const ManageAddressesPage({super.key});
  @override
  State<ManageAddressesPage> createState() => _ManageAddressesPageState();
}

class _ManageAddressesPageState extends State<ManageAddressesPage> {
  final _svc = AddressService();
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = fa.FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _goToAdd() async {
    await Navigator.pushNamed(context, '/edit_address'); // ➜ ไปหน้าเพิ่ม/แก้ที่อยู่
    if (mounted) setState(() {}); // กลับมาแล้วรีเฟรชลิสต์
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ที่อยู่ของฉัน')),
      body: FutureBuilder<List<Address>>(
        future: _svc.list(_uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: _goToAdd,
                child: const Text('เพิ่มที่อยู่แรก'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = items[i];
              return ListTile(
                leading: Icon(
                  a.isDefault ? Icons.star_rounded : Icons.place_rounded,
                  color: a.isDefault ? Colors.amber : Colors.black54,
                ),
                title: Text(a.label),
                subtitle: Text(a.addressText),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'default') {
                      await _svc.setDefault(_uid, a.id);
                    } else if (v == 'delete') {
                      await _svc.delete(_uid, a.id);
                    }
                    if (mounted) setState(() {});
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'default', child: Text('ตั้งเป็นค่าเริ่มต้น')),
                    PopupMenuItem(value: 'delete', child: Text('ลบที่อยู่นี้')),
                  ],
                ),
                onTap: () async {
                  // ถ้าจะ “แก้ไขที่อยู่เดิม” แนะนำทำหน้า edit ที่รับพารามิเตอร์ addressId
                  // ตอนนี้พาไปหน้าเพิ่ม/แก้แบบเดิมก่อน
                  await Navigator.pushNamed(context, '/edit_address');
                  if (mounted) setState(() {});
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAdd, // ➜ ไป /edit_address เลย
        child: const Icon(Icons.add),
      ),
    );
  }
}
