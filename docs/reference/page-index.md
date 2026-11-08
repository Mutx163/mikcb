# 页面索引

**共 68 个页面，`Ctrl+F` 搜中文，按住 `Ctrl` 点名字直接打开源码。**

排列顺序：课表 → 课程 → 日程与任务 → 时间与考试 → 统计 → 导入 → 迁移与导出 → 同步与备份 → 实时显示 → 设置 → 帮助与展示 → 诊断 → 关于。

> 这个文件由 `python tool/page_index.py` 生成，别手改；新增/删除页面后重跑一次并随代码提交。

| 页面 | 页面 | 页面 |
|---|---|---|
| [日视图][p1] | [月视图][p2] | [多课表管理][p3] |
| [周视图][p4] | [添加 / 编辑课程][p5] | [冲突详情][p6] |
| [课程总览与编辑][p7] | [新增/编辑日程][p8] | [添加 / 编辑任务表单][p9] |
| [日期作息规则][p10] | [日程列表][p11] | [任务清单][p12] |
| [添加 / 编辑考试][p13] | [考试安排][p14] | [地点作息匹配][p15] |
| [地点作息匹配][p16] | [时间模板编辑节次][p17] | [时间模板管理][p18] |
| [深度分析][p19] | [统计分析][p20] | [单节课明细][p21] |
| [统计设置][p22] | [AI 课表图片识别导入][p23] | [.ics 日历导入][p24] |
| [导入课程][p25] | [表格导入][p26] | [适配器详情][p27] |
| [教务系统导入][p28] | [自定义脚本调试记录管理][p29] | [教务导入中转][p30] |
| [学校适配器列表][p31] | [网页登录导入][p32] | [数据备份与迁移][p33] |
| [导出日历][p34] | [局域网编辑][p35] | [取件码][p36] |
| [二维码扫码接收][p37] | [二维码发送][p38] | [云备份列表][p39] |
| [云同步][p40] | [情侣课表设置][p41] | [超级岛][p42] |
| [后台保活子屏][p43] | [提醒时间子屏][p44] | [外观编辑][p45] |
| [玻璃坞底栏按钮编辑器][p46] | [坞站图标选择][p47] | [八宫格菜单按钮编辑器][p48] |
| [设置（通用）][p49] | [选择城市][p50] | [澎湃 UI 组件库][p51] |
| [Miuix 展示册][p52] | [全部功能目录全览][p53] | [启动引导流程页面][p54] |
| [用户指南 / 新手引导][p55] | [诊断日志查看器][p56] | [临时测试课程][p57] |
| [内存统计][p58] | [性能报告][p59] | [关于软件][p60] |
| [版本更新][p61] | [高级选项][p62] | [更新日志][p63] |
| [代码贡献者][p64] | [问题反馈][p65] | [开源许可详情][p66] |
| [开源许可][p67] | [支持作者][p68] |   |

<!-- DATA｜脚本用，勿手改；每行：域|页名|入口|文件|预览 -->
timetable|日视图|DayViewPage|timetable/day/DayViewPage.kt|3
timetable|月视图|MonthViewPage|timetable/month/MonthViewPage.kt|3
timetable|多课表管理|TimetableProfilesPage|timetable/TimetableProfilesPage.kt|7
timetable|周视图|TimetableWeekPage|timetable/TimetableWeekPage.kt|3
course|添加 / 编辑课程|AddCoursePage|course/AddCoursePage.kt|4
conflict|冲突详情|CourseConflictPage|conflict/CourseConflictPage.kt|5
course|课程总览与编辑|CourseOverviewPage|course/CourseOverviewPage.kt|6
schedule|新增/编辑日程|AddScheduleItemPage|schedule/AddScheduleItemPage.kt|7
task|添加 / 编辑任务表单|AddTaskPage|task/AddTaskPage.kt|6
schedule|日期作息规则|ScheduleDateRulePage|schedule/ScheduleDateRulePage.kt|7
schedule|日程列表|ScheduleListPage|schedule/ScheduleListPage.kt|7
task|任务清单|TaskListPage|task/TaskListPage.kt|5
exam|添加 / 编辑考试|AddExamPage|exam/AddExamPage.kt|7
exam|考试安排|ExamListPage|exam/ExamListPage.kt|7
time_scheme|地点作息匹配|LocationTimeGroupEditorPage|time_scheme/LocationTimeGroupEditorPage.kt|4
time_scheme|地点作息匹配|LocationTimeMatchPage|time_scheme/LocationTimeMatchPage.kt|4
time_scheme|时间模板编辑节次|TimeSchemeEditorPage|time_scheme/TimeSchemeEditorPage.kt|4
time_scheme|时间模板管理|TimeSchemeManagementPage|time_scheme/TimeSchemeManagementPage.kt|5
statistics|深度分析|CourseStatisticsPage|statistics/CourseStatisticsPage.kt|6
statistics|统计分析|StatisticsAnalysisPage|statistics/StatisticsAnalysisPage.kt|6
statistics|单节课明细|StatisticsSessionPage|statistics/StatisticsSessionPage.kt|4
statistics|统计设置|StatisticsSettingsPage|statistics/StatisticsSettingsPage.kt|4
import|AI 课表图片识别导入|AiImageCourseImportPage|import/warehouse/AiImageCourseImportPage.kt|5
import|.ics 日历导入|IcsImportPage|import/IcsImportPage.kt|5
import|导入课程|ImportEntryPage|import/ImportEntryPage.kt|6
import|表格导入|SpreadsheetImportPage|import/SpreadsheetImportPage.kt|6
import|适配器详情|WarehouseAdapterDetailPage|import/warehouse/WarehouseAdapterDetailPage.kt|8
import|教务系统导入|WarehouseCourseImportPage|import/warehouse/WarehouseCourseImportPage.kt|8
import|自定义脚本调试记录管理|WarehouseCustomDebugPage|import/warehouse/WarehouseCustomDebugPage.kt|5
import|教务导入中转|WarehouseNoTargetPage|import/warehouse/WarehouseWebLoginHost.kt|0
import|学校适配器列表|WarehouseSchoolAdaptersPage|import/warehouse/WarehouseSchoolAdaptersPage.kt|7
import|网页登录导入|WarehouseWebLoginPage|import/warehouse/WarehouseWebLoginPage.kt|0
transfer|数据备份与迁移|DataTransferPage|transfer/DataTransferPage.kt|4
export|导出日历|IcsExportPage|export/IcsExportPage.kt|7
transfer|局域网编辑|LanEditPage|transfer/LanEditPage.kt|5
transfer|取件码|PickupCodesPage|transfer/PickupCodesPage.kt|5
transfer|二维码扫码接收|QrTransferScanPage|transfer/QrTransferScanPage.kt|5
transfer|二维码发送|QrTransferSendPage|transfer/QrTransferSendPage.kt|5
sync|云备份列表|CloudBackupListPage|sync/CloudBackupListPage.kt|8
sync|云同步|CloudSyncPage|sync/CloudSyncPage.kt|8
sync|情侣课表设置|CoupleTimetableSettingsPage|sync/CoupleTimetableSettingsPage.kt|6
live|超级岛|DisplaySettingsPage|live/DisplaySettingsPage.kt|8
live|后台保活子屏|LiveKeepAliveSettingsPage|live/LiveKeepAliveSettingsPage.kt|6
live|提醒时间子屏|LiveReminderTimingPage|live/ReminderTimingPage.kt|5
settings|外观编辑|AppearanceEditorScreen|settings/AppearanceEditorScreen.kt|5
settings|玻璃坞底栏按钮编辑器|GlassDockEditorScreen|settings/DockMenuEditors.kt|5
settings|坞站图标选择|GlassDockIconPickerScreen|settings/GlassDockIconPickerScreen.kt|5
settings|八宫格菜单按钮编辑器|HomeMenuEditorScreen|settings/DockMenuEditors.kt|4
settings|设置（通用）|SettingsPageScreen|settings/SettingsPageRenderers.kt|5
weather|选择城市|WeatherCityPickerPage|weather/WeatherCityPickerPage.kt|9
guide|澎湃 UI 组件库|HyperosShowcasePage|guide/HyperosShowcasePage.kt|3
showcase|Miuix 展示册|MiuixShowcasePage|showcase/MiuixShowcasePage.kt|4
guide|全部功能目录全览|MoreFeaturesPage|guide/MoreFeaturesPage.kt|4
guide|启动引导流程页面|StartupFlowPage|guide/StartupFlowPage.kt|7
guide|用户指南 / 新手引导|UserGuidePage|guide/UserGuidePage.kt|4
diagnostics|诊断日志查看器|LiveDiagnosticsLogPage|diagnostics/LiveDiagnosticsLogPage.kt|7
diagnostics|临时测试课程|LiveTestingFixturePage|diagnostics/LiveTestingFixturePage.kt|5
diagnostics|内存统计|MemoryStatsPage|diagnostics/MemoryStatsPage.kt|7
diagnostics|性能报告|PerfReportPage|diagnostics/PerfReportPage.kt|7
about|关于软件|AboutStaticPage|about/AboutStaticPage.kt|4
about|版本更新|AboutUpdatePage|about/AboutUpdatePage.kt|7
about|高级选项|AdvancedOptionsPage|about/AdvancedOptionsPage.kt|5
about|更新日志|ChangelogPage|about/ChangelogPage.kt|4
about|代码贡献者|ContributorsPage|about/ContributorsPage.kt|9
feedback|问题反馈|FeedbackPage|feedback/FeedbackPage.kt|5
about|开源许可详情|OpenSourceLicenseDetailPage|about/OpenSourceLicensesPage.kt|3
about|开源许可|OpenSourceLicensesPage|about/OpenSourceLicensesPage.kt|6
about|支持作者|SupportCreatorPage|about/SupportCreatorPage.kt|7
-->

<!-- 链接定义 -->
[p1]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt
[p2]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt
[p3]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt
[p4]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt
[p5]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt
[p6]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/conflict/CourseConflictPage.kt
[p7]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt
[p8]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt
[p9]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/AddTaskPage.kt
[p10]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt
[p11]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt
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
[p30]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt
[p31]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt
[p32]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt
[p33]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferPage.kt
[p34]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/export/IcsExportPage.kt
[p35]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditPage.kt
[p36]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/PickupCodesPage.kt
[p37]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferScanPage.kt
[p38]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferSendPage.kt
[p39]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt
[p40]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncPage.kt
[p41]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsPage.kt
[p42]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsPage.kt
[p43]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/LiveKeepAliveSettingsPage.kt
[p44]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/ReminderTimingPage.kt
[p45]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/AppearanceEditorScreen.kt
[p46]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt
[p47]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/GlassDockIconPickerScreen.kt
[p48]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt
[p49]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt
[p50]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerPage.kt
[p51]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/HyperosShowcasePage.kt
[p52]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/showcase/MiuixShowcasePage.kt
[p53]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/MoreFeaturesPage.kt
[p54]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/StartupFlowPage.kt
[p55]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt
[p56]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveDiagnosticsLogPage.kt
[p57]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveTestingFixturePage.kt
[p58]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/MemoryStatsPage.kt
[p59]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfReportPage.kt
[p60]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt
[p61]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt
[p62]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AdvancedOptionsPage.kt
[p63]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt
[p64]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ContributorsPage.kt
[p65]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/feedback/FeedbackPage.kt
[p66]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt
[p67]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt
[p68]: ../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt
