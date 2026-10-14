package com.shafayatb.snapendance.attendance.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

@Composable
fun AttendanceTheme(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalStatusColors provides StatusColors.Light) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = typography,
            content = content,
        )
    }
}

object AttendanceTheme {
    val statusColors: StatusColors
        @Composable
        @ReadOnlyComposable
        get() = LocalStatusColors.current
}

private val colorScheme = lightColorScheme(
    primary = AttendanceColors.primary,
    onPrimary = AttendanceColors.onPrimary,
    primaryContainer = AttendanceColors.primaryContainer,
    onPrimaryContainer = AttendanceColors.primary,
    secondary = AttendanceColors.primary,
    onSecondary = AttendanceColors.onPrimary,
    secondaryContainer = AttendanceColors.primaryContainer,
    onSecondaryContainer = AttendanceColors.primary,
    tertiary = AttendanceColors.primary,
    onTertiary = AttendanceColors.onPrimary,
    tertiaryContainer = AttendanceColors.primaryContainer,
    onTertiaryContainer = AttendanceColors.primary,
    background = AttendanceColors.background,
    onBackground = AttendanceColors.onSurface,
    surface = AttendanceColors.surface,
    onSurface = AttendanceColors.onSurface,
    onSurfaceVariant = AttendanceColors.onSurfaceVariant,
    surfaceContainer = AttendanceColors.surfaceContainer,
    surfaceVariant = AttendanceColors.surface,
    surfaceDim = AttendanceColors.surface,
    surfaceBright = AttendanceColors.surface,
    surfaceContainerLowest = AttendanceColors.surface,
    surfaceContainerLow = AttendanceColors.surface,
    surfaceContainerHigh = AttendanceColors.surface,
    surfaceContainerHighest = AttendanceColors.surface,
    inverseSurface = AttendanceColors.onSurface,
    inverseOnSurface = AttendanceColors.surface,
    inversePrimary = AttendanceColors.onPrimary,
    outline = AttendanceColors.outline,
    outlineVariant = AttendanceColors.outlineVariant,
    error = AttendanceStatusColors.failed,
    errorContainer = AttendanceStatusColors.failedContainer,
    onErrorContainer = AttendanceStatusColors.failed,
)

private val defaults = Typography()

private val typography = Typography(
    displayLarge = defaults.displayLarge.copy(fontFamily = AttendanceFonts.sans),
    displayMedium = defaults.displayMedium.copy(fontFamily = AttendanceFonts.sans),
    displaySmall = defaults.displaySmall.copy(fontFamily = AttendanceFonts.sans),
    headlineLarge = plexSans(32, 40, FontWeight.Bold, -0.02),
    headlineMedium = defaults.headlineMedium.copy(fontFamily = AttendanceFonts.sans),
    headlineSmall = defaults.headlineSmall.copy(fontFamily = AttendanceFonts.sans),
    titleLarge = plexSans(22, 28, FontWeight.SemiBold, -0.01),
    titleMedium = plexSans(18, 24, FontWeight.SemiBold, 0.0),
    titleSmall = defaults.titleSmall.copy(fontFamily = AttendanceFonts.sans),
    bodyLarge = plexSans(16, 24, FontWeight.Normal, 0.0),
    bodyMedium = plexSans(14, 20, FontWeight.Normal, 0.0),
    bodySmall = defaults.bodySmall.copy(fontFamily = AttendanceFonts.sans),
    labelLarge = plexSans(16, 22, FontWeight.SemiBold, 0.0),
    labelMedium = plexSans(12, 16, FontWeight.Bold, 0.08),
    labelSmall = plexSans(11, 16, FontWeight.SemiBold, 0.1),
)

private fun plexSans(size: Int, lineHeight: Int, weight: FontWeight, letterSpacingEm: Double) =
    TextStyle(
        fontFamily = AttendanceFonts.sans,
        fontSize = size.sp,
        lineHeight = lineHeight.sp,
        fontWeight = weight,
        letterSpacing = letterSpacingEm.em,
    )

@Immutable
data class StatusColorPair(val color: Color, val container: Color)

@Immutable
data class StatusColors(
    val inRange: StatusColorPair,
    val outOfRange: StatusColorPair,
    val pending: StatusColorPair,
    val queued: StatusColorPair,
    val uploading: StatusColorPair,
    val synced: StatusColorPair,
    val failed: StatusColorPair,
) {
    companion object {
        val Light = StatusColors(
            inRange = StatusColorPair(
                AttendanceStatusColors.inRange,
                AttendanceStatusColors.inRangeContainer,
            ),
            outOfRange = StatusColorPair(
                AttendanceStatusColors.outOfRange,
                AttendanceStatusColors.outOfRangeContainer,
            ),
            pending = StatusColorPair(
                AttendanceStatusColors.pending,
                AttendanceStatusColors.pendingContainer,
            ),
            queued = StatusColorPair(
                AttendanceStatusColors.queued,
                AttendanceStatusColors.queuedContainer,
            ),
            uploading = StatusColorPair(
                AttendanceStatusColors.uploading,
                AttendanceStatusColors.uploadingContainer,
            ),
            synced = StatusColorPair(
                AttendanceStatusColors.synced,
                AttendanceStatusColors.syncedContainer,
            ),
            failed = StatusColorPair(
                AttendanceStatusColors.failed,
                AttendanceStatusColors.failedContainer,
            ),
        )
    }
}

private val LocalStatusColors = staticCompositionLocalOf { StatusColors.Light }
