package com.mutx163.qingyu.pages.guide

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 启动引导流程页面 · Compose 渲染层。
 * 覆盖：
 * 1. 旧版数据无缝迁移指引（检测到旧版包名时呈现）；
 * 2. 开学日期与当前周次初始化设置；
 * 3. 引导流程状态机流转。
 */
@Composable
fun StartupFlowPage(
    initialState: StartupFlowState = StartupFlowState(),
    onBack: () -> Unit,
    onOpenOldApp: () -> Unit = {},
    onGoImportBackup: () -> Unit = {},
    onFinishStartupFlow: (semesterStartDate: String, totalWeeks: Int) -> Unit = { _, _ -> }
) {
    val stateMachine = remember { StartupFlowStateMachine(initialState) }
    var currentState by remember { mutableStateOf(stateMachine.state) }
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    // 顶栏标题随状态机步骤变化：抽成同一个局部变量喂给 title 与 largeTitle，避免两处各写一遍分叉。
    val pageTitle = when (currentState.currentStep) {
        StartupStep.MIGRATION_CHECK -> GuideStrings.migrationTitle.text
        StartupStep.DATE_SETUP -> GuideStrings.setSemesterStartDateAction.text
        StartupStep.GUIDE_TOUR -> GuideStrings.welcomeTitle.text
        StartupStep.COMPLETED -> GuideStrings.welcomeAppName.text
    }

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃（QingyuPageScaffold 内部三步接线）。
    // 大标题可折叠（Dart 原件 lib/screens/startup_flow_screens.dart:34 走 HyperosSubpage 默认）。
    QingyuPageScaffold(title = pageTitle, onBack = onBack) {
        when (currentState.currentStep) {
            StartupStep.MIGRATION_CHECK -> {
                MigrationGuideContent(
                    innerPadding = innerPadding,
                    scrollBehavior = scrollBehavior,
                    isOpeningOldApp = currentState.isOpeningOldApp,
                    onOpenOldApp = {
                        stateMachine.setOpeningOldApp(true)
                        currentState = stateMachine.state
                        onOpenOldApp()
                        // 立刻复位「正在打开」：宿主那一步是同步的（`startActivity` 发完就返回），
                        // Dart 原件也是在 await 之后 setState 复位（`startup_flow_screens.dart:181-192`）。
                        // 不复位的话按钮会**永久**停在「正在打开旧版……」——用户从旧版回来时
                        // 会看到「正在打开」和「未能打开旧版应用」两句互相矛盾的话。
                        stateMachine.setOpeningOldApp(false)
                        currentState = stateMachine.state
                    },
                    onGoImport = {
                        stateMachine.onMigrationAction(MigrationFlowAction.RESTORE_BACKUP)
                        currentState = stateMachine.state
                        onGoImportBackup()
                    },
                    onSkip = {
                        stateMachine.onMigrationAction(MigrationFlowAction.SKIP)
                        currentState = stateMachine.state
                    }
                )
            }

            StartupStep.DATE_SETUP, StartupStep.GUIDE_TOUR, StartupStep.COMPLETED -> {
                DateSetupContent(
                    innerPadding = innerPadding,
                    scrollBehavior = scrollBehavior,
                    initialDate = currentState.semesterStartDate ?: "2026-09-01",
                    initialWeeks = currentState.totalWeeks,
                    calculatedWeek = currentState.currentWeek,
                    onDateChanged = { newDate ->
                        stateMachine.onUpdateSemesterStartDate(newDate)
                        currentState = stateMachine.state
                    },
                    onWeeksChanged = { newWeeks ->
                        stateMachine.onUpdateTotalWeeks(newWeeks)
                        currentState = stateMachine.state
                    },
                    onConfirm = {
                        if (stateMachine.onCompleteDateSetup()) {
                            currentState = stateMachine.state
                            onFinishStartupFlow(
                                currentState.semesterStartDate ?: "2026-09-01",
                                currentState.totalWeeks
                            )
                        }
                    }
                )
            }
        }
    }
}

/**
 * 迁移步骤卡片内容。
 */
@Composable
private fun MigrationGuideContent(
    innerPadding: PaddingValues,
    scrollBehavior: ScrollBehavior,
    isOpeningOldApp: Boolean,
    onOpenOldApp: () -> Unit,
    onGoImport: () -> Unit,
    onSkip: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    // 折叠手势喂给页面唯一的 scrollBehavior。每一步的内容都是互斥渲染的，
    // 同一时刻只会有一个列表在吃手势，所以每处都接上不会把滚动量送两遍。
    // 官方页面骨架：QingyuPageList（末端轻震 + 过度滚动 + 顶栏联动 + 右侧滚动条）。
    QingyuPageList(
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        horizontalPadding = 16.dp,
        contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // 顶部安心提示卡片
        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.migrationSafeTitle.text,
                        style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                        color = primaryColor
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = GuideStrings.migrationSafeSubtitle.text,
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 20.sp
                    )
                }
            }
        }

        // 迁移三步走
        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    MigrationStepRow(
                        step = 1,
                        title = GuideStrings.migrationStep1Title.text,
                        subtitle = GuideStrings.migrationStep1Subtitle.text
                    )
                    MigrationStepRow(
                        step = 2,
                        title = GuideStrings.migrationStep2Title.text,
                        subtitle = GuideStrings.migrationStep2Subtitle.text
                    )
                    MigrationStepRow(
                        step = 3,
                        title = GuideStrings.migrationStep3Title.text,
                        subtitle = GuideStrings.migrationStep3Subtitle.text
                    )
                }
            }
        }

        // 提示横幅
        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(14.dp)
            ) {
                Row(verticalAlignment = Alignment.Top) {
                    Icon(
                        imageVector = MiuixIcons.Info,
                        contentDescription = null,
                        tint = primaryColor,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = GuideStrings.migrationNoSaveToFilesTitle.text,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = GuideStrings.migrationNoSaveToFilesSubtitle.text,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            lineHeight = 18.sp
                        )
                    }
                }
            }
        }

        // 操作按钮组
        item {
            Spacer(modifier = Modifier.height(8.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onOpenOldApp,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(primaryColor)
                ) {
                    Text(
                        text = if (isOpeningOldApp) GuideStrings.openingOldApp.text else GuideStrings.openOldAppForBackup.text,
                        color = Color.White,
                        style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM)
                    )
                }

                Button(
                    onClick = onGoImport,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(Color(QingyuTheme.card(dark)))
                ) {
                    Text(
                        text = GuideStrings.backupDoneGoImport.text,
                        color = primaryColor,
                        style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM)
                    )
                }

                Button(
                    onClick = onSkip,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(Color.Transparent)
                ) {
                    Text(
                        text = GuideStrings.startFreshWithoutMigration.text,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        style = MiuixTheme.textStyles.body2
                    )
                }
            }
        }
    }
}

/**
 * 步骤序号行。
 */
@Composable
private fun MigrationStepRow(
    step: Int,
    title: String,
    subtitle: String
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(primaryColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "$step",
                color = primaryColor,
                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.BOLD)
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.primaryText(dark))
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                lineHeight = 18.sp
            )
        }
    }
}

/**
 * 开学日期与周次设置界面。
 */
@Composable
private fun DateSetupContent(
    innerPadding: PaddingValues,
    scrollBehavior: ScrollBehavior,
    initialDate: String,
    initialWeeks: Int,
    calculatedWeek: Int,
    onDateChanged: (String) -> Unit,
    onWeeksChanged: (Int) -> Unit,
    onConfirm: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))
    var dateInput by remember { mutableStateOf(initialDate) }
    var weeksValue by remember { mutableIntStateOf(initialWeeks) }

    // 本页主体滚动容器：4 个步骤里 3 个（DATE_SETUP / GUIDE_TOUR / COMPLETED）都渲染这一份，
    // 折叠手势喂给页面唯一的 scrollBehavior。
    // 表单页：imePadding 把整页抬到键盘之上（壳是 edge-to-edge，adjustResize 不生效）。
    QingyuPageList(
        modifier = Modifier.imePadding(),
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        horizontalPadding = 16.dp,
        contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.semesterStartDateLabel.text,
                        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "以开学第一天所在周的周一作为校历第 1 周",
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(14.dp))

                    TextField(
                        value = dateInput,
                        onValueChange = {
                            dateInput = it
                            if (SemesterDateCalculator.isValidDateFormat(it)) {
                                onDateChanged(it)
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }

        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "学期总周数",
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                        Text(
                            text = GuideStrings.currentWeekCompact.filled("week", "$weeksValue"),
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
                            color = primaryColor
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // 常用总周数快速选择
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(16, 18, 20, 24).forEach { w ->
                            val isSelected = w == weeksValue
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(
                                        if (isSelected) primaryColor else primaryColor.copy(alpha = 0.08f)
                                    )
                                    .padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Button(
                                    onClick = {
                                        weeksValue = w
                                        onWeeksChanged(w)
                                    },
                                    colors = ButtonDefaults.buttonColors(Color.Transparent)
                                ) {
                                    Text(
                                        text = "$w 周",
                                        color = if (isSelected) Color.White else primaryColor,
                                        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // 当前周推导结果卡片
        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "当前计算周次",
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.secondaryText(dark))
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = GuideStrings.syncedCurrentWeekMessage.filled("week", "$calculatedWeek"),
                            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                    }

                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(primaryColor.copy(alpha = 0.12f))
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = "第 $calculatedWeek 周",
                            color = primaryColor,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD)
                        )
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onConfirm,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(primaryColor)
            ) {
                Text(
                    text = GuideStrings.guideNextButton.text,
                    color = Color.White,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD)
                )
            }
        }
    }
}

// ── 预览：Android Studio 里免装机看效果（2026-11-08 加）────────────────────
//
// 本页只有两条**看得见**的主分支：
// 1. 迁移检查（`StartupStep.MIGRATION_CHECK`）——检测到旧版包名时才会出现；
// 2. 开学日期（`DATE_SETUP`）——`GUIDE_TOUR` / `COMPLETED` 渲染的是同一个
//    `DateSetupContent`，差别只在顶栏标题，所以不重复铺档。

/** 一档预览：状态名 + 初始状态快照。 */
private data class PreviewStartupState(
    /** 只用来给预览命名，不参与渲染。 */
    val name: String,
    val state: StartupFlowState,
)

private val previewStartupStates: List<PreviewStartupState> = listOf(
    PreviewStartupState(
        name = "迁移检查",
        state = StartupFlowState(
            currentStep = StartupStep.MIGRATION_CHECK,
            legacyPackageName = "com.mutx163.timetable",
        ),
    ),
    PreviewStartupState(
        name = "迁移检查·打开旧版中",
        state = StartupFlowState(
            currentStep = StartupStep.MIGRATION_CHECK,
            legacyPackageName = "com.mutx163.timetable",
            isOpeningOldApp = true,
        ),
    ),
    PreviewStartupState(
        name = "开学日期·未填",
        state = StartupFlowState(currentStep = StartupStep.DATE_SETUP),
    ),
    PreviewStartupState(
        name = "开学日期·已填",
        state = StartupFlowState(
            currentStep = StartupStep.DATE_SETUP,
            semesterStartDate = "2026-09-07",
            totalWeeks = 18,
            currentWeek = 10,
        ),
    ),
)

private fun previewStartupState(name: String): StartupFlowState =
    previewStartupStates.first { it.name == name }.state

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewStartupFlowPage(
    state: StartupFlowState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        StartupFlowPage(
            initialState = state,
            onBack = {},
        )
    }
}

// ── 单档：四态 × 亮色 ────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 迁移检查", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewMigration() {
    PreviewStartupFlowPage(previewStartupState("迁移检查"))
}

@Suppress("unused")
@Preview(name = "2 迁移检查·打开旧版中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewOpeningOldApp() {
    PreviewStartupFlowPage(previewStartupState("迁移检查·打开旧版中"))
}

@Suppress("unused")
@Preview(name = "3 开学日期·未填", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewDateSetupEmpty() {
    PreviewStartupFlowPage(previewStartupState("开学日期·未填"))
}

@Suppress("unused")
@Preview(name = "4 开学日期·已填", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewDateSetupFilled() {
    PreviewStartupFlowPage(previewStartupState("开学日期·已填"))
}

// ── 单档：外观两档（以「开学日期·已填」为基准，它内容最密）──────────────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewDark() {
    PreviewStartupFlowPage(previewStartupState("开学日期·已填"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewLargeText() {
    PreviewStartupFlowPage(previewStartupState("开学日期·已填"), textScale = 1.3f)
}

// ── 总览：四态并排，一屏看完 ─────────────────────────────────────────────

/**
 * 四态横排，用来一眼比结构差异。
 *
 * 4 × 400dp + 3 × 16dp 间距 = 1648dp，所以画布给 1700dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~6 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·四态并排", showBackground = true, widthDp = 1700, heightDp = 900)
@Composable
private fun StartupFlowPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (preview in previewStartupStates) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewStartupFlowPage(preview.state)
            }
        }
    }
}
