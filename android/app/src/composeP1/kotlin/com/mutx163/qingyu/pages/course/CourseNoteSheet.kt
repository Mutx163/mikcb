package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课程备注弹层 —— Dart `lib/widgets/course_note_sheet.dart` 的一比一对位件。
 *
 * ## 它是什么
 *
 * 周视图课程操作弹层的「备注」行点进去的那个底栏弹层：**两段输入**
 *
 * 1. **课程简介**（`courseNoteWholeCourse*`）—— 同名课程共享，长期保留；
 * 2. **本节课备注**（`courseNoteSession*`）—— 只对本次传入的 `week` 生效。
 *
 * ## 分层（本文件只画不算）
 *
 * 初值口径、副标题拼装、只读门控、保存载荷归一化全在
 * [CourseNoteModel]（纯 Kotlin，JVM 可测）。这里只负责把它们摆上屏，
 * 并把用户点「保存」时的两段**文本**交给宿主。
 *
 * ## ⚠️ 不写库：保存只回传文本
 *
 * [onSave] 只给 `wholeNote` / `sessionNote` 两个 `String?`（`null` = 该段被清空）。
 * 落库是宿主（`CourseActionDispatcher.saveCourseNotes`）的事，且宿主**必须**照 Dart
 * `course_note_sheet.dart:160-175` 做四件事：
 *
 * 1. `description` 写共享简介（`wholeNote`）；`note = null` 清掉 legacy 字段（避免双字段漂移）；
 * 2. `sessionNotes[week]` 写本节备注；
 * 3. **`hasHomework` 保留原值** —— `CourseSessionNote(text = sessionNote ?: "",
 *    hasHomework = 旧值)`，不能写死 `false`（否则用户只改一句备注就清掉了本周的作业标记，
 *    对应的 `homeworkMark` 作业下次重算会消失）。详见 [CourseNoteSave] 的注释；
 * 4. 写失败时**不关弹层**、内容留在输入框里让用户重试，并提示 `saveFailed`
 *    （Dart `:181-196` 就是这个形状）。
 *
 * 因此本组件**保存后不自己关**：关不关、失败怎么提示，由宿主决定（宿主成功后再把
 * `show` 置 false）。
 *
 * ## 与 Dart 的已知差异（诚实清单）
 *
 * - **容器**：Dart 用 `showHomeHyperosSheet`（HyperOS 底栏弹层）；这里用 miuix 官方
 *   `OverlayBottomSheet`（与 `CourseActionSheet` / `SettingsSemesterHost` 同一对位件）。
 *   `title` 传 `null`：Dart 的标题是正文里自绘的「课程备注 + 副标题」两行，容器标题会重复。
 * - **限高**：Dart 算的是 `(屏高 - 键盘 - 状态栏) * 0.9`，clamp 到 `[280, 屏高*0.88]`；
 *   这里取「屏高 × 0.88」当上限（键盘部分交给 `imePadding()`，不再重复扣）。
 * - **键盘避让**：Dart 用 `didChangeMetrics` + `Scrollable.ensureVisible(alignment: 0.9)`；
 *   这里用 `imePadding()`（把弹层整体抬到键盘之上）+ `BringIntoViewRequester`
 *   （聚焦后把输入框滚进可视区）。对齐比例 0.9 那点差异没有复刻。
 * - **保存中态**：Dart 有 `_isSaving`（保存中按钮转圈并禁用）。这里不写库，所以没有
 *   异步中态；宿主若要防连点，自己用壳里的状态禁 `onSave` 重入。
 *
 * @param show 是否显示；`false` 时弹层收起。
 * @param course 要编辑备注的课程；`null` = 关闭（与 `show` 同时为真才渲染内容）。
 * @param week 当前浏览的教学周（决定「本节课备注」读写哪一条，也进副标题与说明句）。
 * @param readOnly 只读（对方课程）：顶部不显示，按 Dart 只是「输入框禁编辑 + 无保存按钮 +
 *   底部一行只读说明」。
 * @param onDismiss 关闭请求（点空白 / 返回手势 / 点「取消」）。
 * @param onSave 保存回调：两段文本（已 `trim`，空 → `null`）。**只回传文本，不写库**。
 */
@Composable
fun CourseNoteSheet(
    show: Boolean,
    course: Course?,
    week: Int,
    readOnly: Boolean,
    onDismiss: () -> Unit,
    onSave: (wholeNote: String?, sessionNote: String?) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val editable = CourseNoteModel.isEditable(readOnly)

    // 初值在「换课 / 换周 / 重新打开」时重算：Dart 每次打开都是新 State（`initState` 重算），
    // 这里用 `show` 当 key 复刻这条——收起再打开会回到库里的值，而不是上一次的草稿。
    val initial = remember(course?.id, week, show) { CourseNoteModel.initialDraft(course, week) }
    var wholeText by remember(course?.id, week, show) { mutableStateOf(initial.wholeNote) }
    var sessionText by remember(course?.id, week, show) { mutableStateOf(initial.sessionNote) }

    val focusManager = LocalFocusManager.current
    // 弹层自身的滚动：R2「页面级滚动必须 QingyuPageList」不适用于弹层内部
    // （规则文档 §二 R2 的豁免原文：弹层/抽屉内部的短列表不承载页面级滚动），
    // 所以这里照 Dart 的 SingleChildScrollView 用普通滚动，不引 LazyColumn。
    val scrollState = rememberScrollState()
    val wholeRequester = remember { BringIntoViewRequester() }
    val sessionRequester = remember { BringIntoViewRequester() }
    val wholeInteraction = remember { MutableInteractionSource() }
    val sessionInteraction = remember { MutableInteractionSource() }
    val wholeFocused by wholeInteraction.collectIsFocusedAsState()
    val sessionFocused by sessionInteraction.collectIsFocusedAsState()

    // 键盘避让的第二半：聚焦后把输入框滚进可视区（Dart `_scrollFocusedFieldIntoView`）。
    LaunchedEffect(wholeFocused, sessionFocused) {
        when {
            wholeFocused -> wholeRequester.bringIntoView()
            sessionFocused -> sessionRequester.bringIntoView()
        }
    }

    QingyuSheet(
        show = show && course != null,
        // 内容自己给左右 16，所以框架侧横向内边距归零（否则单边 24+16 = 40，
        // 内容会被挤成中间窄条）。顶部不再另加 16dp：miuix 上游无标题时本就留
        // 42dp（把手 24 + 空标题行 18，见 QingyuSheet KDoc），再叠就是 58dp。
        // 底部让位与键盘让位由套件统一处理。
        contentPadsHorizontally = true,
        // 限高上限：屏高 × 0.88（Dart `:209-212` 的上界）。
        maxHeightFraction = SHEET_MAX_HEIGHT_RATIO,
        // 聚焦后滚进可视区要操作**可见的那个**滚动状态，所以传进去。
        scrollState = scrollState,
        onDismissRequest = onDismiss,
    ) {
        if (course == null) return@QingyuSheet

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp),
        ) {
            // ── 头部：44dp 圆角色块 + 标题 + 副标题（Dart `:231-268`）──
            Row(modifier = Modifier.fillMaxWidth()) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(
                            color = colors.primary.copy(alpha = 0.12f),
                            shape = RoundedCornerShape(14.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = MiuixIcons.Notes,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = colors.primary,
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = CourseNoteStrings.courseNoteSheetTitle.text,
                        style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = primaryText,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = CourseNoteModel.subtitle(course, week),
                        style = MiuixTheme.textStyles.footnote2,
                        color = secondaryText,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))

            // ── 第一段：课程简介（同名课程共享）Dart `:270-288` ──
            NoteFieldLabel(
                label = CourseNoteStrings.courseNoteWholeCourseLabel.text,
                hint = CourseNoteStrings.courseNoteWholeCourseHint.text,
                primaryText = primaryText,
                secondaryText = secondaryText,
            )
            Spacer(modifier = Modifier.height(8.dp))
            TextField(
                value = wholeText,
                onValueChange = { wholeText = it },
                label = CourseNoteStrings.courseNoteWholeCoursePlaceholder.text,
                useLabelAsPlaceholder = true,
                enabled = editable,
                minLines = 2,
                maxLines = 4,
                interactionSource = wholeInteraction,
                modifier = Modifier
                    .fillMaxWidth()
                    .bringIntoViewRequester(wholeRequester),
            )
            Spacer(modifier = Modifier.height(18.dp))

            // ── 第二段：本节课备注（只对本周年有效）Dart `:290-308` ──
            NoteFieldLabel(
                label = CourseNoteStrings.courseNoteSessionLabel.text,
                hint = CourseNoteStrings.sessionHint(week),
                primaryText = primaryText,
                secondaryText = secondaryText,
            )
            Spacer(modifier = Modifier.height(8.dp))
            TextField(
                value = sessionText,
                onValueChange = { sessionText = it },
                label = CourseNoteStrings.courseNoteSessionPlaceholder.text,
                useLabelAsPlaceholder = true,
                enabled = editable,
                minLines = 2,
                maxLines = 4,
                interactionSource = sessionInteraction,
                modifier = Modifier
                    .fillMaxWidth()
                    .bringIntoViewRequester(sessionRequester),
            )

            // ── 只读说明（Dart `:309-312`）──
            if (readOnly) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = CourseNoteStrings.courseNoteReadOnlyNotice.text,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // ── 底部按钮：取消（次）/ 保存（主，只读态不渲染）Dart `:314-337` ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = CourseNoteStrings.cancelAction.text,
                    onClick = onDismiss,
                )
                if (editable) {
                    Button(
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColorsPrimary(),
                        onClick = {
                            // Dart `:153`：先收键盘再保存。
                            focusManager.clearFocus()
                            val payload = CourseNoteDraft(
                                wholeNote = wholeText,
                                sessionNote = sessionText,
                            ).savePayload
                            onSave(payload.wholeNote, payload.sessionNote)
                        },
                    ) {
                        Text(text = CourseNoteStrings.courseNoteSaveAction.text)
                    }
                }
            }
        }
    }
}

/**
 * 一段的标题 + 说明（Dart `_buildSectionLabel` `:344-362`）。
 *
 * 左对齐两行：标题用 14sp（`body2`，对应 Dart `typo.sm`），说明用 11sp 次要色
 * （`footnote2`，对应 Dart `muted` = `typo.xs2 + mutedForeground`），说明最多两行省略。
 */
@Composable
private fun NoteFieldLabel(
    label: String,
    hint: String,
    primaryText: Color,
    secondaryText: Color,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = primaryText,
        )
        Spacer(modifier = Modifier.height(3.dp))
        Text(
            text = hint,
            style = MiuixTheme.textStyles.footnote2,
            color = secondaryText,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** 弹层最大高度占屏高的比例（Dart `course_note_sheet.dart:209-212` 的上界 0.88）。 */
private const val SHEET_MAX_HEIGHT_RATIO = 0.88f
