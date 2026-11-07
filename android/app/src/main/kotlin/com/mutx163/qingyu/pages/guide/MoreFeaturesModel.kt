package com.mutx163.qingyu.pages.guide

/**
 * 搜索关键词高亮文本片段。
 */
data class TextHighlightPart(
    val text: String,
    val isHighlight: Boolean
)

/**
 * 功能条目元数据模型。
 */
data class MoreFeatureItem(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val keywords: List<String> = emptyList(),
    val categoryKey: String = ""
)

/**
 * 功能分组容器。
 */
data class MoreFeatureGroup(
    val id: String,
    val title: String,
    val items: List<MoreFeatureItem>
)

/**
 * 全部功能索引领域模型与搜索逻辑。
 */
object MoreFeaturesModel {

    /**
     * 构造默认全量功能分组。
     * 与 Flutter `lib/screens/more_features_screen.dart` 和 `kHomeMenuCatalog` 严格对齐。
     */
    fun buildDefaultFeatureGroups(
        activeProfileName: String? = null,
        activeTimeSchemeName: String? = null
    ): List<MoreFeatureGroup> {
        return listOf(
            MoreFeatureGroup(
                id = "timetable_content",
                title = GuideStrings.settingsTimetableSectionTitle.text,
                items = listOf(
                    MoreFeatureItem(
                        id = "overview",
                        title = GuideStrings.homeMenuOverviewTitle.text,
                        keywords = listOf("课程", "简称", "颜色")
                    ),
                    MoreFeatureItem(
                        id = "statistics",
                        title = GuideStrings.homeMenuStatisticsTitle.text,
                        keywords = listOf("统计", "排行", "图表", "分析")
                    ),
                    MoreFeatureItem(
                        id = "profiles",
                        title = GuideStrings.timetableProfilesTitle.text,
                        subtitle = activeProfileName,
                        keywords = listOf("多套", "切换", "档案")
                    ),
                    MoreFeatureItem(
                        id = "timeSchemes",
                        title = GuideStrings.timeSchemeTitle.text,
                        subtitle = activeTimeSchemeName,
                        keywords = listOf("作息", "节次", "上下课")
                    ),
                    MoreFeatureItem(
                        id = "locationTimeMatch",
                        title = GuideStrings.locationTimeMatchTitle.text,
                        keywords = listOf("楼栋", "教室", "作息")
                    ),
                    MoreFeatureItem(
                        id = "scheduleDateRule",
                        title = GuideStrings.scheduleDateRuleSectionTitle.text,
                        keywords = listOf("季节", "假期", "换作息")
                    ),
                    MoreFeatureItem(
                        id = "exams",
                        title = GuideStrings.examListTitle.text,
                        keywords = listOf("考试", "倒计时", "成绩")
                    ),
                    MoreFeatureItem(
                        id = "tasks",
                        title = GuideStrings.homeMenuTasksTitle.text,
                        keywords = listOf("作业", "待办", "截止")
                    ),
                    MoreFeatureItem(
                        id = "scheduleList",
                        title = GuideStrings.scheduleListTitle.text,
                        keywords = listOf("日程", "非课程")
                    ),
                    MoreFeatureItem(
                        id = "courseConflict",
                        title = GuideStrings.courseConflictDetailTitle.text,
                        keywords = listOf("冲突", "撞课", "时间重叠")
                    ),
                    MoreFeatureItem(
                        id = "monthView",
                        title = GuideStrings.monthViewTitle.text,
                        keywords = listOf("日历", "整月", "哪天")
                    ),
                    MoreFeatureItem(
                        id = "pickupCode",
                        title = GuideStrings.pickupCodeEntryTitle.text,
                        keywords = listOf("快递", "取件", "包裹")
                    )
                )
            ),
            MoreFeatureGroup(
                id = "timetable_appearance",
                title = GuideStrings.settingsDisplayAppearanceSectionTitle.text,
                items = listOf(
                    MoreFeatureItem(
                        id = "appearanceEditor",
                        title = GuideStrings.appearanceEditorTitle.text,
                        subtitle = GuideStrings.appearanceEditorEntrySubtitle.text,
                        keywords = listOf("换肤", "皮肤", "壁纸", "材质", "主题")
                    ),
                    MoreFeatureItem(
                        id = "appearanceSettings",
                        title = GuideStrings.appearanceTitle.text,
                        keywords = listOf("主题", "深色", "换肤")
                    ),
                    MoreFeatureItem(
                        id = "timetablePageSettings",
                        title = GuideStrings.timetablePageSettingsTitle.text,
                        keywords = listOf("格子", "排版")
                    ),
                    MoreFeatureItem(
                        id = "courseCardSettings",
                        title = GuideStrings.courseCardSettingsTitle.text,
                        keywords = listOf("课程卡", "字色")
                    ),
                    MoreFeatureItem(
                        id = "weatherSettings",
                        title = GuideStrings.weatherSettingsEntryTitle.text,
                        keywords = listOf("天气", "城市")
                    ),
                    MoreFeatureItem(
                        id = "holidaySettings",
                        title = GuideStrings.holidaySettingsTitle.text,
                        keywords = listOf("调休", "放假")
                    )
                )
            ),
            MoreFeatureGroup(
                id = "notification_desktop",
                title = GuideStrings.settingsReminderDesktopSectionTitle.text,
                items = listOf(
                    MoreFeatureItem(
                        id = "liveSettings",
                        title = GuideStrings.liveSettingsTitle.text,
                        keywords = listOf("超级岛", "灵动岛", "通知")
                    ),
                    MoreFeatureItem(
                        id = "homeWidgetSettings",
                        title = GuideStrings.homeWidgetSettingsTitle.text,
                        keywords = listOf("小组件", "桌面")
                    )
                )
            ),
            MoreFeatureGroup(
                id = "app_preferences",
                title = GuideStrings.settingsAppSectionTitle.text,
                items = listOf(
                    MoreFeatureItem(
                        id = "homeNavigation",
                        title = GuideStrings.homeNavigationTitle.text,
                        keywords = listOf("底栏", "八宫格", "菜单")
                    ),
                    MoreFeatureItem(
                        id = "generalSettings",
                        title = GuideStrings.generalSettingsTitle.text,
                        keywords = listOf("语言", "动画", "触感")
                    ),
                    MoreFeatureItem(
                        id = "statisticsSettings",
                        title = GuideStrings.statisticsSettingsTitle.text,
                        keywords = listOf("统计", "算不算")
                    ),
                    MoreFeatureItem(
                        id = "settings",
                        title = GuideStrings.homeMenuSettingsTitle.text,
                        keywords = listOf("设置", "配置", "偏好")
                    )
                )
            ),
            MoreFeatureGroup(
                id = "data_sync",
                title = GuideStrings.settingsDataShareSectionTitle.text,
                items = listOf(
                    MoreFeatureItem(
                        id = "importCourses",
                        title = GuideStrings.homeMenuImportTitle.text,
                        keywords = listOf("教务", "表格", "ics")
                    ),
                    MoreFeatureItem(
                        id = "icsExport",
                        title = GuideStrings.icsExportTitle.text,
                        keywords = listOf("导出", "日历", "ics")
                    ),
                    MoreFeatureItem(
                        id = "dataTransfer",
                        title = GuideStrings.dataTransferEntryTitle.text,
                        keywords = listOf("备份", "恢复", "换机")
                    ),
                    MoreFeatureItem(
                        id = "cloudSync",
                        title = GuideStrings.cloudSyncTitle.text,
                        keywords = listOf("webdav", "云端")
                    ),
                    MoreFeatureItem(
                        id = "lanEdit",
                        title = GuideStrings.lanEditTitle.text,
                        keywords = listOf("局域网", "电脑")
                    ),
                    MoreFeatureItem(
                        id = "coupleTimetable",
                        title = GuideStrings.coupleTimetableTitle.text,
                        keywords = listOf("情侣", "ta")
                    )
                )
            ),
            MoreFeatureGroup(
                id = "about_support",
                title = GuideStrings.settingsAboutSectionTitle.text,
                items = listOf(
                    MoreFeatureItem(
                        id = "update",
                        title = GuideStrings.homeMenuUpdateTitle.text,
                        keywords = listOf("更新", "升级", "版本", "下载")
                    ),
                    MoreFeatureItem(
                        id = "aboutApp",
                        title = GuideStrings.aboutTitle.text,
                        keywords = listOf("版本", "信息")
                    ),
                    MoreFeatureItem(
                        id = "userGuide",
                        title = GuideStrings.userGuideEntryTitle.text,
                        keywords = listOf("教程", "新手")
                    ),
                    MoreFeatureItem(
                        id = "diagnosticsSettings",
                        title = GuideStrings.diagnosticsEntryTitle.text,
                        keywords = listOf("日志", "排查", "自检")
                    ),
                    MoreFeatureItem(
                        id = "changelog",
                        title = GuideStrings.aboutChangelogTitle.text,
                        keywords = listOf("更新记录", "版本")
                    ),
                    MoreFeatureItem(
                        id = "feedback",
                        title = GuideStrings.feedbackTitle.text,
                        keywords = listOf("意见", "问题")
                    ),
                    MoreFeatureItem(
                        id = "openSourceLicenses",
                        title = GuideStrings.aboutOpenSourceLicensesTitle.text,
                        keywords = listOf("许可", "开源")
                    ),
                    MoreFeatureItem(
                        id = "support",
                        title = GuideStrings.homeMenuCoffeeTitle.text,
                        keywords = listOf("捐赠", "请喝咖啡")
                    ),
                    MoreFeatureItem(
                        id = "memoryStats",
                        title = GuideStrings.memoryStatsEntryTitle.text,
                        keywords = listOf("内存", "性能", "调试")
                    )
                )
            )
        )
    }

    /**
     * 按关键词筛选功能分组。
     * 若关键词命中了分组标题，则展示该分组下全部条目；
     * 否则仅保留命中了条目标题或其同义词条目；空分组自动剔除。
     */
    fun filterGroups(
        groups: List<MoreFeatureGroup>,
        rawQuery: String
    ): List<MoreFeatureGroup> {
        val query = rawQuery.trim().lowercase()
        if (query.isEmpty()) {
            return groups
        }
        val result = mutableListOf<MoreFeatureGroup>()
        for (group in groups) {
            val groupHit = group.title.lowercase().contains(query)
            val filteredItems = if (groupHit) {
                group.items
            } else {
                group.items.filter { item ->
                    item.title.lowercase().contains(query) ||
                        item.keywords.any { it.lowercase().contains(query) }
                }
            }
            if (filteredItems.isNotEmpty()) {
                result.add(group.copy(items = filteredItems))
            }
        }
        return result
    }

    /**
     * 将一段文本按照搜索词拆分为普通部分与高亮部分（不区分大小写）。
     */
    fun highlightText(text: String, rawQuery: String): List<TextHighlightPart> {
        val query = rawQuery.trim()
        if (query.isEmpty()) {
            return listOf(TextHighlightPart(text, isHighlight = false))
        }

        val parts = mutableListOf<TextHighlightPart>()
        var searchIndex = 0
        val lowerText = text.lowercase()
        val lowerQuery = query.lowercase()

        while (searchIndex < text.length) {
            val matchIndex = lowerText.indexOf(lowerQuery, searchIndex)
            if (matchIndex < 0) {
                // 没有后续匹配，把剩余文本加入
                parts.add(TextHighlightPart(text.substring(searchIndex), isHighlight = false))
                break
            }

            if (matchIndex > searchIndex) {
                // 匹配前的前缀
                parts.add(TextHighlightPart(text.substring(searchIndex, matchIndex), isHighlight = false))
            }

            // 匹配段
            val matchEnd = matchIndex + query.length
            parts.add(TextHighlightPart(text.substring(matchIndex, matchEnd), isHighlight = true))
            searchIndex = matchEnd
        }

        return parts
    }
}
