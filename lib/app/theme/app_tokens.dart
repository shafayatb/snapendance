import 'package:flutter/painting.dart';

// Light design tokens from docs/design/Design System.dc.html (script renderVals()).
// AttendanceTokens.kt holds the same names and values for Compose; change both together.
// The Android window background (attendance_background in android/app/src/main/res/values/
// colors.xml) repeats `background`.

abstract final class AppColors {
  static const background = Color(0xFFEEF2F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFF3F6FA);
  static const onSurface = Color(0xFF13224A);
  static const onSurfaceVariant = Color(0xFF56627A);
  static const outline = Color(0xFFC5CEDC);
  static const outlineVariant = Color(0xFFDDE3EC);
  static const primary = Color(0xFF1D5BD6);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFDCE6FB);
  static const disabledContainer = Color(0xFFDCE2EA);
  static const onDisabled = Color(0xFF5F6B80);
}

/// Foreground and container color for each status in the light scheme.
abstract final class AppStatusColors {
  static const inRange = Color(0xFF17804A);
  static const inRangeContainer = Color(0xFFDDF3E6);
  static const outOfRange = Color(0xFFC0262D);
  static const outOfRangeContainer = Color(0xFFFCE4E4);
  static const pending = Color(0xFF9A5B00);
  static const pendingContainer = Color(0xFFFCEFD6);
  static const queued = Color(0xFF56627A);
  static const queuedContainer = Color(0xFFE3E8F0);
  static const uploading = Color(0xFF1D5BD6);
  static const uploadingContainer = Color(0xFFDCE6FB);
  static const synced = Color(0xFF17804A);
  static const syncedContainer = Color(0xFFDDF3E6);
  static const failed = Color(0xFFC0262D);
  static const failedContainer = Color(0xFFFCE4E4);
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
}

abstract final class AppFonts {
  static const sans = 'IBM Plex Sans';
  static const mono = 'IBM Plex Mono';
}
