package com.mutx163.qingyu.pages.guide

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
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

    // 大标题折叠行为：Dart 原件 lib/screens/startup_flow_screens.dart:34 走 HyperosSubpage，
    // 大标题可折叠（collapsibleLargeTitle 默认 true）。不传 scrollBehavior 则永不收起。
    val scrollBehavior = MiuixScrollBehavior()
    // 顶栏标题随状态机步骤变化：抽成同一个局部变量喂给 title 与 largeTitle，避免两处各写一遍分叉。
    val pageTitle = when (currentState.currentStep) {
        StartupStep.MIGRATION_CHECK -> GuideStrings.migrationTitle.zh
        StartupStep.DATE_SETUP -> GuideStrings.setSemesterStartDateAction.zh
        StartupStep.GUIDE_TOUR -> GuideStrings.welcomeTitle.zh
        StartupStep.COMPLETED -> GuideStrings.welcomeAppName.zh
    }

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = pageTitle,
                largeTitle = pageTitle,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.primaryText(dark))
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        // 页面级主滚动走共享列表（2026-11-04 收口）：原来外层 Column 吃 innerPadding、
        // 子内容各自再把它塞进 contentPadding 底部（底部账面因此叠了两次手势条）。
        // 现在 innerPadding 只由 QingyuPageList 算，子内容各自补同样的 +24dp 即可，账面不变。
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
    // 2026-11-04 收口：裸 LazyColumn → 共享 QingyuPageList；innerPadding 不再由外层
    // Column 吃，改由组件算，这里只保留原先的 +24dp 底部留白与顶栏下 8dp。
    QingyuPageList(
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        extraTopPadding = 8.dp,
        contentPadding = PaddingValues(
            start = 16.dp,
            end = 16.dp,
            // 组件内部已算一次 innerPadding 底部；保持原先「再叠一次 + 24dp」的账。
            bottom = innerPadding.calculateBottomPadding() + 24.dp
        ),
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
                        text = GuideStrings.migrationSafeTitle.zh,
                        style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                        color = primaryColor
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = GuideStrings.migrationSafeSubtitle.zh,
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
                        title = GuideStrings.migrationStep1Title.zh,
                        subtitle = GuideStrings.migrationStep1Subtitle.zh
                    )
                    HorizontalDivider()
                    MigrationStepRow(
                        step = 2,
                        title = GuideStrings.migrationStep2Title.zh,
                        subtitle = GuideStrings.migrationStep2Subtitle.zh
                    )
                    HorizontalDivider()
                    MigrationStepRow(
                        step = 3,
                        title = GuideStrings.migrationStep3Title.zh,
                        subtitle = GuideStrings.migrationStep3Subtitle.zh
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
                            text = GuideStrings.migrationNoSaveToFilesTitle.zh,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = GuideStrings.migrationNoSaveToFilesSubtitle.zh,
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
                        text = if (isOpeningOldApp) GuideStrings.openingOldApp.zh else GuideStrings.openOldAppForBackup.zh,
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
                        text = GuideStrings.backupDoneGoImport.zh,
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
                        text = GuideStrings.startFreshWithoutMigration.zh,
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
    // 2026-11-04 收口：裸 LazyColumn → 共享 QingyuPageList。原先这一份只接了 nestedScroll，
    // 减震/回弹/滚动条由组件统一补齐（与上一步 MigrationGuideContent 口径一致）。
    QingyuPageList(
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        extraTopPadding = 8.dp,
        contentPadding = PaddingValues(
            start = 16.dp,
            end = 16.dp,
            // 组件内部已算一次 innerPadding 底部；保持原先「再叠一次 + 24dp」的账。
            bottom = innerPadding.calculateBottomPadding() + 24.dp
        ),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.semesterStartDateLabel.zh,
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
                    text = GuideStrings.guideNextButton.zh,
                    color = Color.White,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD)
                )
            }
        }
    }
}
