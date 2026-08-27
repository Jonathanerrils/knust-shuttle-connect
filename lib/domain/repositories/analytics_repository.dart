import '../entities/stop_daily_stats.dart';

abstract class AnalyticsRepository {
  Future<List<StopDailyStats>> statsForDate(DateTime date);
}
