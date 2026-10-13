package com.shafayatb.snapendance.attendance.ui

import android.text.format.DateFormat
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shafayatb.snapendance.R
import com.shafayatb.snapendance.attendance.office.SavedOffice
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceColors
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceFonts
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceRadius
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceSpacing
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

/**
 * "Step 1: Office Context" (design A1, A2, P2): the saved office or why there is none, and Set
 * Office Location. [isBlocked] means a location blocker is shown below the card (A6-A8), so the
 * button is disabled.
 */
@Composable
fun OfficeContextCard(
    office: SavedOffice?,
    fixAttempt: FixAttempt?,
    isBlocked: Boolean,
    onSetOfficeClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val content = when {
        fixAttempt != null -> CardContent.Fetching
        office != null -> CardContent.Saved
        isBlocked -> CardContent.Unavailable
        else -> CardContent.NotSaved
    }
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(AttendanceRadius.lg),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 1.dp,
    ) {
        Column(
            modifier = Modifier.padding(AttendanceSpacing.md),
            verticalArrangement = Arrangement.spacedBy(AttendanceSpacing.sm),
        ) {
            CardHeader(dotColor = content.dotColor())
            when (content) {
                CardContent.NotSaved -> EmptyPanel()
                CardContent.Fetching -> FetchingPanel(checkNotNull(fixAttempt).latestAccuracyMeters)
                CardContent.Unavailable -> UnavailablePanel()
                CardContent.Saved -> CoordinatesPanel(checkNotNull(office))
            }
            Text(
                text = stringResource(content.helperText),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            SetOfficeButton(
                style = when {
                    content == CardContent.Fetching -> ButtonStyle.Fetching
                    isBlocked -> ButtonStyle.Disabled
                    office == null -> ButtonStyle.Filled
                    else -> ButtonStyle.Outlined
                },
                onClick = onSetOfficeClick,
            )
        }
    }
}

private enum class CardContent(val helperText: Int) {
    NotSaved(R.string.office_helper_not_saved),
    Fetching(R.string.office_helper_fetching),
    Unavailable(R.string.office_helper_blocked),
    Saved(R.string.office_helper_saved),
}

@Composable
private fun CardContent.dotColor(): Color = when (this) {
    CardContent.NotSaved -> MaterialTheme.colorScheme.onSurfaceVariant
    CardContent.Fetching -> AttendanceTheme.statusColors.pending.color
    CardContent.Unavailable -> MaterialTheme.colorScheme.error
    CardContent.Saved -> MaterialTheme.colorScheme.primary
}

@Composable
private fun CardHeader(dotColor: Color) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.office_step_title),
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Box(
            Modifier
                .size(8.dp)
                .background(dotColor, CircleShape),
        )
    }
}

private val panelHeight = 128.dp

@Composable
private fun EmptyPanel() {
    val dashColor = MaterialTheme.colorScheme.outline
    CenteredPanel(
        modifier = Modifier
            .background(
                MaterialTheme.colorScheme.surfaceContainer,
                RoundedCornerShape(AttendanceRadius.md),
            )
            .drawBehind {
                val stroke = 1.5.dp.toPx()
                drawRoundRect(
                    color = dashColor,
                    cornerRadius = CornerRadius(AttendanceRadius.md.toPx()),
                    style = Stroke(
                        width = stroke,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx())),
                    ),
                )
            },
    ) {
        PanelIcon(R.drawable.ic_add_location_alt)
        PanelText(stringResource(R.string.office_not_saved), MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun FetchingPanel(latestAccuracyMeters: Float?) {
    CenteredPanel(modifier = Modifier.solidPanel(), spacing = 10.dp) {
        CircularProgressIndicator(
            modifier = Modifier.size(28.dp),
            color = MaterialTheme.colorScheme.primary,
            strokeWidth = 3.dp,
            trackColor = MaterialTheme.colorScheme.primaryContainer,
        )
        PanelText(stringResource(R.string.office_fetching), MaterialTheme.colorScheme.onSurface)
        Text(
            text = if (latestAccuracyMeters != null) {
                stringResource(R.string.office_fetching_accuracy, latestAccuracyMeters.roundToInt())
            } else {
                stringResource(R.string.office_fetching_waiting)
            },
            style = monoStyle(12),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun UnavailablePanel() {
    CenteredPanel(modifier = Modifier.solidPanel()) {
        PanelIcon(R.drawable.ic_location_disabled)
        PanelText(
            stringResource(R.string.office_location_unavailable),
            MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun CoordinatesPanel(office: SavedOffice) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(panelHeight)
            .solidPanel()
            .padding(AttendanceSpacing.sm),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            modifier = Modifier
                .height(32.dp)
                .background(MaterialTheme.colorScheme.surface, CircleShape)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, CircleShape)
                .padding(start = 10.dp, end = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_location_on),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = stringResource(
                    R.string.office_coordinates,
                    formatCoordinate(office.latitude),
                    formatCoordinate(office.longitude),
                ),
                style = monoStyle(13),
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(AttendanceSpacing.xs)) {
            LabeledValue(
                label = stringResource(R.string.office_saved_label),
                value = formatSavedTime(office.savedAtEpochMillis),
                modifier = Modifier.weight(1f),
            )
            LabeledValue(
                label = stringResource(R.string.office_accuracy_label),
                value = stringResource(R.string.office_accuracy_value, office.accuracyMeters.roundToInt()),
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun LabeledValue(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun CenteredPanel(
    modifier: Modifier,
    spacing: Dp = 6.dp,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(panelHeight)
            .then(modifier)
            .padding(horizontal = AttendanceSpacing.sm),
        verticalArrangement = Arrangement.spacedBy(spacing, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        content()
    }
}

@Composable
private fun Modifier.solidPanel(): Modifier {
    val shape = RoundedCornerShape(AttendanceRadius.md)
    return background(MaterialTheme.colorScheme.surfaceContainer, shape)
        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape)
}

@Composable
private fun PanelIcon(icon: Int) {
    Icon(
        painter = painterResource(icon),
        contentDescription = null,
        modifier = Modifier.size(28.dp),
        tint = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun PanelText(text: String, color: Color) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
        color = color,
        textAlign = TextAlign.Center,
    )
}

private fun monoStyle(size: Int) =
    TextStyle(fontFamily = AttendanceFonts.mono, fontSize = size.sp)

private enum class ButtonStyle { Filled, Outlined, Fetching, Disabled }

@Composable
private fun SetOfficeButton(style: ButtonStyle, onClick: () -> Unit) {
    val modifier = Modifier
        .fillMaxWidth()
        .height(52.dp)
    val shape = RoundedCornerShape(AttendanceRadius.md)
    val label = @Composable {
        if (style == ButtonStyle.Fetching) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = AttendanceColors.onDisabled,
                strokeWidth = 2.dp,
            )
        } else {
            Icon(
                painter = painterResource(R.drawable.ic_add_circle),
                contentDescription = null,
                modifier = Modifier.size(20.dp),
            )
        }
        Spacer(Modifier.width(AttendanceSpacing.xs))
        Text(
            text = stringResource(
                if (style == ButtonStyle.Fetching) R.string.office_fetching_button else R.string.office_set_button,
            ),
            style = MaterialTheme.typography.labelLarge.copy(fontSize = 15.sp),
        )
    }
    val padding = PaddingValues(horizontal = AttendanceSpacing.md)
    if (style == ButtonStyle.Filled) {
        Button(onClick = onClick, modifier = modifier, shape = shape, contentPadding = padding) {
            label()
        }
    } else {
        val enabled = style == ButtonStyle.Outlined
        OutlinedButton(
            onClick = onClick,
            modifier = modifier,
            enabled = enabled,
            shape = shape,
            border = BorderStroke(
                1.5.dp,
                if (enabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
            ),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = MaterialTheme.colorScheme.primary,
                disabledContainerColor = MaterialTheme.colorScheme.background,
                disabledContentColor = AttendanceColors.onDisabled,
            ),
            contentPadding = padding,
        ) {
            label()
        }
    }
}

private fun formatCoordinate(value: Double): String = String.format(Locale.ROOT, "%.4f", value)

/** "Today, 08:41 AM", "Yesterday, 08:41 AM", or "12 Oct, 08:41 AM", in the device's 12/24-hour setting. */
@Composable
private fun formatSavedTime(epochMillis: Long): String {
    val timePattern = if (DateFormat.is24HourFormat(LocalContext.current)) "HH:mm" else "hh:mm a"
    val locale = Locale.getDefault()
    val time = SimpleDateFormat(timePattern, locale).format(Date(epochMillis))
    val saved = Calendar.getInstance().apply { timeInMillis = epochMillis }
    val today = Calendar.getInstance()
    val yesterday = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -1) }
    return when {
        saved.isSameDay(today) -> stringResource(R.string.office_saved_today, time)
        saved.isSameDay(yesterday) -> stringResource(R.string.office_saved_yesterday, time)
        else -> stringResource(
            R.string.office_saved_date,
            SimpleDateFormat("d MMM", locale).format(Date(epochMillis)),
            time,
        )
    }
}

private fun Calendar.isSameDay(other: Calendar) =
    get(Calendar.YEAR) == other.get(Calendar.YEAR) &&
        get(Calendar.DAY_OF_YEAR) == other.get(Calendar.DAY_OF_YEAR)

private val previewOffice = SavedOffice(
    latitude = 23.7937,
    longitude = 90.4066,
    accuracyMeters = 6f,
    savedAtEpochMillis = System.currentTimeMillis(),
)

@Preview(name = "A1 not saved", widthDp = 412)
@Composable
private fun NotSavedPreview() {
    AttendanceTheme {
        OfficeContextCard(office = null, fixAttempt = null, isBlocked = false, onSetOfficeClick = {})
    }
}

@Preview(name = "A2 fetching", widthDp = 412)
@Composable
private fun FetchingPreview() {
    AttendanceTheme {
        OfficeContextCard(office = null, fixAttempt = FixAttempt(18f), isBlocked = false, onSetOfficeClick = {})
    }
}

@Preview(name = "P2 saved", widthDp = 412)
@Composable
private fun SavedPreview() {
    AttendanceTheme {
        OfficeContextCard(office = previewOffice, fixAttempt = null, isBlocked = false, onSetOfficeClick = {})
    }
}

@Preview(name = "Blocked, nothing saved", widthDp = 412)
@Composable
private fun BlockedPreview() {
    AttendanceTheme {
        OfficeContextCard(office = null, fixAttempt = null, isBlocked = true, onSetOfficeClick = {})
    }
}
