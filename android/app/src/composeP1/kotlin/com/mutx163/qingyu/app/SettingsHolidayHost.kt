package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.calendar.HolidayProvider
import com.mutx163.qingyu.calendar.HolidayType
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.rememberCappedSheetHeight
import com.mutx163.qingyu.pages.settings.HolidayEditorLogic
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsHolidayPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsStringsExt3
import com.mutx163.qingyu.pages.task.TaskStrings
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import java.time.LocalDate

/**
 * 「节假日标记」主页（`b.holiday`）的**真宿主**。
 *
 * 壳里原来的写法是 `SettingsScreen(SettingsHolidayPage.spec(SettingsPageState()), onBack)`
 * —— 用**空构造的默认 state** 渲染，于是页面永远长成「开关永远开、自定义假期永远空、
 * 法定节假日永远『近期没有节假日』、年份永远空」，点开关不落盘、点「添加假期」无反应。
 * 本宿主把这条链路接真（审计 §二 缺口 1~4、6）。
 *
 * ## 数据流（两条源，与 `WeatherSettingsHost` 同一套循环）
 *
 * | 来源 | 提供什么 | 变化怎么进来 |
 * |---|---|---|
 * | [HolidayProvider] | 法定节假日数据、自定义假期三态、刷新态、日志 | `addListener` → `version++` 触发重组 |
 * | [TimetableSettingsModelStore] | 总开关 `enableHolidayMarking`（落在课表设置里） | 写完就地更新 `model` 局部状态 |
 *
 * 线程：[HolidayProvider] 是同步阻塞实现（见其 KDoc），读盘 / 取网 / 写盘一律走 [Dispatchers.IO]。
 *
 * ## 动作对照（Dart `settings_holiday.dart`）
 *
 * | 行 / 动作 | Dart 出处 | 这里做什么 |
 * |---|---|---|
 * | 总开关 `WRITE_SETTING` + `holiday.enable` | `:508-516` | 取反写回设置模型（`store.save`） |
 * | 自定义假期行点按 `SHEET` | `:556-567` | 弹编辑弹层，带该组 existing 与组内首末日期 |
 * | 自定义假期行长按 `DIALOG` | `:568-570` | 弹删除二次确认（确认后 `removeCustomHoliday`） |
 * | 「添加假期」`RUN_NOW`/`SHEET` + `holiday.card.add` | `:576-592` | 弹新增弹层，起止日期预填**今天** |
 * | 顶栏齿轮 `NAVIGATE` | `:466-478` | `onNavigate(route)`（渲染层把 `topBarAction` 转成一次 NAVIGATE） |
 *
 * ## 与 Flutter 的已知差异（照实写，不糊）
 *
 * 1. **日期选择没有月历**：Dart 用 `showMiuixDatePickerSheet`（月历 + 点标题再弹年/月/日滚轮）。
 *    Kotlin 侧 miuix 0.9.4 **没有 DatePicker**，只有 `NumberPicker`，所以这里用三列滚轮
 *    （年 / 月 / 日），与 `SettingsSemesterHost.SemesterStartDateSheet` 完全同一口径。
 *    交互结果（选到某一天）一致，少的是那层月历装饰。
 * 2. **日期滚轮不叠第二层弹层**：Dart 是在编辑弹层上再叠一个日期弹层；这里沿用
 *    `TimeSchemeQuickGenerateSheet` 已经踩过的做法（同文件注释：「两层 `OverlayBottomSheet`
 *    的层叠顺序、返回键与遮罩行为没有把握」），**同一个弹层内换页**：表单页 ↔ 日期滚轮页。
 *    好处是「取消滚轮」只退回表单、用户填了一半不会被清掉，与 Dart 一致。
 * 3. **提示形态**：Dart 用 `showAppToast` 自定义轻提示；这里用系统 `Toast`
 *    （与 `WeatherSettingsHost` / `SettingsSemesterHost` 同口径，壳里还没有轻提示宿主）。
 * 4. **写盘失败只提示不兜底**：Dart 写失败会 `resetDraft` 把表单退回真值；这里因为每次
 *    打开弹层都重新从 provider 快照取初值，失败后自然退回旧值，不需要额外的草稿回滚。
 *
 * @param provider 节假日状态机（壳里注入 `wiring.holiday`）。
 * @param store 课表设置模型存储（总开关落在它拥有的键里，与设置族其它页同一个 store）。
 * @param onBack 返回键。
 * @param onNavigate `NAVIGATE` 的目标路由（壳负责把路由串翻成页面 id 再推页）。
 */
@Composable
fun SettingsHolidayHost(
    provider: HolidayProvider,
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
    onNavigate: (String) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var model by remember(store) { mutableStateOf(store.load()) }
    var version by remember { mutableIntStateOf(0) }

    // 订阅 provider（进/出页面各自增删，与 WeatherSettingsHost 同形）。
    DisposableEffect(provider) {
        val listener: () -> Unit = { version++ }
        provider.addListener(listener)
        onDispose { provider.removeListener(listener) }
    }
    // 首屏加载态：`initialize()` 在 IO 上跑（远端超时 8 秒），这段时间页面必须是
    // 「正在加载」而不是「近期没有节假日」。判据 = 本页还没跑完第一次 initialize 且
    // 快照里还没有数据；重复进页面时 `snapshot.data` 非空，直接不进加载态。
    var initializing by remember { mutableStateOf(true) }
    // 首次进入读盘 + 缺年份补一次远端（幂等；重复进出页面不会发第二次请求）。
    LaunchedEffect(provider) {
        // `runCatching` 是必须的：`initialize()` 若抛（磁盘/解码异常），没有它这一句就不会
        // 执行，`initializing` 永远停在 true —— 那是比修前更糟的「永久加载中」。
        runCatching { withContext(Dispatchers.IO) { provider.initialize() } }
        initializing = false
    }
    // 读取 version 建立快照订阅（值本身不参与渲染）。
    @Suppress("UNUSED_EXPRESSION")
    version

    // 弹层状态：编辑/新增（一个弹层内换页）+ 删除确认。
    var editorVisible by remember { mutableStateOf(false) }
    var editorInitial by remember { mutableStateOf<HolidayEditorLogic.EditorInitialState?>(null) }
    var deleteVisible by remember { mutableStateOf(false) }
    var deleteGroupId by remember { mutableStateOf<String?>(null) }

    fun notify(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /** 总开关写回（Dart `:512-514` `_updateDraft(copyWith(enableHolidayMarking: value))`）。 */
    fun toggleEnable() {
        val next = model.copy(enableHolidayMarking = !model.enableHolidayMarking)
        runCatching { store.save(next) }
            .onSuccess { model = next }
            .onFailure {
                // 落盘失败：不改界面（开关弹回原位），并让用户知道没存上。
                notify(SettingsStringsExt2.saveFailed.text)
            }
    }

    /** 「添加假期」（Dart `:586-589`）：起止日期**必须**预填今天，否则保存会静默无效。 */
    fun openAddEditor() {
        editorInitial = HolidayEditorLogic.initialEditorState(
            existingGroup = null,
            today = LocalDate.now(),
        )
        editorVisible = true
    }

    /** 点自定义假期行（Dart `:556-567`）：组内首末日期作起止、首条作 existing。 */
    fun openEditEditor(groupId: String) {
        val group = HolidayEditorLogic.groupOf(provider.snapshot.customHolidays, groupId) ?: return
        editorInitial = HolidayEditorLogic.initialEditorState(group, LocalDate.now())
        editorVisible = true
    }

    /**
     * 保存（Dart `:274-313`）：新增生成 `custom-<毫秒>`、编辑沿用原 groupId，
     * 按天展开成条目后交给 provider（唯一写入者）。
     */
    fun saveCustomHoliday(
        name: String,
        start: LocalDate,
        end: LocalDate,
        type: HolidayType,
    ) {
        val initial = editorInitial ?: return
        val groupId = initial.groupId ?: HolidayEditorLogic.nextGroupId(System.currentTimeMillis())
        val entries = HolidayEditorLogic.expandEntries(start, end, name, type, groupId)
        if (entries.isEmpty()) return
        scope.launch {
            val ok = runCatching {
                withContext(Dispatchers.IO) {
                    if (initial.existing != null) {
                        provider.updateCustomHoliday(groupId, entries)
                    } else {
                        provider.addCustomHolidays(entries)
                    }
                }
            }.isSuccess
            // Dart `:298-313`：写入失败必须让用户感知，否则「看似成功、重启即丢」。
            if (!ok) notify(SettingsStringsExt2.saveFailed.text)
        }
    }

    /**
     * 删除（Dart `:367-393`）：确认后按 groupId 整组移除。
     *
     * ⚠️ 已知差异（与 Dart 同病）：`groupId` 为 null 的老条目在界面上归到
     * `ungrouped` 这一桶（Dart `:399`），而 provider 的 `removeCustomHoliday(groupId: String)`
     * 是按字符串比 groupId 的，传 `"ungrouped"` 匹配不到 `null` 条目 ⇒ 删除是空操作。
     * Flutter 侧完全一样（同样是传 `'ungrouped'`），所以这里保持一致、不做「顺手修」；
     * 本 App 自己新建的假期一定带 `custom-<毫秒>`，这一桶只可能来自手改存档。
     */
    fun deleteCustomHoliday(groupId: String) {
        scope.launch {
            val ok = runCatching {
                withContext(Dispatchers.IO) { provider.removeCustomHoliday(groupId) }
            }.isSuccess
            if (!ok) notify(SettingsStringsExt2.saveFailed.text)
        }
    }

    val snapshot = provider.snapshot
    // 页面输入由模型泳道的 buildPageData 归并（官方归并/代表项/isPast/年份文案都在那边，有单测）。
    val data = SettingsHolidayPage.buildPageData(
        enableHolidayMarking = model.enableHolidayMarking,
        official = snapshot.data,
        customHolidays = snapshot.customHolidays,
        customCorrupted = snapshot.customCorrupted,
        today = LocalDate.now(),
        loading = initializing && snapshot.data == null,
    )
    val spec = SettingsHolidayPage.spec(SettingsPageState(), data)

    SettingsPageScreen(
        spec = spec,
        onBack = onBack,
        onAction = { action, target, rowId ->
            when {
                // 顶栏齿轮 / 任何导航行：渲染层已经把 `topBarAction` 翻成一次 NAVIGATE。
                action == SettingsAction.NAVIGATE -> target?.let(onNavigate)

                // 总开关：只有它带 WRITE_SETTING。
                action == SettingsAction.WRITE_SETTING &&
                    rowId == HolidayEditorLogic.ROW_ENABLE -> toggleEnable()

                // 「添加假期」：动作值取决于渲染层控制卡的接线（RUN_NOW 或 SHEET 都可能），
                // 所以**先按 rowId 认**，避开两个泳道对同一个按钮选哪个 action 的分歧。
                rowId == HolidayEditorLogic.ROW_ADD -> openAddEditor()

                // 长按自定义假期行 = 删除确认；点按 = 编辑。两者 rowId 相同，只能靠 action 分。
                action == HolidayEditorLogic.DELETE_CONFIRM_ACTION ->
                    HolidayEditorLogic.groupIdOfRow(rowId)?.let {
                        deleteGroupId = it
                        deleteVisible = true
                    }

                action == SettingsAction.SHEET ->
                    HolidayEditorLogic.groupIdOfRow(rowId)?.let { openEditEditor(it) }

                // 其余动作本页没有落点：不写、不崩（与 SettingsHost 的默认分支同口径）。
                else -> Unit
            }
        },
    )

    val initial = editorInitial
    if (initial != null) {
        HolidayEditorSheet(
            visible = editorVisible,
            initial = initial,
            onDismiss = { editorVisible = false },
            onConfirm = { name, start, end, type ->
                val trimmed = HolidayEditorLogic.validateName(name)
                if (trimmed == null) {
                    // Dart `:120-127`：名字为空 ⇒ 提示且**不关弹层**。
                    notify(SettingsStringsExt3.customHolidayNameRequired.text)
                } else {
                    editorVisible = false
                    saveCustomHoliday(trimmed, start, end, type)
                }
            },
            onDelete = initial.groupId?.let { groupId ->
                {
                    // Dart `:248-258`：编辑态才有删除按钮；先关编辑弹层，再弹独立确认层。
                    editorVisible = false
                    deleteGroupId = groupId
                    deleteVisible = true
                }
            },
        )
    }

    HolidayDeleteConfirmSheet(
        visible = deleteVisible,
        onDismiss = { deleteVisible = false },
        onConfirm = {
            deleteVisible = false
            deleteGroupId?.let { deleteCustomHoliday(it) }
        },
    )
}

/**
 * 新增 / 编辑自定义假期弹层（Dart `:85-315`）。
 *
 * 一个 `OverlayBottomSheet` 里两页：
 * - **表单页**（`:140-260`）：名称输入 + 开始/结束日期 + 类型两档 + 编辑态删除按钮 + 取消/保存；
 * - **日期滚轮页**（替代 Dart 的月历弹层）：年 / 月 / 日三列官方 `NumberPicker` + 取消/确认。
 *
 * 状态全部挂在 [visible] 上：关掉再打开按最新的 [initial] 重铺，不残留上一次没提交的输入
 * （Dart 每次 `_showCustomHolidayDialog` 都是新的局部变量）。
 *
 * @param onConfirm 保存：把**未 trim 的名字**与起止日期交回宿主，校验（名称必填）在宿主里做，
 *   于是「校验失败不关弹层」这条只有一处实现。
 * @param onDelete 非 null 时显示删除按钮（只有编辑态给）；点了之后由宿主弹确认层。
 */
@Composable
private fun HolidayEditorSheet(
    visible: Boolean,
    initial: HolidayEditorLogic.EditorInitialState,
    onDismiss: () -> Unit,
    onConfirm: (name: String, start: LocalDate, end: LocalDate, type: HolidayType) -> Unit,
    onDelete: (() -> Unit)?,
) {
    val dark = isSystemInDarkTheme()
    var name by remember(visible, initial) { mutableStateOf(initial.existing?.name ?: "") }
    var startDate by remember(visible, initial) { mutableStateOf(initial.startDate) }
    var endDate by remember(visible, initial) { mutableStateOf(initial.endDate) }
    var type by remember(visible, initial) { mutableStateOf(initial.type) }

    // null = 表单页；否则正在改的是哪一端（Dart 是两个独立日期弹层，这里合成一页滚轮）。
    var picking by remember(visible, initial) { mutableStateOf<DateField?>(null) }
    var wheelYear by remember(visible, initial) { mutableStateOf(0) }
    var wheelMonth by remember(visible, initial) { mutableStateOf(0) }
    var wheelDay by remember(visible, initial) { mutableStateOf(0) }

    val today = LocalDate.now()

    fun openPicker(field: DateField) {
        val current = if (field == DateField.START) startDate else endDate
        wheelYear = current.year
        wheelMonth = current.monthValue
        wheelDay = current.dayOfMonth
        picking = field
    }

    /** 滚轮确认：开始日期改动后，结束日期早于它就跟到同一天（Dart `:179-183`）。 */
    fun confirmPicker() {
        val field = picking ?: return
        // ⚠️ 必须夹一次「日」：用户可能先在 1 月 31 日打开滚轮、再把月拨到 2 月（或把年拨到平年），
        // 此时 `wheelDay` 仍是 31，直接 `LocalDate.of` 会抛 DateTimeException 把弹层打崩。
        // 滚轮页显示的是夹取后的值（safeDay），确认这里必须与显示一致。
        val clampedDay = wheelDay.coerceAtMost(HolidayEditorLogic.daysInMonth(wheelYear, wheelMonth))
        val picked = LocalDate.of(wheelYear, wheelMonth, clampedDay)
        when (field) {
            DateField.START -> {
                startDate = picked
                endDate = HolidayEditorLogic.clampEnd(picked, endDate)
            }
            DateField.END -> endDate = picked
        }
        picking = null
    }

    val s = SettingsStringsExt3
    val field = picking
    val title = when (field) {
        null -> if (initial.existing != null) s.customHolidayEdit.text else s.customHolidayAdd.text
        DateField.START -> s.customHolidayStartDate.text
        DateField.END -> s.customHolidayEndDate.text
    }

    QingyuSheet(
        show = visible,
        title = title,
        onDismissRequest = onDismiss,
        // ⚠️ 表单页里有**自己的** `LazyColumn`（字段区 380dp 内部滚动），滚轮页没有滚动。
        // 所以这里必须 `contentScrolls = true`：套件在不滚动的默认档下会自己套一层
        // `verticalScroll`，把这颗 LazyColumn 套进去就是嵌套滚动（同一支弹层两种页，
        // 只能取「有滚动」的那一档）。代价是底部让位要自己补，见下面的 Spacer。
        contentScrolls = true,
        // 左右 16 由套件给：内容根是两个 `fillMaxWidth` 的 Column，自己没有横向内边距
        // （`TextField` / `BasicComponent` 那 16 是控件内部留白，不是布局内缩）。
        contentPadsHorizontally = false,
    ) {
        if (field == null) {
            HolidayEditorForm(
                name = name,
                onNameChange = { name = it },
                startDate = startDate,
                endDate = endDate,
                onPickStart = { openPicker(DateField.START) },
                onPickEnd = { openPicker(DateField.END) },
                type = type,
                onTypeChange = { type = it },
                onDelete = onDelete,
                onCancel = onDismiss,
                onSave = { onConfirm(name, startDate, endDate, type) },
                errorColor = Color(QingyuTheme.error(dark)),
                errorContentColor = Color(QingyuTheme.onError(dark)),
            )
        } else {
            HolidayDateWheelPage(
                // 开始日期那一栏与结束日期那一栏的可选区间不同（Dart `:175-176` / `:199-201`）。
                range = if (field == DateField.START) {
                    HolidayEditorLogic.pickerRange(today)
                } else {
                    HolidayEditorLogic.endPickerRange(startDate, today)
                },
                year = wheelYear,
                onYearChange = { wheelYear = it },
                month = wheelMonth,
                onMonthChange = { wheelMonth = it },
                day = wheelDay,
                onDayChange = { wheelDay = it },
                onCancel = { picking = null },
                onConfirm = { confirmPicker() },
            )
        }
        // 底部让位（系统手势区 + 16dp）补在**内容末尾**：套件只在 `contentScrolls = false`
        // 时替我们补，这里自己补一份；补在内容里而不是垫在滚动视口外面（Dart
        // `scrollableBottomGap` 的同一条：垫在外面会留一截永远空的板）。
        Spacer(modifier = Modifier.height(bottomInset))
    }
}

/** 编辑弹层里正在被改的那一端日期。 */
private enum class DateField { START, END }

/**
 * 编辑弹层的表单页（Dart `:140-260`）。
 *
 * 布局与前例（`TimeSchemeQuickGenerateSheet`）同一套：字段区限高 380dp 内部滚动，
 * 「取消 / 保存」留在滚动区外固定。左右 16 由外层弹层统一给；`TextField` /
 * `BasicComponent` 那 16 是控件内部留白，不再给分区标题 / 按钮行另补，避免叠成 32。
 */
@Composable
private fun HolidayEditorForm(
    name: String,
    onNameChange: (String) -> Unit,
    startDate: LocalDate,
    endDate: LocalDate,
    onPickStart: () -> Unit,
    onPickEnd: () -> Unit,
    type: HolidayType,
    onTypeChange: (HolidayType) -> Unit,
    onDelete: (() -> Unit)?,
    onCancel: () -> Unit,
    onSave: () -> Unit,
    errorColor: Color,
    errorContentColor: Color,
) {
    val s = SettingsStringsExt3
    Column(modifier = Modifier.fillMaxWidth()) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = rememberCappedSheetHeight(380.dp))
                .scrollEndHaptic()
                .overScrollVertical(),
        ) {
            item(key = "fields") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    // 名称（Dart `:151-154` HyperosTextField）
                    TextField(
                        value = name,
                        onValueChange = onNameChange,
                        label = s.customHolidayNameLabel.text,
                        useLabelAsPlaceholder = true,
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    // 起止日期：官方 BasicComponent（标题 + 行尾取值 + 整行可点 + 官方按压反馈）。
                    // Dart 是 `HyperosPickerField`（长得像输入框）；差异只在外观，点哪儿、点了弹什么一致。
                    DatePickerField(
                        label = s.customHolidayStartDate.text,
                        value = HolidayEditorLogic.formatDate(startDate),
                        onClick = onPickStart,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    DatePickerField(
                        label = s.customHolidayEndDate.text,
                        value = HolidayEditorLogic.formatDate(endDate),
                        onClick = onPickEnd,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    // 类型两档（Dart `:226-247`：HyperosSegmentedControl）
                    // 分区标题、TabRow 与按钮行都不再自带横向 16：弹层已给 16，
                    // 再叠一层就是 32（与其它同口径弹框对齐成单边 16）。
                    Text(
                        text = s.customHolidayType.text,
                        style = MiuixTheme.textStyles.main,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    TabRow(
                        tabs = listOf(
                            s.customHolidayTypeVacation.text,
                            s.customHolidayTypeWorkday.text,
                        ),
                        selectedTabIndex = if (type == HolidayType.Vacation) 0 else 1,
                        onTabSelected = { index ->
                            onTypeChange(
                                if (index == 0) HolidayType.Vacation else HolidayType.AdjustedWorkday,
                            )
                        },
                    )
                    if (onDelete != null) {
                        Spacer(modifier = Modifier.height(16.dp))
                        // Dart `:248-258`：编辑态才有删除按钮，destructive 配色。
                        // ⚠️ `color` 是**底色**、`contentColor` 才是字色：只给 `color` 会让字
                        // 落在默认的 `onSecondaryVariant` 灰上（红底灰字，对比度坏）。
                        // Dart `HyperosButtonVariant.destructive` = 红底 + `onError` 字。
                        Button(
                            onClick = onDelete,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                color = errorColor,
                                contentColor = errorContentColor,
                            ),
                        ) {
                            Text(text = s.customHolidayDelete.text)
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))
        // Dart `:104-139`：左取消、右保存，平分宽度。
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = s.cancelAction.text,
                onClick = onCancel,
            )
            Button(
                modifier = Modifier.weight(1f),
                onClick = onSave,
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = s.saveAction.text)
            }
        }
    }
}

/** 日期字段行（`HyperosPickerField` 的等价物：标题 + 行尾取值 + 整行可点）。 */
@Composable
private fun DatePickerField(label: String, value: String, onClick: () -> Unit) {
    BasicComponent(
        title = label,
        endActions = {
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        onClick = onClick,
    )
}

/**
 * 日期滚轮页：年 / 月 / 日三列官方 `NumberPicker` + 取消 / 确认。
 *
 * **已知差异**：Dart 是同名 `showMiuixDatePickerSheet` 的**月历**（`miuix_date_picker_sheet.dart`），
 * Kotlin miuix 0.9.4 没有 DatePicker，自绘月历属于 miuix-first 标准的例外范围（要用户拍板），
 * 所以这里与 `SettingsSemesterHost.SemesterStartDateSheet` 一样用官方三列滚轮。
 *
 * 「日」列的上界跟年月走：切月后选中值越界要跟着收（否则确认会造出不存在的日期）。
 * 取消**只退回表单页**、不关整个弹层——用户填了一半的名字不该被清掉。
 */
@Composable
private fun HolidayDateWheelPage(
    range: HolidayEditorLogic.DateRange,
    year: Int,
    onYearChange: (Int) -> Unit,
    month: Int,
    onMonthChange: (Int) -> Unit,
    day: Int,
    onDayChange: (Int) -> Unit,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
) {
    val maxDay = HolidayEditorLogic.daysInMonth(year, month)
    val safeDay = day.coerceAtMost(maxDay)
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NumberPicker(
                value = year,
                onValueChange = onYearChange,
                range = range.first.year..range.last.year,
                label = { "$it${TaskStrings.datePickerYear}" },
                textStyle = MiuixTheme.textStyles.title3,
                modifier = Modifier.weight(1f),
            )
            NumberPicker(
                value = month,
                onValueChange = onMonthChange,
                range = 1..12,
                wrapAround = true,
                label = { "$it${TaskStrings.datePickerMonth}" },
                textStyle = MiuixTheme.textStyles.title3,
                modifier = Modifier.weight(1f),
            )
            NumberPicker(
                value = safeDay,
                onValueChange = onDayChange,
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
                onClick = onCancel,
            )
            Button(
                modifier = Modifier.weight(1f),
                onClick = onConfirm,
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = TaskStrings.confirmAction)
            }
        }
    }
}

/**
 * 删除二次确认弹层（Dart `:318-365`）。
 *
 * Dart 刻意用底部 sheet 而不是居中 dialog（注释：`Bottom confirm sheet with solid HyperOS
 * buttons (not center HyperosDialog)`），这里保持同一形态。删除按钮用 destructive 配色。
 */
@Composable
private fun HolidayDeleteConfirmSheet(
    visible: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val s = SettingsStringsExt3
    QingyuSheet(
        show = visible,
        title = s.customHolidayDelete.text,
        onDismissRequest = onDismiss,
        // 内容里每一行（说明句 + 按钮行）自己都垫了左右 16，没有通栏元素 ⇒ 框架侧横向归零，
        // 单边仍是 Dart 那个 16（Dart 这层一个横向 padding 都没写，全靠 `HyperosSheetFrame`）。
        contentPadsHorizontally = true,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = s.customHolidayDeleteConfirm.text,
                style = MiuixTheme.textStyles.body2,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            Spacer(modifier = Modifier.height(20.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = s.cancelAction.text,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onConfirm,
                    // 同上：`color` 是底色、字色要显式给 `onError`，否则是红底灰字。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                ) {
                    Text(text = s.deleteAction.text)
                }
            }
        }
    }
}
