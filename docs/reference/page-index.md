# 页面索引

**共 91 个页面，`Ctrl+F` 搜中文，按住 `Ctrl` 点名字直接打开源码。**

按功能分区成块排列：课表 → 课程 → 日程与任务 → 时间与考试 → 统计 → 导入 → 迁移与导出 → 同步与备份 → 实时显示 → 设置 → 帮助与展示 → 诊断 → 关于 → 设置二级页 → 实时显示子屏。

> 这个文件由 `python tool/page_index.py` 生成，别手改；新增/删除页面后重跑一次并随代码提交。

### 课表

[日视图][p1] · [月视图][p2] · [多课表管理][p3] · [周视图][p4]

### 课程

[冲突详情][p5] · [添加 / 编辑课程][p6] · [课程总览与编辑][p7]

### 日程与任务

[新增/编辑日程][p8] · [日期作息规则][p9] · [日程列表][p10] · [添加 / 编辑任务表单][p11] · [任务清单][p12]

### 时间与考试

[添加 / 编辑考试][p13] · [考试安排][p14] · [地点时间组编辑][p15] · [地点作息匹配][p16] · [时间模板编辑节次][p17] · [时间模板管理][p18]

### 统计

[深度分析][p19] · [统计分析][p20] · [单节课明细][p21] · [统计设置][p22]

### 导入

[AI 课表图片识别导入][p23] · [.ics 日历导入][p24] · [导入课程][p25] · [表格导入][p26] · [适配器详情][p27] · [教务系统导入][p28]

[自定义脚本调试记录管理][p29] · [课表导入执行日志][p30] · [教务导入中转][p31] · [学校适配器列表][p32] · [网页登录导入][p33]

### 迁移与导出

[导出日历][p34] · [数据备份与迁移][p35] · [局域网编辑][p36] · [取件码][p37] · [二维码扫码接收][p38] · [二维码发送][p39]

### 同步与备份

[云备份列表][p40] · [云同步][p41] · [情侣课表设置][p42]

### 实时显示

[超级岛][p43] · [后台保活子屏][p44] · [提醒时间子屏][p45]

### 设置

[外观编辑][p46] · [玻璃坞底栏按钮编辑器][p47] · [坞站图标选择][p48] · [八宫格菜单按钮编辑器][p49] · [设置（通用）][p50] · [选择城市][p51]

### 帮助与展示

[澎湃 UI 组件库][p52] · [全部功能目录全览][p53] · [启动引导流程页面][p54] · [用户指南 / 新手引导][p55] · [Miuix 展示册][p56]

### 诊断

[诊断日志查看器][p57] · [临时测试课程][p58] · [内存统计][p59] · [性能报告][p60]

### 关于

[关于软件][p61] · [版本更新][p62] · [高级选项][p63] · [更新日志][p64] · [代码贡献者][p65] · [开源许可详情][p66] · [开源许可][p67] · [支持作者][p68]

[问题反馈][p69]

### 设置二级页

[设置 · 外观][p70] · [外观 · 首页背景（壁纸面板）][p71] · [Bing 壁纸画廊][p72] · [课程卡片设置][p73] · [设置 · 诊断][p74]

[设置 · 节假日（高级）][p75] · [设置 · 节假日][p76] · [首页与导航][p77] · [首页小组件][p78] · [设置 · 实时活动][p79] · [实时活动自检][p80]

[外观 · 材质（课程卡页签）][p81] · [外观 · 材质（通用页签）][p82] · [设置 · 重置][p83] · [设置 · 主题管理][p84]

[设置首页（课表设置）][p85] · [课表页面设置][p86] · [设置 · 学期][p87] · [壁纸取景][p88] · [设置 · 天气][p89]

### 实时显示子屏

[上课前显示子屏][p90] · [下课前显示子屏][p91]


[p1]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt
[p2]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt
[p3]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt
[p4]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt
[p5]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/conflict/CourseConflictPage.kt
[p6]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt
[p7]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt
[p8]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt
[p9]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt
[p10]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt
[p11]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/AddTaskPage.kt
[p12]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskListPage.kt
[p13]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/AddExamPage.kt
[p14]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt
[p15]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeGroupEditorPage.kt
[p16]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeMatchPage.kt
[p17]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeEditorPage.kt
[p18]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementPage.kt
[p19]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/CourseStatisticsPage.kt
[p20]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsAnalysisPage.kt
[p21]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSessionPage.kt
[p22]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSettingsPage.kt
[p23]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/AiImageCourseImportPage.kt
[p24]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/IcsImportPage.kt
[p25]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/ImportEntryPage.kt
[p26]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/SpreadsheetImportPage.kt
[p27]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterDetailPage.kt
[p28]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCourseImportPage.kt
[p29]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCustomDebugPage.kt
[p30]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseImportLogPage.kt
[p31]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt
[p32]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt
[p33]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt
[p34]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/export/IcsExportPage.kt
[p35]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferPage.kt
[p36]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditPage.kt
[p37]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/PickupCodesPage.kt
[p38]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferScanPage.kt
[p39]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferSendPage.kt
[p40]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt
[p41]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncPage.kt
[p42]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsPage.kt
[p43]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsPage.kt
[p44]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/LiveKeepAliveSettingsPage.kt
[p45]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/ReminderTimingPage.kt
[p46]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/AppearanceEditorScreen.kt
[p47]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt
[p48]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/GlassDockIconPickerScreen.kt
[p49]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt
[p50]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt
[p51]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerPage.kt
[p52]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/HyperosShowcasePage.kt
[p53]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/MoreFeaturesPage.kt
[p54]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/StartupFlowPage.kt
[p55]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt
[p56]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/showcase/MiuixShowcasePage.kt
[p57]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveDiagnosticsLogPage.kt
[p58]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveTestingFixturePage.kt
[p59]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/MemoryStatsPage.kt
[p60]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfReportPage.kt
[p61]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt
[p62]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt
[p63]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AdvancedOptionsPage.kt
[p64]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt
[p65]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ContributorsPage.kt
[p66]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt
[p67]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt
[p68]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt
[p69]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/feedback/FeedbackPage.kt
[p70]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsAppearancePage.kt
[p71]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsBackdropFlowPage.kt
[p72]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsBingWallpaperGalleryPage.kt
[p73]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsCourseCardPage.kt
[p74]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsDiagnosticsPage.kt
[p75]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsHolidayAdvancedPage.kt
[p76]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsHolidayPage.kt
[p77]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsHomeNavigationPage.kt
[p78]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsHomeWidgetPage.kt
[p79]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsLivePage.kt
[p80]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsLiveSelfCheckPage.kt
[p81]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsMaterialPanels.kt
[p82]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsMaterialPanels.kt
[p83]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsResetPage.kt
[p84]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsAppearancePage.kt
[p85]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsTimetablePage.kt
[p86]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsTimetablePageSettingsPage.kt
[p87]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsTimetablePage.kt
[p88]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsWallpaperPositionPage.kt
[p89]: ../../android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsWeatherPage.kt
[p90]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsPage.kt
[p91]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsPage.kt
