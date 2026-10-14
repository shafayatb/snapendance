package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.marking.AttendanceEligibility
import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.marking.FlatDistanceCalculator
import com.shafayatb.snapendance.attendance.office.SavedOffice
import java.io.IOException
import java.util.TimeZone
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceDistanceTest {
    private val source = FakeLocationSource()
    private var officeStore = FakeOfficeStore(
        SavedOffice(latitude = 0.0, longitude = 90.4066, accuracyMeters = 6f, savedAtEpochMillis = 0L),
    )
    private var attendanceStore = FakeAttendanceStore()

    private val todayEpochMillis = 1_791_946_800_000L
    private val dayMillis = 86_400_000L
    private val startElapsedRealtime = 1_000_000L

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.viewModel(permission: LocationPermission = LocationPermission.Precise) =
        AttendanceViewModel(
            locationSource = source,
            officeStore = officeStore,
            attendanceStore = attendanceStore,
            eligibility = AttendanceEligibility(FlatDistanceCalculator),
            elapsedRealtimeMillis = { elapsedNow() },
            currentTimeMillis = { todayEpochMillis + testScheduler.currentTime },
            timeZone = TimeZone.getTimeZone("UTC"),
        ).apply { onAction(AttendanceAction.ScreenResumed(permission)) }

    private fun TestScope.elapsedNow() = startElapsedRealtime + testScheduler.currentTime

    private fun TestScope.fix(distanceMeters: Double, accuracyMeters: Float = 8f) = LocationFix(
        latitude = distanceMeters,
        longitude = 90.4066,
        accuracyMeters = accuracyMeters,
        elapsedRealtimeMillis = elapsedNow(),
    )

    private fun TestScope.eventsOf(viewModel: AttendanceViewModel): List<AttendanceEvent> {
        val events = mutableListOf<AttendanceEvent>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.events.toList(events)
        }
        return events
    }

    @Test
    fun trackingStartsOnResumeAndWaitsForTheFirstFix() = runTest {
        val viewModel = viewModel()

        assertEquals(1, source.activeRequests)
        assertEquals(DistanceStatus.Locating, viewModel.uiState.value.distance)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun eachFixUpdatesTheDistance() = runTest {
        val viewModel = viewModel()

        source.send(fix(120.0))
        assertEquals(DistanceStatus.OutOfRange(120.0), viewModel.uiState.value.distance)
        assertFalse(viewModel.uiState.value.canMarkAttendance)

        source.send(fix(32.0))
        assertEquals(DistanceStatus.InRange(32.0), viewModel.uiState.value.distance)
        assertTrue(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun movingFrom49To51MetersLocksAgain() = runTest {
        val viewModel = viewModel()

        source.send(fix(49.0))
        assertTrue(viewModel.uiState.value.canMarkAttendance)
        source.send(fix(50.0))
        assertTrue(viewModel.uiState.value.canMarkAttendance)
        source.send(fix(51.0))

        assertEquals(DistanceStatus.OutOfRange(51.0), viewModel.uiState.value.distance)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun inaccurateFixInRangeIsWeakAndLocked() = runTest {
        val viewModel = viewModel()

        source.send(fix(10.0, accuracyMeters = 65f))

        assertEquals(
            DistanceStatus.Weak(10.0, accuracyMeters = 65f, isStale = false),
            viewModel.uiState.value.distance,
        )
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun noFixFor30SecondsTurnsWeakAndLocks() = runTest {
        val viewModel = viewModel()
        source.send(fix(20.0))

        advanceTimeBy(30_000L)
        assertTrue(viewModel.uiState.value.canMarkAttendance)

        advanceTimeBy(2L)
        assertEquals(
            DistanceStatus.Weak(20.0, accuracyMeters = 8f, isStale = true),
            viewModel.uiState.value.distance,
        )
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun stoppingRemovesTheRequestAndResumeStartsFromLocating() = runTest {
        val viewModel = viewModel()
        source.send(fix(20.0))

        viewModel.onAction(AttendanceAction.ScreenStopped)
        assertEquals(0, source.activeRequests)

        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Precise))
        assertEquals(1, source.activeRequests)
        assertEquals(DistanceStatus.Locating, viewModel.uiState.value.distance)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun noOfficeMeansNoTracking() = runTest {
        officeStore = FakeOfficeStore()
        val viewModel = viewModel()

        assertEquals(0, source.activeRequests)
        assertEquals(DistanceStatus.NoOffice, viewModel.uiState.value.distance)
    }

    @Test
    fun approximatePermissionMeansNoTracking() = runTest {
        val viewModel = viewModel(LocationPermission.Approximate)

        assertEquals(0, source.activeRequests)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun servicesOffMeansNoTracking() = runTest {
        source.locationEnabled = false
        val viewModel = viewModel()

        assertEquals(0, source.activeRequests)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun servicesTurnedOffOnScreenShowTheBlockerOnceTheFixGoesStale() = runTest {
        val viewModel = viewModel()
        source.send(fix(20.0))

        source.locationEnabled = false
        advanceTimeBy(30_002L)

        assertEquals(LocationBlocker.LocationServicesOff, viewModel.uiState.value.blocker)
        assertEquals(0, source.activeRequests)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun setOfficeAttemptKeepsOneRequestAndTrackingResumesAgainstTheNewOffice() = runTest {
        val viewModel = viewModel()
        source.send(fix(200.0))

        viewModel.onAction(AttendanceAction.SetOfficeClick)
        viewModel.onAction(AttendanceAction.ReplaceOfficeConfirm)
        assertEquals(1, source.activeRequests)
        assertEquals(DistanceStatus.Locating, viewModel.uiState.value.distance)

        source.send(fix(200.0))
        assertEquals(1, source.activeRequests)
        assertEquals(DistanceStatus.Locating, viewModel.uiState.value.distance)

        source.send(fix(210.0))
        assertEquals(DistanceStatus.InRange(10.0), viewModel.uiState.value.distance)
    }

    @Test
    fun providerFailureShowsUnavailableAndResumeTriesAgain() = runTest {
        source.failure = IllegalStateException("Play services unavailable")
        val viewModel = viewModel()

        assertEquals(DistanceStatus.Unavailable, viewModel.uiState.value.distance)

        source.failure = null
        viewModel.onAction(AttendanceAction.ScreenStopped)
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Precise))
        assertEquals(1, source.activeRequests)
        assertEquals(DistanceStatus.Locating, viewModel.uiState.value.distance)
    }

    @Test
    fun markingWaitsForAFreshFixAndRecordsTimeAndDistance() = runTest {
        val viewModel = viewModel()
        source.send(fix(30.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        assertTrue(viewModel.uiState.value.isCheckingAttendance)
        assertNull(attendanceStore.savedRecord)

        advanceTimeBy(1_000L)
        source.send(fix(32.0))

        val expected = AttendanceRecord(todayEpochMillis + 1_000L, distanceMeters = 32f)
        assertEquals(expected, attendanceStore.savedRecord)
        assertEquals(expected, viewModel.uiState.value.lastAttendance)
        assertTrue(viewModel.uiState.value.isMarkedToday)
        assertFalse(viewModel.uiState.value.isCheckingAttendance)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun movingOutOfRangeAfterTheButtonEnabledRecordsNothing() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        source.send(fix(49.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        source.send(fix(51.0))

        assertNull(attendanceStore.savedRecord)
        assertEquals(listOf(AttendanceEvent.MarkOutOfRange(51.0)), events)
        assertFalse(viewModel.uiState.value.isCheckingAttendance)
        assertFalse(viewModel.uiState.value.isMarkedToday)
    }

    @Test
    fun aFixTakenBeforeTheTapIsNotUsed() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        source.send(fix(20.0))
        val beforeTap = fix(20.0)

        advanceTimeBy(500L)
        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        source.send(beforeTap)

        assertNull(attendanceStore.savedRecord)
        assertTrue(viewModel.uiState.value.isCheckingAttendance)
        assertEquals(emptyList<AttendanceEvent>(), events)
    }

    @Test
    fun noUsableFixWithin10SecondsRecordsNothing() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        source.send(fix(20.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        source.send(fix(20.0, accuracyMeters = 60f))
        advanceTimeBy(10_001L)

        assertNull(attendanceStore.savedRecord)
        assertEquals(listOf(AttendanceEvent.MarkNoFix), events)
        assertFalse(viewModel.uiState.value.isCheckingAttendance)
    }

    @Test
    fun storageFailureWhileMarkingIsReported() = runTest {
        attendanceStore.saveFailure = IOException("disk full")
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        source.send(fix(20.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        source.send(fix(20.0))

        assertEquals(listOf(AttendanceEvent.MarkSaveFailed), events)
        assertFalse(viewModel.uiState.value.isMarkedToday)
        assertFalse(viewModel.uiState.value.isCheckingAttendance)
    }

    @Test
    fun secondTapWhileCheckingRecordsOnce() = runTest {
        val viewModel = viewModel()
        source.send(fix(20.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        advanceTimeBy(1_000L)
        source.send(fix(21.0))
        advanceTimeBy(1_000L)
        source.send(fix(22.0))

        assertEquals(AttendanceRecord(todayEpochMillis + 1_000L, 21f), attendanceStore.savedRecord)
    }

    @Test
    fun tapWhileOutOfRangeDoesNothing() = runTest {
        val viewModel = viewModel()
        source.send(fix(80.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        source.send(fix(20.0))

        assertFalse(viewModel.uiState.value.isCheckingAttendance)
        assertNull(attendanceStore.savedRecord)
    }

    @Test
    fun stoppingWhileCheckingRecordsNothing() = runTest {
        val viewModel = viewModel()
        source.send(fix(20.0))

        viewModel.onAction(AttendanceAction.MarkAttendanceClick)
        viewModel.onAction(AttendanceAction.ScreenStopped)
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Precise))
        source.send(fix(20.0))

        assertNull(attendanceStore.savedRecord)
        assertFalse(viewModel.uiState.value.isCheckingAttendance)
    }

    @Test
    fun recordFromTodayShowsAsMarkedAndBlocksASecondMark() = runTest {
        attendanceStore = FakeAttendanceStore(AttendanceRecord(todayEpochMillis - 3_600_000L, 12f))
        val viewModel = viewModel()
        source.send(fix(20.0))

        assertTrue(viewModel.uiState.value.isMarkedToday)
        assertFalse(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun recordFromYesterdayIsShownButDoesNotBlockMarking() = runTest {
        val yesterday = AttendanceRecord(todayEpochMillis - dayMillis, 12f)
        attendanceStore = FakeAttendanceStore(yesterday)
        val viewModel = viewModel()
        source.send(fix(20.0))

        assertEquals(yesterday, viewModel.uiState.value.lastAttendance)
        assertFalse(viewModel.uiState.value.isMarkedToday)
        assertTrue(viewModel.uiState.value.canMarkAttendance)
    }

    @Test
    fun unreadableRecordShowsNoneWithAMessage() = runTest {
        attendanceStore.readFailure = IOException("corrupt file")
        val viewModel = viewModel()
        val events = eventsOf(viewModel)

        assertNull(viewModel.uiState.value.lastAttendance)
        assertEquals(listOf(AttendanceEvent.AttendanceLoadFailed), events)
    }
}
