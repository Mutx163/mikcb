package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 恢复差异概要单测：四类典型场景的计数口径 + 「拿不到就省略」 + 概要行文案。
 *
 * 期望值人推，不抄实现：新增 = 云端独有 id、删除 = 本机独有 id、覆盖 = 同 id 内容不同。
 */
class RestoreDiffLogicTest {

    // ── 测试数据构造 ──

    private fun course(id: String, name: String = "课程$id"): Map<String, Any?> =
        linkedMapOf("id" to id, "name" to name)

    private fun scheme(id: String, rows: Int = 8): Map<String, Any?> =
        linkedMapOf("id" to id, "name" to "作息$id", "rows" to rows)

    private fun profile(id: String, vararg courses: Map<String, Any?>): Map<String, Any?> =
        linkedMapOf("id" to id, "name" to "档案$id", "courses" to courses.toList())

    private fun payload(
        profiles: List<Map<String, Any?>>?,
        timeSchemes: List<Map<String, Any?>>?,
    ): Map<String, Any?> {
        val out = linkedMapOf<String, Any?>(
            "app" to "mikcb",
            "schemaVersion" to 2,
            "backupType" to "sync",
        )
        profiles?.let { out["profiles"] = it }
        timeSchemes?.let { out["timeSchemes"] = it }
        return out
    }

    /** 便捷：把 payload 走一遍编解码，确保与真实读取路径（MiniJson 往返）同构。 */
    private fun decoded(payload: Map<String, Any?>): Map<String, Any?> =
        @Suppress("UNCHECKED_CAST")
        MiniJson.parse(MiniJson.encode(payload)) as Map<String, Any?>

    // ── 场景一：云端空（云端快照三类皆空，本机有数据 → 全记删除） ──

    @Test
    fun `云端空_本机有数据_全部计删除`() {
        val cloud = payload(profiles = emptyList(), timeSchemes = emptyList())
        val local = payload(
            profiles = listOf(profile("p1", course("c1"), course("c2"))),
            timeSchemes = listOf(scheme("t1")),
        )

        val summary = RestoreDiffLogic.summarize(decoded(cloud), decoded(local))

        assertEquals(RestoreDiffCounts(0, 0, 1), summary.profiles)
        assertEquals(RestoreDiffCounts(0, 0, 2), summary.courses)
        assertEquals(RestoreDiffCounts(0, 0, 1), summary.timeSchemes)
    }

    // ── 场景二：本机空（本机没有用户数据 → 全记新增） ──

    @Test
    fun `本机空_云端有数据_全部计新增`() {
        val cloud = payload(
            profiles = listOf(profile("p1", course("c1"), course("c2"), course("c3"))),
            timeSchemes = listOf(scheme("t1")),
        )

        val summary = RestoreDiffLogic.summarize(decoded(cloud), local = null)

        assertEquals(RestoreDiffCounts(1, 0, 0), summary.profiles)
        assertEquals(RestoreDiffCounts(3, 0, 0), summary.courses)
        assertEquals(RestoreDiffCounts(1, 0, 0), summary.timeSchemes)
    }

    // ── 场景三：两边完全相同 → 三类全 0 ──

    @Test
    fun `两边相同_三类全零`() {
        val cloud = payload(
            profiles = listOf(profile("p1", course("c1", "数学"))),
            timeSchemes = listOf(scheme("t1")),
        )
        val local = payload(
            profiles = listOf(profile("p1", course("c1", "数学"))),
            timeSchemes = listOf(scheme("t1")),
        )

        val summary = RestoreDiffLogic.summarize(decoded(cloud), decoded(local))

        assertEquals(RestoreDiffCounts(0, 0, 0), summary.profiles)
        assertEquals(RestoreDiffCounts(0, 0, 0), summary.courses)
        assertEquals(RestoreDiffCounts(0, 0, 0), summary.timeSchemes)
    }

    // ── 场景四：双向差异（新增 / 覆盖 / 删除同时出现，课程跨档案聚合） ──

    @Test
    fun `双向差异_三类同时出现且课程跨档案求和`() {
        val cloud = payload(
            profiles = listOf(
                // p1：覆盖档案（c1 改名 = 覆盖、c2 云端新增、c4 本机独有 = 删除）
                profile("p1", course("c1", "数学（改）"), course("c2")),
                // p2：云端独有档案（c3 整档计新增）
                profile("p2", course("c3")),
            ),
            timeSchemes = listOf(
                scheme("t1", rows = 9),
                scheme("t2"),
            ),
        )
        val local = payload(
            profiles = listOf(
                profile("p1", course("c1", "数学"), course("c4")),
                // p9：本机独有档案（c8 整档计删除）
                profile("p9", course("c8")),
            ),
            timeSchemes = listOf(
                scheme("t1", rows = 8),
                scheme("t3"),
            ),
        )

        val summary = RestoreDiffLogic.summarize(decoded(cloud), decoded(local))

        // 档案：新增 p2、删除 p9、覆盖 p1（内容变了）。
        assertEquals(RestoreDiffCounts(1, 1, 1), summary.profiles)
        // 课程：p1 内 新增 c2 / 覆盖 c1 / 删除 c4；p2 贡献新增 c3；p9 贡献删除 c8。
        assertEquals(RestoreDiffCounts(2, 1, 2), summary.courses)
        // 时间方案：t2 新增、t3 删除、t1 rows 变了 = 覆盖。
        assertEquals(RestoreDiffCounts(1, 1, 1), summary.timeSchemes)
    }

    // ── 如实省略：云端拿不到某类 → 该类为 null，概要行整行省略 ──

    @Test
    fun `云端缺时间方案键_该类省略其余照算`() {
        val cloud = payload(
            profiles = listOf(profile("p1", course("c1"))),
            timeSchemes = null,
        )
        val local = payload(
            profiles = emptyList(),
            timeSchemes = listOf(scheme("t1")),
        )

        val summary = RestoreDiffLogic.summarize(decoded(cloud), decoded(local))

        assertEquals(RestoreDiffCounts(1, 0, 0), summary.profiles)
        assertEquals(RestoreDiffCounts(1, 0, 0), summary.courses)
        assertNull(summary.timeSchemes)
        assertEquals(
            listOf("课表：新增 1、覆盖 0、删除 0", "课程：新增 1、覆盖 0、删除 0"),
            RestoreDiffStrings.buildDiffLines(summary),
        )
    }

    @Test
    fun `云端缺档案键_档案与课程一起省略`() {
        val cloud = payload(profiles = null, timeSchemes = listOf(scheme("t1")))
        val local = payload(profiles = listOf(profile("p1")), timeSchemes = emptyList())

        val summary = RestoreDiffLogic.summarize(decoded(cloud), decoded(local))

        assertNull(summary.profiles)
        assertNull(summary.courses)
        assertEquals(RestoreDiffCounts(1, 0, 0), summary.timeSchemes)
        assertTrue(RestoreDiffStrings.buildDiffLines(summary).size == 1)
    }

    // ── 脏条目：解析不出 id 的不参与计数（与撤销规划器同口径） ──

    @Test
    fun `无id脏条目不参与计数`() {
        val cloud = payload(
            profiles = listOf(linkedMapOf<String, Any?>("name" to "没id"), profile("p1", course("c1"))),
            timeSchemes = listOf(linkedMapOf<String, Any?>("name" to "没id")),
        )
        val local = payload(
            profiles = listOf(linkedMapOf<String, Any?>("name" to "没id")),
            timeSchemes = emptyList(),
        )

        val summary = RestoreDiffLogic.summarize(decoded(cloud), decoded(local))

        assertEquals(RestoreDiffCounts(1, 0, 0), summary.profiles)
        assertEquals(RestoreDiffCounts(1, 0, 0), summary.courses)
        assertEquals(RestoreDiffCounts(0, 0, 0), summary.timeSchemes)
    }

    // ── 概要行文案 ──

    @Test
    fun `概要行按课表课程作息排序且数字如实`() {
        val summary = RestoreDiffSummary(
            profiles = RestoreDiffCounts(1, 2, 3),
            courses = RestoreDiffCounts(4, 5, 6),
            timeSchemes = RestoreDiffCounts(7, 8, 9),
        )

        assertEquals(
            listOf(
                "课表：新增 1、覆盖 2、删除 3",
                "课程：新增 4、覆盖 5、删除 6",
                "作息时间：新增 7、覆盖 8、删除 9",
            ),
            RestoreDiffStrings.buildDiffLines(summary),
        )
    }

    // ── 口径护栏：三类都拿不到时行列表为空（不渲染空概要） ──

    @Test
    fun `三类全拿不到_概要行为空列表`() {
        val summary = RestoreDiffLogic.summarize(
            cloud = payload(profiles = null, timeSchemes = null),
            local = null,
        )
        assertNull(summary.profiles)
        assertNull(summary.courses)
        assertNull(summary.timeSchemes)
        assertTrue(RestoreDiffStrings.buildDiffLines(summary).isEmpty())
    }
}
