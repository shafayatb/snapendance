package com.shafayatb.snapendance.attendance.office

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

interface OfficeStore {
    val office: Flow<SavedOffice?>

    suspend fun save(office: SavedOffice)
}

internal val officeCorruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() }

val Context.officeDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "office_location",
    corruptionHandler = officeCorruptionHandler,
)

class DataStoreOfficeStore(private val dataStore: DataStore<Preferences>) : OfficeStore {
    override val office: Flow<SavedOffice?> = dataStore.data.map { prefs ->
        SavedOffice(
            latitude = prefs[LATITUDE] ?: return@map null,
            longitude = prefs[LONGITUDE] ?: return@map null,
            accuracyMeters = prefs[ACCURACY_METERS] ?: return@map null,
            savedAtEpochMillis = prefs[SAVED_AT_EPOCH_MILLIS] ?: return@map null,
        )
    }

    override suspend fun save(office: SavedOffice) {
        dataStore.edit { prefs ->
            prefs[LATITUDE] = office.latitude
            prefs[LONGITUDE] = office.longitude
            prefs[ACCURACY_METERS] = office.accuracyMeters
            prefs[SAVED_AT_EPOCH_MILLIS] = office.savedAtEpochMillis
        }
    }

    private companion object {
        val LATITUDE = doublePreferencesKey("latitude")
        val LONGITUDE = doublePreferencesKey("longitude")
        val ACCURACY_METERS = floatPreferencesKey("accuracy_meters")
        val SAVED_AT_EPOCH_MILLIS = longPreferencesKey("saved_at_epoch_millis")
    }
}
