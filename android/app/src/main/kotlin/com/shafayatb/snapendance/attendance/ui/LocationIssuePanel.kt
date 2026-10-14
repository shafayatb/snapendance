package com.shafayatb.snapendance.attendance.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shafayatb.snapendance.R
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceSpacing
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme
import com.shafayatb.snapendance.attendance.ui.theme.StatusColorPair

@Composable
fun LocationIssuePanel(
    blocker: LocationBlocker,
    onRecoveryClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val issue = blocker.issue()
    val colors = issue.colors()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = AttendanceSpacing.xs, top = AttendanceSpacing.xs, end = AttendanceSpacing.xs),
        verticalArrangement = Arrangement.spacedBy(AttendanceSpacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .background(colors.container, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(issue.icon),
                contentDescription = null,
                modifier = Modifier.size(32.dp),
                tint = colors.color,
            )
        }
        Text(
            text = stringResource(issue.title),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )
        Text(
            text = stringResource(issue.body),
            modifier = Modifier.widthIn(max = 330.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Button(
            onClick = onRecoveryClick,
            modifier = Modifier
                .padding(top = AttendanceSpacing.xxs)
                .height(48.dp),
            shape = RoundedCornerShape(24.dp),
            contentPadding = PaddingValues(horizontal = 22.dp),
        ) {
            Text(
                text = stringResource(issue.action),
                style = MaterialTheme.typography.labelLarge.copy(fontSize = 15.sp),
            )
            Spacer(Modifier.width(AttendanceSpacing.xs))
            Icon(
                painter = painterResource(issue.actionIcon),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

private enum class Severity { Error, Warning }

private data class Issue(
    val severity: Severity,
    val icon: Int,
    val title: Int,
    val body: Int,
    val action: Int,
    val actionIcon: Int,
)

private fun LocationBlocker.issue(): Issue = when (this) {
    is LocationBlocker.PermissionDenied -> if (canAskAgain) {
        Issue(
            Severity.Error, R.drawable.ic_location_disabled, R.string.issue_permission_title,
            R.string.issue_permission_body_ask, R.string.issue_permission_action_ask,
            R.drawable.ic_arrow_forward,
        )
    } else {
        Issue(
            Severity.Error, R.drawable.ic_location_disabled, R.string.issue_permission_title,
            R.string.issue_permission_body_settings, R.string.issue_open_app_settings,
            R.drawable.ic_open_in_new,
        )
    }
    is LocationBlocker.ApproximateOnly -> if (canAskAgain) {
        Issue(
            Severity.Warning, R.drawable.ic_location_searching, R.string.issue_precise_title,
            R.string.issue_precise_body_ask, R.string.issue_precise_action_ask,
            R.drawable.ic_arrow_forward,
        )
    } else {
        Issue(
            Severity.Warning, R.drawable.ic_location_searching, R.string.issue_precise_title,
            R.string.issue_precise_body_settings, R.string.issue_open_app_settings,
            R.drawable.ic_open_in_new,
        )
    }
    LocationBlocker.LocationServicesOff -> Issue(
        Severity.Warning, R.drawable.ic_location_off, R.string.issue_services_title,
        R.string.issue_services_body, R.string.issue_services_action, R.drawable.ic_arrow_forward,
    )
}

@Composable
private fun Issue.colors(): StatusColorPair = when (severity) {
    Severity.Error -> AttendanceTheme.statusColors.outOfRange
    Severity.Warning -> AttendanceTheme.statusColors.pending
}

@Preview(name = "A6 ask again", widthDp = 412, showBackground = true, backgroundColor = 0xFFEEF2F7)
@Composable
private fun PermissionAskAgainPreview() {
    AttendanceTheme {
        LocationIssuePanel(LocationBlocker.PermissionDenied(canAskAgain = true), onRecoveryClick = {})
    }
}

@Preview(name = "A6 app settings", widthDp = 412, showBackground = true, backgroundColor = 0xFFEEF2F7)
@Composable
private fun PermissionSettingsPreview() {
    AttendanceTheme {
        LocationIssuePanel(LocationBlocker.PermissionDenied(canAskAgain = false), onRecoveryClick = {})
    }
}

@Preview(name = "A7 approximate", widthDp = 412, showBackground = true, backgroundColor = 0xFFEEF2F7)
@Composable
private fun ApproximatePreview() {
    AttendanceTheme {
        LocationIssuePanel(LocationBlocker.ApproximateOnly(canAskAgain = true), onRecoveryClick = {})
    }
}

@Preview(name = "A8 services off", widthDp = 412, showBackground = true, backgroundColor = 0xFFEEF2F7)
@Composable
private fun ServicesOffPreview() {
    AttendanceTheme {
        LocationIssuePanel(LocationBlocker.LocationServicesOff, onRecoveryClick = {})
    }
}
