# 页面索引

**共 68 个页面，`Ctrl+F` 搜中文，按住 `Ctrl` 点名字直接打开源码。**

按功能分区成块排列：课表 → 课程 → 日程与任务 → 时间与考试 → 统计 → 导入 → 迁移与导出 → 同步与备份 → 实时显示 → 设置 → 帮助与展示 → 诊断 → 关于。

> 这个文件由 `python tool/page_index.py` 生成，别手改；新增/删除页面后重跑一次并随代码提交。

| 分区 | 页面 | 页面 | 页面 |
|---|---|---|---|
| **课表** | [日视图][p1] | [月视图][p2] | [多课表管理][p3] |
|   | [周视图][p4] |   |   |
|  |  |  |  |
| **课程** | [冲突详情][p5] | [添加 / 编辑课程][p6] | [课程总览与编辑][p7] |
|  |  |  |  |
| **日程与任务** | [新增/编辑日程][p8] | [日期作息规则][p9] | [日程列表][p10] |
|   | [添加 / 编辑任务表单][p11] | [任务清单][p12] |   |
|  |  |  |  |
| **时间与考试** | [添加 / 编辑考试][p13] | [考试安排][p14] | [地点时间组编辑][p15] |
|   | [地点作息匹配][p16] | [时间模板编辑节次][p17] | [时间模板管理][p18] |
|  |  |  |  |
| **统计** | [深度分析][p19] | [统计分析][p20] | [单节课明细][p21] |
|   | [统计设置][p22] |   |   |
|  |  |  |  |
| **导入** | [AI 课表图片识别导入][p23] | [.ics 日历导入][p24] | [导入课程][p25] |
|   | [表格导入][p26] | [适配器详情][p27] | [教务系统导入][p28] |
|   | [自定义脚本调试记录管理][p29] | [教务导入中转][p30] | [学校适配器列表][p31] |
|   | [网页登录导入][p32] |   |   |
|  |  |  |  |
| **迁移与导出** | [导出日历][p33] | [数据备份与迁移][p34] | [局域网编辑][p35] |
|   | [取件码][p36] | [二维码扫码接收][p37] | [二维码发送][p38] |
|  |  |  |  |
| **同步与备份** | [云备份列表][p39] | [云同步][p40] | [情侣课表设置][p41] |
|  |  |  |  |
| **实时显示** | [超级岛][p42] | [后台保活子屏][p43] | [提醒时间子屏][p44] |
|  |  |  |  |
| **设置** | [外观编辑][p45] | [玻璃坞底栏按钮编辑器][p46] | [坞站图标选择][p47] |
|   | [八宫格菜单按钮编辑器][p48] | [设置（通用）][p49] | [选择城市][p50] |
|  |  |  |  |
| **帮助与展示** | [澎湃 UI 组件库][p51] | [全部功能目录全览][p52] | [启动引导流程页面][p53] |
|   | [用户指南 / 新手引导][p54] | [Miuix 展示册][p55] |   |
|  |  |  |  |
| **诊断** | [诊断日志查看器][p56] | [临时测试课程][p57] | [内存统计][p58] |
|   | [性能报告][p59] |   |   |
|  |  |  |  |
| **关于** | [关于软件][p60] | [版本更新][p61] | [高级选项][p62] |
|   | [更新日志][p63] | [代码贡献者][p64] | [开源许可详情][p65] |
|   | [开源许可][p66] | [支持作者][p67] | [问题反馈][p68] |
|  |  |  |  |

<!-- 链接定义 -->
[p1]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt
[p2]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt
[p3]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt
[p4]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt
[p5]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/conflict/CourseConflictPage.kt
[p6]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt
[p7]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt
[p8]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt
[p9]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt
[p10]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt
[p11]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/AddTaskPage.kt
[p12]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskListPage.kt
[p13]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/AddExamPage.kt
[p14]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt
[p15]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeGroupEditorPage.kt
[p16]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeMatchPage.kt
[p17]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeEditorPage.kt
[p18]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementPage.kt
[p19]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/CourseStatisticsPage.kt
[p20]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsAnalysisPage.kt
[p21]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSessionPage.kt
[p22]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSettingsPage.kt
[p23]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/AiImageCourseImportPage.kt
[p24]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/IcsImportPage.kt
[p25]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/ImportEntryPage.kt
[p26]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/SpreadsheetImportPage.kt
[p27]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterDetailPage.kt
[p28]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCourseImportPage.kt
[p29]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCustomDebugPage.kt
[p30]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt
[p31]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt
[p32]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt
[p33]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/export/IcsExportPage.kt
[p34]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferPage.kt
[p35]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditPage.kt
[p36]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/PickupCodesPage.kt
[p37]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferScanPage.kt
[p38]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferSendPage.kt
[p39]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt
[p40]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncPage.kt
[p41]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsPage.kt
[p42]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsPage.kt
[p43]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/LiveKeepAliveSettingsPage.kt
[p44]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/ReminderTimingPage.kt
[p45]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/AppearanceEditorScreen.kt
[p46]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt
[p47]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/GlassDockIconPickerScreen.kt
[p48]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt
[p49]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt
[p50]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerPage.kt
[p51]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/HyperosShowcasePage.kt
[p52]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/MoreFeaturesPage.kt
[p53]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/StartupFlowPage.kt
[p54]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt
[p55]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/showcase/MiuixShowcasePage.kt
[p56]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveDiagnosticsLogPage.kt
[p57]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveTestingFixturePage.kt
[p58]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/MemoryStatsPage.kt
[p59]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfReportPage.kt
[p60]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt
[p61]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt
[p62]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AdvancedOptionsPage.kt
[p63]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt
[p64]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ContributorsPage.kt
[p65]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt
[p66]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt
[p67]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt
[p68]: ../../app/src/composeP1/kotlin/com/mutx163/qingyu/pages/feedback/FeedbackPage.kt
