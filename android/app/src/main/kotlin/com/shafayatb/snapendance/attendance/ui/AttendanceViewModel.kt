package com.shafayatb.snapendance.attendance.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.shafayatb.snapendance.attendance.location.FixVerdict
import com.shafayatb.snapendance.attendance.location.LocationFixPolicy
import com.shafayatb.snapendance.attendance.location.LocationSource
import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.marking.AttendanceEligibility
import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.marking.AttendanceStore
import com.shafayatb.snapendance.attendance.marking.Eligibility
import com.shafayatb.snapendance.attendance.office.OfficeStore
import com.shafayatb.snapendance.attendance.office.SavedOffice
import java.io.IOException
import java.util.Calendar
import java.util.TimeZone
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
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
 * clock) judges fix age, and [currentTimeMillis] stamps the saved office and attendance, whose
 * calendar day is read in [timeZone].
 */
class AttendanceViewModel(
    private val locationSource: LocationSource,
    private val officeStore: OfficeStore,
    private val attendanceStore: AttendanceStore,
    private val eligibility: AttendanceEligibility,
    private val elapsedRealtimeMillis: () -> Long,
    private val currentTimeMillis: () -> Long,
    private val timeZone: TimeZone,
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

    // A permission dialog is open. The system answers a second request at that point with an empty
    // result and drops the real answer, so no second one is sent until the first is answered.
    private var permissionRequestPending = false

    // Live distance (plan D2): one location request while the screen is started, an office is
    // saved, location is usable, and no Set Office attempt holds its own request.
    private var isScreenStarted = false
    private var trackingJob: Job? = null
    private var latestFix: LocationFix? = null
    private var trackingFailed = false
    private var staleCheckJob: Job? = null

    // Every tracked fix, for a Mark Attendance check waiting on the next one. Not replayed: the
    // check needs a fix taken after the tap.
    private val trackedFixes = MutableSharedFlow<LocationFix>(extraBufferCapacity = 1)
    private var markJob: Job? = null

    init {
        viewModelScope.launch {
            // The store is the source of truth: a newly saved office normally reaches the screen
            // from here (save() also sets it, for when this flow ended after a failed read).
            officeStore.office
                .catch { error ->
                    if (error !is IOException) throw error
                    emit(null)
                    _events.send(AttendanceEvent.OfficeLoadFailed)
                }
                .collect { office ->
                    _uiState.update { it.copy(office = office, isOfficeLoaded = true) }
                    updateTracking()
                }
        }
        viewModelScope.launch {
            attendanceStore.lastRecord
                .catch { error ->
                    if (error !is IOException) throw error
                    emit(null)
                    _events.send(AttendanceEvent.AttendanceLoadFailed)
                }
                .collect { record -> showAttendance(record) }
        }
    }

    fun onAction(action: AttendanceAction) {
        when (action) {
            AttendanceAction.SetOfficeClick -> onSetOfficeClick()
            AttendanceAction.ReplaceOfficeConfirm -> {
                // A second confirm can arrive before the dialog leaves the screen.
                if (!_uiState.value.isReplaceConfirmationVisible) return
                _uiState.update { it.copy(isReplaceConfirmationVisible = false) }
                startFixAttempt()
            }
            AttendanceAction.AllowLocationClick -> requestPermission()
            AttendanceAction.ReplaceOfficeDismiss ->
                _uiState.update { it.copy(isReplaceConfirmationVisible = false) }
            is AttendanceAction.ScreenResumed -> {
                // A change made in app settings makes the last request's answer out of date.
                if (action.permission != permission) refusal = null
                permission = action.permission
                isScreenStarted = true
                // Each return tries location updates again.
                trackingFailed = false
                // The day may have changed while the screen was away.
                showAttendance(_uiState.value.lastAttendance)
                refreshBlocker()
            }
            is AttendanceAction.PermissionResult -> onPermissionResult(action)
            AttendanceAction.MarkAttendanceClick -> onMarkAttendanceClick()
            AttendanceAction.ScreenStopped -> {
                // Silent: the card returns to what it showed before the attempt or check.
                isScreenStarted = false
                fixJob?.cancel()
                markJob?.cancel()
                _uiState.update { it.copy(fixAttempt = null, isCheckingAttendance = false) }
                updateTracking()
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
                requestPermission()
            }
            // Replacing cannot be undone, so one tap on the outlined button must not do it.
            _uiState.value.office != null ->
                _uiState.update { it.copy(isReplaceConfirmationVisible = true) }
            else -> startFixAttempt()
        }
    }

    private fun requestPermission() {
        if (permissionRequestPending) return
        permissionRequestPending = true
        viewModelScope.launch { _events.send(AttendanceEvent.RequestLocationPermission) }
    }

    private fun onPermissionResult(result: AttendanceAction.PermissionResult) {
        permissionRequestPending = false
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
        updateTracking()
    }

    private fun startFixAttempt() {
        if (fixJob?.isActive == true) return
        if (!locationSource.isLocationEnabled()) {
            _uiState.update { it.copy(blocker = LocationBlocker.LocationServicesOff) }
            updateTracking()
            return
        }
        fixJob = viewModelScope.launch {
            // The attempt holds the one location request; tracking resumes when it ends.
            _uiState.update { it.copy(fixAttempt = FixAttempt()) }
            updateTracking()
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
            updateTracking()
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
            // Normally the store's flow shows it too, but that flow ends after a failed read.
            _uiState.update { it.copy(office = office) }
        } catch (error: IOException) {
            _events.send(AttendanceEvent.OfficeSaveFailed)
        }
    }

    /** Starts or stops live tracking to match the screen, then refreshes the distance. */
    private fun updateTracking() {
        val state = _uiState.value
        val shouldTrack = isScreenStarted && state.office != null &&
            permission == LocationPermission.Precise && state.blocker == null &&
            state.fixAttempt == null && !trackingFailed
        if (shouldTrack && trackingJob?.isActive != true) {
            startTracking()
        } else if (!shouldTrack && trackingJob?.isActive == true) {
            stopTracking()
        }
        refreshDistance()
    }

    private fun startTracking() {
        trackingJob = viewModelScope.launch {
            locationSource.fixes()
                .catch {
                    // Play services missing or updates refused. The next resume tries again.
                    trackingFailed = true
                    latestFix = null
                    refreshDistance()
                }
                .collect { fix ->
                    latestFix = fix
                    refreshDistance()
                    scheduleStaleCheck(fix)
                    trackedFixes.tryEmit(fix)
                }
        }
    }

    private fun stopTracking() {
        trackingJob?.cancel()
        staleCheckJob?.cancel()
        markJob?.cancel()
        // A later start begins from "Locating", never from an old distance.
        latestFix = null
        _uiState.update { it.copy(isCheckingAttendance = false) }
    }

    /**
     * If no newer fix arrives, [fix] turns stale just after 30 s (plan D4). Then the screen
     * re-checks: no fixes may mean location was turned off from the quick-settings shade, which
     * does not pause the screen.
     */
    private fun scheduleStaleCheck(fix: LocationFix) {
        staleCheckJob?.cancel()
        val ageMillis = elapsedRealtimeMillis() - fix.elapsedRealtimeMillis
        val untilStaleMillis = LocationFixPolicy.MAX_AGE_MILLIS - ageMillis + 1
        if (untilStaleMillis <= 0) return
        staleCheckJob = viewModelScope.launch {
            delay(untilStaleMillis)
            if (!locationSource.isLocationEnabled()) {
                refreshBlocker()
            } else {
                refreshDistance()
            }
        }
    }

    private fun refreshDistance() {
        val state = _uiState.value
        val status = when {
            state.office == null -> DistanceStatus.NoOffice
            state.fixAttempt != null -> DistanceStatus.Locating
            trackingFailed -> DistanceStatus.Unavailable
            else -> when (val result = evaluate(state, latestFix)) {
                Eligibility.NoOffice -> DistanceStatus.NoOffice
                // Under a blocker the panel replaces the ring.
                Eligibility.LocationBlocked, Eligibility.WaitingForFix -> DistanceStatus.Locating
                is Eligibility.WeakFix -> DistanceStatus.Weak(
                    distanceMeters = result.distanceMeters,
                    accuracyMeters = latestFix?.accuracyMeters,
                    isStale = result.verdict is FixVerdict.Stale,
                )
                is Eligibility.OutOfRange -> DistanceStatus.OutOfRange(result.distanceMeters)
                is Eligibility.InRange -> DistanceStatus.InRange(result.distanceMeters)
            }
        }
        _uiState.update { it.copy(distance = status) }
    }

    private fun evaluate(state: AttendanceUiState, fix: LocationFix?): Eligibility =
        eligibility.evaluate(
            office = state.office,
            fix = fix,
            hasPrecisePermission = permission == LocationPermission.Precise,
            isLocationEnabled = locationSource.isLocationEnabled(),
            nowElapsedRealtimeMillis = elapsedRealtimeMillis(),
        )

    /**
     * Plan D5: the button's state may be up to 30 s old, so the tap waits for a usable fix taken
     * after it and checks the distance again before recording anything.
     */
    private fun onMarkAttendanceClick() {
        if (!_uiState.value.canMarkAttendance) return
        val tappedAt = elapsedRealtimeMillis()
        _uiState.update { it.copy(isCheckingAttendance = true) }
        markJob = viewModelScope.launch {
            val fix = withTimeoutOrNull(MARK_FIX_TIMEOUT_MILLIS) {
                trackedFixes.first { fix ->
                    fix.elapsedRealtimeMillis >= tappedAt &&
                        LocationFixPolicy.evaluate(fix, elapsedRealtimeMillis()) == FixVerdict.Accepted
                }
            }
            val result = fix?.let { evaluate(_uiState.value, it) }
            when (result) {
                is Eligibility.InRange -> markAttendance(result.distanceMeters)
                is Eligibility.OutOfRange ->
                    _events.send(AttendanceEvent.MarkOutOfRange(result.distanceMeters))
                else -> _events.send(AttendanceEvent.MarkNoFix)
            }
            _uiState.update { it.copy(isCheckingAttendance = false) }
        }
    }

    private suspend fun markAttendance(distanceMeters: Double) {
        val record = AttendanceRecord(currentTimeMillis(), distanceMeters.toFloat())
        try {
            attendanceStore.save(record)
            showAttendance(record)
        } catch (error: IOException) {
            _events.send(AttendanceEvent.MarkSaveFailed)
        }
    }

    private fun showAttendance(record: AttendanceRecord?) {
        val markedToday = record != null &&
            isSameDay(record.markedAtEpochMillis, currentTimeMillis(), timeZone)
        _uiState.update {
            it.copy(lastAttendance = record, isAttendanceLoaded = true, isMarkedToday = markedToday)
        }
    }

    private data class Refusal(val canAskAgain: Boolean)

    private sealed interface FixOutcome {
        data class Usable(val office: SavedOffice) : FixOutcome
        data class Failed(val event: AttendanceEvent) : FixOutcome
    }

    private companion object {
        const val FIX_TIMEOUT_MILLIS = 15_000L
        const val MARK_FIX_TIMEOUT_MILLIS = 10_000L
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

/** Whether two wall-clock times fall on the same calendar day in [timeZone]. */
private fun isSameDay(firstEpochMillis: Long, secondEpochMillis: Long, timeZone: TimeZone): Boolean {
    val first = Calendar.getInstance(timeZone).apply { timeInMillis = firstEpochMillis }
    val second = Calendar.getInstance(timeZone).apply { timeInMillis = secondEpochMillis }
    return first.get(Calendar.YEAR) == second.get(Calendar.YEAR) &&
        first.get(Calendar.DAY_OF_YEAR) == second.get(Calendar.DAY_OF_YEAR)
}
