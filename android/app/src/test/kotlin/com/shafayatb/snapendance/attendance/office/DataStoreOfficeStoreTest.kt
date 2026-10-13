package com.shafayatb.snapendance.attendance.office

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class DataStoreOfficeStoreTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val file: File by lazy { File(folder.root, "office_location.preferences_pb") }

    /**
     * Runs [block] with a store on [file] whose DataStore is closed afterwards, so the next call
     * opens a fresh instance on the same file, as after a process restart.
     */
    private fun <T> withStore(block: suspend (OfficeStore) -> T): T = runBlocking {
        val job = Job()
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + job),
            produceFile = { file },
        )
        try {
            block(DataStoreOfficeStore(dataStore))
        } finally {
            job.cancelAndJoin()
        }
    }

    @Test
    fun savedOfficeReadsBackFromANewStoreInstance() {
        val office = SavedOffice(
            latitude = 23.793712,
            longitude = 90.406591,
            accuracyMeters = 6.5f,
            savedAtEpochMillis = 1_791_870_060_000L,
        )

        withStore { it.save(office) }

        assertEquals(office, withStore { it.office.first() })
    }

    @Test
    fun emptyFileReadsAsNoOffice() {
        assertNull(withStore { it.office.first() })
    }
}
