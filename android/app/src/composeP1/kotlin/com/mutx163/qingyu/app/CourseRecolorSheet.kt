package com.mutx163.qingyu.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuColorPreviewDotGap
import com.mutx163.qingyu.components.QingyuColorPreviewDotSize
import com.mutx163.qingyu.components.QingyuLoadingInButton
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.rememberSheetMaxHeight
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
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.preference.ArrowPreference
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
 * ## 观感（2026-11-10 对照 tag v2.1.4.1 重做）
 *
 * 逐条对齐发布版 `course_recolor_sheet.dart` 的真实结构，不是照着「差不多的弹层」拼的：
 *
 * | 位置 | 发布版 | 旧实现（错在哪） | 现在 |
 * |---|---|---|---|
 * | 说明句 | `HyperosSheet(description:)` ⇒ **正文之后**、底部小字（`hyperos_sheet.dart:414-419`） | 当正文第一段放在标题下 | 移到底部，13sp / 1.5 行高 / 次要色，左右各再收 16dp |
 * | 颜色预览区 | 限高 **屏高 × 0.32** 且自带滚动（`:257-266`） | 不限高，课表课程一多就把按钮顶出屏幕 | 限高 + 独立滚动 |
 * | 颜色组 | `HyperosPickerField`：上方 17sp 标签 + 圆角 16 填充框 + 行首色块 + 值 + 行尾箭头（`:272-278`） | 自拼一行「标题 + 色点 + 右侧组名」，没有框体与箭头，看不出能点 | 同款字段：标签 + 填充框 + 色点 + 组名 + 箭头 |
 * | 上一套/下一套 | 次要按钮 + 中间固定 12dp 槽位（`:283-310`） | 位置文字只在非空时占位，两键宽度会跳 | 中间槽位恒定，两键等宽 |
 * | 换一批 | 主按钮，`loading` 时**只用 18dp 转圈替掉文字**（`hyperos_controls.dart:713-722`） | 转圈 + 文字并排 | 同款：加载中只留转圈 |
 * | 选组弹层 | `HyperosChoiceGroup` 白卡 + `HyperosChoiceTile(dialog, showDivider)`：56dp 行、行首标题、色点副标题、选中行尾 22dp 勾（`tiles.dart:544-731`） | 无卡、无分隔线、行高与勾尺寸随手写的 | 白卡 + 行间 0.5dp 分隔线 + 22dp 勾 |
 * | 选组入口 | 第二层弹层 | 清空外层再挂内层 ⇒ 每次切组整块弹层重新进场一次 | 同一弹层内换页（标题跟着换），不再重进场 |
 *
 * ## 与发布版的两处刻意不同
 *
 * 1. **选组不叠第二层弹层**：发布版是「弹层上再弹一层」，Compose 侧两层
 *    `OverlayBottomSheet` 叠挂会各自带遮罩与返回键处理；这里保持**单层换页**
 *    （标题与正文互换），退场只播一次，行为等价（选完回主页面、点空白回主页面）。
 * 2. **选组行首没有调色板图标**：miuix 0.9.4 的 156 个扩展图标里没有调色板字形，
 *    于是用发布版 `HyperosPickerField.leading` 本来就支持的「行首颜色块」槽位
 *    放当前组的色点（`hyperos_text_field.dart:248-251`）——同一处信息，不另造图标。
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

    // 选组页与主页面**共用同一个弹层**（见 KDoc「刻意不同 1」）：只换标题与正文，
    // 不卸载面板——否则切组时整块弹层会重新进场一次，观感就是闪。
    QingyuSheet(
        show = true,
        onDismissRequest = {
            if (pickingGroup) pickingGroup = false else onDismiss()
        },
        title = if (pickingGroup) {
            ImportStrings.importRandomColorGroupTitle.text
        } else {
            SettingsStrings.courseRecolorSheetTitle.text
        },
    ) {
        if (pickingGroup) {
            ColorGroupPickerContent(
                selectedGroupId = groupId,
                onSelect = { selected ->
                    groupId = selected
                    colorStore.setGroupId(selected)
                    pickingGroup = false
                },
            )
        } else {
            Column(modifier = Modifier.fillMaxWidth()) {
                // 当前整份课表的颜色预览：同名一组，按课表出现顺序排布胶囊。
                // 限高 + 自带滚动（Dart `:257-266` 的 0.32 屏高 + SingleChildScrollView）：
                // 课程再多也只占这一段，下面两颗按钮不会被顶出屏幕。
                // ⚠️ 顺序不能反：`heightIn` 必须在 `verticalScroll` **之前**，滚动容器才拿得到
                // 有界高度；反过来会被父级无界高度量出「滚动容器高度无限」而直接崩。
                val previewMaxHeight = rememberSheetMaxHeight(PREVIEW_MAX_HEIGHT_FRACTION)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = previewMaxHeight)
                        .verticalScroll(rememberScrollState()),
                ) {
                    CourseColorPreview(courses = snapshot.courses)
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 颜色组：发布版是同款字段（标签 + 填充框 + 行首色块 + 值 + 箭头），
                // 不是「一行标题加几个点」——后者看不出能点，也看不出当前选的是哪一组。
                ColorGroupField(groupId = groupId, onClick = { pickingGroup = true })

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
                        Text(
                            text = SettingsStrings.courseRecolorPrevious.text,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    // 发布版中间这 12dp 槽位**恒定存在**（空历史时塞 SizedBox.shrink），
                    // 否则有没有位置文字会让两颗按钮宽度跳一下。
                    Box(modifier = Modifier.padding(horizontal = 12.dp)) {
                        if (!history.isEmpty) {
                            Text(
                                text = SettingsStrings.courseRecolorSchemePosition.filled(
                                    "index" to (history.index + 1).toString(),
                                    "total" to history.schemes.size.toString(),
                                ),
                                style = MiuixTheme.textStyles.footnote1,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                maxLines = 1,
                            )
                        }
                    }
                    Button(
                        modifier = Modifier.weight(1f),
                        onClick = { move(1) },
                        enabled = history.canGoForward && !busy,
                        colors = ButtonDefaults.buttonColors(),
                    ) {
                        Text(
                            text = SettingsStrings.courseRecolorNext.text,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { applyNewBatch() },
                    enabled = !busy,
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    // 发布版加载态是「转圈替掉文字」，不是转圈 + 文字并排
                    // （`hyperos_controls.dart:713-722`）；尺寸与取色走全仓 D1 共享件
                    // `QingyuLoadingInButton()`（16dp/2dp、吃按钮自己的内容色），
                    // 不再每处自己写一套——默认主色转圈压在 primary 底上等于隐形。
                    if (busy) {
                        QingyuLoadingInButton()
                    } else {
                        Text(
                            text = SettingsStrings.courseRecolorNewBatchButton.text,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }

                // 说明句在发布版里是弹层**底部**的小字（`HyperosSheet(description:)`，
                // `hyperos_sheet.dart:414-419`），不是标题下的大段落。左右再各收 16dp
                // 是 `HyperosSectionDescription` 自己的口径（`layout.dart:243-252`），
                // 与设置页「组标签 + 卡内文字」的 32dp 左缘对齐，别当成缩进 bug 改掉。
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = SettingsStrings.courseRecolorSheetDescription.text,
                    style = MiuixTheme.textStyles.footnote1,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
        }
    }
}

/**
 * 选组入口字段——**官方组合**，不手搓控件（评审 P6-3）。
 *
 * 发布版这处是 `HyperosPickerField`（`hyperos_text_field.dart:187-315`）：圆角 16 的填充框 +
 * 行首色块 + 取值 + 行尾箭头。Compose 侧按「组件优先」拼成同一块外形：
 *
 * - 外形/填充/圆角 → `QingyuCard`（官方 `Card` 的薄包，圆角 16、零内边距）；
 * - 行本体 → 官方 `ArrowPreference`（标题 + 行首槽 + 行尾动作 + 官方箭头 + 官方按压指示）。
 *
 * 原来这里是自己画 Row + 填充 + 1dp 描边 + `clickable`——点击指示、按钮角色、行高、箭头
 * 全要自己接，正是「自研 UI」。先例：`pages/transfer/PickupCodesPage.kt:158`、
 * `pages/export/IcsExportPage.kt:155`（日期取值行）、`pages/about/AboutUpdatePage.kt:475`。
 *
 * 与发布版的一处差异（刻意）：取值走行尾 `endActions`（保持「标题左、取值右、箭头最后」的
 * 阅读顺序），不额外加「标签在上」那一层——本仓所有取值行都是这个形态。
 */
@Composable
private fun ColorGroupField(
    groupId: String,
    onClick: () -> Unit,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = FIELD_CORNER,
        insideMargin = PaddingValues(0.dp),
    ) {
        ArrowPreference(
            title = ImportStrings.importRandomColorGroupTitle.text,
            startAction = {
                Box(modifier = Modifier.padding(end = 8.dp)) {
                    ColorDotsRow(hexes = ImportSharedModel.courseColorGroupPalette(groupId))
                }
            },
            endActions = {
                Text(
                    text = ImportRandomColorStore.groupLabel(groupId),
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    maxLines = 1,
                )
            },
            onClick = onClick,
        )
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

/**
 * 一颗「课程名 + 色点」胶囊（Dart `_GroupColorPill`，`course_recolor_sheet.dart:396-455`）。
 *
 * 底色是 `secondaryVariant` 而不是 `secondaryContainer`：Dart 那句注释写着
 * 「玻璃弹层里的浅井用 secondaryVariant；`colors.secondary` 是深色 M3 强调色，
 * 浅色弹窗里会像一颗黑块」。字号是发布版的 `xs2` = 11sp，最宽 180dp。
 */
@Composable
private fun GroupColorPill(name: String, colorHex: String) {
    val color = parseHexColorOrFallback(colorHex)
    val shape = RoundedCornerShape(percent = 50)
    Row(
        modifier = Modifier
            .clip(shape)
            .background(MiuixTheme.colorScheme.secondaryVariant)
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
            style = MiuixTheme.textStyles.footnote2,
            color = MiuixTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 180.dp),
        )
    }
}

/**
 * 色点预览：色板过长时按步长抽样，最多 10 个点（Dart `_ColorDotsPreview` 同口径）。
 *
 * 直径与点间距走共享件 `QingyuColorChips.kt` 导出的只读常量
 * （`QingyuColorPreviewDotSize` / `QingyuColorPreviewDotGap`）——它们和可选色块
 * 42/40/36 三档、chip 间距 12dp 是两回事，数字仍是发布版的 14 / 4，只是不再各写一份字面量。
 */
@Composable
private fun ColorDotsRow(
    hexes: List<String>,
    modifier: Modifier = Modifier,
) {
    if (hexes.isEmpty()) return
    val stride = if (hexes.size > MAX_PREVIEW_DOTS) {
        (hexes.size + MAX_PREVIEW_DOTS - 1) / MAX_PREVIEW_DOTS
    } else {
        1
    }
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(QingyuColorPreviewDotGap),
    ) {
        var index = 0
        var shown = 0
        while (index < hexes.size && shown < MAX_PREVIEW_DOTS) {
            Box(
                modifier = Modifier
                    .size(QingyuColorPreviewDotSize)
                    .clip(CircleShape)
                    .background(parseHexColorOrFallback(hexes[index])),
            )
            index += stride
            shown += 1
        }
    }
}

/**
 * 颜色组挑选页（Dart `_pickGroup` + `HyperosChoiceGroup`，`course_recolor_sheet.dart:196-243`）。
 *
 * 与发布版同构：**一组行放在白卡里**，每行「组名 + 色点副标题」，选中行尾 22dp 勾，
 * 行间 0.5dp 分隔线（左缩进 16dp）。行高 56dp / 内边距 16×13 与
 * `pages/import/ImportCommon.kt` 里同一个「颜色组」弹层逐条一致——两个入口点的是
 * 同一份偏好，长得也必须一样。
 *
 * 没有「取消」按钮：发布版与导入侧都是「点一行就选完，点空白返回」。
 */
@Composable
private fun ColorGroupPickerContent(
    selectedGroupId: String,
    onSelect: (String) -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val options = ImportRandomColorStore.GROUP_OPTIONS
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = FIELD_CORNER,
        insideMargin = PaddingValues(0.dp),
    ) {
        options.forEachIndexed { index, groupId ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = GROUP_ROW_MIN_HEIGHT)
                    .clickable { onSelect(groupId) }
                    .padding(
                        horizontal = GROUP_ROW_HORIZONTAL_PADDING,
                        vertical = GROUP_ROW_VERTICAL_PADDING,
                    ),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = ImportRandomColorStore.groupLabel(groupId),
                        style = MiuixTheme.textStyles.main,
                        color = colors.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    // 色点与标题之间 6dp（Dart `_ColorDotsPreview` 自带的 top padding）。
                    ColorDotsRow(
                        hexes = ImportSharedModel.courseColorGroupPalette(groupId),
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                if (groupId == selectedGroupId) {
                    // Dart `HyperosSelectedCheckmark(size = 22)`（dialog 变体）。
                    Spacer(modifier = Modifier.width(GROUP_CHECK_GAP))
                    Icon(
                        imageVector = MiuixIcons.Ok,
                        contentDescription = null,
                        tint = colors.primary,
                        modifier = Modifier.size(GROUP_CHECK_SIZE),
                    )
                }
            }
            if (index != options.lastIndex) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = GROUP_ROW_HORIZONTAL_PADDING),
                    thickness = 0.5.dp,
                    color = colors.dividerLine,
                )
            }
        }
    }
}

/** 历史作用域的兜底值（档案 id 缺失时；与 Dart `activeProfileId ?? 'default'` 同口径）。 */
private const val DEFAULT_PROFILE_SCOPE = "default"

/** 色点预览最多画几个（Dart `_ColorDotsPreview` 的 `take(10)`）。 */
private const val MAX_PREVIEW_DOTS = 10

/** 颜色预览区限高 = 屏高 × 0.32（Dart `course_recolor_sheet.dart:259`）。 */
private const val PREVIEW_MAX_HEIGHT_FRACTION = 0.32f

/** 字段圆角 16（Dart `HyperosMiuixTextField.cornerRadius`）。 */
private val FIELD_CORNER = 16.dp

/** 选组行最小高度 56（Dart `HyperosMiuixSpec.settingsRowMinHeight`）。 */
private val GROUP_ROW_MIN_HEIGHT = 56.dp

/** 选组行左右内边距 16（Dart `HyperosMiuixSpec.settingsRowPadding.left/right`）。 */
private val GROUP_ROW_HORIZONTAL_PADDING = 16.dp

/** 选组行上下内边距 13（Dart `HyperosMiuixSpec.settingsRowPadding.top/bottom`）。 */
private val GROUP_ROW_VERTICAL_PADDING = 13.dp

/** 选中勾 22dp（Dart `HyperosSelectedCheckmark(size = 22)`）。 */
private val GROUP_CHECK_SIZE = 22.dp

/** 勾与内容之间的间隔 6dp（Dart `tiles.dart:657`）。 */
private val GROUP_CHECK_GAP = 6.dp
