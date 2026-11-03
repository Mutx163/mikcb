package com.mutx163.qingyu.pages.course

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.theme.QingyuTheme
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
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.WindowDropdownPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/** 颜色选择盘（与 AddScheduleItemPage 同一套十色盘；Dart 侧走共享的 course_palette_sheet）。 */
private val kCourseColorPalette = listOf(
    "#6366F1", "#0EA5E9", "#2196F3", "#8B5CF6", "#D946EF",
    "#F97316", "#22C55E", "#14B8A6", "#EF4444", "#F59E0B",
)

/**
 * 添加 / 编辑课程页 · Compose 渲染层（Phase 3 · P3-D1）。
 *
 * 对应 Flutter `lib/screens/add_course_screen.dart`（2239 行）：
 * - 顶栏：返回（改过内容先问「放弃修改？」）+「添加课程 / 编辑课程」+（编辑时）删除 + 保存
 * - 共享信息卡：名称（必填）/ 简称（取前两字）/ 教师 / 教室 / 简介 / 性质 / 颜色
 * - 排课记录卡：星期 / 起止节次 / 哪些周上（弹层）/ 条目教师教室 / 删除 / 添加排课时间
 * - 周选择弹层：连续周（起止周 + 单双周）/ 自定义周（网格 + 全选/单周/双周）
 *
 * **构造参数镜像 Dart `AddCourseScreen` 的两参语义，互不顶替**
 * （`TimetableFormPagesCatalog.courseForm` 按这组名字接线）：
 * - [initialCourse] + [courseGroup] 都为空 → 新建；
 * - 只给 [initialCourse] → 编辑那门课（Dart `widget.course` 的单课编辑入口）；
 * - 给 [courseGroup]（可再带 [initialCourse] 指定被点的课排第一）→ 组编辑
 *   （Dart `widget.courseGroup` + `widget.initialCourse`）。
 *
 * **不做业务计算**：周次集合运算、校验、默认值、保存载荷全部来自
 * [AddCourseFormLogic] / [AddCourseWeekDraftLogic]，本文件只把状态摊到屏上。
 *
 * 与 Dart 的已知差异（真机对照前先读）：
 * - 教师/教室/周次/节次/星期在 Dart 走共享选择弹层（`course_field_picker_sheet`、
 *   `miuix_number_picker_sheet` 等，台账 §6 共享件未迁）；这里用 Miuix 官方
 *   `WindowDropdownPreference` 行内下拉与周网格弹层，选择结果同源同判据。
 * - 「沿用已有课程」与时间模板行需要 provider 数据与共享弹层，暂未搬（条目上的
 *   `timeSchemeIdOverride` 由模型层原样穿透，见穿透测试）；壳层补齐共享件后接线。
 * - 校验失败在 Dart 是 toast；这里用页内错误条（同一份文案键）。
 * - 钟点解析必须由壳层经 [clockResolver] 注入（Dart `_resolveEntryTimeScheme` →
 *   `CourseDomain.editCourseClock`），页面不猜时间。
 */
@Composable
fun AddCoursePage(
    initialCourse: Course? = null,
    courseGroup: CourseGroup? = null,
    initialWeek: Int? = null,
    initialDayOfWeek: Int? = null,
    initialStartSection: Int? = null,
    initialEndSection: Int? = null,
    /** 可选周次表（Dart `settings.availableWeeks`，1..学期周数）。 */
    availableWeeks: List<Int> = (1..20).toList(),
    /** 全局作息节数（Dart `settings.sectionCount`）。 */
    globalSectionCount: Int = 12,
    /** 条目自身解析出的作息模板节数（Dart `_resolveEntryTimeScheme(...)?.sections.length`）。 */
    entrySchemeSectionCount: (entry: AddCourseScheduleEntryData, location: String) -> Int? = { _, _ -> null },
    /** 条目钟点解析（含 `hasCustomTime` 权威钟点回传），保存时逐条调用。 */
    clockResolver: (AddCourseScheduleEntryData) -> AddCourseEntryClock,
    onBack: () -> Unit = {},
    /** 保存载荷交给壳层落盘（provider.addCourse / updateCourseGroup 由壳层按 mode 分派）。 */
    onSave: (AddCourseSavePayload) -> Unit = {},
    /** 编辑态删除（组名/单课名由壳层按入口上下文决定）。 */
    onDelete: () -> Unit = {},
) {
    val dark = isSystemInDarkTheme()
    val groupData = courseGroup?.let { AddCourseGroupData(name = it.name, courses = it.courses) }
    val isEditing = !AddCourseFormLogic.isCreatingNewCourse(initialCourse, groupData)
    val initialState = remember(initialCourse, courseGroup, initialWeek, initialDayOfWeek, initialStartSection, initialEndSection) {
        AddCourseFormLogic.buildInitialState(
            initialWeek = initialWeek ?: 1,
            initialDayOfWeek = initialDayOfWeek ?: 1,
            initialStartSection = initialStartSection ?: 1,
            initialEndSection = initialEndSection,
            initialCourse = initialCourse,
            courseGroup = groupData,
        )
    }

    // ── 表单草稿态（UI 态；业务计算全部在模型层）──
    var sharedName by remember(initialState) { mutableStateOf(initialState.sharedName) }
    var sharedShortName by remember(initialState) { mutableStateOf(initialState.sharedShortName) }
    var sharedTeacher by remember(initialState) { mutableStateOf(initialState.sharedTeacher) }
    var sharedLocation by remember(initialState) { mutableStateOf(initialState.sharedLocation) }
    var sharedDescription by remember(initialState) { mutableStateOf(initialState.sharedDescription) }
    var courseNature by remember(initialState) { mutableStateOf(initialState.courseNature) }
    var selectedColor by remember(initialState) { mutableStateOf(initialState.color) }
    var entries by remember(initialState) { mutableStateOf(initialState.entries) }
    var dirty by remember(initialState) { mutableStateOf(false) }
    var nameError by remember(initialState) { mutableStateOf<String?>(null) }
    var entryError by remember(initialState) { mutableStateOf<String?>(null) }
    var weekDraftEntryId by remember(initialState) { mutableStateOf<String?>(null) }
    var weekDraft by remember(initialState) { mutableStateOf<AddCourseWeekDraft?>(null) }
    var confirmDiscard by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    fun markDirty() {
        dirty = true
    }

    fun updateEntry(index: Int, update: (AddCourseScheduleEntryData) -> AddCourseScheduleEntryData) {
        entries = entries.mapIndexed { i, entry -> if (i == index) update(entry) else entry }
        markDirty()
    }

    fun save() {
        val nameIssue = AddCourseFormLogic.validateCourseName(sharedName)
        if (nameIssue != null) {
            nameError = nameIssue
            entryError = null
            return
        }
        nameError = null
        entries.forEachIndexed { index, entry ->
            if (AddCourseFormLogic.validateEntry(entry) != null) {
                entryError = AddCourseFormLogic.entryWeeksErrorMessage(index)
                return
            }
        }
        entryError = null
        val payload = AddCourseFormLogic.buildSavePayload(
            initialCourse = initialCourse,
            courseGroup = courseGroup?.let { AddCourseGroupData(name = it.name, courses = it.courses) },
            name = sharedName,
            shortName = sharedShortName,
            description = sharedDescription,
            color = selectedColor,
            courseNature = courseNature,
            entries = entries,
            clockResolver = clockResolver,
        )
        dirty = false
        onSave(payload)
    }

    fun requestBack() {
        if (dirty) {
            confirmDiscard = true
        } else {
            onBack()
        }
    }

    // 系统返回手势与顶栏返回键同一判据：改过内容先问一句（Dart PopScope）。
    BackHandler(enabled = dirty && weekDraft == null) {
        confirmDiscard = true
    }

    val pageTitle = if (isEditing) AddCourseStrings.editCourseTitle.zh else AddCourseStrings.addCourseTitle.zh
    // 顶栏折叠行为：Dart 侧同一页面走 HyperosSubpage 默认参数
    // （`collapsibleLargeTitle` 默认 true，见 `hyperos_page.dart:170`），标题是纯 Text ⇒ 有大标题。
    // 一个页面实例一个：返回重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = pageTitle,
                    largeTitle = pageTitle,
                    scrollBehavior = scrollBehavior,
                    color = Color(QingyuTheme.scaffoldBackground(dark)),
                    navigationIcon = {
                        IconButton(onClick = ::requestBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = AddCourseStrings.cancelAction.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    actions = {
                        if (isEditing) {
                            IconButton(onClick = { confirmDelete = true }) {
                                Icon(
                                    imageVector = MiuixIcons.Delete,
                                    contentDescription = AddCourseStrings.deleteAction.zh,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                        }
                        IconButton(onClick = ::save) {
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = AddCourseStrings.saveAction.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            // 主滚动统一走共享套件（R2）：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
            // 与右侧滚动条；`innerPadding` 由套件自己吃掉，不再手写 Column + padding。
            // 横向留白按配方由每个块自己带 12dp，**不**放进 contentPadding
            //（放进去滚动条会跟着内缩、也偏离 28dp 轴线）。
            QingyuPageList(
                innerPadding = innerPadding,
                modifier = Modifier.imePadding(),
                scrollBehavior = scrollBehavior,
                contentPadding = PaddingValues(top = 8.dp, bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // ── 校验错误横幅（Dart 为 toast；同一份文案键）──
                val pageError = nameError ?: entryError
                if (!pageError.isNullOrEmpty()) {
                    item(key = "error") {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                        ) {
                            Text(
                                text = pageError,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.error(dark)),
                            )
                        }
                    }
                }

                item(key = "shared_info") {
                    // ── 共享信息卡 ──
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = AddCourseStrings.sharedInfoTitle.zh,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            TextField(
                                value = sharedName,
                                onValueChange = {
                                    sharedName = it
                                    nameError = null
                                    markDirty()
                                },
                                label = AddCourseStrings.courseNameLabel.zh,
                                useLabelAsPlaceholder = true,
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Text(
                                text = nameError ?: AddCourseStrings.courseNameHelper.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(
                                    if (nameError != null) QingyuTheme.error(dark) else QingyuTheme.secondaryText(dark),
                                ),
                            )
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                TextField(
                                    value = sharedShortName,
                                    onValueChange = {
                                        sharedShortName = it
                                        markDirty()
                                    },
                                    label = AddCourseStrings.courseShortNameOptional.zh,
                                    useLabelAsPlaceholder = true,
                                    singleLine = true,
                                    modifier = Modifier.weight(1f),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = AddCourseStrings.courseShortNameAutoFillAction.zh,
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primary(dark = dark)),
                                    modifier = Modifier
                                        .clickable {
                                            val auto = AddCourseFormLogic.autofillShortName(sharedName)
                                            if (auto.isNotEmpty()) {
                                                sharedShortName = auto
                                                markDirty()
                                            }
                                        }
                                        .padding(horizontal = 6.dp, vertical = 8.dp),
                                )
                            }
                            Text(
                                text = AddCourseStrings.courseShortNameHelper.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                            TextField(
                                value = sharedTeacher,
                                onValueChange = {
                                    sharedTeacher = it
                                    markDirty()
                                },
                                label = AddCourseStrings.teacherLabel.zh,
                                useLabelAsPlaceholder = true,
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            TextField(
                                value = sharedLocation,
                                onValueChange = {
                                    sharedLocation = it
                                    markDirty()
                                },
                                label = AddCourseStrings.locationLabel.zh,
                                useLabelAsPlaceholder = true,
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            TextField(
                                value = sharedDescription,
                                onValueChange = {
                                    sharedDescription = it
                                    markDirty()
                                },
                                label = AddCourseStrings.courseDescriptionOptional.zh,
                                useLabelAsPlaceholder = true,
                                minLines = 2,
                                maxLines = 4,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            val natureOptions = listOf(
                                CourseNature.REQUIRED to AddCourseStrings.courseNatureRequired.zh,
                                CourseNature.ELECTIVE to AddCourseStrings.courseNatureElective.zh,
                            )
                            WindowDropdownPreference(
                                items = natureOptions.map { it.second },
                                selectedIndex = natureOptions.indexOfFirst { it.first == courseNature },
                                title = AddCourseStrings.courseNatureLabel.zh,
                                onSelectedIndexChange = { index ->
                                    natureOptions.getOrNull(index)?.let { (nature, _) ->
                                        courseNature = nature
                                        markDirty()
                                    }
                                },
                            )
                            Text(
                                text = AddCourseStrings.courseColorTitle.zh,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                for (hex in kCourseColorPalette) {
                                    val isChosen = selectedColor.equals(hex, ignoreCase = true)
                                    Box(
                                        modifier = Modifier
                                            .size(28.dp)
                                            .background(
                                                color = Color(android.graphics.Color.parseColor(hex)),
                                                shape = CircleShape,
                                            )
                                            .border(
                                                width = if (isChosen) 2.dp else 1.dp,
                                                color = if (isChosen) {
                                                    Color(QingyuTheme.primaryText(dark))
                                                } else {
                                                    Color(QingyuTheme.dividerLine(dark))
                                                },
                                                shape = CircleShape,
                                            )
                                            .clickable {
                                                selectedColor = hex
                                                markDirty()
                                            },
                                    )
                                }
                            }
                            Text(
                                text = AddCourseStrings.sharedInfoInlineHint.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                    }
                }

                item(key = "schedule_entries") {
                    // ── 排课记录卡 ──
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Column {
                                Text(
                                    text = AddCourseFormLogic.scheduleEntryCardTitle(entries.size),
                                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                    color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                )
                                Text(
                                    text = AddCourseStrings.scheduleEntryCardSubtitle.zh,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                            entries.forEachIndexed { index, entry ->
                                AddCourseEntryFields(
                                    index = index,
                                    entry = entry,
                                    entryCount = entries.size,
                                    dark = dark,
                                    availableWeeks = availableWeeks,
                                    globalSectionCount = globalSectionCount,
                                    entrySchemeSectionCount = entrySchemeSectionCount,
                                    onDayOfWeekChange = { day -> updateEntry(index) { it.copy(dayOfWeek = day) } },
                                    onStartSectionChange = { section -> updateEntry(index) { it.copy(startSection = section) } },
                                    onEndSectionChange = { section -> updateEntry(index) { it.copy(endSection = section) } },
                                    onTeacherChange = { teacher -> updateEntry(index) { it.copy(teacher = teacher) } },
                                    onLocationChange = { location -> updateEntry(index) { it.copy(location = location) } },
                                    onOpenWeekPicker = {
                                        weekDraftEntryId = entry.id
                                        weekDraft = AddCourseWeekDraftLogic.fromEntry(entry)
                                    },
                                    onRemoveEntry = {
                                        entries = entries.filterIndexed { i, _ -> i != index }
                                        markDirty()
                                    },
                                )
                            }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        val last = entries.lastOrNull()
                                        entries = entries + AddCourseFormLogic.nextEntryAfter(
                                            last = last,
                                            sharedTeacher = sharedTeacher,
                                            sharedLocation = sharedLocation,
                                        )
                                        markDirty()
                                    }
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.Add,
                                    contentDescription = null,
                                    tint = Color(QingyuTheme.primary(dark = dark)),
                                    modifier = Modifier.size(17.dp),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = AddCourseStrings.addScheduleEntryAction.zh,
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primary(dark = dark)),
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 周选择弹层（草稿状态机在 AddCourseWeekDraftLogic）──
    // 常驻组合：显隐只由 `show` 驱动，不靠 `weekDraft` 是否为空来挂载；
    // 退场动画期间的草稿内容由弹层内部的 `rememberLastNonNull` 钉住。
    AddCourseWeekPickerDialog(
        draftOrNull = weekDraft,
        show = weekDraft != null && weekDraftEntryId != null,
        availableWeeks = availableWeeks,
        dark = dark,
        onDraftChange = { weekDraft = it },
        onDismiss = {
            weekDraft = null
            weekDraftEntryId = null
        },
        onConfirm = { confirmed ->
            val entryIndex = weekDraftEntryId?.let { id -> entries.indexOfFirst { it.id == id } } ?: -1
            if (entryIndex >= 0) {
                updateEntry(entryIndex) { AddCourseWeekDraftLogic.applyToEntry(it, confirmed) }
            }
            weekDraft = null
            weekDraftEntryId = null
        },
    )

    if (confirmDiscard) {
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = true,
            title = AddCourseStrings.courseFormDiscardTitle.zh,
            summary = AddCourseStrings.courseFormDiscardMessage.zh,
            onDismissRequest = { confirmDiscard = false },
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = { confirmDiscard = false },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = AddCourseStrings.cancelAction.zh)
                }
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = {
                        confirmDiscard = false
                        dirty = false
                        onBack()
                    },
                    modifier = Modifier.weight(1f),
                    colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                ) {
                    Text(text = AddCourseStrings.courseFormDiscardAction.zh)
                }
            }
        }
    }

    if (confirmDelete && isEditing) {
        val deleteTargetName = courseGroup?.name ?: initialCourse?.name.orEmpty()
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = true,
            title = AddCourseStrings.deleteCourseTitle.zh,
            summary = AddCourseStrings.confirmDeleteCourseMessage.filled("name", deleteTargetName),
            onDismissRequest = { confirmDelete = false },
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = { confirmDelete = false },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = AddCourseStrings.cancelAction.zh)
                }
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = {
                        confirmDelete = false
                        onDelete()
                    },
                    modifier = Modifier.weight(1f),
                    colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                ) {
                    Text(text = AddCourseStrings.deleteAction.zh)
                }
            }
        }
    }
}

/** 单条排课记录的输入区（星期 / 起止节次 / 哪些周上 / 条目教师教室 / 删除）。 */
@Composable
private fun AddCourseEntryFields(
    index: Int,
    entry: AddCourseScheduleEntryData,
    entryCount: Int,
    dark: Boolean,
    availableWeeks: List<Int>,
    globalSectionCount: Int,
    entrySchemeSectionCount: (AddCourseScheduleEntryData, String) -> Int?,
    onDayOfWeekChange: (Int) -> Unit,
    onStartSectionChange: (Int) -> Unit,
    onEndSectionChange: (Int) -> Unit,
    onTeacherChange: (String) -> Unit,
    onLocationChange: (String) -> Unit,
    onOpenWeekPicker: () -> Unit,
    onRemoveEntry: () -> Unit,
) {
    val sectionNumbers = AddCourseFormLogic.editableSectionNumbers(
        globalSectionCount = globalSectionCount,
        courseSchemeSectionCount = entrySchemeSectionCount(entry, entry.location),
        currentStartSection = entry.startSection,
        currentEndSection = entry.endSection,
    )
    val weekSummary = AddCourseFormLogic.selectedWeeksSummaryText(
        selectedWeeks = AddCourseFormLogic.selectedWeeksFor(entry),
        availableWeeks = availableWeeks,
        startWeek = entry.startWeek,
        endWeek = entry.endWeek,
        isOddWeek = entry.isOddWeek,
        isEvenWeek = entry.isEvenWeek,
        mode = entry.weekSelectionMode,
    )
    val weekdayNames = AddCourseStrings.weekdayNames()
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 14.dp, top = 10.dp, end = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = AddCourseStrings.scheduleEntryIndexTitle(index + 1),
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.weight(1f),
                )
                if (entryCount > 1) {
                    IconButton(onClick = onRemoveEntry, modifier = Modifier.size(36.dp)) {
                        Icon(
                            imageVector = MiuixIcons.Remove,
                            contentDescription = AddCourseStrings.deleteAction.zh,
                            tint = Color(QingyuTheme.error(dark)),
                            modifier = Modifier.size(17.dp),
                        )
                    }
                }
            }
            WindowDropdownPreference(
                items = weekdayNames,
                selectedIndex = (entry.dayOfWeek - 1).coerceIn(weekdayNames.indices),
                title = AddCourseStrings.weekdayLabel.zh,
                onSelectedIndexChange = { position ->
                    (position + 1).takeIf { it in 1..7 }?.let(onDayOfWeekChange)
                },
            )
            WindowDropdownPreference(
                items = sectionNumbers.map { AddCourseStrings.sectionLabel.filled("section", it.toString()) },
                selectedIndex = sectionNumbers.indexOf(entry.startSection).coerceAtLeast(0),
                title = AddCourseStrings.startSectionLabel.zh,
                onSelectedIndexChange = { position ->
                    sectionNumbers.getOrNull(position)?.let(onStartSectionChange)
                },
            )
            WindowDropdownPreference(
                items = sectionNumbers.map { AddCourseStrings.sectionLabel.filled("section", it.toString()) },
                selectedIndex = sectionNumbers.indexOf(entry.endSection).coerceAtLeast(0),
                title = AddCourseStrings.endSectionLabel.zh,
                onSelectedIndexChange = { position ->
                    sectionNumbers.getOrNull(position)?.let(onEndSectionChange)
                },
            )
            // 「哪些周上」行：摘要即保存校验同一口径（selectedWeeksSummaryText）。
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onOpenWeekPicker)
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = AddCourseStrings.scheduleEntryWeeksSectionTitle.zh,
                    style = MiuixTheme.textStyles.body1,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = weekSummary,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(2f),
                )
            }
            TextField(
                value = entry.teacher,
                onValueChange = onTeacherChange,
                label = AddCourseStrings.teacherLabel.zh,
                useLabelAsPlaceholder = true,
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp),
            )
            Spacer(modifier = Modifier.height(8.dp))
            TextField(
                value = entry.location,
                onValueChange = onLocationChange,
                label = AddCourseStrings.locationLabel.zh,
                useLabelAsPlaceholder = true,
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp),
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
    }
}

/**
 * 「哪些周上」弹层（Dart `_showEntryWeekPickerDialog` 的 Compose 形态）：
 * 模式组 + （范围：起止周 + 单双周组 | 自定义：周网格 + 全选/单周/双周）+ 摘要 + 确认。
 * 确认键按 [AddCourseWeekDraftLogic.canConfirm] 启用——最终周次为空集不许确认。
 */
@Composable
private fun AddCourseWeekPickerDialog(
    draftOrNull: AddCourseWeekDraft?,
    show: Boolean,
    availableWeeks: List<Int>,
    dark: Boolean,
    onDraftChange: (AddCourseWeekDraft) -> Unit,
    onDismiss: () -> Unit,
    onConfirm: (AddCourseWeekDraft) -> Unit,
) {
    // 退场期快照：`show` 转 false 后宿主把 weekDraft 置空，正文仍要按最后一份草稿渲染。
    val currentDraft = rememberLastNonNull(draftOrNull)
    // Dart 原版是全屏子页 + 可滚 ListView；这里收成对话框，正文限高 + 可滚，
    // 避免自定义周网格（53 周 / 大字号）撑破矮屏。确认/取消跟随正文滚动（与 Dart 底部动作一致）。
    val maxBodyHeight = (LocalConfiguration.current.screenHeightDp * 0.72f).dp
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = AddCourseStrings.weekPickerTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        val draft = currentDraft ?: return@OverlayDialog
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = maxBodyHeight)
                .scrollEndHaptic()
                .overScrollVertical(),
        ) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    AddCourseWeekModeTileGroup(
                        tempMode = draft.mode,
                        dark = dark,
                        onSelect = { nextMode ->
                            onDraftChange(AddCourseWeekDraftLogic.selectMode(draft, nextMode, availableWeeks))
                        },
                    )
                    if (draft.mode == AddCourseWeekSelectionMode.RANGE) {
                        WindowDropdownPreference(
                            items = availableWeeks.map { AddCourseStrings.weekLabel.filled("week", it.toString()) },
                            selectedIndex = availableWeeks.indexOf(draft.startWeek).coerceAtLeast(0),
                            title = AddCourseStrings.startWeekLabel.zh,
                            onSelectedIndexChange = { position ->
                                availableWeeks.getOrNull(position)?.let { week ->
                                    onDraftChange(AddCourseWeekDraftLogic.setStartWeek(draft, week, availableWeeks))
                                }
                            },
                        )
                        WindowDropdownPreference(
                            items = availableWeeks.map { AddCourseStrings.weekLabel.filled("week", it.toString()) },
                            selectedIndex = availableWeeks.indexOf(draft.endWeek).coerceAtLeast(0),
                            title = AddCourseStrings.endWeekLabel.zh,
                            onSelectedIndexChange = { position ->
                                availableWeeks.getOrNull(position)?.let { week ->
                                    onDraftChange(AddCourseWeekDraftLogic.setEndWeek(draft, week, availableWeeks))
                                }
                            },
                        )
                        AddCourseWeekParityTileGroup(
                            isAllWeeks = !draft.isOddWeek && !draft.isEvenWeek,
                            isOddWeek = draft.isOddWeek,
                            isEvenWeek = draft.isEvenWeek,
                            dark = dark,
                            onSelectAll = {
                                onDraftChange(draft.copy(isOddWeek = false, isEvenWeek = false))
                            },
                            onSelectOdd = {
                                onDraftChange(draft.copy(isOddWeek = true, isEvenWeek = false))
                            },
                            onSelectEven = {
                                onDraftChange(draft.copy(isOddWeek = false, isEvenWeek = true))
                            },
                        )
                    } else {
                        // 周网格：每行 5 个（Dart 按宽度 4/5/6 列自适应，先取中档）。
                        availableWeeks.chunked(5).forEach { rowWeeks ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                rowWeeks.forEach { week ->
                                    AddCourseWeekGridTile(
                                        week = week,
                                        isSelected = week in draft.customWeeks,
                                        dark = dark,
                                        modifier = Modifier.weight(1f),
                                        onPress = {
                                            onDraftChange(AddCourseWeekDraftLogic.toggleCustomWeek(draft, week))
                                        },
                                    )
                                }
                                // 末排不足 5 格时补等宽空位，保持格宽与上面各行一致（Dart GridView 原版行为）。
                                repeat(5 - rowWeeks.size) {
                                    Spacer(modifier = Modifier.weight(1f))
                                }
                            }
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            AddCourseChoiceChip(
                                label = AddCourseStrings.selectAllAction.zh,
                                isSelected = false,
                                dark = dark,
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    onDraftChange(AddCourseWeekDraftLogic.selectAllCustom(draft, availableWeeks))
                                },
                            )
                            AddCourseChoiceChip(
                                label = AddCourseStrings.selectOddWeeksAction.zh,
                                isSelected = false,
                                dark = dark,
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    onDraftChange(AddCourseWeekDraftLogic.selectOddCustom(draft, availableWeeks))
                                },
                            )
                            AddCourseChoiceChip(
                                label = AddCourseStrings.selectEvenWeeksAction.zh,
                                isSelected = false,
                                dark = dark,
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    onDraftChange(AddCourseWeekDraftLogic.selectEvenCustom(draft, availableWeeks))
                                },
                            )
                        }
                    }
                    val selectedWeeks = AddCourseWeekDraftLogic.selectedWeeks(draft)
                    Text(
                        text = AddCourseStrings.selectedWeeksSummary
                            .filled("count", selectedWeeks.size.toString())
                            .filled("weeks", AddCourseFormLogic.formatWeekList(selectedWeeks)),
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        top.yukonga.miuix.kmp.basic.Button(
                            onClick = onDismiss,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text(text = AddCourseStrings.cancelAction.zh)
                        }
                        top.yukonga.miuix.kmp.basic.Button(
                            onClick = { onConfirm(draft) },
                            enabled = AddCourseWeekDraftLogic.canConfirm(draft),
                            modifier = Modifier.weight(1f),
                            colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColorsPrimary(),
                        ) {
                            Text(text = AddCourseStrings.confirmAction.zh)
                        }
                    }
                }
            }
        }
    }
}

/**
 * 退场期保留最后一份非空状态（常驻组合配方的一半，与 `TimeSchemeManagementDialogs.kt` 同口径）。
 *
 * 弹层 `show` 转 false 后宿主通常立刻把数据置空；退场动画期间内容 lambda 仍会被组合，
 * 直接读可空入参会闪成空板，所以用 remember 钉住最后一份非空值。
 */
@Composable
private fun <T : Any> rememberLastNonNull(current: T?): T? {
    var shown by remember { mutableStateOf(current) }
    if (current != null) {
        shown = current
    }
    return shown
}
