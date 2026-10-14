package com.shafayatb.snapendance.attendance.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shafayatb.snapendance.R
import com.shafayatb.snapendance.attendance.marking.AttendanceEligibility
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceColors
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceSpacing
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceStatusColors
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme
import kotlin.math.ceil

@Composable
fun DistanceRing(
    status: DistanceStatus,
    markedAtEpochMillis: Long?,
    modifier: Modifier = Modifier,
) {
    val look = status.look()
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AttendanceSpacing.sm),
    ) {
        Ring(status = status, look = look)
        if (markedAtEpochMillis != null) {
            StatusChip(
                label = stringResource(R.string.ring_chip_marked, formatClockTime(markedAtEpochMillis)),
                color = AttendanceStatusColors.inRange,
                container = AttendanceStatusColors.inRangeContainer,
            )
        } else {
            StatusChip(label = stringResource(look.chip), color = look.color, container = look.container)
        }
        Text(
            text = if (markedAtEpochMillis != null) {
                stringResource(R.string.ring_helper_marked)
            } else {
                stringResource(look.helper)
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 320.dp),
        )
    }
}

private data class RingLook(
    val color: Color,
    val container: Color,
    val chip: Int,
    val helper: Int,
)

private fun DistanceStatus.look(): RingLook = when (this) {
    DistanceStatus.NoOffice -> RingLook(
        AttendanceStatusColors.queued, AttendanceStatusColors.queuedContainer,
        R.string.ring_chip_no_office, R.string.ring_helper_no_office,
    )
    DistanceStatus.Locating -> RingLook(
        AttendanceStatusColors.uploading, AttendanceStatusColors.uploadingContainer,
        R.string.ring_chip_locating, R.string.ring_helper_locating,
    )
    DistanceStatus.Unavailable -> RingLook(
        AttendanceStatusColors.queued, AttendanceStatusColors.queuedContainer,
        R.string.ring_chip_unavailable, R.string.ring_helper_unavailable,
    )
    is DistanceStatus.Weak -> RingLook(
        AttendanceStatusColors.pending, AttendanceStatusColors.pendingContainer,
        R.string.ring_chip_weak,
        if (isStale) R.string.ring_helper_weak_stale else R.string.ring_helper_weak_inaccurate,
    )
    is DistanceStatus.OutOfRange -> RingLook(
        AttendanceStatusColors.outOfRange, AttendanceStatusColors.outOfRangeContainer,
        R.string.ring_chip_out_of_range, R.string.ring_helper_out_of_range,
    )
    is DistanceStatus.InRange -> RingLook(
        AttendanceStatusColors.inRange, AttendanceStatusColors.inRangeContainer,
        R.string.ring_chip_in_range, R.string.ring_helper_in_range,
    )
}

@Composable
private fun Ring(status: DistanceStatus, look: RingLook) {
    val targetSweep = when (status) {
        is DistanceStatus.OutOfRange ->
            (AttendanceEligibility.MAX_DISTANCE_METERS / status.distanceMeters).toFloat().coerceIn(0f, 1f)
        is DistanceStatus.InRange, is DistanceStatus.Weak -> 1f
        else -> 0f
    }
    val sweep by animateFloatAsState(targetSweep, tween(300, easing = FastOutSlowInEasing), label = "sweep")
    val arcColor by animateColorAsState(look.color, tween(250), label = "arcColor")
    val spin = rememberInfiniteTransition(label = "locating")
    val rotation by spin.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(1_200, easing = LinearEasing), RepeatMode.Restart),
        label = "rotation",
    )
    val track = AttendanceColors.outlineVariant

    Box(
        modifier = Modifier
            .size(176.dp)
            .shadow(1.dp, CircleShape)
            .background(MaterialTheme.colorScheme.surface, CircleShape)
            .semantics(mergeDescendants = true) {},
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.fillMaxSize().padding(3.dp)) {
            val stroke = 10.dp.toPx()
            val inset = stroke / 2
            val arcSize = size.copy(width = size.width - stroke, height = size.height - stroke)
            val topLeft = androidx.compose.ui.geometry.Offset(inset, inset)
            drawArc(track, 0f, 360f, false, topLeft, arcSize, style = Stroke(stroke))
            when (status) {
                DistanceStatus.Locating -> drawArc(
                    arcColor, rotation - 90f, 0.22f * 360f, false, topLeft, arcSize,
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
                is DistanceStatus.Weak -> drawArc(
                    arcColor, -90f, 360f, false, topLeft, arcSize,
                    style = Stroke(
                        stroke,
                        cap = StrokeCap.Round,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 9.6.dp.toPx())),
                    ),
                )
                else -> if (sweep > 0f) {
                    drawArc(
                        arcColor, -90f, sweep * 360f, false, topLeft, arcSize,
                        style = Stroke(stroke, cap = StrokeCap.Round),
                    )
                }
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = status.value(),
                style = MaterialTheme.typography.displaySmall.copy(
                    fontSize = 40.sp,
                    lineHeight = 44.sp,
                    fontWeight = FontWeight.Bold,
                ),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = status.unit(),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun DistanceStatus.value(): String = when (this) {
    DistanceStatus.NoOffice, DistanceStatus.Unavailable -> "—"
    DistanceStatus.Locating -> "…"
    is DistanceStatus.Weak -> "~" + formatDistance(distanceMeters)
    is DistanceStatus.OutOfRange -> formatDistance(distanceMeters)
    is DistanceStatus.InRange -> formatDistance(distanceMeters)
}

@Composable
private fun DistanceStatus.unit(): String = when (this) {
    DistanceStatus.NoOffice -> stringResource(R.string.ring_unit_no_office)
    DistanceStatus.Locating -> stringResource(R.string.ring_unit_locating)
    DistanceStatus.Unavailable -> stringResource(R.string.ring_unit_unavailable)
    is DistanceStatus.Weak -> accuracyMeters?.let {
        stringResource(R.string.ring_unit_accuracy, ceil(it).toInt())
    } ?: stringResource(R.string.ring_unit_accuracy_unknown)
    is DistanceStatus.OutOfRange, is DistanceStatus.InRange -> stringResource(R.string.ring_unit_away)
}

@Composable
private fun StatusChip(label: String, color: Color, container: Color) {
    Row(
        modifier = Modifier
            .heightIn(min = 32.dp)
            .background(container, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = AttendanceSpacing.xxs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AttendanceSpacing.xs),
    ) {
        Box(Modifier.size(8.dp).background(color, CircleShape))
        Text(text = label, style = MaterialTheme.typography.labelMedium, color = color)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFEEF2F7, widthDp = 412)
@Composable
private fun OutOfRangePreview() {
    AttendanceTheme { DistanceRing(DistanceStatus.OutOfRange(120.0), markedAtEpochMillis = null) }
}

@Preview(showBackground = true, backgroundColor = 0xFFEEF2F7, widthDp = 412)
@Composable
private fun WeakPreview() {
    AttendanceTheme {
        DistanceRing(DistanceStatus.Weak(48.0, accuracyMeters = 65f, isStale = true), markedAtEpochMillis = null)
    }
}
