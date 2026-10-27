package com.mutx163.qingyu.pages.guide

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MoreFeaturesModelTest {

    @Test
    fun `全量分组包含规范定义的六大分组`() {
        val groups = MoreFeaturesModel.buildDefaultFeatureGroups(
            activeProfileName = "主课表",
            activeTimeSchemeName = "夏季作息"
        )
        assertEquals(6, groups.size)

        val groupIds = groups.map { it.id }.toSet()
        assertTrue(groupIds.contains("timetable_content"))
        assertTrue(groupIds.contains("timetable_appearance"))
        assertTrue(groupIds.contains("notification_desktop"))
        assertTrue(groupIds.contains("app_preferences"))
        assertTrue(groupIds.contains("data_sync"))
        assertTrue(groupIds.contains("about_support"))

        // 副文本透传验证
        val contentGroup = groups.first { it.id == "timetable_content" }
        val profileItem = contentGroup.items.first { it.id == "profiles" }
        assertEquals("主课表", profileItem.subtitle)

        val timeSchemeItem = contentGroup.items.first { it.id == "timeSchemes" }
        assertEquals("夏季作息", timeSchemeItem.subtitle)
    }

    @Test
    fun `按组名搜索命中整组`() {
        val groups = MoreFeaturesModel.buildDefaultFeatureGroups()
        val filtered = MoreFeaturesModel.filterGroups(groups, "数据")
        // 命中「数据与同步」
        assertTrue(filtered.any { it.id == "data_sync" })
        val syncGroup = filtered.first { it.id == "data_sync" }
        // 整组全部条目均保留
        assertTrue(syncGroup.items.size >= 5)
    }

    @Test
    fun `按条目标题与同义词搜索精准筛选`() {
        val groups = MoreFeaturesModel.buildDefaultFeatureGroups()

        // 搜同义词「换肤」应命中外观编辑与外观设置
        val skinHits = MoreFeaturesModel.filterGroups(groups, "换肤")
        val appearanceGroup = skinHits.firstOrNull { it.id == "timetable_appearance" }
        assertTrue(appearanceGroup != null)
        val hitIds = appearanceGroup!!.items.map { it.id }
        assertTrue(hitIds.contains("appearanceEditor"))
        assertTrue(hitIds.contains("appearanceSettings"))

        // 搜特定条目「考试」
        val examHits = MoreFeaturesModel.filterGroups(groups, "考试")
        val allHitItems = examHits.flatMap { it.items }
        assertTrue(allHitItems.any { it.id == "exams" })

        // 空搜索词应返回全部组
        val allGroups = MoreFeaturesModel.filterGroups(groups, "")
        assertEquals(groups.size, allGroups.size)

        // 搜不存在的词应返回空
        val noHits = MoreFeaturesModel.filterGroups(groups, "xyz123nonexistent")
        assertTrue(noHits.isEmpty())
    }

    @Test
    fun `关键词高亮分段拆分正确`() {
        // 空查询
        val emptyResult = MoreFeaturesModel.highlightText("课程总览", "")
        assertEquals(1, emptyResult.size)
        assertFalse(emptyResult[0].isHighlight)
        assertEquals("课程总览", emptyResult[0].text)

        // 开头命中
        val startResult = MoreFeaturesModel.highlightText("课程总览", "课程")
        assertEquals(2, startResult.size)
        assertTrue(startResult[0].isHighlight)
        assertEquals("课程", startResult[0].text)
        assertFalse(startResult[1].isHighlight)
        assertEquals("总览", startResult[1].text)

        // 中间命中与大小写不敏感
        val midResult = MoreFeaturesModel.highlightText("我的WebDAV配置", "webdav")
        assertEquals(3, midResult.size)
        assertFalse(midResult[0].isHighlight)
        assertEquals("我的", midResult[0].text)
        assertTrue(midResult[1].isHighlight)
        assertEquals("WebDAV", midResult[1].text) // 保留原文大小写
        assertFalse(midResult[2].isHighlight)
        assertEquals("配置", midResult[2].text)

        // 多处重复命中
        val multiResult = MoreFeaturesModel.highlightText("高数与大物高数", "高数")
        assertEquals(3, multiResult.size)
        assertTrue(multiResult[0].isHighlight)
        assertEquals("高数", multiResult[0].text)
        assertFalse(multiResult[1].isHighlight)
        assertEquals("与大物", multiResult[1].text)
        assertTrue(multiResult[2].isHighlight)
        assertEquals("高数", multiResult[2].text)
    }
}
