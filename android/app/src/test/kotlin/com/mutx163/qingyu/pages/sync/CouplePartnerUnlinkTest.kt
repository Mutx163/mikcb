package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.platform.CouplePartnerPortImpl
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 解绑的 active 键落盘口径（对齐 Dart `timetable_partner_service.dart:161-184`）。
 *
 * 旧实现只删情侣档、不重写 `active_timetable_profile_id`，落盘留悬空 id；
 * 读侧回落把坏状态掩盖了。这里锁死两种情况下的落盘值。
 */
class CouplePartnerUnlinkTest {

    private val raw = InMemoryKeyValueStore()
    private val store = TimetableStore(raw)
    private val repository = TimetableRepository(store)
    private val port = CouplePartnerPortImpl(repository, raw)

    private val mainProfile = TimetableProfile(
        id = "main",
        name = "我的课表",
        currentWeek = 3L,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = LocalDateTime.of(2026, 9, 2, 8, 0),
    )

    @Test
    fun `情侣档是 active 时解绑切回第一份普通档并落盘`() {
        repository.replaceAllProfiles(listOf(mainProfile), mainProfile.id)
        port.importPackage(partnerPackage())
        repository.replaceAllProfiles(repository.snapshot.profiles, PARTNER_ID)

        port.unlink()

        assertEquals(mainProfile.id, repository.snapshot.activeProfileId)
        assertEquals(mainProfile.id, store.loadActiveProfileId())
        assertTrue(repository.snapshot.profiles.none { it.id == PARTNER_ID })
        assertNull(port.loadBinding())
    }

    @Test
    fun `普通档是 active 时解绑不动 active 键`() {
        repository.replaceAllProfiles(listOf(mainProfile), mainProfile.id)
        port.importPackage(partnerPackage())

        port.unlink()

        assertEquals(mainProfile.id, repository.snapshot.activeProfileId)
        assertEquals(mainProfile.id, store.loadActiveProfileId())
        assertTrue(repository.snapshot.profiles.none { it.id == PARTNER_ID })
    }

    private fun partnerPackage(): String = CouplePartnerPackageCodec.buildMine(
        profileName = "TA的课表",
        courses = emptyList(),
        tasks = emptyList(),
        scheduleItems = emptyList(),
        settings = TimetableSettings.defaults(),
        currentWeek = 1,
        exportedAtIso = "2026-11-04T09:00:00.000",
        packageId = "couple-unlink-probe",
    )

    private companion object {
        const val PARTNER_ID = CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID
    }
}
