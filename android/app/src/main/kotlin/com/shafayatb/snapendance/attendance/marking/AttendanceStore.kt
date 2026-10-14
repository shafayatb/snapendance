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

interface AttendanceStore {
    val lastRecord: Flow<AttendanceRecord?>

    suspend fun save(record: AttendanceRecord)
}

internal val attendanceCorruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() }

val Context.attendanceDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "attendance_record",
    corruptionHandler = attendanceCorruptionHandler,
)

class DataStoreAttendanceStore(private val dataStore: DataStore<Preferences>) : AttendanceStore {
    override val lastRecord: Flow<AttendanceRecord?> = dataStore.data.map { prefs ->
        AttendanceRecord(
            markedAtEpochMillis = prefs[MARKED_AT_EPOCH_MILLIS] ?: return@map null,
            distanceMeters = prefs[DISTANCE_METERS] ?: return@map null,
        )
    }

    override suspend fun save(record: AttendanceRecord) {
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
