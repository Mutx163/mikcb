package com.mutx163.qingyu.pages.timetable

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.rememberShellShouldShowBackButton
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.ChevronBackward
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Clear
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 领域模型转换为展示条目。
 *
 * `TimetableProfileItem` 由模型层（`main/…/pages/timetable/TimetableProfilesModel.kt`）定义，
 * 渲染层不再重复声明一份同名同包的数据类——那样模型层一旦被编进同一个变体就是重名冲突。
 */
fun TimetableProfile.toItem(isActive: Boolean): TimetableProfileItem =
    TimetableProfileItem(
        id = id,
        name = name,
        courseCount = courses.size,
        currentWeek = currentWeek,
        isPartnerImported = isPartnerImported,
        isActive = isActive,
    )

/**
 * 示例数据，供开发预览或壳使用。
 */
fun sampleProfileItems(): List<TimetableProfileItem> = listOf(
    TimetableProfileItem(
        id = "profile_1",
        name = "大二下学期",
        courseCount = 12,
        currentWeek = 8,
        isPartnerImported = false,
        isActive = true,
    ),
    TimetableProfileItem(
        id = "profile_2",
        name = "考研自习",
        courseCount = 4,
        currentWeek = 8,
        isPartnerImported = false,
        isActive = false,
    ),
    TimetableProfileItem(
        id = "profile_3",
        name = "小柒的课表",
        courseCount = 9,
        currentWeek = 8,
        isPartnerImported = true,
        isActive = false,
    ),
)

/**
 * 多课表管理页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/timetable_profiles_screen.dart`：
 * - 顶栏：返回按钮 + 页面标题（"课表管理"）+ 新建课表按钮（"+"）
 * - 课表档案列表：
 *   - 展示名称、课程数量与当前周数摘要
 *   - 结伴导入课表显示 "情侣课表" 徽标与 "对方课表 只读"
 *   - 激活状态展示对勾高亮，非激活状态展示向右箭头并支持点击整行直接切换
 *   - 更多操作弹层：重命名、复制、清空课程（限激活非结伴）、删除（限多于1个且非结伴）
 * - 二次确认与弹窗交互：新建对话框、重命名对话框、清空确认、删除确认
 * - 提示反馈：轻量底部 Toast
 */
@Composable
fun TimetableProfilesPage(
    profiles: List<TimetableProfileItem>,
    onBack: () -> Unit,
    onCreateProfile: (name: String) -> Unit,
    onSwitchProfile: (profileId: String) -> Unit,
    onRenameProfile: (profileId: String, newName: String) -> Unit,
    onDuplicateProfile: (profileId: String) -> Unit,
    onClearCourses: (profileId: String) -> Unit,
    onDeleteProfile: (profileId: String) -> Unit,
    modifier: Modifier = Modifier,
    toastMessage: String? = null,
    onDismissToast: (() -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()

    // 弹窗状态
    var showCreateDialog by remember { mutableStateOf(false) }
    var activeMenuProfile by remember { mutableStateOf<TimetableProfileItem?>(null) }
    var renamingProfile by remember { mutableStateOf<TimetableProfileItem?>(null) }
    var clearingProfile by remember { mutableStateOf<TimetableProfileItem?>(null) }
    var deletingProfile by remember { mutableStateOf<TimetableProfileItem?>(null) }
    var localToast by remember { mutableStateOf<String?>(null) }

    val currentToast = toastMessage ?: localToast
    // ⚠️ key 必须是 [currentToast]（两条来源的合集），不能只写 `localToast`：
    // 宿主喂的是 `toastMessage`（控制器算好的「已创建 / 已切换 / 已删除」），
    // 只拿 localToast 当 key 时宿主文案变化不会重启本 effect ⇒ 底部那条黑胶囊**永远不走**。
    LaunchedEffect(currentToast) {
        if (currentToast != null) {
            delay(2200)
            // 两条来源都要清：localToast 是页内提示（「至少保留一个课表」），
            // toastMessage 由宿主持有、靠 onDismissToast 交还。
            localToast = null
            onDismissToast?.invoke()
        }
    }

    // Dart timetable_profiles_screen.dart:27-29 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        modifier = modifier,
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = TimetableStrings.timetableProfilesTitle.zh,
                largeTitle = TimetableStrings.timetableProfilesTitle.zh,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    if (rememberShellShouldShowBackButton()) {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.ChevronBackward,
                                contentDescription = TimetableStrings.cancelAction.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    }
                },
                // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
                actions = {
                    QingyuGlassIconButton(
                        onClick = { showCreateDialog = true },
                        contentDescription = TimetableStrings.createTimetableTooltip.zh,
                        icon = MiuixIcons.Add,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                },
            )
        },
    ) { innerPadding ->
        // 页面级主滚动走共享列表（2026-11-04 收口）：原先 Box(padding(innerPadding)) 里再套
        // Column 的裸 LazyColumn。外层 Box 继续留着——Toast 要压在列表上（align BottomCenter）。
        // 版面账：列表的 innerPadding 交给组件；Toast 原先在带 innerPadding 的 Box 里，
        // 现在改由自己补同样的底部偏移（innerPadding.bottom + 32dp），位置一分不差。
        Box(modifier = Modifier.fillMaxSize()) {
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                extraTopPadding = 8.dp,
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    // 组件内部已算一次 innerPadding 底部；保持原先「再叠一次 + 8dp」的账。
                    bottom = innerPadding.calculateBottomPadding() + 8.dp,
                ),
            ) {
                item {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(0.dp),
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            profiles.forEachIndexed { index, profile ->
                                TimetableProfileRow(
                                    profile = profile,
                                    dark = dark,
                                    onRowClick = {
                                        if (!profile.isActive && !profile.isPartnerImported) {
                                            onSwitchProfile(profile.id)
                                        }
                                    },
                                    onMoreClick = {
                                        activeMenuProfile = profile
                                    },
                                )
                            }
                        }
                    }
                }
            }

            // ── 底部 Toast 提示浮层 ──
            AnimatedVisibility(
                visible = currentToast != null,
                enter = fadeIn() + slideInVertically { it / 2 },
                exit = fadeOut() + slideOutVertically { it / 2 },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(
                        start = 24.dp,
                        end = 24.dp,
                        bottom = innerPadding.calculateBottomPadding() + 32.dp,
                    ),
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color(if (dark) 0xFF383838 else 0xFF222222))
                        .padding(horizontal = 20.dp, vertical = 10.dp),
                ) {
                    Text(
                        text = currentToast.orEmpty(),
                        color = Color.White,
                        style = MiuixTheme.textStyles.body2,
                    )
                }
            }
        }
    }

    // ── 4. 弹窗与对话框 ──

    // 4.1 新建课表弹窗：**常驻组合**，显隐只由 `show` 驱动。
    // 条件挂载会让官方退场动画一次都播不出来（2026-11-02 弹层债口径）。
    CreateProfileDialog(
        show = showCreateDialog,
        onDismiss = { showCreateDialog = false },
        onConfirm = { name ->
            showCreateDialog = false
            onCreateProfile(name)
        },
    )

    // 4.2 更多操作弹层：同样**常驻组合**——`?.let {}` 也是条件挂载，退场动画同样被打断。
    // 关闭时宿主把状态置空，因此回调用 `rememberLastNonNull` 的上一份快照取 id。
    val menuProfile = rememberLastNonNull(activeMenuProfile)
    ProfileMoreActionsDialog(
        profileOrNull = activeMenuProfile,
        show = activeMenuProfile != null,
        canDelete = menuProfile?.let { profiles.size > 1 && !it.isPartnerImported } ?: false,
        dark = dark,
        onDismiss = { activeMenuProfile = null },
        onSwitch = {
            activeMenuProfile = null
            menuProfile?.let { onSwitchProfile(it.id) }
        },
        onRename = {
            activeMenuProfile = null
            renamingProfile = menuProfile
        },
        onDuplicate = {
            activeMenuProfile = null
            menuProfile?.let { onDuplicateProfile(it.id) }
        },
        onClear = {
            activeMenuProfile = null
            clearingProfile = menuProfile
        },
        onDelete = {
            activeMenuProfile = null
            deletingProfile = menuProfile
        },
        onCannotDeleteWarning = {
            activeMenuProfile = null
            localToast = TimetableStrings.keepAtLeastOneProfile.zh
        },
    )

    // 4.3 重命名弹窗
    val renameTarget = rememberLastNonNull(renamingProfile)
    RenameProfileDialog(
        profileOrNull = renamingProfile,
        show = renamingProfile != null,
        onDismiss = { renamingProfile = null },
        onConfirm = { newName ->
            renamingProfile = null
            renameTarget?.let { onRenameProfile(it.id, newName) }
        },
    )

    // 4.4 清空课程确认弹窗
    val clearTarget = rememberLastNonNull(clearingProfile)
    ClearCoursesConfirmDialog(
        profileOrNull = clearingProfile,
        show = clearingProfile != null,
        onDismiss = { clearingProfile = null },
        onConfirm = {
            clearingProfile = null
            clearTarget?.let { onClearCourses(it.id) }
        },
    )

    // 4.5 删除课表确认弹窗
    val deleteTarget = rememberLastNonNull(deletingProfile)
    DeleteProfileConfirmDialog(
        profileOrNull = deletingProfile,
        show = deletingProfile != null,
        onDismiss = { deletingProfile = null },
        onConfirm = {
            deletingProfile = null
            deleteTarget?.let { onDeleteProfile(it.id) }
        },
    )
}

/**
 * 兼容接收领域模型 [TimetableProfile] 列表的重载。
 */
@Composable
fun TimetableProfilesPage(
    profiles: List<TimetableProfile>,
    activeProfileId: String,
    onBack: () -> Unit,
    onCreateProfile: (name: String) -> Unit,
    onSwitchProfile: (profileId: String) -> Unit,
    onRenameProfile: (profileId: String, newName: String) -> Unit,
    onDuplicateProfile: (profileId: String) -> Unit,
    onClearCourses: (profileId: String) -> Unit,
    onDeleteProfile: (profileId: String) -> Unit,
    modifier: Modifier = Modifier,
    toastMessage: String? = null,
    onDismissToast: (() -> Unit)? = null,
) {
    val items = remember(profiles, activeProfileId) {
        profiles.map { it.toItem(isActive = it.id == activeProfileId) }
    }
    TimetableProfilesPage(
        profiles = items,
        onBack = onBack,
        onCreateProfile = onCreateProfile,
        onSwitchProfile = onSwitchProfile,
        onRenameProfile = onRenameProfile,
        onDuplicateProfile = onDuplicateProfile,
        onClearCourses = onClearCourses,
        onDeleteProfile = onDeleteProfile,
        modifier = modifier,
        toastMessage = toastMessage,
        onDismissToast = onDismissToast,
    )
}

/**
 * 单个课表条目行展示。
 */
@Composable
private fun TimetableProfileRow(
    profile: TimetableProfileItem,
    dark: Boolean,
    onRowClick: () -> Unit,
    onMoreClick: () -> Unit,
) {
    val isInteractive = !profile.isActive && !profile.isPartnerImported

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = isInteractive, onClick = onRowClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 左侧：名称 + 徽标 + 摘要说明
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = profile.name,
                    style = MiuixTheme.textStyles.main.shiftWeight(
                        if (profile.isActive) QingyuWeightDelta.SEMIBOLD else QingyuWeightDelta.MEDIUM,
                    ),
                    color = if (profile.isActive) {
                        Color(QingyuTheme.primary(dark = dark))
                    } else {
                        Color(QingyuTheme.primaryText(dark))
                    },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (profile.isPartnerImported) {
                    PartnerBadge(dark = dark)
                }
            }

            val summary = if (profile.isPartnerImported) {
                TimetableStrings.coupleTimetablePartnerReadOnlyBadge.zh
            } else {
                // TimetableStrings 的口径收 Int（周次恒为小整数；旧本地函数曾收 Long）。
                TimetableStrings.formatCoursesAndWeekSummary(profile.courseCount, profile.currentWeek.toInt())
            }
            Text(
                text = summary,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        // 右侧操作与状态指示
        if (!profile.isPartnerImported) {
            // 更多操作按钮（三点图标）
            IconButton(
                onClick = onMoreClick,
                modifier = Modifier.size(36.dp),
            ) {
                Icon(
                    imageVector = MiuixIcons.More,
                    contentDescription = TimetableStrings.moreActionsTooltip.zh,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }

            Spacer(modifier = Modifier.width(6.dp))

            // 状态指示槽：激活时对勾高亮，未激活时向右指示箭头
            Box(
                modifier = Modifier.size(24.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (profile.isActive) {
                    Icon(
                        imageVector = MiuixIcons.Ok,
                        contentDescription = TimetableStrings.timetableProfileActiveBadge.zh,
                        tint = Color(QingyuTheme.primary(dark = dark)),
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    Icon(
                        imageVector = MiuixIcons.ChevronForward,
                        contentDescription = null,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
    }
}

/**
 * 结伴 / 情侣课表徽标。
 */
@Composable
private fun PartnerBadge(dark: Boolean) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.12f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(
            text = TimetableStrings.coupleTimetableTitle.zh,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = Color(QingyuTheme.primary(dark = dark)),
        )
    }
}

/**
 * 新建课表对话框。
 */
@Composable
private fun CreateProfileDialog(
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var nameInput by remember { mutableStateOf("") }
    // 拍板 #1：全仓统一「不加自动聚焦」；常驻组合，显隐只由 show 驱动，打开即清空。
    LaunchedEffect(show) {
        if (show) nameInput = ""
    }

    OverlayDialog(
        show = show,
        title = TimetableStrings.createTimetableTitle.zh,
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            TextField(
                value = nameInput,
                onValueChange = { nameInput = it },
                label = TimetableStrings.timetableNameHint.zh,
                modifier = Modifier.fillMaxWidth(),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = TimetableStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    enabled = nameInput.isNotBlank(),
                    onClick = {
                        val trimmed = nameInput.trim()
                        if (trimmed.isNotEmpty()) {
                            onConfirm(trimmed)
                        }
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = TimetableStrings.createAction.zh)
                }
            }
        }
    }
}

/**
 * 重命名课表对话框。
 */
@Composable
private fun RenameProfileDialog(
    profileOrNull: TimetableProfileItem?,
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    // 常驻组合：退场动画期间入参已被宿主置空，用最后一份非空快照继续渲染。
    val current = rememberLastNonNull(profileOrNull)
    var nameInput by remember { mutableStateOf("") }
    // 拍板 #1：全仓统一「不加自动聚焦」；打开时回填名称（Dart 每次弹窗都是新控制器）。
    LaunchedEffect(show) {
        if (show && current != null) nameInput = current.name
    }

    OverlayDialog(
        show = show,
        title = TimetableStrings.renameTimetableTitle.zh,
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        val profile = current ?: return@OverlayDialog
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            TextField(
                value = nameInput,
                onValueChange = { nameInput = it },
                label = TimetableStrings.timetableNameHint.zh,
                modifier = Modifier.fillMaxWidth(),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = TimetableStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    enabled = nameInput.isNotBlank() && nameInput.trim() != profile.name,
                    onClick = {
                        val trimmed = nameInput.trim()
                        if (trimmed.isNotEmpty() && trimmed != profile.name) {
                            onConfirm(trimmed)
                        }
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = TimetableStrings.renameAction.zh)
                }
            }
        }
    }
}

/**
 * 清空课程二次确认对话框。
 */
@Composable
private fun ClearCoursesConfirmDialog(
    profileOrNull: TimetableProfileItem?,
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    // 常驻组合：退场动画期间仍用最后一份非空快照渲染正文。
    val current = rememberLastNonNull(profileOrNull)
    OverlayDialog(
        show = show,
        title = TimetableStrings.clearCurrentTimetableTitle.zh,
        summary = current?.let { TimetableStrings.formatClearCurrentTimetableMessage(it.name) },
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = TimetableStrings.cancelAction.zh,
                onClick = onDismiss,
            )
            // 清空是危险动作：红底 + onError 字，不再是「灰底红字」。
            Button(
                onClick = onConfirm,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    color = MiuixTheme.colorScheme.error,
                    contentColor = MiuixTheme.colorScheme.onError,
                ),
            ) {
                Text(text = TimetableStrings.clearAction.zh)
            }
        }
    }
}

/**
 * 删除课表二次确认对话框。
 */
@Composable
private fun DeleteProfileConfirmDialog(
    profileOrNull: TimetableProfileItem?,
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    // 常驻组合：退场动画期间仍用最后一份非空快照渲染正文。
    val current = rememberLastNonNull(profileOrNull)
    OverlayDialog(
        show = show,
        title = TimetableStrings.deleteTimetableTitle.zh,
        summary = current?.let { TimetableStrings.formatDeleteTimetableMessage(it.name) },
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = TimetableStrings.cancelAction.zh,
                onClick = onDismiss,
            )
            // 删除是危险动作：红底 + onError 字。
            Button(
                onClick = onConfirm,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    color = MiuixTheme.colorScheme.error,
                    contentColor = MiuixTheme.colorScheme.onError,
                ),
            ) {
                Text(text = TimetableStrings.deleteAction.zh)
            }
        }
    }
}

/**
 * 更多操作弹层菜单。
 */
@Composable
private fun ProfileMoreActionsDialog(
    profileOrNull: TimetableProfileItem?,
    show: Boolean,
    canDelete: Boolean,
    dark: Boolean,
    onDismiss: () -> Unit,
    onSwitch: () -> Unit,
    onRename: () -> Unit,
    onDuplicate: () -> Unit,
    onClear: () -> Unit,
    onDelete: () -> Unit,
    onCannotDeleteWarning: () -> Unit,
) {
    // 常驻组合：退场动画期间入参已被宿主置空，用最后一份非空快照继续渲染。
    val current = rememberLastNonNull(profileOrNull)
    // Dart 是 `HyperosSheet` 底部弹层，不是居中 Dialog。
    QingyuSheet(
        show = show,
        title = current?.name.orEmpty(),
        onDismissRequest = onDismiss,
    ) {
        val profile = current ?: return@QingyuSheet
        Column(modifier = Modifier.fillMaxWidth()) {
            // 1. 切换到此课表（非激活状态展示）
            if (!profile.isActive) {
                ActionMenuItem(
                    title = TimetableStrings.switchToThisTimetable.zh,
                    icon = MiuixIcons.Ok,
                    onClick = onSwitch,
                    dark = dark,
                )
            }

            // 2. 重命名
            ActionMenuItem(
                title = TimetableStrings.renameAction.zh,
                icon = MiuixIcons.Edit,
                onClick = onRename,
                dark = dark,
            )

            // 3. 复制
            ActionMenuItem(
                title = TimetableStrings.duplicateAction.zh,
                icon = MiuixIcons.Copy,
                onClick = onDuplicate,
                dark = dark,
            )

            // 4. 清空课程（仅当前激活课表展示）
            if (profile.isActive) {
                val canClear = profile.courseCount > 0
                ActionMenuItem(
                    title = TimetableStrings.clearCoursesAction.zh,
                    icon = MiuixIcons.Clear,
                    isDestructive = true,
                    enabled = canClear,
                    onClick = onClear,
                    dark = dark,
                )
            }

            // 5. 删除课表
            // 这里**不再**用 `enabled = canDelete` 把整行置灰：置灰后 `clickable(enabled=false)`
            // 把下面的 `onCannotDeleteWarning()` 变成不可达分支，用户点「删除」既不删也不提示，
            // 看起来就是「点了没反应」。现在可删 → 走确认；不可删 → 弹「至少保留一个课表」。
            ActionMenuItem(
                title = TimetableStrings.deleteAction.zh,
                icon = MiuixIcons.Delete,
                isDestructive = true,
                onClick = {
                    if (canDelete) {
                        onDelete()
                    } else {
                        onCannotDeleteWarning()
                    }
                },
                dark = dark,
            )

            // 取消按钮
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onDismiss)
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = TimetableStrings.cancelAction.zh,
                    style = MiuixTheme.textStyles.body1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}

/**
 * 弹层菜单单项。
 */
@Composable
private fun ActionMenuItem(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
    dark: Boolean,
    modifier: Modifier = Modifier,
    isDestructive: Boolean = false,
    enabled: Boolean = true,
) {
    val textColor = when {
        !enabled -> Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.38f)
        isDestructive -> Color(QingyuTheme.error(dark))
        else -> Color(QingyuTheme.primaryText(dark))
    }
    val iconColor = when {
        !enabled -> Color(QingyuTheme.actionIcon(dark)).copy(alpha = 0.38f)
        isDestructive -> Color(QingyuTheme.error(dark))
        else -> Color(QingyuTheme.actionIcon(dark))
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            // 横向留白由 QingyuSheet 给（单边 16dp）；这里再加会叠成 36dp。
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = textColor,
            modifier = Modifier.weight(1f),
        )
    }
}

/**
 * 钉住最后一份非空入参（弹层常驻组合：关闭时宿主置空，退场动画期间仍要原对象渲染）。
 */
@Composable
private fun <T : Any> rememberLastNonNull(current: T?): T? {
    var shown by remember { mutableStateOf(current) }
    if (current != null) shown = current
    return shown
}
