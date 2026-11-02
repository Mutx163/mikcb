package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.computeContentSha256
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云端恢复撤销「按 id 三向比对」纯逻辑单测（2026-11-02 修「撤销抹掉恢复后的编辑」）。
 *
 * 判据（与局域网 LanTransferUndoLogic 同语义，为云端快照 JSON 单独实现）：
 * - 恢复**新增**的：现在值仍等于恢复后值 → 删除；已被用户改动或已缺失 → 不动；
 * - 恢复**修改**的：现在值仍等于恢复后值 → 写回恢复前值；已被改动 → 不动；
 * - 恢复**删除**的：现在仍缺失 → 写回恢复前条目；用户重建过 → 不动；
 * - 用户恢复后新建的（三份里只有 current 有）：一律保留。
 *
 * 期望值人推：撤销结果必须同时满足「恢复带来的变更被撤掉」与「用户之后的编辑原样
 * 保留」两句话，缺一句就是错的。
 */
class CloudRestoreUndoPlanTest {

    // ---------- 构造工具 ----------

    private fun course(id: String, name: String = "课-$id"): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "teacher" to "",
        "location" to "",
        "dayOfWeek" to 1L,
        "startSection" to 1L,
        "endSection" to 2L,
    )

    private fun profile(
        id: String,
        courses: List<Map<String, Any?>> = emptyList(),
        name: String = "表-$id",
        currentWeek: Long = 1L,
    ): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "courses" to courses,
        "tasks" to emptyList<Any?>(),
        "scheduleItems" to emptyList<Any?>(),
        "exams" to emptyList<Any?>(),
        "settings" to linkedMapOf<String, Any?>("gridRows" to 10L),
        "currentWeek" to currentWeek,
        "createdAt" to "2026-01-01T00:00:00.000",
        "lastUsedAt" to "2026-01-01T00:00:00.000",
        "profileKind" to "normal",
    )

    private fun payload(
        profiles: List<Map<String, Any?>> = emptyList(),
        timeSchemes: List<Map<String, Any?>> = emptyList(),
        settings: Map<String, Any?>? = linkedMapOf("theme" to "blue"),
        activeProfileId: String? = null,
    ): Map<String, Any?> = linkedMapOf(
        "app" to "mikcb",
        "schemaVersion" to 2L,
        "backupType" to "sync",
        "exportedAt" to "2026-03-07T09:05:00.000",
        "deviceId" to "devA",
        "activeProfileId" to activeProfileId,
        "profiles" to profiles,
        "timeSchemes" to timeSchemes,
        "locationTimeGroups" to emptyList<Any?>(),
        "scheduleDateRules" to emptyList<Any?>(),
        "settings" to settings,
    ).apply { put("contentSha256", computeContentSha256(this)) }

    private fun courseIds(payload: Map<String, Any?>, profileId: String): List<String> {
        val profiles = payload["profiles"] as List<*>
        val target = profiles.first { (it as Map<*, *>)["id"] == profileId }
        @Suppress("UNCHECKED_CAST")
        return (target as Map<String, Any?>)["courses"].let { it as List<Map<String, Any?>> }
            .map { it["id"] as String }
    }

    private fun plan(
        before: Map<String, Any?>,
        after: Map<String, Any?>,
        current: Map<String, Any?>,
    ): Map<String, Any?>? =
        CloudRestoreUndoPlanner.planUndoPayload(before, after, current, exportedAtIso = "2026-03-07T10:00:00.000")

    // ---------- 顶层档案级 ----------

    @Test
    fun `恢复新增的档案_未被用户改过_撤销删除`() {
        val before = payload(profiles = listOf(profile("p1")))
        val after = payload(profiles = listOf(profile("p1"), profile("p2")))
        val current = after // 用户什么都没动

        val undo = plan(before, after, current)

        assertNotNull(undo)
        assertEquals(listOf("p1"), (undo!!["profiles"] as List<*>).map { (it as Map<*, *>)["id"] })
    }

    @Test
    fun `恢复新增的档案_被用户改过_保留现状不撤`() {
        val before = payload(profiles = listOf(profile("p1", courses = listOf(course("a")))))
        val after = payload(profiles = listOf(profile("p1", courses = listOf(course("b"))), profile("p2")))
        // p1 未动（可回退），p2 是恢复新增的、但被用户改了名（不可回退）。
        val current = payload(
            profiles = listOf(
                profile("p1", courses = listOf(course("b"))),
                profile("p2", name = "用户改过名"),
            ),
        )

        val undo = plan(before, after, current)

        assertNotNull(undo)
        val p2 = (undo!!["profiles"] as List<*>).first { (it as Map<*, *>)["id"] == "p2" }
        assertEquals("用户改过名的档案必须原样保留", "用户改过名", (p2 as Map<*, *>)["name"])
        assertEquals("p1 未被动过，仍按恢复前写回", listOf("a"), courseIds(undo, "p1"))
    }

    @Test
    fun `恢复删除的档案_当前仍缺失_写回`() {
        val before = payload(profiles = listOf(profile("p1"), profile("pOld")))
        val after = payload(profiles = listOf(profile("p1")))
        val current = after // 恢复把 pOld 删了，用户没重建

        val undo = plan(before, after, current)

        assertNotNull(undo)
        assertEquals(
            setOf("p1", "pOld"),
            (undo!!["profiles"] as List<*>).map { (it as Map<*, *>)["id"] }.toSet(),
        )
    }

    @Test
    fun `恢复删除的档案_用户重建过同id_保留现状`() {
        val before = payload(profiles = listOf(profile("pOld", name = "原名")))
        val after = payload(profiles = emptyList())
        val current = payload(profiles = listOf(profile("pOld", name = "用户重建的")))

        val undo = plan(before, after, current)

        assertNull("唯一被恢复删除的档案已被用户重建，撤销应无事可做", undo)
    }

    // ---------- 档案内部（课程级）：修「撤销抹掉恢复后的编辑」的核心场景 ----------

    @Test
    fun `恢复带入的课程被撤_用户新增的课程保留`() {
        val before = payload(profiles = listOf(profile("p1", courses = listOf(course("a")))))
        val after = payload(profiles = listOf(profile("p1", courses = listOf(course("b")))))
        // 恢复后用户又加了一门课 c
        val current = payload(profiles = listOf(profile("p1", courses = listOf(course("b"), course("c")))))

        val undo = plan(before, after, current)

        assertNotNull(undo)
        val ids = courseIds(undo!!, "p1")
        assertTrue("恢复带入且未被改过的课程必须被撤销", ids.none { it == "b" })
        assertTrue("用户新增的课程必须原样保留", ids.contains("c"))
    }

    @Test
    fun `恢复覆盖的课程_用户没动过_撤销还原恢复前的课`() {
        val before = payload(profiles = listOf(profile("p1", courses = listOf(course("a")))))
        val after = payload(profiles = listOf(profile("p1", courses = listOf(course("b")))))
        val current = after

        val undo = plan(before, after, current)

        assertNotNull(undo)
        assertEquals(listOf("a"), courseIds(undo!!, "p1"))
    }

    @Test
    fun `档案内标量_用户改过周次_不回退`() {
        val before = payload(profiles = listOf(profile("p1", courses = listOf(course("a")))))
        val after = payload(profiles = listOf(profile("p1", courses = listOf(course("b")), currentWeek = 3L)))
        // 恢复把周次改到 3，用户随后改成 5：恢复的改动已不可追溯。
        val current = payload(profiles = listOf(profile("p1", courses = listOf(course("b")), currentWeek = 5L)))

        val undo = plan(before, after, current)

        assertNotNull(undo)
        val p1 = (undo!!["profiles"] as List<*>).single() as Map<*, *>
        assertEquals("用户改过的周次必须保留", 5L, p1["currentWeek"])
        assertEquals("课程级仍未被动过，照常回退", listOf("a"), courseIds(undo, "p1"))
    }

    @Test
    fun `档案内标量_用户没动过_回退恢复前值`() {
        val before = payload(profiles = listOf(profile("p1", currentWeek = 1L)))
        val after = payload(profiles = listOf(profile("p1", currentWeek = 3L)))
        val current = after

        val undo = plan(before, after, current)

        assertNotNull(undo)
        val p1 = (undo!!["profiles"] as List<*>).single() as Map<*, *>
        assertEquals(1L, p1["currentWeek"])
    }

    // ---------- 顶层标量 ----------

    @Test
    fun `顶层settings_仍是恢复后值时回退_被用户改过时保留`() {
        val beforeSettings = linkedMapOf<String, Any?>("theme" to "blue")
        val afterSettings = linkedMapOf<String, Any?>("theme" to "green")
        val before = payload(profiles = listOf(profile("p1", courses = listOf(course("a")))), settings = beforeSettings)
        val after = payload(profiles = listOf(profile("p1", courses = listOf(course("b")))), settings = afterSettings)

        // 用户没动 settings：回退。
        val undoClean = plan(before, after, after)
        assertEquals("blue", (undoClean!!["settings"] as Map<*, *>)["theme"])

        // 用户把 settings 改成别的：保留现状（档案级照常回退）。
        val userSettings = linkedMapOf<String, Any?>("theme" to "red")
        val current = payload(profiles = listOf(profile("p1", courses = listOf(course("b")))), settings = userSettings)
        val undoEdited = plan(before, after, current)
        assertEquals("red", (undoEdited!!["settings"] as Map<*, *>)["theme"])
        assertEquals("settings 被用户改过不影响档案级回退", listOf("a"), courseIds(undoEdited, "p1"))
    }

    // ---------- 整体出口 ----------

    @Test
    fun `恢复没改动任何数据时撤销无事可做`() {
        val same = payload(profiles = listOf(profile("p1")))
        assertNull(plan(same, same, same))
    }

    @Test
    fun `撤销payload的信封与校验和必须过得了应用侧的门`() {
        val before = payload(profiles = listOf(profile("p1", courses = listOf(course("a")))))
        val after = payload(profiles = listOf(profile("p1", courses = listOf(course("b")))))
        val current = payload(
            profiles = listOf(profile("p1", courses = listOf(course("b"), course("c")))),
        )

        val undo = plan(before, after, current)

        assertNotNull(undo)
        val envelope = checkSnapshotEnvelopeAndChecksum(undo!!)
        assertTrue("撤销 payload 必须是合法快照（信封+校验和），实际=${envelope.errorCode}", envelope.isValid)
        assertTrue((undo["profiles"] as List<*>).isNotEmpty())
        assertEquals("导出时间必须换成撤销时刻", "2026-03-07T10:00:00.000", undo["exportedAt"])
    }
}
