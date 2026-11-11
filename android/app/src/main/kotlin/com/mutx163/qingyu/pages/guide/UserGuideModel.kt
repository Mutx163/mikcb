package com.mutx163.qingyu.pages.guide

/**
 * 权限项数据模型。
 */
data class PermissionItemData(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val enabled: Boolean?,
    val enabledLabel: String,
    val disabledLabel: String
)

/**
 * 权限就绪统计。
 */
data class PermissionProgress(
    val readyCount: Int,
    val totalCount: Int,
    val ratio: Float
) {
    companion object {
        fun calculate(items: List<PermissionItemData>): PermissionProgress {
            val countable = items.filter { it.enabled != null }
            val ready = countable.count { it.enabled == true }
            val total = countable.size
            val ratio = if (total > 0) ready.toFloat() / total.toFloat() else 0f
            return PermissionProgress(ready, total, ratio)
        }
    }
}

/**
 * 用户指南问答分类。
 */
enum class GuideCategory(val label: String) {
    PERMISSIONS_KEEP_ALIVE("权限与保活"),
    COURSE_AND_IMPORT("课程与导入"),
    APPEARANCE_AND_DESKTOP("外观与桌面"),
    SYNC_AND_BACKUP("数据与备份")
}

/**
 * 指南与问答条目数据模型。
 */
data class UserGuideFaqItem(
    val id: String,
    val category: GuideCategory,
    val question: String,
    val answer: String,
    val keywords: List<String> = emptyList()
)

/**
 * 用户指南问答领域模型与仓库。
 */
object UserGuideModel {

    /**
     * 把真实权限状态 [state] 映射成权限页要渲染的 6 行。
     *
     * 口径完全对齐 Flutter 原版 `lib/screens/user_guide_screen.dart:640-704` 的
     * `_buildPermissionItems`：
     * - 行顺序固定：通知 / 超级岛 / 自启动 / 电池 / 保活 / 勿扰；
     * - `enabled` 直接取 state 对应项（**可 null = 还没探测**，进度条会把它排除在总数外）；
     * - 只有「勿扰」行有 subtitle（`guideStatusDoNotDisturbAccessHint`），其余 5 行无副标题；
     * - 超级岛的“未开启”文案依赖 `promotedDeclared`：已声明 → 已开启待生效，未声明 → 建议检查。
     *
     * [PermissionItemData.id] 采用**与 [GuidePermissionAction] 枚举名一致的字符串**，
     * 渲染层可直接 `GuidePermissionAction.valueOf(item.id)` 拿到点击要发的动作。
     */
    fun permissionItems(state: GuidePermissionState): List<PermissionItemData> {
        val enabledLabel = GuideStrings.guideStatusEnabled.text
        val disabledLabel = GuideStrings.guideStatusDisabled.text
        return listOf(
            PermissionItemData(
                id = GuidePermissionAction.Notification.name,
                title = GuideStrings.guideStatusNotificationPermission.text,
                subtitle = null,
                enabled = state.notification,
                enabledLabel = GuideStrings.guideStatusEnabled.text,
                disabledLabel = GuideStrings.guideStatusDisabled.text,
            ),
            PermissionItemData(
                id = GuidePermissionAction.PromotedIsland.name,
                title = GuideStrings.guideStatusIslandSupport.text,
                subtitle = null,
                enabled = state.promotedIsland,
                enabledLabel = GuideStrings.guideStatusSystemAllowed.text,
                disabledLabel = if (state.promotedDeclared) {
                    GuideStrings.guideStatusEnabledPending.text
                } else {
                    GuideStrings.guideStatusSuggestedCheck.text
                },
            ),
            PermissionItemData(
                id = GuidePermissionAction.AutoStart.name,
                title = GuideStrings.quickActionAutoStartTitle.text,
                subtitle = null,
                enabled = state.autoStart,
                enabledLabel = enabledLabel,
                disabledLabel = disabledLabel,
            ),
            PermissionItemData(
                id = GuidePermissionAction.Battery.name,
                title = GuideStrings.guideStatusBatteryOptimization.text,
                subtitle = null,
                enabled = state.batteryUnrestricted,
                enabledLabel = GuideStrings.guideStatusBatteryUnrestricted.text,
                disabledLabel = GuideStrings.guideStatusBatteryRestricted.text,
            ),
            PermissionItemData(
                id = GuidePermissionAction.KeepAliveAccessibility.name,
                title = GuideStrings.guideStatusKeepAlive.text,
                subtitle = null,
                enabled = state.keepAliveAccessibility,
                enabledLabel = enabledLabel,
                disabledLabel = disabledLabel,
            ),
            PermissionItemData(
                id = GuidePermissionAction.DoNotDisturbAccess.name,
                title = GuideStrings.guideStatusDoNotDisturbAccess.text,
                subtitle = GuideStrings.guideStatusDoNotDisturbAccessHint.text,
                enabled = state.doNotDisturbAccess,
                enabledLabel = enabledLabel,
                disabledLabel = disabledLabel,
            ),
        )
    }

    /** 内置常见问答清单 */
    val defaultFaqItems: List<UserGuideFaqItem> = listOf(
        UserGuideFaqItem(
            id = "faq_notification",
            category = GuideCategory.PERMISSIONS_KEEP_ALIVE,
            question = "为什么通知栏或锁屏不显示课前提醒？",
            answer = "请在系统设置中确认已开启应用通知权限，并将电池策略设置为「无限制」以防止系统后台冻结。",
            keywords = listOf("通知", "提醒", "不响", "静音", "漏报")
        ),
        UserGuideFaqItem(
            id = "faq_island",
            category = GuideCategory.PERMISSIONS_KEEP_ALIVE,
            question = "小米澎湃 HyperOS 超级岛 / 焦点通知如何开启？",
            answer = "需 HyperOS 3.0.300 及以上系统支持，在系统「通知与控制中心 → 焦点通知」中允许轻屿课表发送焦点通知。",
            keywords = listOf("超级岛", "灵动岛", "焦点通知", "HyperOS", "锁屏")
        ),
        UserGuideFaqItem(
            id = "faq_autostart",
            category = GuideCategory.PERMISSIONS_KEEP_ALIVE,
            question = "开启自启动与后台保活有什么作用？",
            answer = "自启动权限确保手机重启后能自动加载当天的课表定时任务，后台保活避免切换多任务时服务被系统休眠清理。",
            keywords = listOf("自启动", "后台", "保活", "常驻", "被杀")
        ),
        UserGuideFaqItem(
            id = "faq_dnd",
            category = GuideCategory.PERMISSIONS_KEEP_ALIVE,
            question = "课前勿扰模式访问权限的作用是什么？",
            answer = "该权限允许课前通知上的快捷静音/免打扰按钮直接生效，未授权时点击静音按钮系统将拦截操作。",
            keywords = listOf("勿扰", "免打扰", "静音", "课前静音")
        ),
        UserGuideFaqItem(
            id = "faq_web_import",
            category = GuideCategory.COURSE_AND_IMPORT,
            question = "教务系统网页登录导入失败怎么办？",
            answer = "部分高校在校园网外需挂 VPN 或在内网环境访问。若出现验证码加载失败，可在导入页面选择「自定义调试」或联系仓库维护者适配。",
            keywords = listOf("导入", "教务", "登录", "验证码", "失败", "VPN")
        ),
        UserGuideFaqItem(
            id = "faq_short_name",
            category = GuideCategory.COURSE_AND_IMPORT,
            question = "如何设置课程简称以优化周视图排版？",
            answer = "在「课程总览」中点击课程编辑简称（建议 2~4 个字，如「高等数学」设为「高数」），周视图格子可完整展示而不被省略截断。",
            keywords = listOf("简称", "周视图", "截断", "换行", "排版")
        ),
        UserGuideFaqItem(
            id = "faq_semester_week",
            category = GuideCategory.COURSE_AND_IMPORT,
            question = "课表周次与学校校历不一致怎么调整？",
            answer = "在课表设置中修改「开学日期」或「同步当前周」，周次计算会自动以开学那周的周一为校历第 1 周进行对齐。",
            keywords = listOf("周次", "校历", "不对", "单双周", "开学日期")
        ),
        UserGuideFaqItem(
            id = "faq_glass_mode",
            category = GuideCategory.APPEARANCE_AND_DESKTOP,
            question = "液态玻璃与实体纯色材质有什么区别？",
            answer = "液态玻璃支持跟随背景壁纸进行实时高斯模糊与折射流动效果；实体纯色卡片则不采集壁纸，省电清晰、对比度最高。",
            keywords = listOf("液态玻璃", "材质", "模糊", "纯色", "壁纸", "耗电")
        ),
        UserGuideFaqItem(
            id = "faq_widget_update",
            category = GuideCategory.APPEARANCE_AND_DESKTOP,
            question = "桌面小部件课表不更新或空白怎么办？",
            answer = "这是 MIUI / HyperOS 负一屏与桌面的小部件刷新限制。点击小部件右上角刷新按钮或点进应用即可触发最新课表同步。",
            keywords = listOf("小部件", "桌面", "空白", "刷新", "负一屏")
        ),
        UserGuideFaqItem(
            id = "faq_webdav",
            category = GuideCategory.SYNC_AND_BACKUP,
            question = "如何配置 WebDAV 云端备份与自动同步？",
            answer = "支持坚果云、Nextcloud 等标准 WebDAV。在「云端同步」中填入服务器 URL、账户和授权密码，即可实现换机无缝同步与自动快照。",
            keywords = listOf("WebDAV", "云端", "坚果云", "备份", "同步", "密码")
        ),
        UserGuideFaqItem(
            id = "faq_backup_migration",
            category = GuideCategory.SYNC_AND_BACKUP,
            question = "更换新手机后如何将课表完整迁移过去？",
            answer = "旧手机在「数据备份与迁移」中点击「导出全部数据」生成 .mikcb 文件，通过微信或 QQ 发送至新手机，在新机打开应用导入恢复即可。",
            keywords = listOf("迁移", "换机", "新手机", "mikcb", "备份", "微信")
        )
    )

    /**
     * 筛选 FAQ 条目。
     *
     * @param items 数据源
     * @param query 搜索关键词（支持匹配问题、回答和关键词标签）
     * @param category 分类过滤，为 null 表示全部分类
     */
    fun filterFaq(
        items: List<UserGuideFaqItem> = defaultFaqItems,
        query: String = "",
        category: GuideCategory? = null
    ): List<UserGuideFaqItem> {
        val trimmed = query.trim().lowercase()
        return items.filter { item ->
            val matchCategory = category == null || item.category == category
            if (!matchCategory) return@filter false
            if (trimmed.isEmpty()) return@filter true

            item.question.lowercase().contains(trimmed) ||
                item.answer.lowercase().contains(trimmed) ||
                item.keywords.any { it.lowercase().contains(trimmed) }
        }
    }

    /**
     * 切换展开/折叠状态。
     */
    fun toggleExpanded(expandedIds: Set<String>, id: String): Set<String> {
        return if (expandedIds.contains(id)) {
            expandedIds - id
        } else {
            expandedIds + id
        }
    }

    /**
     * 判断指定条目是否处于展开状态。
     */
    fun isExpanded(expandedIds: Set<String>, id: String): Boolean {
        return expandedIds.contains(id)
    }
}
