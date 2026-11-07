package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.platform.CouplePartnerPortImpl
import java.io.IOException
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 解绑的两条口径：
 *
 * 1. **active 键落盘**（对齐 Dart `timetable_partner_service.dart:161-184`）：旧实现只删情侣档、
 *    不重写 `active_timetable_profile_id`，落盘留悬空 id；读侧回落把坏状态掩盖了。
 * 2. **落盘顺序**（S2，2026-11-05 修复，对齐 Dart `partner_timetable_service.dart:132-139`）：
 *    **先删对方档案、成功后清绑定**。旧实现反过来，删档一失败就留下「无绑定 + 有档案」的
 *    孤儿档——那份档案在课表管理页删不掉也切不走。
 *
 * 失败分支用 [FlakyStore] 注入（对指定 key 的写入/删除抛 `IOException`），断言的是
 * **失败之后盘上还剩什么**，不是「抛没抛」。
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

        assertEquals(CoupleUnlinkStage.DONE, port.unlink())

        assertEquals(mainProfile.id, repository.snapshot.activeProfileId)
        assertEquals(mainProfile.id, store.loadActiveProfileId())
        assertTrue(repository.snapshot.profiles.none { it.id == PARTNER_ID })
        assertNull(port.loadBinding())
    }

    @Test
    fun `普通档是 active 时解绑不动 active 键`() {
        repository.replaceAllProfiles(listOf(mainProfile), mainProfile.id)
        port.importPackage(partnerPackage())

        assertEquals(CoupleUnlinkStage.DONE, port.unlink())

        assertEquals(mainProfile.id, repository.snapshot.activeProfileId)
        assertEquals(mainProfile.id, store.loadActiveProfileId())
        assertTrue(repository.snapshot.profiles.none { it.id == PARTNER_ID })
    }

    // ── 失败分支（S2）──────────────────────────────────────────────

    @Test
    fun `删档落盘失败时不碰绑定 且档案还在`() {
        val f = flakyFixture()
        f.port.importPackage(partnerPackage())
        f.flaky.failPutKeys = setOf(TimetableStore.KEY_PROFILES)

        assertEquals(CoupleUnlinkStage.PROFILE_DELETE_FAILED, f.port.unlink())

        assertTrue("档案没删掉 ⇒ 必须还在", f.repository.snapshot.profiles.any { it.id == PARTNER_ID })
        assertTrue("绑定一个字节都不许动", f.port.loadBinding() != null)
        assertTrue("绑定键也得还在盘上", f.flaky.contains(CouplePartnerStorage.BINDING_KEY))
    }

    @Test
    fun `清绑定失败时档案已删 再解绑一次即可收尾`() {
        val f = flakyFixture()
        f.port.importPackage(partnerPackage())
        f.flaky.failRemoveKeys = setOf(CouplePartnerStorage.BINDING_KEY)

        assertEquals(CoupleUnlinkStage.BINDING_CLEAR_FAILED, f.port.unlink())

        assertTrue("档案已删", f.repository.snapshot.profiles.none { it.id == PARTNER_ID })
        assertTrue("绑定没清掉：还给用户留一次重试机会", f.port.loadBinding() != null)

        // 重试：档案已经不在了，只剩「清绑定」这一步。
        f.flaky.failRemoveKeys = emptySet()
        assertEquals(CoupleUnlinkStage.DONE, f.port.unlink())
        assertNull(f.port.loadBinding())
        assertFalse(f.flaky.contains(CouplePartnerStorage.BINDING_KEY))
    }

    // ── 夹具 ──

    private class Fixture(
        val flaky: FlakyStore,
        val repository: TimetableRepository,
        val port: CouplePartnerPortImpl,
    )

    private fun flakyFixture(): Fixture {
        val flaky = FlakyStore(InMemoryKeyValueStore())
        val store = TimetableStore(flaky)
        val repository = TimetableRepository(store)
        val port = CouplePartnerPortImpl(repository, flaky)
        repository.replaceAllProfiles(
            listOf(
                mainProfile,
                TimetableProfile(
                    id = PARTNER_ID,
                    name = "TA的课表",
                    currentWeek = 1L,
                    createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
                    lastUsedAt = LocalDateTime.of(2026, 9, 2, 8, 0),
                    profileKind = TimetableProfileKind.PARTNER_IMPORTED,
                ),
            ),
            mainProfile.id,
        )
        return Fixture(flaky, repository, port)
    }

    /**
     * 可注入失败的存储：按 key 抛 `IOException`（真机上是磁盘满 / `commit()` 返回 false）。
     *
     * 其余一概委托给 [InMemoryKeyValueStore]，前缀与编码规则与真实现同一套。
     */
    private class FlakyStore(
        private val delegate: InMemoryKeyValueStore,
    ) : KeyValueStore by delegate {
        var failPutKeys: Set<String> = emptySet()
        var failRemoveKeys: Set<String> = emptySet()

        override fun putString(key: String, value: String) {
            if (key in failPutKeys) throw IOException("disk_full:$key")
            delegate.putString(key, value)
        }

        override fun remove(key: String) {
            if (key in failRemoveKeys) throw IOException("disk_full:$key")
            delegate.remove(key)
        }
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
