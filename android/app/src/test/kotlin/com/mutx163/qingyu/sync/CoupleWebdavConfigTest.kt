package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 情侣 WebDAV 配置纯逻辑单测。
 *
 * 抄录 test/services/couple_webdav_config_test.dart 全量；
 * 人推：mySlot 非 1/2 一律归 1（Dart `normalizedMySlot`）。
 */
class CoupleWebdavConfigTest {

    @Test
    fun `normalizes folder and builds dual slot paths`() {
        val config = CoupleWebdavConfig(remoteFolder = "Apps/qingyu-couple")
        assertEquals("/Apps/qingyu-couple/", config.normalizedRemoteFolder)
        assertEquals(
            "/Apps/qingyu-couple/couple-slot-1.mikcb",
            config.mineTimetableRemotePath,
        )
        assertEquals(
            "/Apps/qingyu-couple/couple-slot-2.mikcb",
            config.partnerTimetableRemotePath,
        )
        assertEquals(
            "/Apps/qingyu-couple/partner-timetable.mikcb",
            config.legacyPartnerTimetableRemotePath,
        )
    }

    @Test
    fun `slot 2 swaps upload and pull paths`() {
        val config = CoupleWebdavConfig(mySlot = 2)
        assertEquals("couple-slot-2.mikcb", config.mineTimetableRemotePath.substringAfterLast("/"))
        assertEquals("couple-slot-1.mikcb", config.partnerTimetableRemotePath.substringAfterLast("/"))
    }

    @Test
    fun `invalid slot normalizes to 1`() {
        // 人推：Dart normalizedMySlot 仅 2 保留，其余归 1。
        assertEquals(1, CoupleWebdavConfig(mySlot = 99).normalizedMySlot)
        assertEquals(1, CoupleWebdavConfig(mySlot = 0).normalizedMySlot)
        assertEquals(1, CoupleWebdavConfig(mySlot = -1).normalizedMySlot)
        assertEquals(2, CoupleWebdavConfig(mySlot = 2).normalizedMySlot)
    }

    @Test
    fun `round trips json`() {
        val config = CoupleWebdavConfig(
            username = "user@example.com",
            mySlot = 2,
            lastPulledAtIso = "2026-07-08T04:30:00Z",
            lastRemoteContentHash = "abc123",
        )
        val restored = CoupleWebdavConfig.fromJson(config.toJson())
        assertEquals(config.username, restored.username)
        assertEquals(2, restored.mySlot)
        assertEquals(config.lastPulledAtIso, restored.lastPulledAtIso)
        assertEquals("abc123", restored.lastRemoteContentHash)
        assertEquals(config.partnerTimetableRemotePath, restored.partnerTimetableRemotePath)
    }

    @Test
    fun `fromJson clamps unknown slot to 1`() {
        val restored = CoupleWebdavConfig.fromJson(mapOf("mySlot" to 7))
        assertEquals(1, restored.mySlot)
    }

    @Test
    fun `validated base url falls back on blank`() {
        assertEquals(
            CoupleWebdavConfig.DEFAULT_JIANGUOYUN_BASE_URL,
            validatedCoupleWebdavBaseUrl(""),
        )
        assertEquals(
            CoupleWebdavConfig.DEFAULT_JIANGUOYUN_BASE_URL,
            validatedCoupleWebdavBaseUrl("   "),
        )
    }

    @Test
    fun `validated base url passes https through trimmed`() {
        assertEquals(
            "https://dav.example.com/dav/",
            validatedCoupleWebdavBaseUrl(" https://dav.example.com/dav/ "),
        )
    }

    @Test
    fun `validated base url rejects http without confirm entry`() {
        assertNull(validatedCoupleWebdavBaseUrl("http://192.168.1.10:5005/"))
    }

    @Test
    fun `validated base url rejects non http schemes`() {
        assertNull(validatedCoupleWebdavBaseUrl("ftp://dav.example.com/"))
        assertNull(validatedCoupleWebdavBaseUrl("file:///sdcard/dav"))
        assertNull(validatedCoupleWebdavBaseUrl("dav.example.com/dav/"))
    }
}
