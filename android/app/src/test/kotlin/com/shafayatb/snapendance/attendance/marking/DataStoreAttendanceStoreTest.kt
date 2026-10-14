package com.shafayatb.snapendance.attendance.marking

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

class DataStoreAttendanceStoreTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val file: File by lazy { File(folder.root, "attendance_record.preferences_pb") }

    private fun <T> withStore(block: suspend (AttendanceStore) -> T): T = runBlocking {
        val job = Job()
        val dataStore = PreferenceDataStoreFactory.create(
            corruptionHandler = attendanceCorruptionHandler,
            scope = CoroutineScope(Dispatchers.IO + job),
            produceFile = { file },
        )
        try {
            block(DataStoreAttendanceStore(dataStore))
        } finally {
            job.cancelAndJoin()
        }
    }

    private val record = AttendanceRecord(markedAtEpochMillis = 1_791_870_060_000L, distanceMeters = 32.4f)

    @Test
    fun savedRecordReadsBackFromANewStoreInstance() {
        withStore { it.save(record) }

        assertEquals(record, withStore { it.lastRecord.first() })
    }

    @Test
    fun emptyFileReadsAsNoRecord() {
        assertNull(withStore { it.lastRecord.first() })
    }

    @Test
    fun corruptFileReadsAsNoRecordAndCanBeSavedOver() {
        file.writeText("not a preferences file")

        assertNull(withStore { it.lastRecord.first() })
        withStore { it.save(record) }
        assertEquals(record, withStore { it.lastRecord.first() })
    }
}
