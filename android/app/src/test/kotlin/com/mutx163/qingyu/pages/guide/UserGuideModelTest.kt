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

    // ---------------------------------------------------------------- permissionItems

    @Test
    fun `权限行六项的顺序_标题与状态映射`() {
        val state = GuidePermissionState(
            notification = true,
            promotedIsland = false,
            promotedDeclared = false,
            autoStart = true,
            batteryUnrestricted = false,
            keepAliveAccessibility = true,
            doNotDisturbAccess = false,
        )
        val items = UserGuideModel.permissionItems(state)

        assertEquals(6, items.size)
        // id 与 GuidePermissionAction 枚举名一致，渲染层可直接 valueOf
        assertEquals(
            listOf(
                GuidePermissionAction.Notification.name,
                GuidePermissionAction.PromotedIsland.name,
                GuidePermissionAction.AutoStart.name,
                GuidePermissionAction.Battery.name,
                GuidePermissionAction.KeepAliveAccessibility.name,
                GuidePermissionAction.DoNotDisturbAccess.name,
            ),
            items.map { it.id },
        )
        // 标题逐项对齐 GuideStrings
        assertEquals(
            listOf(
                GuideStrings.guideStatusNotificationPermission.zh,
                GuideStrings.guideStatusIslandSupport.zh,
                GuideStrings.quickActionAutoStartTitle.zh,
                GuideStrings.guideStatusBatteryOptimization.zh,
                GuideStrings.guideStatusKeepAlive.zh,
                GuideStrings.guideStatusDoNotDisturbAccess.zh,
            ),
            items.map { it.title },
        )
        // enabled 直接取 state 对应项
        assertEquals(listOf(true, false, true, false, true, false), items.map { it.enabled })
        // 通知行标签
        assertEquals(GuideStrings.guideStatusEnabled.zh, items[0].enabledLabel)
        assertEquals(GuideStrings.guideStatusDisabled.zh, items[0].disabledLabel)
        // 电池行标签跟着电池口径
        assertEquals(GuideStrings.guideStatusBatteryUnrestricted.zh, items[3].enabledLabel)
        assertEquals(GuideStrings.guideStatusBatteryRestricted.zh, items[3].disabledLabel)
        // 只有勿扰行有 subtitle，其余 5 行都必须没有自造副标题
        assertTrue(items.slice(0 until 5).all { it.subtitle == null })
        assertEquals(GuideStrings.guideStatusDoNotDisturbAccessHint.zh, items[5].subtitle)
    }

    @Test
    fun `超级岛未开启文案按是否已声明分两分支`() {
        val notDeclared = UserGuideModel.permissionItems(
            GuidePermissionState(promotedIsland = false, promotedDeclared = false),
        )
        assertEquals(GuideStrings.guideStatusSuggestedCheck.zh, notDeclared[1].disabledLabel)
        assertEquals(GuideStrings.guideStatusSystemAllowed.zh, notDeclared[1].enabledLabel)

        val declared = UserGuideModel.permissionItems(
            GuidePermissionState(promotedIsland = false, promotedDeclared = true),
        )
        assertEquals(GuideStrings.guideStatusEnabledPending.zh, declared[1].disabledLabel)

        val posting = UserGuideModel.permissionItems(
            GuidePermissionState(promotedIsland = true, promotedDeclared = true),
        )
        assertEquals(GuideStrings.guideStatusSystemAllowed.zh, posting[1].enabledLabel)
    }

    @Test
    fun `未知_null_状态不计入权限进度`() {
        // 全未知：6 行 enabled 都是 null，进度总数为 0
        val unknown = UserGuideModel.permissionItems(GuidePermissionState())
        assertEquals(6, unknown.size)
        assertEquals(0, unknown.count { it.enabled != null })
        val p0 = PermissionProgress.calculate(unknown)
        assertEquals(0, p0.totalCount)
        assertEquals(0, p0.readyCount)

        // 只探测了 2 项：进度总数只算这 2 项，其中 1 项已就绪
        val partial = UserGuideModel.permissionItems(
            GuidePermissionState(notification = true, autoStart = false),
        )
        val p1 = PermissionProgress.calculate(partial)
        assertEquals(2, p1.totalCount)
        assertEquals(1, p1.readyCount)
        assertEquals(0.5f, p1.ratio, 0.001f)
    }
}
