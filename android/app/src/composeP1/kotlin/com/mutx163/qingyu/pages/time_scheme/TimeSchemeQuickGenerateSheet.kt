package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.rememberCappedSheetHeight
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.BreakOverrideRule
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 「快捷生成课表时间」弹层 · Compose 渲染层（P35-TS · ts-editor）。
 *
 * 对应 Flutter `lib/widgets/time_scheme_quick_generate_sheet.dart`（471 行）：
 *
 * | Dart | 这里 |
 * |---|---|
 * | `showTimeSchemeQuickGenerateSheet` + `HyperosSheetFrame(floating)` 外壳 `:55-65`、`:146-157` | 共享 [QingyuSheet]（官方 `OverlayBottomSheet` 的封装：统一 16dp 横向内边距与底部手势区让位） |
 * | 五个数字输入框（上午/下午/晚上节数、单节课时长、小课间时长）`:164-229`、`_buildNumberField` `:278-284` | [NumberField]：miuix `TextField` + 数字键盘（**不改成滚轮**：Dart 就是文本输入框，滚轮会把 6 个字段摊成 6 个 180dp 高的滚轮） |
 * | 三个起始时间 `HyperosPickerField` `:169-219`、`_buildTimeTile` `:286-299` + `showMiuixTimePickerSheet` | [TimePickerField]（行样式）+ 本弹层内**第二页**「时 0-23 / 分 0-59 步长 5」两列官方 `NumberPicker` |
 * | 「大课间规则」标题 + 增删行 `:231-247`、`_buildBreakOverrideRows` `:301-347`、`_addBreakOverride` `:430-436` | 同一套：每行「第几节后 / 休息时长 分钟 / 删除」，空态给 `noLargeBreakRulesHint` |
 * | 取消 / 生成 两个按钮 `:253-272` | 两颗**实心块钮**（secondary / primary）——2026-11-10 起与对话框动作同一口径，不再「文字钮 + 实心钮」混搭 |
 * | （无）| **2026-11-10 重做新增**：四张卡分组（上午 / 下午 / 晚上 / 课堂节奏+大课间）、卡上方的实时预览 `quickGeneratePreviewSummary`、错误挂在出错的那张卡里 |
 * | `_submit` 的两条校验 `:365-412` | [submit]：先「数字没填全」→ `fillNumbersValidationMessage`；再逐条查大课间规则 → `breakOverrideInvalidMessage`。**就地显示在出错的那张卡内**（`MiuixTheme.colorScheme.error`），不弹系统 Toast（弹层里 Toast 会被面板挡视线） |
 * | `_pickTime` 里 `showMiuixTimePickerSheet` 的 `initialTime = 当前值` | 进第二页时按当前 `HH:mm` 定位两列滚轮 |
 *
 * ## 为什么时间选择不叠第二个 Overlay
 *
 * Dart 是在弹层之上**再弹**一个时间选择器。这里改成**同一个弹层内切页**（表单页 ⇄ 滚轮页），
 * 理由：两层 `OverlayBottomSheet` 的层叠顺序、返回键与遮罩行为没有把握，
 * 不值得为「多一层」赌未知的交互风险。**代价**：滚轮页没有表单页可见（用户要先按返回才看得到
 * 自己改的是哪一行）——所以滚轮页的标题直接用**该字段的标签**（「早上第一节时间」），把上下文补回去，
 * 与 Dart 传给时间选择器的 `title` 逐字相同。
 *
 * ## `24:00` 哨兵与本弹层无关
 *
 * Dart 的时间选择器小时上限是 23（`miuix_time_picker_sheet.dart:88`），表达不了「当天结束」`24:00`。
 * 这里只选**起始时间**（早上/下午/晚上第一节），不存在 `24:00`；结束时间的 `24:00` 折叠
 * （`resolveSectionEndTimeEdit`）只发生在编辑器页改单节时间那两跳里，由宿主串。
 *
 * ## 两条 Dart 校验分支：**保留，而且真的可达**
 *
 * 用 `TextField` 就意味着能输空、能输非数字；大课间「新增一行」在 Dart 里的默认值是
 * `第几节后 = 0`（`:433`）——那个值本身非法。所以 `fillNumbersValidationMessage` 与
 * `breakOverrideInvalidMessage` 这两条提示在 Compose 侧**不是死代码**。
 *
 * 2026-11-10 重做后：错误**挂到出错的那张卡里**（[QuickErrorSlot]），并且大课间新行
 * 默认改成「最后一节之后 + 20 分钟」（一个真能用的值，不再逼用户先改错再报错）。
 *
 * ## 重做说明（2026-11-10，用户报「丑、不实用」）
 *
 * 发布版这一屏就是「9 个控件平铺 + 底部一句通用校验」，没有可抄的更好形态，所以按本仓
 * 套件规格重排：控件分组进卡、加一行**实时预览**（改节数/时间的同时就能看到「共 N 节 ·
 * 最后一节几点结束」）、错误就地指格、两个按钮同形制。字段与语义一个没少，只改信息层级。
 *
 * ## 滚动说明（给后来者）
 *
 * 表单页的字段区是 `LazyColumn + scrollEndHaptic + overScrollVertical`：这是**弹层内部滚动**
 * （Dart 对应 `SingleChildScrollView`，`:158-160`），不是页面级滚动，所以不套 [QingyuPageList]
 * 那种带右侧滚动条的页面骨架；三件套里的两件（末端轻震 + 过度滚动）照官方配方接上。
 * 「取消 / 生成」两个按钮**固定在滚动区之外**，规则加再多也不会把按钮顶出屏幕。
 *
 * ## 数字、文案、颜色都不在手边编
 *
 * - 初始值来自宿主传进来的 [initialPreset]（Dart 的 `_lastQuickGeneratePreset`，首次是
 *   `kDefaultTimeSchemeQuickGeneratePreset`：4 / 4 / 2 节、08:00 / 14:00 / 19:00、45 / 10 分钟、
 *   带一条「第 2 节后 20 分钟」）；
 * - 屏上每一句都取 [TimeSchemeManagementStrings]（与 `lib/l10n/app_zh.arb` 逐字对拍）；
 * - 数字滚轮一律官方 `NumberPicker`，主题色与字阶走 `MiuixTheme`，不写死字号/色值。
 *
 * @param visible 弹层是否显示（显隐由宿主持有；每次 `visible` 从 false → true 都按 [initialPreset] 重铺表单）
 * @param initialPreset 打开时的初值（宿主存的上一次生成参数）
 * @param onDismiss 用户关闭（点遮罩/返回键/取消）
 * @param onConfirm 点了「生成」且本地校验通过：把 preset 交回去。**节次落地（`toSections()`）与
 *   `DartFormatException` 的本地化提示都由宿主负责**（契约 §3：本层只回调 preset）
 */
@Composable
fun TimeSchemeQuickGenerateSheet(
    visible: Boolean,
    initialPreset: TimeSchemeQuickGeneratePreset,
    onDismiss: () -> Unit,
    onConfirm: (TimeSchemeQuickGeneratePreset) -> Unit,
) {
    // 全部状态都挂在 visible 上：弹层关掉再打开时按最新的 initialPreset 重铺，
    // 不残留上一次没提交的输入（Dart 每次 open 都是新的 State）。
    var morningCount by remember(visible) { mutableStateOf(initialPreset.morningCount.toString()) }
    var afternoonCount by remember(visible) { mutableStateOf(initialPreset.afternoonCount.toString()) }
    var eveningCount by remember(visible) { mutableStateOf(initialPreset.eveningCount.toString()) }
    var classDuration by remember(visible) {
        mutableStateOf(initialPreset.classDurationMinutes.toString())
    }
    var breakDuration by remember(visible) {
        mutableStateOf(initialPreset.breakDurationMinutes.toString())
    }
    var morningStart by remember(visible) {
        mutableStateOf(initialPreset.morningStartTime ?: QuickTimeField.DEFAULT_MORNING)
    }
    var afternoonStart by remember(visible) {
        mutableStateOf(initialPreset.afternoonStartTime ?: QuickTimeField.DEFAULT_AFTERNOON)
    }
    var eveningStart by remember(visible) {
        mutableStateOf(initialPreset.eveningStartTime ?: QuickTimeField.DEFAULT_EVENING)
    }
    var breakRules by remember(visible) {
        mutableStateOf(
            initialPreset.breakOverrideRules
                .map { QuickBreakRuleDraft(it.afterSection.toString(), it.breakDurationMinutes.toString()) }
                // Dart `:121-125`：初值里一条大课间规则都没有时，补一条「第 2 节后 20 分钟」。
                .ifEmpty { listOf(QuickBreakRuleDraft("2", "20")) },
        )
    }
    // 本地校验提示（就地显示）：null = 没有错。
    var validationError by remember(visible) { mutableStateOf<String?>(null) }
    // 提示挂在**哪一张卡**上（2026-11-10 重做：原来只有底部一句通用话，用户不知道是哪一格错）。
    var errorSlot by remember(visible) { mutableStateOf<QuickErrorSlot?>(null) }

    // null = 表单页；非 null = 「时/分」滚轮页，正在改这一个字段。
    var timeField by remember(visible) { mutableStateOf<QuickTimeField?>(null) }
    var wheelHour by remember(visible) { mutableIntStateOf(0) }
    var wheelMinuteIndex by remember(visible) { mutableIntStateOf(0) }

    fun currentValueOf(field: QuickTimeField): String = when (field) {
        QuickTimeField.MORNING -> morningStart
        QuickTimeField.AFTERNOON -> afternoonStart
        QuickTimeField.EVENING -> eveningStart
    }

    fun applyValueOf(field: QuickTimeField, value: String) {
        when (field) {
            QuickTimeField.MORNING -> morningStart = value
            QuickTimeField.AFTERNOON -> afternoonStart = value
            QuickTimeField.EVENING -> eveningStart = value
        }
    }

    /** 点某一行的起始时间：按它的当前值定位两列滚轮，然后切到滚轮页。 */
    fun openTimePicker(field: QuickTimeField) {
        val (hour, minute) = QuickTimeField.parse(currentValueOf(field))
        wheelHour = hour
        // 分钟滚轮是 0..11 的档位（每档 5 分钟），当前分钟向下归到档位。
        wheelMinuteIndex = (minute / QuickTimeField.MINUTE_STEP).coerceIn(0, 11)
        timeField = field
    }

    /** 滚轮页确认：写回该字段并回到表单页。 */
    fun confirmTimePicker() {
        val field = timeField ?: return
        val hour = wheelHour.toString().padStart(2, '0')
        val minute = (wheelMinuteIndex * QuickTimeField.MINUTE_STEP).toString().padStart(2, '0')
        applyValueOf(field, "$hour:$minute")
        timeField = null
    }

    /**
     * 表单当前值 → 判据输入。
     *
     * 2026-11-11 评审 T-06：`submit()` 与实时预览**必须同源**，否则会出现
     * 「预览显示 12 节、点生成却报请填数字」这种自相矛盾。两者现在都走
     * [TimeSchemeQuickGenerateInput.parse]，这里只负责把 UI 状态摊成输入。
     */
    fun currentInput(): QuickGenerateInputText = QuickGenerateInputText(
        morningCount = morningCount,
        afternoonCount = afternoonCount,
        eveningCount = eveningCount,
        classDuration = classDuration,
        breakDuration = breakDuration,
        breakRules = breakRules.map { it.afterSection to it.duration },
        morningStartTime = morningStart,
        afternoonStartTime = afternoonStart,
        eveningStartTime = eveningStart,
    )

    /** 点「生成」：判据来自 [TimeSchemeQuickGenerateInput.parse]，错误挂到对应卡片。 */
    fun submit() {
        validationError = null
        errorSlot = null
        when (val result = TimeSchemeQuickGenerateInput.parse(currentInput())) {
            is QuickGenerateParseResult.MissingNumbers -> {
                errorSlot = result.field.toErrorSlot()
                validationError = TimeSchemeManagementStrings.fillNumbersValidationMessage.text
            }

            QuickGenerateParseResult.InvalidBreakRule -> {
                errorSlot = QuickErrorSlot.BREAK_RULES
                validationError = TimeSchemeManagementStrings.breakOverrideInvalidMessage.text
            }

            is QuickGenerateParseResult.Ready -> onConfirm(result.preset)
        }
    }

    /** 实时预览用：同一份判据的 Ready 分支（不产生错误提示）。 */
    fun parsedPresetOrNull(): TimeSchemeQuickGeneratePreset? =
        (TimeSchemeQuickGenerateInput.parse(currentInput()) as? QuickGenerateParseResult.Ready)?.preset

    /** 现有三个时段的总节数（新增规则时用来算「最后一节之后」）。全空时退回 1。 */
    fun totalSectionCount(): Int {
        val morning = morningCount.trim().toIntOrNull() ?: 0
        val afternoon = afternoonCount.trim().toIntOrNull() ?: 0
        val evening = eveningCount.trim().toIntOrNull() ?: 0
        return (morning + afternoon + evening).coerceAtLeast(1)
    }

    val title = timeField?.let { timeFieldLabel(it) }
        ?: TimeSchemeManagementStrings.quickGenerateTimeSchemeTitle.text

    QingyuSheet(
        show = visible,
        title = title,
        onDismissRequest = onDismiss,
        // 内容自己就有 `LazyColumn`（字段区在内部滚）：框架侧再套一层 `verticalScroll`
        // 会变成嵌套滚动、直接崩，所以滚动归内容，底部让位也由内容自己补（见本 lambda 末尾）。
        // 横向同理：内容刻意不留统一内边距（见 [QuickGenerateForm] 的 KDoc），框架侧给 16dp。
        contentPadsHorizontally = false,
        contentScrolls = true,
    ) {
        val field = timeField
        if (field == null) {
            QuickGenerateForm(
                morningCount = morningCount,
                onMorningCountChange = { morningCount = it },
                afternoonCount = afternoonCount,
                onAfternoonCountChange = { afternoonCount = it },
                eveningCount = eveningCount,
                onEveningCountChange = { eveningCount = it },
                classDuration = classDuration,
                onClassDurationChange = { classDuration = it },
                breakDuration = breakDuration,
                onBreakDurationChange = { breakDuration = it },
                morningStart = morningStart,
                afternoonStart = afternoonStart,
                eveningStart = eveningStart,
                onPickMorningStart = { openTimePicker(QuickTimeField.MORNING) },
                onPickAfternoonStart = { openTimePicker(QuickTimeField.AFTERNOON) },
                onPickEveningStart = { openTimePicker(QuickTimeField.EVENING) },
                breakRules = breakRules,
                onBreakRuleChange = { index, draft ->
                    breakRules = breakRules.toMutableList().also { it[index] = draft }
                },
                onRemoveBreakRule = { index ->
                    breakRules = breakRules.toMutableList().also { it.removeAt(index) }
                },
                onAddBreakRule = {
                    // 2026-11-10 重做：新行默认「**最后一节之后** + 20 分钟」。
                    // Dart `_addBreakOverride` 给的是「第几节后 = 0」——0 本身非法，
                    // 用户不改就点生成必被挡；默认值改成一个真能用的。
                    breakRules = breakRules +
                        QuickBreakRuleDraft(totalSectionCount().toString(), "20")
                },
                validationError = validationError,
                errorSlot = errorSlot,
                previewSummary = parsedPresetOrNull()?.previewSummary(),
                onCancel = onDismiss,
                onConfirm = ::submit,
            )
        } else {
            QuickGenerateTimePickerPage(
                hour = wheelHour,
                onHourChange = { wheelHour = it },
                minuteIndex = wheelMinuteIndex,
                onMinuteIndexChange = { wheelMinuteIndex = it },
                onCancel = { timeField = null },
                onConfirm = ::confirmTimePicker,
            )
        }
        // S2：底部让位（系统手势区 + 16dp 呼吸）。放在**内容**末尾、两个固定按钮之下：
        // 表单页那行按钮不在滚动区里，垫在滚动视口外只会得到一条永远空着的板。
        Spacer(Modifier.height(bottomInset))
    }
}

@Composable
private fun QuickGenerateForm(
    morningCount: String,
    onMorningCountChange: (String) -> Unit,
    afternoonCount: String,
    onAfternoonCountChange: (String) -> Unit,
    eveningCount: String,
    onEveningCountChange: (String) -> Unit,
    classDuration: String,
    onClassDurationChange: (String) -> Unit,
    breakDuration: String,
    onBreakDurationChange: (String) -> Unit,
    morningStart: String,
    afternoonStart: String,
    eveningStart: String,
    onPickMorningStart: () -> Unit,
    onPickAfternoonStart: () -> Unit,
    onPickEveningStart: () -> Unit,
    breakRules: List<QuickBreakRuleDraft>,
    onBreakRuleChange: (index: Int, draft: QuickBreakRuleDraft) -> Unit,
    onRemoveBreakRule: (index: Int) -> Unit,
    onAddBreakRule: () -> Unit,
    validationError: String?,
    errorSlot: QuickErrorSlot?,
    previewSummary: String?,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        // 弹层内部滚动（见文件头「滚动说明」）：四张卡最多吃 420dp，超出在内部滚，
        // 「取消 / 生成」与预览行留在外面固定。
        // `weight(fill = false)`（2026-11-02 弹层债 #12）：键盘弹起时字段区先收缩、
        // 转内部滚动，按钮行始终在屏内。
        LazyColumn(
            modifier = Modifier
                .weight(1f, fill = false)
                .fillMaxWidth()
                .heightIn(max = rememberCappedSheetHeight(420.dp))
                .scrollEndHaptic()
                .overScrollVertical(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(key = "morning") {
                QuickSectionCard(error = validationError.takeIf { errorSlot == QuickErrorSlot.MORNING }) {
                    NumberField(
                        value = morningCount,
                        onValueChange = onMorningCountChange,
                        label = TimeSchemeManagementStrings.morningSectionCountLabel.text,
                    )
                    Spacer(Modifier.height(12.dp))
                    TimeField(
                        label = TimeSchemeManagementStrings.morningFirstSectionTimeLabel.text,
                        value = morningStart,
                        onClick = onPickMorningStart,
                    )
                }
            }
            item(key = "afternoon") {
                QuickSectionCard(error = validationError.takeIf { errorSlot == QuickErrorSlot.AFTERNOON }) {
                    NumberField(
                        value = afternoonCount,
                        onValueChange = onAfternoonCountChange,
                        label = TimeSchemeManagementStrings.afternoonSectionCountLabel.text,
                    )
                    Spacer(Modifier.height(12.dp))
                    TimeField(
                        label = TimeSchemeManagementStrings.afternoonFirstSectionTimeLabel.text,
                        value = afternoonStart,
                        onClick = onPickAfternoonStart,
                    )
                }
            }
            item(key = "evening") {
                QuickSectionCard(error = validationError.takeIf { errorSlot == QuickErrorSlot.EVENING }) {
                    NumberField(
                        value = eveningCount,
                        onValueChange = onEveningCountChange,
                        label = TimeSchemeManagementStrings.eveningSectionCountLabel.text,
                    )
                    Spacer(Modifier.height(12.dp))
                    TimeField(
                        label = TimeSchemeManagementStrings.eveningFirstSectionTimeLabel.text,
                        value = eveningStart,
                        onClick = onPickEveningStart,
                    )
                }
            }
            item(key = "rhythm") {
                QuickSectionCard(error = validationError.takeIf { errorSlot == QuickErrorSlot.RHYTHM }) {
                    NumberField(
                        value = classDuration,
                        onValueChange = onClassDurationChange,
                        label = TimeSchemeManagementStrings.classDurationMinutesLabel.text,
                    )
                    Spacer(Modifier.height(12.dp))
                    NumberField(
                        value = breakDuration,
                        onValueChange = onBreakDurationChange,
                        label = TimeSchemeManagementStrings.smallBreakDurationMinutesLabel.text,
                    )
                }
            }
            item(key = "breakRules") {
                QuickSectionCard(error = validationError.takeIf { errorSlot == QuickErrorSlot.BREAK_RULES }) {
                    Text(
                        text = TimeSchemeManagementStrings.largeBreakRulesTitle.text,
                        style = MiuixTheme.textStyles.main,
                    )
                    Spacer(Modifier.height(8.dp))
                    if (breakRules.isEmpty()) {
                        // Dart `:303-309`：一条规则都没有时给这句，不是自造空态。
                        Text(
                            text = TimeSchemeManagementStrings.noLargeBreakRulesHint.text,
                            style = MiuixTheme.textStyles.footnote1,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        )
                    } else {
                        for ((index, draft) in breakRules.withIndex()) {
                            BreakRuleRow(
                                draft = draft,
                                onChange = { next -> onBreakRuleChange(index, next) },
                                onRemove = { onRemoveBreakRule(index) },
                            )
                            if (index < breakRules.lastIndex) {
                                Spacer(Modifier.height(8.dp))
                            }
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    // 行内「新增一行」的文字行（原来是整颗实心按钮，压在大课间卡底下很重）。
                    BasicComponent(
                        title = TimeSchemeManagementStrings.addBreakRuleAction.text,
                        onClick = onAddBreakRule,
                    )
                }
            }
        }

        // 实时预览：参数不全时整行不画（错误提示由上面的卡承担，不在这里重复一句）。
        if (!previewSummary.isNullOrBlank()) {
            Spacer(Modifier.height(12.dp))
            Text(
                text = previewSummary,
                style = MiuixTheme.textStyles.footnote1,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }

        Spacer(Modifier.height(20.dp))
        // 取消 / 生成两颗**实心块钮**（secondary / primary）：与对话框动作同一口径，
        // 不再一轻一重（原来取消是文字钮）。
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Button(
                modifier = Modifier.weight(1f),
                onClick = onCancel,
                colors = ButtonDefaults.buttonColors(),
            ) {
                Text(text = TimeSchemeManagementStrings.cancelAction.text)
            }
            Button(
                modifier = Modifier.weight(1f),
                onClick = onConfirm,
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = TimeSchemeManagementStrings.generateAction.text)
            }
        }
    }
}

/**
 * 一张分组卡：里面是这一组的行，[error] 非 null 时在卡内底部挂一行红字。
 *
 * 为什么错误挂在卡内而不是底部：卡本身就在说「这几个字段是一组」，
 * 提示落在同一张卡里，用户不用回读整张表单找是哪一格。
 */
@Composable
private fun QuickSectionCard(
    error: String?,
    content: @Composable ColumnScope.() -> Unit,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
        Column(modifier = Modifier.fillMaxWidth(), content = content)
        if (!error.isNullOrBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = error,
                style = MiuixTheme.textStyles.footnote1,
                color = MiuixTheme.colorScheme.error,
            )
        }
    }
}

/** 校验错误挂在哪张卡上（重做新增；见 [QuickGenerateForm] KDoc 第 3 条）。 */
private enum class QuickErrorSlot { MORNING, AFTERNOON, EVENING, RHYTHM, BREAK_RULES }

/** 判据层「哪一格没填好」→ 渲染层「挂哪张卡」。两套枚举分开是为了让 app/ 判据零 Compose 依赖。 */
private fun QuickGenerateField.toErrorSlot(): QuickErrorSlot = when (this) {
    QuickGenerateField.MORNING -> QuickErrorSlot.MORNING
    QuickGenerateField.AFTERNOON -> QuickErrorSlot.AFTERNOON
    QuickGenerateField.EVENING -> QuickErrorSlot.EVENING
    QuickGenerateField.RHYTHM -> QuickErrorSlot.RHYTHM
}


/**
 * 时间滚轮页：「时 0-23」「分 0-59 步长 5」两列官方 `NumberPicker` + 取消 / 确认。
 *
 * 分钟为什么是 `0..11` 的档位而不是 `0..59`：`NumberPicker` 的 `range` 是**逐 1 递增**的整数区间，
 * 没有步长参数。要让「分」只能选 0/5/10…55，就用 12 个档位、`label` 里乘回 5——
 * 屏幕上看到的仍是 `00`、`05`…`55`，与 Dart `showMiuixTimePickerSheet` 的分钟步长一致。
 *
 * 小时上限 23（与 Dart 一致）：本弹层只选**起始时间**，不涉及 `24:00` 哨兵（见文件头）。
 */
@Composable
private fun QuickGenerateTimePickerPage(
    hour: Int,
    onHourChange: (Int) -> Unit,
    minuteIndex: Int,
    onMinuteIndexChange: (Int) -> Unit,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NumberPicker(
                value = hour,
                onValueChange = onHourChange,
                range = 0..23,
                wrapAround = true,
                label = { it.toString().padStart(2, '0') },
                // 220dp + title3 SEMIBOLD 与 SettingsHost「每天更新时刻」滚轮同款
                // （Dart 同弹层就是 title3 + w600）——弹层债 #3 同款顺手对齐。
                textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                modifier = Modifier.weight(1f),
            )
            NumberPicker(
                value = minuteIndex,
                onValueChange = onMinuteIndexChange,
                range = 0..11,
                wrapAround = true,
                // 档位 → 分钟：0 → "00"、1 → "05" … 11 → "55"。
                label = { (it * QuickTimeField.MINUTE_STEP).toString().padStart(2, '0') },
                textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(16.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 取消 = 只退回表单页，**不关整个弹层**（用户填了一半不该被清掉）。
            // 两颗都是实心块钮（secondary / primary），与表单页、对话框动作同一口径。
            Button(
                modifier = Modifier.weight(1f),
                onClick = onCancel,
                colors = ButtonDefaults.buttonColors(),
            ) {
                Text(text = TimeSchemeManagementStrings.cancelAction.text)
            }
            Button(
                modifier = Modifier.weight(1f),
                onClick = onConfirm,
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                // Dart 的时间选择器两个按钮是 `cancelAction` / `confirmAction`
                //（`lib/widgets/miuix_time_picker_sheet.dart:114`、`:124`），这里同口径。
                Text(text = TimeSchemeManagementStrings.confirmAction.text)
            }
        }
    }
}

/** 数字字段：miuix `TextField` + 数字键盘，非数字字符在入口就滤掉（Dart `keyboardType: number` 同义）。 */
@Composable
private fun NumberField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
) {
    TextField(
        value = value,
        onValueChange = { raw ->
            // 只留数字、最多两位：键盘类型挡不住粘贴与部分输入法，这里再兜一层，
            // 但**不**在空值上做补救——空值要留给 `_submit` 报「请把节数和时长填写为数字」。
            onValueChange(raw.filter { it.isDigit() }.take(2))
        },
        label = label,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = Modifier.fillMaxWidth(),
    )
}

/**
 * 起始时间行：Dart `HyperosPickerField(label:, value:, icon: schedule_outlined)`。
 *
 * 用官方 `BasicComponent`（标题 + 行尾取值 + 整行可点 + 官方按压反馈）承载；
 * 与 Dart 的差异只有外观：Dart 是一个"像输入框"的选值框（带时钟小图标），
 * 这里是一行「标签 → 取值」——点哪儿、点了会弹什么，两者一致。
 */
@Composable
private fun TimeField(
    label: String,
    value: String,
    onClick: () -> Unit,
) {
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
 * 一条大课间规则（Dart `_buildBreakOverrideRows` `:312-346`）：
 * 「第几节后」+「休息时长 分钟」两个数字框 + 右侧删除按钮。
 *
 * 删除按钮用官方 `IconButton`，语义标签取 `deleteRuleTooltip`（Dart `tooltip: deleteRuleTooltip`）。
 */
@Composable
private fun BreakRuleRow(
    draft: QuickBreakRuleDraft,
    onChange: (QuickBreakRuleDraft) -> Unit,
    onRemove: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        TextField(
            value = draft.afterSection,
            onValueChange = { raw -> onChange(draft.copy(afterSection = raw.filter { it.isDigit() }.take(2))) },
            label = TimeSchemeManagementStrings.afterSectionLabel.text,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.weight(1f),
        )
        TextField(
            value = draft.duration,
            onValueChange = { raw -> onChange(draft.copy(duration = raw.filter { it.isDigit() }.take(3))) },
            label = TimeSchemeManagementStrings.breakDurationMinutesLabel.text,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = onRemove) {
            Icon(
                imageVector = MiuixIcons.Delete,
                contentDescription = TimeSchemeManagementStrings.deleteRuleTooltip.text,
                tint = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        }
    }
}

/** 大课间规则的一条草稿（两格都是**原始文本**，非法值要能留在框里让用户改）。 */
private data class QuickBreakRuleDraft(
    val afterSection: String,
    val duration: String,
)

/**
 * 弹层里可以改的三个起始时间。
 *
 * 时间字符串的解析/格式化只服务本弹层（`HH:mm` ⇄ 两列滚轮），与编辑器页
 * 「两跳选时间 + `24:00` 折叠」那套判据无关，所以不放进模型层、也不复用宿主的解析。
 */
private enum class QuickTimeField {
    MORNING,
    AFTERNOON,
    EVENING;

    companion object {
        const val MINUTE_STEP = 5

        // Dart `_TimeSchemeQuickGenerateSheetState` 里的兜底值（`:108-110`）：
        // preset 的三个起始时间为 null 时用这三个。
        const val DEFAULT_MORNING = "08:00"
        const val DEFAULT_AFTERNOON = "14:00"
        const val DEFAULT_EVENING = "19:00"

        /** 容错解析：坏值退回 00:00，滚轮仍能打开（同 Dart `_parseTimeOfDay` 的兜底口径）。 */
        fun parse(value: String): Pair<Int, Int> {
            val parts = value.trim().split(":")
            val hour = parts.getOrNull(0)?.trim()?.toIntOrNull() ?: 0
            val minute = parts.getOrNull(1)?.trim()?.toIntOrNull() ?: 0
            return hour.coerceIn(0, 23) to minute.coerceIn(0, 59)
        }
    }
}

/** 滚轮页标题 = 该字段的标签（与 Dart 传给时间选择器的 `title` 同一句文案）。 */
private fun timeFieldLabel(field: QuickTimeField): String = when (field) {
    QuickTimeField.MORNING -> TimeSchemeManagementStrings.morningFirstSectionTimeLabel.text
    QuickTimeField.AFTERNOON -> TimeSchemeManagementStrings.afternoonFirstSectionTimeLabel.text
    QuickTimeField.EVENING -> TimeSchemeManagementStrings.eveningFirstSectionTimeLabel.text
}
