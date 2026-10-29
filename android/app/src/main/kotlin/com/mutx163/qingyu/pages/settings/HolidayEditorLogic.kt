package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayType
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.YearMonth

/**
 * 「节假日标记」两页里**能脱离界面判定**的那部分行为，纯 Kotlin、零 Android/Compose 依赖。
 *
 * 页面结构（三区块 + 高级页日志）由 [SettingsHolidayPage.spec] / [SettingsHolidayAdvancedPage.spec]
 * 给；本对象只管「弹层里点了保存会得到什么」与「某个 rowId 对应哪个假期组」，
 * 于是宿主（composeP1 的 `SettingsHolidayHost`）只负责弹层与调 provider，
 * 取舍全在这里，JVM 单测能把 Dart 侧几条**容易漏掉的分支**钉住。
 *
 * | 分支 | Dart 出处 |
 * |---|---|
 * | 名字 trim 后为空 ⇒ 不保存、不关弹层 | `settings_holiday.dart:120-127` |
 * | 改开始日期后，结束日期早于它就跟到同一天 | `:179-183` |
 * | 保存按天展开成一条一条 `HolidayEntry`（含跨月/跨年） | `:278-291` |
 * | 新增用 `custom-<epochMillis>`，编辑沿用原 groupId | `:274-275` |
 * | 编辑＝「同组旧条目整体替换」，其余组原样保留 | `holiday_service.dart:705-714` |
 * | 自定义假期按 groupId 归并、组内按日期升序、取首条作 existing | `:396-412` + `:556-566` |
 *
 * ## 为什么写盘不在这里
 *
 * 真正的写盘入口是 `HolidayProvider`（`addCustomHolidays` / `updateCustomHoliday` /
 * `removeCustomHoliday`），单一写入者。本对象的 [replaceGroup] 是那次写入的**可执行规格**：
 * 数据层改语义时这条单测会先红，不必等真机。宿主**不要**自己拿 [replaceGroup] 的结果去写盘，
 * 否则同一份状态会有两个写者。
 *
 * ## 行 id 约定（与模型泳道保持一致，改一处就要两边一起改）
 *
 * 模型侧 `SettingsHolidayPage.customHolidayRows` 生成的行 id 是
 * `holiday.custom.<groupId>`（`settings_holiday.dart:541` 的 `_groupCustomHolidays()` 顺序），
 * 空态 / 损坏态分别是 `holiday.customEmpty` / `holiday.customCorrupted`
 * （**故意不带尾点**，所以前缀判断不会把它们误判成自定义假期行）。
 */
object HolidayEditorLogic {

    /** 总开关行（`settings_holiday.dart:508-516`）。 */
    const val ROW_ENABLE = "holiday.enable"

    /** 「添加假期」按钮（`:576-592`）。 */
    const val ROW_ADD = "holiday.card.add"

    /** 自定义假期行的 id 前缀（`:541-571`，逐条）。 */
    const val CUSTOM_ROW_PREFIX = "holiday.custom."

    /** 自定义假期空态行（`:534-539`）。 */
    const val ROW_CUSTOM_EMPTY = "holiday.customEmpty"

    /** 自定义假期损坏态行（`:528-533`）。 */
    const val ROW_CUSTOM_CORRUPTED = "holiday.customCorrupted"

    /**
     * 长按自定义假期行时的**动作值**（`:568-570` 的 `onLongPress`）。
     *
     * 点按与长按在渲染层最终都汇进同一个 `onAction(action, target, rowId)`，
     * rowId 也一样（都是 `holiday.custom.<groupId>`），唯一的区分维度是 `action`：
     * 点按是 `SHEET`（编辑），长按是 `DIALOG`（删除确认）。模型泳道按此约定在
     * `SettingsHolidayPage.customHolidayRows` 里填 `longPressAction = DIALOG`，
     * 与 Lead 2026-10-29 的对表结论一致。
     *
     * ⚠️ 这里的 `DIALOG` **不是** OverlayDialog 的字面语义，只是「删除确认」这个界面意图的载体；
     * 宿主收到它时弹的仍是 `OverlayBottomSheet`（与 Dart 的 `showHyperosSheet` 同形）。
     */
    val DELETE_CONFIRM_ACTION = SettingsAction.DIALOG

    /** groupId 为 null 的条目在界面上归到 `ungrouped` 这一桶（`:399` `entry.groupId ?? 'ungrouped'`）。 */
    const val UNGROUPED_GROUP_ID = "ungrouped"

    /** 高级页路由（[SettingsHolidayPage.ROUTE_ADVANCED] 的别名，宿主少引一个对象）。 */
    const val ROUTE_ADVANCED = SettingsHolidayPage.ROUTE_ADVANCED

    /** 日期弹层下界（Dart `firstDate: DateTime(now.year - 1)`，`:175`）。 */
    const val PICKER_MIN_YEAR_OFFSET = -1

    /** 日期弹层上界（Dart `lastDate: DateTime(now.year + 2)`，`:176`）。 */
    const val PICKER_MAX_YEAR_OFFSET = 2

    // ---------------------------------------------------------------- 校验

    /**
     * 假期名校验（Dart `:120-127`：`nameController.text.trim().isEmpty` ⇒ 提示「请输入假期名称」）。
     *
     * 返回 trim 后的名字；空白（含全角空格、制表符、换行）⇒ null，宿主据此弹 Toast 且**不关弹层**。
     * 注意 Dart 侧只拦「空」，不拦长度——2026-10-29 审核确认没有长度上限，这里也不擅自加。
     */
    fun validateName(raw: String): String? = raw.trim().ifEmpty { null }

    // ---------------------------------------------------------------- groupId

    /**
     * 新增假期组的 id（Dart `:274-275` `'custom-${DateTime.now().millisecondsSinceEpoch}'`）。
     *
     * [nowMillis] 由宿主传 `System.currentTimeMillis()`，不在这里取时钟——单测要能钉死值。
     * 编辑路径**不要**调它，沿用 `existing.groupId`（否则一次编辑会变成「新建一组 + 旧组没删」）。
     */
    fun nextGroupId(nowMillis: Long): String = "custom-$nowMillis"

    // ---------------------------------------------------------------- 日期

    /** 只保留年月日、时间归零（Dart `DateTime(d.year, d.month, d.day)`，`:283`）。 */
    fun startOfDay(date: LocalDate): LocalDateTime = LocalDateTime.of(date, LocalTime.MIDNIGHT)

    /**
     * 结束日期跟随开始日期（Dart `:181-183`）：
     * `end == null || end.isBefore(start)` ⇒ `end = start`。
     *
     * 方向是**单向**的：只把 end 往 start 抬，绝不动 start。
     * 结束日期那一栏自己选的时候走 `lastDate: startDate`（`:199`），所以正常操作下选不到更早的日期，
     * 这条是改开始日期之后的兜底。
     */
    fun clampEnd(start: LocalDate, end: LocalDate?): LocalDate =
        if (end == null || end.isBefore(start)) start else end

    /**
     * 日期弹层的可选区间（Dart `:175-176` / `:199-201`）：
     * 下界 = 今天所在年 -1，上界 = 今天所在年 +2。
     *
     * 结束日期那一栏的**下界是开始日期**（`:199` `firstDate: startDate ?? …`），
     * 由 [endPickerRange] 表达，别把两者混成一个。
     */
    fun pickerRange(today: LocalDate): DateRange = DateRange(
        first = LocalDate.of(today.year + PICKER_MIN_YEAR_OFFSET, 1, 1),
        last = LocalDate.of(today.year + PICKER_MAX_YEAR_OFFSET, 12, 31),
    )

    /**
     * 结束日期弹层的区间：下界被开始日期顶起来（Dart `:199` `firstDate: startDate ?? …`）。
     *
     * 开始日期已经比下界还早时（跨年边界：开始日期在去年、今天的 -1 年刚好同年），
     * 保留下界不越过 [pickerRange] 的 first——否则滚轮里会出现「比全表下界更早」的年，
     * 与开始日期那一栏对不上。
     */
    fun endPickerRange(start: LocalDate?, today: LocalDate): DateRange {
        val whole = pickerRange(today)
        val lower = start ?: whole.first
        return if (lower.isBefore(whole.first)) whole else DateRange(lower, whole.last)
    }

    /** 闭区间的两端（`java.time.LocalDate` 不能直接用 Kotlin 的 `..`：它只实现 `Comparable<ChronoLocalDate>`）。 */
    data class DateRange(val first: LocalDate, val last: LocalDate)

    /**
     * 某年某月有多少天：日期滚轮里「日」列的上界。
     *
     * 与 `SemesterSettingsLogic.daysInMonth` 同一个理由：不夹的话「选 1 月 31 日 → 切到 2 月」
     * 会得到一个不存在的日期，确认时 `LocalDate.of` 直接抛。
     */
    fun daysInMonth(year: Int, month: Int): Int = YearMonth.of(year, month).lengthOfMonth()

    /**
     * `yyyy-MM-dd`（Dart `_formatFullDate`，`settings_holiday.dart:655-660`：年补 4 位、月日各补 2 位）。
     *
     * 这个是**行上显示的日期**，不是 ARB 文案（Dart 也是拼字符串，不走 l10n）。
     */
    fun formatDate(date: LocalDate): String =
        "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)

    /**
     * 按天展开成 `HolidayEntry`（Dart `:278-291`）：闭区间，含首含尾。
     *
     * - 跨月 / 跨年天然成立（逐日 `plusDays(1)`，不按「月内第几天」算）；
     * - 闰日 2 月 29 日会正常出现（2024-02-28 ~ 2024-03-01 → 3 条）；
     * - `start > end` ⇒ 空列表。Dart 靠 [clampEnd] 与弹层下界保证不会发生，
     *   这里兜一层是为了「万一发生就什么都别写」，而不是写出一条反向区间。
     *
     * Dart 侧 `date` 是 `DateTime(d.year, d.month, d.day)`（时间归零），这里同样是零点。
     */
    fun expandEntries(
        start: LocalDate,
        end: LocalDate,
        name: String,
        type: HolidayType,
        groupId: String?,
    ): List<HolidayEntry> {
        if (end.isBefore(start)) return emptyList()
        val out = ArrayList<HolidayEntry>()
        var cursor = start
        while (!cursor.isAfter(end)) {
            out.add(
                HolidayEntry(
                    date = startOfDay(cursor),
                    name = name,
                    type = type,
                    groupId = groupId,
                ),
            )
            cursor = cursor.plusDays(1)
        }
        return out
    }

    // ---------------------------------------------------------------- 分组

    /**
     * 一个自定义假期组（Dart `_CustomHolidayGroup`，`:835-849`）。
     *
     * [entries] 已按日期升序；[existing] 是放进编辑弹层的那个「代表条目」（Dart `:560-566`
     * 传 `entries.first`），起止日期取组内最早/最晚（`:407-409`）。
     */
    data class CustomHolidayGroup(
        /** 组 id；null groupId 的条目归到 [UNGROUPED_GROUP_ID]。 */
        val groupId: String,
        /** 组内条目，按日期升序。 */
        val entries: List<HolidayEntry>,
    ) {
        /** 编辑弹层的 `existing`（首条）；组空则为 null（调用方不该走到这里）。 */
        val existing: HolidayEntry? get() = entries.firstOrNull()

        /** 组内第一条的日期。 */
        val startDate: LocalDate? get() = entries.firstOrNull()?.date?.toLocalDate()

        /** 组内最后一条的日期。 */
        val endDate: LocalDate? get() = entries.lastOrNull()?.date?.toLocalDate()

        /** 组名取首条（Dart `:406` `e.value.first.name`；同组条目名本来一致）。 */
        val name: String get() = entries.firstOrNull()?.name.orEmpty()
    }

    /**
     * 在自定义假期列表里找一组（Dart `:396-412` 的归并 + `:556-566` 的点击路径）。
     *
     * [groupId] 传 [UNGROUPED_GROUP_ID] 时匹配 `groupId == null` 的条目——界面上那桶的 id
     * 就是字符串 `ungrouped`（`:399`），不这样处理的话「没有 groupId 的老条目」点了没反应。
     *
     * 组内**按日期升序**（`:403` 的 `sort`）；找不到 ⇒ null。
     */
    fun groupOf(customHolidays: List<HolidayEntry>, groupId: String): CustomHolidayGroup? {
        val wanted: String? = if (groupId == UNGROUPED_GROUP_ID) null else groupId
        val members = customHolidays.filter { it.groupId == wanted }
        if (members.isEmpty()) return null
        return CustomHolidayGroup(
            groupId = groupId,
            entries = members.sortedBy { it.date },
        )
    }

    /**
     * 行 id → 组 id；不是自定义假期行（含空态/损坏态/其它页的行）⇒ null。
     *
     * 空态行是 `holiday.customEmpty`，**不带尾点**，所以 `startsWith("holiday.custom.")` 为 false。
     */
    fun groupIdOfRow(rowId: String): String? =
        if (rowId.startsWith(CUSTOM_ROW_PREFIX)) {
            rowId.removePrefix(CUSTOM_ROW_PREFIX).ifEmpty { null }
        } else {
            null
        }

    // ---------------------------------------------------------------- 写回语义

    /**
     * 编辑保存的列表变换（Dart `holiday_service.dart:705-714` `updateCustomHoliday`）：
     * 先 `removeWhere(groupId == …)` 再 `addAll(newEntries)`。
     *
     * 三点要留意，全是照抄 Dart：
     * 1. **不排序**：新条目接在末尾，顺序留到展示层排（`:402-411` 展示时才 sort）；
     * 2. **不跨组去重**：用户把某天同时划进两个自建假期时，两条都留着（Dart 就是允许的）；
     *    真正的「去重」是**同组旧日期被整体移除**——否则改短区间后会留下旧的尾日；
     * 3. `groupId` 为 null 的桶（老数据）同样可以被整体替换，宿主不要因为 null 就跳过。
     *
     * ⚠️ 宿主不直接调它写盘（见类注释）；它是 [HolidayProvider.updateCustomHoliday] 的可执行规格。
     */
    fun replaceGroup(
        old: List<HolidayEntry>,
        groupId: String?,
        newEntries: List<HolidayEntry>,
    ): List<HolidayEntry> = old.filterNot { it.groupId == groupId } + newEntries

    // ---------------------------------------------------------------- 类型映射

    /**
     * 假期类型 → 页面模型的显示档位。
     *
     * Dart 的编辑器只给两档（`vacation` / `adjustedWorkday`，`:234-247`），页面模型 [HolidayKind]
     * 也只有两档；远端数据里可能出现的 `AdjustedRestday`（调休休息日）在自定义假期里不会存在。
     * 真出现时归到**假期**一档：调休休息日语义是「这天放假」，与 [SettingsHolidayPage.buildPageData]
     * 里私有的 `displayKind`（`AdjustedRestday -> VACATION`）保持同一口径——两处映射必须一致，
     * 否则同一份远端数据在「自定义假期行」与「法定节假日行」上会显示成不同类型。
     */
    fun kindOf(type: HolidayType): HolidayKind = when (type) {
        HolidayType.Vacation, HolidayType.AdjustedRestday -> HolidayKind.VACATION
        HolidayType.AdjustedWorkday -> HolidayKind.ADJUSTED_WORKDAY
    }

    /** 页面模型档位 → 持久化类型（编辑器只会写这两个值）。 */
    fun typeOf(kind: HolidayKind): HolidayType = when (kind) {
        HolidayKind.VACATION -> HolidayType.Vacation
        HolidayKind.ADJUSTED_WORKDAY -> HolidayType.AdjustedWorkday
    }

    /**
     * 编辑弹层打开时的四个初值（Dart `:91-94` + 新增按钮 `:586-589`）。
     *
     * 新增时宿主**必须**显式传今天给起止日期——Dart 那次修复（`:582-589` 注释）记的就是这个坑：
     * 早先直接 tear-off `_showCustomHolidayDialog`，两个日期参数都是 null，
     * 用户只填名字点保存就撞上 `startDate == null` 的静默 return，看起来像按钮坏了。
     */
    fun initialEditorState(
        existingGroup: CustomHolidayGroup?,
        today: LocalDate,
    ): EditorInitialState =
        if (existingGroup == null || existingGroup.existing == null) {
            EditorInitialState(
                existing = null,
                startDate = today,
                endDate = today,
                type = HolidayType.Vacation,
            )
        } else {
            val group = existingGroup
            EditorInitialState(
                existing = group.existing,
                startDate = group.startDate ?: today,
                endDate = group.endDate ?: today,
                type = group.existing?.type ?: HolidayType.Vacation,
            )
        }

    /** 打开编辑/新增弹层时的一组初值（[initialEditorState] 的返回体）。 */
    data class EditorInitialState(
        /** null = 新增；非 null = 编辑（弹层据此显示标题与删除按钮）。 */
        val existing: HolidayEntry?,
        val startDate: LocalDate,
        val endDate: LocalDate,
        val type: HolidayType,
    ) {
        /** 编辑态才有 groupId（新增时保存那一刻才生成 [nextGroupId]）。 */
        val groupId: String? get() = existing?.groupId
    }
}
