package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson

/**
 * 日视图「情侣课表叠加」的数据源（B1 第一阶段，2026-11-06）。
 *
 * **这是纯模型层**：读仓储快照里的 `partner-imported` 档案 + 键值存储里的绑定 JSON，
 * 拼成渲染层要的 [CoupleOverlay]；没有绑定 / 没有对方档 / 绑定值坏 ⇒ 返回 null
 * （调用方按「不叠加」处理，与本页任何旧路径都兼容）。
 *
 * ## 为什么放 `widgetdata` 而不是 `pages/sync` 或 `pages/timetable`
 *
 * 它的两头分属两域：绑定模型在 `pages/sync`，消费方 `DayViewDataAssembler` 在
 * `pages/timetable`——而 L0 模块 classpath 里 `pages/timetable` **不含** `pages/sync`，
 * 直接引用会把两条 L0 一起锁死。`widgetdata` 是共享模型目录（`test-kotlin-module.ps1`
 * 的 `$sharedModelDirs`），两侧都能收；本仓小组件的合并内核（`CoupleTimetableData`）
 * 本来就住这里，同一族数据源放同目录。
 *
 * ## 为什么不用 `pages/sync` 的 `PartnerTimetableBindingModel` / `CoupleBindingCodec`
 *
 * 两个原因，都写在 2026-11-06 的 B1 方案里：
 * 1. **L0 依赖方向**：`pages/timetable` 的 L0 收不了 `pages/sync`（脚本按模块隔离），
 *    本源要是引了那边，timetable 的 L0 就得靠一串 ExtraSources 顶着——闭链上任何
 *    文件动一下，整模块自测通道跟着红。本源只引 `core`（`MiniJson` / 课程与档案模型），
 *    解码口径抄 `CoupleBindingCodec.fromJson`（宽松取值、坏值回落默认，不抛）。
 * 2. **只读、无副作用**：`platform/CouplePartnerPortImpl.loadBinding` 对坏值会
 *    archive+remove（写副作用），这里是装配只读层，坏值按「没有绑定」返回 null、不动盘。
 *
 * 键名 `partner_timetable_binding`（Dart `storage_service.dart:38`）在本文件内单点声明；
 * 与 `pages/sync/CoupleStores.kt` 的 `CouplePartnerStorage.BINDING_KEY` 的同值一致性由
 * `pages/timetable` 的 `CouplePartnerBindingKeyGuardTest` 家族（文本守卫）钉住。
 */
object CoupleOverlaySource {

    /** 绑定键（同值一致性由文本守卫钉住，见类 KDoc）。 */
    const val BINDING_KEY: String = "partner_timetable_binding"

    /**
     * 从仓储装配叠加数据。
     *
     * @return null = 不叠加：没有绑定、绑定 JSON 解不开、没有 `partner-imported` 档案，
     *   或那份档案里一门课都没有（叠加空表没有意义，走了也是旧渲染）。
     */
    fun load(repository: TimetableRepository): CoupleOverlay? {
        val binding = parseBinding(repository.rawStoredJson(BINDING_KEY)) ?: return null
        val snapshot = repository.snapshot
        val partnerCourses = snapshot.profiles
            .firstOrNull { it.isPartnerImported }
            ?.courses
            .orEmpty()
        if (partnerCourses.isEmpty()) return null
        return CoupleOverlay(
            weekOffset = binding.weekOffset,
            mineColorHex = binding.mineColorHex,
            partnerColorHex = binding.partnerColorHex,
            togetherColorHex = binding.togetherColorHex,
            partnerCourses = partnerCourses,
        )
    }

    /**
     * 绑定 JSON → 叠加参数（宽松口径抄 `CoupleBindingCodec.fromJson`：字符串项
     * 非字符串时 `toString` 兜底、周偏移钳制 ±15、缺项回落默认色）。null = 没有值
     * 或根本不是 JSON 对象（与 `CoupleBindingCodec.parse` 的「未绑定」判定一致）。
     */
    private fun parseBinding(raw: String?): CoupleOverlayBinding? {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return null
        val decoded = MiniJson.tryParse(text)
        if (decoded !is Map<*, *>) return null

        fun readStr(key: String, fallback: String): String {
            val value = decoded[key] ?: return fallback
            return if (value is String) value else value.toString()
        }

        return CoupleOverlayBinding(
            weekOffset = ((decoded["weekOffset"] as? Number)?.toInt() ?: 0)
                .coerceIn(PartnerTimetableBinding.MIN_WEEK_OFFSET, PartnerTimetableBinding.MAX_WEEK_OFFSET),
            mineColorHex = readStr("mineColorHex", PartnerTimetableBinding.MINE_COLOR_DEFAULT),
            partnerColorHex = readStr("partnerColorHex", PartnerTimetableBinding.PARTNER_COLOR_DEFAULT),
            togetherColorHex = readStr("togetherColorHex", PartnerTimetableBinding.TOGETHER_COLOR_DEFAULT),
        )
    }
}

/** 绑定里叠加渲染要的三个数（周偏移 + 情侣三色）。 */
internal data class CoupleOverlayBinding(
    val weekOffset: Int,
    val mineColorHex: String,
    val partnerColorHex: String,
    val togetherColorHex: String,
)

/**
 * 日视图叠加渲染要的一切（绑定参数 + 对方课表），一次装配、按值传递。
 *
 * [weekOffset] 交给合并内核（`coupleMergedDayCoursesTagged` 的 `partnerWeekOffset`），
 * 装配层不做周次换算——钳制与「我的第 N 周 ↔ TA 的第几周」都在内核里。
 */
data class CoupleOverlay(
    /** 对方周次偏移（绑定原值；钳制由合并内核负责，这里不重复做）。 */
    val weekOffset: Int,
    val mineColorHex: String,
    val partnerColorHex: String,
    val togetherColorHex: String,
    /** `partner-imported` 档案里的全部课程（按周过滤仍由合并内核做）。 */
    val partnerCourses: List<Course>,
)
