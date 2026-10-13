import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The light theme for Home, Attendance entry, and the Upload Manager.
ThemeData buildLightTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.primary,
    // The design has one accent; map the other roles to it, not to M3's teal defaults.
    secondary: AppColors.primary,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.primaryContainer,
    onSecondaryContainer: AppColors.primary,
    tertiary: AppColors.primary,
    onTertiary: AppColors.onPrimary,
    tertiaryContainer: AppColors.primaryContainer,
    onTertiaryContainer: AppColors.primary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    surfaceContainer: AppColors.surfaceContainer,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    error: AppStatusColors.failed,
    errorContainer: AppStatusColors.failedContainer,
    onErrorContainer: AppStatusColors.failed,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppFonts.sans,
    textTheme: _textTheme,
    // Elevation and shape stay per card, so Card.outlined keeps its border.
    cardTheme: CardThemeData(
      color: AppColors.surface,
      // Approximates the design's light Level 1 shadow.
      shadowColor: AppColors.onSurface.withValues(alpha: 0.25),
    ),
    extensions: const [StatusColors.light],
  );
}

// Type scale from the design system; letter spacing converted from em to px.
const _textTheme = TextTheme(
  headlineLarge: TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
    color: AppColors.onSurface,
  ),
  titleLarge: TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    color: AppColors.onSurface,
  ),
  titleMedium: TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.onSurface,
  ),
  labelLarge: TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  ),
  bodyLarge: TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.onSurface,
  ),
  bodyMedium: TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.onSurface,
  ),
  labelMedium: TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.96,
  ),
  labelSmall: TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
  ),
);

/// A foreground color and its container (chip or badge background).
@immutable
class StatusColorPair {
  const StatusColorPair(this.color, this.container);

  final Color color;
  final Color container;

  static StatusColorPair lerp(StatusColorPair a, StatusColorPair b, double t) {
    return StatusColorPair(
      Color.lerp(a.color, b.color, t)!,
      Color.lerp(a.container, b.container, t)!,
    );
  }
}

/// Status colors for attendance range and upload states.
///
/// Read with `Theme.of(context).extension<StatusColors>()!`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.inRange,
    required this.outOfRange,
    required this.pending,
    required this.queued,
    required this.uploading,
    required this.synced,
    required this.failed,
  });

  static const light = StatusColors(
    inRange: StatusColorPair(
      AppStatusColors.inRange,
      AppStatusColors.inRangeContainer,
    ),
    outOfRange: StatusColorPair(
      AppStatusColors.outOfRange,
      AppStatusColors.outOfRangeContainer,
    ),
    pending: StatusColorPair(
      AppStatusColors.pending,
      AppStatusColors.pendingContainer,
    ),
    queued: StatusColorPair(
      AppStatusColors.queued,
      AppStatusColors.queuedContainer,
    ),
    uploading: StatusColorPair(
      AppStatusColors.uploading,
      AppStatusColors.uploadingContainer,
    ),
    synced: StatusColorPair(
      AppStatusColors.synced,
      AppStatusColors.syncedContainer,
    ),
    failed: StatusColorPair(
      AppStatusColors.failed,
      AppStatusColors.failedContainer,
    ),
  );

  final StatusColorPair inRange;
  final StatusColorPair outOfRange;
  final StatusColorPair pending;
  final StatusColorPair queued;
  final StatusColorPair uploading;
  final StatusColorPair synced;
  final StatusColorPair failed;

  @override
  StatusColors copyWith({
    StatusColorPair? inRange,
    StatusColorPair? outOfRange,
    StatusColorPair? pending,
    StatusColorPair? queued,
    StatusColorPair? uploading,
    StatusColorPair? synced,
    StatusColorPair? failed,
  }) {
    return StatusColors(
      inRange: inRange ?? this.inRange,
      outOfRange: outOfRange ?? this.outOfRange,
      pending: pending ?? this.pending,
      queued: queued ?? this.queued,
      uploading: uploading ?? this.uploading,
      synced: synced ?? this.synced,
      failed: failed ?? this.failed,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      inRange: StatusColorPair.lerp(inRange, other.inRange, t),
      outOfRange: StatusColorPair.lerp(outOfRange, other.outOfRange, t),
      pending: StatusColorPair.lerp(pending, other.pending, t),
      queued: StatusColorPair.lerp(queued, other.queued, t),
      uploading: StatusColorPair.lerp(uploading, other.uploading, t),
      synced: StatusColorPair.lerp(synced, other.synced, t),
      failed: StatusColorPair.lerp(failed, other.failed, t),
    );
  }
}
