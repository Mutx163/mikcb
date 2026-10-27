package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import java.time.LocalDateTime

/**
 * 表单页目录（`lib/screens/timetable_form_pages_impl.dart` 的 Kotlin 移植，纯 Kotlin 数据）。
 *
 * ## 移植形态差异
 *
 * Dart 侧是「widgets 层接口 + screens 层实现 + initState 注入」，未注入时抛
 * StateError——那套机制是为解 `widgets → screens` 反向依赖服务的。Kotlin/Compose
 * 侧页面可被壳直接引用，不存在这个反向依赖，所以这里收敛成一个无状态
 * object：**每种表单页 = 类型标识 + 参数载荷（payload）+ 软校验**。壳层拿到
 * payload 后再映射为真正的页面（course 表单的映射见 composeP1 侧
 * `CourseOverviewPage.kt` 底部的接线函数）。
 *
 * ## 参数为什么必须逐个透传（对齐 Dart 源文件头注释）
 *
 * 这批页面的**全部价值就在上下文**：点课程的日程卡进编辑页要带着那门课、
 * 点考试卡要带着那场考试、点某次日程要带着 occurrenceDate。任何一个参数在
 * 这层被吞掉，用户看到的都是「打开了，但表单是空的」——比页面打不开更糟。
 * 所以目录的每个具名参数与 Dart 构造函数一一对应，**不做「取默认值」的简化，
 * 不做静默丢弃**；上下文异常（两条日期入口混用之类）由 `validate()` 报告，
 * 不改写透传结果。契约由 `TimetableFormPagesCatalogTest` 直接对载荷字段断言
 * （对齐 `test/services/timetable_form_pages_contract_test.dart`）。
 */
enum class TimetableFormPageType(val id: String) {
    /** 加课/改课表单（`AddCourseScreen`）。 */
    COURSE_FORM("courseForm"),

    /** 考试表单（`AddExamScreen`）；exam 为 null 是新建。 */
    EXAM_FORM("examForm"),

    /** 日程表单（`AddScheduleItemScreen`）。 */
    SCHEDULE_ITEM_FORM("scheduleItemForm"),

    /** 作业/任务表单（`AddTaskScreen`）。 */
    TASK_FORM("taskForm"),

    /** 作息方案管理页（`TimeSchemeManagementScreen`）。 */
    TIME_SCHEME_MANAGEMENT("timeSchemeManagement"),

    /** 更新详情页（`AboutUpdateScreen`）。 */
    ABOUT_UPDATE("aboutUpdate"),
}

/** 更新详情页的包信息（Dart 侧来自 package_info_plus 的 PackageInfo）。 */
data class AppPackageInfo(
    val appName: String,
    val packageName: String,
    val version: String,
    val buildNumber: String,
)

/**
 * 加课/改课表单载荷。两种典型调用（timetable_form_pages.dart 文档）：
 * - 日视图/周网格课程卡展开进编辑页：传 `initialCourse`（+ `courseGroup`）；
 * - 首页「+」弹层的添加课程：传 `initialWeek` / `initialDayOfWeek`（/ 节次）。
 */
data class CourseFormPayload(
    val initialCourse: Course? = null,
    val courseGroup: CourseGroup? = null,
    val initialWeek: Int? = null,
    val initialDayOfWeek: Int? = null,
    val initialStartSection: Int? = null,
    val initialEndSection: Int? = null,
) {
    val type: TimetableFormPageType get() = TimetableFormPageType.COURSE_FORM
}

/** 考试表单载荷；`exam` 为 null 是新建。 */
data class ExamFormPayload(
    val exam: Exam? = null,
) {
    val type: TimetableFormPageType get() = TimetableFormPageType.EXAM_FORM
}

/** 日程表单的调用模式：新建（只给日期）vs 编辑既有日程/单次覆盖。 */
enum class ScheduleItemFormMode {
    CREATE_NEW,
    EDIT_EXISTING,
}

/**
 * 日程表单载荷的软校验问题。
 *
 * `initialDate` 与 `occurrenceDate` 是两条不同的入口（timetable_form_pages.dart 文档）：
 * 前者来自首页「+」弹层（新建，只给日期），后者来自点击某一次日程（编辑单次覆盖）。
 * **两者混用的直接后果是「跳错日子」**，所以由校验把混用报出来。
 */
enum class ScheduleItemFormIssue {
    /** 两个日期入口同时传：混用会跳错日子。 */
    BOTH_DATE_ENTRIES_SET,

    /** 编辑既有日程还带 initialDate（新建日期入口）。 */
    EDITING_WITH_INITIAL_DATE,

    /** 没带 scheduleItem 却传 occurrenceDate：单次覆盖必须挂在某条日程上。 */
    OCCURRENCE_WITHOUT_ITEM,
}

/**
 * 日程表单载荷。
 *
 * 校验只**报告**、不改写：`initialDate` 与 `occurrenceDate` 各归各的字段，
 * 互不顶替（契约测试钉死）。
 */
data class ScheduleItemFormPayload(
    val scheduleItem: ScheduleItem? = null,
    val initialDate: LocalDateTime? = null,
    val occurrenceDate: LocalDateTime? = null,
) {
    val type: TimetableFormPageType get() = TimetableFormPageType.SCHEDULE_ITEM_FORM

    val mode: ScheduleItemFormMode
        get() = if (scheduleItem != null) ScheduleItemFormMode.EDIT_EXISTING else ScheduleItemFormMode.CREATE_NEW

    fun validate(): List<ScheduleItemFormIssue> = buildList {
        if (initialDate != null && occurrenceDate != null) {
            add(ScheduleItemFormIssue.BOTH_DATE_ENTRIES_SET)
        }
        if (scheduleItem != null && initialDate != null) {
            add(ScheduleItemFormIssue.EDITING_WITH_INITIAL_DATE)
        }
        if (scheduleItem == null && occurrenceDate != null) {
            add(ScheduleItemFormIssue.OCCURRENCE_WITHOUT_ITEM)
        }
    }
}

/**
 * 作业表单载荷的软校验问题：传了 `task` 就是编辑模式（页面自己从 task 预填），
 * `initialCourse` / `initialWeek` 是「从某节课加作业」的新建入口——
 * 编辑态带新建预填会被页面忽略，由校验报告。
 */
enum class TaskFormIssue {
    EDITING_WITH_INITIAL_COURSE,
    EDITING_WITH_INITIAL_WEEK,
}

/** 作业/任务表单载荷；`task` 非空 = 编辑那一条，null = 新建。 */
data class TaskFormPayload(
    val task: CourseTask? = null,
    val initialCourse: Course? = null,
    val initialWeek: Int? = null,
) {
    val type: TimetableFormPageType get() = TimetableFormPageType.TASK_FORM

    fun validate(): List<TaskFormIssue> = buildList {
        if (task != null && initialCourse != null) {
            add(TaskFormIssue.EDITING_WITH_INITIAL_COURSE)
        }
        if (task != null && initialWeek != null) {
            add(TaskFormIssue.EDITING_WITH_INITIAL_WEEK)
        }
    }
}

/** 作息方案管理页载荷；`initialEditSchemeId` 非空 = 打开即进入该方案编辑。 */
data class TimeSchemeManagementPayload(
    val initialEditSchemeId: String? = null,
) {
    val type: TimetableFormPageType get() = TimetableFormPageType.TIME_SCHEME_MANAGEMENT
}

/** 更新详情页载荷（Dart 侧 `packageInfo` 是必填参数）。 */
data class AboutUpdatePayload(
    val packageInfo: AppPackageInfo,
) {
    val type: TimetableFormPageType get() = TimetableFormPageType.ABOUT_UPDATE
}

/**
 * 表单页目录本体：与 Dart `kTimetableFormPages` 的六个 builder 一一对应。
 */
object TimetableFormPagesCatalog {

    /** 加课/改课表单：六个具名参数逐个透传（对应 `_buildCourseForm`）。 */
    fun courseForm(
        initialCourse: Course? = null,
        courseGroup: CourseGroup? = null,
        initialWeek: Int? = null,
        initialDayOfWeek: Int? = null,
        initialStartSection: Int? = null,
        initialEndSection: Int? = null,
    ): CourseFormPayload = CourseFormPayload(
        initialCourse = initialCourse,
        courseGroup = courseGroup,
        initialWeek = initialWeek,
        initialDayOfWeek = initialDayOfWeek,
        initialStartSection = initialStartSection,
        initialEndSection = initialEndSection,
    )

    /** 考试表单（对应 `_buildExamForm`）。 */
    fun examForm(exam: Exam? = null): ExamFormPayload = ExamFormPayload(exam = exam)

    /** 日程表单：`initialDate` 与 `occurrenceDate` 各归各，互不顶替（对应 `_buildScheduleItemForm`）。 */
    fun scheduleItemForm(
        scheduleItem: ScheduleItem? = null,
        initialDate: LocalDateTime? = null,
        occurrenceDate: LocalDateTime? = null,
    ): ScheduleItemFormPayload = ScheduleItemFormPayload(
        scheduleItem = scheduleItem,
        initialDate = initialDate,
        occurrenceDate = occurrenceDate,
    )

    /** 作业表单（对应 `_buildTaskForm`）。 */
    fun taskForm(
        task: CourseTask? = null,
        initialCourse: Course? = null,
        initialWeek: Int? = null,
    ): TaskFormPayload = TaskFormPayload(
        task = task,
        initialCourse = initialCourse,
        initialWeek = initialWeek,
    )

    /** 作息方案管理页（对应 `_buildTimeSchemeManagement`）。 */
    fun timeSchemeManagement(
        initialEditSchemeId: String? = null,
    ): TimeSchemeManagementPayload = TimeSchemeManagementPayload(initialEditSchemeId = initialEditSchemeId)

    /** 更新详情页（对应 `_buildAboutUpdate`）。 */
    fun aboutUpdate(packageInfo: AppPackageInfo): AboutUpdatePayload =
        AboutUpdatePayload(packageInfo = packageInfo)
}
