import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color knustRed = Color(0xFFB5121B);
  static const Color knustGold = Color(0xFFFDB515);
  static const Color knustGreen = Color(0xFF006B3F);

  static const Color demandNone = Color(0xFF78909C);
  static const Color demandEmerging = Color(0xFF1976D2);
  static const Color demandNormal = Color(0xFF2E7D32);
  static const Color demandHigh = Color(0xFFF9A825);
  static const Color demandUrgent = Color(0xFFD32F2F);

  /// Provisional demand bands for the MVP. These are intentionally isolated
  /// here so they can later be calibrated against verified shuttle capacity.
  static Color demandColor(int waitingCount) {
    if (waitingCount <= 0) return demandNone;
    if (waitingCount <= 4) return demandEmerging;
    if (waitingCount <= 9) return demandNormal;
    if (waitingCount <= 19) return demandHigh;
    return demandUrgent;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.knustRed,
      secondary: AppColors.knustGold,
      tertiary: AppColors.knustGreen,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light
            ? AppColors.knustRed
            : scheme.surface,
        foregroundColor: brightness == Brightness.light
            ? Colors.white
            : scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
