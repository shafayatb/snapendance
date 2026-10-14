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

    private val _events = Channel<AttendanceEvent>(Channel.BUFFERED)
    val events: Flow<AttendanceEvent> = _events.receiveAsFlow()

    private var fixJob: Job? = null

    private var permission = LocationPermission.None

    private var refusal: Refusal? = null

    private var setOfficeAfterPermission = false

    private var permissionRequestPending = false

    private var isScreenStarted = false
    private var trackingJob: Job? = null
    private var latestFix: LocationFix? = null
    private var trackingFailed = false
    private var staleCheckJob: Job? = null

    private val trackedFixes = MutableSharedFlow<LocationFix>(extraBufferCapacity = 1)
    private var markJob: Job? = null

    init {
        viewModelScope.launch {
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
                if (!_uiState.value.isReplaceConfirmationVisible) return
                _uiState.update { it.copy(isReplaceConfirmationVisible = false) }
                startFixAttempt()
            }
            AttendanceAction.AllowLocationClick -> requestPermission()
            AttendanceAction.ReplaceOfficeDismiss ->
                _uiState.update { it.copy(isReplaceConfirmationVisible = false) }
            is AttendanceAction.ScreenResumed -> {
                if (action.permission != permission) refusal = null
                permission = action.permission
                isScreenStarted = true
                trackingFailed = false
                if (_uiState.value.isAttendanceLoaded) {
                    showAttendance(_uiState.value.lastAttendance)
                }
                refreshBlocker()
            }
            is AttendanceAction.PermissionResult -> onPermissionResult(action)
            AttendanceAction.MarkAttendanceClick -> onMarkAttendanceClick()
            AttendanceAction.ScreenStopped -> {
                isScreenStarted = false
                fixJob?.cancel()
                markJob?.cancel()
                _uiState.update { it.copy(fixAttempt = null, isCheckingAttendance = false) }
                updateTracking()
            }
        }
    }

    private fun onSetOfficeClick() {
        if (fixJob?.isActive == true) return
        if (!_uiState.value.isOfficeLoaded) return
        when {
            permission != LocationPermission.Precise -> {
                setOfficeAfterPermission = true
                requestPermission()
            }
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

    private fun refreshBlocker() {
        val refusal = refusal
        val blocker = when {
            permission == LocationPermission.None && refusal != null ->
                LocationBlocker.PermissionDenied(refusal.canAskAgain)
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
            _uiState.update { it.copy(fixAttempt = FixAttempt()) }
            updateTracking()
            val outcome = awaitUsableFix()
            _uiState.update { it.copy(fixAttempt = null) }
            when (outcome) {
                is FixOutcome.Usable -> save(outcome.office)
                is FixOutcome.Failed -> if (locationSource.isLocationEnabled()) {
                    _events.send(outcome.event)
                } else {
                    _uiState.update { it.copy(blocker = LocationBlocker.LocationServicesOff) }
                }
            }
            updateTracking()
        }
    }

    private suspend fun awaitUsableFix(): FixOutcome {
        var bestInaccurate: FixVerdict.TooInaccurate? = null
        var sawStale = false
        var providerFailed = false

        val accepted = withTimeoutOrNull(FIX_TIMEOUT_MILLIS) {
            locationSource.fixes()
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
                    accuracyMeters = checkNotNull(accepted.accuracyMeters),
                    savedAtEpochMillis = currentTimeMillis(),
                ),
            )
        }
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
            _uiState.update { it.copy(office = office) }
        } catch (error: IOException) {
            _events.send(AttendanceEvent.OfficeSaveFailed)
        }
    }

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
        latestFix = null
        _uiState.update { it.copy(isCheckingAttendance = false) }
    }

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

private fun moreAccurate(
    current: FixVerdict.TooInaccurate?,
    candidate: FixVerdict.TooInaccurate,
): FixVerdict.TooInaccurate {
    val currentAccuracy = current?.accuracyMeters ?: return candidate
    val candidateAccuracy = candidate.accuracyMeters ?: return current
    return if (candidateAccuracy < currentAccuracy) candidate else current
}

private fun isSameDay(firstEpochMillis: Long, secondEpochMillis: Long, timeZone: TimeZone): Boolean {
    val first = Calendar.getInstance(timeZone).apply { timeInMillis = firstEpochMillis }
    val second = Calendar.getInstance(timeZone).apply { timeInMillis = secondEpochMillis }
    return first.get(Calendar.YEAR) == second.get(Calendar.YEAR) &&
        first.get(Calendar.DAY_OF_YEAR) == second.get(Calendar.DAY_OF_YEAR)
}
