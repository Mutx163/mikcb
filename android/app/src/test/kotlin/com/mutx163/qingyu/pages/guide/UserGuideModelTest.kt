package com.mutx163.qingyu.pages.guide

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UserGuideModelTest {

    @Test
    fun `权限统计进度计算正确`() {
        val empty = PermissionProgress.calculate(emptyList())
        assertEquals(0, empty.readyCount)
        assertEquals(0, empty.totalCount)
        assertEquals(0f, empty.ratio, 0.001f)

        val items = listOf(
            PermissionItemData("1", "通知", null, true, "已开启", "未开启"),
            PermissionItemData("2", "自启动", null, false, "已开启", "未开启"),
            PermissionItemData("3", "保活", null, true, "已开启", "未开启"),
            PermissionItemData("4", "提示项", null, null, "", "") // 不计入总分
        )
        val progress = PermissionProgress.calculate(items)
        assertEquals(2, progress.readyCount)
        assertEquals(3, progress.totalCount)
        assertEquals(2f / 3f, progress.ratio, 0.001f)
    }

    @Test
    fun `FAQ条目覆盖四大分类且内容完备`() {
        val items = UserGuideModel.defaultFaqItems
        assertTrue("FAQ 条目数不应少于 10 条，当前 ${items.size}", items.size >= 10)

        val categories = items.map { it.category }.toSet()
        assertEquals(
            "应完整覆盖 GuideCategory 的全部 4 个枚举",
            GuideCategory.values().toSet(),
            categories
        )
    }

    @Test
    fun `FAQ分类过滤与关键词检索`() {
        val items = UserGuideModel.defaultFaqItems

        // 纯分类过滤
        val syncItems = UserGuideModel.filterFaq(items, category = GuideCategory.SYNC_AND_BACKUP)
        assertTrue(syncItems.isNotEmpty())
        assertTrue(syncItems.all { it.category == GuideCategory.SYNC_AND_BACKUP })

        // 匹配问题
        val qHits = UserGuideModel.filterFaq(items, query = "超级岛")
        assertTrue(qHits.any { it.id == "faq_island" })

        // 匹配回答内容
        val aHits = UserGuideModel.filterFaq(items, query = "Nextcloud")
        assertTrue(aHits.any { it.id == "faq_webdav" })

        // 匹配关键词标签
        val kHits = UserGuideModel.filterFaq(items, query = "被杀")
        assertTrue(kHits.any { it.id == "faq_autostart" })

        // 大小写不敏感匹配
        val upperHits = UserGuideModel.filterFaq(items, query = "WEBDAV")
        assertTrue(upperHits.any { it.id == "faq_webdav" })

        // 空关键词返回原集
        val allFiltered = UserGuideModel.filterFaq(items, query = "")
        assertEquals(items.size, allFiltered.size)
    }

    @Test
    fun `手风琴展开与折叠状态切换`() {
        var expanded = emptySet<String>()
        assertFalse(UserGuideModel.isExpanded(expanded, "item1"))

        expanded = UserGuideModel.toggleExpanded(expanded, "item1")
        assertTrue(UserGuideModel.isExpanded(expanded, "item1"))

        expanded = UserGuideModel.toggleExpanded(expanded, "item2")
        assertTrue(UserGuideModel.isExpanded(expanded, "item1"))
        assertTrue(UserGuideModel.isExpanded(expanded, "item2"))

        expanded = UserGuideModel.toggleExpanded(expanded, "item1")
        assertFalse(UserGuideModel.isExpanded(expanded, "item1"))
        assertTrue(UserGuideModel.isExpanded(expanded, "item2"))
    }
}
