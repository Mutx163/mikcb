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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuBackIconButton
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Update
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 用户指南 / 新手引导 · Compose 渲染层（极简重设计版）。
 *
 * ## 设计取向（2026-10-28 用户拍板）
 *
 * 「Avoid unnecessary secondary labels and descriptions. Let the layout do the explaining.」
 * —— 一条信息原则：**每页只有「标题 + 内容/操作」**。具体做法：
 * - **没有顶栏、没有大标题、没有折叠/缩放动画**：页面标题就是正文第一行（大号左对齐），
 *   跟着内容一起滚，标题与页面是一体的；
 * - 删掉所有「把标题换个说法」的灰字、复述性副标题、导航说明；
 * - 隐私页是唯一保留长文的地方（法律正文），其余页面靠排版 / 图标 / ✓✗ 对比 / 色块说话。
 *
 * 行为真相仍是 `lib/screens/user_guide_screen.dart`；本页只做「减字 + 去大标题」，
 * 功能（真实权限状态、个性化写回、隐私同意、横滑翻页）一个不少。
 *
 * ## 分层（未变）
 *
 * 本层不探测系统、不写设置：六项权限真实状态经 [permissionState] 传入，个性化改动经
 * [onSettingsPatch] 交宿主落盘，权限行点击经 [onPermissionAction] 交宿主拉起系统页。
 * 契约类型见 [GuideRuntimeTypes]（Lead 冻结）。
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

    // 首启未同意隐私前锁住横滑（恒挂 5 页，用 userScrollEnabled 锁，按钮推进）。
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

    // 欢迎页导入/恢复：首启未同意隐私前先跳隐私页（Dart :464-480）。
    val runWelcomeAction: (() -> Unit) -> Unit = { action ->
        if (requirePrivacyConsent && !privacyChecked) goToPage(1) else action()
    }

    // 复看模式（从设置进入）才给「关闭」返回键；首启模式必须走完流程。
    val closeGuide: (() -> Unit)? = if (requirePrivacyConsent) null else onBack

    // 无顶栏、无大标题：标题在每页正文首行。Scaffold 只负责底色与底栏。
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
                        onBack = closeGuide,
                        onStart = { goToPage(1) },
                        onImport = { runWelcomeAction(onImportCourses) },
                        onRestore = { runWelcomeAction(onRestoreBackup) },
                    )

                    1 -> PrivacyPage(
                        innerPadding = innerPadding,
                        title = pageTitles[1],
                        onBack = closeGuide,
                        requireConsent = requirePrivacyConsent,
                        consentChecked = privacyChecked,
                        onConsentChanged = { privacyChecked = it },
                    )

                    2 -> PermissionsPage(
                        innerPadding = innerPadding,
                        title = pageTitles[2],
                        onBack = closeGuide,
                        state = permissionState,
                        onPermissionAction = onPermissionAction,
                        onRefresh = onRefreshPermissions,
                    )

                    3 -> PersonalizePage(
                        innerPadding = innerPadding,
                        title = pageTitles[3],
                        onBack = closeGuide,
                        settings = settings,
                        seedOptions = seedOptions,
                        onSettingsPatch = onSettingsPatch,
                    )

                    4 -> TipsPage(
                        innerPadding = innerPadding,
                        title = pageTitles[4],
                        onBack = closeGuide,
                        onOpenCourseOverview = onOpenCourseOverview,
                    )
                }
            }
        }
    }
}

/** 引导页总页数（Dart :70）。 */
private const val TOTAL_GUIDE_PAGES = 5

// ───────────────────────────── 共用：页头（标题即正文首行） ─────────────────────────────

/**
 * 无顶栏页头：可选「关闭返回键 + 右侧动作」一行，下面直接是大号标题。
 *
 * 视觉上标题落在正文里、随内容滚动，与页面融为一体；没有条形底色、没有折叠缩放。
 */
@Composable
private fun GuideHeader(
    title: String,
    onBack: (() -> Unit)?,
    action: (@Composable () -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    Column(Modifier.fillMaxWidth()) {
        if (onBack != null || action != null) {
            Row(
                modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (onBack != null) QingyuBackIconButton(onBack = onBack)
                Spacer(Modifier.weight(1f))
                action?.invoke()
            }
        }
        Text(
            text = title,
            style = MiuixTheme.textStyles.title2,
            fontWeight = FontWeight.Bold,
            color = Color(QingyuTheme.primaryText(dark)),
        )
    }
}

/** 一组内容的小标题（body2 加粗）。只用于真正分组的组名，不复述页面标题。 */
@Composable
private fun GuideGroupTitle(text: String, dark: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.body2,
        fontWeight = FontWeight.Bold,
        color = Color(QingyuTheme.primaryText(dark)),
    )
}

/** 正文段落（footnote1，舒适行高）。 */
@Composable
private fun GuideParagraph(text: String, dark: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = Color(QingyuTheme.secondaryText(dark)),
        lineHeight = 20.sp,
    )
}

// ───────────────────────────── 欢迎页 ─────────────────────────────

@Composable
private fun WelcomePage(
    innerPadding: PaddingValues,
    title: String,
    onBack: (() -> Unit)?,
    onStart: () -> Unit,
    onImport: () -> Unit,
    onRestore: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, onBack) }

        item(key = "brand") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Text(
                    text = GuideStrings.welcomeAppName.zh,
                    style = MiuixTheme.textStyles.title3,
                    fontWeight = FontWeight.Bold,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }

        item(key = "actions") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    GuideNavRow(MiuixIcons.Play, GuideStrings.startUsingTitle.zh, onStart)
                    HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
                    GuideNavRow(MiuixIcons.Import, GuideStrings.importTimetableTitle.zh, onImport)
                    HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
                    GuideNavRow(MiuixIcons.Update, GuideStrings.restoreBackupTitle.zh, onRestore)
                }
            }
        }
    }
}

/** 一行动作：图标 + 标题 + chevron（无副标题，靠图标和标题自己解释）。 */
@Composable
private fun GuideNavRow(icon: ImageVector, title: String, onClick: () -> Unit) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color(QingyuTheme.primary(dark = dark)),
            modifier = Modifier.size(22.dp),
        )
        Spacer(Modifier.width(14.dp))
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(16.dp),
        )
    }
}

// ───────────────────────────── 隐私页 ─────────────────────────────

@Composable
private fun PrivacyPage(
    innerPadding: PaddingValues,
    title: String,
    onBack: (() -> Unit)?,
    requireConsent: Boolean,
    consentChecked: Boolean,
    onConsentChanged: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, onBack) }

        // 隐私正文：法律正文，保留（不属于「次要标签」）。
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

        // 免责与风险：保留一个组名 + 三段，标题不复述页面名。
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
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
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
        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") {
            GuideHeader(title, onBack, action = {
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
            // 进度：一根条 + N/6，一句说明都不要。
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
                            style = MiuixTheme.textStyles.body1,
                            fontWeight = FontWeight.Bold,
                            color = Color(QingyuTheme.primary(dark = dark)),
                        )
                        Spacer(Modifier.height(10.dp))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(CircleShape)
                                .background(Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.15f)),
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(progress.ratio)
                                    .height(6.dp)
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
                            if (idx > 0) HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
                            GuidePermissionRow(
                                item = item,
                                dark = dark,
                                onClick = { permissionActionOf(item.id)?.let(onPermissionAction) },
                            )
                        }
                    }
                }
            }

            item(key = "footnote") {
                Text(
                    text = GuideStrings.guidePermissionsFooterHint.zh,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
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
        true -> Color(QingyuTheme.primary(dark = dark))
        false -> Color(QingyuTheme.secondaryText(dark))
        null -> Color(QingyuTheme.secondaryText(dark))
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
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
        Text(
            text = if (item.enabled == true) item.enabledLabel else item.disabledLabel,
            style = MiuixTheme.textStyles.footnote1,
            color = statusColor,
        )
        Spacer(Modifier.width(6.dp))
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(14.dp),
        )
    }
}

private fun permissionActionOf(id: String): GuidePermissionAction? =
    GuidePermissionAction.values().firstOrNull { it.name == id }

// ───────────────────────────── 个性化页 ─────────────────────────────

@Composable
private fun PersonalizePage(
    innerPadding: PaddingValues,
    title: String,
    onBack: (() -> Unit)?,
    settings: GuideSettingsSnapshot,
    seedOptions: List<GuideSeedOption>,
    onSettingsPatch: (GuideSettingsPatch) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, onBack) }

        // 菜单样式：两个选项只留标题，选中靠边框。
        item(key = "menuStyle") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guidePersonalizeMenuStyleTitle.zh, dark)
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OptionCard(
                            label = GuideStrings.homeMenuStyleList.zh,
                            selected = !settings.homeMenuGrid,
                            dark = dark,
                            onClick = { onSettingsPatch(GuideSettingsPatch.HomeMenuGrid(false)) },
                            modifier = Modifier.weight(1f),
                        )
                        OptionCard(
                            label = GuideStrings.homeMenuStyleGrid.zh,
                            selected = settings.homeMenuGrid,
                            dark = dark,
                            onClick = { onSettingsPatch(GuideSettingsPatch.HomeMenuGrid(true)) },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }

        // 深浅色：三档分段，选项名本身承载语义，不加说明句。
        item(key = "themeMode") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guidePersonalizeThemeModeTitle.zh, dark)
                    Spacer(Modifier.height(10.dp))
                    TabRow(
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
                    )
                }
            }
        }

        // 主题色：纯色块，靠颜色自己解释，无文字。
        item(key = "seedColor") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    GuideGroupTitle(GuideStrings.guidePersonalizeSeedColorTitle.zh, dark)
                    Spacer(Modifier.height(12.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        items(seedOptions) { option ->
                            ThemeSwatch(
                                hex = option.hex,
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

@Composable
private fun OptionCard(
    label: String,
    selected: Boolean,
    dark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) primary.copy(alpha = 0.12f) else Color(QingyuTheme.card(dark)))
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) primary else Color(QingyuTheme.dividerLine(dark)),
                shape = RoundedCornerShape(12.dp),
            )
            .clickable(onClick = onClick)
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body1,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) primary else Color(QingyuTheme.primaryText(dark)),
        )
    }
}

@Composable
private fun ThemeSwatch(
    hex: String,
    selected: Boolean,
    dark: Boolean,
    onClick: () -> Unit,
) {
    val color = parseHexColorOrFallback(hex)
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(color)
            .border(
                width = if (selected) 3.dp else 1.dp,
                color = if (selected) Color(QingyuTheme.primaryText(dark)) else Color(QingyuTheme.dividerLine(dark)),
                shape = CircleShape,
            )
            .clickable(onClick = onClick),
    )
}

// ───────────────────────────── 使用技巧页 ─────────────────────────────

@Composable
private fun TipsPage(
    innerPadding: PaddingValues,
    title: String,
    onBack: (() -> Unit)?,
    onOpenCourseOverview: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageList(
        innerPadding = innerPadding,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        item(key = "header") { GuideHeader(title, onBack) }

        // 简称：一条 ✓ 正例、一条 ✗ 反例，排版自己说明。
        item(key = "shortName") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column {
                    ExampleRow(
                        ok = true,
                        label = GuideStrings.guideShortNameRecommended.zh,
                        example = GuideStrings.guideShortNameRecommendedExample.zh,
                        dark = dark,
                    )
                    Spacer(Modifier.height(8.dp))
                    ExampleRow(
                        ok = false,
                        label = GuideStrings.guideShortNameNotRecommended.zh,
                        example = GuideStrings.guideShortNameNotRecommendedExample.zh,
                        dark = dark,
                    )
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

        // 导入方法：三步，数字 + 短句。
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

        // 最终提示：三条，勾 + 短句。
        item(key = "finalTips") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    GuideGroupTitle(GuideStrings.guideFinalTipsTitle.zh, dark)
                    TipRow(GuideStrings.guideFinalTip1.zh, dark)
                    TipRow(GuideStrings.guideFinalTip2.zh, dark)
                    TipRow(GuideStrings.guideFinalTip3.zh, dark)
                }
            }
        }
    }
}

/** ✓ / ✗ 对比行：符号着色 + 标签 + 例子。 */
@Composable
private fun ExampleRow(ok: Boolean, label: String, example: String, dark: Boolean) {
    val markColor = if (ok) Color(QingyuTheme.primary(dark = dark)) else Color(QingyuTheme.secondaryText(dark))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = if (ok) "✓" else "✗",
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Bold,
            color = markColor,
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(Modifier.width(6.dp))
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
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape)
                .background(Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = step,
                style = MiuixTheme.textStyles.footnote2,
                fontWeight = FontWeight.Bold,
                color = Color(QingyuTheme.primary(dark = dark)),
            )
        }
        Spacer(Modifier.width(10.dp))
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun TipRow(text: String, dark: Boolean) {
    Row(verticalAlignment = Alignment.Top) {
        Text(
            text = "✓",
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Bold,
            color = Color(QingyuTheme.primary(dark = dark)),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
            lineHeight = 19.sp,
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
    val onCardText = Color(QingyuTheme.primaryText(dark))

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(QingyuTheme.scaffoldBackground(dark)))
            .padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            when {
                isPrivacyPage -> GuideSecondaryButton(
                    label = GuideStrings.exitAppAction.zh,
                    textColor = onCardText,
                    cardColor = Color(QingyuTheme.card(dark)),
                    onClick = onExit,
                )

                currentPage > 0 -> GuideSecondaryButton(
                    label = GuideStrings.guidePrevButton.zh,
                    textColor = onCardText,
                    cardColor = Color(QingyuTheme.card(dark)),
                    onClick = onPrev,
                )

                else -> Spacer(Modifier.width(56.dp))
            }

            if (!isLastPage) {
                Button(
                    onClick = onNext,
                    enabled = canGoNext,
                    colors = ButtonDefaults.buttonColors(primary),
                ) {
                    Text(
                        text = GuideStrings.guideNextButton.zh,
                        color = Color.White,
                        style = MiuixTheme.textStyles.body2,
                        fontWeight = FontWeight.Medium,
                    )
                }
            } else {
                Button(
                    onClick = onNext,
                    colors = ButtonDefaults.buttonColors(primary),
                ) {
                    Text(
                        text = if (requireConsent) {
                            GuideStrings.agreeAndStartAction.zh
                        } else {
                            GuideStrings.gotItAction.zh
                        },
                        color = Color.White,
                        style = MiuixTheme.textStyles.body2,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }

        // 圆点整屏水平居中（Dart :305-351）；非交互装饰，整组承担页码语义。
        GuidePageDots(
            dark = dark,
            currentPage = currentPage,
            modifier = Modifier.align(Alignment.Center),
        )
    }
}

@Composable
private fun GuidePageDots(
    dark: Boolean,
    currentPage: Int,
    modifier: Modifier = Modifier,
) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    val inactive = Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.3f)

    Row(
        modifier = modifier.clearAndSetSemantics {
            contentDescription = "${currentPage + 1} / $TOTAL_GUIDE_PAGES"
        },
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (i in 0 until TOTAL_GUIDE_PAGES) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(if (i == currentPage) primary else inactive),
            )
        }
    }
}

@Composable
private fun GuideSecondaryButton(
    label: String,
    textColor: Color,
    cardColor: Color,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(cardColor),
    ) {
        Text(
            text = label,
            color = textColor,
            style = MiuixTheme.textStyles.body2,
            fontWeight = FontWeight.Medium,
        )
    }
}
