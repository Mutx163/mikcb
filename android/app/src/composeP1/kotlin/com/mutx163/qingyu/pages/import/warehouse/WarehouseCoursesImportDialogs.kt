package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.YearMonth

/**
 * 课程导入写回前的两步确认（对齐 Dart
 * `warehouse_adapter_web_login_screen.dart` 的 `askImportReplaceExisting` +
 * `pickImportSemesterConfig`，F32 的 courses 链路缺的就是这两问）。
 *
 * ## 取消语义（照抄旧版）
 *
 * 任一步取消 = **中止整次导入**：不写回、提示「已取消导入」、导入执行期结束。
 * `saveImportedCourses` 在网页侧不是 Promise（发完就返回 true），所以取消
 * 不需要对网页回话——这与 confirm/prompt 那组对话框不同。
 *
 * ## 弹层纪律
 *
 * 两个弹层都常驻组合、`show` 由宿主驱动；本层无可空载荷（计数/日期都是非空
 * 参数），退场动画期间无塌空面。`OverlayDialog` 显式 16dp insideMargin。
 */

/** 弹层里可选的开学日期范围（对齐旧版日期选择器 `DateTime(2020)`~`DateTime(2035)`）。 */
private val IMPORT_START_DATE_YEAR_RANGE = 2020..2035

/**
 * 第一步：有旧课表时问「覆盖导入还是更新课表」。
 *
 * 空课表时宿主不弹这一步、直接按替换走（对齐旧版 `provider.courses.isEmpty
 * ? true : ask…`）。三动作与旧版同序：取消 / 更新课表（=合并，推荐）/
 * 覆盖导入（=替换）。旧版正文还拼了一句硬编码说明（非 ARB 文案），本层不抄。
 */
@Composable
fun WarehouseReplaceExistingDialog(
    show: Boolean,
    courseCount: Int,
    onPick: (Boolean) -> Unit,
    onCancel: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.courseImportTitle.zh,
        summary = WarehouseStrings.importCourseCountPrompt.filled("count", courseCount.toString()),
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = WarehouseStrings.cancelAction.zh,
                onClick = onCancel,
            )
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = WarehouseStrings.courseImportUpdateRecommendedAction.zh,
                onClick = { onPick(false) },
            )
            Button(
                onClick = { onPick(true) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = WarehouseStrings.courseImportOverwriteAction.zh)
            }
        }
    }
}

/**
 * 第三步（按需）：现有节次表装不下导入课程时，问是否「自动补齐并导入」。
 *
 * 对齐旧版 `ensureImportSectionCapacity`（`import_shared.dart:446`）的确认框：
 * 标题/正文/按钮文字全部取 ARB；取消 = 中止整次导入（旧版同语义，落到
 * 「导入已中断」）。正文数字由宿主填（现节次数 / 需要到的节号）。
 */
@Composable
fun WarehouseSectionExpansionDialog(
    show: Boolean,
    currentSectionCount: Int,
    requiredSectionCount: Int,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.courseImportSectionCountInsufficientTitle.zh,
        summary = WarehouseStrings.courseImportSectionCountInsufficientMessage.filled(
            "current" to currentSectionCount.toString(),
            "required" to requiredSectionCount.toString(),
        ),
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = WarehouseStrings.cancelAction.zh,
                onClick = onCancel,
            )
            Button(
                onClick = onConfirm,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = WarehouseStrings.courseImportAutoFillAndImportAction.zh)
            }
        }
    }
}

/**
 * 第二步：确认开学日期与「课表第 1 周 = 校历第几周」。
 *
 * 形态对齐 Dart `pickImportSemesterConfig`（`import_shared.dart:275`）：标题 +
 * 副标题 + 开学日期 + 首周选择 + 平移提示 + 取消/继续。
 *
 * ## 高度（2026-11-07 用户实报「确定按钮在页面外面」）
 *
 * 内容 = 副标题两行 + 日期滚轮（160dp）+ 首周滚轮（160dp）+ 两行说明 + 平移提示 +
 * 按钮行，天然超过 `maxHeightFraction = 0.75f` 的限高。旧写法没传 `contentScrolls`，
 * `QingyuSheet` 会把**整列**（含按钮）套进一个 `verticalScroll`：按钮排在滚动内容
 * 末尾，首屏看不到，要滚到底才出现——真机观感就是「确定键在页面外」。
 *
 * 修法（两件事同时做，缺一会复发）：
 * 1. `contentScrolls = true`：内容自己管滚动，限高时可视区内的部分可滚到；
 * 2. **按钮行不进滚动区**：发布版（`showHyperosSheet` + `HyperosSheetFrame` +
 *    `SingleChildScrollView`）的按钮在滚动内容末尾、整层可滚——但本仓滚动收口在
 *    `QingyuSheet`，按钮跟着滚的观感是「确认键跑到手指底下」；miuix 官方弹层的
 *    契约是动作固定在面板内。这里按「滚动区 + 固定动作行」重排：滚轮滚，
 *    确定按钮永远在面板内可见。底部让位（手势区）垫在固定件之后（见
 *    `QingyuSheet` KDoc「滚动区下面还有固定件」一段）。
 *
 * 滚轮行文按发布版语义对齐（首周从 1 起、范围 1..20；无课选第 2 周的提示；
 * 平移提示在抬手后反映当前选择）。开学日初值先夹进 `2020..2035`：
 * `NumberPicker` 只夹显示值，不夹状态，存档里的越界日期不在这里夹就会「看到 2020、
 * 写回 2019」。
 */
@Composable
fun WarehouseSemesterMappingSheet(
    show: Boolean,
    initialStartDate: LocalDate,
    onConfirm: (LocalDate, Int) -> Unit,
    onDismiss: () -> Unit,
) {
    var year by remember(show, initialStartDate) {
        mutableIntStateOf(initialStartDate.year.coerceIn(IMPORT_START_DATE_YEAR_RANGE))
    }
    var month by remember(show, initialStartDate) { mutableIntStateOf(initialStartDate.monthValue) }
    var day by remember(show, initialStartDate) { mutableIntStateOf(initialStartDate.dayOfMonth) }
    var firstWeek by remember(show, initialStartDate) { mutableIntStateOf(1) }

    // 存档里的开学日可能落在 2020..2035 之外（旧版本手改 / 还原备份 / 设备时钟停住）。
    // `NumberPicker` 只夹**显示值**，不夹 `year` 状态；不在这里夹，用户看到 2020、
    // 确认后却写回 2019。与 `SemesterSettingsLogic.clampPickerDate` 同口径。
    val safeYear = year.coerceIn(IMPORT_START_DATE_YEAR_RANGE)
    val maxDay = YearMonth.of(safeYear, month).lengthOfMonth()
    val safeDay = day.coerceAtMost(maxDay)
    val selectedDate = LocalDate.of(safeYear, month, safeDay)
    val shiftedWeeks = firstWeek - 1

    QingyuSheet(
        show = show,
        title = WarehouseStrings.importConfirmSemesterMappingTitle.zh,
        onDismissRequest = onDismiss,
        maxHeightFraction = 0.75f,
        contentScrolls = true,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // ---- 滚动区：副标题 + 两个滚轮 + 说明 + 平移提示 ----
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f, fill = false)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = WarehouseStrings.importConfirmSemesterMappingSubtitleWarehouse.zh,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    lineHeight = 20.sp,
                )
                Text(
                    text = WarehouseStrings.importSemesterStartDateTitle.zh,
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    NumberPicker(
                        value = safeYear,
                        onValueChange = { year = it },
                        range = IMPORT_START_DATE_YEAR_RANGE,
                        label = { it.toString() },
                        textStyle = MiuixTheme.textStyles.title3,
                        modifier = Modifier.weight(1f),
                    )
                    NumberPicker(
                        value = month,
                        onValueChange = { month = it },
                        range = 1..12,
                        wrapAround = true,
                        label = { it.toString() },
                        textStyle = MiuixTheme.textStyles.title3,
                        modifier = Modifier.weight(1f),
                    )
                    NumberPicker(
                        value = safeDay,
                        onValueChange = { day = it },
                        range = 1..maxDay,
                        wrapAround = true,
                        label = { it.toString() },
                        textStyle = MiuixTheme.textStyles.title3,
                        modifier = Modifier.weight(1f),
                    )
                }
                Text(
                    text = WarehouseStrings.importSemesterStartDateSubtitle.zh,
                    style = MiuixTheme.textStyles.footnote2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
                Text(
                    text = WarehouseStrings.importFirstCourseWeekMappingLabel.zh,
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    NumberPicker(
                        value = firstWeek,
                        onValueChange = { firstWeek = it },
                        range = 1..20,
                        label = { WarehouseStrings.calendarWeekOption.filled("week", it.toString()) },
                        textStyle = MiuixTheme.textStyles.title3,
                        modifier = Modifier.weight(1f),
                    )
                }
                Text(
                    text = WarehouseStrings.importFirstCourseWeekMappingSubtitle.zh,
                    style = MiuixTheme.textStyles.footnote2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
                Text(
                    text = if (shiftedWeeks <= 0) {
                        WarehouseStrings.importSemesterMappingNoShiftHint.zh
                    } else {
                        WarehouseStrings.importSemesterMappingShiftHint.filled(
                            "shiftedWeeks" to shiftedWeeks.toString(),
                            "calendarWeek" to firstWeek.toString(),
                        )
                    },
                    style = MiuixTheme.textStyles.footnote2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            // ---- 固定区：按钮行 + 底部让位（手势区 + 呼吸）----
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = WarehouseStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    onClick = { onConfirm(selectedDate, firstWeek) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(
                        text = WarehouseStrings.spreadsheetImportWarningsContinue.zh,
                        textAlign = TextAlign.Center,
                    )
                }
            }
            Spacer(modifier = Modifier.height(bottomInset))
        }
    }
}
