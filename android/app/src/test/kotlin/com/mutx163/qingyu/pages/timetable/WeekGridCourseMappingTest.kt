package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * 周视图「课程取数与排版」单测（`WeekGridCourseMapping`）。
 *
 * 期望值全部由 Dart 真源人推，**不抄 Kotlin 实现**：
 * - 取数过滤与排序：`lib/domain/day_course_display_logic.dart:194-223`（`getCoursesForDay`）；
 * - 卡片组装（压盖过滤 + 透明度 + 角标）：`:69-104`（`buildDayCourseDisplayItems`）；
 * - 透明度口径：`:54-63`（`courseDisplayOpacity`），非本周常量 `:31`（0.62）/ `:34`（`#94A3B8`）；
 * - 角标口径：`:147-165`（`resolveCompactOverlineText`）、`:170-189`（`resolveCompactBadgeText`）；
 * - 压盖与「同段只留最近一门」：`:226-234`（`hasCurrentWeekOverlap`）、
 *   `:237-270`（`isPreferredNonCurrentCourse`）、`:273-285`（`distanceToNearestActiveWeek`）；
 * - 稳定排序：`:107-122`（`compareDayCourseDisplayItems`）。
 *
 * 2026-10-29 整份重写：旧版钉的是已删除的「同天重叠按列平分」模型
 * （`TimetableCourse` / `WeekCourseCardModel` / `colIndex` / `totalCols`），
 * Dart 侧从来没有这套东西——课程卡永远占满整列宽度，重叠时后画的压住先画的，
 * 冲突只体现在「透明度 + 左上角小字 + 右上角角标」。
 */
class WeekGridCourseMappingTest {

    // ------------------------------------------------------------------
    // 夹具：Course 字段多，这里只暴露测试关心的那几个
    // ------------------------------------------------------------------

    private fun course(
        id: String,
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        color: String = "#2196F3",
    ): Course = Course(
        id = id,
        name = "课程 $id",
        teacher = "任课教师",
        location = "教学楼 101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:35",
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
    )

    // ------------------------------------------------------------------
    // 1. 非本周课默认不显示
    // ------------------------------------------------------------------

    @Test
    fun `非本周课默认不显示，开会后进入当日列表`() {
        // 第 7 周才开始上的课，看第 5 周：isInWeek(5)=false，hasActiveWeekOnOrAfter(5)=true。
        val future = course(id = "future", startWeek = 7, endWeek = 16)
        val week = 5

        assertEquals(
            "关闭「显示非本周课程」时，非本周课不进当日列表（day_course_display_logic.dart:208-209）",
            emptyList<Course>(),
            WeekGridCourseMapping.coursesForDay(
                allCourses = listOf(future),
                week = week,
                dayOfWeek = 1,
                showNonCurrentWeekCourses = false,
            ),
        )

        assertEquals(
            "开会后第 7 周的课以「非本周」进入第 5 周的当日列表",
            listOf("future"),
            WeekGridCourseMapping.coursesForDay(
                allCourses = listOf(future),
                week = week,
                dayOfWeek = 1,
                showNonCurrentWeekCourses = true,
            ).map { it.id },
        )

        // 整周排版也必须跟着这个开关走（默认 WeekViewStyle.showNonCurrentWeekCourses=false）。
        val defaultStyleMap = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(future),
            week = week,
            style = WeekViewStyle(),
        )
        assertTrue("默认风格下周一不应有任何卡片", defaultStyleMap.getValue(1).isEmpty())
        assertEquals(
            "开会后周一剩一张非本周卡",
            listOf("future"),
            WeekGridCourseMapping.cardsForWeek(
                courses = listOf(future),
                week = week,
                style = WeekViewStyle(showNonCurrentWeekCourses = true),
            ).getValue(1).map { it.course.id },
        )
    }

    // ------------------------------------------------------------------
    // 2. 已结课的非本周课不再显示
    // ------------------------------------------------------------------

    @Test
    fun `已结课的非本周课即使开了开关也不显示`() {
        // 已结课：第 1-4 周，看第 5 周 ⇒ 第 5 周及以后没有任何上课周（Dart :208-209 的
        // hasActiveWeekOnOrAfter 判据；类注释 :193 写明「已结课的课程不再以非本周显示」）。
        val concluded = course(id = "concluded", startWeek = 1, endWeek = 4)
        val upcoming = course(id = "upcoming", startWeek = 7, endWeek = 16)

        assertEquals(
            "只留还有后续上课周的那门",
            listOf("upcoming"),
            WeekGridCourseMapping.coursesForDay(
                allCourses = listOf(concluded, upcoming),
                week = 5,
                dayOfWeek = 1,
                showNonCurrentWeekCourses = true,
            ).map { it.id },
        )

        // 这条判据只住在 getCoursesForDay 里：Dart buildDayCourseDisplayItems 不再重复判
        //（:69-104 只做压盖与「最近一门」），所以手工把已结课塞进 displayCards 仍会被留下。
        // 钉住这个分工，防止以后把过滤搬到 displayCards 里造成双份判据。
        val directCards = WeekGridCourseMapping.displayCards(
            dayCourses = listOf(concluded),
            week = 5,
            style = WeekViewStyle(showNonCurrentWeekCourses = true),
            conflicts = emptyMap(),
        )
        assertEquals("displayCards 不负责「已结课」过滤", listOf("concluded"), directCards.map { it.course.id })
        assertFalse(directCards.single().isCurrentWeek)
    }

    // ------------------------------------------------------------------
    // 3. 被本周课压住的非本周课不显示
    // ------------------------------------------------------------------

    @Test
    fun `被本周课压住的非本周课不显示`() {
        val week = 5
        // 本周课占第 1-2 节；非本周课占第 2-3 节 ⇒ 第 2 节重叠。
        val current = course(id = "current", startSection = 1, endSection = 2, startWeek = 5, endWeek = 16)
        val nonCurrent = course(id = "nonCurrent", startSection = 2, endSection = 3, startWeek = 7, endWeek = 16)

        val dayCourses = WeekGridCourseMapping.coursesForDay(
            allCourses = listOf(current, nonCurrent),
            week = week,
            dayOfWeek = 1,
            showNonCurrentWeekCourses = true,
        )
        // 排序是「开始节次 → 本周课靠后 → 结束节次 → id」（Dart
        // `getCoursesForDay` :209-221）：本周课从第 1 节开始 ⇒ 仍然排在前面，
        // 「本周课靠后」只在**开始节次相同**时起作用。旧期望把它当成第一判据了。
        assertEquals(listOf("current", "nonCurrent"), dayCourses.map { it.id })

        val cards = WeekGridCourseMapping.displayCards(
            dayCourses = dayCourses,
            week = week,
            style = WeekViewStyle(showNonCurrentWeekCourses = true),
            conflicts = WeekGridCourseMapping.conflictMap(listOf(current, nonCurrent), week),
        )
        assertEquals(
            "非本周课被本周课压住 ⇒ 只剩本周那张（Dart :82-85）",
            listOf("current"),
            cards.map { it.course.id },
        )
        // 非本周课不在第 5 周上课 ⇒ 不进本周冲突索引（CourseDomain.buildConflictMap 用
        // isActiveInWeek），所以本周这张不算冲突：不压淡、不标角标。
        assertFalse(cards.single().isConflicting)
        assertEquals(1f, cards.single().opacity, 0.001f)
        assertNull(cards.single().overline)
        assertNull(cards.single().badge)
    }

    // ------------------------------------------------------------------
    // 4. 同时段多门非本周课只留「离本周最近」的那门
    // ------------------------------------------------------------------

    @Test
    fun `同时段多门非本周课只留离本周最近的那门`() {
        val week = 5
        val near = course(id = "near", startWeek = 6, endWeek = 16) // 第 6 周 ⇒ 距离 1
        val far = course(id = "far", startWeek = 9, endWeek = 16) // 第 9 周 ⇒ 距离 4

        assertEquals(1, WeekGridCourseMapping.distanceToNearestActiveWeek(near, week))
        assertEquals(4, WeekGridCourseMapping.distanceToNearestActiveWeek(far, week))

        val cards = WeekGridCourseMapping.displayCards(
            dayCourses = WeekGridCourseMapping.coursesForDay(
                allCourses = listOf(far, near),
                week = week,
                dayOfWeek = 1,
                showNonCurrentWeekCourses = true,
            ),
            week = week,
            style = WeekViewStyle(showNonCurrentWeekCourses = true),
            conflicts = emptyMap(),
        )
        assertEquals("只留最近的那门（Dart :268-269）", listOf("near"), cards.map { it.course.id })
        assertFalse(cards.single().isCurrentWeek)
        assertEquals(0.62f, cards.single().opacity, 0.001f)
    }

    @Test
    fun `非本周课同距时先比起始周、再比结束周、最后比 id`() {
        val week = 5

        // (a) 同距 1 周：一门「往前数到第 4 周」，一门「往后数到第 6 周」。
        //     Dart :251-256 先比 distance、再比 startWeek ⇒ 起始周更早的胜。
        val earlyStart = course(id = "earlyStart", startWeek = 2, endWeek = 8, customWeeks = listOf(4, 7))
        val lateStart = course(id = "lateStart", startWeek = 6, endWeek = 6, customWeeks = listOf(6))
        assertEquals(1, WeekGridCourseMapping.distanceToNearestActiveWeek(earlyStart, week))
        assertEquals(1, WeekGridCourseMapping.distanceToNearestActiveWeek(lateStart, week))
        assertEquals(
            "同距时起始周更早的胜",
            listOf("earlyStart"),
            WeekGridCourseMapping.displayCards(
                dayCourses = WeekGridCourseMapping.coursesForDay(
                    allCourses = listOf(lateStart, earlyStart),
                    week = week,
                    dayOfWeek = 1,
                    showNonCurrentWeekCourses = true,
                ),
                week = week,
                style = WeekViewStyle(showNonCurrentWeekCourses = true),
                conflicts = emptyMap(),
            ).map { it.course.id },
        )

        // (b) 同距 2 周、同起始周：结束周更小的胜（Dart :261-264）。
        val shortRun = course(id = "shortRun", startWeek = 7, endWeek = 10)
        val longRun = course(id = "longRun", startWeek = 7, endWeek = 12)
        assertEquals(2, WeekGridCourseMapping.distanceToNearestActiveWeek(shortRun, week))
        assertEquals(2, WeekGridCourseMapping.distanceToNearestActiveWeek(longRun, week))

        // (c) 起止周完全相同：id 小的胜（Dart :265）。
        val idB = course(id = "b", startWeek = 7, endWeek = 10)
        val idA = course(id = "a", startWeek = 7, endWeek = 10)

        for ((label, courses, expected) in listOf(
            Triple("同距同起始周 ⇒ 结束周小者胜", listOf(longRun, shortRun), "shortRun"),
            Triple("起止周相同 ⇒ id 小者胜", listOf(idB, idA), "a"),
        )) {
            val kept = WeekGridCourseMapping.displayCards(
                dayCourses = WeekGridCourseMapping.coursesForDay(
                    allCourses = courses,
                    week = week,
                    dayOfWeek = 1,
                    showNonCurrentWeekCourses = true,
                ),
                week = week,
                style = WeekViewStyle(showNonCurrentWeekCourses = true),
                conflicts = emptyMap(),
            ).map { it.course.id }
            assertEquals(label, listOf(expected), kept)
        }
    }

    // ------------------------------------------------------------------
    // 5. 透明度
    // ------------------------------------------------------------------

    @Test
    fun `非本周课透明度固定 0-62 且优先于冲突设置值`() {
        // 常量来自 Dart day_course_display_logic.dart:31 / :34。
        assertEquals(0.62f, WeekGridCourseMapping.NON_CURRENT_WEEK_OPACITY, 0.001f)
        assertEquals("#94A3B8", WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX)

        // Dart :59-62：非本周先返回，冲突设置值不参与。
        assertEquals(
            0.62f,
            WeekGridCourseMapping.courseDisplayOpacity(
                isCurrentWeek = false,
                isConflicting = true,
                conflictOpacity = 0.45f,
            ),
            0.001f,
        )
        assertEquals(
            0.45f,
            WeekGridCourseMapping.courseDisplayOpacity(
                isCurrentWeek = true,
                isConflicting = true,
                conflictOpacity = 0.45f,
            ),
            0.001f,
        )
        assertEquals(
            1f,
            WeekGridCourseMapping.courseDisplayOpacity(
                isCurrentWeek = true,
                isConflicting = false,
                conflictOpacity = 0.45f,
            ),
            0.001f,
        )
    }

    @Test
    fun `本周冲突课的透明度取设置里的值`() {
        val week = 3
        val first = course(id = "c1", startSection = 1, endSection = 2)
        val second = course(id = "c2", startSection = 2, endSection = 3)
        val style = WeekViewStyle(conflictCourseOpacity = 0.45f)

        val conflicts = WeekGridCourseMapping.conflictMap(listOf(first, second), week)
        assertEquals(setOf("c2"), conflicts.getValue("c1"))
        assertEquals(setOf("c1"), conflicts.getValue("c2"))

        val cards = WeekGridCourseMapping.displayCards(
            dayCourses = WeekGridCourseMapping.coursesForDay(listOf(first, second), week, 1, false),
            week = week,
            style = style,
            conflicts = conflicts,
        )
        assertEquals(2, cards.size)
        for (card in cards) {
            assertTrue("两门课互相冲突", card.isConflicting)
            assertEquals("冲突课透明度 = 设置值（Dart :62）", 0.45f, card.opacity, 0.001f)
        }
    }

    // ------------------------------------------------------------------
    // 6. 角标优先级与开关
    // ------------------------------------------------------------------

    @Test
    fun `左上角小字优先级是非本周高于冲突`() {
        // Dart :158-163：先判非本周，再看「冲突 + 开关」。
        assertEquals(
            WeekCardOverline.NON_CURRENT_WEEK,
            WeekGridCourseMapping.resolveOverline(
                isCurrentWeek = false,
                isConflicting = true,
                showConflictBadge = true,
            ),
        )
        assertEquals(
            WeekCardOverline.CONFLICT,
            WeekGridCourseMapping.resolveOverline(
                isCurrentWeek = true,
                isConflicting = true,
                showConflictBadge = true,
            ),
        )
        assertNull(
            WeekGridCourseMapping.resolveOverline(
                isCurrentWeek = true,
                isConflicting = false,
                showConflictBadge = true,
            ),
        )
        assertNull(
            "关掉冲突角标开关后连小字也不标（Dart :161）",
            WeekGridCourseMapping.resolveOverline(
                isCurrentWeek = true,
                isConflicting = true,
                showConflictBadge = false,
            ),
        )
    }

    @Test
    fun `右上角角标受冲突开关控制，周视图不标正在上课`() {
        // Dart :176-184 的 parts 里只有「合堂 / 正在上课 / 冲突」；
        // 周网格传的 currentCourseIds 是空集，所以只剩冲突一档。
        assertEquals(WeekCardBadge.CONFLICT, WeekGridCourseMapping.resolveBadge(true, true))
        assertNull(WeekGridCourseMapping.resolveBadge(isConflicting = false, showConflictBadge = true))
        assertNull(WeekGridCourseMapping.resolveBadge(isConflicting = true, showConflictBadge = false))
    }

    @Test
    fun `关掉冲突角标开关后卡面不再标冲突但透明度照旧压淡`() {
        val week = 2
        val first = course(id = "c1", startSection = 1, endSection = 2)
        val second = course(id = "c2", startSection = 1, endSection = 2)
        val style = WeekViewStyle(conflictCourseOpacity = 0.55f, showConflictBadge = false)

        val cards = WeekGridCourseMapping.displayCards(
            dayCourses = WeekGridCourseMapping.coursesForDay(listOf(first, second), week, 1, false),
            week = week,
            style = style,
            conflicts = WeekGridCourseMapping.conflictMap(listOf(first, second), week),
        )
        assertEquals(2, cards.size)
        for (card in cards) {
            assertNull("开关关掉 ⇒ 无左上角小字", card.overline)
            assertNull("开关关掉 ⇒ 无右上角角标", card.badge)
            assertTrue("冲突标记本身仍是 true（只是不画）", card.isConflicting)
            assertEquals("透明度不受角标开关影响", 0.55f, card.opacity, 0.001f)
        }
    }

    // ------------------------------------------------------------------
    // 7. 排序
    // ------------------------------------------------------------------

    @Test
    fun `当日排序是开始节次、本周课靠后、结束节次、id`() {
        val week = 5
        val nonCurrentAtOne = course(id = "z", startSection = 1, endSection = 2, startWeek = 7, endWeek = 16)
        val currentAtOne = course(id = "a", startSection = 1, endSection = 2, startWeek = 5, endWeek = 16)
        val currentEndThree = course(id = "c", startSection = 3, endSection = 3, startWeek = 5, endWeek = 16)
        val currentEndFour = course(id = "b", startSection = 3, endSection = 4, startWeek = 5, endWeek = 16)
        val idY = course(id = "y", startSection = 5, endSection = 6, startWeek = 5, endWeek = 16)
        val idX = course(id = "x", startSection = 5, endSection = 6, startWeek = 5, endWeek = 16)

        val ordered = WeekGridCourseMapping.coursesForDay(
            allCourses = listOf(idY, currentEndFour, nonCurrentAtOne, idX, currentEndThree, currentAtOne),
            week = week,
            dayOfWeek = 1,
            showNonCurrentWeekCourses = true,
        ).map { it.id }

        assertEquals(
            "第 1 节组内非本周(z)在前、本周(a)在后；第 3 节组内结束早(c)在前；" +
                "第 5 节组内按 id(x<y)（Dart :211-221 / :107-122）",
            listOf("z", "a", "c", "b", "x", "y"),
            ordered,
        )

        // 卡片层沿用同一比较器：非本周 z 被本周 a 压掉后，剩下的相对顺序不变。
        val cards = WeekGridCourseMapping.displayCards(
            dayCourses = WeekGridCourseMapping.coursesForDay(
                allCourses = listOf(idY, currentEndFour, nonCurrentAtOne, idX, currentEndThree, currentAtOne),
                week = week,
                dayOfWeek = 1,
                showNonCurrentWeekCourses = true,
            ),
            week = week,
            style = WeekViewStyle(showNonCurrentWeekCourses = true),
            conflicts = emptyMap(),
        )
        assertEquals(listOf("a", "c", "b", "x", "y"), cards.map { it.course.id })
    }

    // ------------------------------------------------------------------
    // 8. 整周按天分组
    // ------------------------------------------------------------------

    @Test
    fun `cardsForWeek 按星期分组且默认给满 7 天`() {
        val courses = listOf(
            course(id = "mon1", dayOfWeek = 1, startSection = 1, endSection = 2),
            course(id = "mon2", dayOfWeek = 1, startSection = 3, endSection = 4),
            course(id = "wed", dayOfWeek = 3, startSection = 1, endSection = 2),
            course(id = "fri", dayOfWeek = 5, startSection = 5, endSection = 6),
        )

        val weekMap = WeekGridCourseMapping.cardsForWeek(courses, week = 1, style = WeekViewStyle())

        assertEquals("默认 7 天全给", setOf(1, 2, 3, 4, 5, 6, 7), weekMap.keys)
        assertEquals(listOf("mon1", "mon2"), weekMap.getValue(1).map { it.course.id })
        assertTrue("周二无课", weekMap.getValue(2).isEmpty())
        assertEquals(listOf("wed"), weekMap.getValue(3).map { it.course.id })
        assertEquals(listOf("fri"), weekMap.getValue(5).map { it.course.id })
        assertTrue("周日无课", weekMap.getValue(7).isEmpty())

        // Dart visibleDayNumbers（timetable_layout.dart:6-10）：隐藏周末时只给 1-5。
        val weekdayOnly = WeekGridCourseMapping.cardsForWeek(
            courses = courses,
            week = 1,
            style = WeekViewStyle(),
            visibleDays = listOf(1, 2, 3, 4, 5),
        )
        assertEquals(listOf(1, 2, 3, 4, 5), weekdayOnly.keys.toList())
    }

    @Test
    fun `统一课卡色透传到每张卡，未开时为空`() {
        val courses = listOf(course(id = "mon", dayOfWeek = 1))
        val plain = WeekGridCourseMapping.cardsForWeek(courses, 1, WeekViewStyle()).getValue(1).single()
        assertNull("未开统一色 ⇒ 渲染层用课程自己的 color", plain.colorHex)

        val unified = WeekGridCourseMapping.cardsForWeek(
            courses,
            1,
            WeekViewStyle(unifiedCardColorHex = "#123456"),
        ).getValue(1).single()
        assertEquals("#123456", unified.colorHex)
    }

    // ------------------------------------------------------------------
    // 9. 卡片派生字段
    // ------------------------------------------------------------------

    @Test
    fun `卡片派生字段取节数并标出停课周`() {
        // 停课周（第 5 周停课）在 Dart 周网格里**仍然算本周课**出现（isInWeek 不看
        // suspendedWeeks，压盖/透明度都按本周算），停课只作为额外标记交给渲染层。
        val suspended = course(
            id = "suspended",
            startSection = 3,
            endSection = 5,
            startWeek = 1,
            endWeek = 16,
            suspendedWeeks = listOf(5),
        )
        val card = WeekGridCourseMapping.displayCards(
            dayCourses = listOf(suspended),
            week = 5,
            style = WeekViewStyle(),
            conflicts = emptyMap(),
        ).single()

        assertEquals("sectionSpan 取课次节数 3..5 ⇒ 3", 3, card.sectionSpan)
        assertTrue(card.isCurrentWeek)
        assertTrue("停课周标记", card.isSuspended)
        assertEquals(1f, card.opacity, 0.001f)

        val notSuspended = WeekGridCourseMapping.displayCards(
            dayCourses = listOf(suspended),
            week = 6,
            style = WeekViewStyle(),
            conflicts = emptyMap(),
        ).single()
        assertFalse("第 6 周没停课", notSuspended.isSuspended)
    }

    @Test
    fun `课卡不再有列平分字段，冲突课各占整列`() {
        // 钉住「没有列平分」这件事：两门完全重叠的本周课都各自是完整一张卡，
        // 模型里不存在 colIndex / totalCols 之类字段，只靠透明度与角标表达冲突。
        val first = course(id = "c1", dayOfWeek = 2, startSection = 5, endSection = 6)
        val second = course(id = "c2", dayOfWeek = 2, startSection = 5, endSection = 6)

        val cards = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(first, second),
            week = 1,
            style = WeekViewStyle(),
        ).getValue(2)

        assertEquals(2, cards.size)
        assertEquals(listOf(2, 2), cards.map { it.sectionSpan })
        assertTrue(cards.all { it.isConflicting })
        assertTrue(cards.all { it.overline == WeekCardOverline.CONFLICT })
        assertTrue(cards.all { it.badge == WeekCardBadge.CONFLICT })
    }

    // ------------------------------------------------------------------
    // 单节课提醒铃铛（Dart `hasReminder`，timetable_day_column.dart:138-145）
    // 数据源：`core/TimetableSettings.classReminders` 换装出来的 `courseId|yyyy-MM-dd`。
    // ------------------------------------------------------------------

    /** 固定开学日 2026-09-07（周一），第 3 周周一 = 2026-09-21。 */
    private val semesterStart: LocalDate = LocalDate.of(2026, 9, 7)

    @Test
    fun `提醒键命中当天才亮铃铛`() {
        val monday = course(id = "c1", dayOfWeek = 1)
        val cards = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(monday),
            week = 3,
            style = WeekViewStyle(),
            visibleDays = listOf(1),
            reminderKeys = setOf("c1|2026-09-21"),
            semesterStartDate = semesterStart,
        )

        assertTrue("第 3 周周一 = 2026-09-21，已设提醒应亮", cards.getValue(1).single().hasReminder)
    }

    @Test
    fun `提醒日期对不上就不亮 也不串到别的周`() {
        val monday = course(id = "c1", dayOfWeek = 1)
        val otherDay = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(monday),
            week = 3,
            style = WeekViewStyle(),
            visibleDays = listOf(1),
            // 同是周一，但日期属于第 2 周（2026-09-14）。
            reminderKeys = setOf("c1|2026-09-14"),
            semesterStartDate = semesterStart,
        )
        assertFalse(otherDay.getValue(1).single().hasReminder)

        val otherCourse = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(course(id = "c2", dayOfWeek = 1)),
            week = 3,
            style = WeekViewStyle(),
            visibleDays = listOf(1),
            reminderKeys = setOf("c1|2026-09-21"),
            semesterStartDate = semesterStart,
        )
        assertFalse("键必须课程 id 也一致", otherCourse.getValue(1).single().hasReminder)
    }

    @Test
    fun `没有提醒数据源或开学日时一律不亮`() {
        val monday = course(id = "c1", dayOfWeek = 1)
        val noData = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(monday),
            week = 3,
            style = WeekViewStyle(),
            visibleDays = listOf(1),
            reminderKeys = null,
            semesterStartDate = semesterStart,
        )
        assertFalse("拿不到提醒数据不是「已设」", noData.getValue(1).single().hasReminder)

        val noCalendar = WeekGridCourseMapping.cardsForWeek(
            courses = listOf(monday),
            week = 3,
            style = WeekViewStyle(),
            visibleDays = listOf(1),
            reminderKeys = setOf("c1|2026-09-21"),
            semesterStartDate = null,
        )
        assertFalse("日期未知时无法匹配真实课次", noCalendar.getValue(1).single().hasReminder)
    }
}
