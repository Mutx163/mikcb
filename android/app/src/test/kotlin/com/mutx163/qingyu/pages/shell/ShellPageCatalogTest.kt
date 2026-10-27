package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 页面目录（[ShellPageCatalog]）的**数据契约**测试。
 *
 * ## 为什么这份目录需要测试
 *
 * 它是索引界面与分派层（`composeUi` 的 `ShellPageIndex.kt`）**共用的唯一真源**：
 * 索引按它渲染行，分派按它的 id 选 Composable。这里一旦出现重复 id、
 * 空标题、或「标了可进入但没写原因就进不去」，用户看到的就是点了没反应——
 * 而这种问题在 Compose 里只能靠人一页页点，测不出来。
 *
 * ## 钉住的是「不许悄悄变少」
 *
 * 总数 82 / 可进入 75 / 暂不可用 6 是照 `docs/plans/2026-10-27-compose-phase3-l4-checklist.md`
 * §2 数出来的。将来真接进去几页，改这里的数字就是**显式决定**（并同步改清单），
 * 而不是某次重构顺手掉两页、没人发现。
 */
class ShellPageCatalogTest {

    @Test
    fun `总数与四档合计对得上`() {
        assertEquals("目录总条数", 82, ShellPageCatalog.totalCount)

        val sum = ShellPageDataKind.entries.sumOf { ShellPageCatalog.countOf(it) }
        assertEquals("四档数量之和必须等于总数（kind 不许漏档）", ShellPageCatalog.totalCount, sum)
    }

    @Test
    fun `可进入与不可用的数量`() {
        assertEquals("可进入条数", 75, ShellPageCatalog.openable.size)
        assertEquals("暂不可用条数", 6, ShellPageCatalog.countOf(ShellPageDataKind.UNAVAILABLE))
        assertEquals("常驻条数（底部玻璃坞自身）", 1, ShellPageCatalog.countOf(ShellPageDataKind.ALWAYS_VISIBLE))
    }

    @Test
    fun `id 全局唯一`() {
        val duplicated = ShellPageCatalog.all
            .groupBy { it.id }
            .filterValues { it.size > 1 }
            .keys
        assertTrue("重复 id 会让点击落到错误的页面：$duplicated", duplicated.isEmpty())
    }

    @Test
    fun `每条都有非空标题且无首尾空白`() {
        ShellPageCatalog.all.forEach { entry ->
            assertTrue("${entry.id} 标题为空", entry.title.isNotBlank())
            assertEquals("${entry.id} 标题带首尾空白（会导致行看起来没对齐）", entry.title.trim(), entry.title)
        }
    }

    @Test
    fun `id 前缀与所属批次一致`() {
        ShellPageCatalog.batches.forEach { batch ->
            val expectedPrefix = batch.code.lowercase().removePrefix("p3-")
            batch.pages.forEach { entry ->
                assertTrue(
                    "${entry.id} 不属于批次 ${batch.code}（期望前缀 $expectedPrefix.）",
                    entry.id.startsWith("$expectedPrefix."),
                )
            }
        }
    }

    @Test
    fun `批次编号唯一且每批都有页`() {
        val codes = ShellPageCatalog.batches.map { it.code }
        assertEquals("批次编号重复", codes.size, codes.toSet().size)
        ShellPageCatalog.batches.forEach { batch ->
            assertTrue("批次 ${batch.code} 是空的", batch.pages.isNotEmpty())
            assertTrue("批次 ${batch.code} 缺标题", batch.title.isNotBlank())
        }
    }

    @Test
    fun `进不去的每一条都写了原因`() {
        ShellPageCatalog.all
            .filter { it.kind == ShellPageDataKind.UNAVAILABLE || it.kind == ShellPageDataKind.ALWAYS_VISIBLE }
            .forEach { entry ->
                // 「暂不可用」不写原因等于把「缺什么」这件事丢了，下一批人得重新查一遍。
                assertNotNull("${entry.id} 标了进不去却没写原因", entry.note)
                assertTrue("${entry.id} 的原因太短，说不清缺什么：${entry.note}", (entry.note?.length ?: 0) >= 8)
            }
    }

    @Test
    fun `每条不可用都带可反查的分类`() {
        val unavailable = ShellPageCatalog.all.filter { it.kind == ShellPageDataKind.UNAVAILABLE }
        assertEquals("不可用条数变了就要同步改这条断言与 L4 清单", 6, unavailable.size)

        unavailable.forEach { entry ->
            // 分类不是给人看的形容词，是机器可判的字段：将来补了依赖/槽位，
            // 按 blockedBy 一筛就知道该放开哪几条，不用重读六句话。
            val reason = entry.blockedBy
            assertNotNull("${entry.id} 没有 blockedBy，无法反查该补什么", reason)

            val label = reason!!.label
            assertTrue(
                "${entry.id} 的原因必须以分类标签「$label」开头（分类与文字不许各说各的）：${entry.note}",
                entry.note?.startsWith(label) == true,
            )
        }

        // 反向：能进去的页面不许挂「缺什么」——挂了说明有人改了 kind 忘了清字段。
        ShellPageCatalog.all
            .filter { it.isOpenable }
            .forEach { entry ->
                assertNull("${entry.id} 可进入却标了 blockedBy=${entry.blockedBy}", entry.blockedBy)
            }
    }

    @Test
    fun `六条不可用的分类清单`() {
        // 这张表就是「将来补了东西该放开哪条」的反查依据。每放开一条都应当是显式改动：
        // 补了整页渲染层 → 从第一行划掉；补了二维码/相机 → 从第二行划掉。
        val byReason = ShellPageCatalog.all
            .filter { it.kind == ShellPageDataKind.UNAVAILABLE }
            .groupBy({ it.blockedBy }, { it.id })

        assertEquals(
            "缺整页渲染层",
            setOf("a.changelog", "b.timetablePage", "j.keepAlive"),
            byReason[ShellBlockReason.MISSING_RENDERER]?.toSet(),
        )
        assertEquals(
            "缺宿主槽位",
            setOf("g3.qrSend", "g3.qrScan"),
            byReason[ShellBlockReason.MISSING_HOST_SLOT]?.toSet(),
        )
        assertEquals(
            "缺宿主数据（页面已写好，只差壳侧喂数据）",
            setOf("c2.month"),
            byReason[ShellBlockReason.MISSING_HOST_DATA]?.toSet(),
        )
        assertNull("本轮没有单纯缺库的条目；真有的话在这里登记", byReason[ShellBlockReason.MISSING_DEPENDENCY])
    }

    @Test
    fun `行尾短标签与分档一一对应`() {
        // DIRECT 不贴标签（正常页面不需要解释）；其余三档必须各有自己的短标签且互不相同。
        assertNull("可直连的页面不该贴标签", ShellPageCatalog.badgeOf(ShellPageDataKind.DIRECT))

        val labels = listOf(
            ShellPageDataKind.DEMO,
            ShellPageDataKind.UNAVAILABLE,
            ShellPageDataKind.ALWAYS_VISIBLE,
        ).map { ShellPageCatalog.badgeOf(it) }

        labels.forEach { assertTrue("标签不能为空", !it.isNullOrBlank()) }
        assertEquals("三档标签不许重名（否则用户分不清是演示数据还是进不去）", 3, labels.toSet().size)
    }

    @Test
    fun `可点判据只有直连与演示数据两档`() {
        assertEquals(75, ShellPageCatalog.all.count { it.isOpenable })

        val clickable = ShellPageCatalog.all.filter { it.isOpenable }
        assertTrue(
            "可点的只能是 DIRECT 或 DEMO",
            clickable.all { it.kind == ShellPageDataKind.DIRECT || it.kind == ShellPageDataKind.DEMO },
        )

        val notClickable = ShellPageCatalog.all.filterNot { it.isOpenable }
        assertTrue(
            "UNAVAILABLE / ALWAYS_VISIBLE 一条都不许可点（点了没反应比不给入口更糟）",
            notClickable.isNotEmpty() &&
                notClickable.all {
                    it.kind == ShellPageDataKind.UNAVAILABLE || it.kind == ShellPageDataKind.ALWAYS_VISIBLE
                },
        )
    }

    @Test
    fun `find 能按 id 取回同一条`() {
        ShellPageCatalog.all.forEach { entry ->
            assertEquals(entry, ShellPageCatalog.find(entry.id))
        }
        assertNull("不存在的 id 必须返回 null，而不是随便给一条", ShellPageCatalog.find("nope.missing"))
    }

    @Test
    fun `展平顺序等于批次顺序`() {
        val expected = ShellPageCatalog.batches.flatMap { it.pages }
        assertEquals("索引按声明顺序渲染，展平顺序必须一致", expected, ShellPageCatalog.all)
    }
}
