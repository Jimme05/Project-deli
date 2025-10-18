// services/rider_location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class RiderLocationService {
  final String rid;
  StreamSubscription<Position>? _sub;

  RiderLocationService(this.rid);

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    if (!await _ensurePermission()) return;
    const settings = LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5);
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      await FirebaseDatabase.instance.ref('rider_locations/$rid').update({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<void> stop() async { await _sub?.cancel(); _sub = null; }
}
