# 页面索引

按软件结构分区。找页面就找功能区，点中文名直接打开源码。

共 **68** 个整页入口、**340** 个预览。

## 怎么用

1. **直接点**：「页面」那列是指向源码文件的链接，按住 `Ctrl` 点一下（macOS 是 `Cmd`）就打开。
2. 不确定在哪就 `Ctrl+F` 搜中文。
3. 打开文件滚到底、右侧点 **Split / Preview**，就是这一页的全部档位。

> **这个文件是生成的，别手改。** 在 `pages/` 下新增、改名或删除整页入口后，
> 在仓库根跑 `python tool/page_index.py` 重新生成，并随代码一起提交。

## 口径

- 分区对应 App 的路由编号（`ShellPageIndex.kt` 里的 `a.*` … `j.*`）；一页属于哪个区由它所在域决定。
- 入口 = 非 `private` 的 `fun XxxPage(` / `fun XxxScreen(`；`XxxHost` 是接线层，不收。
- 没有固定中文标题的页（设置类的 `spec.title`、周/日/月视图等），显示入口函数名，同样可点。
- 预览数按 `@Preview` 后调用的公共体归属，用来判断「这页铺没铺」，不是精确统计。

## 课表（c）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| timetable | [DayViewPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt) | `DayViewPage` | `pages/timetable/day/DayViewPage.kt` | 0 |
| timetable | [MonthViewPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt) | `MonthViewPage` | `pages/timetable/month/MonthViewPage.kt` | 0 |
| timetable | [多课表管理](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt) | `TimetableProfilesPage` | `pages/timetable/TimetableProfilesPage.kt` | 6 |
| timetable | [TimetableWeekPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt) | `TimetableWeekPage` | `pages/timetable/TimetableWeekPage.kt` | 0 |

## 课程（d1）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| conflict | [冲突详情](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/conflict/CourseConflictPage.kt) | `CourseConflictPage` | `pages/conflict/CourseConflictPage.kt` | 4 |
| course | [添加 / 编辑课程](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt) | `AddCoursePage` | `pages/course/AddCoursePage.kt` | 4 |
| course | [课程总览与编辑](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt) | `CourseOverviewPage` | `pages/course/CourseOverviewPage.kt` | 6 |

## 日程与任务（d2）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| schedule | [新增/编辑日程](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt) | `AddScheduleItemPage` | `pages/schedule/AddScheduleItemPage.kt` | 7 |
| schedule | [日期作息规则](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt) | `ScheduleDateRulePage` | `pages/schedule/ScheduleDateRulePage.kt` | 6 |
| schedule | [日程列表](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt) | `ScheduleListPage` | `pages/schedule/ScheduleListPage.kt` | 6 |
| task | [添加 / 编辑任务表单](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/AddTaskPage.kt) | `AddTaskPage` | `pages/task/AddTaskPage.kt` | 5 |
| task | [任务清单](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskListPage.kt) | `TaskListPage` | `pages/task/TaskListPage.kt` | 4 |

## 时间与考试（d3）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| exam | [添加 / 编辑考试](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/AddExamPage.kt) | `AddExamPage` | `pages/exam/AddExamPage.kt` | 6 |
| exam | [考试安排](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt) | `ExamListPage` | `pages/exam/ExamListPage.kt` | 6 |
| time_scheme | [地点作息匹配](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeGroupEditorPage.kt) | `LocationTimeGroupEditorPage` | `pages/time_scheme/LocationTimeGroupEditorPage.kt` | 4 |
| time_scheme | [LocationTimeMatchPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeMatchPage.kt) | `LocationTimeMatchPage` | `pages/time_scheme/LocationTimeMatchPage.kt` | 4 |
| time_scheme | [时间模板编辑节次](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeEditorPage.kt) | `TimeSchemeEditorPage` | `pages/time_scheme/TimeSchemeEditorPage.kt` | 4 |
| time_scheme | [TimeSchemeManagementPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementPage.kt) | `TimeSchemeManagementPage` | `pages/time_scheme/TimeSchemeManagementPage.kt` | 5 |

## 统计（e）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| statistics | [深度分析](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/CourseStatisticsPage.kt) | `CourseStatisticsPage` | `pages/statistics/CourseStatisticsPage.kt` | 6 |
| statistics | [StatisticsAnalysisPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsAnalysisPage.kt) | `StatisticsAnalysisPage` | `pages/statistics/StatisticsAnalysisPage.kt` | 6 |
| statistics | [单节课明细](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSessionPage.kt) | `StatisticsSessionPage` | `pages/statistics/StatisticsSessionPage.kt` | 4 |
| statistics | [统计设置](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSettingsPage.kt) | `StatisticsSettingsPage` | `pages/statistics/StatisticsSettingsPage.kt` | 4 |

## 导入（g1 / g2）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| import | [AI 课表图片识别导入](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/AiImageCourseImportPage.kt) | `AiImageCourseImportPage` | `pages/import/warehouse/AiImageCourseImportPage.kt` | 5 |
| import | [.ics 日历导入](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/IcsImportPage.kt) | `IcsImportPage` | `pages/import/IcsImportPage.kt` | 5 |
| import | [导入课程](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/ImportEntryPage.kt) | `ImportEntryPage` | `pages/import/ImportEntryPage.kt` | 6 |
| import | [表格导入](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/SpreadsheetImportPage.kt) | `SpreadsheetImportPage` | `pages/import/SpreadsheetImportPage.kt` | 6 |
| import | [适配器详情](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterDetailPage.kt) | `WarehouseAdapterDetailPage` | `pages/import/warehouse/WarehouseAdapterDetailPage.kt` | 7 |
| import | [教务系统导入](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCourseImportPage.kt) | `WarehouseCourseImportPage` | `pages/import/warehouse/WarehouseCourseImportPage.kt` | 7 |
| import | [自定义脚本调试记录管理](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCustomDebugPage.kt) | `WarehouseCustomDebugPage` | `pages/import/warehouse/WarehouseCustomDebugPage.kt` | 5 |
| import | [WarehouseNoTargetPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt) | `WarehouseNoTargetPage` | `pages/import/warehouse/WarehouseWebLoginHost.kt` | 0 |
| import | [学校适配器列表](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt) | `WarehouseSchoolAdaptersPage` | `pages/import/warehouse/WarehouseSchoolAdaptersPage.kt` | 6 |
| import | [网页登录导入](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt) | `WarehouseWebLoginPage` | `pages/import/warehouse/WarehouseWebLoginPage.kt` | 0 |

## 迁移与导出（g3）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| export | [导出日历](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/export/IcsExportPage.kt) | `IcsExportPage` | `pages/export/IcsExportPage.kt` | 6 |
| transfer | [数据备份与迁移](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferPage.kt) | `DataTransferPage` | `pages/transfer/DataTransferPage.kt` | 4 |
| transfer | [局域网编辑](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditPage.kt) | `LanEditPage` | `pages/transfer/LanEditPage.kt` | 5 |
| transfer | [取件码](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/PickupCodesPage.kt) | `PickupCodesPage` | `pages/transfer/PickupCodesPage.kt` | 5 |
| transfer | [二维码扫码接收](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferScanPage.kt) | `QrTransferScanPage` | `pages/transfer/QrTransferScanPage.kt` | 5 |
| transfer | [二维码发送](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferSendPage.kt) | `QrTransferSendPage` | `pages/transfer/QrTransferSendPage.kt` | 5 |

## 同步与备份（f）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| sync | [云备份列表](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt) | `CloudBackupListPage` | `pages/sync/CloudBackupListPage.kt` | 7 |
| sync | [云同步](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncPage.kt) | `CloudSyncPage` | `pages/sync/CloudSyncPage.kt` | 7 |
| sync | [情侣课表设置](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsPage.kt) | `CoupleTimetableSettingsPage` | `pages/sync/CoupleTimetableSettingsPage.kt` | 5 |

## 实时显示（j）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| live | [超级岛](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsPage.kt) | `DisplaySettingsPage` | `pages/live/DisplaySettingsPage.kt` | 8 |
| live | [后台保活子屏](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/LiveKeepAliveSettingsPage.kt) | `LiveKeepAliveSettingsPage` | `pages/live/LiveKeepAliveSettingsPage.kt` | 5 |
| live | [提醒时间子屏](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/live/ReminderTimingPage.kt) | `LiveReminderTimingPage` | `pages/live/ReminderTimingPage.kt` | 4 |

## 设置（b）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| settings | [AppearanceEditorScreen](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/AppearanceEditorScreen.kt) | `AppearanceEditorScreen` | `pages/settings/AppearanceEditorScreen.kt` | 5 |
| settings | [玻璃坞底栏按钮编辑器](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt) | `GlassDockEditorScreen` | `pages/settings/DockMenuEditors.kt` | 5 |
| settings | [GlassDockIconPickerScreen](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/GlassDockIconPickerScreen.kt) | `GlassDockIconPickerScreen` | `pages/settings/GlassDockIconPickerScreen.kt` | 5 |
| settings | [八宫格菜单按钮编辑器](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt) | `HomeMenuEditorScreen` | `pages/settings/DockMenuEditors.kt` | 4 |
| settings | [SettingsPageScreen](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt) | `SettingsPageScreen` | `pages/settings/SettingsPageRenderers.kt` | 4 |
| weather | [选择城市](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerPage.kt) | `WeatherCityPickerPage` | `pages/weather/WeatherCityPickerPage.kt` | 9 |

## 帮助与展示（i）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| guide | [澎湃 UI 组件库](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/HyperosShowcasePage.kt) | `HyperosShowcasePage` | `pages/guide/HyperosShowcasePage.kt` | 3 |
| guide | [全部功能目录全览](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/MoreFeaturesPage.kt) | `MoreFeaturesPage` | `pages/guide/MoreFeaturesPage.kt` | 4 |
| guide | [启动引导流程页面](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/StartupFlowPage.kt) | `StartupFlowPage` | `pages/guide/StartupFlowPage.kt` | 7 |
| guide | [用户指南 / 新手引导](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt) | `UserGuidePage` | `pages/guide/UserGuidePage.kt` | 4 |
| showcase | [Miuix 展示册](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/showcase/MiuixShowcasePage.kt) | `MiuixShowcasePage` | `pages/showcase/MiuixShowcasePage.kt` | 4 |

## 诊断（h）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| diagnostics | [诊断日志查看器](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveDiagnosticsLogPage.kt) | `LiveDiagnosticsLogPage` | `pages/diagnostics/LiveDiagnosticsLogPage.kt` | 7 |
| diagnostics | [临时测试课程](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveTestingFixturePage.kt) | `LiveTestingFixturePage` | `pages/diagnostics/LiveTestingFixturePage.kt` | 5 |
| diagnostics | [内存统计](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/MemoryStatsPage.kt) | `MemoryStatsPage` | `pages/diagnostics/MemoryStatsPage.kt` | 7 |
| diagnostics | [性能报告](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfReportPage.kt) | `PerfReportPage` | `pages/diagnostics/PerfReportPage.kt` | 7 |

## 关于（a）

| 域 | 页面 | 入口函数 | 文件 | 预览 |
|---|---|---|---|---|
| about | [关于软件](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt) | `AboutStaticPage` | `pages/about/AboutStaticPage.kt` | 4 |
| about | [AboutUpdatePage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt) | `AboutUpdatePage` | `pages/about/AboutUpdatePage.kt` | 7 |
| about | [高级选项](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AdvancedOptionsPage.kt) | `AdvancedOptionsPage` | `pages/about/AdvancedOptionsPage.kt` | 5 |
| about | [更新日志](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt) | `ChangelogPage` | `pages/about/ChangelogPage.kt` | 4 |
| about | [代码贡献者](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ContributorsPage.kt) | `ContributorsPage` | `pages/about/ContributorsPage.kt` | 9 |
| about | [OpenSourceLicenseDetailPage](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt) | `OpenSourceLicenseDetailPage` | `pages/about/OpenSourceLicensesPage.kt` | 3 |
| about | [开源许可](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesPage.kt) | `OpenSourceLicensesPage` | `pages/about/OpenSourceLicensesPage.kt` | 6 |
| about | [支持作者](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt) | `SupportCreatorPage` | `pages/about/SupportCreatorPage.kt` | 7 |
| feedback | [问题反馈](../../android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/feedback/FeedbackPage.kt) | `FeedbackPage` | `pages/feedback/FeedbackPage.kt` | 5 |

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
