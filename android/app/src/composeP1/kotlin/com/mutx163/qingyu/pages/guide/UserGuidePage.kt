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
import androidx.compose.ui.tooling.preview.Preview
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
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Info
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
 * 2026-11-09 美学复核：
 * - 标题、眉标、说明统一落到 **28dp 文字左缘**（页面 12 + 卡内 16），不再和卡片内容错开；
 * - 欢迎页标题升到 `title1`，并把「开始使用」拆成主题浅色主卡，与两项「已有课表」分层；
 * - 操作行改走官方 `BasicComponent`，行高与按压反馈不再自己拼 `clickable`。
 *
 * 行为真相仍是 `lib/screens/user_guide_screen.dart`；本层不探测系统、不写设置：六项权限真实状态
 * 经 [permissionState] 传入，个性化改动经 [onSettingsPatch] 交宿主落盘，权限行点击经
 * [onPermissionAction] 交宿主拉起系统页。契约类型见 GuideRuntimeTypes（Lead 冻结）。
 *
 * [initialPage] 只作为首次组合的起始页（0 起），之后仍由滑动 / 底栏按钮决定；宿主不传，
 * 静态预览用它直达隐私 / 权限 / 个性化 / 技巧页。首启模式未勾选隐私时会被收在第 2 页，
 * 不能靠传参绕过同意流程。
 */
@Composable
fun UserGuidePage(
    requirePrivacyConsent: Boolean = false,
    initialPrivacyChecked: Boolean = false,
    initialPage: Int = 0,
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

    // 首启模式没勾选隐私就不能跳过第 2 页：预览用的 initialPage 也走同一道闸。
    val startPage = if (requirePrivacyConsent && !initialPrivacyChecked) {
        initialPage.coerceIn(0, 1)
    } else {
        initialPage
    }
    val pagerState = rememberPagerState(
        initialPage = startPage.coerceIn(0, TOTAL_GUIDE_PAGES - 1),
        pageCount = { TOTAL_GUIDE_PAGES },
    )
    val currentPage = pagerState.currentPage

    val pageTitles = listOf(
        GuideStrings.welcomeTitle.text,
        GuideStrings.guidePrivacyPageTitle.text,
        GuideStrings.guidePermissionsPageTitle.text,
        GuideStrings.guidePersonalizePageTitle.text,
        GuideStrings.guideTipsPageTitle.text,
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
    largeTitle: Boolean = false,
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
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        // 正文左缘落在 28dp 轴线（页面 12 + 卡内 16）：标题、眉标与卡片里的文字
        // 同一列，扫读时不会来回跳。页码和返回键仍贴 12dp 页边。
        Column(Modifier.padding(horizontal = 16.dp)) {
            if (eyebrow != null) {
                Spacer(Modifier.height(20.dp))
                Text(
                    text = eyebrow,
                    style = MiuixTheme.textStyles.footnote1
                        .shiftWeight(QingyuWeightDelta.MEDIUM)
                        .copy(letterSpacing = 0.6.sp),
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            Spacer(Modifier.height(if (eyebrow != null) 10.dp else 8.dp))
            Text(
                text = title,
                style = (if (largeTitle) {
                    MiuixTheme.textStyles.title1
                } else {
                    MiuixTheme.textStyles.title2
                }).shiftWeight(QingyuWeightDelta.BOLD),
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
        // 标题与首张卡片之间多留 4dp：12dp 的分段间距读起来太挤，标题像贴在卡片上。
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
private fun GuideGroupTitle(text: String, dark: Boolean) {
    // 卡片标题提一档：13sp 灰色加粗和正文几乎同级，三张卡看起来像三坨灰字。
    // 16sp 主文字色 + 半粗，先立标题再读说明，页面的层次才出来。
    Text(
        text = text,
        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
        color = Color(QingyuTheme.primaryText(dark)),
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

/**
 * 带图标的一行提示条（发布版 `HyperosHintBanner`：自适应卡片 + 18dp 图标 + 10dp 间距 + 一句说明）。
 *
 * 图标用 [MiuixIcons.Info]：miuix 图标集里没有发布版那颗 lightbulb，同仓 `CloudSyncPage`
 * 的 `HintCard` 也是用 Info，保持一致。
 */
@Composable
private fun GuideHintBanner(text: String, dark: Boolean) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = MiuixIcons.Info,
                contentDescription = null,
                tint = Color(QingyuTheme.primary(dark = dark)),
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = text,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
    }
}

/**
 * 一行动作：文字（可带一句说明）+ 细箭头（无图标，靠排版。Dart 欢迎页三动作）。
 *
 * [subtitle] 对应发布版 `_GuideActionTile(subtitle:)`——挂在「导入课表」「从备份恢复」两行，
 * 「开始使用」行发布版就没有副标题（原副标题与实际行为不符，已被删掉）。
 *
 * 布局、56dp 最小行高、整行点击与按压反馈都由官方 [BasicComponent] 给：
 * 以前自己拼 `Row` + 裸 `.clickable`，按下没有反馈，截图里还会留下半截灰块。
 * 卡片外层已给 16dp 横向内边距，这里 `insideMargin` 传 0 免得叠成 32dp。
 */
@Composable
private fun GuideActionRow(
    title: String,
    onClick: () -> Unit,
    subtitle: String? = null,
    emphasized: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    val accent = Color(QingyuTheme.primary(dark = dark))
    BasicComponent(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
        endActions = {
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = if (emphasized) {
                    accent.copy(alpha = 0.85f)
                } else {
                    Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.42f)
                },
                modifier = Modifier.size(if (emphasized) 18.dp else 16.dp),
            )
        },
        onClick = onClick,
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1.shiftWeight(
                if (emphasized) QingyuWeightDelta.BOLD else QingyuWeightDelta.MEDIUM,
            ),
            // 主行动靠「浅色卡 + 加粗 + 主色箭头」分层，不用主色字：
            // 蓝字压在浅蓝底上对比度只有 3 出头，而且会和底栏那颗实心蓝按钮抢眼神。
            color = Color(QingyuTheme.primaryText(dark)),
        )
        if (subtitle != null) {
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
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
    val accent = Color(QingyuTheme.primary(dark = dark))
    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 4.dp, bottom = 16.dp),
        // 欢迎页只有两块内容：留白靠 24dp 的分段间距和页头内部节奏撑开，
        // 不用魔法数字把卡片硬推到屏幕中间。
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        item(key = "hero") {
            Column(Modifier.fillMaxWidth()) {
                GuideHeader(
                    title = title,
                    pageIndex = pageIndex,
                    onBack = onBack,
                    eyebrow = GuideStrings.welcomeAppName.text,
                    largeTitle = true,
                )
                // GuideHeader 末尾自带 4dp（标题到卡片的默认呼吸），这里再补 12dp，
                // 标题与说明之间留 16dp，说明和第一张卡之间才是 24dp 的分段间距。
                Spacer(Modifier.height(12.dp))
                Text(
                    text = GuideStrings.welcomeSubtitle.text,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    lineHeight = 21.sp,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
        }
        item(key = "actions") {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
            ) {
                // 主路径单独一张浅色主题卡：和下面两项「已有课表」不是同一档，
                // 不靠图标也能一眼看出先点哪个。
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                    colors = CardDefaults.defaultColors(
                        color = accent.copy(alpha = if (dark) 0.20f else 0.10f),
                    ),
                ) {
                    GuideActionRow(
                        title = GuideStrings.startUsingTitle.text,
                        onClick = onStart,
                        emphasized = true,
                    )
                }
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                ) {
                    Column {
                        GuideActionRow(
                            title = GuideStrings.importTimetableTitle.text,
                            onClick = onImport,
                            subtitle = GuideStrings.importTimetableSubtitle.text,
                        )
                        // 行间不画横线：官方 demo 同卡多行之间一处都没有，行距由
                        // BasicComponent 自带内边距承担（RowDividerGuardTest 也会拦）。
                        GuideActionRow(
                            title = GuideStrings.restoreBackupTitle.text,
                            onClick = onRestore,
                            subtitle = GuideStrings.restoreBackupSubtitle.text,
                        )
                    }
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
                    GuideParagraph(GuideStrings.guidePrivacyParagraph1.text, dark)
                    GuideParagraph(GuideStrings.guidePrivacyParagraph2.text, dark)
                    GuideParagraph(GuideStrings.guidePrivacyParagraph3.text, dark)
                    GuideParagraph(GuideStrings.guidePrivacyParagraph4.text, dark)
                }
            }
        }

        item(key = "risk") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    GuideGroupTitle(GuideStrings.guideRiskTitle.text, dark)
                    GuideParagraph(GuideStrings.guideRiskParagraph1.text, dark)
                    GuideParagraph(GuideStrings.guideRiskParagraph2.text, dark)
                    GuideParagraph(GuideStrings.guideRiskParagraph3.text, dark)
                }
            }
        }

        item(key = "umeng") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Text(
                    text = GuideStrings.guideUmengPrivacyLink.text,
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
                            text = GuideStrings.guidePrivacyConsentLabel.text,
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
                        contentDescription = GuideStrings.refreshStatusTooltip.text,
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
                        // 发布版摘要卡的第一句（`HyperosTypography.listDetail`）：为什么这套设置值得做。
                        GuideParagraph(GuideStrings.guidePermissionsSubtitle.text, dark)
                        Spacer(Modifier.height(10.dp))
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

            // 发布版在权限列表之后跟一条提示条（`HyperosHintBanner`：灯泡图标 + 一句话）。
            item(key = "footerHint") {
                GuideHintBanner(GuideStrings.guidePermissionsFooterHint.text, dark)
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
                text = GuideStrings.guidePersonalizeSubtitle.text,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }

        // 菜单样式：两条官方单选行（对齐发布版 HyperosChoiceTile，不再用画歪的分段控件）
        item(key = "menuStyle") {
            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                Column {
                    GuideCardTitle(GuideStrings.guidePersonalizeMenuStyleTitle.text, dark)
                    RadioButtonPreference(
                        title = GuideStrings.homeMenuStyleList.text,
                        summary = GuideStrings.homeMenuStyleListSubtitle.text,
                        selected = !settings.homeMenuGrid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.HomeMenuGrid(false)) },
                    )
                    RadioButtonPreference(
                        title = GuideStrings.homeMenuStyleGrid.text,
                        summary = GuideStrings.homeMenuStyleGridSubtitle.text,
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
                    GuideCardTitle(GuideStrings.frostedGlassModeLabel.text, dark)
                    RadioButtonPreference(
                        title = GuideStrings.frostedGlassModeLiquid.text,
                        summary = GuideStrings.guideVisualEffectLiquidDesc.text,
                        selected = !settings.materialSolid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.MaterialSolid(false)) },
                    )
                    RadioButtonPreference(
                        title = GuideStrings.guidePersonalizeVisualEffectSolid.text,
                        summary = GuideStrings.guideVisualEffectSolidDesc.text,
                        selected = settings.materialSolid,
                        onClick = { onSettingsPatch(GuideSettingsPatch.MaterialSolid(true)) },
                    )
                    if (!settings.materialSolid) {
                        Text(
                            text = GuideStrings.guideVisualEffectWallpaperHint.text,
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
                    GuideGroupTitle(GuideStrings.guidePersonalizeThemeModeTitle.text, dark)
                    Spacer(Modifier.height(10.dp))
                    TabRowWithContour(
                        tabs = listOf(
                            GuideStrings.themeModeSystem.text,
                            GuideStrings.themeModeLight.text,
                            GuideStrings.themeModeDark.text,
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
                    GuideGroupTitle(GuideStrings.guidePersonalizeSeedColorTitle.text, dark)
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
                    GuideGroupTitle(GuideStrings.guideShortNameAdviceTitle.text, dark)
                    Spacer(Modifier.height(6.dp))
                    // 发布版卡片首句：先说「为什么简称值得填」，再给推荐 / 不推荐两行示例。
                    GuideParagraph(GuideStrings.guideShortNameAdviceSubtitle.text, dark)
                    Spacer(Modifier.height(16.dp))
                    ExampleRow(ok = true, label = GuideStrings.guideShortNameRecommended.text, example = GuideStrings.guideShortNameRecommendedExample.text, dark = dark)
                    Spacer(Modifier.height(12.dp))
                    ExampleRow(ok = false, label = GuideStrings.guideShortNameNotRecommended.text, example = GuideStrings.guideShortNameNotRecommendedExample.text, dark = dark)
                    Spacer(Modifier.height(18.dp))
                    // 卡片内按钮是「次要动作」，不跟底栏主按钮抢视觉：主色 12% 的浅底 + 主色字。
                    // 原来用卡片同色做底，在白卡上等于隐形，只剩一行飘着的文字。
                    Button(
                        onClick = onOpenCourseOverview,
                        colors = ButtonDefaults.buttonColors(
                            Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.12f),
                        ),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = GuideStrings.guideSetCourseShortNameAction.text,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.primary(dark = dark)),
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
                Column {
                    GuideGroupTitle(GuideStrings.guideImportMethodsTitle.text, dark)
                    Spacer(Modifier.height(6.dp))
                    // 发布版卡片首句：先说整体有什么方式，再列 3 条步骤。
                    GuideParagraph(GuideStrings.guideImportMethodsSubtitle.text, dark)
                    Spacer(Modifier.height(16.dp))
                    StepRow("1", GuideStrings.guideImportMethodStep1.text, dark)
                    Spacer(Modifier.height(12.dp))
                    StepRow("2", GuideStrings.guideImportMethodStep2.text, dark)
                    Spacer(Modifier.height(12.dp))
                    StepRow("3", GuideStrings.guideImportMethodStep3.text, dark)
                    // 发布版在 3 条步骤之后补一句「也可以参与适配」的次要说明（mutedBody）。
                    // 只靠 18dp 留白分层：守卫（RowDividerGuardTest）不允许在同一张卡的
                    // 内容之间插 HorizontalDivider，官方 demo 也是用行距而不是横线。
                    Spacer(Modifier.height(18.dp))
                    GuideParagraph(GuideStrings.guideImportMethodExtra.text, dark)
                }
            }
        }

        item(key = "finalTips") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guideFinalTipsTitle.text, dark)
                    Spacer(Modifier.height(10.dp))
                    NumberedTip(GuideStrings.guideFinalTip1.text, dark)
                    Spacer(Modifier.height(10.dp))
                    NumberedTip(GuideStrings.guideFinalTip2.text, dark)
                    Spacer(Modifier.height(10.dp))
                    NumberedTip(GuideStrings.guideFinalTip3.text, dark)
                }
            }
        }
    }
}

@Composable
private fun ExampleRow(ok: Boolean, label: String, example: String, dark: Boolean) {
    // 两行结构：第一行「对 / 错 + 结论」，第二行才是示例本身。
    //
    // 原来把结论和示例塞在同一行、给结论固定 56dp：中文「推荐示例」正好 52dp 勉强挤下，
    // 英文 “Not recommended” 却要 90dp 左右，只能折行或把示例顶歪；示例列也永远对不齐。
    // 改成上下两行后，结论宽度随语言自然撑开，示例统一从 20dp 缩进起步，哪种语言都齐。
    val markColor = if (ok) {
        Color(QingyuTheme.success(dark))
    } else {
        Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.55f)
    }
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = if (ok) "✓" else "✗",
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
                color = markColor,
                modifier = Modifier.width(20.dp),
            )
            Text(
                text = label,
                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Spacer(Modifier.height(3.dp))
        Text(
            text = example,
            style = MiuixTheme.textStyles.body2,
            // 不推荐的那条压成次要色：不是「看不清」，而是明确降一级，眼睛先看到推荐写法。
            color = if (ok) {
                Color(QingyuTheme.primaryText(dark))
            } else {
                Color(QingyuTheme.secondaryText(dark))
            },
            lineHeight = 21.sp,
            modifier = Modifier.padding(start = 20.dp),
        )
    }
}

@Composable
private fun StepRow(step: String, text: String, dark: Boolean) {
    // 顶对齐：一条步骤经常两行以上，序号垂直居中会飘到段落中间（原来就是这样）。
    Row(verticalAlignment = Alignment.Top) {
        Text(
            text = step,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.primary(dark = dark)),
            modifier = Modifier.width(20.dp),
        )
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
            lineHeight = 20.sp,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 匹配「1. 」「2、」这类写在文案里的序号（六份 ARB 都是同一格式）。 */
private val orderedTipPrefix = Regex("""^[\s\u3000]*(\d+)[.、][\s\u3000]*""")

/**
 * 把 ARB 里自带「1. 」的提醒拆成「序号列 + 正文」两段渲染。
 *
 * 只改排版、不改字：序号和正文仍然逐字上屏，只是正文折行后能对齐到 20dp 缩进，
 * 不会像整段 `1. …` 那样第二行顶回最左边。遇到没有序号的译文就原样交给 [GuideParagraph]，
 * 不为「格式」赌一条文案一定长什么样。
 */
@Composable
private fun NumberedTip(text: String, dark: Boolean) {
    val prefix = orderedTipPrefix.find(text)
    if (prefix == null) {
        GuideParagraph(text, dark)
        return
    }
    Row(verticalAlignment = Alignment.Top) {
        Text(
            text = prefix.groupValues[1],
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.primary(dark = dark)),
            modifier = Modifier.width(20.dp),
        )
        Text(
            text = text.substring(prefix.range.last + 1),
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            lineHeight = 20.sp,
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
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            for (i in 0 until TOTAL_GUIDE_PAGES) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(3.dp)
                        .clip(RoundedCornerShape(1.5.dp))
                        .background(
                            if (i <= currentPage) primary
                            else Color(QingyuTheme.dividerLine(dark)),
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
                    label = if (isPrivacyPage) GuideStrings.exitAppAction.text else GuideStrings.guidePrevButton.text,
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
                        if (requireConsent) GuideStrings.agreeAndStartAction.text else GuideStrings.gotItAction.text
                    } else {
                        GuideStrings.guideNextButton.text
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

// ── 预览：Android Studio 里免装机看效果（2026-11-08 加，2026-11-09 补全状态）────────
//
// 一条预览 = 一个真实状态，覆盖「五页 × 首启 / 复看 × 明暗 × 大字号」以及页内分支：
//   · 欢迎页：首启（无返回、底栏只有「下一步」）/ 复看（右上返回）/ 暗色；
//   · 隐私页：待勾选（「下一步」禁用、次按钮变「退出」）/ 已勾选 / 复看（不显示勾选卡）/ 大字号；
//   · 权限页：探测中（转圈）/ 3 of 6（含「已开启待生效」）/ 0 of 6（含「建议检查」）/ 全开 / 暗色；
//   · 个性化页：默认档（宫格 + 液态玻璃 + 跟随系统 + 湖水蓝）/ 实体 + 暗色 + 竹林绿 / 大字号；
//   · 技巧页：首启末页（同意并开始）/ 复看末页（知道了）。
//
// 静态预览能落到指定页，靠 `UserGuidePage(initialPage = …)`——它只给 `rememberPagerState`
// 一个初值；首启未勾选隐私时仍被收在第 2 页，绕不过同意流程。
//
// 预览名用中文，和 WeatherCityPickerPage 等页一致。它们会计入 `CjkLiteralGateTest`
// 的文件计数：这是**预览样例**，不是屏上文案，基线里按文件登记，别当成 i18n 回归。

/** 权限页要看的六项真实状态：全开（对齐「权限都给够了」的正常形态）。 */
private val previewGuidePermissions = GuidePermissionState(
    notification = true,
    promotedIsland = true,
    promotedDeclared = true,
    autoStart = true,
    batteryUnrestricted = true,
    keepAliveAccessibility = true,
    doNotDisturbAccess = true,
)

/** 权限页 3 / 6：超级岛未开、清单已声明，未开文案走「已开启待生效」。 */
private val previewGuidePermissionsPartial = GuidePermissionState(
    notification = true,
    promotedIsland = false,
    promotedDeclared = true,
    autoStart = true,
    batteryUnrestricted = false,
    keepAliveAccessibility = true,
    doNotDisturbAccess = false,
)

/** 权限页 0 / 6：六项都探测过且都没开，清单未声明超级岛，未开文案走「建议检查」。 */
private val previewGuidePermissionsNone = GuidePermissionState(
    notification = false,
    promotedIsland = false,
    promotedDeclared = false,
    autoStart = false,
    batteryUnrestricted = false,
    keepAliveAccessibility = false,
    doNotDisturbAccess = false,
)

/** 个性化页默认档：宫格菜单 + 液态玻璃 + 跟随系统 + 湖水蓝。 */
private val previewGuideSettings = GuideSettingsSnapshot(
    homeMenuGrid = true,
    materialSolid = false,
    themeMode = GuideThemeMode.SYSTEM,
    seedHex = "#3B82F6",
)

/** 个性化页另一档：列表菜单 + 实体材质 + 暗色档 + 竹林绿（壁纸提示随实体材质隐藏）。 */
private val previewGuideSettingsSolid = GuideSettingsSnapshot(
    homeMenuGrid = false,
    materialSolid = true,
    themeMode = GuideThemeMode.DARK,
    seedHex = "#22C55E",
)

/** 个性化页的主题色豆（中文名 + 十六进制），与设置页同一批色语义。 */
private val previewGuideSeedOptions = listOf(
    GuideSeedOption(hex = "#3B82F6", label = "湖水蓝"),
    GuideSeedOption(hex = "#22C55E", label = "竹林绿"),
    GuideSeedOption(hex = "#F59E0B", label = "暖阳橙"),
    GuideSeedOption(hex = "#8B5CF6", label = "藤萝紫"),
    GuideSeedOption(hex = "#EF4444", label = "朱砂红"),
)

/** 一档预览的公共身体：起始页 + 模式 + 页内数据 + 外观档位。 */
@Composable
private fun PreviewUserGuidePage(
    initialPage: Int = 0,
    requirePrivacyConsent: Boolean = true,
    privacyChecked: Boolean = false,
    permissionState: GuidePermissionState = previewGuidePermissions,
    settings: GuideSettingsSnapshot = previewGuideSettings,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        UserGuidePage(
            requirePrivacyConsent = requirePrivacyConsent,
            initialPrivacyChecked = privacyChecked,
            initialPage = initialPage,
            permissionState = permissionState,
            settings = settings,
            seedOptions = previewGuideSeedOptions,
            onBack = {},
        )
    }
}

// ── 第 1 页 · 欢迎 ──

@Suppress("unused")
@Preview(name = "1/5 欢迎·首启", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewWelcomeFirstRun() {
    PreviewUserGuidePage(initialPage = 0)
}

@Suppress("unused")
@Preview(name = "1/5 欢迎·复看", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewWelcomeRevisit() {
    PreviewUserGuidePage(initialPage = 0, requirePrivacyConsent = false)
}

@Suppress("unused")
@Preview(name = "1/5 欢迎·暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewWelcomeDark() {
    PreviewUserGuidePage(initialPage = 0, dark = true)
}

// ── 第 2 页 · 隐私 ──

@Suppress("unused")
@Preview(name = "2/5 隐私·待勾选", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPrivacyPending() {
    PreviewUserGuidePage(initialPage = 1)
}

@Suppress("unused")
@Preview(name = "2/5 隐私·已勾选", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPrivacyChecked() {
    PreviewUserGuidePage(initialPage = 1, privacyChecked = true)
}

@Suppress("unused")
@Preview(name = "2/5 隐私·复看", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPrivacyRevisit() {
    PreviewUserGuidePage(initialPage = 1, requirePrivacyConsent = false)
}

@Suppress("unused")
@Preview(name = "2/5 隐私·大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPrivacyLargeText() {
    PreviewUserGuidePage(initialPage = 1, textScale = 1.3f)
}

// ── 第 3 页 · 系统权限 ──

@Suppress("unused")
@Preview(name = "3/5 权限·探测中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPermissionsLoading() {
    PreviewUserGuidePage(
        initialPage = 2,
        privacyChecked = true,
        permissionState = GuidePermissionState(),
    )
}

@Suppress("unused")
@Preview(name = "3/5 权限·3/6", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPermissionsPartial() {
    PreviewUserGuidePage(
        initialPage = 2,
        privacyChecked = true,
        permissionState = previewGuidePermissionsPartial,
    )
}

@Suppress("unused")
@Preview(name = "3/5 权限·0/6", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPermissionsNone() {
    PreviewUserGuidePage(
        initialPage = 2,
        privacyChecked = true,
        permissionState = previewGuidePermissionsNone,
    )
}

@Suppress("unused")
@Preview(name = "3/5 权限·6/6", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPermissionsAllGranted() {
    PreviewUserGuidePage(initialPage = 2, privacyChecked = true)
}

@Suppress("unused")
@Preview(name = "3/5 权限·暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPermissionsDark() {
    PreviewUserGuidePage(initialPage = 2, privacyChecked = true, dark = true)
}

// ── 第 4 页 · 个性化 ──

@Suppress("unused")
@Preview(name = "4/5 个性化·默认", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPersonalizeDefault() {
    PreviewUserGuidePage(initialPage = 3, privacyChecked = true)
}

@Suppress("unused")
@Preview(name = "4/5 个性化·实体+暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPersonalizeSolidDark() {
    PreviewUserGuidePage(
        initialPage = 3,
        privacyChecked = true,
        settings = previewGuideSettingsSolid,
        dark = true,
    )
}

@Suppress("unused")
@Preview(name = "4/5 个性化·大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewPersonalizeLargeText() {
    PreviewUserGuidePage(initialPage = 3, privacyChecked = true, textScale = 1.3f)
}

// ── 第 5 页 · 使用技巧 ──

@Suppress("unused")
@Preview(name = "5/5 技巧·首启末页", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewTipsFirstRun() {
    PreviewUserGuidePage(initialPage = 4, privacyChecked = true)
}

@Suppress("unused")
@Preview(name = "5/5 技巧·复看末页", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun UserGuidePagePreviewTipsRevisit() {
    PreviewUserGuidePage(initialPage = 4, requirePrivacyConsent = false)
}
