package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.office.OfficeStore
import com.shafayatb.snapendance.attendance.office.SavedOffice
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

class FakeOfficeStore(initial: SavedOffice? = null) : OfficeStore {
    private val stored = MutableStateFlow(initial)

    val savedOffice: SavedOffice? get() = stored.value

    var readFailure: IOException? = null
    var saveFailure: IOException? = null

    var readGate: CompletableDeferred<Unit>? = null

    override val office: Flow<SavedOffice?> = flow {
        readGate?.await()
        readFailure?.let { throw it }
        emitAll(stored)
    }

    override suspend fun save(office: SavedOffice) {
        saveFailure?.let { throw it }
        stored.value = office
    }
}
