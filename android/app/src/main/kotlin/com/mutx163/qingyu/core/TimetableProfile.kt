package com.mutx163.qingyu.core

import java.time.LocalDateTime

/**
 * 课表档案（移植自 lib/models/timetable_profile.dart）。
 *
 * ## 解析口径（与 Dart 逐条一致，且与 Course **刻意相反**）
 *
 * - `id` 必须是真字符串，**缺失/类型不对一律拒收**（FormatException）——
 *   一份课表 = 课 + 考试 + 作业 + 设置，静默丢掉整档比拒收整份危险得多
 *   （full_backup_profile_salvage_test.dart:72 钉着这条）。
 * - name 类型不对 → 退回「未命名课表」（这条是宽松的）。
 * - 列表类条目逐条 try，坏的丢弃计数（lenient 路径），不让单条坏数据炸整份。
 * - currentWeek：lenientInt ?: 1，先 clamp(1, 30)，再按 semesterWeekCount 钳制。
 * - profileKind：lenientString 再 fromValue，非法名回落 normal。
 *
 * ## 模型边界（本族裁定）
 *
 * tasks/scheduleItems/exams 的 JSON 解析已随本族模型一并移植（三者是 profile
 * 的一等字段，序列化契约不可拆）；settings 只含时间/周次核心四键（见
 * [TimetableSettings] 头注释）——**整体设置合并/回写语义由设置族补齐**。
 */
enum class TimetableProfileKind(val value: String) {
    NORMAL("normal"),
    PARTNER_IMPORTED("partnerImported");

    companion object {
        /** 未知值回落 normal（timetable_profile.dart:19-25）。 */
        fun fromValue(value: String?): TimetableProfileKind =
            entries.firstOrNull { it.value == value } ?: NORMAL
    }
}

/** Dart clampCurrentWeekToSettings（timetable_profile.dart:27-38）。 */
fun clampCurrentWeekToSettings(week: Long, settings: TimetableSettings): Long {
    val maxWeek = if (settings.semesterWeekCount < 1) 1 else settings.semesterWeekCount
    if (week < 1) return 1
    if (week > maxWeek) return maxWeek.toLong()
    return week
}

data class TimetableProfile(
    val id: String,
    val name: String,
    val courses: List<Course> = emptyList(),
    val tasks: List<CourseTask> = emptyList(),
    val scheduleItems: List<ScheduleItem> = emptyList(),
    val exams: List<Exam> = emptyList(),
    val settings: TimetableSettings = TimetableSettings.defaults(),
    val currentWeek: Long,
    val createdAt: LocalDateTime,
    val lastUsedAt: LocalDateTime,
    val profileKind: TimetableProfileKind = TimetableProfileKind.NORMAL,
) {
    val isPartnerImported: Boolean get() = profileKind == TimetableProfileKind.PARTNER_IMPORTED

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "courses" to courses.map { it.toJson() },
        "tasks" to tasks.map { it.toJson() },
        "scheduleItems" to scheduleItems.map { it.toJson() },
        "exams" to exams.map { it.toJson() },
        "settings" to settings.toJson(),
        "currentWeek" to currentWeek,
        "createdAt" to DartTime.toIso(createdAt),
        "lastUsedAt" to DartTime.toIso(lastUsedAt),
        "profileKind" to profileKind.value,
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        const val UNNAMED = "未命名课表"

        /** 留档容量上限：条数 / 单条字符数（timetable_profile.dart:297-298）。 */
        const val MAX_QUARANTINED_ITEMS = 50
        const val MAX_QUARANTINED_ITEM_CHARS = 4096

        /** Dart fromJson（timetable_profile.dart:86-148）：id 拒收、其余宽松。 */
        fun fromJson(json: Map<String, Any?>): TimetableProfile {
            val rawSettings = json["settings"]
            val settings = if (rawSettings is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                TimetableSettings.fromJson(rawSettings as Map<String, Any?>)
            } else {
                TimetableSettings.defaults()
            }

            // id：真字符串才收，数字/缺失同一条拒收路径（profile_id_invalid）。
            val id = json["id"]
            if (id !is String) {
                throw DartFormatException("profile_id_invalid")
            }

            return TimetableProfile(
                id = id,
                name = if (json["name"] is String) json["name"] as String else UNNAMED,
                courses = parseListLenient(json["courses"]) { Course.fromJson(it) },
                tasks = parseListLenient(json["tasks"]) { CourseTask.fromJson(it) },
                scheduleItems = parseListLenient(json["scheduleItems"]) { ScheduleItem.fromJson(it) },
                exams = parseListLenient(json["exams"]) { Exam.fromJson(it) },
                settings = settings,
                // (lenientInt ?? 1).clamp(1, 30) 再按 semesterWeekCount 钳。
                currentWeek = clampCurrentWeekToSettings(
                    (LenientJson.int(json["currentWeek"]) ?: 1L).coerceIn(1L, 30L),
                    settings,
                ),
                createdAt = DartTime.tryParseIso(json["createdAt"]?.toString())
                    ?: LocalDateTime.now(),
                lastUsedAt = DartTime.tryParseIso(json["lastUsedAt"]?.toString())
                    ?: LocalDateTime.now(),
                profileKind = TimetableProfileKind.fromValue(LenientJson.string(json["profileKind"])),
            )
        }

        fun fromJsonString(text: String): TimetableProfile {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("profile json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }

        /**
         * Dart `_parseListLenient`：非 Map 或解析抛错的条目丢弃并留档
         * （quarantine），返回解析成功的条目列表。
         */
        fun <T> parseListLenient(
            rawList: Any?,
            quarantineSink: MutableList<String>? = null,
            parse: (Map<String, Any?>) -> T,
        ): List<T> {
            if (rawList !is List<*>) return emptyList()
            val parsed = mutableListOf<T>()
            for (item in rawList) {
                if (item !is Map<*, *>) {
                    quarantineDroppedItem(quarantineSink, item)
                    continue
                }
                @Suppress("UNCHECKED_CAST")
                val map = item as Map<String, Any?>
                try {
                    parsed.add(parse(map))
                } catch (_: Exception) {
                    // 存档原始字节：丢弃可能只是「当前版本的解析器读不懂」，
                    // 用户数据不该因此永久消失。
                    quarantineDroppedItem(quarantineSink, item)
                }
            }
            return parsed
        }

        /** 被丢弃条目编码进 [sink]，上限防畸形数据撑爆留档。 */
        fun quarantineDroppedItem(sink: MutableList<String>?, item: Any?) {
            if (sink == null || sink.size >= MAX_QUARANTINED_ITEMS) return
            val encoded = try {
                MiniJson.encode(item)
            } catch (_: Exception) {
                "\"${item.toString()}\""
            }
            sink.add(
                if (encoded.length > MAX_QUARANTINED_ITEM_CHARS) {
                    encoded.substring(0, MAX_QUARANTINED_ITEM_CHARS) + "…(截断)"
                } else {
                    encoded
                },
            )
        }

        /** 解析 stats（timetable_profile.dart:330-370）。 */
        class ParseStats {
            var droppedProfiles: Int = 0
            var droppedCourses: Int = 0
            var droppedTasks: Int = 0
            var droppedScheduleItems: Int = 0
            var droppedExams: Int = 0
            var droppedSettings: Int = 0
            val quarantinedItems: MutableList<String> = mutableListOf()

            /**
             * 顶层数组里被整条丢弃的档案下标（升序）。存储层据此**按原始字节**
             * 切除坏记录后写回，其余档案字节不动（见 [TimetableStore.loadProfiles]）。
             */
            val droppedProfileIndices: MutableList<Int> = mutableListOf()

            val hasItemLevelDrops: Boolean
                get() = droppedCourses > 0 || droppedTasks > 0 || droppedScheduleItems > 0 ||
                    droppedExams > 0 || droppedSettings > 0

            val hasProfileLevelDrops: Boolean get() = droppedProfiles > 0

            val didDrop: Boolean
                get() = hasProfileLevelDrops || hasItemLevelDrops

            val totalDropped: Int
                get() = droppedProfiles + droppedCourses + droppedTasks +
                    droppedScheduleItems + droppedExams + droppedSettings
        }

        class ProfilesParseResult(
            val profiles: List<TimetableProfile>,
            val stats: ParseStats,
        ) {
            val didDrop: Boolean get() = stats.didDrop

            /** 只有条目级损坏（没有整条记录坏掉）——存储层不应把清洗结果写回磁盘。 */
            val hasItemLevelOnlyDrops: Boolean
                get() = stats.hasItemLevelDrops && !stats.hasProfileLevelDrops

            val quarantinedItems: List<String> get() = stats.quarantinedItems

            val droppedProfileIndices: List<Int> get() = stats.droppedProfileIndices
        }

        /**
         * 解析 profiles JSON 列表，跳过坏 profile/条目而不是清空
         * （timetable_profile.dart:224-248）。settings 解析失败 → 整份回落
         * defaults 并计 droppedSettings（fromJsonLenient 的口径）。
         */
        fun parseProfilesPayload(rawProfiles: List<*>): ProfilesParseResult {
            val stats = ParseStats()
            val profiles = mutableListOf<TimetableProfile>()
            for ((index, item) in rawProfiles.withIndex()) {
                if (item !is Map<*, *>) {
                    stats.droppedProfiles++
                    stats.droppedProfileIndices.add(index)
                    quarantineDroppedItem(stats.quarantinedItems, item)
                    continue
                }
                try {
                    @Suppress("UNCHECKED_CAST")
                    profiles.add(
                        fromJsonLenient(item as Map<String, Any?>, stats),
                    )
                } catch (_: Exception) {
                    stats.droppedProfiles++
                    stats.droppedProfileIndices.add(index)
                    quarantineDroppedItem(stats.quarantinedItems, item)
                }
            }
            return ProfilesParseResult(profiles, stats)
        }

        /**
         * Dart fromJsonLenient（timetable_profile.dart:151-221）：坏条目跳过计数，
         * id 缺失/空白抛 profile_id_required。
         */
        fun fromJsonLenient(json: Map<String, Any?>, stats: ParseStats? = null): TimetableProfile {
            val rawSettings = json["settings"]
            val settings: TimetableSettings = if (rawSettings is Map<*, *>) {
                try {
                    @Suppress("UNCHECKED_CAST")
                    TimetableSettings.fromJson(rawSettings as Map<String, Any?>)
                } catch (_: Exception) {
                    // 整份设置被回落成默认值同样是「条目级」损失：留档原始那份。
                    if (stats != null) stats.droppedSettings++
                    TimetableProfile.quarantineDroppedItem(stats?.quarantinedItems, rawSettings)
                    TimetableSettings.defaults()
                }
            } else {
                // Dart 口径：rawSettings 非 Map（或缺失）时直接 defaults()，
                // 不计 droppedSettings、不留档（只有 is Map 但解析抛错才计）。
                TimetableSettings.defaults()
            }

            val id = json["id"]?.toString()
            if (id == null || id.isEmpty()) {
                throw DartFormatException("profile_id_required")
            }

            val courses = parseListLenient(json["courses"], stats?.quarantinedItems) { Course.fromJson(it) }
            val tasks = parseListLenient(json["tasks"], stats?.quarantinedItems) { CourseTask.fromJson(it) }
            val scheduleItems = parseListLenient(json["scheduleItems"], stats?.quarantinedItems) { ScheduleItem.fromJson(it) }
            val exams = parseListLenient(json["exams"], stats?.quarantinedItems) { Exam.fromJson(it) }
            if (stats != null) {
                stats.droppedCourses += countDropped(json["courses"], courses)
                stats.droppedTasks += countDropped(json["tasks"], tasks)
                stats.droppedScheduleItems += countDropped(json["scheduleItems"], scheduleItems)
                stats.droppedExams += countDropped(json["exams"], exams)
            }

            return TimetableProfile(
                id = id,
                name = json["name"]?.toString() ?: UNNAMED,
                courses = courses,
                tasks = tasks,
                scheduleItems = scheduleItems,
                exams = exams,
                settings = settings,
                currentWeek = clampCurrentWeekToSettings(
                    (LenientJson.int(json["currentWeek"]) ?: 1L).coerceIn(1L, 30L),
                    settings,
                ),
                createdAt = DartTime.tryParseIso(json["createdAt"]?.toString())
                    ?: LocalDateTime.now(),
                lastUsedAt = DartTime.tryParseIso(json["lastUsedAt"]?.toString())
                    ?: LocalDateTime.now(),
                profileKind = TimetableProfileKind.fromValue(LenientJson.string(json["profileKind"])),
            )
        }

        /**
         * Dart 侧条目级丢弃计数：`原始 List 长度 - 解析成功数`（非 Map 条目与
         * 解析抛错条目都算，与 onDropped 的调用次数一致）。非 List 输入按 0。
         */
        private fun countDropped(rawList: Any?, parsed: List<*>): Int {
            if (rawList !is List<*>) return 0
            return (rawList.size - parsed.size).coerceAtLeast(0)
        }
    }
}
