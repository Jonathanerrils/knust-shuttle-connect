import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/entities/shuttle.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/repositories/shuttle_repository.dart';
import '../../domain/repositories/stop_repository.dart';
import '../../domain/usecases/cancel_check_in.dart';
import '../../domain/usecases/check_in_at_stop.dart';

class StudentController extends ChangeNotifier {
  static const _lastActionKey = 'last_checkin_action_at';

  final AppUser student;
  final StopRepository _stops;
  final CheckInRepository _checkIns;
  final ShuttleRepository _shuttles;
  final CheckInAtStop _checkInAtStop;
  final CompleteCheckIn _completeCheckIn;

  StreamSubscription<List<BusStop>>? _stopsSub;
  StreamSubscription<CheckIn?>? _checkInSub;
  StreamSubscription<Position>? _exitWatchSub;
  StreamSubscription<List<Shuttle>>? _shuttleSub;

  List<BusStop> stops = const [];
  bool stopsFromCacheOnly = true;
  DateTime? stopsUpdatedAt;
  Position? position;
  CheckIn? myCheckIn;
  List<Shuttle> shuttles = const [];
  String? locationError;
  bool workingOnCheckIn = false;
  String? selectedDestinationStopId;

  StudentController({
    required this.student,
    required StopRepository stopRepository,
    required CheckInRepository checkInRepository,
    required ShuttleRepository shuttleRepository,
  })  : _stops = stopRepository,
        _checkIns = checkInRepository,
        _shuttles = shuttleRepository,
        _checkInAtStop = CheckInAtStop(checkInRepository),
        _completeCheckIn = CompleteCheckIn(checkInRepository) {
    _init();
  }

  BusStop? get nearestStop {
    final pos = position;
    if (pos == null || stops.isEmpty) return null;
    BusStop? best;
    double bestDistance = double.infinity;
    for (final stop in stops) {
      final d = GeoUtils.distanceMeters(
          pos.latitude, pos.longitude, stop.latitude, stop.longitude);
      if (d < bestDistance) {
        bestDistance = d;
        best = stop;
      }
    }
    return best;
  }

  BusStop? get selectedDestination {
    final id = selectedDestinationStopId;
    if (id == null) return null;
    for (final stop in stops) {
      if (stop.id == id) return stop;
    }
    return null;
  }

  List<BusStop> destinationsFor(BusStop? boardingStop) => stops
      .where((stop) => stop.active && stop.id != boardingStop?.id)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  void selectDestination(String? stopId) {
    selectedDestinationStopId = stopId;
    notifyListeners();
  }

  BusStop? get checkedInStop {
    final c = myCheckIn;
    if (c == null) return null;
    for (final stop in stops) {
      if (stop.id == c.stopId) return stop;
    }
    return null;
  }

  int get peopleGoingMyWay {
    final checkIn = myCheckIn;
    final stop = checkedInStop;
    if (checkIn == null || stop == null) return 0;
    return stop.demandForDestination(checkIn.destinationStopId);
  }

  String? get activeDestinationStopId =>
      myCheckIn?.destinationStopId ?? selectedDestinationStopId;

  List<Shuttle> get compatibleShuttles {
    final destinationId = activeDestinationStopId;
    if (destinationId == null) return const <Shuttle>[];
    return shuttles
        .where((shuttle) => shuttle.canServeDestination(destinationId))
        .toList();
  }

  List<Shuttle> get assignmentUnknownShuttles =>
      shuttles.where((shuttle) => !shuttle.hasServiceAssignment).toList();

  Future<void> _init() async {
    stops = await _stops.getCachedStops();
    stopsUpdatedAt = await _stops.lastCacheTime();
    notifyListeners();

    _stopsSub = _stops.watchStops().listen((live) {
      stops = live;
      stopsFromCacheOnly = false;
      stopsUpdatedAt = DateTime.now();
      notifyListeners();
      unawaited(_stops.cacheStops(live));
    });

    _checkInSub = _checkIns.watchMyCheckIn(student.uid).listen((checkIn) {
      final hadCheckIn = myCheckIn != null;
      myCheckIn = checkIn;
      notifyListeners();
      if (checkIn != null) {
        _startGeofenceExitWatch(checkIn);
        _startShuttleWatch();
      } else if (hadCheckIn) {
        _stopGeofenceExitWatch();
        _stopShuttleWatch();
      }
    });

    unawaited(refreshLocation());
    unawaited(FirebaseMessaging.instance.requestPermission());
  }

  Future<void> refreshLocation() async {
    locationError = null;
    notifyListeners();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationError =
            'Location permission is needed to verify you are at a stop. '
            'You can still browse stops.';
        notifyListeners();
        return;
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      locationError = 'Could not get your location. Turn on GPS and retry.';
    }
    notifyListeners();
  }

  Future<String?> checkInAt(BusStop stop, BusStop destination) async {
    if (position == null) {
      await refreshLocation();
      if (position == null) {
        return locationError ?? 'Waiting for your location — try again.';
      }
    }
    workingOnCheckIn = true;
    notifyListeners();
    try {
      final result = await _checkInAtStop(
        uid: student.uid,
        stop: stop,
        destination: destination,
        latitude: position!.latitude,
        longitude: position!.longitude,
        lastActionAt: await _lastActionAt(),
      );
      if (result.isFailure) return result.error;
      await _recordAction();
      unawaited(FirebaseMessaging.instance
          .subscribeToTopic(AppConstants.stopTopic(stop.id)));
      return null;
    } finally {
      workingOnCheckIn = false;
      notifyListeners();
    }
  }

  Future<String?> markBoarded() => _completeWaiting(WaitingEndReason.boarded);

  Future<String?> cancelWaiting() =>
      _completeWaiting(WaitingEndReason.cancelled);

  Future<String?> _completeWaiting(WaitingEndReason reason) async {
    final current = myCheckIn;
    if (current == null) return null;
    workingOnCheckIn = true;
    notifyListeners();
    try {
      final result = await _completeCheckIn(student.uid, reason);
      if (result.isFailure) return result.error;
      unawaited(FirebaseMessaging.instance
          .unsubscribeFromTopic(AppConstants.stopTopic(current.stopId)));
      return null;
    } finally {
      workingOnCheckIn = false;
      notifyListeners();
    }
  }

  Future<String?> reportMissedBoarding() async {
    if (myCheckIn == null) return null;
    workingOnCheckIn = true;
    notifyListeners();
    try {
      await _checkIns.reportMissedBoarding(student.uid);
      return null;
    } catch (e) {
      return 'Could not record that the shuttle was full. ($e)';
    } finally {
      workingOnCheckIn = false;
      notifyListeners();
    }
  }

  void _startGeofenceExitWatch(CheckIn checkIn) {
    _exitWatchSub?.cancel();
    final stop = stops.where((s) => s.id == checkIn.stopId).firstOrNull;
    if (stop == null) return;
    _exitWatchSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: AppConstants.studentDistanceFilterMeters,
      ),
    ).listen((pos) {
      position = pos;
      notifyListeners();
      final distance = GeoUtils.distanceMeters(
          pos.latitude, pos.longitude, stop.latitude, stop.longitude);
      final exitThreshold =
          stop.geofenceRadiusMeters + AppConstants.geofenceExitBufferMeters;
      if (distance > exitThreshold) {
        unawaited(_completeWaiting(WaitingEndReason.geofenceExited));
      }
    });
  }

  void _stopGeofenceExitWatch() {
    _exitWatchSub?.cancel();
    _exitWatchSub = null;
  }

  void _startShuttleWatch() {
    _shuttleSub ??= _shuttles.watchOnDutyShuttles().listen((live) {
      shuttles = live;
      notifyListeners();
    });
  }

  void _stopShuttleWatch() {
    _shuttleSub?.cancel();
    _shuttleSub = null;
    shuttles = const [];
  }

  int? get etaMinutesToMyStop {
    final stop = checkedInStop;
    final candidates = compatibleShuttles;
    if (stop == null || candidates.isEmpty) return null;
    double best = double.infinity;
    for (final shuttle in candidates) {
      final eta = shuttle.etaMinutesTo(stop.latitude, stop.longitude);
      if (eta < best) best = eta;
    }
    return best.ceil();
  }

  Future<DateTime?> _lastActionAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastActionKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _recordAction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastActionKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _stopsSub?.cancel();
    _checkInSub?.cancel();
    _exitWatchSub?.cancel();
    _shuttleSub?.cancel();
    super.dispose();
  }
}
