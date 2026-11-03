package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
 * 第二步：确认开学日期与「课表第 1 周 = 校历第几周」。
 *
 * 形态对齐 Dart `pickImportSemesterConfig`（`import_shared.dart:275`）：标题 +
 * 副标题 + 开学日期行（这里直接嵌官方 `NumberPicker` 三列滚轮，形态同
 * `SettingsSemesterHost` 的开学日期弹层——本仓 miuix 0.9.4 没有月历组件）
 * + 首周滚轮（1~20，对齐旧版 `weekItems` 与初值钳制）+ 平移提示 + 取消/继续。
 * 平移提示实时反映当前选择（旧版同款两条文案）。
 */
@Composable
fun WarehouseSemesterMappingSheet(
    show: Boolean,
    initialStartDate: LocalDate,
    onConfirm: (LocalDate, Int) -> Unit,
    onDismiss: () -> Unit,
) {
    var year by remember(show, initialStartDate) { mutableIntStateOf(initialStartDate.year) }
    var month by remember(show, initialStartDate) { mutableIntStateOf(initialStartDate.monthValue) }
    var day by remember(show, initialStartDate) { mutableIntStateOf(initialStartDate.dayOfMonth) }
    var firstWeek by remember(show, initialStartDate) { mutableIntStateOf(1) }

    val maxDay = YearMonth.of(year, month).lengthOfMonth()
    val safeDay = day.coerceAtMost(maxDay)
    val selectedDate = LocalDate.of(year, month, safeDay)
    val shiftedWeeks = firstWeek - 1

    QingyuSheet(
        show = show,
        title = WarehouseStrings.importConfirmSemesterMappingTitle.zh,
        onDismissRequest = onDismiss,
        maxHeightFraction = 0.75f,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
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
                    value = year,
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
                modifier = Modifier.fillMaxWidth(),
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
            Spacer(modifier = Modifier.height(4.dp))
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
        }
    }
}
