package com.shafayatb.snapendance.attendance.office

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * The saved office location. An interface so ViewModel tests can use a fake that fails.
 *
 * [office] emits null while nothing is saved. Reading or saving throws `IOException` when the file
 * cannot be accessed; the caller decides what the user sees.
 */
interface OfficeStore {
    val office: Flow<SavedOffice?>

    suspend fun save(office: SavedOffice)
}

/** The app's one office-location DataStore (the delegate keeps it to one instance per process). */
val Context.officeDataStore: DataStore<Preferences> by preferencesDataStore(name = "office_location")

class DataStoreOfficeStore(private val dataStore: DataStore<Preferences>) : OfficeStore {
    override val office: Flow<SavedOffice?> = dataStore.data.map { prefs ->
        // A record missing any field is treated as not saved rather than shown with a made-up value.
        SavedOffice(
            latitude = prefs[LATITUDE] ?: return@map null,
            longitude = prefs[LONGITUDE] ?: return@map null,
            accuracyMeters = prefs[ACCURACY_METERS] ?: return@map null,
            savedAtEpochMillis = prefs[SAVED_AT_EPOCH_MILLIS] ?: return@map null,
        )
    }

    override suspend fun save(office: SavedOffice) {
        // One edit, so all four fields are written together or not at all.
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
