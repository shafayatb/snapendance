package com.shafayatb.snapendance.attendance.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.shafayatb.snapendance.R

// Light design tokens from docs/design/Design System.dc.html (script renderVals()).
// lib/app/theme/app_tokens.dart holds the same names and values for Flutter; change both
// together. The window background (attendance_background in res/values/colors.xml) repeats
// `background`.

object AttendanceColors {
    val background = Color(0xFFEEF2F7)
    val surface = Color(0xFFFFFFFF)
    val surfaceContainer = Color(0xFFF3F6FA)
    val onSurface = Color(0xFF13224A)
    val onSurfaceVariant = Color(0xFF56627A)
    val outline = Color(0xFFC5CEDC)
    val outlineVariant = Color(0xFFDDE3EC)
    val primary = Color(0xFF1D5BD6)
    val onPrimary = Color(0xFFFFFFFF)
    val primaryContainer = Color(0xFFDCE6FB)
    val disabledContainer = Color(0xFFDCE2EA)
    val onDisabled = Color(0xFF5F6B80)
}

/** Foreground and container color for each status in the light scheme. */
object AttendanceStatusColors {
    val inRange = Color(0xFF17804A)
    val inRangeContainer = Color(0xFFDDF3E6)
    val outOfRange = Color(0xFFC0262D)
    val outOfRangeContainer = Color(0xFFFCE4E4)
    val pending = Color(0xFF9A5B00)
    val pendingContainer = Color(0xFFFCEFD6)
    val queued = Color(0xFF56627A)
    val queuedContainer = Color(0xFFE3E8F0)
    val uploading = Color(0xFF1D5BD6)
    val uploadingContainer = Color(0xFFDCE6FB)
    val synced = Color(0xFF17804A)
    val syncedContainer = Color(0xFFDDF3E6)
    val failed = Color(0xFFC0262D)
    val failedContainer = Color(0xFFFCE4E4)
}

object AttendanceSpacing {
    val xxs = 4.dp
    val xs = 8.dp
    val sm = 12.dp
    val md = 16.dp
    val lg = 20.dp
    val xl = 24.dp
    val xxl = 32.dp
}

object AttendanceRadius {
    val xs = 6.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 28.dp
}

// IBM Plex TTFs in res/font, copies of assets/fonts (SIL Open Font License, assets/fonts/OFL.txt).
object AttendanceFonts {
    val sans = FontFamily(
        Font(R.font.ibm_plex_sans_regular, FontWeight.Normal),
        Font(R.font.ibm_plex_sans_semibold, FontWeight.SemiBold),
        Font(R.font.ibm_plex_sans_bold, FontWeight.Bold),
    )
    val mono = FontFamily(
        Font(R.font.ibm_plex_mono_medium, FontWeight.Medium),
    )
}
