package com.mutx163.qingyu.pages.course

import android.widget.Toast
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuColorPickerDialog
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.glass.LocalQingyuPageBackdrop
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.DialogGlassSpec
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Info
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
 * - 教师/教室：走共享 [CourseFieldPickerSheet]（发布版 `showCourseFieldPickerSheet`，
 *   候选由壳用 `CourseFieldSuggestionLogic` 从课程 + 日程算好注入）；星期/节次/周次
 *   仍是 Miuix 行内下拉与周网格弹层。
 * - 「沿用已有课程」（2026-11-10 已建）与「时间模板」行（同一批补上）：两者都需要
 *   provider 数据，现由壳经 [courseTemplates] / [timeSchemes] 注入；条目上的
 *   `timeSchemeIdOverride` 由模型层原样穿透，本页只负责选择与回写。
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
    /** 课表里已有的课程：新建态「沿用已有课程」的候选（发布版 `provider.courseGroups` 的拍平视图）。 */
    courseTemplates: List<Course> = emptyList(),
    /** 教师候选（发布版 `provider.uniqueTeachers` 的对位；壳用 CourseFieldSuggestionLogic 算）。 */
    teacherSuggestions: List<String> = emptyList(),
    /** 地点候选（发布版 `provider.uniqueLocations` 的对位，含日程地点）。 */
    locationSuggestions: List<String> = emptyList(),
    /** 时间模板候选（发布版 `provider.timeSchemes`）；首项「跟随当前课表」写回 null。 */
    timeSchemes: List<TimeScheme> = emptyList(),
    /** 当前生效模板名（`跟随当前课表 · <name>` 里的 name；null = 未知，只显示「跟随当前课表」）。 */
    activeTimeSchemeName: String? = null,
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
    // 「课程颜色」选择行点开的官方取色弹窗；常驻组合，显隐只由它驱动（2026-11-10 十色点阵退役）。
    var colorPickerOpen by remember { mutableStateOf(false) }
    // 「沿用已有课程」候选（按课名分组、名称升序）与选择弹层开关。
    val templateGroups = remember(courseTemplates) { AddCourseTemplateLogic.groups(courseTemplates) }
    var templatePickerOpen by remember { mutableStateOf(false) }
    // 「已有教师 / 地点」选择弹层：目标 = 共享信息卡两行 或 某条排课记录。
    var fieldPickerTarget by remember { mutableStateOf<CourseFieldPickerTarget?>(null) }
    // 「时间模板」选择弹层当前作用于哪条排课记录（null = 关）。
    var timeSchemePickerEntryId by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current

    fun markDirty() {
        dirty = true
    }

    fun updateEntry(index: Int, update: (AddCourseScheduleEntryData) -> AddCourseScheduleEntryData) {
        entries = entries.mapIndexed { i, entry -> if (i == index) update(entry) else entry }
        markDirty()
    }

    /**
     * 沿用已有课程：六字段回填 + 每条排课记录的教师/地点同步；**不搬排课时间表**
     * （发布版 `_applyCourseTemplate`：只改共享信息与条目教师/地点，星期/节次/周次原样）。
     */
    fun applyTemplate(course: Course) {
        val fill = AddCourseTemplateLogic.fillFor(course)
        sharedName = fill.name
        sharedShortName = fill.shortName
        sharedTeacher = fill.teacher
        sharedDescription = fill.description
        courseNature = fill.courseNature
        selectedColor = fill.color
        entries = AddCourseTemplateLogic.fillEntries(entries, course)
        nameError = null
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
                                Row(verticalAlignment = Alignment.CenterVertically) {
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
                                        modifier = Modifier.weight(1f),
                                    )
                                    // 发布版 `showReuseAction = course == null` 只判 course；这里**有意收窄**成
                                    // 「只有新建态才出现」：组编辑时课程组已存在，沿用模板回填会盖掉整组共享信息。
                                    // 按钮宽 108dp（Dart `_reuseCourseActionWidth = 108.0`）。
                                    if (!isEditing) {
                                        Spacer(modifier = Modifier.width(8.dp))
                                        TextButton(
                                            text = AddCourseStrings.reuseExistingCourseLabel.text,
                                            onClick = {
                                                if (templateGroups.isEmpty()) {
                                                    Toast.makeText(
                                                        context,
                                                        AddCourseStrings.noTemplateCoursesHint.text,
                                                        Toast.LENGTH_SHORT,
                                                    ).show()
                                                } else {
                                                    templatePickerOpen = true
                                                }
                                            },
                                            modifier = Modifier.width(108.dp),
                                            minWidth = 0.dp,
                                            minHeight = 0.dp,
                                            insideMargin = PaddingValues(horizontal = 10.dp, vertical = 11.dp),
                                            textStyle = MiuixTheme.textStyles.footnote1,
                                        )
                                    }
                                }
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
                            // 教师 / 地点：发布版是「手输 + 历史候选」弹层（`showCourseFieldPickerSheet`，
                            // `add_course_screen.dart:917/:933`）；共享卡这两行与条目两行走同一份弹层。
                            BasicComponent(
                                title = AddCourseStrings.teacherLabel.text,
                                endActions = {
                                    Text(
                                        text = sharedTeacher.ifBlank { AddCourseStrings.manualInputLabel.text },
                                        style = MiuixTheme.textStyles.body2,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                    )
                                },
                                onClick = { fieldPickerTarget = CourseFieldPickerTarget.Shared(teacher = true) },
                            )
                            BasicComponent(
                                title = AddCourseStrings.locationLabel.text,
                                endActions = {
                                    Text(
                                        text = sharedLocation.ifBlank { AddCourseStrings.manualInputLabel.text },
                                        style = MiuixTheme.textStyles.body2,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                    )
                                },
                                onClick = { fieldPickerTarget = CourseFieldPickerTarget.Shared(teacher = false) },
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
                        // 发布版 v2.1.4.1 的「课程颜色」是一行选择器（`HyperosPickerField`：左侧色块
                        // + 十六进制值，点开全色调色盘），不是我们自造的十色点阵；这里照样只留一行，
                        // 点开官方 ColorPicker。选色落盘仍只走 selectedColor 一处。
                        BasicComponent(
                            title = AddCourseStrings.courseColorTitle.text,
                            endActions = {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(20.dp)
                                            .clip(RoundedCornerShape(5.dp))
                                            .background(
                                                parseCourseColor(
                                                    selectedColor,
                                                    Color(QingyuTheme.primary(dark = dark)),
                                                ),
                                            )
                                            .border(
                                                width = 1.dp,
                                                color = Color(QingyuTheme.outline(dark)),
                                                shape = RoundedCornerShape(5.dp),
                                            ),
                                    )
                                    Text(
                                        text = selectedColor.uppercase(),
                                        style = MiuixTheme.textStyles.body2,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                    )
                                }
                            },
                            onClick = { colorPickerOpen = true },
                        )
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
                        onOpenTeacherPicker = {
                            fieldPickerTarget = CourseFieldPickerTarget.Entry(index = index, teacher = true)
                        },
                        onOpenLocationPicker = {
                            fieldPickerTarget = CourseFieldPickerTarget.Entry(index = index, teacher = false)
                        },
                        activeTimeSchemeName = activeTimeSchemeName,
                        timeSchemes = timeSchemes,
                        onOpenTimeSchemePicker = { timeSchemePickerEntryId = entry.id },
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
            // 12dp：发布版 HyperosDialog 的动作行间距（`hyperos_dialog.dart` 两颗按钮之间）。
            horizontalArrangement = Arrangement.spacedBy(12.dp),
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
            // 12dp：与放弃修改框 / 发布版 HyperosDialog 的动作行同一间距。
            horizontalArrangement = Arrangement.spacedBy(12.dp),
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

    // 沿用已有课程弹层：常驻组合、显隐只由 `show` 驱动（与全仓弹层口径一致）。
    AddCourseTemplatePickerSheet(
        show = templatePickerOpen,
        groups = templateGroups,
        dark = dark,
        onPick = { group ->
            templatePickerOpen = false
            applyTemplate(group.course)
        },
        onDismiss = { templatePickerOpen = false },
    )

    // 「已有教师 / 地点」弹层：常驻组合、显隐只由 `fieldPickerTarget` 驱动。
    // 候选由壳用 `CourseFieldSuggestionLogic` 从课程 + 日程算好传进来；空表时就是纯手输，
    // 不伪造历史（发布版有一份持久记录表，本仓没有——已登记的已知差异）。
    val pickerTarget = fieldPickerTarget
    val pickerIsTeacher = when (val target = pickerTarget) {
        is CourseFieldPickerTarget.Shared -> target.teacher
        is CourseFieldPickerTarget.Entry -> target.teacher
        null -> true
    }
    val pickerInitialValue = when (val target = pickerTarget) {
        null -> ""
        is CourseFieldPickerTarget.Shared -> if (target.teacher) sharedTeacher else sharedLocation
        is CourseFieldPickerTarget.Entry -> entries.getOrNull(target.index)?.let { entry ->
            if (target.teacher) entry.teacher else entry.location
        } ?: ""
    }
    CourseFieldPickerSheet(
        show = pickerTarget != null,
        title = if (pickerIsTeacher) {
            AddCourseStrings.selectTeacherTitle.text
        } else {
            AddCourseStrings.selectLocationTitle.text
        },
        label = AddCourseStrings.manualInputLabel.text,
        value = pickerInitialValue,
        suggestions = if (pickerIsTeacher) teacherSuggestions else locationSuggestions,
        confirmLabel = AddCourseStrings.confirmAction.text,
        cancelLabel = AddCourseStrings.cancelAction.text,
        onDismiss = { fieldPickerTarget = null },
        onConfirm = { picked ->
            when (val target = fieldPickerTarget) {
                is CourseFieldPickerTarget.Shared -> {
                    if (target.teacher) sharedTeacher = picked else sharedLocation = picked
                    markDirty()
                }
                is CourseFieldPickerTarget.Entry -> {
                    updateEntry(target.index) { entry ->
                        if (target.teacher) entry.copy(teacher = picked) else entry.copy(location = picked)
                    }
                }
                null -> {}
            }
            fieldPickerTarget = null
        },
    )

    // 「时间模板」弹层：常驻组合、显隐由 `timeSchemePickerEntryId` 驱动。
    // 候选 = 「跟随当前课表」（写回 null）+ `timeSchemes`；不自造模板。
    val timeSchemeEntry = entries.firstOrNull { it.id == timeSchemePickerEntryId }
    AddCourseTimeSchemeSheet(
        show = timeSchemeEntry != null,
        activeName = activeTimeSchemeName,
        schemes = timeSchemes,
        selectedId = timeSchemeEntry?.timeSchemeIdOverride,
        onDismiss = { timeSchemePickerEntryId = null },
        onPick = { schemeId ->
            val targetId = timeSchemePickerEntryId
            val targetIndex = entries.indexOfFirst { it.id == targetId }
            if (targetIndex >= 0) {
                updateEntry(targetIndex) { it.copy(timeSchemeIdOverride = schemeId) }
            }
            timeSchemePickerEntryId = null
        },
    )

    // 十色点阵退役（2026-11-10）：发布版没有点阵，只有一行「课程颜色」选择行；
    // 选色走官方 ColorPicker 弹窗。常驻组合、显隐只由 `show` 驱动（退场动画才播得出来）。
    QingyuColorPickerDialog(
        show = colorPickerOpen,
        initialHex = selectedColor,
        title = AddCourseStrings.courseColorTitle.text,
        cancelLabel = AddCourseStrings.cancelAction.text,
        confirmLabel = AddCourseStrings.confirmAction.text,
        dark = dark,
        onDismiss = { colorPickerOpen = false },
        onConfirm = { hex ->
            selectedColor = hex
            markDirty()
            colorPickerOpen = false
        },
    )
}

// ── 课程名片 / 颜色 / 单条排课卡片 ──────────────────────────────────────────

/** 把课程色解析成 Compose 颜色；用户数据里的坏值回落主题主色，不让整页崩。 */
private fun parseCourseColor(hex: String, fallback: Color): Color =
    runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(fallback)

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
    /** 点「教师」行：由页面统一开「已有教师」弹层（弹层状态在页级，不为此拆第二份）。 */
    onOpenTeacherPicker: () -> Unit,
    onOpenLocationPicker: () -> Unit,
    /** 当前生效模板名：`跟随当前课表 · <name>` 的 name（null = 未知）。 */
    activeTimeSchemeName: String?,
    /** 时间模板候选（第一项「跟随当前课表」由页面拼，写回 null）。 */
    timeSchemes: List<TimeScheme>,
    /** 点「时间模板」行：由页面统一开模板弹层。 */
    onOpenTimeSchemePicker: () -> Unit,
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
                // 教师 / 地点：发布版这两个位置就是 `CourseFieldPickerTile`（`add_course_screen.dart:917/:933`），
                // 点开「手输 + 历史候选」弹层；这里不再用纯 TextField 手打。
                BasicComponent(
                    title = AddCourseStrings.teacherLabel.text,
                    endActions = {
                        Text(
                            text = entry.teacher.ifBlank { AddCourseStrings.manualInputLabel.text },
                            style = MiuixTheme.textStyles.body2,
                            color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        )
                    },
                    onClick = onOpenTeacherPicker,
                )
                BasicComponent(
                    title = AddCourseStrings.locationLabel.text,
                    endActions = {
                        Text(
                            text = entry.location.ifBlank { AddCourseStrings.manualInputLabel.text },
                            style = MiuixTheme.textStyles.body2,
                            color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        )
                    },
                    onClick = onOpenLocationPicker,
                )
                // 时间模板（Dart `_buildEntryTimeSchemeField`）：null = 跟随当前课表，否则覆盖这一条。
                BasicComponent(
                    title = AddCourseStrings.timeSchemeLabel.text,
                    endActions = {
                        Text(
                            text = entryTimeSchemeSummary(entry, activeTimeSchemeName, timeSchemes),
                            style = MiuixTheme.textStyles.body2,
                            color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    onClick = onOpenTimeSchemePicker,
                )
            }
        }
    }
}

/**
 * 「哪些周上」弹层（Dart `_showEntryWeekPickerDialog` 的 Compose 形态）：
 * 模式组 + （范围：起止周 + 单双周组 | 自定义：周网格 + 全选/单周/双周）+ 摘要 + 确认。
 * 确认键按 [AddCourseWeekDraftLogic.canConfirm] 启用——最终周次为空集不许确认。
 *
 * 2026-11-10 按发布版 v2.1.4.1（`add_course_screen.dart:1713-1960`）对齐三处：
 * - 起止周不再走行内下拉，改成**单列滚轮弹层**（Dart `_pickFromNumberWheelSheet` →
 *   `showMiuixNumberPickerSheet`：220dp、title3 w600、「第 N 周」文案、取消 + 确认）；
 *   止周滚轮的下界是当前起周（发布版 `minValue: tempStartWeek`）。
 * - 取消 / 确认钉在滚动区**外面**（Dart 的底部动作行在 ListView 之外）：发布版是全屏子页，
 *   这里收成对话框（正文限高 + 可滚），周次多（53 周 / 大字号）时不必滚到底才能确认。
 * - 动作行间距 12dp、确认主色 / 取消灰底，与发布版 HyperosDialog 同一口径。
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
    // 正文 + 动作行的总限高：动作行固定在滚动区外，所以整卡一起限（不是只限列表）。
    val maxCardHeight = rememberSheetMaxHeight(0.72f)
    // 正在滚的「起 / 止」周；null = 滚轮弹层收起。
    var pickingWeekEndpoint by remember { mutableStateOf<AddCourseWeekEndpoint?>(null) }
    val wheelEndpoint = pickingWeekEndpoint
    val wheelDraft = currentDraft
    // 止周滚轮的下界是当前起周（发布版 `_pickFromNumberWheelSheet(minValue: tempStartWeek)`），
    // 这样滚轮里根本滚不出「止周 < 起周」；回写时模型层还会再夹一次。
    val wheelWeeks = when (wheelEndpoint) {
        AddCourseWeekEndpoint.END -> {
            availableWeeks.filter { it >= (wheelDraft?.startWeek ?: availableWeeks.first()) }
        }
        else -> availableWeeks
    }.ifEmpty { availableWeeks }

    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = AddCourseStrings.weekPickerTitle.text,
        onDismissRequest = onDismiss,
    ) {
        val draft = currentDraft ?: return@OverlayDialog
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = maxCardHeight),
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    // fill = false：内容短时列表只占自身高度，不把对话框撑成空白大板。
                    .weight(1f, fill = false)
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
                            // 起止周 = 发布版 `HyperosPickerField`：行内显示「第 N 周」，点行弹单列滚轮。
                            AddCourseWeekPickerField(
                                label = AddCourseStrings.startWeekLabel.text,
                                value = AddCourseStrings.weekLabel.filled("week", draft.startWeek.toString()),
                                onClick = { pickingWeekEndpoint = AddCourseWeekEndpoint.START },
                            )
                            AddCourseWeekPickerField(
                                label = AddCourseStrings.endWeekLabel.text,
                                value = AddCourseStrings.weekLabel.filled("week", draft.endWeek.toString()),
                                onClick = { pickingWeekEndpoint = AddCourseWeekEndpoint.END },
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
                    }
                }
            }
            // 动作行钉在滚动区外（发布版底部动作行在 ListView 之外）：周次再多也不用来回滚。
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = AddCourseStrings.cancelAction.text)
                }
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = { onConfirm(draft) },
                    // 算出来的周次为空（例如「第 2 周 + 单周」）时不许确认：存进去的课
                    // 任何一周都不出现，却仍计入统计（发布版同一条 `selectedWeeks.isEmpty` 判据）。
                    enabled = AddCourseWeekDraftLogic.canConfirm(draft),
                    modifier = Modifier.weight(1f),
                    colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = AddCourseStrings.confirmAction.text)
                }
            }
        }
    }

    // 滚轮弹层在对话框**之后**组合：同一 root scaffold 下后组合者画在上层，
    // 否则会被周次对话框盖住（发布版同样是把 sheet 叠在子页之上）。
    AddCourseWeekWheelSheet(
        show = wheelEndpoint != null,
        title = if (wheelEndpoint == AddCourseWeekEndpoint.END) {
            AddCourseStrings.endWeekLabel.text
        } else {
            AddCourseStrings.startWeekLabel.text
        },
        weeks = wheelWeeks,
        currentWeek = if (wheelEndpoint == AddCourseWeekEndpoint.END) {
            wheelDraft?.endWeek
        } else {
            wheelDraft?.startWeek
        },
        onConfirm = { week ->
            val draft = wheelDraft
            if (draft != null) {
                when (wheelEndpoint) {
                    AddCourseWeekEndpoint.START -> onDraftChange(
                        AddCourseWeekDraftLogic.setStartWeek(draft, week, availableWeeks),
                    )
                    AddCourseWeekEndpoint.END -> onDraftChange(
                        AddCourseWeekDraftLogic.setEndWeek(draft, week, availableWeeks),
                    )
                    null -> Unit
                }
            }
            pickingWeekEndpoint = null
        },
        onDismiss = { pickingWeekEndpoint = null },
    )
}

/** 周次滚轮正在选「起 / 止」哪一端。 */
private enum class AddCourseWeekEndpoint { START, END }

/**
 * 起 / 止周选值行（Dart `HyperosPickerField` 的等价物）：标签 + 行尾取值 + 整行可点。
 *
 * 与 `schedule/AddScheduleItemPage.SchedulePickerField`、`SettingsHolidayHost.DatePickerField`
 * 同一先例：官方 `BasicComponent` 承载，自带 16dp 内边距与官方按压反馈。
 */
@Composable
private fun AddCourseWeekPickerField(label: String, value: String, onClick: () -> Unit) {
    BasicComponent(
        title = label,
        endActions = {
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        onClick = onClick,
    )
}

/**
 * 起 / 止周滚轮弹层：与发布版 `showMiuixNumberPickerSheet` 同口径——
 * 底部 sheet、单列 `NumberPicker`（0.9.4 没有跨周列表能力，选项即连续周次区间）、
 * 高 220dp、`title3` + w600、行文案「第 N 周」、取消灰底 + 确认主色、间距 12dp。
 *
 * 不循环：周次是一段区间，滚到底就是边界（发布版 `MiuixFlingNumberPicker` 默认不 wrap）。
 */
@Composable
private fun AddCourseWeekWheelSheet(
    show: Boolean,
    title: String,
    weeks: List<Int>,
    currentWeek: Int?,
    onConfirm: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    if (weeks.isEmpty()) return
    val range = weeks.first()..weeks.last()
    var week by remember(show, currentWeek) {
        mutableIntStateOf((currentWeek ?: weeks.first()).coerceIn(range))
    }

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 内容根 Column 自带左右 16dp ⇒ 框架侧横向归零，单边仍是 16，不叠成 32。
        contentPadsHorizontally = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = week,
                    onValueChange = { week = it },
                    range = range,
                    label = { AddCourseStrings.weekLabel.filled("week", it.toString()) },
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = AddCourseStrings.cancelAction.text)
                }
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = { onConfirm(week) },
                    modifier = Modifier.weight(1f),
                    colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = AddCourseStrings.confirmAction.text)
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
//
// 高度口径（2026-11-10 用户点名「预览看不到排课区」）：四档整页预览按**整页高度**给画布
// （1800 / 1800 / 1800 / 2200dp，大字号那档按 1.3 倍放宽），AS 里等比缩小能看全页、
// 切「实际大小」可滚。另加一档 400×900 的「5 排课区 1:1」：只画排课段并按原尺寸显示，
// 用来核对卡内下拉行、「哪些周上」摘要与条目删除键——整页缩放后这些细节看不清。

/** 预览用“已有课程”：高等数学，周一 1~2 节，第 1~16 周，已设自定义钟点。 */
internal val previewAddCourseInitial = com.mutx163.qingyu.core.Course(
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

// ── 单档：新建 / 编辑 × 亮色 ────────────────────────────────

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

// ── 单档：外观两档（以「编辑」为基准，它内容最全）─────────────────────

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

/**
 * 「5 整页」：整页高度档。
 *
 * 900 那几档只画一屏，页面下方的**排课区**（星期 / 起止节次 / 哪些周上 / 条目教师教室）
 * 会被画布裁掉——用户点名「预览看不到排课区」就是这件事。这一档按整页高度给画布
 * （1400dp），AS 里等比缩小能看全页、切「实际大小」可滚。
 *
 * 名字按全仓口径用中文（356 个既有预览名都是中文）；`CjkLiteralGateTest` 把预览名里的中文
 * 计入棘轮，本档新增的 1 条已在 `cjk-literal-baseline.txt` 登记（理由：@Preview 名是 IDE
 * 标签、非屏上文案）。
 */
@Suppress("unused")
@Preview(name = "5 整页 1400", showBackground = true, widthDp = 400, heightDp = 1400)
@Composable
private fun PreviewAddCourseFullPage() {
    PreviewAddCourseBody(initialCourse = previewAddCourseInitial)
}

/**
 * 沿用已有课程：课程模板选择弹层（发布版 `widgets/course_template_picker_sheet.dart`）。
 *
 * 一行的名片信息取该组第一门课（Dart `final representative = group.courses.first`）：
 * 36dp 圆角色块 + 12dp 同色圆点、课名 + 教师副标题；点一行即回填。
 * 标题用 `reuseExistingCourseHelper`（「带入这门课已有的信息」），底部一颗取消——
 * 与发布版的 sheet 结构一致。
 */
@Composable
private fun AddCourseTemplatePickerSheet(
    show: Boolean,
    groups: List<AddCourseTemplateGroup>,
    dark: Boolean,
    onPick: (AddCourseTemplateGroup) -> Unit,
    onDismiss: () -> Unit,
) {
    QingyuSheet(
        show = show,
        title = AddCourseStrings.reuseExistingCourseHelper.text,
        onDismissRequest = onDismiss,
        // Dart `maxListHeight = MediaQuery.sizeOf(context).height * 0.52`；
        // 本仓弹层要连标题与取消按钮一起算，给 0.72 让列表区落在同一高度。
        maxHeightFraction = 0.72f,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            groups.forEach { group ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(group) }
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val groupColor = parseCourseColor(
                        group.color,
                        Color(QingyuTheme.primary(dark = dark)),
                    )
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(groupColor.copy(alpha = 0.14f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(groupColor),
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = group.name,
                            style = MiuixTheme.textStyles.main,
                            color = Color(QingyuTheme.primaryText(dark)),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (group.teacher.isNotBlank()) {
                            Text(
                                text = group.teacher,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            TextButton(
                text = AddCourseStrings.cancelAction.text,
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
/**
 * 「已有教师 / 地点」弹层当前作用于哪一处：共享信息卡两行，或第 [Entry.index] 条排课记录。
 */
private sealed class CourseFieldPickerTarget {
    /** 共享信息卡：教师（true）/ 地点（false）。 */
    data class Shared(val teacher: Boolean) : CourseFieldPickerTarget()

    /** 第 [index] 条排课记录：教师（true）/ 地点（false）。 */
    data class Entry(val index: Int, val teacher: Boolean) : CourseFieldPickerTarget()
}

/**
 * 「时间模板」行的摘要：null = 跟随当前课表（带生效模板名），否则显示覆盖模板名。
 *
 * 发布版 `_buildEntryTimeSchemeField`：`timeSchemeIdOverride == null` 时显示
 * 「跟随当前课表 · <生效模板>」；模板被删/找不到 id 时退回 id 本身，不吞成空白。
 */
private fun entryTimeSchemeSummary(
    entry: AddCourseScheduleEntryData,
    activeTimeSchemeName: String?,
    schemes: List<TimeScheme>,
): String {
    val overrideId = entry.timeSchemeIdOverride
    if (overrideId != null) {
        return schemes.firstOrNull { it.id == overrideId }?.name ?: overrideId
    }
    return AddCourseStrings.followCurrentTimetableWithName
        .filled("name", activeTimeSchemeName.orEmpty())
        .trimEnd()
}

/**
 * 「时间模板」选择弹层（照 `AddCourseWeekPickerDialog` 的列表形态，不自造控件）。
 *
 * 首项「跟随当前课表」写回 `null`（= 用课表生效模板）；其余项写回模板 id。
 * 与发布版 `_buildEntryTimeSchemeField` 的弹层语义一致。
 */
@Composable
private fun AddCourseTimeSchemeSheet(
    show: Boolean,
    activeName: String?,
    schemes: List<TimeScheme>,
    selectedId: String?,
    onDismiss: () -> Unit,
    onPick: (String?) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val accent = MiuixTheme.colorScheme.primary
    val followLabel = AddCourseStrings.followCurrentTimetableWithName
        .filled("name", activeName.orEmpty())
        .trimEnd()
    QingyuSheet(
        show = show,
        title = AddCourseStrings.timeSchemeLabel.text,
        onDismissRequest = onDismiss,
        maxHeightFraction = 0.72f,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 首项：跟随当前课表（id = null）。
            TimeSchemeOptionRow(
                label = followLabel,
                selected = selectedId == null,
                primaryText = primaryText,
                accentColor = accent,
                onClick = { onPick(null) },
            )
            schemes.forEach { scheme ->
                TimeSchemeOptionRow(
                    label = scheme.name,
                    selected = selectedId == scheme.id,
                    primaryText = primaryText,
                    accentColor = accent,
                    onClick = { onPick(scheme.id) },
                )
            }
        }
    }
}

/** 模板弹层里的一行（选中态 = 主色字 + 勾，与同域列表弹层一致）。 */
@Composable
private fun TimeSchemeOptionRow(
    label: String,
    selected: Boolean,
    primaryText: Color,
    accentColor: Color,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.main,
            color = if (selected) accentColor else primaryText,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (selected) {
            Icon(
                imageVector = MiuixIcons.Ok,
                contentDescription = null,
                tint = accentColor,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}
