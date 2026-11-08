package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.import.parseImportAccentHex
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * AI 课表图片识别导入页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/ai_image_course_import_screen.dart`：
 * 1. 顶部栏返回导航；
 * 2. AI 识图三步指引卡片（复制提示词、发送给AI专家模式、粘贴返回的JSON）；
 * 3. 提示词复制与剪贴板快速操作；
 * 4. 多行 JSON 输入框与实时解析校验；
 * 5. 解析预览卡片与底部导入确认栏。
 *
 * ## 样式（2026-10-28 对齐官方 demo）
 *
 * 骨架 / 顶栏 / 返回键走 `QingyuPageScaffold`（R1），页面级滚动走 `QingyuPageList`（R2，
 * 内含官方滚动三件套与右侧滚动条），卡片走 `QingyuCard`（R3，可点卡片才有按压反馈），
 * 字号走 `MiuixTheme.textStyles`（R4）。紫色强调色取域内色板
 * [parseImportAccentHex]（与 Dart `HyperosIconColors.purple` 同源），不再写字面色值（R5）。
 */
@Composable
fun AiImageCourseImportPage(
    onBack: () -> Unit = {},
    isImporting: Boolean = false,
    onCopyPrompt: () -> Unit = {},
    onShowPromptSheet: () -> Unit = {},
    onPasteFromClipboard: () -> String = { "" },
    onConfirmImport: (AiCourseImportParseResult) -> Unit = {},
) {
    var rawJsonInput by remember { mutableStateOf("") }
    var parseResult by remember { mutableStateOf<AiCourseImportParseResult?>(null) }
    var parseError by remember { mutableStateOf<String?>(null) }

    // Dart 侧 AI 徽标用 HyperosIconColors.purple；取域内色板而不是字面量，深色模式与换主题色时不脱节。
    val aiAccent = Color(parseImportAccentHex("purple"))

    val workflowSteps = remember {
        splitWorkflowArrowTitle(WarehouseStrings.aiWorkflowTitle.text).ifEmpty {
            listOf("复制提示词", "豆包专家模式识别", "复制JSON返回导入")
        }
    }

    fun parseCurrentInput() {
        if (rawJsonInput.trim().isEmpty()) {
            parseResult = null
            parseError = WarehouseStrings.aiPasteJsonFirst.text
            return
        }
        val result = parseAiImageImportJson(rawJsonInput)
        if (result.isValid) {
            parseResult = result
            parseError = null
        } else {
            parseResult = null
            parseError = result.warnings.firstOrNull() ?: WarehouseStrings.aiParseFailedIncompleteJson.text
        }
    }

    // Dart ai_image_course_import_screen.dart:207-209 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    QingyuPageScaffold(
        title = WarehouseStrings.aiImportTitle.text,
        onBack = onBack,
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MiuixTheme.colorScheme.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = ::parseCurrentInput,
                        modifier = Modifier.weight(1f),
                        content = { Text(text = WarehouseStrings.previewAction.text) },
                        colors = ButtonDefaults.buttonColors(
                            color = MiuixTheme.colorScheme.secondary,
                            contentColor = MiuixTheme.colorScheme.primary
                        )
                    )
                    Button(
                        onClick = {
                            parseCurrentInput()
                            parseResult?.let { onConfirmImport(it) }
                        },
                        modifier = Modifier.weight(1f),
                        content = { Text(text = if (isImporting) "导入中..." else WarehouseStrings.confirmImportAction.text) },
                        enabled = !isImporting
                    )
                }
            }
        }
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            // 工作流指引卡片
            item(key = "workflow_guide") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(aiAccent.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "✨",
                                    style = MiuixTheme.textStyles.title4
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = WarehouseStrings.importMethodAiTitle.text,
                                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD)
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = WarehouseStrings.aiWorkflowSubtitle.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))
                        HorizontalDivider()
                        Spacer(modifier = Modifier.height(14.dp))

                        // 步骤流
                        for ((index, step) in workflowSteps.withIndex()) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(22.dp)
                                        .clip(CircleShape)
                                        .background(MiuixTheme.colorScheme.primary.copy(alpha = 0.12f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = "${index + 1}",
                                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                                        color = MiuixTheme.colorScheme.primary
                                    )
                                }
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = step,
                                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "💡 ${WarehouseStrings.aiExpertModeSuggestion.text}",
                            style = MiuixTheme.textStyles.footnote1,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                        )
                    }
                }
            }

            // 操作按钮组
            item(key = "prompt_actions") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(top = 14.dp),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = onCopyPrompt,
                            modifier = Modifier.fillMaxWidth(),
                            content = { Text(text = WarehouseStrings.copyAddress.text) }
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = onShowPromptSheet,
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.aiPromptShortAction.text) },
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.secondary,
                                    contentColor = MiuixTheme.colorScheme.primary
                                )
                            )
                            Button(
                                onClick = {
                                    val text = onPasteFromClipboard()
                                    if (text.isNotEmpty()) {
                                        rawJsonInput = text
                                        parseCurrentInput()
                                    }
                                },
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.pasteAction.text) },
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.secondary,
                                    contentColor = MiuixTheme.colorScheme.primary
                                )
                            )
                            Button(
                                onClick = {
                                    rawJsonInput = ""
                                    parseResult = null
                                    parseError = null
                                },
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.clearAction.text) },
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.secondary,
                                    contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions
                                )
                            )
                        }
                    }
                }
            }

            // JSON 输入框
            item(key = "json_input") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(top = 14.dp),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = WarehouseStrings.aiPasteJsonTitle.text,
                            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD)
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = WarehouseStrings.aiPasteJsonHintLong.text,
                            style = MiuixTheme.textStyles.footnote1,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        TextField(
                            value = rawJsonInput,
                            onValueChange = {
                                rawJsonInput = it
                                if (parseResult != null || parseError != null) {
                                    parseResult = null
                                    parseError = null
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            label = WarehouseStrings.aiPasteJsonHintShort.text,
                            useLabelAsPlaceholder = true,
                            minLines = 6,
                            maxLines = 16,
                        )
                    }
                }
            }

            // 错误信息或解析结果预览
            if (parseError != null) {
                item(key = "parse_error") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 14.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "⚠️",
                                style = MiuixTheme.textStyles.body1
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = WarehouseStrings.aiParseFailedChip.text,
                                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
                                    color = MiuixTheme.colorScheme.error
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = parseError!!,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                                )
                            }
                        }
                    }
                }
            } else if (parseResult != null) {
                val res = parseResult!!
                item(key = "parse_summary") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 14.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = WarehouseStrings.aiPreviewCoursesTitle.text,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD)
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            val warningSuffix = if (res.warnings.isNotEmpty()) {
                                WarehouseStrings.aiWarningCountSuffix.filled("count", res.warnings.size.toString())
                            } else ""
                            Text(
                                text = WarehouseStrings.aiPreviewSummary
                                    .filled("count", res.courses.size.toString())
                                    .filled("section", res.requiredSectionCount.toString())
                                    .filled("warningSuffix", warningSuffix),
                                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = MiuixTheme.colorScheme.primary
                            )

                            if (res.warnings.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                for (w in res.warnings) {
                                    Text(
                                        text = "• $w",
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = MiuixTheme.colorScheme.error
                                    )
                                }
                            }
                        }
                    }
                }

                items(res.courses.take(8)) { course ->
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 12.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = course.name,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD)
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "周${course.dayOfWeek} 第${course.startSection}-${course.endSection}节 · ${course.location.ifEmpty { "地点未知" }} · ${course.teacher.ifEmpty { "教师未知" }}",
                                style = MiuixTheme.textStyles.footnote1,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄）：主题包 `QingyuPageTheme(isDark = …)`，
// 字号用 `textScale = …`（不用 `@Preview(fontScale = …)`，后者绕过 appTextScale 口径），
// 宽度 400dp 是本仓折行实测口径。
//
// 局限：JSON 输入框的文本、解析结果与错误都在页面自己的 `remember` 里，
// 从外面预置不了——所以这里只能看到「空输入框」那一帧，要看解析卡片请用真机 / 交互预览。
// ─────────────────────────────────────────────────────────────────────────────

/** 一档预览的公共身体：外观档位 + 导入中开关。 */
@Composable
private fun PreviewAiImageCourseImportPage(
    dark: Boolean = false,
    textScale: Float = 1f,
    isImporting: Boolean = false,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        AiImageCourseImportPage(
            onBack = {},
            isImporting = isImporting,
            onCopyPrompt = {},
            onShowPromptSheet = {},
            onPasteFromClipboard = { "" },
            onConfirmImport = { _ -> },
        )
    }
}

@Suppress("unused")
@Preview(name = "1 亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AiImageCourseImportPagePreviewLight() {
    PreviewAiImageCourseImportPage()
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AiImageCourseImportPagePreviewDark() {
    PreviewAiImageCourseImportPage(dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AiImageCourseImportPagePreviewLargeText() {
    PreviewAiImageCourseImportPage(textScale = 1.3f)
}

@Suppress("unused")
@Preview(name = "4 导入中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AiImageCourseImportPagePreviewImporting() {
    PreviewAiImageCourseImportPage(isImporting = true)
}
