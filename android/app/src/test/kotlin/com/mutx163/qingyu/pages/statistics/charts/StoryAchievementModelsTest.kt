package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.Achievement
import com.mutx163.qingyu.statistics.CourseNatureStats
import com.mutx163.qingyu.statistics.DataStory
import com.mutx163.qingyu.statistics.SemesterStats
import com.mutx163.qingyu.statistics.StoryType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

private fun semesterStats(
    totalCourses: Int = 8,
    totalSections: Int = 192,
    totalWeeks: Int = 20,
    longestStreak: Int = 5,
) = SemesterStats(
    totalCourses = totalCourses,
    totalSections = totalSections,
    totalWeeks = totalWeeks,
    longestStreak = longestStreak,
    dailyAverages = emptyList(),
    natureStats = CourseNatureStats(0, 0, 0, 0),
    courseRanking = emptyList(),
)

class OverviewModelTest {

    @Test
    fun `四格读数是 门课程 节课 周 天连续`() {
        val cells = OverviewModel.cells(semesterStats())
        assertEquals(4, cells.size)
        assertEquals(listOf("8", "192", "20", "5"), cells.map { it.value })
        assertEquals(
            listOf("门课程", "节课", "周", "天连续"),
            cells.map { it.label },
        )
        // 只有首格高亮
        assertEquals(listOf(true, false, false, false), cells.map { it.highlight })
    }

    @Test
    fun `没有课程时整块不显示`() {
        assertEquals(0, OverviewModel.cells(semesterStats(totalCourses = 0)).size)
    }
}

class DataStoryModelTest {

    @Test
    fun `星号片段被拆成普通段与加粗段`() {
        assertEquals(
            listOf(
                RichSegment("只有 ", false),
                RichSegment("两项", true),
                RichSegment(" 数据", false),
            ),
            DataStoryModel.richSegments("只有 **两项** 数据"),
        )
        // 整句加粗
        assertEquals(listOf(RichSegment("全加粗", true)), DataStoryModel.richSegments("**全加粗**"))
        // 没有星号：整句一个普通段
        assertEquals(listOf(RichSegment("无星号", false)), DataStoryModel.richSegments("无星号"))
        // 空串：不铺任何片段
        assertEquals(0, DataStoryModel.richSegments("").size)
        // 落单的 **（不成对）：原样留在普通段里，不吞字
        assertEquals(listOf(RichSegment("落单 ** 星号", false)), DataStoryModel.richSegments("落单 ** 星号"))
        // 两对星号
        assertEquals(
            listOf(
                RichSegment("a ", false),
                RichSegment("b", true),
                RichSegment(" c ", false),
                RichSegment("d", true),
            ),
            DataStoryModel.richSegments("a **b** c **d**"),
        )
    }

    @Test
    fun `最忙的一天正文按 ARB 模板拼`() {
        val story = DataStory(
            type = StoryType.BUSIEST_DAY,
            dayOfWeek = 3,
            weekNumber = 8,
            averageSections = 4.5,
        )
        assertEquals(
            "截至第 8 周，这学期你最忙的一天是 **周三**，平均 **4.5** 节课",
            DataStoryModel.content(story),
        )
        assertEquals("最忙的一天", DataStoryModel.title(StoryType.BUSIEST_DAY))
        assertEquals(StoryTone.RED, DataStoryModel.tone(StoryType.BUSIEST_DAY))
    }

    @Test
    fun `最常去的教室与教学楼探险正文`() {
        val room = DataStory(
            type = StoryType.FAVORITE_ROOM,
            weekNumber = 8,
            room = "A101",
            visitCount = 5,
        )
        assertEquals(
            "截至第 8 周，你最常去的教室是 **A101**，共去了 **5** 次",
            DataStoryModel.content(room),
        )
        val building = DataStory(type = StoryType.BUILDING_COUNT, weekNumber = 8, buildingCount = 3)
        assertEquals(
            "截至第 8 周，你的课程分布在 **3** 栋不同的教学楼",
            DataStoryModel.content(building),
        )
    }

    @Test
    fun `时间跨度正文只填空缺字段原样留空`() {
        val story = DataStory(
            type = StoryType.TIME_RANGE,
            earliestTime = "08:00",
            latestTime = "18:30",
        )
        assertEquals("你最早的课是 **08:00**，最晚的课是 **18:30**", DataStoryModel.content(story))
        assertEquals(StoryTone.ORANGE, DataStoryModel.tone(StoryType.TIME_RANGE))
    }

    @Test
    fun `缺字段时兜底与 Dart 完全一致`() {
        // 周次缺省 0、星期与平均课时为空串 → 模板里的 **{x}** 变成 ****（空加粗段）。
        // 这是 Dart 原行为（`?? 0` / `?? ''`），不要"顺手修漂亮"
        val story = DataStory(type = StoryType.BUSIEST_DAY)
        assertEquals(
            "截至第 0 周，这学期你最忙的一天是 ****，平均 **** 节课",
            DataStoryModel.content(story),
        )
        // 渲染成屏上是「是 ，平均  节课」（空加粗段不占宽）
        val segments = DataStoryModel.richSegments(DataStoryModel.content(story))
        assertEquals(5, segments.size)
        assertEquals(RichSegment("", true), segments[1])
    }

    @Test
    fun `五种故事的标题与语义色`() {
        assertEquals("最轻松的一天", DataStoryModel.title(StoryType.LIGHTEST_DAY))
        assertEquals("最常去的教室", DataStoryModel.title(StoryType.FAVORITE_ROOM))
        assertEquals("教学楼探险", DataStoryModel.title(StoryType.BUILDING_COUNT))
        assertEquals("时间跨度", DataStoryModel.title(StoryType.TIME_RANGE))
        assertEquals(StoryTone.TEAL, DataStoryModel.tone(StoryType.LIGHTEST_DAY))
        assertEquals(StoryTone.BLUE, DataStoryModel.tone(StoryType.FAVORITE_ROOM))
        assertEquals(StoryTone.PURPLE, DataStoryModel.tone(StoryType.BUILDING_COUNT))
    }

    @Test
    fun `列表按传入顺序逐条转换`() {
        val items = DataStoryModel.items(
            listOf(
                DataStory(type = StoryType.BUSIEST_DAY, dayOfWeek = 1, weekNumber = 3, averageSections = 6.0),
                DataStory(type = StoryType.TIME_RANGE, earliestTime = "08:00", latestTime = "18:00"),
            ),
        )
        assertEquals(2, items.size)
        assertEquals("最忙的一天", items[0].title)
        assertEquals("时间跨度", items[1].title)
        // 分段已解析好（正文含加粗片段）
        assertEquals(true, items[0].segments.any { it.bold })
    }
}

class AchievementModelTest {

    @Test
    fun `已解锁优先显示已达成 而不是进度数字`() {
        val unlocked = Achievement(
            id = "scholar",
            isUnlocked = true,
            progressCurrent = 100,
            progressTarget = 100,
        )
        val model = AchievementModel.badge(unlocked)
        assertEquals("学霸", model.name)
        assertEquals("总课时 ≥ 100", model.description)
        assertEquals(true, model.unlocked)
        assertEquals("已达成", model.progressLabel)
        assertEquals(1.0, model.progressFraction, 1e-9)
        assertEquals(AchievementAccent.BLUE, model.accent)
    }

    @Test
    fun `未解锁显示当前进度`() {
        val locked = Achievement(
            id = "scholar",
            isUnlocked = false,
            progressCurrent = 86,
            progressTarget = 100,
        )
        val model = AchievementModel.badge(locked)
        assertEquals("86/100", model.progressLabel)
        assertEquals(0.86, model.progressFraction, 1e-9)
    }

    @Test
    fun `越小越好的成就未解锁时不显示反向前进`() {
        for (id in listOf("balanced", "gap_master")) {
            val model = AchievementModel.badge(
                Achievement(id = id, isUnlocked = false, progressCurrent = 6, progressTarget = 2),
            )
            assertNull("$id 不应显示 6/2", model.progressLabel)
            assertEquals("$id 不应画满进度条", 0.0, model.progressFraction, 1e-9)
        }
    }

    @Test
    fun `没有进度信息时整行不显示`() {
        val model = AchievementModel.badge(Achievement(id = "weekend_warrior", isUnlocked = true))
        assertNull(model.progressLabel)
        assertEquals(0.0, model.progressFraction, 1e-9)
        assertEquals("周末战士", model.name)
    }

    @Test
    fun `目标为零不除零`() {
        val model = AchievementModel.badge(
            Achievement(id = "scholar", isUnlocked = false, progressCurrent = 5, progressTarget = 0),
        )
        // hasProgress 要求 target > 0，所以这里根本不算进度
        assertNull(model.progressLabel)
        assertEquals(0.0, model.progressFraction, 1e-9)
    }

    @Test
    fun `十二个成就的语义色映射与未知回退`() {
        assertEquals(AchievementAccent.ORANGE, AchievementModel.accentOf("early_bird"))
        assertEquals(AchievementAccent.GREEN, AchievementModel.accentOf("perfect_attendance"))
        assertEquals(AchievementAccent.PURPLE, AchievementModel.accentOf("weekend_warrior"))
        assertEquals(AchievementAccent.YELLOW, AchievementModel.accentOf("class_king"))
        assertEquals(AchievementAccent.BLUE, AchievementModel.accentOf("scholar"))
        assertEquals(AchievementAccent.TEAL, AchievementModel.accentOf("balanced"))
        assertEquals(AchievementAccent.INDIGO, AchievementModel.accentOf("night_owl"))
        assertEquals(AchievementAccent.CYAN, AchievementModel.accentOf("explorer"))
        assertEquals(AchievementAccent.RED, AchievementModel.accentOf("full_day_king"))
        assertEquals(AchievementAccent.GREEN, AchievementModel.accentOf("building_hopper"))
        assertEquals(AchievementAccent.YELLOW, AchievementModel.accentOf("morning_person"))
        assertEquals(AchievementAccent.CYAN, AchievementModel.accentOf("gap_master"))
        // 未知 id 回落蓝色（Dart `_ => blue`）
        assertEquals(AchievementAccent.BLUE, AchievementModel.accentOf("nope"))
    }

    @Test
    fun `勋章尺寸与锁定态透明度照抄 Dart`() {
        assertEquals(36f, AchievementModel.MEDAL_SIZE_DP, 1e-4f)
        assertEquals(12f, AchievementModel.MEDAL_RADIUS_DP, 1e-4f)
        assertEquals(0.14f, AchievementModel.LOCKED_FILL_LIGHT, 1e-4f)
        assertEquals(0.26f, AchievementModel.LOCKED_FILL_DARK, 1e-4f)
        assertEquals(0.28f, AchievementModel.LOCKED_BORDER_LIGHT, 1e-4f)
        assertEquals(0.44f, AchievementModel.LOCKED_BORDER_DARK, 1e-4f)
        assertEquals(0.55f, AchievementModel.LOCKED_ICON_LIGHT, 1e-4f)
        assertEquals(0.86f, AchievementModel.LOCKED_ICON_DARK, 1e-4f)
    }
}
