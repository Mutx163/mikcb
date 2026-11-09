package com.mutx163.qingyu.pages.course

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.selection.selectable
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
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.glass.LocalQingyuPageBackdrop
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.DialogGlassSpec
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.layout.DialogGlass
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
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

    val pageTitle = if (isEditing) AddCourseStrings.editCourseTitle.text else AddCourseStrings.addCourseTitle.text

    // 页面骨架走共享件（R1）：折叠大标题、顶栏玻璃、返回键与动作键的玻璃圆底、
    // 动作键间距全由骨架统一注入；本页只保留业务动作，不再手拼 Scaffold + TopAppBar。
    QingyuPageScaffold(
        title = pageTitle,
        onBack = ::requestBack,
        actions = {
            if (isEditing) {
                QingyuGlassIconButton(
                    onClick = { confirmDelete = true },
                    contentDescription = AddCourseStrings.deleteAction.text,
                    icon = MiuixIcons.Delete,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
            QingyuGlassIconButton(
                onClick = ::save,
                contentDescription = AddCourseStrings.saveAction.text,
                icon = MiuixIcons.Ok,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        },
    ) {
        // 主滚动统一走共享套件（R2）；横向留白按配方由每个块自己带 12dp，
        // 不放进 contentPadding（否则滚动条内缩、也偏离 28dp 文字轴线）。
        QingyuPageList(
            innerPadding = innerPadding,
            modifier = Modifier.imePadding(),
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(top = 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // ── 校验错误横幅：名称错误已经在字段下方就地提示，顶部只承接
            // 可能滚出屏幕的「排课条目」错误（两条都挂会让同一句话出现两遍）──
            val pageError = entryError
            if (!pageError.isNullOrEmpty()) {
                item(key = "error") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = MiuixIcons.Info,
                                contentDescription = null,
                                tint = Color(QingyuTheme.error(dark)),
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = pageError,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.error(dark)),
                            )
                        }
                    }
                }
            }

            // ── 实时课程名片：名称 / 简称 / 教师 / 教室 / 性质 / 颜色 / 首条排课一变就跟着变 ──
            item(key = "identity") {
                AddCourseIdentityCard(
                    name = sharedName,
                    shortName = sharedShortName,
                    teacher = sharedTeacher,
                    location = sharedLocation,
                    nature = courseNature,
                    colorHex = selectedColor,
                    firstEntry = entries.firstOrNull(),
                    dark = dark,
                )
            }

            // ── 共享信息：分组标题在卡外（官方 SmallTitle），卡内普通内容统一 16dp；
            // 性质是官方 Preference 行（自带 16dp），所以卡片本身不再给 insideMargin。
            item(key = "shared_info") {
                QingyuSectionTitle(AddCourseStrings.sharedInfoTitle.text)
                Text(
                    text = AddCourseStrings.sharedInfoInlineHint.text,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(start = 28.dp, end = 28.dp, bottom = 8.dp),
                )
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = PaddingValues(0.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                TextField(
                                    value = sharedName,
                                    onValueChange = {
                                        sharedName = it
                                        nameError = null
                                        markDirty()
                                    },
                                    label = AddCourseStrings.courseNameLabel.text,
                                    useLabelAsPlaceholder = true,
                                    singleLine = true,
                                    modifier = Modifier.fillMaxWidth(),
                                )
                                Text(
                                    text = nameError ?: AddCourseStrings.courseNameHelper.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(
                                        if (nameError != null) {
                                            QingyuTheme.error(dark)
                                        } else {
                                            QingyuTheme.secondaryText(dark)
                                        },
                                    ),
                                )
                            }
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    TextField(
                                        value = sharedShortName,
                                        onValueChange = {
                                            sharedShortName = it
                                            markDirty()
                                        },
                                        label = AddCourseStrings.courseShortNameOptional.text,
                                        useLabelAsPlaceholder = true,
                                        singleLine = true,
                                        modifier = Modifier.weight(1f),
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    // 官方 TextButton：自带 squircle 底、按压反馈与 Role.Button。
                                    TextButton(
                                        text = AddCourseStrings.courseShortNameAutoFillAction.text,
                                        onClick = {
                                            val auto = AddCourseFormLogic.autofillShortName(sharedName)
                                            if (auto.isNotEmpty()) {
                                                sharedShortName = auto
                                                markDirty()
                                            }
                                        },
                                        minWidth = 0.dp,
                                        minHeight = 0.dp,
                                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 11.dp),
                                        textStyle = MiuixTheme.textStyles.body2,
                                    )
                                }
                                Text(
                                    text = AddCourseStrings.courseShortNameHelper.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                            TextField(
                                value = sharedTeacher,
                                onValueChange = {
                                    sharedTeacher = it
                                    markDirty()
                                },
                                label = AddCourseStrings.teacherLabel.text,
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
                                label = AddCourseStrings.locationLabel.text,
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
                                label = AddCourseStrings.courseDescriptionOptional.text,
                                useLabelAsPlaceholder = true,
                                minLines = 2,
                                maxLines = 4,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                        // 官方 demo 同卡多行之间不画横线：分隔交给各行的内边距。
                        Spacer(modifier = Modifier.height(4.dp))
                        val natureOptions = listOf(
                            CourseNature.REQUIRED to AddCourseStrings.courseNatureRequired.text,
                            CourseNature.ELECTIVE to AddCourseStrings.courseNatureElective.text,
                        )
                        WindowDropdownPreference(
                            items = natureOptions.map { it.second },
                            selectedIndex = natureOptions.indexOfFirst { it.first == courseNature },
                            title = AddCourseStrings.courseNatureLabel.text,
                            onSelectedIndexChange = { index ->
                                natureOptions.getOrNull(index)?.let { (nature, _) ->
                                    courseNature = nature
                                    markDirty()
                                }
                            },
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Column(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Text(
                                text = AddCourseStrings.courseColorTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            AddCourseColorSwatches(
                                selectedColor = selectedColor,
                                dark = dark,
                                onSelect = { hex ->
                                    selectedColor = hex
                                    markDirty()
                                },
                            )
                        }
                    }
                }
            }

            // ── 排课记录：一条一张独立卡片；序号徽标沿用课程颜色，卡片之间只留 12dp ──
            item(key = "schedule_section_title") {
                QingyuSectionTitle(AddCourseFormLogic.scheduleEntryCardTitle(entries.size))
            }
            entries.forEachIndexed { index, entry ->
                item(key = "schedule_entry_${entry.id}") {
                    AddCourseEntryFields(
                        index = index,
                        entry = entry,
                        entryCount = entries.size,
                        dark = dark,
                        accentColor = selectedColor,
                        modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
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
            }
            item(key = "add_entry") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
                    onClick = {
                        val last = entries.lastOrNull()
                        entries = entries + AddCourseFormLogic.nextEntryAfter(
                            last = last,
                            sharedTeacher = sharedTeacher,
                            sharedLocation = sharedLocation,
                        )
                        markDirty()
                    },
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(30.dp)
                                .background(
                                    Color(QingyuTheme.primary(dark = dark))
                                        .copy(alpha = if (dark) 0.22f else 0.10f),
                                    CircleShape,
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Add,
                                contentDescription = null,
                                tint = Color(QingyuTheme.primary(dark = dark)),
                                modifier = Modifier.size(18.dp),
                            )
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = AddCourseStrings.addScheduleEntryAction.text,
                            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.primary(dark = dark)),
                        )
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

    // 常驻组合（2026-11-04 弹层债收口）：显隐只由 `show` 驱动。原先 `if (confirmDiscard)`
    // 在状态置 false 的同一帧把整棵 OverlayDialog 摘出组合，官方退场动画
    // （miuix 0.9.4 `DialogLayout` 的 fadeOut + scaleOut + slideOut）一次都播不出来。
    // 标题/正文均为常量文案，退场期间没有会被清空的数据，无需 `rememberLastNonNull`。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = confirmDiscard,
        title = AddCourseStrings.courseFormDiscardTitle.text,
        summary = AddCourseStrings.courseFormDiscardMessage.text,
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
                Text(text = AddCourseStrings.cancelAction.text)
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
                Text(text = AddCourseStrings.courseFormDiscardAction.text)
            }
        }
    }

    // 删除确认弹层常驻组合（`show` 由实时状态驱动，关闭不再整棵摘出组合），并保留
    // 本仓玻璃试点（2026-11-03，用户批准「改库」）：玻璃画在官方容器同一节点，取值在
    // core/DialogGlassSpec；DialogGlassSpec.enabled=false 一键回退官方实心板。本试点由
    // QingyuGlassDialogGuardTest 钉住，不许铺开。
    val deleteTargetName = courseGroup?.name ?: initialCourse?.name.orEmpty()
    val schemeBackground = MiuixTheme.colorScheme.background
    val glassDark = DialogGlassSpec.isDarkBackground(schemeBackground.toArgb())
    val glassOn = DialogGlassSpec.enabled
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = confirmDelete && isEditing,
        title = AddCourseStrings.deleteCourseTitle.text,
        summary = AddCourseStrings.confirmDeleteCourseMessage.filled("name", deleteTargetName),
        // 圆角钉 32dp：官方贴底档下限，玻璃面与面板同值（容器内两者共用推导值）。
        cornerRadius = DialogGlassSpec.CORNER_RADIUS_DP.dp,
        // 要玻璃时底色必须半透明（压色落在模糊层上）；关玻璃就退回实心，观感与官方一致。
        backgroundColor = if (glassOn) {
            schemeBackground.copy(alpha = DialogGlassSpec.tintAlpha(glassDark))
        } else {
            schemeBackground
        },
        glass = if (glassOn) {
            DialogGlass(
                backdrop = LocalQingyuPageBackdrop.current,
                blurRadius = DialogGlassSpec.BLUR_RADIUS_DP.dp,
                saturation = DialogGlassSpec.SATURATION,
                dark = glassDark,
            )
        } else {
            null
        },
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
                Text(text = AddCourseStrings.cancelAction.text)
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
                Text(text = AddCourseStrings.deleteAction.text)
            }
        }
    }
}

// ── 课程名片 / 十色盘 / 单条排课卡片 ────────────────────────────────────────

/** 把课程色解析成 Compose 颜色；用户数据里的坏值回落主题主色，不让整页崩。 */
private fun parseCourseColor(hex: String, fallback: Color): Color =
    runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(fallback)

/**
 * 实时课程名片：填写过程中就能看到「这门课长什么样」。
 * 纯展示，所有取值都来自当前表单草稿，不参与保存载荷。
 */
@Composable
private fun AddCourseIdentityCard(
    name: String,
    shortName: String,
    teacher: String,
    location: String,
    nature: CourseNature,
    colorHex: String,
    firstEntry: AddCourseScheduleEntryData?,
    dark: Boolean,
) {
    val swatch = parseCourseColor(colorHex, Color(QingyuTheme.primary(dark = dark)))
    // 文字用对比度修正后的同色相取值：浅色（黄 / 青）在亮底上也读得清；
    // 色块本身仍用用户选的原色，所见即所得。
    val accent = Color(QingyuTheme.primary(seedHex = colorHex, dark = dark))
    val badgeText = shortName.trim()
        .ifEmpty { AddCourseFormLogic.autofillShortName(name) }
        .take(2)
    val meta = listOf(teacher.trim(), location.trim())
        .filter { it.isNotEmpty() }
        .joinToString(" · ")

    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin),
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(54.dp)
                    .background(
                        swatch.copy(alpha = if (dark) 0.26f else 0.14f),
                        RoundedCornerShape(18.dp),
                    )
                    .border(
                        width = 1.dp,
                        color = swatch.copy(alpha = 0.32f),
                        shape = RoundedCornerShape(18.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (badgeText.isEmpty()) {
                    // 还没起名时不留空色块：放一张课程纸页图标当占位。
                    Icon(
                        imageVector = MiuixIcons.Notes,
                        contentDescription = null,
                        tint = accent,
                        modifier = Modifier.size(22.dp),
                    )
                } else {
                    Text(
                        text = badgeText,
                        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = accent,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = name.trim().ifEmpty { AddCourseStrings.courseNameLabel.text },
                    style = MiuixTheme.textStyles.title4,
                    color = if (name.isBlank()) {
                        Color(QingyuTheme.secondaryText(dark))
                    } else {
                        Color(QingyuTheme.primaryText(dark))
                    },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = meta.ifEmpty { AddCourseStrings.sharedInfoInlineHint.text },
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    AddCourseMetaPill(
                        text = AddCourseStrings.courseNatureName(nature),
                        tint = accent,
                    )
                    firstEntry?.let { entry ->
                        AddCourseMetaPill(
                            text = AddCourseStrings.weekdayName(entry.dayOfWeek) + " · " +
                                AddCourseStrings.sectionRangeText(entry.startSection, entry.endSection),
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                }
            }
        }
    }
}

/** 名片上的小胶囊：课程性质 / 首条排课摘要。 */
@Composable
private fun AddCourseMetaPill(text: String, tint: Color) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
        color = tint,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .background(tint.copy(alpha = 0.12f), RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/**
 * 十色盘：两行五列。
 *
 * 十个圆点原来挤在一行：400dp 屏卡内只剩 344dp，最后两颗会被裁掉。
 * 改成两行五列后单行 224dp，任何字号档都不会溢出；选中态用 2dp 环 + 对勾，
 * 不靠颜色本身区分（色弱用户也能看出选中）。
 */
@Composable
private fun AddCourseColorSwatches(
    selectedColor: String,
    dark: Boolean,
    onSelect: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        kCourseColorPalette.chunked(5).forEach { rowColors ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                // 32dp 圆点 + 16dp 间距：Compose 的 48dp 最小触控区互不重叠，
                // 既不会点错色，也仍然排得进 400dp 屏的卡内宽度。
                horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally),
            ) {
                rowColors.forEach { hex ->
                    val swatch = parseCourseColor(hex, Color(QingyuTheme.primary(dark = dark)))
                    val isChosen = selectedColor.equals(hex, ignoreCase = true)
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(swatch)
                            .border(
                                width = if (isChosen) 2.dp else 1.dp,
                                color = if (isChosen) {
                                    Color(QingyuTheme.primaryText(dark))
                                } else {
                                    Color(QingyuTheme.dividerLine(dark)).copy(alpha = 0.7f)
                                },
                                shape = CircleShape,
                            )
                            .selectable(
                                selected = isChosen,
                                role = Role.RadioButton,
                                onClick = { onSelect(hex) },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isChosen) {
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(16.dp),
                            )
                        }
                    }
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
    accentColor: String,
    modifier: Modifier = Modifier,
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
    val swatch = parseCourseColor(accentColor, Color(QingyuTheme.primary(dark = dark)))
    val accent = Color(QingyuTheme.primary(seedHex = accentColor, dark = dark))
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, top = 14.dp, end = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // 序号徽标：与错误文案里的「排课记录 N」同号，同时把课程色带进每张卡。
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .background(
                            swatch.copy(alpha = if (dark) 0.24f else 0.12f),
                            CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = (index + 1).toString(),
                        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = accent,
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = AddCourseStrings.weekdayName(entry.dayOfWeek) + " · " +
                        AddCourseStrings.sectionRangeText(entry.startSection, entry.endSection),
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (entryCount > 1) {
                    IconButton(onClick = onRemoveEntry, modifier = Modifier.size(36.dp)) {
                        Icon(
                            imageVector = MiuixIcons.Remove,
                            contentDescription = AddCourseStrings.deleteAction.text,
                            tint = Color(QingyuTheme.error(dark)),
                            modifier = Modifier.size(17.dp),
                        )
                    }
                }
            }
            WindowDropdownPreference(
                items = weekdayNames,
                selectedIndex = (entry.dayOfWeek - 1).coerceIn(weekdayNames.indices),
                title = AddCourseStrings.weekdayLabel.text,
                onSelectedIndexChange = { position ->
                    (position + 1).takeIf { it in 1..7 }?.let(onDayOfWeekChange)
                },
            )
            WindowDropdownPreference(
                items = sectionNumbers.map { AddCourseStrings.sectionLabel.filled("section", it.toString()) },
                selectedIndex = sectionNumbers.indexOf(entry.startSection).coerceAtLeast(0),
                title = AddCourseStrings.startSectionLabel.text,
                onSelectedIndexChange = { position ->
                    sectionNumbers.getOrNull(position)?.let(onStartSectionChange)
                },
            )
            WindowDropdownPreference(
                items = sectionNumbers.map { AddCourseStrings.sectionLabel.filled("section", it.toString()) },
                selectedIndex = sectionNumbers.indexOf(entry.endSection).coerceAtLeast(0),
                title = AddCourseStrings.endSectionLabel.text,
                onSelectedIndexChange = { position ->
                    sectionNumbers.getOrNull(position)?.let(onEndSectionChange)
                },
            )
            // 「哪些周上」行：官方 ArrowPreference，摘要仍走保存校验同一口径。
            ArrowPreference(
                title = AddCourseStrings.scheduleEntryWeeksSectionTitle.text,
                summary = weekSummary,
                onClick = onOpenWeekPicker,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Column(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                TextField(
                    value = entry.teacher,
                    onValueChange = onTeacherChange,
                    label = AddCourseStrings.teacherLabel.text,
                    useLabelAsPlaceholder = true,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                TextField(
                    value = entry.location,
                    onValueChange = onLocationChange,
                    label = AddCourseStrings.locationLabel.text,
                    useLabelAsPlaceholder = true,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
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
    val maxBodyHeight = rememberSheetMaxHeight(0.72f)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = AddCourseStrings.weekPickerTitle.text,
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
                            title = AddCourseStrings.startWeekLabel.text,
                            onSelectedIndexChange = { position ->
                                availableWeeks.getOrNull(position)?.let { week ->
                                    onDraftChange(AddCourseWeekDraftLogic.setStartWeek(draft, week, availableWeeks))
                                }
                            },
                        )
                        WindowDropdownPreference(
                            items = availableWeeks.map { AddCourseStrings.weekLabel.filled("week", it.toString()) },
                            selectedIndex = availableWeeks.indexOf(draft.endWeek).coerceAtLeast(0),
                            title = AddCourseStrings.endWeekLabel.text,
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
                                label = AddCourseStrings.selectAllAction.text,
                                isSelected = false,
                                dark = dark,
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    onDraftChange(AddCourseWeekDraftLogic.selectAllCustom(draft, availableWeeks))
                                },
                            )
                            AddCourseChoiceChip(
                                label = AddCourseStrings.selectOddWeeksAction.text,
                                isSelected = false,
                                dark = dark,
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    onDraftChange(AddCourseWeekDraftLogic.selectOddCustom(draft, availableWeeks))
                                },
                            )
                            AddCourseChoiceChip(
                                label = AddCourseStrings.selectEvenWeeksAction.text,
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
                            Text(text = AddCourseStrings.cancelAction.text)
                        }
                        top.yukonga.miuix.kmp.basic.Button(
                            onClick = { onConfirm(draft) },
                            enabled = AddCourseWeekDraftLogic.canConfirm(draft),
                            modifier = Modifier.weight(1f),
                            colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColorsPrimary(),
                        ) {
                            Text(text = AddCourseStrings.confirmAction.text)
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

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 新建/编辑两态的初值全部由页面自己的模型层现算：`AddCourseFormLogic.buildInitialState(...)`
// 在页面内部被 remember 调用，预览不另写一份表单状态。
// `clockResolver` 是必传项（壳层注入真实作息），预览里给一个不跑真实时钟的常量实现。
//
// `Course` / `AddCourseEntryClock` 用全限定名/同包名：本文件的 import 块按预览约定
// 只允许动三行（`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览用“已有课程”：高等数学，周一 1~2 节，第 1~16 周，已设自定义钟点。 */
private val previewAddCourseInitial = com.mutx163.qingyu.core.Course(
    id = "course-math",
    name = "高等数学",
    shortName = "高数",
    teacher = "张明",
    location = "示例大学 A101",
    dayOfWeek = 1,
    startSection = 1,
    endSection = 2,
    startTime = "08:00",
    endTime = "09:40",
    startWeek = 1,
    endWeek = 16,
    description = "微积分与级数基础，期中期末各一次考试。",
)

/** 预览用的钟点解析：取作息模板的第 1~2 节钟点，不随系统时间漂。 */
private fun previewAddCourseClockResolver(entry: AddCourseScheduleEntryData): AddCourseEntryClock {
    val start = if (entry.startSection <= 2) "08:00" else "10:00"
    val end = if (entry.endSection <= 2) "09:40" else "11:40"
    return AddCourseEntryClock(startTime = start, endTime = end)
}

/** 一档预览的公共身体：新建 / 编辑 + 外观档位。 */
@Composable
private fun PreviewAddCourseBody(
    initialCourse: com.mutx163.qingyu.core.Course? = null,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        AddCoursePage(
            initialCourse = initialCourse,
            initialWeek = 8,
            initialDayOfWeek = 1,
            initialStartSection = 1,
            availableWeeks = (1..20).toList(),
            globalSectionCount = 12,
            clockResolver = ::previewAddCourseClockResolver,
            onBack = {},
            onSave = {},
            onDelete = {},
        )
    }
}

// ── 单档：新建 / 编辑 × 亮色 ────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 新建课程", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAddCourseCreate() {
    PreviewAddCourseBody()
}

@Suppress("unused")
@Preview(name = "2 编辑已有课程", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAddCourseEdit() {
    PreviewAddCourseBody(initialCourse = previewAddCourseInitial)
}

// ── 单档：外观两档（以「编辑」为基准，它内容最全）─────────────────────────

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAddCourseDark() {
    PreviewAddCourseBody(initialCourse = previewAddCourseInitial, dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAddCourseLargeText() {
    PreviewAddCourseBody(initialCourse = previewAddCourseInitial, textScale = 1.3f)
}
