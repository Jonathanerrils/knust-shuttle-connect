import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/repositories/shuttle_repository.dart';
import '../../domain/repositories/stop_repository.dart';
import '../auth/auth_controller.dart';
import '../common/last_updated_banner.dart';
import 'stop_picker_sheet.dart';
import 'student_controller.dart';
import 'student_info_cards.dart';
import 'student_map_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  final AppUser student;

  const StudentHomeScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StudentController(
        student: student,
        stopRepository: ctx.read<StopRepository>(),
        checkInRepository: ctx.read<CheckInRepository>(),
        shuttleRepository: ctx.read<ShuttleRepository>(),
      ),
      child: const _StudentHomeView(),
    );
  }
}

class _StudentHomeView extends StatelessWidget {
  const _StudentHomeView();

  Future<void> _showError(BuildContext context, String? error) async {
    if (error == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StudentController>();
    final checkIn = controller.myCheckIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KNUST Shuttle Connect'),
        actions: [
          IconButton(
            tooltip: 'Campus map',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: controller,
                child: const StudentMapScreen(),
              ),
            )),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthController>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LastUpdatedBanner(
              fromCacheOnly: controller.stopsFromCacheOnly,
              updatedAt: controller.stopsUpdatedAt,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (checkIn == null)
                    _NotCheckedIn(controller: controller, onError: _showError)
                  else
                    _CheckedIn(controller: controller, onError: _showError),
                  const SizedBox(height: 16),
                  const SafetyTipCard(),
                  const SizedBox(height: 10),
                  const SponsoredSlotCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotCheckedIn extends StatelessWidget {
  final StudentController controller;
  final Future<void> Function(BuildContext, String?) onError;

  const _NotCheckedIn({required this.controller, required this.onError});

  @override
  Widget build(BuildContext context) {
    final nearest = controller.nearestStop;
    final destinations = controller.destinationsFor(nearest);
    final destination = controller.selectedDestination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.locationError != null) ...[
          Text(controller.locationError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.refreshLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Retry location'),
          ),
          const SizedBox(height: 16),
        ],
        Text('Boarding stop', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          nearest?.name ?? 'Finding your nearest stop…',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (nearest != null)
          Text('${nearest.waitingCount} people currently checked in here'),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: destination?.id,
          decoration: const InputDecoration(
            labelText: 'Where are you going?',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          items: [
            for (final stop in destinations)
              DropdownMenuItem(value: stop.id, child: Text(stop.name)),
          ],
          onChanged: controller.selectDestination,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 82,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.knustRed,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            onPressed: nearest == null ||
                    destination == null ||
                    controller.workingOnCheckIn
                ? null
                : () async {
                    final error = await controller.checkInAt(nearest, destination);
                    if (error != null && context.mounted) {
                      await onError(context, error);
                    }
                  },
            icon: const Icon(Icons.front_hand, size: 30),
            label: const Text("I'm Waiting Here"),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: controller.stops.isEmpty
              ? null
              : () async {
                  final stop = await showStopPicker(
                    context,
                    stops: controller.stops,
                    position: controller.position,
                  );
                  if (stop == null || !context.mounted) return;
                  final chosenDestination = await _chooseDestination(
                    context,
                    controller.destinationsFor(stop),
                  );
                  if (chosenDestination == null || !context.mounted) return;
                  final error =
                      await controller.checkInAt(stop, chosenDestination);
                  if (error != null && context.mounted) {
                    await onError(context, error);
                  }
                },
          child: const Text('Choose a different boarding stop'),
        ),
      ],
    );
  }

  Future<BusStop?> _chooseDestination(
      BuildContext context, List<BusStop> destinations) {
    return showModalBottomSheet<BusStop>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text('Where are you going?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final stop in destinations)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(stop.name),
                onTap: () => Navigator.of(ctx).pop(stop),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckedIn extends StatelessWidget {
  final StudentController controller;
  final Future<void> Function(BuildContext, String?) onError;

  const _CheckedIn({required this.controller, required this.onError});

  @override
  Widget build(BuildContext context) {
    final checkIn = controller.myCheckIn!;
    final compatible = controller.compatibleShuttles.length;
    final compatibleEnRoute = controller.compatibleShuttleEnRouteToMyStop;
    final compatibleAtStop = controller.compatibleShuttleAtMyStop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 68, color: AppColors.knustGreen),
        const SizedBox(height: 12),
        Text(
          '${checkIn.stopName} → ${checkIn.destinationStopName}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${controller.peopleGoingMyWay} ${controller.peopleGoingMyWay == 1 ? 'person is' : 'people are'} going your way',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          compatible == 0
              ? 'No currently assigned shuttle is confirmed for your destination.'
              : '$compatible active ${compatible == 1 ? 'shuttle is' : 'shuttles are'} assigned to your destination.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (compatibleEnRoute) ...[
          const SizedBox(height: 10),
          Chip(
            avatar: const Icon(Icons.directions_bus, size: 18),
            label: Text(controller.etaMinutesToMyStop == null
                ? 'A compatible shuttle is on its way to this stop'
                : 'Compatible shuttle ~${controller.etaMinutesToMyStop} min away'),
          ),
        ],
        if (compatibleAtStop) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Your compatible shuttle has arrived. Did you get on?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: controller.workingOnCheckIn
                        ? null
                        : () async {
                            final error = await controller.reportMissedBoarding();
                            if (error != null && context.mounted) {
                              await onError(context, error);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Recorded. You remain in the waiting queue.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.no_transfer),
                    label: const Text("Couldn't board — keep me waiting"),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (checkIn.missedBoardingCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            'You have reported ${checkIn.missedBoardingCount} missed ${checkIn.missedBoardingCount == 1 ? 'boarding' : 'boardings'} during this wait.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Expires ${DateFormat.jm().format(checkIn.expiresAt)} if you are still waiting. Leaving the stop records a geofence exit.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.knustGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: controller.workingOnCheckIn
              ? null
              : () async {
                  final error = await controller.markBoarded();
                  if (error != null && context.mounted) {
                    await onError(context, error);
                  }
                },
          icon: const Icon(Icons.directions_bus_filled),
          label: const Text('I boarded'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.workingOnCheckIn
              ? null
              : () async {
                  final error = await controller.cancelWaiting();
                  if (error != null && context.mounted) {
                    await onError(context, error);
                  }
                },
          icon: const Icon(Icons.close),
          label: const Text('Cancel waiting'),
        ),
      ],
    );
  }
}
