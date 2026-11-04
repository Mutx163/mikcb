package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.import.IcsImportModel
import com.mutx163.qingyu.pages.sync.CloudSyncLogic
import com.mutx163.qingyu.platform.SecretCipher
import com.mutx163.qingyu.platform.WebdavConfigStoreImpl
import com.mutx163.qingyu.transfer.IcsSerializer
import com.mutx163.qingyu.transfer.collectCourseEvents
import com.mutx163.qingyu.transfer.compareIcsEvents
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 升级链路端到端矩阵（7 格，JVM 单测；每格夹具独立、可单独跑）。
 *
 * 只允许读生产代码、只新增测试：本文件**不修改** Android 主源码目录与 `lib/` 目录。
 * 断言钉的是「升级后用户能看到的状态」（档案 / 周次 / 设置 / 隔离档 / 连接态 / 导入结果），
 * 而不是某个私有方法的内部字段。
 *
 * 与 Lead 描述的差异已写进相关用例 KDoc（尤其第 5 格的「旧 key 是否保留」）。
 */
class UpgradeScenarioTest {

    // ==================================================================
    // 格 1：旧 Flutter 盘（有 courses、无 profiles）→ bootstrap
    // ==================================================================

    /**
     * 旧 Flutter 世界只有单 key `courses`：bootstrap 后用户应看到一份默认课表、
     * 周次/学期周数/开学日/语言都被带过来，且 marker 让第二次启动不重复建档。
     *
     * 修复候选：`e57607b5`（A+B 迁移：legacy bootstrap + 内嵌 settings 镜像）。
     */
    @Test
    fun `格1 旧 courses 无 profiles 迁移后用户可见状态`() {
        val raw = InMemoryKeyValueStore()
        raw.putStringList(
            TimetableStore.KEY_LEGACY_COURSES,
            listOf(
                MiniJson.encode(legacyCourse("c1", "高等数学", "张老师", "教学楼A101", 1, 1, 2).toJson()),
                MiniJson.encode(legacyCourse("c2", "大学英语", "王老师", "外语楼B203", 3, 3, 4).toJson()),
            ),
        )
        raw.putLong(TimetableStore.KEY_SEMESTER_START, LOCAL_MIDNIGHT_MILLIS)
        raw.putInt(TimetableStore.KEY_CURRENT_WEEK, 5)
        raw.putString(
            TimetableStore.KEY_SETTINGS,
            MiniJson.encode(linkedMapOf("semesterWeekCount" to 18, "appLocaleTag" to "ja")),
        )
        val store = TimetableStore(raw, nowMicros = { FIXED_NOW_MICROS })

        val result = store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertTrue("迁移应成功", result.bootstrapped)
        assertEquals(2, result.importedCourses)
        assertEquals(0, result.quarantinedCourses)

        val loaded = store.loadProfiles()
        assertEquals("应只有一份档案", 1, loaded.profiles.size)
        val profile = loaded.profiles.single()
        assertEquals(5L, profile.currentWeek)
        assertEquals("旧顶层 semesterWeekCount 应带进档案", 18, profile.settings.semesterWeekCount)
        assertEquals(
            "旧 semester_start 应带进档案，且与同一 millis 换算结果一致",
            DartTime.fromEpochMillis(LOCAL_MIDNIGHT_MILLIS),
            profile.settings.semesterStartDate,
        )
        assertEquals(2, profile.courses.size)
        assertEquals(18, store.loadSettings().semesterWeekCount)
        assertEquals("ja", store.loadSettingsJson()["appLocaleTag"])
        assertTrue(raw.getBool(TimetableStore.KEY_BOOTSTRAP_MIGRATED, false))

        // marker 已写：即使调用方仍报 currentProfilesEmpty=true，也不得重复建档。
        val again = store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertFalse(again.bootstrapped)
        assertEquals("already_migrated", again.skippedReason)
        assertEquals(1, store.loadProfiles().profiles.size)
    }

    // ==================================================================
    // 格 2：档案内嵌 settings = 真源，顶层镜像只是镜像
    // ==================================================================

    /**
     * 内嵌 18 与顶层镜像 25 冲突时，读必须是内嵌 18；写 patch 只改被点的键，
     * 顶层镜像不能被整份覆盖清空（`appLocaleTag="ja"` 必须还在）。
     *
     * 修复候选：`e57607b5`（内嵌 settings 读优先 + 合并写镜像）。
     */
    @Test
    fun `格2 内嵌 settings 优先于顶层镜像且 patch 不清空镜像`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson(
                    "p1" to linkedMapOf("semesterWeekCount" to 18, "appLocaleTag" to "ja"),
                ),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
                TimetableStore.KEY_SETTINGS to MiniJson.encode(
                    linkedMapOf("semesterWeekCount" to 25, "appLocaleTag" to "ja"),
                ),
            ),
        )
        val store = TimetableStore(raw)

        assertEquals("活动档案内嵌 settings 才是真源", 18, store.loadSettings().semesterWeekCount)

        store.saveSettingsPatch(linkedMapOf("semesterWeekCount" to 20))
        assertEquals(20, store.loadSettings().semesterWeekCount)
        assertEquals(20, (store.loadSettingsJson()["semesterWeekCount"] as Number).toInt())

        val topMirror = MiniJson.parse(raw.getString(TimetableStore.KEY_SETTINGS)!!) as Map<*, *>
        assertEquals("镜像里的目标键应同步", 20L, (topMirror["semesterWeekCount"] as Number).toLong())
        assertEquals("镜像里未被点的键不能被清空", "ja", topMirror["appLocaleTag"])
    }

    // ==================================================================
    // 格 3：全局设置缺失但档案存在 → 从活动档案播种，切档不跟着变
    // ==================================================================

    /**
     * `app_global_settings_v1` 缺失时，44 个整机级键应从活动档案 p1 播种一次；
     * 之后切到 p2，这 6 个外观/语言键仍保持 p1 值（整机级不随课表走）。
     *
     * 修复候选：`30e2aca6`（全局设置 44 键播种 + overlay/split）。
     */
    @Test
    fun `格3 全局设置缺失时从活动档案播种且切档不变`() {
        val p1 = linkedMapOf<String, Any?>(
            "appThemeMode" to "dark",
            "appFontMode" to "harmonyOs",
            "appFontWeight" to 700,
            "appLocaleTag" to "ja",
            "courseCardSurfaceStyle" to "refraction",
            "homeNavigationForm" to "glassDock",
            "semesterWeekCount" to 18,
        )
        val p2 = linkedMapOf<String, Any?>(
            "appThemeMode" to "light",
            "appFontMode" to "serif",
            "appFontWeight" to 400,
            "appLocaleTag" to "en",
            "courseCardSurfaceStyle" to "solid",
            "homeNavigationForm" to "classic",
            "semesterWeekCount" to 25,
        )
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson("p1" to p1, "p2" to p2),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        val store = TimetableStore(raw)

        // loadSettingsJson 的 overlay 会走 ensureInitialized（种子入口）。
        store.loadSettingsJson()

        val global = globalSettingsObject(raw) ?: throw AssertionError("应已写出 app_global_settings_v1")
        assertEquals("全局对象固定 44 键", 44, global.size)
        for (key in AppGlobalSettingsStore.KEYS) {
            assertTrue("44 键应全部存在（值可为 null）：$key", global.containsKey(key))
        }
        for (key in GLOBAL_KEYS_TO_PIN) {
            assertGlobalValue("应从 p1 内嵌播种：$key", p1[key], global[key])
        }
        assertTrue(raw.getBool(AppGlobalSettingsStore.KEY_MIGRATED, false))

        // 切到 p2：整机级键不许跟着换。
        store.saveActiveProfileId("p2")
        val afterSwitchGlobal = globalSettingsObject(raw) ?: throw AssertionError("全局对象不应消失")
        for (key in GLOBAL_KEYS_TO_PIN) {
            assertGlobalValue("切档后仍应是 p1 值：$key", p1[key], afterSwitchGlobal[key])
        }
        val afterSwitchMerged = store.loadSettingsJson()
        for (key in GLOBAL_KEYS_TO_PIN) {
            assertGlobalValue("切档后读到的全局键仍是 p1 值：$key", p1[key], afterSwitchMerged[key])
        }
        assertEquals(
            "非全局键 semesterWeekCount 应来自 p2",
            25L,
            (afterSwitchMerged["semesterWeekCount"] as Number).toLong(),
        )
    }

    // ==================================================================
    // 格 4：foruiTheme 坏盘两条路径（默认 MIUI vs 合法对象缺键 BLUE）
    // ==================================================================

    /**
     * 整份 `timetable_settings` 不是 JSON 对象（坏盘）→ `defaults()` 路径 → MIUI。
     *
     * 修复候选：`d00b284e`（foruiTheme 两条真值路径分流）。
     */
    @Test
    fun `格4a 坏盘 foruiTheme 走 defaults 回落 MIUI`() {
        val store = TimetableStore(
            InMemoryKeyValueStore(
                mapOf(TimetableStore.KEY_SETTINGS to "[1,2,3]"),
            ),
        )
        val model = TimetableSettingsModelStore(store).load()
        assertEquals(ForuiTheme.MIUI, model.foruiTheme)
        assertEquals("miui", model.foruiTheme.value)
    }

    /**
     * JSON 合法但缺 `foruiTheme` 键 → `fromValue(null)` 的 orElse 路径 → BLUE。
     *
     * 修复候选：`d00b284e`。
     */
    @Test
    fun `格4b 合法对象缺 foruiTheme 键回落 BLUE`() {
        val store = TimetableStore(
            InMemoryKeyValueStore(
                mapOf(TimetableStore.KEY_SETTINGS to """{"appThemeMode":"dark"}"""),
            ),
        )
        val model = TimetableSettingsModelStore(store).load()
        assertEquals(ForuiTheme.BLUE, model.foruiTheme)
        assertEquals("blue", model.foruiTheme.value)
    }

    // ==================================================================
    // 格 5：旧 courses 全坏 → 隔离档 count=1
    // ==================================================================

    /**
     * 唯一一条旧课程 JSON 不可解析时：坏条目进 `courses_unparsed_items`（count=1），
     * 且因为「全坏」还会走 `archiveCorrupt("courses")`——**原 key 被留档后删除**。
     *
     * ⚠️ 与 Lead 描述「旧 key 保留」的差异：Lead 那条对应「2 好 + 1 坏」的部分坏场景
     * （源码注释 :428「整份 key 保留」）。本格是全坏场景，生产实现明确在
     * `TimetableStore.kt:430-437` 走 `archiveCorrupt(KEY_LEGACY_COURSES)`，
     * 即「写 `courses_corrupt_backup_<micros>` + 删 `courses`」。测试以生产真值为准。
     *
     * 修复候选：`e57607b5`（bootstrap 全坏分支留档删除）。
     */
    @Test
    fun `格5 旧 courses 全坏时隔离档 count 为 1 且原 key 留档删除`() {
        val raw = InMemoryKeyValueStore()
        raw.putStringList(TimetableStore.KEY_LEGACY_COURSES, listOf("{bad json"))
        val store = TimetableStore(raw, nowMicros = { FIXED_NOW_MICROS })

        val result = store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
        assertFalse("全坏不建空档案", result.bootstrapped)
        assertEquals("no_parsable_courses", result.skippedReason)
        assertEquals(1, result.quarantinedCourses)

        val archived = MiniJson.parse(raw.getString(TimetableStore.KEY_COURSES_UNPARSED_ITEMS)!!) as Map<*, *>
        assertEquals(1, (archived["count"] as Number).toInt())
        assertEquals(1, (archived["items"] as List<*>).size)

        // 与 Lead 描述的差异：全坏时原 courses key 不保留，而是留档删除。
        assertFalse("全坏时原 courses key 应被删除", raw.contains(TimetableStore.KEY_LEGACY_COURSES))
        val backupKey = corruptBackupKey(TimetableStore.KEY_LEGACY_COURSES, FIXED_NOW_MICROS)
        assertTrue("原 key 应留档到 $backupKey", raw.contains(backupKey))
        // 留档内容是原始 StringList 的编码（不是单条课程 JSON）。
        assertEquals(listOf("{bad json"), FrozenValueCodec.decodeStringList(raw.getString(backupKey)!!))

        assertEquals("不应产生空档案", 0, store.loadProfiles().profiles.size)
    }

    // ==================================================================
    // 格 6：旧 secure storage 密码不被新版识别 + 升级提示标记只写一次
    // ==================================================================

    /**
     * 旧 `flutter_secure_storage` 键 `webdav_sync_password` 里有值，但新版实现只认
     * 自己的密文键 `mikcb_webdav_password_v2` ⇒ `hasStoredPassword()==false`；
     * 用户名非空 + 没密码 ⇒ 云同步页「未连接」。
     *
     * ⚠️ 与 Lead 描述不一致：Lead 认为纯判据 `shouldPromptLegacyPasswordReentry` 尚未落地，
     * 但同步线已在 `46280a4b` / `CloudSyncModel.kt:198,213` 实现（含一次性取数入口）。
     * 因此本格直接调用生产入口，不复制规则；用计数装饰器验证「标记只写一次」。
     *
     * 修复候选：`f39bcd11`（WebdavConfigStoreImpl 另起 v2 密文键）/ `46280a4b`（升级提示判据）。
     */
    @Test
    fun `格6 旧密码不被识别为已连接且升级提示标记只写一次`() {
        val raw = InMemoryKeyValueStore(mapOf("webdav_sync_password" to "legacy-ciphertext"))
        val cipher = ReversibleFakeCipher()
        val configStore = WebdavConfigStoreImpl(raw, cipher)

        assertEquals("旧 key 里的密文应原样留在盘上", "legacy-ciphertext", raw.getString("webdav_sync_password"))
        assertFalse("旧插件键不被新版密文键识别", configStore.hasStoredPassword())
        assertEquals(
            "用户名非空但没有密码 ⇒ 未连接",
            false,
            CloudSyncLogic.isAccountConnected("u@x", configStore.hasStoredPassword()),
        )

        // 新键写入后才是「已存密码」。
        configStore.storePassword("p@ss")
        assertTrue(configStore.hasStoredPassword())

        // 生产判据已在 46280a4b 落地（与 Lead 的「未实现」描述不一致），直接走真实入口。
        val markerKey = CloudSyncLogic.LEGACY_REPROMPT_MARK_CLOUD
        assertTrue(CloudSyncLogic.shouldPromptLegacyPasswordReentry(false, true, false))
        assertFalse(CloudSyncLogic.shouldPromptLegacyPasswordReentry(false, true, true))
        assertFalse(CloudSyncLogic.shouldPromptLegacyPasswordReentry(true, true, false))

        val counting = CountingKeyValueStore(InMemoryKeyValueStore())
        var markCalls = 0
        val alreadyPrompted = { counting.getBool(markerKey, false) }
        val hasLegacyDartCredential = { _: String -> true }
        val markPrompted = {
            markCalls += 1
            counting.putBool(markerKey, true)
        }
        assertTrue(
            "首次：有旧凭据且未提示过 ⇒ 应提示",
            CloudSyncLogic.takeLegacyPasswordReentryPrompt(
                hasStoredPassword = false,
                legacyKeySuffix = CloudSyncLogic.LEGACY_KEY_SUFFIX_CLOUD,
                alreadyPrompted = alreadyPrompted,
                hasLegacyDartCredential = hasLegacyDartCredential,
                markPrompted = markPrompted,
            ),
        )
        assertEquals("标记只写一次", 1, markCalls)
        assertEquals("标记只写一次（落盘）", 1, counting.writeCount(markerKey))
        assertFalse(
            "第二次：标记已在 ⇒ 不再提示",
            CloudSyncLogic.takeLegacyPasswordReentryPrompt(
                hasStoredPassword = false,
                legacyKeySuffix = CloudSyncLogic.LEGACY_KEY_SUFFIX_CLOUD,
                alreadyPrompted = alreadyPrompted,
                hasLegacyDartCredential = hasLegacyDartCredential,
                markPrompted = markPrompted,
            ),
        )
        assertEquals("第二次判断不再写标记", 1, markCalls)
        assertEquals("第二次判断不再写标记（落盘）", 1, counting.writeCount(markerKey))
    }

    // ==================================================================
    // 格 7：18 门课真实 ICS 导出 → 导入逐字段一致
    // ==================================================================

    /**
     * 18 门课各占一个时段、各上一周；走真实导出 `collectCourseEvents` + `IcsSerializer`
     * 再走导入 `IcsImportModel.parseWakeUpSchedule`，18 条一条不少、逐字段一致。
     *
     * 重点防回归：`Location: A楼-101` 的末段不得被当成教师（教师必须纯教师名）。
     *
     * 修复候选：`2d10e39b`（ICS 往返测试落地）/ `132bfc2a`（教师-地点前缀解析修复）。
     */
    @Test
    fun `格7 18 门课 ICS 导出再导入逐字段一致且教师不含地点末段`() {
        val source = (1..18).map { i ->
            course(
                id = "src-$i",
                name = "课程${i.toString().padStart(2, '0')}",
                teacher = "教师$i",
                location = "A楼-${100 + i}",
                dayOfWeek = (i - 1) % 7 + 1,
                startSection = i,
                endSection = i,
                startTime = "08:00",
                endTime = "08:45",
                startWeek = i,
                endWeek = i,
                description = "简介$i",
                note = "备注$i",
            )
        }

        val imported = IcsImportModel.parseWakeUpSchedule(
            exportIcs(source, LocalDateTime.of(2026, 3, 2, 0, 0)),
            FIXED_LOCAL_NOW,
        )
        assertEquals("18 门课导出再导入应仍是 18 条", 18, imported.courses.size)
        assertEquals(LocalDateTime.of(2026, 3, 2, 0, 0), imported.semesterStart)

        val byName = imported.courses.associateBy { it.name }
        for (src in source) {
            val got = byName[src.name] ?: throw AssertionError("导入结果缺少 ${src.name}")
            assertEquals(src.name, got.name)
            assertEquals(src.teacher, got.teacher)
            assertEquals(src.location, got.location)
            assertEquals(src.description, got.description)
            assertEquals(src.note, got.note)
            assertEquals(src.dayOfWeek, got.dayOfWeek)
            assertEquals(src.startSection, got.startSection)
            assertEquals(src.endSection, got.endSection)
            assertEquals(src.startWeek, got.startWeek)
            assertEquals(src.endWeek, got.endWeek)

            val locationTail = src.location.substringAfterLast('-')
            assertFalse("教师不得含地点末段（$locationTail）：${got.teacher}", got.teacher.contains(locationTail))
            assertFalse("教师不得含地点串：${got.teacher}", got.teacher.contains("A楼"))
        }
    }

    // ==================================================================
    // 私有夹具 / helper（按格归属标注；公共构造器放最后）
    // ==================================================================

    /** 格 1 / 5 共用的固定时钟（micros）与「本地零点」毫秒，避免时区敏感。 */
    private val FIXED_NOW_MICROS = 1_700_000_000_000_000L
    private val LOCAL_MIDNIGHT_MILLIS = DartTime.toEpochMillis(LocalDateTime.of(2026, 3, 2, 0, 0))
    private val FIXED_LOCAL_NOW = LocalDateTime.of(2026, 11, 4, 12, 0)

    /** 格 3 钉住的 6 个整机级键。 */
    private val GLOBAL_KEYS_TO_PIN = listOf(
        "appThemeMode",
        "appFontMode",
        "appFontWeight",
        "appLocaleTag",
        "courseCardSurfaceStyle",
        "homeNavigationForm",
    )

    /** 格 1 的旧世界课程序列化（只依赖生产 Course.toJson 的键契约）。 */
    private fun legacyCourse(
        id: String,
        name: String,
        teacher: String,
        location: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
    ): Course = course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
    )

    /** 格 2 / 3 共用的档案数组夹具（id → 内嵌 settings）。 */
    private fun profilesJson(vararg profiles: Pair<String, Map<String, Any?>>): String =
        MiniJson.encode(
            profiles.map { (id, settings) ->
                linkedMapOf(
                    "id" to id,
                    "name" to "课表-$id",
                    "courses" to emptyList<Any?>(),
                    "settings" to settings,
                    "currentWeek" to 1,
                )
            },
        )

    /** 格 3：盘上全局对象原样读出（不走 44 键补齐）。 */
    private fun globalSettingsObject(raw: InMemoryKeyValueStore): Map<*, *>? =
        raw.getString(AppGlobalSettingsStore.KEY)?.let { MiniJson.parse(it) as? Map<*, *> }

    /** 格 3：JSON 数字解析成 Long/Double 时与夹具里的 Int 对齐后比较。 */
    private fun assertGlobalValue(label: String, expected: Any?, actual: Any?) {
        if (expected is Number && actual is Number) {
            assertEquals(label, expected.toLong(), actual.toLong())
        } else {
            assertEquals(label, expected, actual)
        }
    }

    /** 格 6：测试内私有计数装饰器，只统计写次数（不替代生产实现）。 */
    private class CountingKeyValueStore(private val delegate: KeyValueStore) : KeyValueStore by delegate {
        private val puts = mutableMapOf<String, Int>()

        override fun putString(key: String, value: String) {
            puts[key] = (puts[key] ?: 0) + 1
            delegate.putString(key, value)
        }

        override fun putBool(key: String, value: Boolean) {
            puts[key] = (puts[key] ?: 0) + 1
            delegate.putBool(key, value)
        }

        fun writeCount(key: String): Int = puts[key] ?: 0
    }

    /** 格 6：可逆假 cipher（JVM 无 Android KeyStore）。 */
    private class ReversibleFakeCipher : SecretCipher {
        override fun encrypt(plaintext: String): String = "enc:$plaintext"

        override fun decrypt(ciphertext: String): String? =
            ciphertext.removePrefix("enc:").takeIf { ciphertext.startsWith("enc:") }
    }

    /** 格 7：与 `ImportRoundTripTest` 同形的真实导出路径（只读复用生产 transfer 实现）。 */
    private fun exportIcs(courses: List<Course>, semesterStart: LocalDateTime): String {
        val collected = collectCourseEvents(
            profileId = "p1",
            courses = courses,
            semesterStartDate = semesterStart,
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 7, 31, 0, 0),
        )
        val events = collected.events.sortedWith(Comparator { left, right -> compareIcsEvents(left, right) })
        return IcsSerializer.serializeCalendar(
            calendarName = "升级矩阵",
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 7, 31, 0, 0),
            generatedAt = FIXED_LOCAL_NOW,
            events = events,
        )
    }

    /** 公共 Course 构造器（与 `ImportRoundTripTest` 同形，只保留本文件需要的形参）。 */
    @Suppress("LongParameterList")
    private fun course(
        id: String,
        name: String,
        teacher: String,
        location: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        startTime: String,
        endTime: String,
        startWeek: Int = 1,
        endWeek: Int = 16,
        description: String? = null,
        note: String? = null,
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        startWeek = startWeek,
        endWeek = endWeek,
        description = description,
        note = note,
    )
}
