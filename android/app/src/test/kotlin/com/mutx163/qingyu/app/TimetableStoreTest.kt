package com.mutx163.qingyu.app

import com.mutx163.qingyu.FlutterPrefsCodec
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [TimetableStore] 的读写与损坏自愈测试。
 *
 * 期望值来自数据契约 §1.3/§2.1 与 Dart `storage_service.dart` 的同口径行为：
 * - `timetable_profiles` 是 **JSON 数组**，写路径盖 `timetable_profiles_schema_version = 1`；
 * - 坏值留档 `{key}_corrupt_backup_{micros}` 再删原 key，同 key 旧留档只留最近一份；
 * - 条目级损坏（整条档案还能用）**不删 key**（删了等于把「解析器读不懂」变成永久删除）。
 */
class TimetableStoreTest {

    private val fixedMicros = 1_700_000_000_000_000L

    private fun newStore(initial: Map<String, String> = emptyMap()): Pair<InMemoryKeyValueStore, TimetableStore> {
        val raw = InMemoryKeyValueStore(initial)
        return raw to TimetableStore(raw, nowMicros = { fixedMicros })
    }

    // ---------- profiles ----------

    @Test
    fun loadProfilesOnMissingKeyIsEmptyAndLeavesNoBackup() {
        val (raw, store) = newStore()

        val result = store.loadProfiles()

        assertEquals(emptyList<TimetableProfile>(), result.profiles)
        assertFalse(result.didDrop)
        assertNull(result.corruptBackupKey)
        assertTrue(raw.keys().isEmpty())
    }

    @Test
    fun saveProfilesWritesJsonArrayAndStampsSchemaVersion() {
        val (raw, store) = newStore()

        store.saveProfiles(listOf(profile("p1", listOf(course("c1")))))

        val written = raw.getString("timetable_profiles")!!
        assertTrue("v1 布局是数组", written.trimStart().startsWith("["))
        assertEquals(1, store.profilesSchemaVersion())
        assertEquals("1", raw.rawSnapshot()["flutter.timetable_profiles_schema_version"])
    }

    @Test
    fun profilesRoundTripKeepsCoursesSettingsAndKind() {
        val (_, store) = newStore()
        val original = profile("p1", listOf(course("c1"), course("c2", name = "物理"))).copy(
            settings = TimetableSettings(semesterWeekCount = 18, activeTimeSchemeId = "ts-1"),
            currentWeek = 5L,
            profileKind = TimetableProfileKind.PARTNER_IMPORTED,
        )

        store.saveProfiles(listOf(original))
        val loaded = store.loadProfiles().profiles

        assertEquals(1, loaded.size)
        assertEquals("p1", loaded[0].id)
        assertEquals(listOf("c1", "c2"), loaded[0].courses.map { it.id })
        assertEquals(18, loaded[0].settings.semesterWeekCount)
        assertEquals("ts-1", loaded[0].settings.activeTimeSchemeId)
        assertEquals(5L, loaded[0].currentWeek)
        assertEquals(TimetableProfileKind.PARTNER_IMPORTED, loaded[0].profileKind)
    }

    @Test
    fun corruptProfilesJsonIsArchivedThenKeyRemoved() {
        val (raw, store) = newStore(mapOf("timetable_profiles" to "{not json"))

        val result = store.loadProfiles()

        assertEquals(emptyList<TimetableProfile>(), result.profiles)
        assertTrue(result.didDrop)
        assertEquals("timetable_profiles_corrupt_backup_$fixedMicros", result.corruptBackupKey)
        // 原值被完整留档，原 key 消失。
        assertEquals("{not json", raw.rawSnapshot()["flutter.timetable_profiles_corrupt_backup_$fixedMicros"])
        assertFalse(raw.contains("timetable_profiles"))
    }

    @Test
    fun jsonObjectInsteadOfArrayIsAlsoCorrupt() {
        val (raw, store) = newStore(mapOf("timetable_profiles" to """{"id":"p1"}"""))

        val result = store.loadProfiles()

        assertTrue(result.didDrop)
        assertNotNull(result.corruptBackupKey)
        assertFalse(raw.contains("timetable_profiles"))
    }

    @Test
    fun arrayOfUnrecoverableEntriesIsTopLevelLossAndArchived() {
        val (raw, store) = newStore(mapOf("timetable_profiles" to "[1,2,3]"))

        val result = store.loadProfiles()

        assertEquals(emptyList<TimetableProfile>(), result.profiles)
        assertTrue(result.didDrop)
        assertFalse(result.itemLevelOnlyDrop)
        assertNotNull(result.corruptBackupKey)
        assertFalse(raw.contains("timetable_profiles"))
    }

    @Test
    fun itemLevelDropKeepsKeyOnDiskAndReturnsUsableProfile() {
        // 「条目级损坏」= 整条档案解析得出来，但它内部的某条课程读坏了。
        // 此时整条档案仍可用 → **不许**写回/删 key，否则「当前解析器读不懂」
        // 就变成永久删除（Dart storage_service.dart:1102-1115）。
        val payload = """
            [{"id":"p1","name":"课表-p1","currentWeek":3,"courses":[
              {"id":"c1","name":"数学","teacher":"张老师","location":"A101",
               "dayOfWeek":1,"startSection":1,"endSection":2,
               "startTime":"08:00","endTime":"09:40"},
              "garbage-course-entry"
            ]}]
        """.trimIndent()
        val (raw, store) = newStore(mapOf("timetable_profiles" to payload))

        val result = store.loadProfiles()

        assertEquals(listOf("p1"), result.profiles.map { it.id })
        assertEquals(listOf("c1"), result.profiles.single().courses.map { it.id })
        assertTrue(result.didDrop)
        assertTrue(result.itemLevelOnlyDrop)
        assertNull(result.corruptBackupKey)
        assertTrue("条目级损坏不许删 key", raw.contains("timetable_profiles"))
        assertEquals(payload, raw.getString("timetable_profiles"))
    }

    @Test
    fun itemLevelDropArchivesRawEntriesUnderRollingKey() {
        // Dart `_archiveUnparsedProfileItems`（storage_service.dart:1136-1150）：
        // 条目级损坏在盘上不写回，所以原始字节必须另存一份，否则进程一退就永久消失。
        val payload = """
            [{"id":"p1","name":"课表-p1","currentWeek":3,"courses":[
              {"id":"c1","name":"数学","teacher":"张老师","location":"A101",
               "dayOfWeek":1,"startSection":1,"endSection":2,
               "startTime":"08:00","endTime":"09:40"},
              "garbage-course-entry"
            ]}]
        """.trimIndent()
        val (raw, store) = newStore(mapOf("timetable_profiles" to payload))

        store.loadProfiles()

        val archive = MiniJson.parse(
            raw.getString("timetable_profiles_unparsed_items")!!,
        ) as Map<*, *>
        val items = archive["items"] as List<*>
        assertEquals(1, (archive["count"] as Number).toInt())
        assertEquals("留档的是原始条目编码串，不是解析后的半成品", "\"garbage-course-entry\"", items.single())
        // 时间戳按 Dart 口径是本机 ISO 串（不是 epoch 数字）；微秒非零时 Dart 输出 6 位。
        assertTrue(
            "archivedAt 应为 ISO 串，实际 ${archive["archivedAt"]}",
            Regex("""^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(\d{3})?$""")
                .matches(archive["archivedAt"] as String),
        )
        // 归档归归档，原 key 仍然一个字节不变。
        assertEquals(payload, raw.getString("timetable_profiles"))
    }

    @Test
    fun itemLevelDropQuarantineIsCappedAt50AndTruncatedAt4096() {
        val garbage = (1..59).joinToString(",") { "\"bad-$it\"" }
        val huge = "\"" + "x".repeat(5000) + "\""
        // 超长条放最前面：留档上限按到达顺序截断，放后面根本进不了留档。
        val payload = """[{"id":"p1","name":"课表","courses":[$huge,$garbage]}]"""
        val (raw, store) = newStore(mapOf("timetable_profiles" to payload))

        store.loadProfiles()

        val items = (MiniJson.parse(raw.getString("timetable_profiles_unparsed_items")!!) as Map<*, *>)
            .let { it["items"] as List<*> }
        assertEquals("留档上限 50 条", 50, items.size)
        // 单条超长值被截到 4096 字符再打截断标记，避免畸形数据撑爆存储。
        val truncated = items[0] as String
        assertTrue("首条超长值应带截断标记", truncated.endsWith("…(截断)"))
        assertEquals(4096, truncated.length - "…(截断)".length)
    }

    @Test
    fun cleanLoadWritesNoUnparsedArchive() {
        val (raw, store) = newStore(
            mapOf("timetable_profiles" to """[{"id":"p1","name":"课表","courses":[]}]"""),
        )

        store.loadProfiles()

        assertNull(raw.getString("timetable_profiles_unparsed_items"))
    }

    @Test
    fun repeatedCorruptionKeepsOnlyNewestBackup() {
        val raw = InMemoryKeyValueStore()
        var micros = 100L
        val store = TimetableStore(raw, nowMicros = { micros })

        raw.putString("timetable_profiles", "{first}")
        store.loadProfiles()
        micros = 200L
        raw.putString("timetable_profiles", "{second}")
        store.loadProfiles()

        assertTrue(raw.contains("timetable_profiles_corrupt_backup_200"))
        assertFalse("旧留档要清扫掉", raw.contains("timetable_profiles_corrupt_backup_100"))
    }

    // ---------- settings ----------

    @Test
    fun loadSettingsOnMissingKeyReturnsDefaults() {
        val (_, store) = newStore()

        val settings = store.loadSettings()

        assertEquals(TimetableSettings.DEFAULT_SECTIONS, settings.sections)
        assertEquals(20, settings.semesterWeekCount)
        assertNull(settings.activeTimeSchemeId)
        assertNull(settings.semesterStartDate)
    }

    @Test
    fun saveSettingsPreservesForeignKeysOwnedByOtherFamilies() {
        // 本层只拥有时间/周次 4 键；Dart 侧同一份 JSON 有 250+ 字段。
        // 整体覆盖写 = 用户丢设置，所以 saveSettings 必须合并。
        val (raw, store) = newStore(
            mapOf("timetable_settings" to """{"cornerRadius":22,"cardHeight":88,"sections":[]}"""),
        )

        store.saveSettings(TimetableSettings(semesterWeekCount = 18))

        val written = MiniJson.parse(raw.getString("timetable_settings")!!) as Map<*, *>
        assertEquals(22, (written["cornerRadius"] as Number).toInt())
        assertEquals(88, (written["cardHeight"] as Number).toInt())
        assertEquals(18, (written["semesterWeekCount"] as Number).toInt())
        assertEquals(18, store.loadSettings().semesterWeekCount)
    }

    @Test
    fun saveSettingsKeepsEveryUnknownKeyValueForValue() {
        // 真实存档里 Dart 侧有 250+ 个本层不认识的键。这条是「防止用户设置被静默清空」
        // 的闸：只要有人把 saveSettings 顺手简化成整体覆盖，它必须红。
        val archived = """
            {
              "themeSeedColor": "#FF5722",
              "timetableHideWeekends": true,
              "longPressEmptySlotToAddCourseEnabled": false,
              "cardCornerRadius": 22,
              "wallpaperBlurStrength": 0.65,
              "unicodeName": "课表·设置",
              "nullValue": null,
              "nested": {"a": [1, 2, {"b": "c"}], "empty": []}
            }
        """.trimIndent()
        val (raw, store) = newStore(mapOf("timetable_settings" to archived))
        val before = MiniJson.parse(archived) as Map<*, *>

        store.saveSettings(TimetableSettings(semesterWeekCount = 18, activeTimeSchemeId = "ts-7"))

        val after = MiniJson.parse(raw.getString("timetable_settings")!!) as Map<*, *>
        // 一个都没少。
        assertTrue("未知键丢了：${before.keys - after.keys}", after.keys.containsAll(before.keys))
        // 值逐字未变（含布尔、数字、null、嵌套对象与数组）。
        for ((key, value) in before) {
            assertEquals("键 $key 的值被改了", value, after[key])
        }
        // 本层拥有的键确实改了。
        assertEquals(18, (after["semesterWeekCount"] as Number).toInt())
        assertEquals("ts-7", after["activeTimeSchemeId"])
    }

    @Test
    fun saveSettingsWritesOwnedKeysAndSurvivesReload() {
        val (_, store) = newStore()
        val start = LocalDateTime.of(2026, 9, 7, 0, 0)

        store.saveSettings(
            TimetableSettings(
                sections = listOf(SectionTime("08:30", "09:15")),
                activeTimeSchemeId = "ts-9",
                semesterWeekCount = 16,
                semesterStartDate = start,
            ),
        )

        val loaded = store.loadSettings()
        assertEquals(listOf(SectionTime("08:30", "09:15")), loaded.sections)
        assertEquals("ts-9", loaded.activeTimeSchemeId)
        assertEquals(16, loaded.semesterWeekCount)
        assertEquals(start, loaded.semesterStartDate)
    }

    @Test
    fun corruptSettingsAreArchivedAndFallBackToDefaults() {
        val (raw, store) = newStore(mapOf("timetable_settings" to "[]"))

        val settings = store.loadSettings()

        assertEquals(20, settings.semesterWeekCount)
        assertEquals("[]", raw.rawSnapshot()["flutter.timetable_settings_corrupt_backup_$fixedMicros"])
        assertFalse(raw.contains("timetable_settings"))
    }

    // ---------- current_week ----------

    @Test
    fun currentWeekDistinguishesMissingFromZero() {
        val (_, store) = newStore()
        assertNull(store.loadCurrentWeek())

        store.saveCurrentWeek(0)
        assertEquals(0, store.loadCurrentWeek())
    }

    // ---------- time_schemes ----------

    @Test
    fun timeSchemesRoundTrip() {
        val (_, store) = newStore()
        val scheme = TimeScheme(
            id = "ts-1",
            name = "冬季作息",
            sections = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")),
            createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
            updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        )

        store.saveTimeSchemes(listOf(scheme))
        val loaded = store.loadTimeSchemes()

        assertNull(loaded.corruptBackupKey)
        assertEquals(listOf("ts-1"), loaded.schemes.map { it.id })
        assertEquals(2, loaded.schemes[0].sections.size)
    }

    @Test
    fun corruptTimeSchemesAreArchived() {
        val (raw, store) = newStore(mapOf("time_schemes" to "not-a-json-array"))

        val broken = store.loadTimeSchemes()

        assertEquals(emptyList<TimeScheme>(), broken.schemes)
        assertEquals("time_schemes_corrupt_backup_$fixedMicros", broken.corruptBackupKey)
        assertFalse(raw.contains("time_schemes"))
    }

    // ---------- teacher / location 记录（List<String>） ----------

    @Test
    fun teacherRecordsRoundTripAsStringList() {
        val (raw, store) = newStore()

        store.saveTeacherRecords(listOf("张老师", "李老师"))

        assertEquals(listOf("张老师", "李老师"), store.loadTeacherRecords())
        assertTrue(raw.getString("teacher_records")!!.startsWith(FlutterPrefsCodec.LIST_PREFIX))
    }

    @Test
    fun corruptTeacherRecordsAreArchivedNotSilentlyTreatedAsEmpty() {
        // 契约要求 getStringList 解码失败要抛；存储层在边界接住它并**留档**，
        // 而不是静默当空（否则下一次保存就把坏数据永久覆盖掉）。
        val (raw, store) = newStore(mapOf("teacher_records" to "definitely-not-a-list"))

        assertEquals(emptyList<String>(), store.loadTeacherRecords())

        assertEquals(
            "definitely-not-a-list",
            raw.rawSnapshot()["flutter.teacher_records_corrupt_backup_$fixedMicros"],
        )
        assertFalse(raw.contains("teacher_records"))
    }

    @Test
    fun archiveWriteFailureKeepsLoadSideAliveInsteadOfCrashingInit() {
        // 「坏数据 + 磁盘满」双故障：留档这笔写不进去（IOException）。读侧不许把它
        // 升级成崩溃（仓储在 init 里 reload，一炸就是启动崩），降级为按默认值读，
        // 坏值留在盘上等下次再补留档（2026-11-02：写失败开始抛 IOException 后的护栏）。
        val raw = InMemoryKeyValueStore(mapOf("timetable_profiles" to "{not json"))
        val store = TimetableStore(
            ArchiveFailingStore(raw, failArchiveOf = "timetable_profiles"),
            nowMicros = { fixedMicros },
        )

        val result = store.loadProfiles()

        assertEquals(emptyList<TimetableProfile>(), result.profiles)
        assertTrue(result.didDrop)
        // 坏值还在盘上（这次没删成），留档名照常返回（但不代表盘上有留档）。
        assertEquals("{not json", raw.getString("timetable_profiles"))
        assertEquals("timetable_profiles_corrupt_backup_$fixedMicros", result.corruptBackupKey)
    }

    /** 只有 `archiveCorruptAndRemove` 对指定 key 抛 IOException 的替身（磁盘满）。 */
    private class ArchiveFailingStore(
        private val delegate: InMemoryKeyValueStore,
        private val failArchiveOf: String,
    ) : KeyValueStore by delegate {
        override fun archiveCorruptAndRemove(key: String, micros: Long): String {
            if (key == failArchiveOf) throw java.io.IOException("disk_full")
            return delegate.archiveCorruptAndRemove(key, micros)
        }
    }

    // ---------- 旧 courses 通道 bootstrap（四种老盘态） ----------

    /** 老盘态 1：`timetable_profiles` 缺失 + 旧 `courses` 有 3 门课。 */
    @Test
    fun bootstrapMissingProfilesBuildsDefaultProfileWithAllLegacyCourses() {
        val legacyCourses = listOf(course("c1"), course("c2", "物理"), course("c3", "化学"))
        val (raw, store) = newStore(
            mapOf(
                "courses" to FlutterPrefsCodec.encodeStringList(
                    legacyCourses.map { MiniJson.encode(it.toJson()) },
                ),
                "semester_start" to "1700000000000",
                "current_week" to "5",
                "timetable_settings" to
                    """{"semesterWeekCount":18,"timetableShowCurrentWeekCourses":true,"appLocaleTag":"en"}""",
            ),
        )

        // 迁移前：没有档案；设置只能读到顶层旧镜像。
        assertEquals(emptyList<TimetableProfile>(), store.loadProfiles().profiles)
        assertNull(raw.getString("timetable_profiles"))
        assertEquals("en", store.loadSettingsJson()["appLocaleTag"])
        assertNull(raw.getString("compose_bootstrap_migrated_v1"))

        // 迁移
        val result = store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertTrue(result.bootstrapped)
        assertEquals(3, result.importedCourses)
        assertEquals(0, result.quarantinedCourses)

        // 迁移后：3 门课都在、id 不重复、档案内嵌设置/周次正确。
        val loaded = store.loadProfiles().profiles
        assertEquals(1, loaded.size)
        assertEquals("默认课表", loaded[0].name)
        assertEquals(listOf("c1", "c2", "c3"), loaded[0].courses.map { it.id })
        assertEquals(3, loaded[0].courses.map { it.id }.toSet().size)
        assertEquals(5L, loaded[0].currentWeek)
        assertEquals(18, loaded[0].settings.semesterWeekCount)
        // Dart 读回时优先 date-only 文本（`parseSemesterStartDate`），时分归零；
        // 这里模型落成当日 00:00，与 Dart 往返后的值一致。
        assertEquals(
            DartTime.fromEpochMillis(1_700_000_000_000L).toLocalDate(),
            loaded[0].settings.semesterStartDate?.toLocalDate(),
        )
        assertEquals("en", store.loadSettingsJson()["appLocaleTag"])
        assertEquals(18, store.loadSettings().semesterWeekCount)
        // 幂等标记与 active id 落盘。
        assertTrue(raw.getBool("compose_bootstrap_migrated_v1", false))
        assertEquals(loaded[0].id, store.loadActiveProfileId())
        // 旧 key 不被清掉（Dart 只在 bootstrap 时读，不写回）。
        assertTrue(raw.contains("courses"))
    }

    /** 老盘态 2：档案存在但顶层 `timetable_settings` 与档案内嵌不同 —— 以档案内嵌为准。 */
    @Test
    fun settingsReadPrefersActiveProfileEmbeddedOverLegacyTopLevel() {
        val embedded = profile("p1", listOf(course("c1"))).copy(
            settings = TimetableSettings(semesterWeekCount = 18, activeTimeSchemeId = "ts-1"),
            currentWeek = 7L,
        )
        val (raw, store) = newStore(
            mapOf(
                "timetable_profiles" to MiniJson.encode(listOf(embedded.toJson())),
                "active_timetable_profile_id" to "p1",
                "timetable_settings" to
                    """{"semesterWeekCount":25,"appLocaleTag":"ja","timetableShowCurrentWeekCourses":false}""",
            ),
        )

        // 迁移前：顶层是 25，档案内嵌是 18 —— 读必须给 18；
        // 只存在于顶层的键（appLocaleTag）在档案存在时不参与读取。
        assertEquals(18L, store.loadSettingsJson()["semesterWeekCount"])
        assertNull(store.loadSettingsJson()["appLocaleTag"])
        assertEquals(18, store.loadSettings().semesterWeekCount)

        // 写入：真源落档案内嵌，顶层同步镜像（镜像保留自己独有的键）。
        store.saveSettingsPatch(mapOf("semesterWeekCount" to 20))

        assertEquals(20L, store.loadSettingsJson()["semesterWeekCount"])
        assertEquals(20, store.loadSettings().semesterWeekCount)
        val topMirror = MiniJson.parse(raw.getString("timetable_settings")!!) as Map<*, *>
        assertEquals(20L, topMirror["semesterWeekCount"])
        assertEquals("ja", topMirror["appLocaleTag"])
        val embeddedWritten = (MiniJson.parse(raw.getString("timetable_profiles")!!) as List<*>)
            .first() as Map<*, *>
        val embeddedSettings = embeddedWritten["settings"] as Map<*, *>
        assertEquals(20L, embeddedSettings["semesterWeekCount"])
        assertNull(embeddedSettings["appLocaleTag"])
    }

    /** 老盘态 3：迁移后重启 —— 不再迁移（幂等），用户新建档案不被覆盖。 */
    @Test
    fun bootstrapIsIdempotentAcrossRestartAndNeverOverwritesUserProfiles() {
        val (raw, store) = newStore(
            mapOf(
                "courses" to FlutterPrefsCodec.encodeStringList(
                    listOf(MiniJson.encode(course("c1").toJson())),
                ),
            ),
        )

        assertTrue(store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true).bootstrapped)
        val afterFirst = store.loadProfiles().profiles.map { it.id }

        // 重启（同一份盘）：rawSnapshot 是落盘名（带 flutter. 前缀），先还原成契约 key。
        val (raw2, restarted) = newStore(raw.logicalSnapshot())
        val second = restarted.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = false)
        assertFalse(second.bootstrapped)
        // marker 判在档案判之前：迁移完成过一次，之后无论盘上是否有档案都不再跑。
        assertEquals("already_migrated", second.skippedReason)

        // 即使调用方错传「空」（marker 已在），也绝不重组第二份档案。
        val third = restarted.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertFalse(third.bootstrapped)
        assertEquals("already_migrated", third.skippedReason)
        assertEquals(afterFirst, restarted.loadProfiles().profiles.map { it.id })

        // 用户在 Compose 里新建档案 → 再次重启不被 bootstrap 覆盖。
        restarted.saveProfiles(listOf(profile("user-1", listOf(course("c9")))))
        val (_, restartedAgain) = newStore(raw2.logicalSnapshot())
        val fourth = restartedAgain.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertFalse(fourth.bootstrapped)
        assertEquals(listOf("user-1"), restartedAgain.loadProfiles().profiles.map { it.id })
    }

    /** [InMemoryKeyValueStore.rawSnapshot] 是落盘名（带 `flutter.`），转回契约 key 供重启测试。 */
    private fun InMemoryKeyValueStore.logicalSnapshot(): Map<String, String> =
        rawSnapshot().entries.associate { (physical, value) ->
            FrozenValueCodec.logicalKey(physical)!! to value
        }

    /** 老盘态 4：`courses` 里有坏条目 —— 好的进档案、坏的进 `courses_unparsed_items`。 */
    @Test
    fun bootstrapQuarantinesBadLegacyCourseEntriesBeforeOverwriting() {
        val good1 = MiniJson.encode(course("c1").toJson())
        val bad = "{not-json"
        val good2 = MiniJson.encode(course("c2", "物理").toJson())
        val (raw, store) = newStore(
            mapOf("courses" to FlutterPrefsCodec.encodeStringList(listOf(good1, bad, good2))),
        )

        // 迁移前：没有档案，也没有隔离档。
        assertNull(raw.getString("timetable_profiles"))
        assertFalse(raw.contains("courses_unparsed_items"))

        val result = store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertTrue(result.bootstrapped)
        assertEquals(2, result.importedCourses)
        assertEquals(1, result.quarantinedCourses)

        // 迁移后：好条目进档案；坏条目原始 JSON 字面量进隔离档。
        val loaded = store.loadProfiles().profiles.single()
        assertEquals(listOf("c1", "c2"), loaded.courses.map { it.id })
        val archive = MiniJson.parse(raw.getString("courses_unparsed_items")!!) as Map<*, *>
        assertEquals(1L, archive["count"])
        assertEquals(listOf(MiniJson.encode(bad)), archive["items"] as List<*>)
        // 旧 key 保留（Dart 不写回原始列表）。
        assertTrue(raw.contains("courses"))
    }

    // ---------- 夹具 ----------

    private fun course(id: String, name: String = "数学") = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun profile(id: String, courses: List<Course> = emptyList()) = TimetableProfile(
        id = id,
        name = "课表-$id",
        courses = courses,
        currentWeek = 3L,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = LocalDateTime.of(2026, 9, 2, 8, 0),
    )
}
