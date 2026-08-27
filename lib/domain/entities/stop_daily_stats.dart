class StopDailyStats {
  final String stopId;
  final String date;
  final int total;
  final List<int> hourly;

  const StopDailyStats({
    required this.stopId,
    required this.date,
    required this.total,
    required this.hourly,
  });

  int? get peakHour {
    if (total == 0) return null;
    var best = 0;
    for (var h = 1; h < hourly.length; h++) {
      if (hourly[h] > hourly[best]) best = h;
    }
    return best;
  }

  int get peakCount => peakHour == null ? 0 : hourly[peakHour!];
}
