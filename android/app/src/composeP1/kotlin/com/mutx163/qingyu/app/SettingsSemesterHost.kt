package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.BuildConfig
import com.mutx163.qingyu.MemoryStatsCollector
import com.mutx163.qingyu.pages.settings.SemesterSettingsLogic
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsTimetablePage
import com.mutx163.qingyu.pages.task.TaskStrings
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 「学期设置」子页的**真宿主**（`b.semester`）。
 *
 * 壳里原来的写法是
 * `SettingsScreen(SettingsTimetablePage.semesterSpec(SettingsTimetableState()), onBack)`
 * —— 用**空构造的默认 state** 渲染，于是三行永久长成「设置开学日期 / 20 周 / 同步当前周(禁用)」，
 * 而 `SHEET` / `RUN_NOW` 两条动作在壳里只会被当成「按路由推页」（target 为 null ⇒ 什么都不发生）。
 * 结果就是「看着有页面，点了没反应，也永远不会显示用户真实的开学日期」。
 *
 * 本宿主补上三件事：
 *
 * 1. **真数据**：从 [TimetableRepository] 快照读 `currentWeek` / `semesterWeekCount` /
 *    `semesterStartDate`，并订阅变更（改完立刻能看到行尾跟着变）；
 * 2. **真动作**：第一行弹日期滚轮、第二行弹周数滚轮、第三行同步当前周；
 * 3. **真落盘**：`repository.updateSettings(...)`（合并写，只覆盖设置里 core 4 键）
 *    + `repository.setCurrentWeek(...)`，语义逐条对齐 Dart `_SemesterSettingsScreen`。
 *
 * ## 与 Dart 的三条行为对齐（都在 [SemesterSettingsLogic] 里，有 JVM 单测）
 *
 * | 行为 | Dart 出处 |
 * |---|---|
 * | 选完开学日期**立刻**按新日期对齐当前周，再提示「已同步到第 N 周」 | `:772-803` |
 * | 周数改小、当前周超出时回拨到新学期周数，**不**给提示 | `:859-861` |
 * | 「同步当前周」：开学前算第 1 周，超出学期周数钳到末周 | `timetable_provider.dart:3224-3252` |
 *
 * ## 与 Dart 的已知差异（照实写，不糊）
 *
 * - **没有月历**：Flutter 的日期弹层是 `MiuixDatePicker` 月历 + 点标题再弹年/月/日滚轮
 *   （`miuix_date_picker_sheet.dart:170-245`）。Kotlin 版 miuix 0.9.4 **没有** DatePicker
 *   （`miuix-ui` 只有 `NumberPicker`），自绘月历属于 miuix-first 标准的例外范围，
 *   需用户另行拍板；这里直接用官方 `NumberPicker` 三列滚轮，交互结果（选到某一天）
 *   与 Dart 的年/月/日滚轮一致，少的只是那层月历装饰。
 * - **提示形态**：Dart 成功时用 `showAppLightTip`（自定义轻提示浮层），这里用系统
 *   `Toast`（与 `WeatherSettingsHost` 同一口径）——壳里目前没有轻提示宿主。
 *
 * @param repository 课表仓储（壳里注入 `wiring.timetable`；读写都走它，设置与课表同源）。
 * @param onBack 返回键。
 * @param onNavigate `NAVIGATE` 动作的路由（本页目前三行没有导航，留着与其它设置宿主同形）。
 */
@Composable
fun SettingsSemesterHost(
    repository: TimetableRepository,
    onBack: () -> Unit,
    onNavigate: (route: String) -> Unit = {},
) {
    val context = LocalContext.current

    // 订阅照仓储 KDoc：先读 snapshot 拿初值，再 observe（与 ShellPageIndex 里其它宿主同形）。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    var showDateSheet by remember { mutableStateOf(false) }
    var showWeekSheet by remember { mutableStateOf(false) }

    fun notify(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /**
     * 「同步当前周」（Dart `_syncCurrentWeekWithSemesterStartImpl`）。
     *
     * 没开学日期直接返回：页面上那一行本来就是禁用态（`semesterSpec` 给了 `enabled = false`），
     * 这里再兜一次是为了防止将来渲染层改动把禁用态弄丢。
     */
    fun syncCurrentWeek(showTip: Boolean) {
        // ⚠️ 读写一律取 `repository.snapshot`（内存现值），**不要**取上面那个 compose state：
        // 后者要等 observe 回调触发重组后才更新，改完日期紧接着同步时会读到**旧日期**，
        // 算出来的周次就差一整段。仓储的 snapshot 是现算的（`loadedSettings` + 当前周），
        // `updateSettings` 又先改内存再通知，所以这里拿到的必然是刚写进去的那份。
        val settings = repository.snapshot.settings
        val start = settings.semesterStartDate ?: return
        val week = SemesterSettingsLogic.weekForNow(
            now = LocalDateTime.now(),
            semesterStart = start,
            semesterWeekCount = settings.semesterWeekCount,
        )
        val ok = runCatching { repository.setCurrentWeek(week) }.isSuccess
        if (!ok) {
            notify(SettingsStringsExt2.saveFailed.zh)
            return
        }
        if (showTip) {
            notify(SettingsStringsExt2.syncedCurrentWeekMessage.filled("week", week.toString()))
        }
    }

    /** 选完开学日期：落盘 → 按新日期对齐当前周 → 提示（Dart `:772-803`）。 */
    fun applyStartDate(date: LocalDate) {
        val settings = repository.snapshot.settings
        val next = settings.copy(semesterStartDate = SemesterSettingsLogic.startDateTime(date))
        if (runCatching { repository.updateSettings(next) }.isFailure) {
            notify(SettingsStringsExt2.saveFailed.zh)
            return
        }
        // ⚠️ 顺序不能反：先落盘再同步，同步要用**新**日期算周次。
        syncCurrentWeek(showTip = true)
    }

    /** 选完学期周数：与当前值相同 ⇒ 什么都不做；改小后当前周回拨且**不**提示（Dart `:826-861`）。 */
    fun applyWeekCount(count: Int) {
        val settings = repository.snapshot.settings
        if (count == settings.semesterWeekCount) return
        if (runCatching { repository.updateSettings(settings.copy(semesterWeekCount = count)) }.isFailure) {
            notify(SettingsStringsExt2.saveFailed.zh)
            return
        }
        // 用刚写进去的周数判断（同样取仓储现值，别取还没重组的 compose state）。
        SemesterSettingsLogic.weekToFollowAfterWeekCountChange(
            currentWeek = repository.snapshot.currentWeek,
            newWeekCount = count,
        )?.let { week ->
            if (runCatching { repository.setCurrentWeek(week) }.isFailure) {
                notify(SettingsStringsExt2.saveFailed.zh)
            }
        }
    }

    val state = SemesterSettingsLogic.stateOf(
        currentWeek = snapshot.currentWeek,
        semesterWeekCount = snapshot.settings.semesterWeekCount,
        startDate = snapshot.settings.semesterStartDate?.toLocalDate(),
    )

    SettingsPageScreen(
        spec = SettingsTimetablePage.semesterSpec(state),
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (action) {
                SettingsAction.SHEET -> when (rowId) {
                    SemesterSettingsLogic.ROW_START_DATE -> showDateSheet = true
                    SemesterSettingsLogic.ROW_WEEK_COUNT -> showWeekSheet = true
                }

                SettingsAction.RUN_NOW -> {
                    if (rowId == SemesterSettingsLogic.ROW_SYNC_WEEK) syncCurrentWeek(showTip = true)
                }

                SettingsAction.NAVIGATE -> target?.let(onNavigate)

                // 其余动作本页没有落点：不写、不崩（与 SettingsHost 的默认分支同口径）。
                else -> Unit
            }
        },
    )

    SemesterStartDateSheet(
        show = showDateSheet,
        initial = SemesterSettingsLogic.pickerInitialDate(
            startDate = snapshot.settings.semesterStartDate?.toLocalDate(),
            today = LocalDate.now(),
        ),
        onConfirm = { date ->
            showDateSheet = false
            applyStartDate(date)
        },
        onDismiss = { showDateSheet = false },
    )

    SemesterWeekCountSheet(
        show = showWeekSheet,
        initial = SemesterSettingsLogic.pickerInitialWeekCount(snapshot.settings.semesterWeekCount),
        onConfirm = { count ->
            showWeekSheet = false
            applyWeekCount(count)
        },
        onDismiss = { showWeekSheet = false },
    )
}

/**
 * 开学日期弹层：官方 `NumberPicker` 三列滚轮（年 / 月 / 日）+ 取消 / 确认。
 *
 * 范围与初值由 [SemesterSettingsLogic] 决定（2020-01-01 ~ 2035-12-31，初值 `已设 ?: 今天`）；
 * 年/月改动后「日」的上界跟着变，选中值越界时**跟着收**，否则确认会写进一个不存在的日期。
 * 滚轮用官方组件，触感与惯性由它自带（不自研）。
 */
@Composable
private fun SemesterStartDateSheet(
    show: Boolean,
    initial: LocalDate,
    onConfirm: (LocalDate) -> Unit,
    onDismiss: () -> Unit,
) {
    var year by remember(show, initial) { mutableIntStateOf(initial.year) }
    var month by remember(show, initial) { mutableIntStateOf(initial.monthValue) }
    var day by remember(show, initial) { mutableIntStateOf(initial.dayOfMonth) }

    val maxDay = SemesterSettingsLogic.daysInMonth(year, month)
    val safeDay = day.coerceAtMost(maxDay)

    OverlayBottomSheet(
        show = show,
        title = SettingsStringsExt2.semesterStartDateLabel.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = year,
                    onValueChange = { year = it },
                    range = SemesterSettingsLogic.FIRST_YEAR..SemesterSettingsLogic.LAST_YEAR,
                    label = { "$it${TaskStrings.datePickerYear}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = month,
                    onValueChange = { month = it },
                    range = 1..12,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerMonth}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = safeDay,
                    onValueChange = { day = it },
                    range = 1..maxDay,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerDay}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = TaskStrings.cancelAction,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(LocalDate.of(year, month, safeDay)) },
                ) {
                    Text(text = TaskStrings.confirmAction)
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/**
 * 学期周数弹层：官方 `NumberPicker` 单列滚轮（1~30，行文案「N 周」）+ 取消 / 确认。
 *
 * Dart 同款（`showSemesterWeekCountPickerSheet`：`showMiuixNumberPickerSheet` 的
 * `minValue = 1` / `maxValue = 30` / `label = semesterWeekCountAction`）。
 */
@Composable
private fun SemesterWeekCountSheet(
    show: Boolean,
    initial: Int,
    onConfirm: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    var count by remember(show, initial) { mutableIntStateOf(initial) }

    OverlayBottomSheet(
        show = show,
        title = SettingsStringsExt2.selectSemesterWeekCountTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            NumberPicker(
                value = count,
                onValueChange = { count = it },
                range = SemesterSettingsLogic.MIN_WEEK_COUNT..SemesterSettingsLogic.MAX_WEEK_COUNT,
                label = { SettingsStringsExt2.semesterWeekCountAction.filled("count", it.toString()) },
                // 与 Flutter 逐值对齐（`miuix_number_picker_sheet.dart:58-59` `_pickerHeight = 220`、
                // `:85-87` `title3 + w600`）：高度差 40dp、字重差一档是最容易一眼看出来的两处。
                textStyle = MiuixTheme.textStyles.title3.copy(fontWeight = FontWeight.SemiBold),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = TaskStrings.cancelAction,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(count) },
                ) {
                    Text(text = TaskStrings.confirmAction)
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/**
 * 「课表设置」主页（设置首页，`b.settingsHome`）的**真宿主**——本批只把顶部那张
 * 学期摘要卡接真，其余行仍是各批次的演示数据（S2 的其余 16 页）。
 *
 * ## 为什么这页也要改（审计缺口 F2）
 *
 * 那张摘要卡就是**学期设置的入口**，卡上写的是「当前第 N 周 / 共 M 周」＋开学日期
 * （Dart `timetable_settings_screen.dart:379-397` 直接读 `provider.currentWeek` 与
 * `settings.*`）。壳里原来给的是 `SettingsTimetableState()` 空构造 ⇒ 用户走进设置
 * 永远看到「当前第 1 周 / 共 20 周」「未设置开学日期」，哪怕他刚在学期设置里填过。
 * 于是「子页改了、入口卡不跟着变」——这正是审计里最刺眼的一条。
 *
 * 本宿主订阅 [TimetableRepository] 快照，把 `currentWeek` / `semesterWeekCount` /
 * `semesterStartDate` 换成真值后再交给 [SettingsTimetablePage.spec]；其余输入保持默认
 * （与改动前完全一致，不假装已经接上了课表管理 / 时间模板 / 天气等行）。
 *
 * @param repository 课表仓储（与学期设置子页同一个实例，进子页改完回来卡上就是新值）。
 * @param onBack 返回键。
 * @param onNavigate 行上的导航目标（壳负责把路由串翻成页面 id 再推页）。
 */
@Composable
fun SettingsTimetableHubHost(
    repository: TimetableRepository,
    onBack: () -> Unit,
    onNavigate: (route: String) -> Unit = {},
) {
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    // 开发者工具整组的可见性（Dart `timetable_settings_screen.dart:1052-1070`）：
    //   诊断构建（包名 .debug / .profile）⇒ 六行（含「内存状态」「实时活动夹具」）；
    //   正式发布包 ⇒ 整组隐藏；其余（debug 包但非 dev flavor）⇒ 只留组件展示 / 调试叠层。
    // 壳里原来这两处都用默认 false ⇒ 永远走「其余」分支，**内存状态与夹具入口在壳里从未出现过**，
    // 而这两行正是诊断族的两个真实入口。Kotlin 侧判定是同步的，不必像 Dart 那样等 FutureBuilder。
    val context = LocalContext.current
    val diagnosticsBuild = MemoryStatsCollector.isDiagnosticsPackage(context)
    val releaseBuild = !BuildConfig.DEBUG
    val state = SemesterSettingsLogic.stateOf(
        currentWeek = snapshot.currentWeek,
        semesterWeekCount = snapshot.settings.semesterWeekCount,
        startDate = snapshot.settings.semesterStartDate?.toLocalDate(),
    ).copy(
        releaseBuild = releaseBuild,
        diagnosticsBuild = diagnosticsBuild,
    )

    SettingsPageScreen(
        spec = SettingsTimetablePage.spec(state),
        onBack = onBack,
        onAction = { action, target, _ ->
            // 本页只有「箭头行」有落点；开关/弹层那几行仍属演示数据（no-op 与改动前一致）。
            if (action == SettingsAction.NAVIGATE) target?.let(onNavigate)
        },
    )
}
