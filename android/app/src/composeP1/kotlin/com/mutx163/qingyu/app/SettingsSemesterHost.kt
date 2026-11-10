package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.BuildConfig
import com.mutx163.qingyu.MemoryStatsCollector
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.live.LiveDisplayStore
import com.mutx163.qingyu.pages.settings.SettingsTimetableHubLogic
import com.mutx163.qingyu.pages.settings.SemesterSettingsLogic
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsTimetablePage
import com.mutx163.qingyu.pages.sync.CouplePartnerPort
import com.mutx163.qingyu.pages.task.TaskStrings
import com.mutx163.qingyu.platform.CouplePartnerPortImpl
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.weather.WeatherProvider
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
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
            notify(SettingsStringsExt2.saveFailed.text)
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
            notify(SettingsStringsExt2.saveFailed.text)
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
            notify(SettingsStringsExt2.saveFailed.text)
            return
        }
        // 用刚写进去的周数判断（同样取仓储现值，别取还没重组的 compose state）。
        SemesterSettingsLogic.weekToFollowAfterWeekCountChange(
            currentWeek = repository.snapshot.currentWeek,
            newWeekCount = count,
        )?.let { week ->
            if (runCatching { repository.setCurrentWeek(week) }.isFailure) {
                notify(SettingsStringsExt2.saveFailed.text)
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
    val dark = isSystemInDarkTheme()
    var year by remember(show, initial) { mutableIntStateOf(initial.year) }
    var month by remember(show, initial) { mutableIntStateOf(initial.monthValue) }
    var day by remember(show, initial) { mutableIntStateOf(initial.dayOfMonth) }

    val maxDay = SemesterSettingsLogic.daysInMonth(year, month)
    val safeDay = day.coerceAtMost(maxDay)

    QingyuSheet(
        show = show,
        title = SettingsStringsExt2.semesterStartDateLabel.text,
        onDismissRequest = onDismiss,
        // 内容根 Column 自己给了左右 16（里面没有通栏元素）⇒ 框架侧横向归零，
        // 单边就是 Dart 那个 16（`hyperosMiuixBottomSheetInsideMargin`），不再叠成 32。
        contentPadsHorizontally = true,
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
                // E2：滚轮弹层的「取消」= 发布版 `HyperosButtonVariant.secondary`
                //（浅灰实心 + 主文本字，`hyperos_controls.dart:657-818`），不再是 ghost TextButton。
                // 与 IcsExportPage 那三颗滚轮同口径；弹窗（OverlayDialog）里的取消不动。
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.secondary(dark)),
                        contentColor = Color(QingyuTheme.primaryText(dark)),
                    ),
                ) {
                    Text(text = TaskStrings.cancelAction)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(LocalDate.of(year, month, safeDay)) },
                    // 弹层的主出口（不是取消）⇒ 强调色。默认 `buttonColors()` 是灰的
                    // `secondaryVariant`，读起来像禁用（Dart 用 `HyperosButtonVariant.primary`）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = TaskStrings.confirmAction)
                }
            }
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
    val dark = isSystemInDarkTheme()
    var count by remember(show, initial) { mutableIntStateOf(initial) }

    QingyuSheet(
        show = show,
        title = SettingsStringsExt2.selectSemesterWeekCountTitle.text,
        onDismissRequest = onDismiss,
        // 与开学日期弹层同一个口径（见上）。
        contentPadsHorizontally = true,
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
                textStyle = MiuixTheme.textStyles.title3
                    .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // E2：同上一条（滚轮弹层取消 = secondary 实心）。
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.secondary(dark)),
                        contentColor = Color(QingyuTheme.primaryText(dark)),
                    ),
                ) {
                    Text(text = TaskStrings.cancelAction)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(count) },
                    // 弹层主出口 ⇒ 强调色（同上）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = TaskStrings.confirmAction)
                }
            }
        }
    }
}

/**
 * 「课表设置」主页（设置首页，`b.settingsHome`）的**真宿主**。
 *
 * ## 本批修的是「五行拿默认值冒充真值」
 *
 * 壳里原先只喂了学期摘要卡的三个字段，其余全走 [SettingsTimetableState] 的构造默认值，
 * 于是用户在这些子页里改过的值，回到首页**看不出来**：
 *
 * | 行 | 假默认值 | 现在的真源 |
 * |---|---|---|
 * | 课表管理 | 空白（`activeProfileName = null`） | 仓储快照 `activeProfileId` 命中的档案名 |
 * | 时间模板 | 恒「未选择」 | 快照 `activeTimeSchemeId` 命中的模板名 |
 * | 节假日 | 恒「已开启」 | `TimetableSettingsModel.enableHolidayMarking`（落盘真值） |
 * | 天气 | 恒「未设置」 | [WeatherProvider.location] 的城市名；provider 未注入时保持「未设置」 |
 * | 情侣课表 | 恒「未绑定」 | `partner_timetable_binding` 键能否解出绑定（`hasPartnerBinding` 的同口径） |
 *
 * 合成逻辑在 `SettingsTimetableHubLogic.stateOf`（`pages/settings/SettingsP3B2States.kt`，
 * 纯 Kotlin、有 JVM 单测），本函数只负责「从哪读到、什么时候重读」。
 *
 * ## 本页五行都是**只读展示**
 *
 * 五行的交互都是箭头（`MiuixRowComponent.ARROW` + `NAVIGATE`），与 Dart 一致——写入口在
 * 各自子页：改名去「课表管理」、改模板去「时间模板」、拖节假日开关去「节假日标记」
 * （`SettingsHolidayHost.toggleEnable` 负责落盘，失败会弹提示并把开关弹回）、选城去
 * 「天气」、绑定去「情侣课表」。所以本页不存在「写回」动作，也就没有写回失败可提示；
 * 读取失败时按「没有该数据」展示（不拿假值补位）。
 *
 * ## 为什么有可空参数
 *
 * 壳的调用点（`ShellPageIndex.kt`）归 Lead 所有，本批不动。因此：
 *
 * - [settingsStore] / [partnerPort] 传 null 时，宿主用 [PrefsKeyValueStore] 在**同一份**
 *   `FlutterSharedPreferences` 上自建只读实例（键完全相同，读到的是同一份存档）；
 * - [weather] 没有同等的「自建」余地（provider 带网络与缓存），传 null 就**保持
 *   「未设置」并如实展示**，等 Lead 在调用点补 `weather = wiring.weather`。
 *
 * ## 重读时机
 *
 * 仓储快照有 `observe`，档案 / 模板改名当场跟着变；节假日与情侣绑定没有变更通道，
 * 依赖「从子页返回时本 entry 重新组合」读到新值（NavDisplay 栈内下层 entry 会销毁重建）。
 *
 * @param repository 课表仓储（与学期设置子页同一个实例）。
 * @param settingsStore 完整设置模型存储（节假日开关在其中）；null = 自建只读实例。
 * @param weather 天气 provider（壳里注入 `wiring.weather`）；null = 天气行显示「未设置」。
 * @param partnerPort 情侣绑定端口；null = 自建实例读 `partner_timetable_binding`。
 * @param onBack 返回键。
 * @param onNavigate 行上的导航目标（壳负责把路由串翻成页面 id 再推页）。
 */
@Composable
fun SettingsTimetableHubHost(
    repository: TimetableRepository,
    onBack: () -> Unit,
    onNavigate: (route: String) -> Unit = {},
    settingsStore: TimetableSettingsModelStore? = null,
    weather: WeatherProvider? = null,
    partnerPort: CouplePartnerPort? = null,
) {
    val context = LocalContext.current

    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    // ---- 三处本页不拥有的真源 -------------------------------------------------
    // 与壳共用同一份 `FlutterSharedPreferences`（`PrefsKeyValueStore` 是无状态薄封装：
    // 每次 get 直接读 SharedPreferences，所以自建实例读到的就是壳刚写进去的那份）。
    val sharedPrefs = remember(context) { PrefsKeyValueStore(context.applicationContext) }
    val fallbackSettingsStore = remember(sharedPrefs) {
        TimetableSettingsModelStore(TimetableStore(sharedPrefs))
    }
    val fallbackPartnerPort = remember(repository, sharedPrefs) {
        CouplePartnerPortImpl(repository, sharedPrefs)
    }
    val activeSettingsStore = settingsStore ?: fallbackSettingsStore
    val activePartnerPort = partnerPort ?: fallbackPartnerPort

    // 天气 provider 不是 Compose 可观察的（`addListener` 那套），用一个计数把
    // 「数据到了 / 城市变了」转成重组；退订必须用**同一个** lambda 引用（同
    // `TimetableWithCourseActions` 的写法）。
    var weatherRevision by remember(weather) { mutableIntStateOf(0) }
    DisposableEffect(weather) {
        if (weather == null) {
            onDispose { }
        } else {
            val listener: () -> Unit = { weatherRevision += 1 }
            weather.addListener(listener)
            onDispose { weather.removeListener(listener) }
        }
    }
    @Suppress("UNUSED_EXPRESSION")
    weatherRevision // 读一次建立订阅；值本身不参与渲染。

    // 设置模型没有变更通道（只有 load / save），按「快照变一次就重读一次」取初值。
    // 仓储通知不覆盖节假日写入（那是另一个 store 直接写盘），所以从子页返回时
    // 依赖 entry 重建再读（见 KDoc「重读时机」）。
    val settings = remember(activeSettingsStore, snapshot) {
        runCatching { activeSettingsStore.load() }.getOrDefault(TimetableSettingsModel())
    }
    // 绑定态判据与 Dart `provider.hasPartnerBinding`（`:577`）同口径：能解出绑定才算绑定。
    // 读失败 / 坏值 = 没有可用绑定 ⇒ false（`CouplePartnerPort.loadBinding` 对坏值按 Dart
    // `getPartnerTimetableBinding` 的口径留档后清除，所以这里不出现「看着绑定其实是坏值」）。
    val partnerBound = remember(activePartnerPort, snapshot) {
        runCatching { activePartnerPort.loadBinding() != null }.getOrDefault(false)
    }

    // 开发者工具整组的可见性（Dart `timetable_settings_screen.dart:1052-1070`）：
    //   诊断构建（包名 .debug / .profile）⇒ 六行（含「内存状态」「实时活动夹具」）；
    //   正式发布包 ⇒ 整组隐藏；其余（debug 包但非 dev flavor）⇒ 只留两组组件展示。
    // 壳里原来这两处都用默认 false ⇒ 永远走「其余」分支，**内存状态与夹具入口在壳里从未出现过**，
    // 而这两行正是诊断族的两个真实入口。Kotlin 侧判定是同步的，不必像 Dart 那样等 FutureBuilder。
    val diagnosticsBuild = MemoryStatsCollector.isDiagnosticsPackage(context)
    val releaseBuild = !BuildConfig.DEBUG

    // ---- 两项「异步查 + 回前台重查」的行尾真值 ----------------------------------
    //
    // 1) 超级岛行尾（Flutter `timetable_settings_screen.dart:900-926`，`_LiveEntryTileState`）：
    //    通知权限 null = 还没查到（行尾留白，避免首帧闪「缺权限」），查到后按
    //    「缺权限优先于开关状态」显示；三个提醒开关任一开着算「已开启」。
    //    权限判据与 Dart 的 `MiuiLiveActivitiesService().checkNotificationPermission()` 同源：
    //    系统层面本应用通知是否可用（未授予 POST_NOTIFICATIONS、或用户在系统设置里
    //    关掉应用通知，都会是 false）。
    // 2) 云同步行尾（`:995-1007`，`_CloudSyncEntryTileState`）：见
    //    [readCloudSyncTrailingState] 的 KDoc——只取已落盘的「已开启 / 已关闭」。
    var notificationPermissionGranted by remember { mutableStateOf<Boolean?>(null) }
    var liveReminderEnabled by remember { mutableStateOf(true) }
    var cloudSyncState by remember { mutableStateOf("loading") }

    val liveStore = remember(sharedPrefs) { LiveDisplayStore(TimetableStore(sharedPrefs)) }

    fun readAsyncTrailingValues() {
        notificationPermissionGranted = runCatching {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }.getOrNull()
        // 读不到就按出厂默认（三个开关都开）显示：不能拿 false 冒充「用户关过」。
        liveReminderEnabled = runCatching {
            val timing = liveStore.loadReminderTiming()
            timing.liveEnableBeforeClass || timing.liveEnableDuringClass || timing.liveEnableBeforeEnd
        }.getOrDefault(true)
        cloudSyncState = runCatching { readCloudSyncTrailingState(sharedPrefs) }
            .getOrDefault("loading")
    }
    LaunchedEffect(liveStore) { readAsyncTrailingValues() }
    // 回前台重查（Dart `didChangeAppLifecycleState`，`timetable_settings_screen.dart:156-170`）：
    // 用户可能刚在系统设置里开了通知、或在实时活动子页改了提醒开关；云同步的开关也
    // 在别的页里改，回本页时要跟着变。
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, liveStore) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) readAsyncTrailingValues()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val state = SettingsTimetableHubLogic.stateOf(
        snapshot = snapshot,
        settings = settings,
        weatherCityName = weather?.location?.name,
        partnerBound = partnerBound,
    ).copy(
        releaseBuild = releaseBuild,
        diagnosticsBuild = diagnosticsBuild,
        notificationPermissionGranted = notificationPermissionGranted,
        liveReminderEnabled = liveReminderEnabled,
        cloudSyncState = cloudSyncState,
    )

    SettingsPageScreen(
        spec = SettingsTimetablePage.spec(state),
        onBack = onBack,
        onAction = { action, target, _ ->
            // 本页只有「箭头行」有落点；开关/弹层那几行在各自子页（见 KDoc）。
            if (action == SettingsAction.NAVIGATE) target?.let(onNavigate)
        },
    )
}

/**
 * 云同步行尾的**已落盘**状态串（`enabled` / `disabled`）。
 *
 * ## 口径
 *
 * 发布版行尾五态（`_CloudSyncEntryTileState.build`，`timetable_settings_screen.dart:995-1007`）：
 * 未读完留白 / 已关闭 / 同步中 / 上次失败 / 已开启。其中「同步中」「上次失败」来自
 * `provider.cloudSyncStatus`——那是**内存态**，进程重启就没了。
 *
 * 重构版的运行时状态活在 `CloudSyncController` 实例里（`pages/sync/CloudSyncController.kt`
 * 的 `status.lastErrorCode`；云同步页与备份列表页各自 `new` 一份，没有进程级共享件），
 * 设置首页拿不到 ⇒ 这里只给**已落盘的两态**，其余时间显示「已开启 / 已关闭」，
 * 不拿假值冒充「同步中 / 上次失败」。缺的那份共享状态已作为待办报给 Chief（需要同步泳道
 * 提供进程级状态持有者），不在本文件造。
 *
 * ## 读法
 *
 * 键与 [WebdavSyncConfig.PREFS_KEY] 同源（`webdav_sync_config_v1` 的 `enabled`）；
 * 读不到 / 坏值按出厂默认（未启用）算——与 `WebdavConfigStoreImpl.loadConfig()` 的
 * 兜底一致，也与 Dart 侧 `cloudSyncConfig.enabled` 的默认一致。
 */
private fun readCloudSyncTrailingState(prefs: PrefsKeyValueStore): String {
    val raw = prefs.getString(WebdavSyncConfig.PREFS_KEY)
    if (raw.isNullOrEmpty()) return "disabled"
    val decoded = MiniJson.tryParse(raw) as? Map<*, *> ?: return "disabled"
    val map = LinkedHashMap<String, Any?>()
    for ((key, value) in decoded) {
        if (key is String) map[key] = value
    }
    val enabled = runCatching { WebdavSyncConfig.fromJson(map).enabled }.getOrDefault(false)
    return if (enabled) "enabled" else "disabled"
}
