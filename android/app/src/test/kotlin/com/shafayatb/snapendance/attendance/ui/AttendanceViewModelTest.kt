package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.office.SavedOffice
import java.io.IOException
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
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModelTest {
    private val source = FakeLocationSource()
    private var store = FakeOfficeStore()

    // Fix ages are measured against this; fixes are built relative to it.
    private val nowElapsedRealtime = 1_000_000L
    private val nowEpochMillis = 1_791_870_060_000L

    private val savedOffice = SavedOffice(
        latitude = 23.7937,
        longitude = 90.4066,
        accuracyMeters = 8f,
        savedAtEpochMillis = 1_791_800_000_000L,
    )

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** A ViewModel whose screen has resumed holding [permission]. */
    private fun viewModel(permission: LocationPermission = LocationPermission.Precise) =
        AttendanceViewModel(
            locationSource = source,
            officeStore = store,
            elapsedRealtimeMillis = { nowElapsedRealtime },
            currentTimeMillis = { nowEpochMillis },
        ).apply { onAction(AttendanceAction.ScreenResumed(permission)) }

    private fun fix(accuracyMeters: Float?, ageMillis: Long = 0L, latitude: Double = 23.8103) =
        LocationFix(
            latitude = latitude,
            longitude = 90.4125,
            accuracyMeters = accuracyMeters,
            elapsedRealtimeMillis = nowElapsedRealtime - ageMillis,
        )

    /** Collects the ViewModel's events for the rest of the test. */
    private fun TestScope.eventsOf(viewModel: AttendanceViewModel): List<AttendanceEvent> {
        val events = mutableListOf<AttendanceEvent>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.events.toList(events)
        }
        return events
    }

    @Test
    fun savedOfficeIsShownOnStart() = runTest {
        store = FakeOfficeStore(savedOffice)

        assertEquals(savedOffice, viewModel().uiState.value.office)
    }

    @Test
    fun unreadableOfficeShowsAsNotSetWithAMessage() = runTest {
        store.readFailure = IOException("corrupt file")
        val viewModel = viewModel()
        val events = eventsOf(viewModel)

        assertNull(viewModel.uiState.value.office)
        assertEquals(listOf(AttendanceEvent.OfficeLoadFailed), events)
    }

    @Test
    fun acceptedFixIsSavedAndShownAndUpdatesStop() = runTest {
        val viewModel = viewModel()

        viewModel.onAction(AttendanceAction.SetOfficeClick)
        assertNotNull(viewModel.uiState.value.fixAttempt)
        source.send(fix(accuracyMeters = 6f))

        val expected = SavedOffice(23.8103, 90.4125, 6f, nowEpochMillis)
        assertEquals(expected, store.savedOffice)
        assertEquals(expected, viewModel.uiState.value.office)
        assertNull(viewModel.uiState.value.fixAttempt)
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun staleAndInaccurateFixesAreSkippedUntilAUsableOneArrives() = runTest {
        val viewModel = viewModel()
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        source.send(fix(accuracyMeters = 5f, ageMillis = 45_000L, latitude = 1.0))
        source.send(fix(accuracyMeters = 40f, latitude = 2.0))

        assertNull(store.savedOffice)
        assertEquals(FixAttempt(latestAccuracyMeters = 40f), viewModel.uiState.value.fixAttempt)

        source.send(fix(accuracyMeters = 12f, latitude = 3.0))

        assertEquals(3.0, store.savedOffice?.latitude)
        assertEquals(12f, store.savedOffice?.accuracyMeters)
    }

    @Test
    fun noFixWithin15SecondsReportsNoFixAndSavesNothing() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        advanceTimeBy(14_999L)
        assertNotNull(viewModel.uiState.value.fixAttempt)
        assertEquals(emptyList<AttendanceEvent>(), events)

        advanceTimeBy(2L)
        assertEquals(listOf(AttendanceEvent.NoFix), events)
        assertNull(viewModel.uiState.value.fixAttempt)
        assertNull(store.savedOffice)
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun onlyInaccurateFixesReportTheBestAccuracySeen() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        source.send(fix(accuracyMeters = 60f))
        source.send(fix(accuracyMeters = 40f))
        source.send(fix(accuracyMeters = null))
        source.send(fix(accuracyMeters = 45f))
        advanceTimeBy(15_001L)

        assertEquals(listOf(AttendanceEvent.FixTooInaccurate(bestAccuracyMeters = 40f)), events)
        assertNull(store.savedOffice)
    }

    @Test
    fun onlyStaleFixesReportStale() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        source.send(fix(accuracyMeters = 5f, ageMillis = 90_000L))
        advanceTimeBy(15_001L)

        assertEquals(listOf(AttendanceEvent.FixStale), events)
        assertNull(store.savedOffice)
    }

    @Test
    fun providerFailureReportsNoFixAtOnce() = runTest {
        source.failure = IllegalStateException("Play services unavailable")
        val viewModel = viewModel()
        val events = eventsOf(viewModel)

        viewModel.onAction(AttendanceAction.SetOfficeClick)

        assertEquals(listOf(AttendanceEvent.NoFix), events)
        assertNull(viewModel.uiState.value.fixAttempt)
    }

    @Test
    fun storageErrorReportsSaveFailureAndShowsNoOffice() = runTest {
        store.saveFailure = IOException("disk full")
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        source.send(fix(accuracyMeters = 6f))

        assertEquals(listOf(AttendanceEvent.OfficeSaveFailed), events)
        assertNull(viewModel.uiState.value.office)
        assertNull(viewModel.uiState.value.fixAttempt)
    }

    @Test
    fun secondTapWhileFetchingStartsNoSecondRequest() = runTest {
        val viewModel = viewModel()

        viewModel.onAction(AttendanceAction.SetOfficeClick)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        assertEquals(1, source.activeRequests)
    }

    @Test
    fun replacingASavedOfficeNeedsConfirmation() = runTest {
        store = FakeOfficeStore(savedOffice)
        val viewModel = viewModel()

        viewModel.onAction(AttendanceAction.SetOfficeClick)
        assertTrue(viewModel.uiState.value.isReplaceConfirmationVisible)
        assertEquals(0, source.activeRequests)

        viewModel.onAction(AttendanceAction.ReplaceOfficeConfirm)
        assertFalse(viewModel.uiState.value.isReplaceConfirmationVisible)
        source.send(fix(accuracyMeters = 6f))

        assertEquals(23.8103, viewModel.uiState.value.office?.latitude)
    }

    @Test
    fun dismissingReplaceKeepsTheSavedOffice() = runTest {
        store = FakeOfficeStore(savedOffice)
        val viewModel = viewModel()

        viewModel.onAction(AttendanceAction.SetOfficeClick)
        viewModel.onAction(AttendanceAction.ReplaceOfficeDismiss)

        assertFalse(viewModel.uiState.value.isReplaceConfirmationVisible)
        assertEquals(0, source.activeRequests)
        assertEquals(savedOffice, viewModel.uiState.value.office)
    }

    @Test
    fun stoppingTheScreenCancelsTheAttemptSilently() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        viewModel.onAction(AttendanceAction.ScreenStopped)

        assertNull(viewModel.uiState.value.fixAttempt)
        assertEquals(0, source.activeRequests)
        advanceTimeBy(20_000L)
        assertEquals(emptyList<AttendanceEvent>(), events)
    }

    @Test
    fun tapWithoutPermissionAsksForItAndGrantingPreciseStartsTheFetch() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        val events = eventsOf(viewModel)

        viewModel.onAction(AttendanceAction.SetOfficeClick)
        assertEquals(listOf(AttendanceEvent.RequestLocationPermission), events)
        assertEquals(0, source.activeRequests)

        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.Precise, false))
        source.send(fix(accuracyMeters = 6f))

        assertEquals(23.8103, store.savedOffice?.latitude)
        assertNull(viewModel.uiState.value.blocker)
    }

    @Test
    fun firstRunWithoutPermissionShowsNoBlocker() = runTest {
        // A1: the button stays enabled until the user has been asked.
        assertNull(viewModel(LocationPermission.None).uiState.value.blocker)
    }

    @Test
    fun grantingApproximateOnlyShowsTheApproximateBlockerAndDoesNotFetch() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.Approximate, true))

        assertEquals(LocationBlocker.ApproximateOnly(canAskAgain = true), viewModel.uiState.value.blocker)
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun resumingWithApproximateOnlyShowsTheApproximateBlocker() = runTest {
        val viewModel = viewModel(LocationPermission.Approximate)

        assertEquals(LocationBlocker.ApproximateOnly(canAskAgain = true), viewModel.uiState.value.blocker)
    }

    @Test
    fun approximateAfterTheSystemStopsAskingPointsToAppSettings() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        // Precise was refused and the system will not show the upgrade dialog again, so asking
        // from A7 would return at once with nothing changed.
        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.Approximate, false))
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Approximate))

        assertEquals(
            LocationBlocker.ApproximateOnly(canAskAgain = false),
            viewModel.uiState.value.blocker,
        )
    }

    @Test
    fun changingThePermissionInSettingsForgetsTheLastRefusal() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        viewModel.onAction(AttendanceAction.SetOfficeClick)
        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.None, false))

        // Approximate granted in app settings: the old "won't ask again" no longer applies.
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Approximate))

        assertEquals(
            LocationBlocker.ApproximateOnly(canAskAgain = true),
            viewModel.uiState.value.blocker,
        )
    }

    @Test
    fun denialThatCanBeAskedAgainOffersToAskAgain() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.None, true))
        // The dialog closing resumes the screen; that must not hide the blocker.
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.None))

        assertEquals(
            LocationBlocker.PermissionDenied(canAskAgain = true),
            viewModel.uiState.value.blocker,
        )
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun permanentDenialPointsToAppSettings() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.None, false))
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.None))

        assertEquals(
            LocationBlocker.PermissionDenied(canAskAgain = false),
            viewModel.uiState.value.blocker,
        )
    }

    @Test
    fun resumingAfterPermissionIsGrantedInSettingsClearsTheBlocker() = runTest {
        val viewModel = viewModel(LocationPermission.None)
        viewModel.onAction(AttendanceAction.SetOfficeClick)
        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.None, false))
        assertNotNull(viewModel.uiState.value.blocker)

        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Precise))

        assertNull(viewModel.uiState.value.blocker)
        // Returning from settings is not a tap; the user starts the fetch.
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun preciseGrantedFromABlockerDoesNotStartAFetchByItself() = runTest {
        val viewModel = viewModel(LocationPermission.Approximate)
        assertEquals(LocationBlocker.ApproximateOnly(canAskAgain = true), viewModel.uiState.value.blocker)

        // A7's "Use precise location" asks without Set Office Location being tapped.
        viewModel.onAction(AttendanceAction.PermissionResult(LocationPermission.Precise, false))

        assertNull(viewModel.uiState.value.blocker)
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun servicesOffShowsTheServicesBlockerOnResume() = runTest {
        source.locationEnabled = false

        val viewModel = viewModel()

        assertEquals(LocationBlocker.LocationServicesOff, viewModel.uiState.value.blocker)
    }

    @Test
    fun tapWithServicesOffShowsTheServicesBlockerAndDoesNotFetch() = runTest {
        val viewModel = viewModel()
        source.locationEnabled = false

        viewModel.onAction(AttendanceAction.SetOfficeClick)

        assertEquals(LocationBlocker.LocationServicesOff, viewModel.uiState.value.blocker)
        assertNull(viewModel.uiState.value.fixAttempt)
        assertEquals(0, source.activeRequests)
    }

    @Test
    fun resumingWithServicesBackOnClearsTheBlocker() = runTest {
        source.locationEnabled = false
        val viewModel = viewModel()
        assertEquals(LocationBlocker.LocationServicesOff, viewModel.uiState.value.blocker)

        source.locationEnabled = true
        viewModel.onAction(AttendanceAction.ScreenResumed(LocationPermission.Precise))

        assertNull(viewModel.uiState.value.blocker)
    }

    @Test
    fun servicesTurnedOffDuringAnAttemptShowTheServicesBlockerInsteadOfNoFix() = runTest {
        val viewModel = viewModel()
        val events = eventsOf(viewModel)
        viewModel.onAction(AttendanceAction.SetOfficeClick)

        source.locationEnabled = false
        advanceTimeBy(15_001L)

        assertEquals(LocationBlocker.LocationServicesOff, viewModel.uiState.value.blocker)
        assertEquals(emptyList<AttendanceEvent>(), events)
        assertNull(store.savedOffice)
    }
}
