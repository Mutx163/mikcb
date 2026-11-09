package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 「课表重新配色」纯逻辑层的 L0 用例。
 *
 * 覆盖四条承诺（其余都是实现细节）：
 * 1. 同名同色：分组键按共享课程名，多条课次共享一色；
 * 2. 种子确定性：同种子 + 同课程列表逐色一致；
 * 3. 永远有路可回：原色快照能恢复手工挑过的颜色，且不动快照里没有的新课；
 * 4. 历史按档案隔离、上限 20、坏数据不拖垮整份历史。
 */
class CourseRecolorLogicTest {

    // ── 分组键 ────────────────────────────────────────────────────────────

    @Test
    fun `分组键按共享课程名归一，忽略首尾空白与大小写`() {
        assertEquals(
            buildCourseRecolorGroupKey(course("1", "  Math  ")),
            buildCourseRecolorGroupKey(course("2", "math")),
        )
        assertFalse(
            buildCourseRecolorGroupKey(course("1", "Math")) ==
                buildCourseRecolorGroupKey(course("2", "Physics")),
        )
    }

    // ── 种子重放 ──────────────────────────────────────────────────────────

    @Test
    fun `同种子同课程列表逐色一致`() {
        val courses = listOf(
            course("1", "数学", color = "#111111"),
            course("2", "物理", color = "#222222"),
            course("3", "英语", color = "#333333"),
        )
        val first = applySeedCourseRecolor(courses, seed = 42, colorGroupId = "all", assignMatchingTextColor = false)
        val second = applySeedCourseRecolor(courses, seed = 42, colorGroupId = "all", assignMatchingTextColor = false)
        assertEquals(first.map { it.color }, second.map { it.color })
        assertEquals(first.map { it.textColor }, second.map { it.textColor })
    }

    @Test
    fun `同名课程共享一色，不同名字不保证不同色但颜色来自所选色板`() {
        val courses = listOf(
            course("1", "数学"),
            course("2", "数学"),
            course("3", "物理"),
        )
        val recolored = applySeedCourseRecolor(
            courses,
            seed = 7,
            colorGroupId = "ocean",
            assignMatchingTextColor = false,
        )
        assertEquals(recolored[0].color, recolored[1].color)
        assertTrue(recolored.map { it.color }.all { it in ImportSharedModel.courseColorGroupPalette("ocean") })
        assertTrue(recolored.all { it.textColor == null })
    }

    @Test
    fun `开启文字色后按亮度配墨`() {
        val recolored = applySeedCourseRecolor(
            listOf(course("1", "数学")),
            seed = 3,
            colorGroupId = "all",
            assignMatchingTextColor = true,
        )
        val textColor = recolored.single().textColor
        assertTrue(textColor == "#1F1F1F" || textColor == "#FFFFFF")
        assertEquals(
            ImportSharedModel.matchingCourseTextColorHex(recolored.single().color),
            textColor,
        )
    }

    // ── 快照与恢复 ────────────────────────────────────────────────────────

    @Test
    fun `快照按同名组取首条颜色，恢复时新课保持原色`() {
        val original = listOf(
            course("1", "数学", color = "#AABBCC", textColor = "#010101"),
            course("2", "数学", color = "#AABBCC", textColor = "#010101"),
            course("3", "物理", color = "#DDEEFF"),
        )
        val snapshot = captureCourseRecolorSnapshot(original, now = NOW)

        val recolored = original.map { it.copy(color = "#123456") }
        val added = course("4", "化学", color = "#654321")
        val restored = applyCourseRecolorScheme(recolored + added, snapshot)

        assertEquals("#AABBCC", restored[0].color)
        assertEquals("#010101", restored[0].textColor)
        assertEquals("#AABBCC", restored[1].color)
        assertEquals("#DDEEFF", restored[2].color)
        assertEquals("#654321", restored[3].color)
    }

    @Test
    fun `空课表快照是空记录，应用后原样返回`() {
        val snapshot = captureCourseRecolorSnapshot(emptyList(), now = NOW)
        assertTrue(snapshot.entries.isEmpty())
        val courses = listOf(course("1", "数学", color = "#123456"))
        assertEquals(courses, applyCourseRecolorScheme(courses, snapshot))
    }

    // ── JSON 契约 ─────────────────────────────────────────────────────────

    @Test
    fun `种子方案与快照方案都能 JSON 往返`() {
        val seed = CourseRecolorScheme.Seed(
            seed = 1234,
            colorGroupId = "pastel",
            assignMatchingTextColor = true,
            createdAt = NOW,
        )
        assertEquals(seed, roundTrip(seed))

        val snapshot = captureCourseRecolorSnapshot(
            listOf(course("1", "数学", color = "#AABBCC", textColor = "#010101")),
            now = NOW,
        )
        assertEquals(snapshot, roundTrip(snapshot))
    }

    @Test
    fun `坏记录整条丢弃，不连坐其它好记录`() {
        assertNull(CourseRecolorScheme.fromJson("not-a-map"))
        assertNull(CourseRecolorScheme.fromJson(mapOf("createdAt" to "not-a-date")))
        assertNull(CourseRecolorScheme.fromJson(mapOf("createdAt" to NOW.toString())))
        // 类型垃圾（seed 是字符串 / 色组是数字）整条丢弃。
        assertNull(
            CourseRecolorScheme.fromJson(
                mapOf("createdAt" to NOW.toString(), "seed" to "42"),
            ),
        )
        assertNull(
            CourseRecolorScheme.fromJson(
                mapOf("createdAt" to NOW.toString(), "seed" to 42, "colorGroupId" to 5),
            ),
        )
        // 快照里的坏条目跳过，但记录本身仍可用。
        val scheme = CourseRecolorScheme.fromJson(
            mapOf(
                "createdAt" to NOW.toString(),
                "snapshot" to mapOf(
                    "name\u0000math" to mapOf("color" to "#AABBCC"),
                    "name\u0000broken" to mapOf("color" to ""),
                ),
            ),
        )
        assertTrue(scheme is CourseRecolorScheme.Snapshot)
        assertEquals(1, (scheme as CourseRecolorScheme.Snapshot).entries.size)
    }

    // ── 历史存储 ──────────────────────────────────────────────────────────

    @Test
    fun `历史往返保留顺序与游标`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        val schemes = listOf(seedScheme(1, minute = 0), seedScheme(2, minute = 1), seedScheme(3, minute = 2))
        assertTrue(store.save(scope = "p1", schemes = schemes, index = 1))

        val loaded = store.load("p1")
        assertEquals(3, loaded.schemes.size)
        assertEquals(1, loaded.index)
        assertTrue(loaded.canGoBack)
        assertTrue(loaded.canGoForward)
        assertEquals(seedScheme(2, minute = 1), loaded.current)
    }

    @Test
    fun `没有游标时默认指向最后一套`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        store.save(scope = "p1", schemes = listOf(seedScheme(1, minute = 0), seedScheme(2, minute = 1)), index = 0)
        // 模拟旧数据 / 坏数据：盘上只有方案、没有游标键。
        disk.remove(store.indexKey("p1"))

        val loaded = store.load("p1")
        assertEquals(1, loaded.index)
        assertEquals(seedScheme(2, minute = 1), loaded.current)
    }

    @Test
    fun `超过 20 套丢最旧并同步前移游标`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        val schemes = (0 until 25).map { seedScheme(it + 1, minute = it) }
        assertTrue(store.save(scope = "p1", schemes = schemes, index = 24))

        val loaded = store.load("p1")
        assertEquals(CourseRecolorHistoryStore.MAX_SCHEMES, loaded.schemes.size)
        assertEquals(19, loaded.index)
        // 丢掉的是最旧 5 套（seed 1..5），现存的头是 seed 6。
        assertEquals(seedScheme(6, minute = 5), loaded.schemes.first())
        assertEquals(seedScheme(25, minute = 24), loaded.schemes.last())
    }

    @Test
    fun `历史按档案作用域隔离`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        store.save(scope = "p1", schemes = listOf(seedScheme(1, minute = 0)), index = 0)
        store.save(scope = "p2", schemes = listOf(seedScheme(2, minute = 1), seedScheme(3, minute = 2)), index = 1)

        assertEquals(1, store.load("p1").schemes.size)
        assertEquals(2, store.load("p2").schemes.size)
        assertEquals(seedScheme(3, minute = 2), store.load("p2").current)
    }

    @Test
    fun `坏 JSON 返回空历史而不是抛异常`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        disk.putString(store.schemesKey("p1"), "{broken")
        assertTrue(store.load("p1").isEmpty)
    }

    @Test
    fun `坏条目跳过，好条目保留`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        val good = seedScheme(9, minute = 0)
        val encoded = MiniJson.encode(
            listOf("garbage", 42, good.toJson()),
        )
        disk.putString(store.schemesKey("p1"), encoded)
        disk.putInt(store.indexKey("p1"), 0)

        val loaded = store.load("p1")
        assertEquals(1, loaded.schemes.size)
        assertEquals(good, loaded.schemes.single())
    }

    @Test
    fun `清空历史时删键`() {
        val disk = InMemoryKeyValueStore()
        val store = CourseRecolorHistoryStore(disk)
        store.save(scope = "p1", schemes = listOf(seedScheme(1, minute = 0)), index = 0)
        assertTrue(store.save(scope = "p1", schemes = emptyList(), index = -1))
        assertTrue(store.load("p1").isEmpty)
        assertNull(disk.getString(store.schemesKey("p1")))
        assertNull(disk.getString(store.indexKey("p1")))
    }

    // ── 工具 ──────────────────────────────────────────────────────────────

    private fun roundTrip(scheme: CourseRecolorScheme): CourseRecolorScheme? {
        val parsed = MiniJson.tryParse(MiniJson.encode(scheme.toJson()))
        return CourseRecolorScheme.fromJson(parsed)
    }

    private fun seedScheme(seed: Int, minute: Int): CourseRecolorScheme.Seed =
        CourseRecolorScheme.Seed(
            seed = seed,
            colorGroupId = "all",
            assignMatchingTextColor = false,
            createdAt = NOW.plusMinutes(minute.toLong()),
        )

    private fun course(
        id: String,
        name: String,
        color: String = "#2196F3",
        textColor: String? = null,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
        textColor = textColor,
    )

    private companion object {
        val NOW: LocalDateTime = LocalDateTime.of(2026, 11, 9, 10, 0)
    }
}
