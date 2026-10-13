package com.shafayatb.snapendance.attendance

import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AttendanceActivityTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<AttendanceActivity>()

    @Test
    fun tappingNavigateBackFinishesActivity() {
        // Held before the tap: the rule cannot look up an Activity once it is destroyed.
        val activity = composeRule.activity

        composeRule.onNodeWithContentDescription("Navigate back").performClick()

        assertTrue("AttendanceActivity should finish", activity.isFinishing)
    }
}
