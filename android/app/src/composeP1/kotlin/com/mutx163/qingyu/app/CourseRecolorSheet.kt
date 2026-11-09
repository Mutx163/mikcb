package com.mutx163.qingyu.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.pages.import.CourseRecolorHistoryState
import com.mutx163.qingyu.pages.import.CourseRecolorHistoryStore
import com.mutx163.qingyu.pages.import.CourseRecolorScheme
import com.mutx163.qingyu.pages.import.ImportRandomColorStore
import com.mutx163.qingyu.pages.import.ImportSharedModel
import com.mutx163.qingyu.pages.import.ImportStrings
import com.mutx163.qingyu.pages.import.applyCourseRecolorScheme
import com.mutx163.qingyu.pages.import.buildCourseRecolorGroupKey
import com.mutx163.qingyu.pages.import.captureCourseRecolorSnapshot
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDateTime
import kotlin.random.Random

/**
 * 「课表重新配色」底部弹层（Dart `lib/widgets/course_recolor_sheet.dart`，457 行）。
 *
 * ## 功能
 *
 * - **换一批颜色**：生成一套新的随机配色立即生效并落盘；
 * - **上一套 / 下一套**：在配色历史里往返（首次换色前自动存导入原色快照）；
 * - **颜色组**：与导入随机配色共用同一份偏好（`ImportRandomColorStore`）；
 * - **历史按课表档案隔离**：切课表互不串色。
 *
 * ## 顺序（不是随手写的）
 *
 * 与 Dart 同口径：**先落历史、再应用课程颜色**。`applyCourseRecolors` 内部会把课程颜色
 * 持久化；若先应用后存历史，两步之间进程被杀会留下「颜色已变、历史未存」，首次换色时
 * 导入原色快照就此永久丢失。反过来最坏只是多存一条尚未应用的方案，下一拍可自愈。
 *
 * ## 失败语义
 *
 * - 历史落盘失败 → 提示「保存失败」，不应用颜色；
 * - 课程颜色落盘失败 → 仓储先写后改内存，内存不变；这里把刚追加的方案撤回、历史游标
 *   回到原处，再提示「保存失败」。不留下「历史指向新方案、屏上还是旧色」的错位。
 *
 * @param repository 课表仓储（读课程、批量写色）。
 * @param colorStore 随机配色偏好（颜色组 / 文字色开关）。
 * @param historyStore 配色历史（按 profile 作用域隔离）。
 * @param onDismiss 关闭弹层。
 * @param onToast 轻提示（空课表 / 保存失败）。
 */
@Composable
fun CourseRecolorSheetHost(
    repository: TimetableRepository,
    colorStore: ImportRandomColorStore,
    historyStore: CourseRecolorHistoryStore,
    onDismiss: () -> Unit,
    onToast: (String) -> Unit,
) {
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    val profileScope = snapshot.activeProfileId ?: DEFAULT_PROFILE_SCOPE
    var history by remember(profileScope) { mutableStateOf(historyStore.load(profileScope)) }
    var groupId by remember { mutableStateOf(colorStore.groupId()) }
    var busy by remember { mutableStateOf(false) }
    var pickingGroup by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    // 空课表：Dart 只 toast、不弹层。这里在画弹层之前就退出，避免闪一下空面板。
    if (snapshot.courses.isEmpty()) {
        LaunchedEffect(Unit) {
            onToast(SettingsStrings.courseRecolorNoCoursesToast.text)
            onDismiss()
        }
        return
    }

    fun applyNewBatch() {
        if (busy) return
        val courses = snapshot.courses
        if (courses.isEmpty()) {
            onToast(SettingsStrings.courseRecolorNoCoursesToast.text)
            return
        }
        busy = true
        coroutineScope.launch {
            val previous = history
            val schemes = previous.schemes.toMutableList()
            if (schemes.isEmpty()) {
                // 首次换色：先把当前（导入原）颜色存成快照，永远有路可回。
                schemes.add(captureCourseRecolorSnapshot(courses))
            } else if (previous.index < schemes.size - 1) {
                // 从历史中途换新：丢弃被放弃的前向分支（undo/redo 语义）。
                while (schemes.size > previous.index + 1) {
                    schemes.removeAt(schemes.size - 1)
                }
            }
            val scheme = CourseRecolorScheme.Seed(
                seed = Random.nextInt(Int.MAX_VALUE),
                colorGroupId = groupId,
                assignMatchingTextColor = colorStore.isTextColorEnabled(),
                createdAt = LocalDateTime.now(),
            )
            schemes.add(scheme)
            val targetIndex = schemes.size - 1

            val saved = withContext(Dispatchers.IO) {
                historyStore.save(profileScope, schemes, targetIndex)
            }
            if (!saved) {
                busy = false
                onToast(SettingsStringsExt2.saveFailed.text)
                return@launch
            }

            val applied = runCatching {
                withContext(Dispatchers.IO) {
                    repository.applyCourseRecolors(applyCourseRecolorScheme(courses, scheme))
                }
            }
            if (applied.isFailure) {
                // 仓储已回滚课程颜色；历史也撤回刚追加的这一条，避免「指向新方案、屏上旧色」。
                schemes.removeAt(schemes.size - 1)
                withContext(Dispatchers.IO) {
                    historyStore.save(profileScope, schemes, previous.index.coerceAtLeast(-1))
                }
                busy = false
                onToast(SettingsStringsExt2.saveFailed.text)
                return@launch
            }

            history = CourseRecolorHistoryState(schemes = schemes, index = targetIndex)
            busy = false
        }
    }

    fun move(delta: Int) {
        if (busy) return
        val previous = history
        val target = previous.index + delta
        if (target !in previous.schemes.indices) return
        val courses = snapshot.courses
        if (courses.isEmpty()) {
            onToast(SettingsStrings.courseRecolorNoCoursesToast.text)
            return
        }
        val scheme = previous.schemes[target]
        busy = true
        coroutineScope.launch {
            // 与「换一批」同口径：先落历史再应用，避免中间态丢历史。
            val saved = withContext(Dispatchers.IO) {
                historyStore.save(profileScope, previous.schemes, target)
            }
            if (!saved) {
                busy = false
                onToast(SettingsStringsExt2.saveFailed.text)
                return@launch
            }
            val applied = runCatching {
                withContext(Dispatchers.IO) {
                    repository.applyCourseRecolors(applyCourseRecolorScheme(courses, scheme))
                }
            }
            if (applied.isFailure) {
                withContext(Dispatchers.IO) {
                    historyStore.save(profileScope, previous.schemes, previous.index)
                }
                busy = false
                onToast(SettingsStringsExt2.saveFailed.text)
                return@launch
            }
            history = CourseRecolorHistoryState(schemes = previous.schemes, index = target)
            busy = false
        }
    }

    if (pickingGroup) {
        ColorGroupPicker(
            selectedGroupId = groupId,
            onDismiss = { pickingGroup = false },
            onSelect = { selected ->
                groupId = selected
                colorStore.setGroupId(selected)
                pickingGroup = false
            },
        )
        return
    }

    QingyuSheet(
        show = true,
        onDismissRequest = onDismiss,
        title = SettingsStrings.courseRecolorSheetTitle.text,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = SettingsStrings.courseRecolorSheetDescription.text,
                style = MiuixTheme.textStyles.footnote1,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            )
            Spacer(modifier = Modifier.height(12.dp))

            // 当前整份课表的颜色预览：同名一组，按课表出现顺序排布胶囊。
            CourseColorPreview(courses = snapshot.courses)

            Spacer(modifier = Modifier.height(16.dp))

            // 颜色组行：与导入随机配色共用同一份偏好；右侧是当前组名，下方是色点预览。
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { pickingGroup = true }
                    .padding(horizontal = 4.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = ImportStrings.importRandomColorGroupTitle.text,
                        style = MiuixTheme.textStyles.body1,
                        color = MiuixTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    ColorDotsRow(
                        hexes = ImportSharedModel.courseColorGroupPalette(groupId),
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = ImportRandomColorStore.groupLabel(groupId),
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { move(-1) },
                    enabled = history.canGoBack && !busy,
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = SettingsStrings.courseRecolorPrevious.text)
                }
                if (!history.isEmpty) {
                    Text(
                        text = SettingsStrings.courseRecolorSchemePosition.filled(
                            "index" to (history.index + 1).toString(),
                            "total" to history.schemes.size.toString(),
                        ),
                        style = MiuixTheme.textStyles.footnote1,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        maxLines = 1,
                        modifier = Modifier.padding(horizontal = 12.dp),
                    )
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { move(1) },
                    enabled = history.canGoForward && !busy,
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = SettingsStrings.courseRecolorNext.text)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { applyNewBatch() },
                enabled = !busy,
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                if (busy) {
                    CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(text = SettingsStrings.courseRecolorNewBatchButton.text)
            }
        }
    }
}

/** 当前整份课表的颜色预览：同名一组，按课表出现顺序排布胶囊。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CourseColorPreview(courses: List<com.mutx163.qingyu.core.Course>) {
    val seen = linkedSetOf<String>()
    val pills = mutableListOf<Pair<String, String>>()
    for (course in courses) {
        if (seen.add(buildCourseRecolorGroupKey(course))) {
            pills.add(course.name to course.color)
        }
    }
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        for ((name, colorHex) in pills) {
            GroupColorPill(name = name, colorHex = colorHex)
        }
    }
}

/** 一颗「课程名 + 色点」胶囊。 */
@Composable
private fun GroupColorPill(name: String, colorHex: String) {
    val color = parseHexColorOrFallback(colorHex)
    val shape = RoundedCornerShape(percent = 50)
    Row(
        modifier = Modifier
            .clip(shape)
            .background(MiuixTheme.colorScheme.secondaryContainer)
            .border(width = 1.dp, color = MiuixTheme.colorScheme.outline, shape = shape)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
                .border(width = 0.8.dp, color = MiuixTheme.colorScheme.outline, shape = CircleShape),
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = name,
            style = MiuixTheme.textStyles.footnote1,
            color = MiuixTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 160.dp),
        )
    }
}

/** 色点预览：色板过长时按步长抽样，最多 10 个点（Dart `_ColorDotsPreview` 同口径）。 */
@Composable
private fun ColorDotsRow(hexes: List<String>) {
    if (hexes.isEmpty()) return
    val stride = if (hexes.size > MAX_PREVIEW_DOTS) {
        (hexes.size + MAX_PREVIEW_DOTS - 1) / MAX_PREVIEW_DOTS
    } else {
        1
    }
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        var index = 0
        var shown = 0
        while (index < hexes.size && shown < MAX_PREVIEW_DOTS) {
            Box(
                modifier = Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(parseHexColorOrFallback(hexes[index])),
            )
            index += stride
            shown += 1
        }
    }
}

/** 颜色组选择：同一弹层内切页，避免两层 `OverlayBottomSheet` 叠加（见 `QingyuSheet` KDoc）。 */
@Composable
private fun ColorGroupPicker(
    selectedGroupId: String,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
) {
    QingyuSheet(
        show = true,
        onDismissRequest = onDismiss,
        title = ImportStrings.importRandomColorGroupTitle.text,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            for (groupId in ImportRandomColorStore.GROUP_OPTIONS) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { onSelect(groupId) }
                        .padding(horizontal = 4.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = ImportRandomColorStore.groupLabel(groupId),
                            style = MiuixTheme.textStyles.body1,
                            color = MiuixTheme.colorScheme.onSurface,
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        ColorDotsRow(hexes = ImportSharedModel.courseColorGroupPalette(groupId))
                    }
                    if (groupId == selectedGroupId) {
                        Spacer(modifier = Modifier.width(12.dp))
                        Icon(
                            imageVector = MiuixIcons.Ok,
                            contentDescription = null,
                            tint = MiuixTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = SettingsStringsExt4.cancelAction.text,
                onClick = onDismiss,
            )
        }
    }
}

/** 历史作用域的兜底值（档案 id 缺失时；与 Dart `activeProfileId ?? 'default'` 同口径）。 */
private const val DEFAULT_PROFILE_SCOPE = "default"

/** 色点预览最多画几个（Dart `_ColorDotsPreview` 的 `take(10)`）。 */
private const val MAX_PREVIEW_DOTS = 10
