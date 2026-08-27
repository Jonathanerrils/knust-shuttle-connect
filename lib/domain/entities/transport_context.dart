class TransportContext {
  final String countryId;
  final String cityId;
  final String networkId;
  final String operatorId;

  const TransportContext({
    required this.countryId,
    required this.cityId,
    required this.networkId,
    required this.operatorId,
  });

  Map<String, String> toMap() => <String, String>{
        'countryId': countryId,
        'cityId': cityId,
        'networkId': networkId,
        'operatorId': operatorId,
      };
}
