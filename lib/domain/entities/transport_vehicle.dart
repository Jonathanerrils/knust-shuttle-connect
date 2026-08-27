class TransportVehicle {
  final String id;
  final String operatorId;
  final String? fleetNumber;
  final String? vehicleType;
  final int seatedCapacity;
  final int standingCapacity;
  final bool active;

  const TransportVehicle({
    required this.id,
    required this.operatorId,
    this.fleetNumber,
    this.vehicleType,
    required this.seatedCapacity,
    this.standingCapacity = 0,
    this.active = true,
  });

  int get safeCapacity => seatedCapacity + standingCapacity;
}
