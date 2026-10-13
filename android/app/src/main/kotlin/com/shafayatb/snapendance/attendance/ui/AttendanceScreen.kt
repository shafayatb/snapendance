package com.shafayatb.snapendance.attendance.ui

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.LocalActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import com.shafayatb.snapendance.R
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceSpacing
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Connects [AttendanceScreen] to [viewModel]: collects its state, carries out its events
 * (permission request, snackbars) and the blockers' recoveries, and reports the permission and
 * lifecycle back.
 */
@Composable
fun AttendanceRoot(
    viewModel: AttendanceViewModel,
    onNavigateBack: () -> Unit,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val resources = LocalResources.current
    val activity = LocalActivity.current

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        // Read the permission again rather than the result map: it holds only what was asked.
        viewModel.onAction(
            AttendanceAction.PermissionResult(
                permission = context.locationPermission(),
                shouldShowRationale = activity
                    ?.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION)
                    ?: false,
            ),
        )
    }

    // Fine and coarse together: Android 12+ ignores a request for fine alone.
    val requestPermission = {
        permissionLauncher.launch(
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
        )
    }
    val recheckLocation = {
        viewModel.onAction(AttendanceAction.ScreenResumed(context.locationPermission()))
    }

    // Nothing to read from the result: closing the dialog resumes the screen, which re-checks.
    val turnOnLocationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult(),
    ) {}

    // Permission and services can change in system settings while the screen is away (plan D6).
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { recheckLocation() }
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
        viewModel.onAction(AttendanceAction.ScreenStopped)
    }

    ObserveAsEvents(viewModel.events) { event ->
        val message = when (event) {
            AttendanceEvent.RequestLocationPermission -> {
                requestPermission()
                return@ObserveAsEvents
            }
            AttendanceEvent.NoFix -> resources.getString(R.string.office_error_no_fix)
            is AttendanceEvent.FixTooInaccurate -> event.bestAccuracyMeters?.let {
                resources.getString(R.string.office_error_inaccurate, it.roundToInt())
            } ?: resources.getString(R.string.office_error_inaccurate_unknown)
            AttendanceEvent.FixStale -> resources.getString(R.string.office_error_stale)
            AttendanceEvent.OfficeSaveFailed -> resources.getString(R.string.office_error_save)
            AttendanceEvent.OfficeLoadFailed -> resources.getString(R.string.office_error_load)
        }
        // A failed load has nothing to retry; every other message is a failed attempt.
        val canRetry = event != AttendanceEvent.OfficeLoadFailed
        scope.launch {
            // The newest message replaces one still on screen instead of queueing behind it.
            snackbarHostState.currentSnackbarData?.dismiss()
            val result = snackbarHostState.showSnackbar(
                message = message,
                actionLabel = if (canRetry) resources.getString(R.string.office_retry) else null,
                duration = SnackbarDuration.Long,
            )
            if (result == SnackbarResult.ActionPerformed) {
                viewModel.onAction(AttendanceAction.SetOfficeClick)
            }
        }
    }

    AttendanceScreen(
        state = state,
        onAction = viewModel::onAction,
        onRecoveryClick = { blocker ->
            when (blocker) {
                is LocationBlocker.PermissionDenied ->
                    if (blocker.canAskAgain) requestPermission() else context.openAppSettings()
                is LocationBlocker.ApproximateOnly ->
                    if (blocker.canAskAgain) requestPermission() else context.openAppSettings()
                LocationBlocker.LocationServicesOff ->
                    activity?.turnOnLocation(turnOnLocationLauncher, onAlreadyOn = recheckLocation)
            }
        },
        onNavigateBack = onNavigateBack,
        snackbarHostState = snackbarHostState,
    )
}

/**
 * Attendance screen (design A1, A2, A6-A8, P2). Task 03 adds the distance ring and Mark
 * Attendance. [onRecoveryClick] carries out the recovery of the blocker shown.
 */
@Composable
fun AttendanceScreen(
    state: AttendanceUiState,
    onAction: (AttendanceAction) -> Unit,
    onRecoveryClick: (LocationBlocker) -> Unit,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    snackbarHostState: SnackbarHostState = remember { SnackbarHostState() },
) {
    Scaffold(
        modifier = modifier,
        topBar = { AttendanceTopBar(onNavigateBack = onNavigateBack) },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background,
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(
                    start = AttendanceSpacing.md,
                    top = AttendanceSpacing.xxs,
                    end = AttendanceSpacing.md,
                    bottom = AttendanceSpacing.md,
                ),
            verticalArrangement = Arrangement.spacedBy(AttendanceSpacing.lg),
        ) {
            OfficeContextCard(
                office = state.office,
                fixAttempt = state.fixAttempt,
                isBlocked = state.blocker != null,
                onSetOfficeClick = { onAction(AttendanceAction.SetOfficeClick) },
            )
            // Plan D7: in the area task 03's distance ring will use.
            state.blocker?.let { blocker ->
                LocationIssuePanel(blocker = blocker, onRecoveryClick = { onRecoveryClick(blocker) })
            }
        }
    }

    if (state.isReplaceConfirmationVisible) {
        ReplaceOfficeDialog(
            onConfirm = { onAction(AttendanceAction.ReplaceOfficeConfirm) },
            onDismiss = { onAction(AttendanceAction.ReplaceOfficeDismiss) },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AttendanceTopBar(onNavigateBack: () -> Unit) {
    // Small top app bar: 64 dp, 48 dp back button, titleLarge. It pads itself below the status bar.
    TopAppBar(
        title = { Text(stringResource(R.string.attendance_title)) },
        navigationIcon = {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    painter = painterResource(R.drawable.ic_arrow_back),
                    contentDescription = stringResource(R.string.attendance_navigate_back),
                )
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = MaterialTheme.colorScheme.background,
        ),
    )
}

/** Plan D8: replacing the saved office cannot be undone, so it is confirmed first. */
@Composable
private fun ReplaceOfficeDialog(onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.office_replace_title)) },
        text = { Text(stringResource(R.string.office_replace_body)) },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(stringResource(R.string.office_replace_confirm)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.office_replace_cancel)) }
        },
        containerColor = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp,
    )
}

/**
 * Collects one-off [events] while the screen is at least started, on the main thread without
 * a dispatch, so an event sent just before a configuration change is not lost.
 */
@Composable
private fun <T> ObserveAsEvents(events: Flow<T>, onEvent: (T) -> Unit) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnEvent by rememberUpdatedState(onEvent)
    LaunchedEffect(events, lifecycleOwner) {
        lifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
            withContext(Dispatchers.Main.immediate) {
                events.collect { currentOnEvent(it) }
            }
        }
    }
}

/** The location permission this app holds now. */
private fun Context.locationPermission(): LocationPermission = when {
    isGranted(Manifest.permission.ACCESS_FINE_LOCATION) -> LocationPermission.Precise
    isGranted(Manifest.permission.ACCESS_COARSE_LOCATION) -> LocationPermission.Approximate
    else -> LocationPermission.None
}

private fun Context.isGranted(permission: String) =
    ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

/** This app's page in system settings, where a permission the system no longer asks for is changed. */
private fun Context.openAppSettings() {
    startSettings(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
}

/**
 * Shows the Play services "turn on location" dialog (A8), or the system location settings when
 * it cannot be shown (no Play services, or the device does not allow the change). [onAlreadyOn]
 * runs when location is on already: turned on from the notification shade, which does not
 * resume the screen. Callbacks are tied to this Activity, so none runs after it stops.
 */
private fun Activity.turnOnLocation(
    dialogLauncher: ActivityResultLauncher<IntentSenderRequest>,
    onAlreadyOn: () -> Unit,
) {
    val request = LocationSettingsRequest.Builder()
        .addLocationRequest(LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1_000L).build())
        .build()
    LocationServices.getSettingsClient(this).checkLocationSettings(request)
        .addOnSuccessListener(this) { onAlreadyOn() }
        .addOnFailureListener(this) { error ->
            if (error is ResolvableApiException) {
                dialogLauncher.launch(IntentSenderRequest.Builder(error.resolution).build())
            } else {
                startSettings(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
            }
        }
}

/** Opens a settings screen, or the main settings page on a device without that screen. */
private fun Context.startSettings(intent: Intent) {
    try {
        startActivity(intent)
    } catch (error: ActivityNotFoundException) {
        startActivity(Intent(Settings.ACTION_SETTINGS))
    }
}

@Preview(showBackground = true, widthDp = 412, heightDp = 915)
@Composable
private fun AttendanceScreenPreview() {
    AttendanceTheme {
        AttendanceScreen(
            state = AttendanceUiState(),
            onAction = {},
            onRecoveryClick = {},
            onNavigateBack = {},
        )
    }
}
