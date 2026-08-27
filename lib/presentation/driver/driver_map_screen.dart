import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bus_stop.dart';
import '../common/map_markers.dart';
import 'driver_controller.dart';

class DriverMapScreen extends StatelessWidget {
  const DriverMapScreen({super.key});

  Future<Set<Marker>> _buildMarkers(
      BuildContext context, List<BusStop> stops) async {
    final controller = context.read<DriverController>();
    final markers = <Marker>{};
    for (final stop in stops) {
      final demand = controller.relevantDemand(stop);
      markers.add(Marker(
        markerId: MarkerId('stop-${stop.id}'),
        position: LatLng(stop.latitude, stop.longitude),
        icon: await MapMarkers.countBadge(
          demand,
          AppColors.demandColor(demand),
        ),
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: stop.name,
          snippet: controller.isMine(stop)
              ? 'You are en route — tap your list to update'
              : controller.selectedDestinationStopId == null
                  ? '$demand total waiting · tap here to go en route'
                  : '$demand waiting for your selected destination · tap here to go en route',
          onTap: controller.isMine(stop)
              ? null
              : () => controller.markEnRoute(stop),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DriverController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.selectedDestinationStopId == null
            ? 'Demand map'
            : 'Route-specific demand map'),
      ),
      body: FutureBuilder<Set<Marker>>(
        future: _buildMarkers(context, controller.stops),
        builder: (context, snapshot) => GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(
                AppConstants.campusCenterLat, AppConstants.campusCenterLng),
            zoom: AppConstants.campusDefaultZoom,
          ),
          markers: snapshot.data ?? const <Marker>{},
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}
