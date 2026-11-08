# 页面索引

**一张表装全库，`Ctrl+F` 搜中文就能定位，不用按分区往下翻。**

共 **68** 个整页入口、**367** 个预览。

## 怎么用

1. `Ctrl+F` 搜你记得的中文页名，直接跳到那一行。
2. 按住 `Ctrl` 点名字（macOS 是 `Cmd`），打开对应源码文件。
3. 打开文件滚到底、右侧点 **Split / Preview**，就是这一页的全部档位。

> **这个文件是生成的，别手改。** 在 `pages/` 下新增、改名或删除整页入口后，
> 在仓库根跑 `python tool/page_index.py` 重新生成，并随代码一起提交。

## 口径

- 分区对应 App 的路由编号（`ShellPageIndex.kt` 里的 `a.*` … `j.*`），顺序按打开 App 到设置的路径。
- 入口 = 非 `private` 的 `fun XxxPage(` / `fun XxxScreen(`；`XxxHost` 是接线层，不收。
- 少数页面的标题由运行期决定（设置类的 `spec.title`、周/日/月视图、网页登录页），表里用的是按功能确定的中文名。
- 预览数按 `@Preview` 后调用的公共体归属，用来判断「这页铺没铺」，不是精确统计。

## 全部页面

| 分区 | 页面 | 入口 | 文件 | 预览 |
|---|---|---|---|---|
| 课表 | [日视图][p1] | `DayViewPage` | `timetable/day/DayViewPage.kt` | 3 |
| 课表 | [月视图][p2] | `MonthViewPage` | `timetable/month/MonthViewPage.kt` | 3 |
| 课表 | [多课表管理][p3] | `TimetableProfilesPage` | `timetable/TimetableProfilesPage.kt` | 7 |
| 课表 | [周视图][p4] | `TimetableWeekPage` | `timetable/TimetableWeekPage.kt` | 3 |
| 课程 | [冲突详情][p5] | `CourseConflictPage` | `conflict/CourseConflictPage.kt` | 5 |
| 课程 | [添加 / 编辑课程][p6] | `AddCoursePage` | `course/AddCoursePage.kt` | 4 |
| 课程 | [课程总览与编辑][p7] | `CourseOverviewPage` | `course/CourseOverviewPage.kt` | 6 |
| 日程与任务 | [新增/编辑日程][p8] | `AddScheduleItemPage` | `schedule/AddScheduleItemPage.kt` | 7 |
| 日程与任务 | [日期作息规则][p9] | `ScheduleDateRulePage` | `schedule/ScheduleDateRulePage.kt` | 7 |
| 日程与任务 | [日程列表][p10] | `ScheduleListPage` | `schedule/ScheduleListPage.kt` | 7 |
| 日程与任务 | [添加 / 编辑任务表单][p11] | `AddTaskPage` | `task/AddTaskPage.kt` | 6 |
| 日程与任务 | [任务清单][p12] | `TaskListPage` | `task/TaskListPage.kt` | 5 |
| 时间与考试 | [添加 / 编辑考试][p13] | `AddExamPage` | `exam/AddExamPage.kt` | 7 |
| 时间与考试 | [考试安排][p14] | `ExamListPage` | `exam/ExamListPage.kt` | 7 |
| 时间与考试 | [地点作息匹配][p15] | `LocationTimeGroupEditorPage` | `time_scheme/LocationTimeGroupEditorPage.kt` | 4 |
| 时间与考试 | [地点作息匹配][p16] | `LocationTimeMatchPage` | `time_scheme/LocationTimeMatchPage.kt` | 4 |
| 时间与考试 | [时间模板编辑节次][p17] | `TimeSchemeEditorPage` | `time_scheme/TimeSchemeEditorPage.kt` | 4 |
| 时间与考试 | [时间模板管理][p18] | `TimeSchemeManagementPage` | `time_scheme/TimeSchemeManagementPage.kt` | 5 |
| 统计 | [深度分析][p19] | `CourseStatisticsPage` | `statistics/CourseStatisticsPage.kt` | 6 |
| 统计 | [统计分析][p20] | `StatisticsAnalysisPage` | `statistics/StatisticsAnalysisPage.kt` | 6 |
| 统计 | [单节课明细][p21] | `StatisticsSessionPage` | `statistics/StatisticsSessionPage.kt` | 4 |
| 统计 | [统计设置][p22] | `StatisticsSettingsPage` | `statistics/StatisticsSettingsPage.kt` | 4 |
| 导入 | [AI 课表图片识别导入][p23] | `AiImageCourseImportPage` | `import/warehouse/AiImageCourseImportPage.kt` | 5 |
| 导入 | [.ics 日历导入][p24] | `IcsImportPage` | `import/IcsImportPage.kt` | 5 |
| 导入 | [导入课程][p25] | `ImportEntryPage` | `import/ImportEntryPage.kt` | 6 |
| 导入 | [表格导入][p26] | `SpreadsheetImportPage` | `import/SpreadsheetImportPage.kt` | 6 |
| 导入 | [适配器详情][p27] | `WarehouseAdapterDetailPage` | `import/warehouse/WarehouseAdapterDetailPage.kt` | 8 |
| 导入 | [教务系统导入][p28] | `WarehouseCourseImportPage` | `import/warehouse/WarehouseCourseImportPage.kt` | 8 |
| 导入 | [自定义脚本调试记录管理][p29] | `WarehouseCustomDebugPage` | `import/warehouse/WarehouseCustomDebugPage.kt` | 5 |
| 导入 | [教务导入中转][p30] | `WarehouseNoTargetPage` | `import/warehouse/WarehouseWebLoginHost.kt` | 0 |
| 导入 | [学校适配器列表][p31] | `WarehouseSchoolAdaptersPage` | `import/warehouse/WarehouseSchoolAdaptersPage.kt` | 7 |
| 导入 | [网页登录导入][p32] | `WarehouseWebLoginPage` | `import/warehouse/WarehouseWebLoginPage.kt` | 0 |
| 迁移与导出 | [导出日历][p33] | `IcsExportPage` | `export/IcsExportPage.kt` | 7 |
| 迁移与导出 | [数据备份与迁移][p34] | `DataTransferPage` | `transfer/DataTransferPage.kt` | 4 |
| 迁移与导出 | [局域网编辑][p35] | `LanEditPage` | `transfer/LanEditPage.kt` | 5 |
| 迁移与导出 | [取件码][p36] | `PickupCodesPage` | `transfer/PickupCodesPage.kt` | 5 |
| 迁移与导出 | [二维码扫码接收][p37] | `QrTransferScanPage` | `transfer/QrTransferScanPage.kt` | 5 |
| 迁移与导出 | [二维码发送][p38] | `QrTransferSendPage` | `transfer/QrTransferSendPage.kt` | 5 |
| 同步与备份 | [云备份列表][p39] | `CloudBackupListPage` | `sync/CloudBackupListPage.kt` | 8 |
| 同步与备份 | [云同步][p40] | `CloudSyncPage` | `sync/CloudSyncPage.kt` | 8 |
| 同步与备份 | [情侣课表设置][p41] | `CoupleTimetableSettingsPage` | `sync/CoupleTimetableSettingsPage.kt` | 6 |
| 实时显示 | [超级岛][p42] | `DisplaySettingsPage` | `live/DisplaySettingsPage.kt` | 8 |
| 实时显示 | [后台保活子屏][p43] | `LiveKeepAliveSettingsPage` | `live/LiveKeepAliveSettingsPage.kt` | 6 |
| 实时显示 | [提醒时间子屏][p44] | `LiveReminderTimingPage` | `live/ReminderTimingPage.kt` | 5 |
| 设置 | [外观编辑][p45] | `AppearanceEditorScreen` | `settings/AppearanceEditorScreen.kt` | 5 |
| 设置 | [玻璃坞底栏按钮编辑器][p46] | `GlassDockEditorScreen` | `settings/DockMenuEditors.kt` | 5 |
| 设置 | [坞站图标选择][p47] | `GlassDockIconPickerScreen` | `settings/GlassDockIconPickerScreen.kt` | 5 |
| 设置 | [八宫格菜单按钮编辑器][p48] | `HomeMenuEditorScreen` | `settings/DockMenuEditors.kt` | 4 |
| 设置 | [设置（通用）][p49] | `SettingsPageScreen` | `settings/SettingsPageRenderers.kt` | 5 |
| 设置 | [选择城市][p50] | `WeatherCityPickerPage` | `weather/WeatherCityPickerPage.kt` | 9 |
| 帮助与展示 | [澎湃 UI 组件库][p51] | `HyperosShowcasePage` | `guide/HyperosShowcasePage.kt` | 3 |
| 帮助与展示 | [全部功能目录全览][p52] | `MoreFeaturesPage` | `guide/MoreFeaturesPage.kt` | 4 |
| 帮助与展示 | [启动引导流程页面][p53] | `StartupFlowPage` | `guide/StartupFlowPage.kt` | 7 |
| 帮助与展示 | [用户指南 / 新手引导][p54] | `UserGuidePage` | `guide/UserGuidePage.kt` | 4 |
| 帮助与展示 | [Miuix 展示册][p55] | `MiuixShowcasePage` | `showcase/MiuixShowcasePage.kt` | 4 |
| 诊断 | [诊断日志查看器][p56] | `LiveDiagnosticsLogPage` | `diagnostics/LiveDiagnosticsLogPage.kt` | 7 |
| 诊断 | [临时测试课程][p57] | `LiveTestingFixturePage` | `diagnostics/LiveTestingFixturePage.kt` | 5 |
| 诊断 | [内存统计][p58] | `MemoryStatsPage` | `diagnostics/MemoryStatsPage.kt` | 7 |
| 诊断 | [性能报告][p59] | `PerfReportPage` | `diagnostics/PerfReportPage.kt` | 7 |
| 关于 | [关于软件][p60] | `AboutStaticPage` | `about/AboutStaticPage.kt` | 4 |
| 关于 | [版本更新][p61] | `AboutUpdatePage` | `about/AboutUpdatePage.kt` | 7 |
| 关于 | [高级选项][p62] | `AdvancedOptionsPage` | `about/AdvancedOptionsPage.kt` | 5 |
| 关于 | [更新日志][p63] | `ChangelogPage` | `about/ChangelogPage.kt` | 4 |
| 关于 | [代码贡献者][p64] | `ContributorsPage` | `about/ContributorsPage.kt` | 9 |
| 关于 | [开源许可详情][p65] | `OpenSourceLicenseDetailPage` | `about/OpenSourceLicensesPage.kt` | 3 |
| 关于 | [开源许可][p66] | `OpenSourceLicensesPage` | `about/OpenSourceLicensesPage.kt` | 6 |
| 关于 | [支持作者][p67] | `SupportCreatorPage` | `about/SupportCreatorPage.kt` | 7 |
| 关于 | [问题反馈][p68] | `FeedbackPage` | `feedback/FeedbackPage.kt` | 5 |

## 按分区统计

| 分区 | 入口数 |
|---|---|
| 课表 | 4 |
| 课程 | 3 |
| 日程与任务 | 5 |
| 时间与考试 | 6 |
| 统计 | 4 |
| 导入 | 10 |
| 迁移与导出 | 6 |
| 同步与备份 | 3 |
| 实时显示 | 3 |
| 设置 | 6 |
| 帮助与展示 | 5 |
| 诊断 | 4 |
| 关于 | 9 |

<!-- 链接定义：表格里的 [名字][pN] 指到这里 -->
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
