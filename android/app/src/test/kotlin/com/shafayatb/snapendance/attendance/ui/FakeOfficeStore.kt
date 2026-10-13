package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.office.OfficeStore
import com.shafayatb.snapendance.attendance.office.SavedOffice
import java.io.IOException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

/** An in-memory [OfficeStore] that can fail on read or save like the DataStore file. */
class FakeOfficeStore(initial: SavedOffice? = null) : OfficeStore {
    private val stored = MutableStateFlow(initial)

    /** What is currently saved. */
    val savedOffice: SavedOffice? get() = stored.value

    var readFailure: IOException? = null
    var saveFailure: IOException? = null

    override val office: Flow<SavedOffice?> = flow {
        readFailure?.let { throw it }
        emitAll(stored)
    }

    override suspend fun save(office: SavedOffice) {
        saveFailure?.let { throw it }
        stored.value = office
    }
}
