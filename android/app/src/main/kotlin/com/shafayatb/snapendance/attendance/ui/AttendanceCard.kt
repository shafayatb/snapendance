package com.shafayatb.snapendance.attendance.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shafayatb.snapendance.R
import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceColors
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceRadius
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceSpacing
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceStatusColors
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme
import kotlin.math.ceil

private enum class CardKind { Locked, Ready, Marked }

/**
 * Mark Attendance (design A3-A5): dashed and locked until [AttendanceUiState.canMarkAttendance],
 * green-bordered and enabled when it is, and the "Attendance marked" confirmation once marked
 * today. The bottom line shows the last attendance instead of the reference's time window.
 */
@Composable
fun AttendanceCard(
    state: AttendanceUiState,
    onMarkClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val kind = when {
        state.isMarkedToday -> CardKind.Marked
        state.canMarkAttendance || state.isCheckingAttendance -> CardKind.Ready
        else -> CardKind.Locked
    }
    // The card cross-fades between kinds (A4 → A5: 250 ms).
    AnimatedContent(
        targetState = kind,
        transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(250)) },
        modifier = modifier.fillMaxWidth(),
        label = "attendanceCard",
    ) { target ->
        when (target) {
            CardKind.Locked -> LockedCard(state.lastAttendance)
            CardKind.Ready -> ReadyCard(state.lastAttendance, state.isCheckingAttendance, onMarkClick)
            CardKind.Marked -> state.lastAttendance?.let { MarkedCard(it) }
        }
    }
}

@Composable
private fun LockedCard(lastAttendance: AttendanceRecord?) {
    val dash = AttendanceColors.outline
    CardColumn(
        modifier = Modifier.drawBehind {
            val stroke = 1.5.dp.toPx()
            drawRoundRect(
                color = dash,
                topLeft = androidx.compose.ui.geometry.Offset(stroke / 2, stroke / 2),
                size = size.copy(width = size.width - stroke, height = size.height - stroke),
                cornerRadius = CornerRadius(AttendanceRadius.lg.toPx()),
                style = Stroke(
                    width = stroke,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx())),
                ),
            )
        },
    ) {
        CardIcon(R.drawable.ic_lock, MaterialTheme.colorScheme.onSurfaceVariant)
        // Disabled, not hidden: tapping the locked button does nothing (A3).
        MarkButton(enabled = false, isChecking = false, onClick = {})
        LastMarkedLine(lastAttendance)
    }
}

@Composable
private fun ReadyCard(lastAttendance: AttendanceRecord?, isChecking: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(AttendanceRadius.lg)
    CardColumn(
        modifier = Modifier
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.5.dp, AttendanceStatusColors.inRange, shape),
    ) {
        CardIcon(R.drawable.ic_where_to_vote, AttendanceStatusColors.inRange)
        MarkButton(enabled = true, isChecking = isChecking, onClick = onClick)
        LastMarkedLine(lastAttendance)
    }
}

@Composable
private fun MarkedCard(record: AttendanceRecord) {
    val shape = RoundedCornerShape(AttendanceRadius.lg)
    val onMarked = Color(0xFF0F5C35)
    CardColumn(
        modifier = Modifier
            .background(AttendanceStatusColors.inRangeContainer, shape)
            .border(1.5.dp, AttendanceStatusColors.inRange, shape),
        spacing = AttendanceSpacing.xs,
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_task_alt),
            contentDescription = null,
            modifier = Modifier.size(40.dp),
            tint = AttendanceStatusColors.inRange,
        )
        Text(
            text = stringResource(R.string.card_marked_title),
            style = MaterialTheme.typography.titleMedium,
            color = onMarked,
        )
        Text(
            text = stringResource(
                R.string.card_marked_detail,
                formatSavedTime(record.markedAtEpochMillis),
                ceil(record.distanceMeters).toInt(),
            ),
            style = MaterialTheme.typography.bodyMedium,
            color = onMarked,
            textAlign = TextAlign.Center,
        )
        Text(
            text = stringResource(R.string.card_marked_saved),
            style = MaterialTheme.typography.bodySmall,
            color = Color(0xFF2C5E43),
        )
    }
}

@Composable
private fun CardColumn(
    modifier: Modifier,
    spacing: androidx.compose.ui.unit.Dp = AttendanceSpacing.sm,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .then(modifier)
            .padding(start = AttendanceSpacing.lg, top = AttendanceSpacing.lg, end = AttendanceSpacing.lg, bottom = AttendanceSpacing.md),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) {
        content()
    }
}

@Composable
private fun CardIcon(icon: Int, tint: Color) {
    Icon(
        painter = painterResource(icon),
        contentDescription = null,
        modifier = Modifier.size(32.dp),
        tint = tint,
    )
}

@Composable
private fun MarkButton(enabled: Boolean, isChecking: Boolean, onClick: () -> Unit) {
    Button(
        // While checking, the button keeps its look but ignores taps (the ViewModel does too).
        onClick = { if (!isChecking) onClick() },
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(AttendanceRadius.md),
        colors = ButtonDefaults.buttonColors(
            disabledContainerColor = AttendanceColors.disabledContainer,
            disabledContentColor = AttendanceColors.onDisabled,
        ),
    ) {
        if (isChecking) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = MaterialTheme.colorScheme.onPrimary,
                strokeWidth = 2.dp,
            )
        } else if (enabled) {
            Icon(
                painter = painterResource(R.drawable.ic_how_to_reg),
                contentDescription = null,
                modifier = Modifier.size(20.dp),
            )
        }
        if (isChecking || enabled) Spacer(Modifier.width(AttendanceSpacing.xs))
        Text(
            text = stringResource(if (isChecking) R.string.card_checking else R.string.card_mark_button),
            style = MaterialTheme.typography.labelLarge.copy(fontSize = 16.sp, fontWeight = FontWeight.SemiBold),
        )
    }
}

@Composable
private fun LastMarkedLine(lastAttendance: AttendanceRecord?) {
    Text(
        text = lastAttendance?.let {
            stringResource(R.string.card_last_marked, formatSavedTime(it.markedAtEpochMillis)).uppercase()
        } ?: stringResource(R.string.card_never_marked),
        style = MaterialTheme.typography.labelSmall.copy(fontSize = 12.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.48.sp),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
    )
}

private val previewRecord = AttendanceRecord(System.currentTimeMillis(), 32f)

@Preview(showBackground = true, backgroundColor = 0xFFEEF2F7, widthDp = 412)
@Composable
private fun ReadyPreview() {
    AttendanceTheme {
        AttendanceCard(
            state = AttendanceUiState(
                office = null,
                isOfficeLoaded = true,
                isAttendanceLoaded = true,
                distance = DistanceStatus.InRange(32.0),
            ),
            onMarkClick = {},
            modifier = Modifier.padding(AttendanceSpacing.md),
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFEEF2F7, widthDp = 412)
@Composable
private fun MarkedPreview() {
    AttendanceTheme {
        AttendanceCard(
            state = AttendanceUiState(lastAttendance = previewRecord, isMarkedToday = true),
            onMarkClick = {},
            modifier = Modifier.padding(AttendanceSpacing.md),
        )
    }
}
