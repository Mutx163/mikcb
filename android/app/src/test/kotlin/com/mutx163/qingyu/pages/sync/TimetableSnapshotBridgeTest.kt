package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.AppGlobalSettingsStore
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import com.mutx163.qingyu.sync.SNAPSHOT_APP_ID
import com.mutx163.qingyu.sync.SNAPSHOT_BACKUP_TYPE
import com.mutx163.qingyu.sync.SNAPSHOT_SCHEMA_VERSION
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decodeSnapshotObject
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C1：备份快照必须带走 / 带回档案**完整内嵌 settings**。
 *
 * 背景：`TimetableProfile.toJson()` 只带 core 4 键，外观（`appThemeMode`）/语言
 * （`appLocaleTag`）等整份 250+ 键设置只存在于磁盘档案的 `settings` 对象里。
 * 修复前快照只写 core 4 键，恢复又按 id 用本机旧内嵌铺底 ⇒ 换机恢复后外观/语言
 * 仍是本机那套，备份里那套丢了（P1）。
 *
 * 对齐 Dart `app_sync_snapshot_service.dart:338-400`（每档序列化完整 profile）。
 */
class TimetableSnapshotBridgeTest {

    private val t0: LocalDateTime = LocalDateTime.of(2026, 9, 1, 8, 0)

    // ---------- 断言 ①：备份内嵌优先落盘 ----------

    @Test
    fun `本机 dark zh_TW 恢复 light ja 备份后档案内嵌为备份那套`() {
        val local = fixture(
            profiles = listOf(profileJson("p1", "本机课表", fullSettings("dark", "zh_TW", 9.0))),
            global = linkedMapOf("appThemeMode" to "dark", "appLocaleTag" to "zh_TW"),
        )
        val backup = fixture(
            profiles = listOf(profileJson("p1", "备份课表", fullSettings("light", "ja", 12.0))),
        )
        val bytes = buildBytes(backup.repository)

        assertTrue(TimetableSnapshotBridge.applySnapshot(local.repository, bytes) is SnapshotApplyResult.Applied)

        val restored = rawSettings(local, "p1")
        assertEquals("备份的外观主题优先落盘", "light", restored["appThemeMode"])
        assertEquals("备份的语言优先落盘", "ja", restored["appLocaleTag"])
        assertEquals("备份的其它完整键也要落盘", 12.0, restored["courseCardFontSize"])
    }

    // ---------- 断言 ②：快照 JSON 逐键完整 ----------

    @Test
    fun `快照里每档内嵌 settings 逐键完整 不止 core 4 键`() {
        val settings = fullSettings("light", "ja", 12.0)
        val backup = fixture(profiles = listOf(profileJson("p1", "备份课表", settings)))

        val bytes = buildBytes(backup.repository)
        val json = decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        val profile = (json["profiles"] as List<*>).first() as Map<*, *>
        val embedded = profile["settings"] as Map<*, *>

        for ((key, value) in settings) {
            val actual = embedded[key]
            // JSON 解出来的整数是 Long、字面量是 Int：按数值比较，不按装箱类型。
            if (value is Number && actual is Number) {
                assertEquals("快照内嵌 settings 缺键或不一致：$key", value.toDouble(), actual.toDouble(), 0.0)
            } else {
                assertEquals("快照内嵌 settings 缺键或不一致：$key", value, actual)
            }
        }
        assertTrue("不能只有 core 4 键（实际 ${embedded.size} 键）", embedded.size > 4)
    }

    // ---------- 断言 ③：全局偏好不被备份覆盖 ----------

    @Test
    fun `恢复后全局偏好 appGlobalSettingsV1 不被备份覆盖`() {
        val global = linkedMapOf<String, Any?>("appThemeMode" to "dark", "appLocaleTag" to "zh_TW")
        val local = fixture(
            profiles = listOf(profileJson("p1", "本机课表", fullSettings("dark", "zh_TW", 9.0))),
            global = global,
        )
        val globalBefore = local.raw.getString(AppGlobalSettingsStore.KEY)
        val backup = fixture(
            profiles = listOf(profileJson("p1", "备份课表", fullSettings("light", "ja", 12.0))),
        )

        assertTrue(TimetableSnapshotBridge.applySnapshot(local.repository, buildBytes(backup.repository)) is SnapshotApplyResult.Applied)

        assertEquals(
            "全局偏好是整机级真源，云恢复不许动它",
            globalBefore,
            local.raw.getString(AppGlobalSettingsStore.KEY),
        )
    }

    // ---------- 兼容：老备份内嵌只有 core 4 键 ----------

    @Test
    fun `老备份只有 4 键内嵌时恢复按现有逻辑补齐且不报错`() {
        val local = fixture(
            profiles = listOf(profileJson("p1", "本机课表", fullSettings("dark", "zh_TW", 9.0))),
        )
        // 老版本快照：settings 只有 core 4 键（没有外观/语言/字号）。
        val oldSettings = linkedMapOf<String, Any?>(
            "sections" to emptyList<Any?>(),
            "semesterWeekCount" to 18,
            "activeTimeSchemeId" to "ts-1",
            "semesterStartDateText" to "2026-09-01",
        )
        val bytes = snapshotBytes(listOf(profileJson("p1", "老备份课表", oldSettings)))

        assertTrue(TimetableSnapshotBridge.applySnapshot(local.repository, bytes) is SnapshotApplyResult.Applied)

        val restored = rawSettings(local, "p1")
        assertEquals("备份带来的 core 键要生效", 18, (restored["semesterWeekCount"] as Number).toInt())
        assertEquals("老备份没有的键按本机旧内嵌保留", "dark", restored["appThemeMode"])
        assertEquals("老备份没有的键按本机旧内嵌保留", "zh_TW", restored["appLocaleTag"])
        assertEquals("老备份没有的键按本机旧内嵌保留", 9.0, restored["courseCardFontSize"])
    }

    // ============ S1：孤儿对方档自愈（Compose 侧适配）============

    @Test
    fun `恢复时剔掉本机没有绑定的对方课表档`() {
        // 上传侧还不带绑定键 ⇒ 换机/恢复之后本机就不会有绑定；这份档案在本机没有主子。
        val local = fixture(profiles = listOf(profileJson("p1", "我的课表", fullSettings("light", "zh", 12.0))))
        val backup = fixture(
            profiles = listOf(
                profileJson("p1", "我的课表", fullSettings("light", "zh", 12.0)),
                partnerProfileJson("partner-imported", "TA的课表"),
            ),
        )

        assertTrue(TimetableSnapshotBridge.applySnapshot(local.repository, buildBytes(backup.repository)) is SnapshotApplyResult.Applied)

        assertEquals(
            "孤儿对方档不该写进本机（写进去就删不掉、切不走了）",
            listOf("p1"),
            local.repository.snapshot.profiles.map { it.id },
        )
        assertEquals("p1", local.repository.snapshot.activeProfileId)
    }

    @Test
    fun `本机有绑定时恢复保留对方课表档`() {
        val local = fixture(
            profiles = listOf(profileJson("p1", "我的课表", fullSettings("light", "zh", 12.0))),
            partnerBinding = """{"partnerName":"小屿"}""",
        )
        val backup = fixture(
            profiles = listOf(
                profileJson("p1", "我的课表", fullSettings("light", "zh", 12.0)),
                partnerProfileJson("partner-imported", "TA的课表"),
            ),
        )

        assertTrue(TimetableSnapshotBridge.applySnapshot(local.repository, buildBytes(backup.repository)) is SnapshotApplyResult.Applied)

        assertTrue(
            "还绑定着 ⇒ 对方课表是有效数据，必须留下",
            local.repository.snapshot.profiles.any { it.id == "partner-imported" },
        )
    }

    @Test
    fun `备份里只有一份孤儿对方档时拒绝恢复而不是把本机写成空`() {
        val local = fixture(profiles = listOf(profileJson("p1", "我的课表", fullSettings("light", "zh", 12.0))))
        val backup = fixture(profiles = listOf(partnerProfileJson("partner-imported", "TA的课表")))

        val result = TimetableSnapshotBridge.applySnapshot(local.repository, buildBytes(backup.repository))

        assertEquals("sync_snapshot_no_profiles", (result as SnapshotApplyResult.Invalid).errorCode)
        assertEquals("本机档案必须原样不动", listOf("p1"), local.repository.snapshot.profiles.map { it.id })
    }

    @Test
    fun `孤儿对方档不算本机用户数据 有绑定时才算`() {
        // 只有一份默认名、没课的档案 + 一份孤儿对方档 ⇒ 空壳本机（不弹「选边」）。
        val orphan = fixture(
            profiles = listOf(
                profileJson("p1", TimetableRepository.DEFAULT_PROFILE_NAME, fullSettings("light", "zh", 12.0)),
                partnerProfileJson("partner-imported", "TA的课表"),
            ),
        )
        assertTrue(
            "孤儿对方档不该被当成用户亲手沉淀的数据（否则每次同步都弹选边）",
            !TimetableSnapshotBridge.localHasUserAuthoredData(orphan.repository),
        )

        val bound = fixture(
            profiles = listOf(
                profileJson("p1", TimetableRepository.DEFAULT_PROFILE_NAME, fullSettings("light", "zh", 12.0)),
                partnerProfileJson("partner-imported", "TA的课表"),
            ),
            partnerBinding = """{"partnerName":"小屿"}""",
        )
        assertTrue(
            "绑定还在 ⇒ 对方课表是有效数据，仍算本机有数据",
            TimetableSnapshotBridge.localHasUserAuthoredData(bound.repository),
        )
    }

    // ============ 夹具 ============

    private class Fixture(
        val raw: InMemoryKeyValueStore,
        val repository: TimetableRepository,
    )

    private fun fixture(
        profiles: List<Map<String, Any?>>,
        global: Map<String, Any?>? = null,
        /** 非 null = 本机还持有对方课表绑定（`partner_timetable_binding` 的值）。 */
        partnerBinding: String? = null,
    ): Fixture {
        val initial = LinkedHashMap<String, String>()
        initial[TimetableStore.KEY_PROFILES] = MiniJson.encode(profiles)
        initial[TimetableStore.KEY_ACTIVE_PROFILE_ID] = "p1"
        if (global != null) initial[AppGlobalSettingsStore.KEY] = MiniJson.encode(global)
        if (partnerBinding != null) initial[CouplePartnerStorage.BINDING_KEY] = partnerBinding
        val raw = InMemoryKeyValueStore(initial)
        return Fixture(raw, TimetableRepository(TimetableStore(raw)))
    }

    /** 对方课表档案（`profileKind = partnerImported`，与情侣页导入出来的那份同形）。 */
    private fun partnerProfileJson(id: String, name: String): Map<String, Any?> {
        val base = LinkedHashMap(
            TimetableProfile(
                id = id,
                name = name,
                currentWeek = 1L,
                createdAt = t0,
                lastUsedAt = t0,
                profileKind = TimetableProfileKind.PARTNER_IMPORTED,
            ).toJson(),
        )
        base["settings"] = fullSettings("light", "zh", 12.0)
        return base
    }

    /** 磁盘档案 JSON：完整内嵌 settings（`saveProfiles` 造不出来，只能直接播种）。 */
    private fun profileJson(id: String, name: String, settings: Map<String, Any?>): Map<String, Any?> {
        val base = LinkedHashMap(
            TimetableProfile(
                id = id,
                name = name,
                currentWeek = 3L,
                createdAt = t0,
                lastUsedAt = t0,
            ).toJson(),
        )
        base["settings"] = settings
        return base
    }

    private fun fullSettings(themeMode: String, localeTag: String, fontSize: Double): LinkedHashMap<String, Any?> =
        linkedMapOf(
            "appThemeMode" to themeMode,
            "appLocaleTag" to localeTag,
            "courseCardFontSize" to fontSize,
            "foruiTheme" to "miui",
            "semesterWeekCount" to 18,
            "activeTimeSchemeId" to "ts-1",
        )

    private fun rawSettings(fixture: Fixture, profileId: String): Map<*, *> {
        val list = MiniJson.parse(fixture.raw.getString(TimetableStore.KEY_PROFILES)!!) as List<*>
        val entry = list.mapNotNull { it as? Map<*, *> }.first { it["id"] == profileId }
        return entry["settings"] as Map<*, *>
    }

    private fun buildBytes(repository: TimetableRepository): ByteArray {
        val result = TimetableSnapshotBridge.buildSnapshotBytes(repository, "device-b", "2026-11-04T10:00:00.000Z")
        return (result as SnapshotBuildResult.Success).bytes
    }

    /** 手搓一份老版本快照（含信封与校验和），用于兼容性用例。 */
    private fun snapshotBytes(profiles: List<Map<String, Any?>>): ByteArray {
        val payload = linkedMapOf<String, Any?>(
            "app" to SNAPSHOT_APP_ID,
            "schemaVersion" to SNAPSHOT_SCHEMA_VERSION,
            "backupType" to SNAPSHOT_BACKUP_TYPE,
            "exportedAt" to "2026-11-04T10:00:00.000Z",
            "deviceId" to "device-b",
            "activeProfileId" to "p1",
            "profiles" to profiles,
            "timeSchemes" to emptyList<Any?>(),
            "locationTimeGroups" to emptyList<Any?>(),
            "scheduleDateRules" to emptyList<Any?>(),
        )
        payload["contentSha256"] = computeContentSha256(payload)
        return MiniJson.encode(payload).toByteArray(Charsets.UTF_8)
    }
}
