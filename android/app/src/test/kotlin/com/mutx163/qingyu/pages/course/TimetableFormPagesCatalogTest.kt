package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 表单页目录注入契约：**参数必须原样到达页面载荷**。
 *
 * 对齐 Dart 侧 `test/services/timetable_form_pages_contract_test.dart`（6 例）
 * 与 TEST-POLICY「参数透传类改动」一节：存量 UI 测试只断言「页面打开了」，
 * 参数在中间层被吞掉也照样绿。所以这里**直接对着目录产出的载荷字段断言**，
 * 不经过任何 UI 渲染。
 *
 * 被钉死的三条语义（来自 `lib/widgets/timetable/timetable_form_pages.dart` 的文档）：
 * 1. 每个具名参数与页面构造函数一一对应，不做「取个默认值」的简化；
 * 2. `initialDate` 与 `occurrenceDate` 是两条不同入口，**不许互相顶替**
 *    （混用的直接后果是「跳错日子」）；
 * 3. 作业表单传了 `task` 就是编辑模式，`initialCourse` / `initialWeek` 是新建
 *    预填入口，三者不能互相顶替。
 *
 * 与 Dart 侧的形态差异：Dart 用「widgets 层接口 + screens 层注入」解依赖，
 * 未注入时抛 StateError；Kotlin 侧页面可被壳直接引用，目录是无状态 object，
 * 不需要 register/get 与 StateError 机制，故不移植那 2 例。
 */
class TimetableFormPagesCatalogTest {

    // ── 夹具：与 Dart 契约测试同名同值 ──

    private val course = Course(
        id = "c1",
        name = "高等数学",
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    /** 「大学英语」组：故意不含 [course]，用来抓「initialCourse 被 courseGroup 顶替」。 */
    private val unrelatedGroup = CourseGroup(
        name = "大学英语",
        courses = listOf(
            Course(
                id = "c2",
                name = "大学英语",
                teacher = "李老师",
                location = "B202",
                dayOfWeek = 3,
                startSection = 3,
                endSection = 4,
                startTime = "10:00",
                endTime = "11:40",
            ),
        ),
    )

    private fun scheduleItem(
        id: String = "s1",
        date: LocalDateTime = LocalDateTime.of(2026, 5, 12, 0, 0),
    ): ScheduleItem = ScheduleItem(
        id = id,
        title = "答疑",
        startDate = date,
        endDate = date,
        startTime = "19:00",
        endTime = "20:00",
        createdAt = LocalDateTime.of(2026, 4, 12, 0, 0),
        updatedAt = LocalDateTime.of(2026, 4, 12, 0, 0),
    )

    // ==========================================
    // 1. 课程表单（courseForm）
    // ==========================================

    @Test
    fun `课程表单：initialCourse 与 courseGroup 两个编辑入口互不顶替`() {
        // 日视图/周网格课程卡展开编辑页时两个入口同时传（timetable_form_pages.dart 文档）。
        // courseGroup 故意与 initialCourse 不同源：目录若把 initialCourse 顶替成
        // courseGroup 里的课程，这条会当场红（这正是 TEST-POLICY 点名的那类 bug）。
        val payload = TimetableFormPagesCatalog.courseForm(
            initialCourse = course,
            courseGroup = unrelatedGroup,
            initialWeek = 7,
            initialDayOfWeek = 3,
            initialStartSection = 2,
            initialEndSection = 5,
        )

        assertSame("丢了 initialCourse，编辑页就是空表单", course, payload.initialCourse)
        assertSame("丢了 courseGroup，编辑页不知道在改哪一组", unrelatedGroup, payload.courseGroup)
        assertEquals(7, payload.initialWeek)
        assertEquals(3, payload.initialDayOfWeek)
        assertEquals(2, payload.initialStartSection)
        assertEquals(5, payload.initialEndSection)
        assertEquals(TimetableFormPageType.COURSE_FORM, payload.type)
    }

    @Test
    fun `课程表单：无参调用仍是新建（全部为 null）`() {
        val payload = TimetableFormPagesCatalog.courseForm()

        assertNull(payload.initialCourse)
        assertNull(payload.courseGroup)
        assertNull(payload.initialWeek)
        assertNull(payload.initialDayOfWeek)
        assertNull(payload.initialStartSection)
        assertNull(payload.initialEndSection)
    }

    // ==========================================
    // 2. 考试表单（examForm）
    // ==========================================

    @Test
    fun `考试表单：exam 透传；无参是新建`() {
        val exam = Exam(
            id = "e1",
            courseId = "c1",
            name = "期末考试",
            dateTime = LocalDateTime.of(2026, 6, 20, 0, 0),
            startTime = "09:00",
            endTime = "11:00",
            createdAt = LocalDateTime.of(2026, 5, 12, 0, 0),
            updatedAt = LocalDateTime.of(2026, 5, 12, 0, 0),
        )

        val editing = TimetableFormPagesCatalog.examForm(exam = exam)
        assertSame("丢了 exam，编辑页就是一张空表单", exam, editing.exam)
        assertEquals(TimetableFormPageType.EXAM_FORM, editing.type)

        assertNull(TimetableFormPagesCatalog.examForm().exam)
    }

    // ==========================================
    // 3. 日程表单（scheduleItemForm）——initialDate / occurrenceDate 互不顶替
    // ==========================================

    @Test
    fun `日程表单：编辑单次覆盖只带 occurrenceDate，不带新建日期`() {
        val item = scheduleItem()
        val occurrenceDate = LocalDateTime.of(2026, 5, 8, 0, 0)

        val payload = TimetableFormPagesCatalog.scheduleItemForm(
            scheduleItem = item,
            occurrenceDate = occurrenceDate,
        )

        assertSame(item, payload.scheduleItem)
        assertEquals(occurrenceDate, payload.occurrenceDate)
        assertNull("编辑单次覆盖不该凭空带出新建日期", payload.initialDate)
        assertEquals(ScheduleItemFormMode.EDIT_EXISTING, payload.mode)
        // 干净的编辑调用：校验不报任何问题
        assertTrue(payload.validate().isEmpty())
    }

    @Test
    fun `日程表单：新建只带 initialDate，不带 occurrenceDate`() {
        val initialDate = LocalDateTime.of(2026, 5, 2, 0, 0)

        val payload = TimetableFormPagesCatalog.scheduleItemForm(initialDate = initialDate)

        assertEquals(initialDate, payload.initialDate)
        assertNull("新建不该带 occurrenceDate", payload.occurrenceDate)
        assertNull(payload.scheduleItem)
        assertEquals(ScheduleItemFormMode.CREATE_NEW, payload.mode)
        assertTrue(payload.validate().isEmpty())
    }

    @Test
    fun `日程表单：两个日期入口同时传时原样透传并报校验问题（混用会跳错日子）`() {
        val item = scheduleItem()
        val initialDate = LocalDateTime.of(2026, 5, 2, 0, 0)
        val occurrenceDate = LocalDateTime.of(2026, 5, 8, 0, 0)

        val payload = TimetableFormPagesCatalog.scheduleItemForm(
            scheduleItem = item,
            initialDate = initialDate,
            occurrenceDate = occurrenceDate,
        )

        // 透传语义不变：目录不做改写，只是把两条入口各自带到各自的字段。
        assertSame(item, payload.scheduleItem)
        assertEquals(initialDate, payload.initialDate)
        assertEquals(occurrenceDate, payload.occurrenceDate)

        // 但校验必须报出「两条入口混用」——这是「跳错日子」的根源。
        assertTrue(
            "initialDate 与 occurrenceDate 混用必须被校验抓住，实际 ${payload.validate()}",
            payload.validate().contains(ScheduleItemFormIssue.BOTH_DATE_ENTRIES_SET),
        )
    }

    @Test
    fun `日程表单：编辑态带 initialDate 与无 item 带 occurrenceDate 各报一条校验问题`() {
        val item = scheduleItem()

        val editingWithCreateDate = TimetableFormPagesCatalog.scheduleItemForm(
            scheduleItem = item,
            initialDate = LocalDateTime.of(2026, 5, 2, 0, 0),
        )
        assertTrue(
            editingWithCreateDate.validate().contains(ScheduleItemFormIssue.EDITING_WITH_INITIAL_DATE),
        )

        val occurrenceWithoutItem = TimetableFormPagesCatalog.scheduleItemForm(
            occurrenceDate = LocalDateTime.of(2026, 5, 8, 0, 0),
        )
        assertTrue(
            occurrenceWithoutItem.validate().contains(ScheduleItemFormIssue.OCCURRENCE_WITHOUT_ITEM),
        )
    }

    // ==========================================
    // 4. 作业表单（taskForm）
    // ==========================================

    @Test
    fun `作业表单：task 透传（日视图待办带点一行走这里进编辑页）`() {
        val task = CourseTask(
            id = "t1",
            title = "第三章习题",
            courseId = "c1",
            dueDate = LocalDateTime.of(2026, 6, 15, 0, 0),
            createdAt = LocalDateTime.of(2026, 6, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 6, 1, 0, 0),
        )

        val editing = TimetableFormPagesCatalog.taskForm(task = task)
        // 钉「收到了什么」：只断言「页面打开了」的话，参数在这一层被吞掉也照样绿。
        assertSame("丢了 task，编辑页就是一张空表单", task, editing.task)
        assertEquals(TimetableFormPageType.TASK_FORM, editing.type)
        assertTrue(editing.validate().isEmpty())
    }

    @Test
    fun `作业表单：initialCourse 与 initialWeek 透传，仍是新建而非编辑`() {
        val creating = TimetableFormPagesCatalog.taskForm(
            initialCourse = course,
            initialWeek = 7,
        )

        assertSame(creating.initialCourse, course)
        assertEquals(7, creating.initialWeek)
        assertNull("带着 initialCourse 进来仍是「新建」，不能变成编辑模式", creating.task)
        // 新建预填是合法调用：校验不报问题
        assertTrue(creating.validate().isEmpty())
    }

    @Test
    fun `作业表单：无参调用是新建（三个字段全 null）`() {
        val payload = TimetableFormPagesCatalog.taskForm()

        assertNull(payload.task)
        assertNull(payload.initialCourse)
        assertNull(payload.initialWeek)
    }

    @Test
    fun `作业表单：编辑态带新建预填——透传原样、校验报告（不改写不丢弃）`() {
        val task = CourseTask(
            id = "t1",
            title = "第三章习题",
            createdAt = LocalDateTime.of(2026, 6, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 6, 1, 0, 0),
        )

        val payload = TimetableFormPagesCatalog.taskForm(
            task = task,
            initialCourse = course,
            initialWeek = 7,
        )

        // 传了 task 就是编辑模式：initialCourse / initialWeek 会被页面忽略，
        // 但目录仍原样透传（不静默丢弃），由校验把问题报出来。
        assertSame(task, payload.task)
        assertSame(course, payload.initialCourse)
        assertEquals(7, payload.initialWeek)
        assertEquals(
            listOf(TaskFormIssue.EDITING_WITH_INITIAL_COURSE, TaskFormIssue.EDITING_WITH_INITIAL_WEEK),
            payload.validate(),
        )
    }

    // ==========================================
    // 5. 作息管理页与更新详情页
    // ==========================================

    @Test
    fun `作息管理页：initialEditSchemeId 透传；无参为 null`() {
        val editing = TimetableFormPagesCatalog.timeSchemeManagement(initialEditSchemeId = "scheme-1")
        assertEquals("scheme-1", editing.initialEditSchemeId)
        assertEquals(TimetableFormPageType.TIME_SCHEME_MANAGEMENT, editing.type)

        assertNull(TimetableFormPagesCatalog.timeSchemeManagement().initialEditSchemeId)
    }

    @Test
    fun `更新详情页：packageInfo 必填且原样透传`() {
        val packageInfo = AppPackageInfo(
            appName = "轻屿课表",
            packageName = "com.mutx163.qingyu",
            version = "1.2.3",
            buildNumber = "42",
        )

        val payload = TimetableFormPagesCatalog.aboutUpdate(packageInfo)
        assertSame(packageInfo, payload.packageInfo)
        assertEquals(TimetableFormPageType.ABOUT_UPDATE, payload.type)
    }

    // ==========================================
    // 6. 类型标识与 Dart builder 名一一对应
    // ==========================================

    @Test
    fun `六种表单页的类型标识与 Dart builder 名逐字一致`() {
        assertEquals("courseForm", TimetableFormPageType.COURSE_FORM.id)
        assertEquals("examForm", TimetableFormPageType.EXAM_FORM.id)
        assertEquals("scheduleItemForm", TimetableFormPageType.SCHEDULE_ITEM_FORM.id)
        assertEquals("taskForm", TimetableFormPageType.TASK_FORM.id)
        assertEquals("timeSchemeManagement", TimetableFormPageType.TIME_SCHEME_MANAGEMENT.id)
        assertEquals("aboutUpdate", TimetableFormPageType.ABOUT_UPDATE.id)
        assertEquals(6, TimetableFormPageType.entries.size)
    }
}
