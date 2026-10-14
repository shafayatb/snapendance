package com.shafayatb.snapendance.attendance.location

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Looper
import androidx.core.location.LocationManagerCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

class FusedLocationSource(context: Context) : LocationSource {
    private val appContext = context.applicationContext
    private val client = LocationServices.getFusedLocationProviderClient(appContext)
    private val locationManager = appContext.getSystemService(LocationManager::class.java)

    @SuppressLint("MissingPermission")
    override fun fixes(): Flow<LocationFix> = callbackFlow {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, UPDATE_INTERVAL_MILLIS)
            .build()
        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.locations.forEach { trySend(it.toLocationFix()) }
            }
        }
        client.requestLocationUpdates(request, callback, Looper.getMainLooper())
            .addOnFailureListener { close(it) }
        awaitClose { client.removeLocationUpdates(callback) }
    }

    override fun isLocationEnabled(): Boolean =
        LocationManagerCompat.isLocationEnabled(locationManager)

    private companion object {
        const val UPDATE_INTERVAL_MILLIS = 1_000L
    }
}

private fun Location.toLocationFix() = LocationFix(
    latitude = latitude,
    longitude = longitude,
    accuracyMeters = if (hasAccuracy()) accuracy else null,
    elapsedRealtimeMillis = elapsedRealtimeNanos / 1_000_000,
)
