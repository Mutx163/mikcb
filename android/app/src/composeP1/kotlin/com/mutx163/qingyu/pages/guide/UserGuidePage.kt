package com.mutx163.qingyu.pages.guide

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuBackIconButton
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.preference.RadioButtonPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 用户指南 / 新手引导 · Compose 渲染层（干净版）。
 *
 * ## 设计取向（2026-10-29 用户拍板）
 *
 * 走「干净、克制、无卡通图标」的路线：
 * - **无顶栏、无大标题折叠/缩放**：页面标题就是正文第一行（大号左对齐），和页面一体；
 * - **不放彩色图标徽章**：操作行只有「文字 + 细箭头」，权限状态用「小圆点 + 颜色」；
 * - 交互控件一律走 Miuix（[QingyuPageList] / [QingyuCard] / [Text] / [Button] / [TabRow] / [Checkbox]）；
 * - 文字保持最少：删掉复述性副标题，隐私页法律正文除外。
 *
 * 行为真相仍是 `lib/screens/user_guide_screen.dart`；本层不探测系统、不写设置：六项权限真实状态
 * 经 [permissionState] 传入，个性化改动经 [onSettingsPatch] 交宿主落盘，权限行点击经
 * [onPermissionAction] 交宿主拉起系统页。契约类型见 GuideRuntimeTypes（Lead 冻结）。
 */
@Composable
fun UserGuidePage(
    requirePrivacyConsent: Boolean = false,
    initialPrivacyChecked: Boolean = false,
    permissionState: GuidePermissionState = GuidePermissionState(),
    settings: GuideSettingsSnapshot = GuideSettingsSnapshot(),
    seedOptions: List<GuideSeedOption> = emptyList(),
    onBack: () -> Unit,
    onImportCourses: () -> Unit = {},
    onRestoreBackup: () -> Unit = {},
    onFinishGuide: () -> Unit = {},
    onOpenCourseOverview: () -> Unit = {},
    onPermissionAction: (GuidePermissionAction) -> Unit = {},
    onRefreshPermissions: () -> Unit = {},
    onSettingsPatch: (GuideSettingsPatch) -> Unit = {},
) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()

    var privacyChecked by remember { mutableStateOf(initialPrivacyChecked) }
    val gatedToPrivacy = requirePrivacyConsent && !privacyChecked

    val pagerState = rememberPagerState(pageCount = { TOTAL_GUIDE_PAGES })
    val currentPage = pagerState.currentPage

    val pageTitles = listOf(
        GuideStrings.welcomeTitle.zh,
        GuideStrings.guidePrivacyPageTitle.zh,
        GuideStrings.guidePermissionsPageTitle.zh,
        GuideStrings.guidePersonalizePageTitle.zh,
        GuideStrings.guideTipsPageTitle.zh,
    )

    val goToPage: (Int) -> Unit = { target ->
        scope.launch { pagerState.animateScrollToPage(target.coerceIn(0, TOTAL_GUIDE_PAGES - 1)) }
    }

    val runWelcomeAction: (() -> Unit) -> Unit = { action ->
        if (requirePrivacyConsent && !privacyChecked) goToPage(1) else action()
    }

    // 复看模式（从设置进入）才给关闭返回键；首启模式必须走完流程。
    val closeGuide: (() -> Unit)? = if (requirePrivacyConsent) null else onBack

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        bottomBar = {
            GuideBottomBar(
                dark = dark,
                currentPage = currentPage,
                isPrivacyPage = requirePrivacyConsent && currentPage == 1,
                isLastPage = currentPage == TOTAL_GUIDE_PAGES - 1,
                canGoNext = !(requirePrivacyConsent && currentPage == 1) || privacyChecked,
                requireConsent = requirePrivacyConsent,
                onExit = onBack,
                onPrev = { goToPage(currentPage - 1) },
                onNext = {
                    if (currentPage < TOTAL_GUIDE_PAGES - 1) goToPage(currentPage + 1) else onFinishGuide()
                },
            )
        },
    ) { innerPadding ->
        QingyuPageTheme {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
                userScrollEnabled = !gatedToPrivacy,
            ) { page ->
                when (page) {
                    0 -> WelcomePage(
                        innerPadding = innerPadding,
                        title = pageTitles[0],
                        pageIndex = 0,
                        onBack = closeGuide,
                        onStart = { goToPage(1) },
                        onImport = { runWelcomeAction(onImportCourses) },
                        onRestore = { runWelcomeAction(onRestoreBackup) },
                    )

                    1 -> PrivacyPage(
                        innerPadding = innerPadding,
                        title = pageTitles[1],
                        pageIndex = 1,
                        onBack = closeGuide,
                        requireConsent = requirePrivacyConsent,
                        consentChecked = privacyChecked,
                        onConsentChanged = { privacyChecked = it },
                    )

                    2 -> PermissionsPage(
                        innerPadding = innerPadding,
                        title = pageTitles[2],
                        pageIndex = 2,
                        onBack = closeGuide,
                        state = permissionState,
                        onPermissionAction = onPermissionAction,
                        onRefresh = onRefreshPermissions,
                    )

                    3 -> PersonalizePage(
                        innerPadding = innerPadding,
                        title = pageTitles[3],
                        pageIndex = 3,
                        onBack = closeGuide,
                        settings = settings,
                        seedOptions = seedOptions,
                        onSettingsPatch = onSettingsPatch,
                    )

                    4 -> TipsPage(
                        innerPadding = innerPadding,
                        title = pageTitles[4],
                        pageIndex = 4,
                        onBack = closeGuide,
                        onOpenCourseOverview = onOpenCourseOverview,
                    )
                }
            }
        }
    }
}

private const val TOTAL_GUIDE_PAGES = 5

// ───────────────────────────── 共用：页头（标题即正文首行） ─────────────────────────────

@Composable
private fun GuideHeader(
    title: String,
    pageIndex: Int,
    onBack: (() -> Unit)?,
    eyebrow: String? = null,
    action: (@Composable () -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().heightIn(min = 40.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (onBack != null) {
                QingyuBackIconButton(onBack = onBack)
            } else {
                Spacer(Modifier.width(1.dp))
            }
            Spacer(Modifier.weight(1f))
            action?.invoke()
            if (action != null) Spacer(Modifier.width(4.dp))
            Text(
                text = "${pageIndex + 1} / $TOTAL_GUIDE_PAGES",
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        if (eyebrow != null) {
            Spacer(Modifier.height(6.dp))
            Text(
                text = eyebrow,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = title,
            style = MiuixTheme.textStyles.title2.shiftWeight(QingyuWeightDelta.BOLD),
            color = Color(QingyuTheme.primaryText(dark)),
        )
    }
}

@Composable
private fun GuideGroupTitle(text: String, dark: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.BOLD),
        color = Color(QingyuTheme.secondaryText(dark)),
    )
}

@Composable
private fun GuideParagraph(text: String, dark: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = Color(QingyuTheme.secondaryText(dark)),
        lineHeight = 20.sp,
    )
}

/** 一行动作：文字 + 细箭头（无图标，靠排版。Dart 欢迎页三动作）。 */
@Composable
private fun GuideNavRow(title: String, onClick: () -> Unit) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .heightIn(min = 56.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.5f),
            modifier = Modifier.size(16.dp),
        )
    }
}

// ───────────────────────────── 欢迎页 ─────────────────────────────

@Composable
private fun WelcomePage(
    innerPadding: PaddingValues,
    title: String,
    pageIndex: Int,
    onBack: (() -> Unit)?,
    onStart: () -> Unit,
    onImport: () -> Unit,
    onRestore: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") {
            GuideHeader(title, pageIndex, onBack, eyebrow = GuideStrings.welcomeAppName.zh)
        }
        item(key = "subtitle") {
            Text(
                text = GuideStrings.welcomeSubtitle.zh,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
        item(key = "actions") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
            ) {
                Column {
                    GuideNavRow(GuideStrings.startUsingTitle.zh, onStart)
                    GuideNavRow(GuideStrings.importTimetableTitle.zh, onImport)
                    GuideNavRow(GuideStrings.restoreBackupTitle.zh, onRestore)
                }
            }
        }
    }
}

// ───────────────────────────── 隐私页 ─────────────────────────────

@Composable
private fun PrivacyPage(
    innerPadding: PaddingValues,
    title: String,
    pageIndex: Int,
    onBack: (() -> Unit)?,
    requireConsent: Boolean,
    consentChecked: Boolean,
    onConsentChanged: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, pageIndex, onBack) }

        item(key = "privacy") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    GuideParagraph(GuideStrings.guidePrivacyParagraph1.zh, dark)
                    GuideParagraph(GuideStrings.guidePrivacyParagraph2.zh, dark)
                    GuideParagraph(GuideStrings.guidePrivacyParagraph3.zh, dark)
                    GuideParagraph(GuideStrings.guidePrivacyParagraph4.zh, dark)
                }
            }
        }

        item(key = "risk") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    GuideGroupTitle(GuideStrings.guideRiskTitle.zh, dark)
                    GuideParagraph(GuideStrings.guideRiskParagraph1.zh, dark)
                    GuideParagraph(GuideStrings.guideRiskParagraph2.zh, dark)
                    GuideParagraph(GuideStrings.guideRiskParagraph3.zh, dark)
                }
            }
        }

        item(key = "umeng") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Text(
                    text = GuideStrings.guideUmengPrivacyLink.zh,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.primary(dark = dark)),
                )
            }
        }

        if (requireConsent) {
            item(key = "consent") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onConsentChanged(!consentChecked) },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Checkbox(
                            state = if (consentChecked) ToggleableState.On else ToggleableState.Off,
                            onClick = { onConsentChanged(!consentChecked) },
                        )
                        Spacer(Modifier.width(10.dp))
                        Text(
                            text = GuideStrings.guidePrivacyConsentLabel.zh,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                }
            }
        }
    }
}

// ───────────────────────────── 系统权限页 ─────────────────────────────

@Composable
private fun PermissionsPage(
    innerPadding: PaddingValues,
    title: String,
    pageIndex: Int,
    onBack: (() -> Unit)?,
    state: GuidePermissionState,
    onPermissionAction: (GuidePermissionAction) -> Unit,
    onRefresh: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val items = UserGuideModel.permissionItems(state)
    val progress = PermissionProgress.calculate(items)

    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") {
            GuideHeader(title, pageIndex, onBack, action = {
                IconButton(onClick = onRefresh) {
                    Icon(
                        imageVector = MiuixIcons.Refresh,
                        contentDescription = GuideStrings.refreshStatusTooltip.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
            })
        }

        if (state.isLoading) {
            item(key = "loading") {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
            }
        } else {
            item(key = "progress") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column {
                        Text(
                            text = GuideStrings.guidePermissionsProgressLabel.filled(
                                "ready" to "${progress.readyCount}",
                                "total" to "${progress.totalCount}",
                            ),
                            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Spacer(Modifier.height(10.dp))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(7.dp)
                                .clip(CircleShape)
                                .background(Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.12f)),
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(progress.ratio)
                                    .height(7.dp)
                                    .clip(CircleShape)
                                    .background(Color(QingyuTheme.primary(dark = dark))),
                            )
                        }
                    }
                }
            }

            item(key = "rows") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                ) {
                    Column {
                        items.forEachIndexed { idx, item ->
                            GuidePermissionRow(
                                item = item,
                                dark = dark,
                                onClick = { permissionActionOf(item.id)?.let(onPermissionAction) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GuidePermissionRow(
    item: PermissionItemData,
    dark: Boolean,
    onClick: () -> Unit,
) {
    val statusColor = when (item.enabled) {
        true -> Color(QingyuTheme.success(dark))
        false -> Color(QingyuTheme.secondaryText(dark))
        null -> Color(QingyuTheme.secondaryText(dark))
    }
    // 官方 BasicComponent：行内布局、56dp 最小行高、整行点击与**按压反馈**都由它给
    // （`Modifier.clickable` + `MiuixTheme` 提供的 `LocalIndication`）。
    // 以前这里是自己拼 `Row` + 裸 `.clickable`，视觉上按下去没有反馈。
    // 卡片外层已给 16dp 横向内边距，这里 `insideMargin` 传 0 免得叠成 32dp。
    BasicComponent(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
        endActions = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(statusColor),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = if (item.enabled == true) item.enabledLabel else item.disabledLabel,
                    style = MiuixTheme.textStyles.footnote1,
                    color = statusColor,
                )
            }
            Spacer(Modifier.width(4.dp))
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.5f),
                modifier = Modifier.size(15.dp),
            )
        },
        onClick = onClick,
    ) {
        Text(
            text = item.title,
            style = MiuixTheme.textStyles.body1,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        if (item.subtitle != null) {
            Text(
                text = item.subtitle,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

private fun permissionActionOf(id: String): GuidePermissionAction? =
    GuidePermissionAction.values().firstOrNull { it.name == id }

// ───────────────────────────── 个性化页 ─────────────────────────────

/** 卡片内分组标题：与官方选择行的 16dp 行内边距左缘对齐。 */
@Composable
private fun GuideCardTitle(text: String, dark: Boolean, top: Dp = 12.dp) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.BOLD),
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = top, bottom = 2.dp),
    )
}

@Composable
private fun PersonalizePage(
    innerPadding: PaddingValues,
    title: String,
    pageIndex: Int,
    onBack: (() -> Unit)?,
    settings: GuideSettingsSnapshot,
    seedOptions: List<GuideSeedOption>,
    onSettingsPatch: (GuideSettingsPatch) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, pageIndex, onBack) }

        item(key = "subtitle") {
            Text(
                text = GuideStrings.guidePersonalizeSubtitle.zh,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }

        // 菜单样式：两条官方单选行（对齐发布版 HyperosChoiceTile，不再用画歪的分段控件）
        item(key = "menuStyle") {
            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                Column {
                    GuideCardTitle(GuideStrings.guidePersonalizeMenuStyleTitle.zh, dark)
                    RadioButtonPreference(
                        title = GuideStrings.homeMenuStyleList.zh,
                        summary = GuideStrings.homeMenuStyleListSubtitle.zh,
                        selected = !settings.homeMenuGrid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.HomeMenuGrid(false)) },
                    )
                    RadioButtonPreference(
                        title = GuideStrings.homeMenuStyleGrid.zh,
                        summary = GuideStrings.homeMenuStyleGridSubtitle.zh,
                        selected = settings.homeMenuGrid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.HomeMenuGrid(true)) },
                    )
                    Spacer(Modifier.height(4.dp))
                }
            }
        }

        // 默认材质：液态玻璃 / 实体卡片（对齐发布版；实体档省性能，玻璃档提示需配壁纸）
        item(key = "material") {
            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                Column {
                    GuideCardTitle(GuideStrings.frostedGlassModeLabel.zh, dark)
                    RadioButtonPreference(
                        title = GuideStrings.frostedGlassModeLiquid.zh,
                        summary = GuideStrings.guideVisualEffectLiquidDesc.zh,
                        selected = !settings.materialSolid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.MaterialSolid(false)) },
                    )
                    RadioButtonPreference(
                        title = GuideStrings.guidePersonalizeVisualEffectSolid.zh,
                        summary = GuideStrings.guideVisualEffectSolidDesc.zh,
                        selected = settings.materialSolid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.MaterialSolid(true)) },
                    )
                    if (!settings.materialSolid) {
                        Text(
                            text = GuideStrings.guideVisualEffectWallpaperHint.zh,
                            style = MiuixTheme.textStyles.footnote2,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 12.dp),
                        )
                    } else {
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }

        // 深浅色模式：官方轮廓分段（TabRowWithContour，对齐发布版 HyperosTabRow 默认 contour 档）
        item(key = "themeMode") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guidePersonalizeThemeModeTitle.zh, dark)
                    Spacer(Modifier.height(10.dp))
                    TabRowWithContour(
                        tabs = listOf(
                            GuideStrings.themeModeSystem.zh,
                            GuideStrings.themeModeLight.zh,
                            GuideStrings.themeModeDark.zh,
                        ),
                        selectedTabIndex = when (settings.themeMode) {
                            GuideThemeMode.SYSTEM -> 0
                            GuideThemeMode.LIGHT -> 1
                            GuideThemeMode.DARK -> 2
                        },
                        onTabSelected = { index ->
                            onSettingsPatch(
                                GuideSettingsPatch.ThemeMode(
                                    when (index) {
                                        0 -> GuideThemeMode.SYSTEM
                                        1 -> GuideThemeMode.LIGHT
                                        else -> GuideThemeMode.DARK
                                    },
                                ),
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }

        item(key = "seedColor") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guidePersonalizeSeedColorTitle.zh, dark)
                    Spacer(Modifier.height(12.dp))
                    seedOptions.chunked(6).forEachIndexed { rowIdx, rowOptions ->
                        if (rowIdx > 0) Spacer(Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            rowOptions.forEach { option ->
                                ThemeSwatch(
                                    hex = option.hex,
                                    label = option.label,
                                    selected = option.hex.equals(settings.seedHex, ignoreCase = true),
                                    dark = dark,
                                    onClick = { onSettingsPatch(GuideSettingsPatch.SeedColor(option.hex)) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ThemeSwatch(
    hex: String,
    label: String,
    selected: Boolean,
    dark: Boolean,
    onClick: () -> Unit,
) {
    val color = parseHexColorOrFallback(hex)
    val ring = if (selected) Color(QingyuTheme.primary(dark = dark)) else Color(QingyuTheme.dividerLine(dark))
    // 可点区撑到 48dp，色块视觉本体仍是 32dp；只放大命中面，不改视觉尺寸。
    Box(
        modifier = Modifier
            .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
            .clickable(onClick = onClick)
            // 色块只有颜色、没有文字，读屏默认只会念「按钮」；补上名字与单选语义。
            .semantics {
                contentDescription = label
                role = Role.RadioButton
                this.selected = selected
            },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(color)
                .border(width = if (selected) 2.dp else 1.dp, color = ring, shape = CircleShape),
        )
    }
}

// ───────────────────────────── 使用技巧页 ─────────────────────────────

@Composable
private fun TipsPage(
    innerPadding: PaddingValues,
    title: String,
    pageIndex: Int,
    onBack: (() -> Unit)?,
    onOpenCourseOverview: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, pageIndex, onBack) }

        item(key = "shortName") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guideShortNameAdviceTitle.zh, dark)
                    Spacer(Modifier.height(8.dp))
                    ExampleRow(ok = true, label = GuideStrings.guideShortNameRecommended.zh, example = GuideStrings.guideShortNameRecommendedExample.zh, dark = dark)
                    Spacer(Modifier.height(6.dp))
                    ExampleRow(ok = false, label = GuideStrings.guideShortNameNotRecommended.zh, example = GuideStrings.guideShortNameNotRecommendedExample.zh, dark = dark)
                    Spacer(Modifier.height(14.dp))
                    Button(
                        onClick = onOpenCourseOverview,
                        colors = ButtonDefaults.buttonColors(Color(QingyuTheme.card(dark))),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = GuideStrings.guideSetCourseShortNameAction.zh,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                }
            }
        }

        item(key = "importMethods") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    GuideGroupTitle(GuideStrings.guideImportMethodsTitle.zh, dark)
                    StepRow("1", GuideStrings.guideImportMethodStep1.zh, dark)
                    StepRow("2", GuideStrings.guideImportMethodStep2.zh, dark)
                    StepRow("3", GuideStrings.guideImportMethodStep3.zh, dark)
                }
            }
        }

        item(key = "finalTips") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    GuideGroupTitle(GuideStrings.guideFinalTipsTitle.zh, dark)
                    GuideParagraph(GuideStrings.guideFinalTip1.zh, dark)
                    GuideParagraph(GuideStrings.guideFinalTip2.zh, dark)
                    GuideParagraph(GuideStrings.guideFinalTip3.zh, dark)
                }
            }
        }
    }
}

@Composable
private fun ExampleRow(ok: Boolean, label: String, example: String, dark: Boolean) {
    val markColor = if (ok) Color(QingyuTheme.success(dark)) else Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.6f)
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = if (ok) "✓" else "✗",
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
            color = markColor,
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.width(56.dp),
        )
        Text(
            text = example,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun StepRow(step: String, text: String, dark: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = step,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.BOLD),
            color = Color(QingyuTheme.primary(dark = dark)),
            modifier = Modifier.width(18.dp),
        )
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
    }
}

// ───────────────────────────── 底栏 ─────────────────────────────

@Composable
private fun GuideBottomBar(
    dark: Boolean,
    currentPage: Int,
    isPrivacyPage: Boolean,
    isLastPage: Boolean,
    canGoNext: Boolean,
    requireConsent: Boolean,
    onExit: () -> Unit,
    onPrev: () -> Unit,
    onNext: () -> Unit,
) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    // 「下一步」按钮压在 primary 实底上：墨色按底色亮度翻黑/白（对齐发布版 onAccentInk），
    // 避免选了浅色主题种子（如黄）时白字压浅底看不清。
    val onAccentInk = if (primary.luminance() > 0.5f) Color.Black else Color.White

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(QingyuTheme.scaffoldBackground(dark)))
            .padding(start = 24.dp, end = 24.dp, top = 12.dp, bottom = 20.dp),
    ) {
        // 分段进度条：靠图形说明「走到第几步」，等分撑满更整齐。
        Row(
            modifier = Modifier.fillMaxWidth().clearAndSetSemantics {
                contentDescription = "${currentPage + 1} / $TOTAL_GUIDE_PAGES"
            },
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            for (i in 0 until TOTAL_GUIDE_PAGES) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(
                            if (i <= currentPage) primary
                            else Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.25f),
                        ),
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val showPrev = isPrivacyPage || currentPage > 0
            if (showPrev) {
                GuideSecondaryButton(
                    label = if (isPrivacyPage) GuideStrings.exitAppAction.zh else GuideStrings.guidePrevButton.zh,
                    dark = dark,
                    onClick = if (isPrivacyPage) onExit else onPrev,
                    modifier = Modifier.weight(1f),
                )
            }
            Button(
                onClick = onNext,
                enabled = if (isLastPage) true else canGoNext,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(primary),
            ) {
                Text(
                    text = if (isLastPage) {
                        if (requireConsent) GuideStrings.agreeAndStartAction.zh else GuideStrings.gotItAction.zh
                    } else {
                        GuideStrings.guideNextButton.zh
                    },
                    color = onAccentInk,
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                )
            }
        }
    }
}

@Composable
private fun GuideSecondaryButton(
    label: String,
    dark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier,
        colors = ButtonDefaults.buttonColors(Color(QingyuTheme.card(dark))),
    ) {
        Text(
            text = label,
            color = Color(QingyuTheme.primaryText(dark)),
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
        )
    }
}
