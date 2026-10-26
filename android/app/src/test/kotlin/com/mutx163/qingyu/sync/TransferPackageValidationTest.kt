package com.mutx163.qingyu.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 传输包包体校验纯逻辑单测。
 *
 * 期望值来源：
 * - [Dart抄录] test/services/transfer_package_test.dart（614 行）逐条转录；
 * - [Dart推演] 按 transfer_package.dart 实现行号推演（字段表/门序/唯一 id 规则）；
 * - [人推] 人推边界（正交覆盖，不来自既有测试）。
 */
class TransferPackageValidationTest {

    // ---------- 测试夹具（对齐 transfer_package_test.dart 的 _course/_exam 夹具字段） ----------

    private fun courseJson(
        id: String = "course-1",
        name: String? = "线性代数",
    ): LinkedHashMap<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "teacher" to "Teacher",
        "location" to "A-101",
        "dayOfWeek" to 1L,
        "startSection" to 1L,
        "endSection" to 2L,
        "startTime" to "08:00",
        "endTime" to "09:40",
    )

    private fun profileJson(
        id: String = "profile-1",
        name: String = "大二下",
        courses: List<Any?> = listOf(courseJson()),
    ): LinkedHashMap<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "courses" to courses,
        "tasks" to emptyList<Any?>(),
        "scheduleItems" to emptyList<Any?>(),
        "exams" to emptyList<Any?>(),
        "settings" to TimetableSettings.defaults().toJson(),
        "currentWeek" to 1L,
        "createdAt" to "2026-04-01T08:00:00.000",
        "lastUsedAt" to "2026-04-01T08:00:00.000",
    )

    /** 结构最小合法包：八张列表键齐全 + 信封 + 必填标量。 */
    private fun basePackage(
        scope: String = "current_timetable",
        channel: String = "file",
        packageId: String = "transfer-test-1",
        exportedAt: String = "2026-04-01T08:00:00.000",
        currentWeek: Any? = 1L,
        settings: Any? = TimetableSettings.defaults().toJson(),
        profiles: List<Any?> = emptyList(),
    ): LinkedHashMap<String, Any?> {
        val json = linkedMapOf<String, Any?>(
            "app" to "mikcb",
            "packageType" to "transfer",
            "schemaVersion" to 1,
            "packageId" to packageId,
            "scope" to scope,
            "channel" to channel,
            "exportedAt" to exportedAt,
            "courses" to emptyList<Any?>(),
            "tasks" to emptyList<Any?>(),
            "scheduleItems" to emptyList<Any?>(),
            "exams" to emptyList<Any?>(),
            "timeSchemes" to emptyList<Any?>(),
            "scheduleDateRules" to emptyList<Any?>(),
            "locationTimeGroups" to emptyList<Any?>(),
            "profiles" to profiles,
        )
        if (currentWeek != null) json["currentWeek"] = currentWeek
        if (settings != null) json["settings"] = settings
        return json
    }

    private fun firstError(json: Map<String, Any?>): String =
        validateTransferPackageJson(MiniJson.encode(json)).errors.first()

    // ---------- 信封与版本门 ----------

    @Test
    fun `valid minimal package passes with empty diagnostics`() {
        // [Dart抄录] transfer_package_test.dart:126-153（scoped 包可过 decode）
        val result = validateTransferPackageJson(MiniJson.encode(basePackage()))
        assertTrue(result.isValid)
        assertTrue(result.warnings.isEmpty())
    }

    @Test
    fun `rejects non-json content as json invalid`() {
        // [Dart抄录] transfer_package.dart:318-324（decode 的 jsonDecode catch）
        assertEquals(
            "transfer_package_json_invalid",
            validateTransferPackageJson("not json at all").errors.single(),
        )
    }

    @Test
    fun `rejects non-object root`() {
        // [Dart抄录] transfer_package.dart:325-327（decoded is! Map）
        assertEquals(
            "transfer_package_root_invalid",
            validateTransferPackageJson("[1,2,3]").errors.single(),
        )
    }

    @Test
    fun `rejects wrong app or packageType`() {
        // [Dart抄录] transfer_package.dart:342-344
        val wrongApp = basePackage(); wrongApp["app"] = "other"
        assertEquals("transfer_package_type_invalid", firstError(wrongApp))

        val wrongType = basePackage(); wrongType["packageType"] = "snapshot"
        assertEquals("transfer_package_type_invalid", firstError(wrongType))
    }

    @Test
    fun `rejects unsupported schema version`() {
        // [Dart抄录] transfer_package_test.dart:155-174（schemaVersion+1）
        val future = basePackage(); future["schemaVersion"] = 2L
        assertEquals("transfer_package_schema_unsupported", firstError(future))
    }

    @Test
    fun `rejects schema version as string but accepts integral double`() {
        // [Dart推演] :345-347 version != schemaVersion；Dart num 语义下 1.0 == 1 成立、
        // "1" == 1 不成立（String 不等于 int）。
        val asString = basePackage(); asString["schemaVersion"] = "1"
        assertEquals("transfer_package_schema_unsupported", firstError(asString))

        val asDouble = basePackage(); asDouble["schemaVersion"] = 1.0
        assertTrue(validateTransferPackageJson(MiniJson.encode(asDouble)).isValid)
    }

    // ---------- 必填列表键门 ----------

    @Test
    fun `diagnoses missing envelope list fields`() {
        // [Dart抄录] transfer_package_test.dart:176-194（toJson 后删 courses）
        val missingCourses = basePackage(); missingCourses.remove("courses")
        assertEquals("transfer_course_list_required", firstError(missingCourses))

        // [Dart推演] _requiredListKinds 声明序逐张检查，多缺时报第一张。
        val missingAll = basePackage()
        for (key in TRANSFER_REQUIRED_LIST_KINDS.keys) missingAll.remove(key)
        assertEquals("transfer_course_list_required", firstError(missingAll))

        val missingProfiles = basePackage(); missingProfiles.remove("profiles")
        assertEquals("transfer_profile_list_required", firstError(missingProfiles))
    }

    // ---------- 必填标量门 ----------

    @Test
    fun `requires non-blank package id`() {
        // [Dart抄录] transfer_package.dart:280-282 + _requiredString :552-562
        assertEquals(
            "transfer_package_id_required",
            firstError(basePackage(packageId = "  ")),
        )
    }

    @Test
    fun `requires valid scope`() {
        // [Dart抄录] TransferScope.fromValue → transfer_scope_invalid（TransferEnvelope.kt 同口径）
        assertEquals("transfer_scope_invalid", firstError(basePackage(scope = "bogus")))
        // [Dart推演] _requiredString(json,'scope','scope') → 缺失报 transfer_scope_required
        assertEquals("transfer_scope_required", firstError(basePackage(scope = "")))
    }

    @Test
    fun `requires known channel string`() {
        // [Dart推演] _parseChannel :598-609：非字符串才报 required；空串/未知值都报 invalid（不回落）
        assertEquals("transfer_channel_invalid", firstError(basePackage(channel = "")))
        val nonString = basePackage(); nonString["channel"] = 42L
        assertEquals("transfer_channel_required", firstError(nonString))
        val bad = basePackage(); bad["channel"] = "smoke-signal"
        assertEquals("transfer_channel_invalid", firstError(bad))
        // qr/lan/cloud/file 全放行
        for (value in listOf("file", "qr", "lan", "cloud")) {
            assertTrue(validateTransferPackageJson(MiniJson.encode(basePackage(channel = value))).isValid)
        }
    }

    @Test
    fun `requires parseable exportedAt`() {
        // [Dart推演] _parseExportedAt :587-596
        assertEquals("transfer_exported_at_required", firstError(basePackage(exportedAt = " ")))
        assertEquals("transfer_exported_at_invalid", firstError(basePackage(exportedAt = "not-a-date")))
    }

    @Test
    fun `optional scalars must be well typed`() {
        // [Dart推演] _optionalString :564-574 / _optionalInt :576-585
        val badProfileName = basePackage(); badProfileName["profileName"] = 42L
        assertEquals("transfer_profileName_invalid", firstError(badProfileName))

        val badWeek = basePackage(); badWeek["currentWeek"] = "5"
        assertEquals("transfer_current_week_invalid", firstError(badWeek))

        // 整值 double 可过（num.toInt() == value）
        val doubleWeek = basePackage(); doubleWeek["currentWeek"] = 5.0
        assertTrue(validateTransferPackageJson(MiniJson.encode(doubleWeek)).isValid)
    }

    @Test
    fun `rejects unknown backup type`() {
        // [Dart抄录] transfer_package.dart:365-368
        val bad = basePackage(); bad["backupType"] = "incremental"
        assertEquals("transfer_backup_type_invalid", firstError(bad))
        val full = basePackage(); full["backupType"] = "full"
        assertTrue(validateTransferPackageJson(MiniJson.encode(full)).isValid)
    }

    @Test
    fun `settings must be an object when present`() {
        // [Dart抄录] transfer_package.dart:372-375（settingsRaw is! Map）
        val bad = basePackage(settings = "settings")
        assertEquals("transfer_settings_invalid", firstError(bad))
    }

    // ---------- scope 语义门 ----------

    @Test
    fun `whole-timetable scope requires settings or profiles`() {
        // [Dart抄录] transfer_package.dart:422-426（currentTimetable + 无 settings + 无 profiles）
        assertEquals(
            "transfer_settings_required",
            firstError(basePackage(scope = "current_timetable", settings = null, currentWeek = 1L)),
        )
        // all_data 同口径
        assertEquals(
            "transfer_settings_required",
            firstError(basePackage(scope = "all_data", settings = null, currentWeek = 1L)),
        )
        // 带 profiles（profileScoped）即可豁免
        val withProfiles = basePackage(
            scope = "current_timetable",
            settings = null,
            currentWeek = 1L,
            profiles = listOf(profileJson()),
        )
        assertTrue(validateTransferPackageJson(MiniJson.encode(withProfiles)).isValid)
    }

    @Test
    fun `non-exempt scopes require currentWeek`() {
        // [Dart抄录] transfer_package.dart:427-433（week_timetable 不在三个豁免 scope 里）
        assertEquals(
            "transfer_current_week_required",
            firstError(basePackage(scope = "week_timetable", settings = null, currentWeek = null)),
        )
        // [Dart抄录] transfer_package_test.dart:142-153：selected-course 带课程载荷可省 currentWeek。
        // （空载荷会落到 validate() 的 transfer_package_empty——Dart 侧同样先过门再报空包。
        // time_template 的载荷是 timeSchemes（补课表反而会撞 transfer_time_template_empty，
        // 见 :490-492），selected_* 的载荷是 courses，各自把「currentWeek 豁免」单独钉住。）
        for (scope in listOf("selected_courses", "selected_course")) {
            val exempt = basePackage(scope = scope, settings = null, currentWeek = null)
            exempt["courses"] = listOf(courseJson())
            val result = validateTransferPackageJson(MiniJson.encode(exempt))
            assertTrue(scope, result.isValid)
        }
        val template = basePackage(scope = "time_template", settings = null, currentWeek = null)
        template["timeSchemes"] = listOf(
            linkedMapOf<String, Any?>(
                "id" to "scheme-1", "name" to "作息",
                "sections" to listOf(linkedMapOf("startTime" to "08:00", "endTime" to "08:45")),
                "createdAt" to "2026-04-01T08:00:00.000",
                "updatedAt" to "2026-04-01T08:00:00.000",
            ),
        )
        assertTrue(validateTransferPackageJson(MiniJson.encode(template)).isValid)
    }

    // ---------- 实体字段校验（两张表） ----------

    @Test
    fun `missing entity field reports kind_field_required`() {
        // [Dart推演] _requiredEntityFields['course'] + :713-717 循环
        val noName = courseJson(name = null) as LinkedHashMap<String, Any?>
        val pkg = basePackage(scope = "current_timetable")
        pkg["courses"] = listOf(noName)
        assertEquals("transfer_course_name_required", firstError(pkg))

        // task 表：id/title/createdAt/updatedAt
        val taskNoTitle = linkedMapOf<String, Any?>(
            "id" to "task-1", "createdAt" to "2026-04-01T08:00:00.000",
            "updatedAt" to "2026-04-01T08:00:00.000",
        )
        val taskPkg = basePackage(scope = "current_timetable")
        taskPkg["tasks"] = listOf(taskNoTitle)
        assertEquals("transfer_task_title_required", firstError(taskPkg))
    }

    @Test
    fun `non-list entity value and non-map item are rejected`() {
        // [Dart推演] _parseList :619-627
        val pkg = basePackage(scope = "current_timetable")
        pkg["courses"] = "courses"
        assertEquals("transfer_course_list_invalid", firstError(pkg))

        val pkg2 = basePackage(scope = "current_timetable")
        pkg2["exams"] = listOf("not-a-map")
        assertEquals("transfer_exam_invalid", firstError(pkg2))
    }

    @Test
    fun `profile nested lists are validated recursively`() {
        // [Dart抄录] _validateProfileNestedMaps :723-742
        val nestedNotList = profileJson(courses = listOf(courseJson()))
        nestedNotList["courses"] = "not-a-list"
        val pkg = basePackage(scope = "current_timetable", profiles = listOf(nestedNotList))
        assertEquals("transfer_profile_courses_list_invalid", firstError(pkg))

        // 嵌套课程缺字段 → 内层种类错误码
        val nestedBadCourse = profileJson(courses = listOf(courseJson(name = null)))
        val pkg2 = basePackage(scope = "current_timetable", profiles = listOf(nestedBadCourse))
        assertEquals("transfer_course_name_required", firstError(pkg2))

        // 嵌套条目非 Map
        val nestedNonMap = profileJson(courses = listOf(42L))
        val pkg3 = basePackage(scope = "current_timetable", profiles = listOf(nestedNonMap))
        assertEquals("transfer_course_invalid", firstError(pkg3))
    }

    @Test
    fun `empty or duplicate entity ids are rejected`() {
        // [Dart推演] _requireUniqueIds :670-681（空 → id_required；重复 → id_duplicate）
        val emptyId = basePackage(scope = "current_timetable")
        emptyId["courses"] = listOf(courseJson(id = "  "))
        assertEquals("transfer_course_id_required", firstError(emptyId))

        val dup = basePackage(scope = "current_timetable")
        dup["courses"] = listOf(courseJson(id = "same"), courseJson(id = "same", name = "物理"))
        assertEquals("transfer_course_id_duplicate", firstError(dup))

        // 非字符串 id 取 toString 后照常查重
        val numericFirst = courseJson(id = "7")
        numericFirst["id"] = 7L
        val numericId = basePackage(scope = "current_timetable")
        numericId["courses"] = listOf(numericFirst, courseJson(id = "7", name = "重复"))
        assertEquals("transfer_course_id_duplicate", firstError(numericId))
    }

    // ---------- 唯一 id 规则（cloud/full 与 file/qr/lan 的差异） ----------

    @Test
    fun `duplicate ids inside one profile are rejected even for full backup`() {
        // [Dart抄录] transfer_package_test.dart:210-236
        val pkg = basePackage(
            scope = "all_data",
            settings = null,
            currentWeek = null,
            profiles = listOf(profileJson(courses = listOf(courseJson(id = "c1"), courseJson(id = "c1", name = "重复")))),
        )
        pkg["backupType"] = "full"
        assertEquals("transfer_course_id_duplicate", firstError(pkg))
    }

    @Test
    fun `cloud channel allows repeated ids across profiles but not within`() {
        // [Dart抄录] transfer_package_test.dart:238-271（同一 id 出现在两个 cloud 课表里合法）
        val pkg = basePackage(
            scope = "all_data",
            channel = "cloud",
            settings = null,
            currentWeek = null,
            profiles = listOf(
                profileJson(id = "profile-1", courses = listOf(courseJson(id = "shared"))),
                profileJson(id = "profile-2", name = "共享课表", courses = listOf(courseJson(id = "shared"))),
            ),
        )
        pkg["backupType"] = "full"
        assertTrue(validateTransferPackageJson(MiniJson.encode(pkg)).isValid)
    }

    @Test
    fun `full backups allow cross-profile repeated ids on file and qr channels`() {
        // [Dart抄录] transfer_package_test.dart:273-316（导入为新课表保留来源 id）
        for (channel in listOf("file", "qr")) {
            val pkg = basePackage(
                scope = "all_data",
                channel = channel,
                settings = null,
                currentWeek = null,
                profiles = listOf(
                    profileJson(id = "profile-1", courses = listOf(courseJson(id = "shared"))),
                    profileJson(id = "profile-2", name = "TA的课表", courses = listOf(courseJson(id = "shared"))),
                ),
            )
            pkg["backupType"] = "full"
            assertTrue("channel=$channel", validateTransferPackageJson(MiniJson.encode(pkg)).isValid)
        }
    }

    @Test
    fun `non-full file transfer pools top-level and profile ids for uniqueness`() {
        // [Dart抄录] _requireUniqueIdsAcross :683-706（顶层 + 各课表同一个池查重）
        val pkg = basePackage(
            scope = "all_data",
            channel = "file",
            settings = null,
            currentWeek = null,
            profiles = listOf(profileJson(courses = listOf(courseJson(id = "shared")))),
        )
        pkg["courses"] = listOf(courseJson(id = "shared", name = "顶层同名"))
        assertEquals("transfer_course_id_duplicate", firstError(pkg))
    }

    @Test
    fun `global kinds are always unique across the whole package`() {
        // [Dart抄录] :273-279（profile/time_scheme/time_rule/location_group 恒全局唯一）
        val schemeA = linkedMapOf<String, Any?>(
            "id" to "scheme-1", "name" to "作息",
            "sections" to listOf(linkedMapOf("startTime" to "08:00", "endTime" to "08:45")),
            "createdAt" to "2026-04-01T08:00:00.000",
            "updatedAt" to "2026-04-01T08:00:00.000",
        )
        val pkg = basePackage(scope = "current_timetable")
        pkg["timeSchemes"] = listOf(schemeA, LinkedHashMap(schemeA))
        assertEquals("transfer_time_scheme_id_duplicate", firstError(pkg))

        // profile id 重复（不因 cloud/full 豁免——豁免只覆盖四类实体）
        val cloudPkg = basePackage(
            scope = "all_data",
            channel = "cloud",
            settings = null,
            currentWeek = null,
            profiles = listOf(profileJson(id = "same"), profileJson(id = "same", name = "重复课表")),
        )
        cloudPkg["backupType"] = "full"
        assertEquals("transfer_profile_id_duplicate", firstError(cloudPkg))
    }

    // ---------- 结构诊断（validate()） ----------

    @Test
    fun `empty package reports transfer_package_empty`() {
        // [Dart抄录] transfer_package_test.dart:196-208
        val empty = basePackage(scope = "time_template", settings = null, currentWeek = null)
        val result = validateTransferPackageJson(MiniJson.encode(empty))
        assertFalse(result.isValid)
        assertTrue(result.errors.contains("transfer_package_empty"))
    }

    @Test
    fun `full all-data backup without profiles is an error`() {
        // [Dart抄录] transfer_package.dart:487-489（有 courses 载荷、无 profiles）
        // 无 settings 会先撞 transfer_settings_required 门（:422-426）；到结构诊断需带 settings。
        val pkg = basePackage(scope = "all_data", settings = TimetableSettings.defaults().toJson(), currentWeek = 1L)
        pkg["backupType"] = "full"
        pkg["courses"] = listOf(courseJson())
        val result = validateTransferPackageJson(MiniJson.encode(pkg))
        assertTrue(result.errors.contains("transfer_full_profiles_required"))
        assertFalse(result.errors.contains("transfer_package_empty"))
    }

    @Test
    fun `time template scope without schemes is an error`() {
        // [Dart抄录] transfer_package.dart:490-492（timeTemplate 无作息但 payload 非空）
        val pkg = basePackage(scope = "time_template", settings = null, currentWeek = null)
        pkg["courses"] = listOf(courseJson())
        val result = validateTransferPackageJson(MiniJson.encode(pkg))
        assertTrue(result.errors.contains("transfer_time_template_empty"))
        assertFalse(result.errors.contains("transfer_package_empty"))
    }

    @Test
    fun `unknown activeProfileId is a warning not an error`() {
        // [Dart抄录] transfer_package.dart:493-497
        val pkg = basePackage(currentWeek = 1L, profiles = listOf(profileJson()))
        pkg["activeProfileId"] = "nope"
        val result = validateTransferPackageJson(MiniJson.encode(pkg))
        assertTrue(result.isValid)
        assertEquals(listOf("active_profile_missing:nope"), result.warnings)
        assertTrue(result.hasWarnings)
    }

    // ---------- 拼包（toJson 键序与键集） ----------

    @Test
    fun `built package json round-trips through validation`() {
        // [Dart抄录] transfer_package.dart:285-312（toJson 键序）+ :85-124 往返
        val json = buildTransferPackageJson(
            packageId = " transfer-build-1 ",
            scope = TransferScope.SELECTED_COURSES,
            exportedAtIso = "2026-04-01T08:00:00.000",
            channel = TransferChannel.QR,
            profileName = "大二下",
            currentWeek = 5,
            coursesJson = listOf(courseJson()),
        )
        assertEquals("transfer-build-1", json["packageId"]) // 构造器 packageId.trim()
        // 键序：app / packageType / schemaVersion 打头（Dart toJson 字面量序）
        assertEquals(listOf("app", "packageType", "schemaVersion"), json.keys.take(3).toList())
        assertEquals(1, json["schemaVersion"])
        assertFalse(json.containsKey("backupType")) // 非 full 不写

        val result = validateTransferPackageJson(MiniJson.encode(json))
        assertTrue(result.errors.toString(), result.isValid)
    }

    @Test
    fun `built full backup writes backupType and lists stay present when empty`() {
        // [Dart推演] toJson：if (isFullBackup) 'backupType'；八张列表键恒定输出
        val json = buildTransferPackageJson(
            packageId = "p",
            scope = TransferScope.ALL_DATA,
            exportedAtIso = "2026-04-01T08:00:00.000",
            isFullBackup = true,
        )
        assertEquals("full", json["backupType"])
        assertEquals(emptyList<Any?>(), json["courses"])
        assertEquals(emptyList<Any?>(), json["profiles"])
    }

    // ---------- 必填表本身的形状（防止移植时抄错表） ----------

    @Test
    fun `required tables mirror dart source verbatim`() {
        // [Dart抄录] transfer_package.dart:108-117 / 119-184 逐键对照
        assertEquals(
            linkedMapOf(
                "courses" to "course", "tasks" to "task", "scheduleItems" to "schedule_item",
                "exams" to "exam", "timeSchemes" to "time_scheme", "scheduleDateRules" to "time_rule",
                "locationTimeGroups" to "location_group", "profiles" to "profile",
            ),
            TRANSFER_REQUIRED_LIST_KINDS,
        )
        assertEquals(
            listOf("id", "name", "teacher", "location", "dayOfWeek", "startSection",
                "endSection", "startTime", "endTime"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["course"],
        )
        assertEquals(
            listOf("id", "title", "createdAt", "updatedAt"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["task"],
        )
        assertEquals(
            listOf("id", "title", "startDate", "endDate", "startTime", "endTime",
                "createdAt", "updatedAt", "recurrence", "exceptionDates", "enabled"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["schedule_item"],
        )
        assertEquals(
            listOf("id", "courseId", "name", "dateTime", "startTime", "endTime",
                "createdAt", "updatedAt"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["exam"],
        )
        assertEquals(
            listOf("id", "name", "sections", "createdAt", "updatedAt"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["time_scheme"],
        )
        assertEquals(
            listOf("id", "name", "timeSchemeId", "enabled", "startDate", "endDate"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["time_rule"],
        )
        assertEquals(
            listOf("id", "name", "timeSchemeId", "enabled", "priority", "keywords"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["location_group"],
        )
        assertEquals(
            listOf("id", "name", "courses", "tasks", "scheduleItems", "exams", "settings",
                "currentWeek", "createdAt", "lastUsedAt"),
            TRANSFER_REQUIRED_ENTITY_FIELDS["profile"],
        )
    }

    @Test
    fun `validateJson never throws on hostile input`() {
        // [Dart抄录] transfer_package.dart:456-468（validateJson 吞一切异常，只回错误码）
        assertEquals(
            "transfer_package_json_invalid",
            validateTransferPackageJson("").errors.single(),
        )
        assertEquals(
            "transfer_package_json_invalid",
            validateTransferPackageJson("{\"app\":").errors.single(),
        )
        // 深嵌套也不崩（MiniJson 递归解析）
        val deep = "[".repeat(64) + "]".repeat(64)
        assertFalse(validateTransferPackageJson(deep).isValid)
    }
}
