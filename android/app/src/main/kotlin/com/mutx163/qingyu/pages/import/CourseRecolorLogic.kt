package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.course.buildSharedCourseNameKey
import java.time.LocalDateTime
import kotlin.random.Random

/**
 * 「课表重新配色」的纯逻辑层：配色方案、原色快照与方案历史。
 *
 * 移植自 Dart `lib/utils/course_recolor.dart` + `lib/services/course_recolor_history_service.dart`
 * （去 Flutter 化 P4-C 时随 Dart 层一起删除，这里补回 Compose 侧唯一实现）。
 *
 * ## 三条必须守住的口径
 *
 * 1. **同名同色**：分组键按共享课程名（[buildCourseRecolorGroupKey]），与课程组编辑同口径；
 *    重刷必须维持「一门课的所有课次颜色一致」，不能沿用导入期的 name+teacher 键。
 * 2. **确定性重放**：一套方案只存随机种子 + 色组 + 文字色开关，同一份课程列表重放
 *    得到逐色一致的结果——这是「上一套 / 下一套」能往返的基础。注意：Dart 与 Kotlin 的
 *    伪随机算法不同，Dart 时期存下的种子在 Kotlin 侧重放会得到另一套颜色；首次换色时
 *    写入的原色快照不受影响（快照存的是逐组颜色本身）。
 * 3. **永远有路可回**：首次换色前先把当前（导入原）颜色存成快照，历史里没有该档案的记录
 *    时也能回到原样。快照里没有的组（刷色后才加的课）保持原色不动。
 *
 * 本文件只依赖 `core` / `course` / `pages.import` 与 [KeyValueStore]，不碰 Compose / Android，
 * 因此可以直接跑 L0 单测。
 */

/** 重刷配色的分组键：按共享课程名（与课程组编辑页同口径）。 */
fun buildCourseRecolorGroupKey(course: Course): String =
    "name\u0000${buildSharedCourseNameKey(course.name)}"

/** 一组（同名课程）在快照记录里的颜色。 */
data class CourseRecolorSnapshotEntry(
    val color: String,
    val textColor: String? = null,
) {

    fun toJson(): Map<String, Any?> = mapOf("color" to color, "text" to textColor)

    companion object {

        /**
         * 坏数据（color 缺失 / 为空 / 非字符串）返回 null，由调用方丢弃该条。
         *
         * 与 Dart 同口径：这里**不兜底默认蓝**——损坏记录会被渲染成错误颜色，
         * 而类型垃圾若抛出去会让整份历史被服务整体 catch 后静默清空。
         */
        fun fromJson(json: Map<*, *>): CourseRecolorSnapshotEntry? {
            val color = json["color"] as? String ?: return null
            if (color.isEmpty()) return null
            val text = json["text"]
            return CourseRecolorSnapshotEntry(
                color = color,
                textColor = text as? String,
            )
        }
    }
}

/**
 * 一套已应用的配色方案，供「上一套 / 下一套」往返切换。
 *
 * 两类记录：
 * - [Seed]：记种子 + 当时色组 + 文字色开关，同一课程列表下重放即逐色还原；
 * - [Snapshot]：逐组保存刷色前的颜色与文字色，用于回到导入 / 刷色前的原样
 *   （含手工挑过的颜色）。
 */
sealed class CourseRecolorScheme {

    abstract val createdAt: LocalDateTime

    data class Seed(
        val seed: Int,
        val colorGroupId: String,
        val assignMatchingTextColor: Boolean,
        override val createdAt: LocalDateTime,
    ) : CourseRecolorScheme()

    data class Snapshot(
        val entries: Map<String, CourseRecolorSnapshotEntry>,
        override val createdAt: LocalDateTime,
    ) : CourseRecolorScheme()

    fun toJson(): Map<String, Any?> = when (this) {
        is Snapshot -> mapOf(
            "createdAt" to createdAt.toString(),
            "snapshot" to entries.mapValues { (_, entry) -> entry.toJson() },
        )

        is Seed -> mapOf(
            "createdAt" to createdAt.toString(),
            "seed" to seed,
            "colorGroupId" to colorGroupId,
            "assignMatchingTextColor" to assignMatchingTextColor,
        )
    }

    companion object {

        /** 坏数据（缺字段 / 类型不符）返回 null，由调用方丢弃该条。 */
        fun fromJson(raw: Any?): CourseRecolorScheme? {
            val json = raw as? Map<*, *> ?: return null
            val createdAt = (json["createdAt"] as? String)
                ?.let { runCatching { LocalDateTime.parse(it) }.getOrNull() }
                ?: return null

            val snapshotRaw = json["snapshot"]
            if (snapshotRaw is Map<*, *>) {
                val entries = LinkedHashMap<String, CourseRecolorSnapshotEntry>()
                snapshotRaw.forEach { (key, value) ->
                    if (key is String && value is Map<*, *>) {
                        CourseRecolorSnapshotEntry.fromJson(value)?.let { entries[key] = it }
                    }
                }
                return Snapshot(entries = entries, createdAt = createdAt)
            }

            val seed = (json["seed"] as? Number)?.toInt() ?: return null
            // colorGroupId / assignMatchingTextColor 与 snapshot 条目同口径：类型垃圾整条丢弃，
            // 字段缺失仍兜底默认值。裸 cast 抛出的异常会被历史服务的整体 catch 吞掉，
            // 一条坏记录就会静默清空全部历史。
            val colorGroupId = json["colorGroupId"]
            val assignMatchingTextColor = json["assignMatchingTextColor"]
            if (colorGroupId != null && colorGroupId !is String) return null
            if (assignMatchingTextColor != null && assignMatchingTextColor !is Boolean) return null
            return Seed(
                seed = seed,
                colorGroupId = colorGroupId ?: ImportSharedModel.COURSE_COLOR_GROUP_ALL_ID,
                assignMatchingTextColor = assignMatchingTextColor ?: false,
                createdAt = createdAt,
            )
        }
    }
}

/** 按固定种子对整份课表重刷随机配色（与导入随机配色同一算法与色板）。 */
fun applySeedCourseRecolor(
    courses: List<Course>,
    seed: Int,
    colorGroupId: String,
    assignMatchingTextColor: Boolean,
): List<Course> = ImportSharedModel.applyRandomImportCourseColors(
    courses = courses,
    palette = ImportSharedModel.courseColorGroupPalette(colorGroupId),
    assignMatchingTextColor = assignMatchingTextColor,
    random = Random(seed),
    groupKeyBuilder = ::buildCourseRecolorGroupKey,
)

/** 捕获当前整份课表的颜色快照（逐组 color / textColor，同名组以首条为准）。 */
fun captureCourseRecolorSnapshot(
    courses: List<Course>,
    now: LocalDateTime = LocalDateTime.now(),
): CourseRecolorScheme.Snapshot {
    val entries = LinkedHashMap<String, CourseRecolorSnapshotEntry>()
    for (course in courses) {
        entries.putIfAbsent(
            buildCourseRecolorGroupKey(course),
            CourseRecolorSnapshotEntry(color = course.color, textColor = course.textColor),
        )
    }
    return CourseRecolorScheme.Snapshot(entries = entries, createdAt = now)
}

/**
 * 把 [scheme] 应用到当前课程列表，返回重刷后的课程副本。
 *
 * 快照记录里没有的组（刷色后才加的课程）保持原色不动。
 */
fun applyCourseRecolorScheme(courses: List<Course>, scheme: CourseRecolorScheme): List<Course> =
    when (scheme) {
        is CourseRecolorScheme.Snapshot -> courses.map { course ->
            val entry = scheme.entries[buildCourseRecolorGroupKey(course)]
            if (entry == null) {
                course
            } else {
                course.copy(color = entry.color, textColor = entry.textColor)
            }
        }

        is CourseRecolorScheme.Seed -> applySeedCourseRecolor(
            courses = courses,
            seed = scheme.seed,
            colorGroupId = scheme.colorGroupId,
            assignMatchingTextColor = scheme.assignMatchingTextColor,
        )
    }

/** 配色历史 + 当前指向的下标。 */
data class CourseRecolorHistoryState(
    val schemes: List<CourseRecolorScheme> = emptyList(),
    /** 当前指向 [schemes] 的下标；-1 表示尚无历史。 */
    val index: Int = -1,
) {

    val isEmpty: Boolean get() = schemes.isEmpty()

    val canGoBack: Boolean get() = index > 0

    val canGoForward: Boolean get() = index >= 0 && index < schemes.size - 1

    val current: CourseRecolorScheme? get() = schemes.getOrNull(index)
}

/**
 * 「课表重新配色」的方案历史持久化。
 *
 * 只存方案记录（随机种子或颜色快照），不存课程数据本身；当前指向哪一套（导航位置）
 * 一并持久化，弹层重开后才能继续往返。历史按课表 profile 作用域隔离——不同课表
 * 互不串色。键名与 Dart 逐字对齐，老用户的配色历史不会因为换实现而丢。
 *
 * 写完**回读校验**：`KeyValueStore.putString` 是 `Unit`，不认账也看不出来；回读不一致
 * 就返回 false，让弹层提示「保存失败」而不是假装成功。
 */
class CourseRecolorHistoryStore(private val store: KeyValueStore) {

    fun schemesKey(scope: String): String = "$SCHEMES_KEY_PREFIX$scope"

    fun indexKey(scope: String): String = "$INDEX_KEY_PREFIX$scope"

    fun load(scope: String): CourseRecolorHistoryState {
        val schemes = loadSchemes(schemesKey(scope))
        if (schemes.isEmpty()) return CourseRecolorHistoryState()

        val rawIndex = store.getInt(indexKey(scope), -1)
        // 旧数据 / 坏数据没有有效指向时，当前观感大概率就是最后一套。
        val index = if (rawIndex < 0) schemes.size - 1 else rawIndex
        return CourseRecolorHistoryState(
            schemes = schemes,
            index = index.coerceIn(0, schemes.size - 1),
        )
    }

    /** 保存历史与指向；超过 [MAX_SCHEMES] 时丢最旧记录并同步前移指向。 */
    fun save(scope: String, schemes: List<CourseRecolorScheme>, index: Int): Boolean {
        if (schemes.isEmpty()) {
            store.remove(schemesKey(scope))
            store.remove(indexKey(scope))
            return true
        }

        var bounded = schemes
        var boundedIndex = index
        if (schemes.size > MAX_SCHEMES) {
            val dropCount = schemes.size - MAX_SCHEMES
            bounded = schemes.subList(dropCount, schemes.size).toList()
            boundedIndex = (index - dropCount).coerceIn(0, bounded.size - 1)
        }

        val encoded = MiniJson.encode(bounded.map { it.toJson() })
        val schemesKey = schemesKey(scope)
        val indexKey = indexKey(scope)
        store.putString(schemesKey, encoded)
        store.putInt(indexKey, boundedIndex)
        return store.getString(schemesKey) == encoded &&
            store.getInt(indexKey, Int.MIN_VALUE) == boundedIndex
    }

    private fun loadSchemes(key: String): List<CourseRecolorScheme> {
        val raw = store.getString(key)
        if (raw.isNullOrEmpty()) return emptyList()
        val decoded = runCatching { MiniJson.tryParse(raw) }.getOrNull() as? List<*> ?: return emptyList()
        return decoded.mapNotNull { CourseRecolorScheme.fromJson(it) }
    }

    companion object {

        /** 与 Dart 的 `course_recolor_history_v1:` 前缀逐字一致。 */
        const val SCHEMES_KEY_PREFIX = "course_recolor_history_v1:"

        /** 与 Dart 的 `course_recolor_history_index_v1:` 前缀逐字一致。 */
        const val INDEX_KEY_PREFIX = "course_recolor_history_index_v1:"

        /** 历史上限：超过时丢最旧的记录（包括最旧的导入原色快照）。 */
        const val MAX_SCHEMES = 20
    }
}
