package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * AI 课表图片识别导入页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/ai_image_course_import_screen.dart`：
 * 1. 顶部栏返回导航；
 * 2. AI 识图三步指引卡片（复制提示词、发送给AI专家模式、粘贴返回的JSON）；
 * 3. 提示词复制与剪贴板快速操作；
 * 4. 多行 JSON 输入框与实时解析校验；
 * 5. 解析预览卡片与底部导入确认栏。
 */
@Composable
fun AiImageCourseImportPage(
    onBack: () -> Unit = {},
    onCopyPrompt: () -> Unit = {},
    onShowPromptSheet: () -> Unit = {},
    onPasteFromClipboard: () -> String = { "" },
    onConfirmImport: (AiCourseImportParseResult) -> Unit = {},
) {
    var rawJsonInput by remember { mutableStateOf("") }
    var parseResult by remember { mutableStateOf<AiCourseImportParseResult?>(null) }
    var parseError by remember { mutableStateOf<String?>(null) }
    var isImporting by remember { mutableStateOf(false) }

    val workflowSteps = remember {
        splitWorkflowArrowTitle(WarehouseStrings.aiWorkflowTitle.zh).ifEmpty {
            listOf("复制提示词", "豆包专家模式识别", "复制JSON返回导入")
        }
    }

    fun parseCurrentInput() {
        if (rawJsonInput.trim().isEmpty()) {
            parseResult = null
            parseError = WarehouseStrings.aiPasteJsonFirst.zh
            return
        }
        val result = parseAiImageImportJson(rawJsonInput)
        if (result.isValid) {
            parseResult = result
            parseError = null
        } else {
            parseResult = null
            parseError = result.warnings.firstOrNull() ?: WarehouseStrings.aiParseFailedIncompleteJson.zh
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = WarehouseStrings.aiImportTitle.zh,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(imageVector = MiuixIcons.Back, contentDescription = WarehouseStrings.cancelAction.zh)
                    }
                }
            )
        },
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
                        text = WarehouseStrings.previewAction.zh,
                        colors = ButtonDefaults.buttonColors(
                            color = MiuixTheme.colorScheme.surfaceVariant,
                            contentColor = MiuixTheme.colorScheme.primary
                        )
                    )
                    Button(
                        onClick = {
                            parseCurrentInput()
                            parseResult?.let { onConfirmImport(it) }
                        },
                        modifier = Modifier.weight(1f),
                        text = if (isImporting) "导入中..." else WarehouseStrings.confirmImportAction.zh,
                        enabled = !isImporting && parseResult != null
                    )
                }
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 工作流指引卡片
            item(key = "workflow_guide") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF8E24AA).copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "✨",
                                    fontSize = 18.sp
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = WarehouseStrings.importMethodAiTitle.zh,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = WarehouseStrings.aiWorkflowSubtitle.zh,
                                    fontSize = 12.sp,
                                    color = MiuixTheme.colorScheme.onSurfaceVariant
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
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MiuixTheme.colorScheme.primary
                                    )
                                }
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = step,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "💡 ${WarehouseStrings.aiExpertModeSuggestion.zh}",
                            fontSize = 12.sp,
                            color = MiuixTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 操作按钮组
            item(key = "prompt_actions") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = onCopyPrompt,
                            modifier = Modifier.fillMaxWidth(),
                            text = WarehouseStrings.copyAddress.zh
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = onShowPromptSheet,
                                modifier = Modifier.weight(1f),
                                text = WarehouseStrings.aiPromptShortAction.zh,
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
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
                                text = WarehouseStrings.pasteAction.zh,
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
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
                                text = WarehouseStrings.clearAction.zh,
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
                                    contentColor = MiuixTheme.colorScheme.onSurfaceVariant
                                )
                            )
                        }
                    }
                }
            }

            // JSON 输入框
            item(key = "json_input") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = WarehouseStrings.aiPasteJsonTitle.zh,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = WarehouseStrings.aiPasteJsonHintLong.zh,
                            fontSize = 12.sp,
                            color = MiuixTheme.colorScheme.onSurfaceVariant
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
                            placeholder = WarehouseStrings.aiPasteJsonHintShort.zh,
                            minLines = 6,
                            maxLines = 16,
                        )
                    }
                }
            }

            // 错误信息或解析结果预览
            if (parseError != null) {
                item(key = "parse_error") {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "⚠️",
                                fontSize = 16.sp
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = WarehouseStrings.aiParseFailedChip.zh,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = MiuixTheme.colorScheme.error
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = parseError!!,
                                    fontSize = 12.sp,
                                    color = MiuixTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            } else if (parseResult != null) {
                val res = parseResult!!
                item(key = "parse_summary") {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                        ) {
                            Text(
                                text = WarehouseStrings.aiPreviewCoursesTitle.zh,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
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
                                fontSize = 13.sp,
                                color = MiuixTheme.colorScheme.primary,
                                fontWeight = FontWeight.Medium
                            )

                            if (res.warnings.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                for (w in res.warnings) {
                                    Text(
                                        text = "• $w",
                                        fontSize = 12.sp,
                                        color = MiuixTheme.colorScheme.error
                                    )
                                }
                            }
                        }
                    }
                }

                items(res.courses.take(8)) { course ->
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp)
                        ) {
                            Text(
                                text = course.name,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "周${course.dayOfWeek} 第${course.startSection}-${course.endSection}节 · ${course.location.ifEmpty { "地点未知" }} · ${course.teacher.ifEmpty { "教师未知" }}",
                                fontSize = 12.sp,
                                color = MiuixTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}
