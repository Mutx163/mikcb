package com.mutx163.qingyu.pages.guide

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Checkbox
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
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Search

/**
 * 用户指南与新手问答页 · Compose 渲染层。
 * 覆盖：
 * 1. 新手引导 5 大分步指引（欢迎、隐私免责、系统权限、个性化定制、使用技巧）；
 * 2. 问答卡片（Miuix 风格 Card、按分类筛选、关键词搜索与平滑展开折叠过渡）；
 * 3. 权限状态实时统计与底栏导航。
 */
@Composable
fun UserGuidePage(
    requirePrivacyConsent: Boolean = false,
    initialPrivacyChecked: Boolean = false,
    onBack: () -> Unit,
    onImportCourses: () -> Unit = {},
    onRestoreBackup: () -> Unit = {},
    onFinishGuide: () -> Unit = {}
) {
    var currentStep by remember { mutableIntStateOf(0) }
    var privacyChecked by remember { mutableStateOf(initialPrivacyChecked) }
    var faqSearchQuery by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf<GuideCategory?>(null) }
    var expandedFaqIds by remember { mutableStateOf(setOf<String>()) }
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    val stepTitles = listOf(
        GuideStrings.welcomeTitle.zh,
        GuideStrings.guidePrivacyPageTitle.zh,
        GuideStrings.guidePermissionsPageTitle.zh,
        GuideStrings.guidePersonalizePageTitle.zh,
        GuideStrings.guideTipsPageTitle.zh
    )

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark))
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = stepTitles.getOrElse(currentStep) { GuideStrings.userGuideEntryTitle.zh },
                navigationIcon = {
                    if (!requirePrivacyConsent || currentStep > 0) {
                        IconButton(onClick = {
                            if (currentStep > 0) currentStep-- else onBack()
                        }) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = "返回",
                                tint = Color(QingyuTheme.primaryText(dark))
                            )
                        }
                    }
                }
            )

            Box(modifier = Modifier.weight(1f)) {
                when (currentStep) {
                    0 -> WelcomeStepContent(
                        innerPadding = innerPadding,
                        onStart = { currentStep = 1 },
                        onImport = onImportCourses,
                        onRestore = onRestoreBackup
                    )
                    1 -> PrivacyStepContent(
                        innerPadding = innerPadding,
                        requireConsent = requirePrivacyConsent,
                        consentChecked = privacyChecked,
                        onConsentChanged = { privacyChecked = it }
                    )
                    2 -> PermissionsStepContent(innerPadding = innerPadding)
                    3 -> PersonalizeStepContent(innerPadding = innerPadding)
                    4 -> TipsAndFaqStepContent(
                        innerPadding = innerPadding,
                        faqQuery = faqSearchQuery,
                        onFaqQueryChange = { faqSearchQuery = it },
                        selectedCategory = selectedCategory,
                        onCategorySelect = { selectedCategory = it },
                        expandedIds = expandedFaqIds,
                        onToggleFaq = { id ->
                            expandedFaqIds = UserGuideModel.toggleExpanded(expandedFaqIds, id)
                        }
                    )
                }
            }

            // 底部操作栏与居中页码圆点
            BottomNavigationBar(
                currentStep = currentStep,
                totalSteps = 5,
                canGoNext = currentStep != 1 || !requirePrivacyConsent || privacyChecked,
                requireConsent = requirePrivacyConsent,
                onPrev = { if (currentStep > 0) currentStep-- },
                onNext = {
                    if (currentStep < 4) {
                        currentStep++
                    } else {
                        onFinishGuide()
                    }
                }
            )
        }
    }
}

/** 欢迎步骤卡片 */
@Composable
private fun WelcomeStepContent(
    innerPadding: PaddingValues,
    onStart: () -> Unit,
    onImport: () -> Unit,
    onRestore: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.welcomeAppName.zh,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = GuideStrings.welcomeSubtitle.zh,
                        fontSize = 14.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 20.sp
                    )
                }
            }
        }

        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(14.dp)
            ) {
                Text(
                    text = GuideStrings.thirdPartyDisclaimer.zh,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    lineHeight = 18.sp
                )
            }
        }

        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(12.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    GuideActionRow(
                        title = GuideStrings.startUsingTitle.zh,
                        subtitle = "直接进入软件并浏览完整功能",
                        onClick = onStart
                    )
                    HorizontalDivider()
                    GuideActionRow(
                        title = GuideStrings.importTimetableTitle.zh,
                        subtitle = GuideStrings.importTimetableSubtitle.zh,
                        onClick = onImport
                    )
                    HorizontalDivider()
                    GuideActionRow(
                        title = GuideStrings.restoreBackupTitle.zh,
                        subtitle = GuideStrings.restoreBackupSubtitle.zh,
                        onClick = onRestore
                    )
                }
            }
        }
    }
}

/** 隐私免责步骤卡片 */
@Composable
private fun PrivacyStepContent(
    innerPadding: PaddingValues,
    requireConsent: Boolean,
    consentChecked: Boolean,
    onConsentChanged: (Boolean) -> Unit
) {
    val dark = isSystemInDarkTheme()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.guidePrivacySectionTitle.zh,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = GuideStrings.guidePrivacyParagraph1.zh,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 18.sp
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = GuideStrings.guidePrivacyParagraph2.zh,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 18.sp
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = GuideStrings.guidePrivacyParagraph3.zh,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 18.sp
                    )
                }
            }
        }

        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.guideRiskTitle.zh,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = GuideStrings.guideRiskParagraph1.zh,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 18.sp
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = GuideStrings.guideRiskParagraph2.zh,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 18.sp
                    )
                }
            }
        }

        if (requireConsent) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(14.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onConsentChanged(!consentChecked) },
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            state = if (consentChecked) ToggleableState.On else ToggleableState.Off,
                            onClick = { onConsentChanged(!consentChecked) }
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = GuideStrings.guidePrivacyConsentLabel.zh,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                    }
                }
            }
        }
    }
}

/** 权限步骤卡片 */
@Composable
private fun PermissionsStepContent(innerPadding: PaddingValues) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    val items = listOf(
        PermissionItemData("1", GuideStrings.guideStatusNotificationPermission.zh, "课前提醒通知的前提", true, "已开启", "未开启"),
        PermissionItemData("2", GuideStrings.guideStatusIslandSupport.zh, "锁屏与灵动通知展示", true, "系统已允许", "建议检查"),
        PermissionItemData("3", GuideStrings.quickActionAutoStartTitle.zh, "开机自动加载定时任务", false, "已开启", "未开启"),
        PermissionItemData("4", GuideStrings.guideStatusBatteryOptimization.zh, "防止后台被省电策略冻结", true, "无限制", "仍受限制"),
        PermissionItemData("5", GuideStrings.guideStatusKeepAlive.zh, "多任务切换后台保持", false, "已开启", "未开启"),
        PermissionItemData("6", GuideStrings.guideStatusDoNotDisturbAccess.zh, GuideStrings.guideStatusDoNotDisturbAccessHint.zh, true, "已开启", "未开启")
    )
    val progress = PermissionProgress.calculate(items)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // 进度卡片
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = GuideStrings.guidePermissionsSubtitle.zh,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            text = GuideStrings.guidePermissionsProgressLabel.filled(
                                "ready" to "${progress.readyCount}",
                                "total" to "${progress.totalCount}"
                            ),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = primaryColor
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // 进度条
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .clip(CircleShape)
                            .background(primaryColor.copy(alpha = 0.15f))
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(progress.ratio)
                                .height(6.dp)
                                .clip(CircleShape)
                                .background(primaryColor)
                        )
                    }
                }
            }
        }

        // 权限清单
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(14.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    items.forEachIndexed { idx, p ->
                        if (idx > 0) HorizontalDivider()
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = p.title,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                                if (p.subtitle != null) {
                                    Text(
                                        text = p.subtitle,
                                        fontSize = 12.sp,
                                        color = Color(QingyuTheme.secondaryText(dark))
                                    )
                                }
                            }
                            Text(
                                text = if (p.enabled == true) p.enabledLabel else p.disabledLabel,
                                fontSize = 13.sp,
                                color = if (p.enabled == true) primaryColor else Color(QingyuTheme.secondaryText(dark))
                            )
                        }
                    }
                }
            }
        }

        item {
            Text(
                text = GuideStrings.guidePermissionsFooterHint.zh,
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                lineHeight = 16.sp
            )
        }
    }
}

/** 个性化定制步骤卡片 */
@Composable
private fun PersonalizeStepContent(innerPadding: PaddingValues) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))
    var menuStyle by remember { mutableStateOf(GuideHomeMenuStyle.LIST) }
    var visualEffect by remember { mutableStateOf(GuideVisualEffect.LIQUID_GLASS) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // 首页菜单样式
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.guidePersonalizeMenuStyleTitle.zh,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OptionCapsule(
                            title = GuideStrings.homeMenuStyleList.zh,
                            subtitle = GuideStrings.homeMenuStyleListSubtitle.zh,
                            selected = menuStyle == GuideHomeMenuStyle.LIST,
                            onClick = { menuStyle = GuideHomeMenuStyle.LIST },
                            modifier = Modifier.weight(1f)
                        )
                        OptionCapsule(
                            title = GuideStrings.homeMenuStyleGrid.zh,
                            subtitle = GuideStrings.homeMenuStyleGridSubtitle.zh,
                            selected = menuStyle == GuideHomeMenuStyle.GRID,
                            onClick = { menuStyle = GuideHomeMenuStyle.GRID },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        // 默认材质
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.frostedGlassModeLabel.zh,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OptionCapsule(
                            title = GuideStrings.frostedGlassModeLiquid.zh,
                            subtitle = GuideStrings.guideVisualEffectLiquidDesc.zh,
                            selected = visualEffect == GuideVisualEffect.LIQUID_GLASS,
                            onClick = { visualEffect = GuideVisualEffect.LIQUID_GLASS },
                            modifier = Modifier.weight(1f)
                        )
                        OptionCapsule(
                            title = GuideStrings.guidePersonalizeVisualEffectSolid.zh,
                            subtitle = GuideStrings.guideVisualEffectSolidDesc.zh,
                            selected = visualEffect == GuideVisualEffect.SOLID,
                            onClick = { visualEffect = GuideVisualEffect.SOLID },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }
}

/** 技巧与问答折叠卡片 */
@Composable
private fun TipsAndFaqStepContent(
    innerPadding: PaddingValues,
    faqQuery: String,
    onFaqQueryChange: (String) -> Unit,
    selectedCategory: GuideCategory?,
    onCategorySelect: (GuideCategory?) -> Unit,
    expandedIds: Set<String>,
    onToggleFaq: (String) -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))
    val filteredFaq = UserGuideModel.filterFaq(
        query = faqQuery,
        category = selectedCategory
    )

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // 课程简称建议
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(16.dp)
            ) {
                Column {
                    Text(
                        text = GuideStrings.guideShortNameAdviceTitle.zh,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(QingyuTheme.primaryText(dark))
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = GuideStrings.guideShortNameAdviceSubtitle.zh,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        lineHeight = 18.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Row {
                        Text(
                            text = GuideStrings.guideShortNameRecommended.zh + "：",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = primaryColor
                        )
                        Text(
                            text = GuideStrings.guideShortNameRecommendedExample.zh,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                    }
                }
            }
        }

        // FAQ 搜索框
        item {
            TextField(
                value = faqQuery,
                onValueChange = onFaqQueryChange,
                modifier = Modifier.fillMaxWidth()
            )
        }

        // FAQ 分类胶囊栏
        item {
            LazyRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    CategoryChip(
                        title = "全部",
                        selected = selectedCategory == null,
                        onClick = { onCategorySelect(null) }
                    )
                }
                items(GuideCategory.values()) { cat ->
                    CategoryChip(
                        title = cat.label,
                        selected = selectedCategory == cat,
                        onClick = { onCategorySelect(cat) }
                    )
                }
            }
        }

        // FAQ 列表项
        items(filteredFaq, key = { it.id }) { item ->
            val isExpanded = UserGuideModel.isExpanded(expandedIds, item.id)
            Card(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(14.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onToggleFaq(item.id) }
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = item.question,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                            modifier = Modifier.weight(1f)
                        )
                        Icon(
                            imageVector = if (isExpanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
                            contentDescription = if (isExpanded) "折叠" else "展开",
                            tint = Color(QingyuTheme.secondaryText(dark))
                        )
                    }

                    AnimatedVisibility(
                        visible = isExpanded,
                        enter = fadeIn(tween(200)) + expandVertically(tween(200)),
                        exit = fadeOut(tween(200)) + shrinkVertically(tween(200))
                    ) {
                        Column {
                            Spacer(modifier = Modifier.height(10.dp))
                            HorizontalDivider()
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = item.answer,
                                fontSize = 13.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                lineHeight = 19.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

/** 分类胶囊 */
@Composable
private fun CategoryChip(
    title: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(
                if (selected) primaryColor else primaryColor.copy(alpha = 0.08f)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(
            text = title,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = if (selected) Color.White else primaryColor
        )
    }
}

/** 选项卡片胶囊 */
@Composable
private fun OptionCapsule(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (selected) primaryColor.copy(alpha = 0.12f) else Color(QingyuTheme.card(dark))
            )
            .clickable(onClick = onClick)
            .padding(12.dp)
    ) {
        Column {
            Text(
                text = title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (selected) primaryColor else Color(QingyuTheme.primaryText(dark))
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = subtitle,
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                lineHeight = 16.sp
            )
        }
    }
}

/** 指南动作行 */
@Composable
private fun GuideActionRow(
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    val dark = isSystemInDarkTheme()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.primaryText(dark))
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark))
            )
        }
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(16.dp)
        )
    }
}

/** 底部导航操作条 */
@Composable
private fun BottomNavigationBar(
    currentStep: Int,
    totalSteps: Int,
    canGoNext: Boolean,
    requireConsent: Boolean,
    onPrev: () -> Unit,
    onNext: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(QingyuTheme.scaffoldBackground(dark)))
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (currentStep > 0) {
                Button(
                    onClick = onPrev,
                    colors = ButtonDefaults.buttonColors(Color(QingyuTheme.card(dark)))
                ) {
                    Text(
                        text = GuideStrings.guidePrevButton.zh,
                        color = Color(QingyuTheme.primaryText(dark)),
                        fontSize = 14.sp
                    )
                }
            } else {
                Spacer(modifier = Modifier.width(60.dp))
            }

            // 居中分页圆点
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                for (i in 0 until totalSteps) {
                    Box(
                        modifier = Modifier
                            .size(if (i == currentStep) 8.dp else 6.dp)
                            .clip(CircleShape)
                            .background(
                                if (i == currentStep) primaryColor else primaryColor.copy(alpha = 0.25f)
                            )
                    )
                }
            }

            Button(
                onClick = onNext,
                enabled = canGoNext,
                colors = ButtonDefaults.buttonColors(primaryColor)
            ) {
                Text(
                    text = if (currentStep == totalSteps - 1) {
                        if (requireConsent) GuideStrings.agreeAndStartAction.zh else GuideStrings.gotItAction.zh
                    } else {
                        GuideStrings.guideNextButton.zh
                    },
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}
