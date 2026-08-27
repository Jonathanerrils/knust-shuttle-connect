import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/shuttle.dart';
import '../../domain/repositories/shuttle_repository.dart';
import '../common/map_markers.dart';
import 'student_controller.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  late final Stream<List<Shuttle>> _shuttles;

  @override
  void initState() {
    super.initState();
    _shuttles = context.read<ShuttleRepository>().watchOnDutyShuttles();
  }

  bool _isCompatible(StudentController controller, Shuttle shuttle) {
    final destinationId = controller.activeDestinationStopId;
    return destinationId != null && shuttle.canServeDestination(destinationId);
  }

  Future<Set<Marker>> _buildMarkers(
    StudentController controller,
    List<BusStop> stops,
    List<Shuttle> shuttles,
  ) async {
    final markers = <Marker>{};
    for (final stop in stops) {
      markers.add(Marker(
        markerId: MarkerId('stop-${stop.id}'),
        position: LatLng(stop.latitude, stop.longitude),
        icon: await MapMarkers.countBadge(
            stop.waitingCount, AppColors.demandColor(stop.waitingCount)),
        infoWindow: InfoWindow(
          title: stop.name,
          snippet: '${stop.waitingCount} waiting'
              '${stop.hasShuttleEnRoute ? ' · shuttle on the way' : ''}',
        ),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    for (final shuttle in shuttles) {
      final compatible = _isCompatible(controller, shuttle);
      final assignmentKnown = shuttle.hasServiceAssignment;
      final hue = compatible
          ? BitmapDescriptor.hueGreen
          : assignmentKnown
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueViolet;
      final serviceStatus = compatible
          ? 'Compatible with your destination'
          : assignmentKnown
              ? 'Serving another destination'
              : 'Service assignment not confirmed';
      final occupancy = shuttle.occupancyEstimate();
      final occupancyText = compatible
          ? ' · ${occupancy.label} (${occupancy.confidenceLabel} confidence)'
          : '';

      markers.add(Marker(
        markerId: MarkerId('shuttle-${shuttle.id}'),
        position: LatLng(shuttle.latitude, shuttle.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: compatible ? 'Compatible shuttle' : 'Active shuttle',
          snippet: '$serviceStatus$occupancyText',
        ),
        rotation: shuttle.headingDegrees ?? 0,
      ));
    }
    return markers;
  }

  String? _etaText(StudentController controller, List<Shuttle> shuttles) {
    final stop = controller.checkedInStop ?? controller.nearestStop;
    final destinationId = controller.activeDestinationStopId;
    if (stop == null || destinationId == null) return null;

    final compatible = shuttles
        .where((shuttle) => shuttle.canServeDestination(destinationId))
        .toList();
    if (compatible.isEmpty) {
      return 'No currently assigned shuttle is confirmed for your destination.';
    }

    Shuttle? bestShuttle;
    double best = double.infinity;
    for (final shuttle in compatible) {
      final eta = shuttle.etaMinutesTo(stop.latitude, stop.longitude);
      if (eta < best) {
        best = eta;
        bestShuttle = shuttle;
      }
    }
    final minutes = best.ceil();
    final occupancy = bestShuttle?.occupancyEstimate();
    final occupancySuffix = occupancy == null
        ? ''
        : ' · ${occupancy.label} (${occupancy.confidenceLabel})';
    return minutes <= 1
        ? 'Compatible shuttle ~1 min from ${stop.name}$occupancySuffix'
        : 'Compatible shuttle ~$minutes min from ${stop.name}$occupancySuffix';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StudentController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Campus map')),
      body: StreamBuilder<List<Shuttle>>(
        stream: _shuttles,
        builder: (context, snapshot) {
          final shuttles = snapshot.data ?? const <Shuttle>[];
          final eta = _etaText(controller, shuttles);
          return FutureBuilder<Set<Marker>>(
            future: _buildMarkers(controller, controller.stops, shuttles),
            builder: (context, markerSnapshot) => Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(AppConstants.campusCenterLat,
                        AppConstants.campusCenterLng),
                    zoom: AppConstants.campusDefaultZoom,
                  ),
                  markers: markerSnapshot.data ?? const <Marker>{},
                  myLocationEnabled: controller.locationError == null,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),
                if (eta != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_bus,
                                color: AppColors.knustRed),
                            const SizedBox(width: 10),
                            Expanded(child: Text(eta)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
