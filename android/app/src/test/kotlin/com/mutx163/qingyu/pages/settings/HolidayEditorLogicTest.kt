package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * [HolidayEditorLogic] 的 JVM 单测：钉住 Dart `settings_holiday.dart` 编辑弹层里
 * **人容易漏、机器不会喊**的那几条分支。
 *
 * ## 期望值怎么来的（全部人推，不是从实现里抄）
 *
 * - 跨月：`2026-01-30 ~ 2026-02-02`，1 月 30、31 两天 → 2 月 1、2 两天，**4 条**；
 * - 跨年：`2025-12-30 ~ 2026-01-01`，12 月 30、31 → 1 月 1，**3 条**；
 * - 闰日：2024 是闰年，`2024-02-28 ~ 2024-03-01` = 02-28 / 02-29 / 03-01，**3 条**；
 * - 单日：`X ~ X` 恒为 **1 条**（闭区间，不是空区间）；
 * - 名字：Dart 只判 `trim().isEmpty`（`:120`），所以「两个半角空格」「全角空格」「制表符」
 *   都算空，而 `" 国庆 "` 是合法的、要去掉两侧空格存进 `name`。
 *
 * 期望字面量一律手写日期（不调用被测函数的反函数拼），保证「实现改了、期望不会跟着改」。
 */
class HolidayEditorLogicTest {

    private fun date(text: String): LocalDate = LocalDate.parse(text)

    private fun entry(
        dateText: String,
        name: String = "国庆节",
        type: HolidayType = HolidayType.Vacation,
        groupId: String? = "custom-1",
    ): HolidayEntry = HolidayEntry(
        date = LocalDateTime.parse("${dateText}T00:00"),
        name = name,
        type = type,
        groupId = groupId,
    )

    // ------------------------------------------------------------ 名字校验（:120-127）

    @Test
    fun `空名字不通过校验`() {
        // Dart :120 `nameController.text.trim().isEmpty` ⇒ 提示「请输入假期名称」
        assertNull(HolidayEditorLogic.validateName(""))
    }

    @Test
    fun `只有空白字符的名字不通过校验`() {
        assertNull(HolidayEditorLogic.validateName("   "))
        assertNull(HolidayEditorLogic.validateName("\t\n"))
        // 全角空格 U+3000（中文输入法下最容易手滑打出来的「空」）
        assertNull(HolidayEditorLogic.validateName("\u3000"))
        assertNull(HolidayEditorLogic.validateName("\u3000 \u3000"))
    }

    @Test
    fun `名字两侧空白被去掉`() {
        assertEquals("国庆", HolidayEditorLogic.validateName("  国庆  "))
        assertEquals("国庆", HolidayEditorLogic.validateName("\u3000国庆\u3000"))
        assertEquals("国庆", HolidayEditorLogic.validateName("国庆"))
    }

    @Test
    fun `名字中间的空格保留`() {
        // 只 trim 两端；「十一 假期」这种写法是用户自己的事
        assertEquals("十一 假期", HolidayEditorLogic.validateName("  十一 假期  "))
    }

    // ------------------------------------------------------------ groupId（:274-275）

    @Test
    fun `新增假期的 groupId 是 custom 加毫秒时间戳`() {
        assertEquals("custom-1759999999999", HolidayEditorLogic.nextGroupId(1_759_999_999_999L))
        assertEquals("custom-0", HolidayEditorLogic.nextGroupId(0L))
    }

    @Test
    fun `不同毫秒得到不同 groupId`() {
        // 连续两次「添加假期」不能撞到同一组，否则第二次编辑会把第一组改掉
        assertTrue(
            HolidayEditorLogic.nextGroupId(1L) != HolidayEditorLogic.nextGroupId(2L),
        )
    }

    // ------------------------------------------------------------ 结束日期跟随（:179-183）

    @Test
    fun `结束日期早于开始日期时跟到同一天`() {
        assertEquals(
            date("2026-10-05"),
            HolidayEditorLogic.clampEnd(date("2026-10-05"), date("2026-10-01")),
        )
    }

    @Test
    fun `结束日期为空时取开始日期`() {
        assertEquals(
            date("2026-10-05"),
            HolidayEditorLogic.clampEnd(date("2026-10-05"), null),
        )
    }

    @Test
    fun `结束日期与开始日期同一天时不变`() {
        assertEquals(
            date("2026-10-05"),
            HolidayEditorLogic.clampEnd(date("2026-10-05"), date("2026-10-05")),
        )
    }

    @Test
    fun `结束日期晚于开始日期时原样保留`() {
        assertEquals(
            date("2026-10-09"),
            HolidayEditorLogic.clampEnd(date("2026-10-05"), date("2026-10-09")),
        )
    }

    @Test
    fun `改开始日期只抬结束日期不动开始日期`() {
        // 方向是单向的：start 永远原样返回（Dart :181-183 只改 endDate）
        val start = date("2026-11-20")
        val end = HolidayEditorLogic.clampEnd(start, date("2026-11-01"))
        assertEquals(date("2026-11-20"), end)
        assertEquals("2026-11-20", start.toString())
    }

    // ------------------------------------------------------------ 日期弹层区间（:175-201）

    @Test
    fun `开始日期区间是今天所在年减一到加二`() {
        val range = HolidayEditorLogic.pickerRange(date("2026-10-29"))
        assertEquals(date("2025-01-01"), range.first)
        assertEquals(date("2028-12-31"), range.last)
    }

    @Test
    fun `结束日期区间下界被开始日期顶起来`() {
        val range = HolidayEditorLogic.endPickerRange(date("2027-03-04"), date("2026-10-29"))
        assertEquals(date("2027-03-04"), range.first)
        assertEquals(date("2028-12-31"), range.last)
    }

    @Test
    fun `没有开始日期时结束日期区间与整表一致`() {
        val range = HolidayEditorLogic.endPickerRange(null, date("2026-10-29"))
        assertEquals(date("2025-01-01"), range.first)
        assertEquals(date("2028-12-31"), range.last)
    }

    @Test
    fun `开始日期早于整表下界时结束日期区间不越界`() {
        // 2024-12-31 比 2025-01-01 还早：滚轮下界不能比开始日期那一栏更早
        val range = HolidayEditorLogic.endPickerRange(date("2024-12-31"), date("2026-10-29"))
        assertEquals(date("2025-01-01"), range.first)
        assertEquals(date("2028-12-31"), range.last)
    }

    // ------------------------------------------------------------ 按天展开（:278-291）

    @Test
    fun `单日假期展开成一条`() {
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2026-10-01"),
            end = date("2026-10-01"),
            name = "国庆节",
            type = HolidayType.Vacation,
            groupId = "custom-1759999999999",
        )
        assertEquals(1, entries.size)
        assertEquals("2026-10-01", entries[0].date.toLocalDate().toString())
        assertEquals("国庆节", entries[0].name)
        assertEquals(HolidayType.Vacation, entries[0].type)
        assertEquals("custom-1759999999999", entries[0].groupId)
    }

    @Test
    fun `跨月区间按天展开`() {
        // 1 月 30、31 → 2 月 1、2，共 4 天
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2026-01-30"),
            end = date("2026-02-02"),
            name = "寒假",
            type = HolidayType.Vacation,
            groupId = "custom-2",
        )
        assertEquals(
            listOf("2026-01-30", "2026-01-31", "2026-02-01", "2026-02-02"),
            entries.map { it.date.toLocalDate().toString() },
        )
    }

    @Test
    fun `跨年区间按天展开`() {
        // 2025-12-30 与 31 是 2025 年，2026-01-01 是新年 → 3 条
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2025-12-30"),
            end = date("2026-01-01"),
            name = "元旦",
            type = HolidayType.Vacation,
            groupId = "custom-3",
        )
        assertEquals(
            listOf("2025-12-30", "2025-12-31", "2026-01-01"),
            entries.map { it.date.toLocalDate().toString() },
        )
    }

    @Test
    fun `闰日不会被跳过`() {
        // 2024 是闰年：02-28 / 02-29 / 03-01
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2024-02-28"),
            end = date("2024-03-01"),
            name = "寒假",
            type = HolidayType.Vacation,
            groupId = "custom-4",
        )
        assertEquals(
            listOf("2024-02-28", "2024-02-29", "2024-03-01"),
            entries.map { it.date.toLocalDate().toString() },
        )
    }

    @Test
    fun `平年二月不产生二十九日`() {
        // 2026 不是闰年：02-28 之后直接 03-01，仍是 2 条
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2026-02-28"),
            end = date("2026-03-01"),
            name = "寒假",
            type = HolidayType.Vacation,
            groupId = "custom-5",
        )
        assertEquals(
            listOf("2026-02-28", "2026-03-01"),
            entries.map { it.date.toLocalDate().toString() },
        )
    }

    @Test
    fun `反向区间展开成空列表`() {
        // Dart 靠 clampEnd + 弹层下界保证不会发生；真发生就一条都不写
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2026-10-09"),
            end = date("2026-10-05"),
            name = "国庆节",
            type = HolidayType.Vacation,
            groupId = "custom-6",
        )
        assertTrue(entries.isEmpty())
    }

    @Test
    fun `展开出来的时刻是当天零点`() {
        // Dart :283 `DateTime(d.year, d.month, d.day)`：日期部分归零，时分秒都是 0
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2026-05-01"),
            end = date("2026-05-02"),
            name = "劳动节",
            type = HolidayType.AdjustedWorkday,
            groupId = "custom-7",
        )
        assertEquals(2, entries.size)
        assertTrue(entries.all { it.date.hour == 0 && it.date.minute == 0 && it.date.second == 0 })
    }

    @Test
    fun `调休上班类型原样写进每条`() {
        val entries = HolidayEditorLogic.expandEntries(
            start = date("2026-10-10"),
            end = date("2026-10-11"),
            name = "补班",
            type = HolidayType.AdjustedWorkday,
            groupId = "custom-8",
        )
        assertTrue(entries.all { it.type == HolidayType.AdjustedWorkday })
    }

    // ------------------------------------------------------------ 归并找组（:396-412、:556-566）

    @Test
    fun `按 groupId 找到组并按日期升序排`() {
        // 故意乱序喂进去：Dart :403 在归并后 sort，取 first 当 existing
        val list = listOf(
            entry("2026-10-03", groupId = "custom-1"),
            entry("2026-10-01", groupId = "custom-1"),
            entry("2026-10-02", groupId = "custom-1"),
        )
        val group = HolidayEditorLogic.groupOf(list, "custom-1")
        assertEquals(
            listOf("2026-10-01", "2026-10-02", "2026-10-03"),
            group!!.entries.map { it.date.toLocalDate().toString() },
        )
        // existing = 最早那条（Dart :560-566 传 entries.first）
        assertEquals("2026-10-01", group.existing!!.date.toLocalDate().toString())
        assertEquals("2026-10-01", group.startDate.toString())
        assertEquals("2026-10-03", group.endDate.toString())
        assertEquals("国庆节", group.name)
    }

    @Test
    fun `找不到的 groupId 返回 null`() {
        val list = listOf(entry("2026-10-01", groupId = "custom-1"))
        assertNull(HolidayEditorLogic.groupOf(list, "custom-999"))
        assertNull(HolidayEditorLogic.groupOf(emptyList(), "custom-1"))
    }

    @Test
    fun `没有 groupId 的老条目归到 ungrouped 桶`() {
        // Dart :399 `entry.groupId ?? 'ungrouped'`
        val list = listOf(
            entry("2026-12-25", name = "圣诞", groupId = null),
            entry("2026-10-01", groupId = "custom-1"),
        )
        val group = HolidayEditorLogic.groupOf(list, HolidayEditorLogic.UNGROUPED_GROUP_ID)
        assertEquals(1, group!!.entries.size)
        assertEquals("圣诞", group.name)
        assertEquals("2026-12-25", group.startDate.toString())
    }

    @Test
    fun `ungrouped 桶不会吞掉有 groupId 的条目`() {
        val list = listOf(
            entry("2026-10-01", groupId = "custom-1"),
            entry("2026-10-02", groupId = "custom-2"),
        )
        assertNull(HolidayEditorLogic.groupOf(list, HolidayEditorLogic.UNGROUPED_GROUP_ID))
    }

    // ------------------------------------------------------------ 行 id 解析（与模型泳道约定）

    @Test
    fun `自定义假期行 id 解析出 groupId`() {
        assertEquals(
            "custom-1759999999999",
            HolidayEditorLogic.groupIdOfRow("holiday.custom.custom-1759999999999"),
        )
        assertEquals(
            HolidayEditorLogic.UNGROUPED_GROUP_ID,
            HolidayEditorLogic.groupIdOfRow("holiday.custom.ungrouped"),
        )
    }

    @Test
    fun `空态与损坏态行不是自定义假期行`() {
        // 「holiday.customEmpty」不含尾点，前缀判断必须为 false，否则点空态会弹编辑框
        assertNull(HolidayEditorLogic.groupIdOfRow(HolidayEditorLogic.ROW_CUSTOM_EMPTY))
        assertNull(HolidayEditorLogic.groupIdOfRow(HolidayEditorLogic.ROW_CUSTOM_CORRUPTED))
    }

    @Test
    fun `其它页的行 id 一律解析成 null`() {
        assertNull(HolidayEditorLogic.groupIdOfRow(HolidayEditorLogic.ROW_ENABLE))
        assertNull(HolidayEditorLogic.groupIdOfRow(HolidayEditorLogic.ROW_ADD))
        assertNull(HolidayEditorLogic.groupIdOfRow("holiday.official.0"))
        assertNull(HolidayEditorLogic.groupIdOfRow("weather.enable"))
    }

    @Test
    fun `前缀为空时返回 null`() {
        // 只有前缀没有内容的畸形 id：不要返回空字符串（空串会被当成一个真实分组）
        assertNull(HolidayEditorLogic.groupIdOfRow("holiday.custom."))
    }

    // ------------------------------------------------------------ 替换写回（holiday_service.dart:705-714）

    @Test
    fun `编辑保存替换同组全部旧条目`() {
        // 旧组 3 天（用户把 10-01~10-03 改成 10-01~10-02），另一组不能被动到
        val old = listOf(
            entry("2026-10-01", groupId = "custom-1"),
            entry("2026-10-02", groupId = "custom-1"),
            entry("2026-10-03", groupId = "custom-1"),
            entry("2026-12-25", name = "圣诞", groupId = "custom-2"),
        )
        val next = HolidayEditorLogic.replaceGroup(
            old = old,
            groupId = "custom-1",
            newEntries = listOf(
                entry("2026-10-01", groupId = "custom-1"),
                entry("2026-10-02", groupId = "custom-1"),
            ),
        )
        assertEquals(
            listOf("2026-12-25", "2026-10-01", "2026-10-02"),
            next.map { it.date.toLocalDate().toString() },
        )
        // 旧的 10-03 必须消失——否则改短区间会留下尾日
        assertTrue(next.none { it.date.toLocalDate() == date("2026-10-03") })
    }

    @Test
    fun `替换成空列表等于删除该组`() {
        val old = listOf(
            entry("2026-10-01", groupId = "custom-1"),
            entry("2026-12-25", name = "圣诞", groupId = "custom-2"),
        )
        val next = HolidayEditorLogic.replaceGroup(old, "custom-1", emptyList())
        assertEquals(listOf("2026-12-25"), next.map { it.date.toLocalDate().toString() })
    }

    @Test
    fun `替换不存在的组时新条目追加在末尾`() {
        // Dart 是 removeWhere（没删到任何东西）+ addAll，顺序照抄
        val old = listOf(entry("2026-12-25", name = "圣诞", groupId = "custom-2"))
        val next = HolidayEditorLogic.replaceGroup(
            old = old,
            groupId = "custom-9",
            newEntries = listOf(
                entry("2026-05-01", name = "劳动节", groupId = "custom-9"),
                entry("2026-05-02", name = "劳动节", groupId = "custom-9"),
            ),
        )
        assertEquals(
            listOf("2026-12-25", "2026-05-01", "2026-05-02"),
            next.map { it.date.toLocalDate().toString() },
        )
    }

    @Test
    fun `可以整体替换没有 groupId 的桶`() {
        val old = listOf(
            entry("2026-12-25", name = "圣诞", groupId = null),
            entry("2026-10-01", groupId = "custom-1"),
        )
        val next = HolidayEditorLogic.replaceGroup(
            old = old,
            groupId = null,
            newEntries = listOf(entry("2026-12-26", name = "圣诞", groupId = null)),
        )
        assertEquals(
            listOf("2026-10-01", "2026-12-26"),
            next.map { it.date.toLocalDate().toString() },
        )
    }

    @Test
    fun `跨组同一天不去重`() {
        // Dart 允许两个自建假期撞在同一天（展示层按组各出一行），别在这里擅自删用户数据
        val old = listOf(entry("2026-10-01", groupId = "custom-2"))
        val next = HolidayEditorLogic.replaceGroup(
            old = old,
            groupId = "custom-1",
            newEntries = listOf(entry("2026-10-01", groupId = "custom-1")),
        )
        assertEquals(2, next.size)
    }

    // ------------------------------------------------------------ 类型映射

    @Test
    fun `假期类型与页面档位互转`() {
        assertEquals(HolidayKind.VACATION, HolidayEditorLogic.kindOf(HolidayType.Vacation))
        assertEquals(
            HolidayKind.ADJUSTED_WORKDAY,
            HolidayEditorLogic.kindOf(HolidayType.AdjustedWorkday),
        )
        assertEquals(HolidayType.Vacation, HolidayEditorLogic.typeOf(HolidayKind.VACATION))
        assertEquals(
            HolidayType.AdjustedWorkday,
            HolidayEditorLogic.typeOf(HolidayKind.ADJUSTED_WORKDAY),
        )
    }

    @Test
    fun `调休休息日归到假期档显示`() {
        // 远端数据里的 adjusted_restday 在编辑器里没有第三档；语义是「这天放假」⇒ 归假期档，
        // 与 SettingsHolidayPage.buildPageData 里私有的 displayKind 同一口径
        assertEquals(
            HolidayKind.VACATION,
            HolidayEditorLogic.kindOf(HolidayType.AdjustedRestday),
        )
    }

    @Test
    fun `往返转换不改变假期与调休上班`() {
        assertEquals(
            HolidayType.Vacation,
            HolidayEditorLogic.typeOf(HolidayEditorLogic.kindOf(HolidayType.Vacation)),
        )
        assertEquals(
            HolidayType.AdjustedWorkday,
            HolidayEditorLogic.typeOf(HolidayEditorLogic.kindOf(HolidayType.AdjustedWorkday)),
        )
    }

    // ------------------------------------------------------------ 行上显示的日期与滚轮上界

    @Test
    fun `日期显示成补零的 yyyy-MM-dd`() {
        // Dart :655-660 `_formatFullDate`：年 4 位、月日各补 2 位
        assertEquals("2026-01-05", HolidayEditorLogic.formatDate(date("2026-01-05")))
        assertEquals("2026-12-31", HolidayEditorLogic.formatDate(date("2026-12-31")))
        // 三位数年份也要补到 4 位（用户手改存档里可能出现）
        assertEquals("0999-02-03", HolidayEditorLogic.formatDate(LocalDate.of(999, 2, 3)))
    }

    @Test
    fun `日期滚轮的日子列上界跟年月走`() {
        // 1 月 31 天、4 月 30 天、2 月看闰年
        assertEquals(31, HolidayEditorLogic.daysInMonth(2026, 1))
        assertEquals(30, HolidayEditorLogic.daysInMonth(2026, 4))
        assertEquals(28, HolidayEditorLogic.daysInMonth(2026, 2))
        assertEquals(29, HolidayEditorLogic.daysInMonth(2024, 2))
        // 整百年：1900 不是闰年、2000 是（Gregorian 规则，不做「四年一闰」的简化）
        assertEquals(28, HolidayEditorLogic.daysInMonth(1900, 2))
        assertEquals(29, HolidayEditorLogic.daysInMonth(2000, 2))
    }

    // ------------------------------------------------------------ 与页面模型的咬合（行 id / 动作约定）

    @Test
    fun `长按删除用 DIALOG 这个约定不能漂`() {
        // Lead 2026-10-29 对表结论：点按 SHEET = 编辑、长按 DIALOG = 删除确认。
        // 两个值一旦改成同一个，宿主就无法区分这两条路径（rowId 完全相同）。
        assertEquals(SettingsAction.DIALOG, HolidayEditorLogic.DELETE_CONFIRM_ACTION)
    }

    @Test
    fun `无 groupId 桶的名字与页面模型一致`() {
        // 模型侧 `grouped.getOrPut(entry.groupId ?: UNGROUPED_CUSTOM_GROUP)` 用的是它，
        // 宿主拿 rowId 去掉前缀后要靠同一个字符串才能找回这一组。
        assertEquals(SettingsHolidayPage.UNGROUPED_CUSTOM_GROUP, HolidayEditorLogic.UNGROUPED_GROUP_ID)
    }

    @Test
    fun `宿主要的行 id 与页面模型实际产出的一致`() {
        // 咬合探针：宿主靠这几个字符串认行，模型泳道改了 id 就会在这里红，而不是等真机上点不动。
        val empty = SettingsHolidayPage.buildPageData(
            enableHolidayMarking = true,
            official = null,
            customHolidays = emptyList(),
            customCorrupted = false,
            today = date("2026-10-29"),
        )
        val emptyRows = flattenIds(SettingsHolidayPage.spec(SettingsPageState(), empty))
        assertTrue(emptyRows.contains(HolidayEditorLogic.ROW_ENABLE))
        // 「添加假期」不是 SettingsRow，而是整宽按钮装在控制卡里的 SettingsInline
        // （Dart `:576-592`；模型里是 `SettingsInline(kind = CONTROL_CARD)`）——
        // 所以这条契约测试必须收**所有节点的 id**，不能只收 SettingsRow。
        assertTrue(emptyRows.contains(HolidayEditorLogic.ROW_ADD))
        assertTrue(emptyRows.contains(HolidayEditorLogic.ROW_CUSTOM_EMPTY))

        val corrupted = SettingsHolidayPage.buildPageData(
            enableHolidayMarking = true,
            official = null,
            customHolidays = listOf(entry("2026-10-01", groupId = "custom-42")),
            customCorrupted = true,
            today = date("2026-10-29"),
        )
        val corruptedIds = flattenIds(SettingsHolidayPage.spec(SettingsPageState(), corrupted))
        assertTrue(corruptedIds.contains(HolidayEditorLogic.ROW_CUSTOM_CORRUPTED))
    }

    @Test
    fun `高级页检查更新按钮在固定底栏上且 id 与宿主约定一致`() {
        // 宿主按 rowId 认这颗按钮（`SettingsHolidayAdvancedHost.ROW_ADVANCED_REFRESH`）。
        // 它在 `footerNode` 里、**不在** `nodes` 里（模型泳道 2026-10-29 口径）：
        // 放进 nodes 会跟着日志列表滚走，而 Dart 是页面 Column 的最后一个子项（`:792-812`）。
        val spec = SettingsHolidayAdvancedPage.spec(SettingsPageState())
        assertEquals("holidayAdvanced.card.refresh", spec.footerNode?.id)
        assertTrue(flattenIds(spec).isEmpty() || !flattenIds(spec).contains("holidayAdvanced.card.refresh"))
    }

    @Test
    fun `自定义假期行的点按与长按动作符合宿主预期`() {
        val data = SettingsHolidayPage.buildPageData(
            enableHolidayMarking = true,
            official = null,
            customHolidays = listOf(
                entry("2026-10-02", groupId = "custom-42"),
                entry("2026-10-01", groupId = "custom-42"),
            ),
            customCorrupted = false,
            today = date("2026-10-29"),
        )
        val rows = flattenRows(SettingsHolidayPage.spec(SettingsPageState(), data))
        val row = rows.first { it.id == HolidayEditorLogic.CUSTOM_ROW_PREFIX + "custom-42" }
        // 点按 = 编辑弹层
        assertEquals(SettingsAction.SHEET, row.action)
        // 长按 = 删除确认（宿主用同一个 onAction 回调，靠 action 区分）
        assertEquals(HolidayEditorLogic.DELETE_CONFIRM_ACTION, row.longPressAction)
        // rowId 去掉前缀就是 provider 的 groupId（宿主据此调 update/remove）
        assertEquals("custom-42", HolidayEditorLogic.groupIdOfRow(row.id))
    }

    /** 把页面 spec 里的行全部摊平（分组里的子行也要能看到）。 */
    private fun flattenRows(node: SettingsPageSpec): List<SettingsRow> =
        node.nodes.flatMap { flattenNode(it) }

    private fun flattenNode(node: SettingsNode): List<SettingsRow> = when (node) {
        is SettingsRow -> listOf(node)
        is SettingsGroup -> node.children.flatMap { flattenNode(it) }
        else -> emptyList()
    }

    /**
     * 把 spec 里**所有**节点的 id 摊平：Row / Inline / Label / Group 都收。
     *
     * 为什么要单独一个：本页有两处动作**不在行上**——「添加假期」是整宽按钮装在
     * `HyperosControlCard` 里的 `SettingsInline(CONTROL_CARD)`（Dart `:576-592`），
     * 高级页的「检查更新」更是 `footerNode`。只收 `SettingsRow` 会把它们漏掉，
     * 于是「宿主认的 id 与模型产出的 id 一致」这条契约看似通过、实则没验到。
     */
    private fun flattenIds(spec: SettingsPageSpec): List<String> =
        spec.nodes.flatMap { flattenIdsOf(it) }

    private fun flattenIdsOf(node: SettingsNode): List<String> = when (node) {
        is SettingsGroup -> listOf(node.id) + node.children.flatMap { flattenIdsOf(it) }
        else -> listOf(node.id)
    }

    // ------------------------------------------------------------ 弹层初值（:91-94、:586-589）

    @Test
    fun `新增弹层起止日期预填今天`() {
        // Dart :586-589 显式传 DateTime.now()——不传会静默点不动保存
        val state = HolidayEditorLogic.initialEditorState(
            existingGroup = null,
            today = date("2026-10-29"),
        )
        assertNull(state.existing)
        assertEquals(date("2026-10-29"), state.startDate)
        assertEquals(date("2026-10-29"), state.endDate)
        assertEquals(HolidayType.Vacation, state.type)
        assertNull(state.groupId)
    }

    @Test
    fun `编辑弹层沿用组的起止日期与类型`() {
        val group = HolidayEditorLogic.groupOf(
            listOf(
                entry("2026-10-04", name = "补班", type = HolidayType.AdjustedWorkday, groupId = "custom-1"),
                entry("2026-10-02", name = "补班", type = HolidayType.AdjustedWorkday, groupId = "custom-1"),
                entry("2026-10-03", name = "补班", type = HolidayType.AdjustedWorkday, groupId = "custom-1"),
            ),
            "custom-1",
        )
        val state = HolidayEditorLogic.initialEditorState(group, date("2026-10-29"))
        assertEquals(date("2026-10-02"), state.startDate)
        assertEquals(date("2026-10-04"), state.endDate)
        assertEquals(HolidayType.AdjustedWorkday, state.type)
        assertEquals("custom-1", state.groupId)
        assertEquals("2026-10-02", state.existing!!.date.toLocalDate().toString())
    }

    @Test
    fun `编辑弹层不会把组的日期换成今天`() {
        val group = HolidayEditorLogic.groupOf(
            listOf(entry("2025-01-01", name = "元旦", groupId = "custom-1")),
            "custom-1",
        )
        val state = HolidayEditorLogic.initialEditorState(group, date("2026-10-29"))
        assertEquals(date("2025-01-01"), state.startDate)
        assertEquals(date("2025-01-01"), state.endDate)
    }
}
