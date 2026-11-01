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
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Clear
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课表管理模块文案常量（逐字对齐 `lib/l10n/app_zh.arb` 与 Flutter 界面）。
 */
object TimetableProfilesStrings {
    const val TITLE_PROFILES = "课表管理"
    const val CREATE_TIMETABLE_TOOLTIP = "新建课表"
    const val CREATE_TIMETABLE_TITLE = "新建课表"
    const val TIMETABLE_NAME_HINT = "例如：大二下"
    const val CREATE_ACTION = "创建"
    const val CANCEL_ACTION = "取消"
    const val RENAME_TIMETABLE_TITLE = "重命名课表"
    const val RENAME_ACTION = "重命名"
    const val DUPLICATE_ACTION = "复制"
    const val CLEAR_COURSES_ACTION = "清空课程"
    const val CLEAR_CURRENT_TIMETABLE_TITLE = "清空当前课表"
    const val CLEAR_ACTION = "清空"
    const val DELETE_TIMETABLE_TITLE = "删除课表"
    const val DELETE_ACTION = "删除"
    const val SWITCH_TO_THIS_TIMETABLE = "切换到此课表"
    const val MORE_ACTIONS_TOOLTIP = "更多操作"
    const val PARTNER_READ_ONLY_BADGE = "对方课表 只读"
    const val PARTNER_BADGE = "情侣课表"
    const val KEEP_AT_LEAST_ONE_PROFILE = "至少保留一个课表"
    const val COPIED_CURRENT_TIMETABLE = "已复制当前课表"
    const val NO_COURSES_IN_CURRENT_PROFILE = "当前课表已经没有课程"
    const val SAVE_FAILED = "保存失败"
    const val CLEAR_FAILED = "清空失败，课表内容没有变化"
    const val DELETE_FAILED = "删除失败"

    fun switchedToProfile(name: String): String = "已切换到 $name"
    fun createdProfile(name: String): String = "已创建课表：$name"
    fun renamedProfile(name: String): String = "已重命名为 $name"
    fun clearedProfile(name: String): String = "已清空课表：$name"
    fun deletedProfile(name: String): String = "已删除课表：$name"
    fun clearCurrentTimetableMessage(name: String): String = "确定清空 $name 的全部课程？课表设置将保留"
    fun deleteTimetableMessage(name: String): String = "确定删除课表 $name？"
    fun coursesAndWeekSummary(count: Int, week: Long): String = "$count 门课程 · 第 $week 周"
}

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
    LaunchedEffect(localToast) {
        if (localToast != null) {
            delay(2200)
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
                title = TimetableProfilesStrings.TITLE_PROFILES,
                largeTitle = TimetableProfilesStrings.TITLE_PROFILES,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = TimetableProfilesStrings.CANCEL_ACTION,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showCreateDialog = true }) {
                        Icon(
                            imageVector = MiuixIcons.Add,
                            contentDescription = TimetableProfilesStrings.CREATE_TIMETABLE_TOOLTIP,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
                // 默认含 systemBars 顶部，TopAppBar 自己也会加 systemBars.only(Top)，
                // 再写一次是第三次叠加，标题会下移一个多状态栏高（2026-10-27）。
                .padding(innerPadding),
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // ── 2. 课表列表 ──
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .scrollEndHaptic()
                        .overScrollVertical()
                        .nestedScroll(scrollBehavior.nestedScrollConnection),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
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
                                    if (index > 0) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(horizontal = 16.dp),
                                            color = Color(QingyuTheme.dividerLine(dark)),
                                        )
                                    }
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
            }

            // ── 3. 底部 Toast 提示浮层 ──
            AnimatedVisibility(
                visible = currentToast != null,
                enter = fadeIn() + slideInVertically { it / 2 },
                exit = fadeOut() + slideOutVertically { it / 2 },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 32.dp, start = 24.dp, end = 24.dp),
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

    // 4.1 新建课表弹窗
    if (showCreateDialog) {
        CreateProfileDialog(
            dark = dark,
            onDismiss = { showCreateDialog = false },
            onConfirm = { name ->
                showCreateDialog = false
                onCreateProfile(name)
            },
        )
    }

    // 4.2 更多操作弹层
    activeMenuProfile?.let { profile ->
        val canDelete = profiles.size > 1 && !profile.isPartnerImported
        ProfileMoreActionsDialog(
            profile = profile,
            canDelete = canDelete,
            dark = dark,
            onDismiss = { activeMenuProfile = null },
            onSwitch = {
                activeMenuProfile = null
                onSwitchProfile(profile.id)
            },
            onRename = {
                activeMenuProfile = null
                renamingProfile = profile
            },
            onDuplicate = {
                activeMenuProfile = null
                onDuplicateProfile(profile.id)
            },
            onClear = {
                activeMenuProfile = null
                clearingProfile = profile
            },
            onDelete = {
                activeMenuProfile = null
                deletingProfile = profile
            },
            onCannotDeleteWarning = {
                activeMenuProfile = null
                localToast = TimetableProfilesStrings.KEEP_AT_LEAST_ONE_PROFILE
            },
        )
    }

    // 4.3 重命名弹窗
    renamingProfile?.let { profile ->
        RenameProfileDialog(
            profile = profile,
            dark = dark,
            onDismiss = { renamingProfile = null },
            onConfirm = { newName ->
                renamingProfile = null
                onRenameProfile(profile.id, newName)
            },
        )
    }

    // 4.4 清空课程确认弹窗
    clearingProfile?.let { profile ->
        ClearCoursesConfirmDialog(
            profile = profile,
            dark = dark,
            onDismiss = { clearingProfile = null },
            onConfirm = {
                clearingProfile = null
                onClearCourses(profile.id)
            },
        )
    }

    // 4.5 删除课表确认弹窗
    deletingProfile?.let { profile ->
        DeleteProfileConfirmDialog(
            profile = profile,
            dark = dark,
            onDismiss = { deletingProfile = null },
            onConfirm = {
                deletingProfile = null
                onDeleteProfile(profile.id)
            },
        )
    }
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
                TimetableProfilesStrings.PARTNER_READ_ONLY_BADGE
            } else {
                TimetableProfilesStrings.coursesAndWeekSummary(profile.courseCount, profile.currentWeek)
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
                    contentDescription = TimetableProfilesStrings.MORE_ACTIONS_TOOLTIP,
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
                        contentDescription = "已激活",
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
            text = TimetableProfilesStrings.PARTNER_BADGE,
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
    dark: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var nameInput by remember { mutableStateOf("") }

    Dialog(onDismissRequest = onDismiss) {
        QingyuCard(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            insideMargin = PaddingValues(20.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = TimetableProfilesStrings.CREATE_TIMETABLE_TITLE,
                    style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                )

                TextField(
                    value = nameInput,
                    onValueChange = { nameInput = it },
                    label = TimetableProfilesStrings.TIMETABLE_NAME_HINT,
                    modifier = Modifier.fillMaxWidth(),
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onDismiss,
                    ) {
                        Text(text = TimetableProfilesStrings.CANCEL_ACTION)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        enabled = nameInput.isNotBlank(),
                        onClick = {
                            val trimmed = nameInput.trim()
                            if (trimmed.isNotEmpty()) {
                                onConfirm(trimmed)
                            }
                        },
                    ) {
                        Text(text = TimetableProfilesStrings.CREATE_ACTION)
                    }
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
    profile: TimetableProfileItem,
    dark: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var nameInput by remember(profile) { mutableStateOf(profile.name) }

    Dialog(onDismissRequest = onDismiss) {
        QingyuCard(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            insideMargin = PaddingValues(20.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = TimetableProfilesStrings.RENAME_TIMETABLE_TITLE,
                    style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                )

                TextField(
                    value = nameInput,
                    onValueChange = { nameInput = it },
                    label = TimetableProfilesStrings.TIMETABLE_NAME_HINT,
                    modifier = Modifier.fillMaxWidth(),
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onDismiss,
                    ) {
                        Text(text = TimetableProfilesStrings.CANCEL_ACTION)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        enabled = nameInput.isNotBlank() && nameInput.trim() != profile.name,
                        onClick = {
                            val trimmed = nameInput.trim()
                            if (trimmed.isNotEmpty() && trimmed != profile.name) {
                                onConfirm(trimmed)
                            }
                        },
                    ) {
                        Text(text = TimetableProfilesStrings.RENAME_ACTION)
                    }
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
    profile: TimetableProfileItem,
    dark: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        QingyuCard(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            insideMargin = PaddingValues(20.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = TimetableProfilesStrings.CLEAR_CURRENT_TIMETABLE_TITLE,
                    style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                )

                Text(
                    text = TimetableProfilesStrings.clearCurrentTimetableMessage(profile.name),
                    style = MiuixTheme.textStyles.body2,
                    lineHeight = 20.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onDismiss,
                    ) {
                        Text(text = TimetableProfilesStrings.CANCEL_ACTION)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = onConfirm,
                    ) {
                        Text(
                            text = TimetableProfilesStrings.CLEAR_ACTION,
                            color = Color(QingyuTheme.error(dark)),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 删除课表二次确认对话框。
 */
@Composable
private fun DeleteProfileConfirmDialog(
    profile: TimetableProfileItem,
    dark: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        QingyuCard(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            insideMargin = PaddingValues(20.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = TimetableProfilesStrings.DELETE_TIMETABLE_TITLE,
                    style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                )

                Text(
                    text = TimetableProfilesStrings.deleteTimetableMessage(profile.name),
                    style = MiuixTheme.textStyles.body2,
                    lineHeight = 20.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onDismiss,
                    ) {
                        Text(text = TimetableProfilesStrings.CANCEL_ACTION)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = onConfirm,
                    ) {
                        Text(
                            text = TimetableProfilesStrings.DELETE_ACTION,
                            color = Color(QingyuTheme.error(dark)),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 更多操作弹层菜单。
 */
@Composable
private fun ProfileMoreActionsDialog(
    profile: TimetableProfileItem,
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
    Dialog(onDismissRequest = onDismiss) {
        QingyuCard(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            insideMargin = PaddingValues(vertical = 12.dp),
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = profile.name,
                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                )

                HorizontalDivider(
                    color = Color(QingyuTheme.dividerLine(dark)),
                )

                // 1. 切换到此课表（非激活状态展示）
                if (!profile.isActive) {
                    ActionMenuItem(
                        title = TimetableProfilesStrings.SWITCH_TO_THIS_TIMETABLE,
                        icon = MiuixIcons.Ok,
                        onClick = onSwitch,
                        dark = dark,
                    )
                }

                // 2. 重命名
                ActionMenuItem(
                    title = TimetableProfilesStrings.RENAME_ACTION,
                    icon = MiuixIcons.Edit,
                    onClick = onRename,
                    dark = dark,
                )

                // 3. 复制
                ActionMenuItem(
                    title = TimetableProfilesStrings.DUPLICATE_ACTION,
                    icon = MiuixIcons.Copy,
                    onClick = onDuplicate,
                    dark = dark,
                )

                // 4. 清空课程（仅当前激活课表展示）
                if (profile.isActive) {
                    val canClear = profile.courseCount > 0
                    ActionMenuItem(
                        title = TimetableProfilesStrings.CLEAR_COURSES_ACTION,
                        icon = MiuixIcons.Clear,
                        isDestructive = true,
                        enabled = canClear,
                        onClick = onClear,
                        dark = dark,
                    )
                }

                // 5. 删除课表
                ActionMenuItem(
                    title = TimetableProfilesStrings.DELETE_ACTION,
                    icon = MiuixIcons.Delete,
                    isDestructive = true,
                    enabled = canDelete,
                    onClick = {
                        if (canDelete) {
                            onDelete()
                        } else {
                            onCannotDeleteWarning()
                        }
                    },
                    dark = dark,
                )

                HorizontalDivider(
                    color = Color(QingyuTheme.dividerLine(dark)),
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
                        text = TimetableProfilesStrings.CANCEL_ACTION,
                        style = MiuixTheme.textStyles.body1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
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
            .padding(horizontal = 20.dp, vertical = 14.dp),
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
