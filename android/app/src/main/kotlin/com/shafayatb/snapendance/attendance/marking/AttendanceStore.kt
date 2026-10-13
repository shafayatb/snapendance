package com.shafayatb.snapendance.attendance.marking

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * The last attendance record. An interface so ViewModel tests can use a fake that fails.
 *
 * [lastRecord] emits null while nothing is saved. Reading or saving throws `IOException` when the
 * file cannot be accessed.
 */
interface AttendanceStore {
    val lastRecord: Flow<AttendanceRecord?>

    suspend fun save(record: AttendanceRecord)
}

/** A corrupt file is replaced by an empty one (no record), as for the office file. */
internal val attendanceCorruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() }

val Context.attendanceDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "attendance_record",
    corruptionHandler = attendanceCorruptionHandler,
)

class DataStoreAttendanceStore(private val dataStore: DataStore<Preferences>) : AttendanceStore {
    override val lastRecord: Flow<AttendanceRecord?> = dataStore.data.map { prefs ->
        // A record missing a field is treated as not saved rather than shown with a made-up value.
        AttendanceRecord(
            markedAtEpochMillis = prefs[MARKED_AT_EPOCH_MILLIS] ?: return@map null,
            distanceMeters = prefs[DISTANCE_METERS] ?: return@map null,
        )
    }

    override suspend fun save(record: AttendanceRecord) {
        // One edit, so both fields are written together or not at all.
        dataStore.edit { prefs ->
            prefs[MARKED_AT_EPOCH_MILLIS] = record.markedAtEpochMillis
            prefs[DISTANCE_METERS] = record.distanceMeters
        }
    }

    private companion object {
        val MARKED_AT_EPOCH_MILLIS = longPreferencesKey("marked_at_epoch_millis")
        val DISTANCE_METERS = floatPreferencesKey("distance_meters")
    }
}
