package com.shafayatb.snapendance.attendance.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.shafayatb.snapendance.attendance.location.FixVerdict
import com.shafayatb.snapendance.attendance.location.LocationFixPolicy
import com.shafayatb.snapendance.attendance.location.LocationSource
import com.shafayatb.snapendance.attendance.office.OfficeStore
import com.shafayatb.snapendance.attendance.office.SavedOffice
import java.io.IOException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * State and decisions for the attendance screen. It knows nothing about Activities: the screen
 * sends [AttendanceAction]s and shows [uiState] and [events].
 *
 * The clocks are injected so tests control time: [elapsedRealtimeMillis] (the fix timestamps'
 * clock) judges fix age, and [currentTimeMillis] stamps the saved office.
 */
class AttendanceViewModel(
    private val locationSource: LocationSource,
    private val officeStore: OfficeStore,
    private val elapsedRealtimeMillis: () -> Long,
    private val currentTimeMillis: () -> Long,
) : ViewModel() {
    private val _uiState = MutableStateFlow(AttendanceUiState())
    val uiState: StateFlow<AttendanceUiState> = _uiState.asStateFlow()

    // Buffered, so an attempt ends when it sends its message rather than when the screen reads it,
    // and messages sent while the screen is stopped are shown when it starts again.
    private val _events = Channel<AttendanceEvent>(Channel.BUFFERED)
    val events: Flow<AttendanceEvent> = _events.receiveAsFlow()

    private var fixJob: Job? = null

    // The permission the screen last reported. Kept out of the UI state: the screen shows its
    // effect (the blocker), not the permission itself.
    private var permission = LocationPermission.None

    // Whether the last request result refused precise location and if the system will ask again.
    // Only a request result can tell, so it is kept until the permission changes.
    private var refusal: Refusal? = null

    // Set when a tap asked for permission, so granting it continues to the fetch. A grant from a
    // blocker's recovery button does not start one.
    private var setOfficeAfterPermission = false

    init {
        viewModelScope.launch {
            // The store is the source of truth: a newly saved office reaches the screen from here.
            officeStore.office
                .catch { error ->
                    if (error !is IOException) throw error
                    emit(null)
                    _events.send(AttendanceEvent.OfficeLoadFailed)
                }
                .collect { office ->
                    _uiState.update { it.copy(office = office, isOfficeLoaded = true) }
                }
        }
    }

    fun onAction(action: AttendanceAction) {
        when (action) {
            AttendanceAction.SetOfficeClick -> onSetOfficeClick()
            AttendanceAction.ReplaceOfficeConfirm -> {
                _uiState.update { it.copy(isReplaceConfirmationVisible = false) }
                startFixAttempt()
            }
            AttendanceAction.ReplaceOfficeDismiss ->
                _uiState.update { it.copy(isReplaceConfirmationVisible = false) }
            is AttendanceAction.ScreenResumed -> {
                // A change made in app settings makes the last request's answer out of date.
                if (action.permission != permission) refusal = null
                permission = action.permission
                refreshBlocker()
            }
            is AttendanceAction.PermissionResult -> onPermissionResult(action)
            AttendanceAction.ScreenStopped -> {
                // Silent: the card returns to what it showed before the attempt.
                fixJob?.cancel()
                _uiState.update { it.copy(fixAttempt = null) }
            }
        }
    }

    private fun onSetOfficeClick() {
        // One attempt at a time: a second tap must not open a second location request.
        if (fixJob?.isActive == true) return
        // Until the saved office is read, a replace would skip its confirmation.
        if (!_uiState.value.isOfficeLoaded) return
        when {
            permission != LocationPermission.Precise -> {
                setOfficeAfterPermission = true
                viewModelScope.launch { _events.send(AttendanceEvent.RequestLocationPermission) }
            }
            // Replacing cannot be undone, so one tap on the outlined button must not do it.
            _uiState.value.office != null ->
                _uiState.update { it.copy(isReplaceConfirmationVisible = true) }
            else -> startFixAttempt()
        }
    }

    private fun onPermissionResult(result: AttendanceAction.PermissionResult) {
        permission = result.permission
        refusal = if (permission == LocationPermission.Precise) {
            null
        } else {
            Refusal(canAskAgain = result.shouldShowRationale)
        }
        val continueSetOffice = setOfficeAfterPermission
        setOfficeAfterPermission = false
        refreshBlocker()
        if (continueSetOffice && permission == LocationPermission.Precise) onSetOfficeClick()
    }

    /** One blocker at a time, permission first. Before any denial, no permission is not one (A1). */
    private fun refreshBlocker() {
        val refusal = refusal
        val blocker = when {
            permission == LocationPermission.None && refusal != null ->
                LocationBlocker.PermissionDenied(refusal.canAskAgain)
            // Until a request says otherwise, assume the system still offers the upgrade.
            permission == LocationPermission.Approximate ->
                LocationBlocker.ApproximateOnly(canAskAgain = refusal?.canAskAgain ?: true)
            !locationSource.isLocationEnabled() -> LocationBlocker.LocationServicesOff
            else -> null
        }
        _uiState.update { it.copy(blocker = blocker) }
    }

    private fun startFixAttempt() {
        if (!locationSource.isLocationEnabled()) {
            _uiState.update { it.copy(blocker = LocationBlocker.LocationServicesOff) }
            return
        }
        fixJob = viewModelScope.launch {
            _uiState.update { it.copy(fixAttempt = FixAttempt()) }
            val outcome = awaitUsableFix()
            _uiState.update { it.copy(fixAttempt = null) }
            when (outcome) {
                is FixOutcome.Usable -> save(outcome.office)
                // Services turned off mid-attempt explain the failure better than its message.
                is FixOutcome.Failed -> if (locationSource.isLocationEnabled()) {
                    _events.send(outcome.event)
                } else {
                    _uiState.update { it.copy(blocker = LocationBlocker.LocationServicesOff) }
                }
            }
        }
    }

    /**
     * Collects fixes until the policy accepts one or [FIX_TIMEOUT_MILLIS] passes. Ending the
     * collection stops location updates.
     */
    private suspend fun awaitUsableFix(): FixOutcome {
        var bestInaccurate: FixVerdict.TooInaccurate? = null
        var sawStale = false
        var providerFailed = false

        val accepted = withTimeoutOrNull(FIX_TIMEOUT_MILLIS) {
            locationSource.fixes()
                // Play services missing or updates refused: no fix can come, so stop waiting now.
                .catch { providerFailed = true }
                .firstOrNull { fix ->
                    _uiState.update { it.copy(fixAttempt = FixAttempt(fix.accuracyMeters)) }
                    when (val verdict = LocationFixPolicy.evaluate(fix, elapsedRealtimeMillis())) {
                        FixVerdict.Accepted -> true
                        is FixVerdict.Stale -> {
                            sawStale = true
                            false
                        }
                        is FixVerdict.TooInaccurate -> {
                            bestInaccurate = moreAccurate(bestInaccurate, verdict)
                            false
                        }
                    }
                }
        }

        if (accepted != null) {
            return FixOutcome.Usable(
                SavedOffice(
                    latitude = accepted.latitude,
                    longitude = accepted.longitude,
                    // The policy accepts only fixes that report an accuracy.
                    accuracyMeters = checkNotNull(accepted.accuracyMeters),
                    savedAtEpochMillis = currentTimeMillis(),
                ),
            )
        }
        // A current but inaccurate fix says more about what to do (move to a window) than a stale one.
        val event = when {
            providerFailed -> AttendanceEvent.NoFix
            bestInaccurate != null -> AttendanceEvent.FixTooInaccurate(bestInaccurate.accuracyMeters)
            sawStale -> AttendanceEvent.FixStale
            else -> AttendanceEvent.NoFix
        }
        return FixOutcome.Failed(event)
    }

    private suspend fun save(office: SavedOffice) {
        try {
            officeStore.save(office)
        } catch (error: IOException) {
            _events.send(AttendanceEvent.OfficeSaveFailed)
        }
    }

    private data class Refusal(val canAskAgain: Boolean)

    private sealed interface FixOutcome {
        data class Usable(val office: SavedOffice) : FixOutcome
        data class Failed(val event: AttendanceEvent) : FixOutcome
    }

    private companion object {
        const val FIX_TIMEOUT_MILLIS = 15_000L
    }
}

/** The verdict with the better accuracy; a reported accuracy beats none. */
private fun moreAccurate(
    current: FixVerdict.TooInaccurate?,
    candidate: FixVerdict.TooInaccurate,
): FixVerdict.TooInaccurate {
    val currentAccuracy = current?.accuracyMeters ?: return candidate
    val candidateAccuracy = candidate.accuracyMeters ?: return current
    return if (candidateAccuracy < currentAccuracy) candidate else current
}
