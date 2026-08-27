import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/stop_repository.dart';

class DriverController extends ChangeNotifier {
  final AppUser driver;
  final StopRepository _stops;
  final FirebaseFirestore _db;

  StreamSubscription<List<BusStop>>? _stopsSub;
  StreamSubscription<Position>? _dutySub;

  List<BusStop> stops = const [];
  bool sharingLocation = false;
  DateTime lastUpdate = DateTime.now();
  String? selectedDestinationStopId;

  DriverController({
    required this.driver,
    required StopRepository stopRepository,
    FirebaseFirestore? db,
  })  : _stops = stopRepository,
        _db = db ?? FirebaseFirestore.instance {
    _stopsSub = _stops.watchStops().listen((live) {
      stops = [...live]..sort(_compareDemand);
      lastUpdate = DateTime.now();
      notifyListeners();
    });
  }

  int relevantDemand(BusStop stop) =>
      stop.demandForDestination(selectedDestinationStopId);

  int _compareDemand(BusStop a, BusStop b) =>
      relevantDemand(b).compareTo(relevantDemand(a));

  Future<void> selectDestination(String? stopId) async {
    selectedDestinationStopId = stopId;
    stops = [...stops]..sort(_compareDemand);
    notifyListeners();
    await _shuttleDoc.set(<String, dynamic>{
      'servingDestinationStopId': stopId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool isMine(BusStop stop) => stop.enRouteBy == driver.uid;

  Future<void> markEnRoute(BusStop stop) =>
      _stops.markEnRoute(stop.id, driver.uid);

  Future<void> markArrived(BusStop stop) =>
      _stops.markArrived(stop.id, driver.uid);

  Future<void> clearEnRoute(BusStop stop) => _stops.clearEnRoute(stop.id);

  Future<void> setSharingLocation(bool enabled) async {
    if (enabled == sharingLocation) return;
    if (!enabled) {
      await _dutySub?.cancel();
      _dutySub = null;
      sharingLocation = false;
      notifyListeners();
      await _shuttleDoc.set(<String, dynamic>{
        'onDuty': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    sharingLocation = true;
    notifyListeners();
    _dutySub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.driverDistanceFilterMeters,
      ),
    ).listen((pos) {
      unawaited(_shuttleDoc.set(<String, dynamic>{
        'onDuty': true,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'servingDestinationStopId': selectedDestinationStopId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));
    });
  }

  DocumentReference<Map<String, dynamic>> get _shuttleDoc =>
      _db.collection('shuttles').doc(driver.uid);

  @override
  void dispose() {
    _stopsSub?.cancel();
    _dutySub?.cancel();
    super.dispose();
  }
}
