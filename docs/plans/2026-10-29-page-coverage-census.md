# 全仓页面覆盖普查：哪些页单独修过、哪些还没覆盖

> 生成时间 2026-10-29 20:05（快照，工作区仍在动）
> **只读普查**：全部结论来自 `ShellPageIndex.kt`（87 条可进入路由）逐条的代码实况，
> 不采信台账/派工表里的旧状态字（那些已被证明会过期）。

## 一、口径

| 项 | 数 |
|---|---|
| 页面单元总数（`ShellPageCatalog`） | **88** |
| 其中可进入路由（`ShellPageIndex.kt` 的分派分支） | **87** |
| 其中常驻底栏（不是独立页） | 1 |

**「单独修过」的判据**：有专门为这一页/这一族做过的审核文档，或有提交标题点名这一页/这一族的「迁移/接线/修复/复刻」。**仅样式对齐、仅字阶替换不算**（那是批量改，不是针对这页的功能修复）。

**「现状」四档**：

- ✅ **真**：数据来自真仓储/系统服务，按钮有真落点（或页面自带数据源）。
- ⚠️ **半接**：主链路是真的，但仍有明显的空按钮或占位文案。
- ❌ **死**：壳里喂的是默认 state / `emptyList()` / 演示对象，或关键回调是空实现——点进去是空页。
- ▫️ **静态**：组件展示册一类，本来就没有数据与动作。

## 二、总数（先看这张）

| 维度 | 数 | 占 87 |
|---|---|---|
| **做过单独修复** | **47** | 54% |
| 没被单独修过 | **40** | 46% |
| 其中：现在真的能用 | 46 | 53% |
| 其中：半接（还有空按钮） | 6 | 7% |
| 其中：仍是死的 | 33 | 38% |
| 其中：静态页（无需接线） | 2 | 2% |

### 交叉表：修没修过 × 现在活没活

| | ✅ 真 | ⚠️ 半接 | ❌ 死 | ▫️ 静态 | 小计 |
|---|---|---|---|---|---|
| 修过 | 38 | 5 | 4 | 0 | **47** |
| 没修过 | 8 | 1 | 29 | 2 | **40** |
| **合计** | **46** | **6** | **33** | **2** | **87** |

**一句话读法**：修过的 47 页里有 38 页真的活了；没修过的 40 页里只有 8 页碰巧本来就真，其余 **29 页还是死的**。

## 三、按域汇总

| 域 | 页数 | 真 | 半接 | 死 | 静态 | 修过 |
|---|---|---|---|---|---|---|
| a 关于与说明 | 6 | 4 | 0 | 2 | 0 | 6 |
| b 设置族 | 25 | 14 | 0 | 11 | 0 | 11 |
| c 课表视图 | 4 | 3 | 1 | 0 | 0 | 4 |
| d 课程/日程/作息考试 | 12 | 10 | 0 | 2 | 0 | 10 |
| e 统计族 | 4 | 3 | 1 | 0 | 0 | 2 |
| f 同步与备份 | 3 | 1 | 2 | 0 | 0 | 3 |
| g1-g2 导入与教务适配 | 9 | 0 | 1 | 8 | 0 | 1 |
| g3 导出与传输 | 6 | 3 | 0 | 3 | 0 | 4 |
| h 诊断 | 4 | 4 | 0 | 0 | 0 | 4 |
| i 引导与展示 | 6 | 1 | 1 | 2 | 2 | 1 |
| j 实时活动与天气 | 6 | 2 | 0 | 4 | 0 | 1 |
| k 冲突与反馈 | 2 | 1 | 0 | 1 | 0 | 0 |

## 四、逐页明细（87 条）

### a 关于与说明（6 页：真 4 / 半 0 / 死 2 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `a.about` | 关于主页 | ✅ 真 | 是 | 关于页族审核 + 10 入口接 onOpenPage |
| `a.changelog` | 更新日志 | ✅ 真 | 是 | 关于页族审核（读 assets 真发布说明） |
| `a.licenses` | 开源许可 | ✅ 真 | 是 | 关于页族审核 + OpenSourceLicensesHost 读真 LicenseRegistry |
| `a.update` | 版本更新 | ✅ 真 | 是 | 「版本更新页 1:1 复刻」批次（a7e57f51 / 7ae6264a） |
| `a.support` | 支持作者 | ❌ 死 | 是 | 关于页族审核点名；鸣谢网络服务未移植，donorData=null、onReload 空 |
| `a.contributors` | 代码贡献者 | ❌ 死 | 是 | 关于页族审核新增整页；仓储服务未移植，maintainers=emptyList() |

### b 设置族（25 页：真 14 / 半 0 / 死 11 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `b.settingsHome` | 设置首页/课表设置 | ✅ 真 | 是 | 415184e0 换真宿主 |
| `b.semester` | 设置·学期 | ✅ 真 | 是 | 62417867 / 415184e0 / 1813c821 |
| `b.general` | 设置·通用 | ✅ 真 | 是 | 通用设置页审核 + 1703478d |
| `b.appearance` | 设置·外观 | ✅ 真 | 是 | c8a9a081 设置族 4 页改真宿主 |
| `b.theme` | 设置·主题 | ✅ 真 | 是 | c8a9a081 |
| `b.courseCard` | 设置·课程卡 | ✅ 真 | 是 | c8a9a081 |
| `b.timetablePage` | 设置·课表页 | ✅ 真 | 是 | f4b12e96 显示偏好改读用户存档（S1） |
| `b.holiday` | 设置·节假日 | ✅ 真 | 是 | 2083fa08 节假日页复刻 |
| `b.holidayAdvanced` | 设置·节假日高级 | ✅ 真 | 是 | 2083fa08 |
| `b.weather` | 设置·天气 | ✅ 真 | 是 | weatherProvider 真天气源 + 天气审核（_AUDIT-weather） |
| `b.diagnostics` | 设置·诊断 | ✅ 真 | 是 | 诊断族审核 + 2d171f22 |
| `b.homeNavigation` | 设置·首页导航 | ✅ 真 | — | 已传 wiring.settingsModel 真宿主，但无单独修复批次 |
| `b.homeMenuEditor` | 设置·首页菜单编辑 | ✅ 真 | — | HomeMenuEditorHost(store) 真宿主，无单独修复批次 |
| `b.glassDock` | 设置·玻璃底栏 | ✅ 真 | — | GlassDockEditorHost(store) 真宿主，无单独修复批次 |
| `b.appearanceEditor` | 设置·外观编辑 | ❌ 死 | — | SettingsScreen(spec(SettingsPageState()))：空 state |
| `b.materialGeneral` | 设置·材质-通用 | ❌ 死 | — | 空 state |
| `b.materialCourseCard` | 设置·材质-课程卡 | ❌ 死 | — | 空 state |
| `b.backdropFlow` | 设置·背景流转 | ❌ 死 | — | 空 state |
| `b.recentWallpaper` | 设置·最近壁纸 | ❌ 死 | — | 空 state |
| `b.bingGallery` | 设置·必应壁纸 | ❌ 死 | — | 空 state |
| `b.homeWidget` | 设置·桌面小组件 | ❌ 死 | — | 空 state |
| `b.live` | 设置·实时活动 | ❌ 死 | — | SettingsLivePage.spec(SettingsPageState())：只有导航是真的 |
| `b.liveSelfCheck` | 设置·实时活动自检 | ❌ 死 | — | 空 state |
| `b.glassDockIcon` | 设置·底栏图标编辑 | ❌ 死 | — | 空 state |
| `b.reset` | 设置·重置 | ❌ 死 | — | 空 state（重置动作没接） |

### c 课表视图（4 页：真 3 / 半 1 / 死 0 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `c1.week` | 课表·周视图 | ✅ 真 | 是 | 周视图审核 + a3902f85 复刻 + 962a534b 课程弹层 |
| `c1.profiles` | 课表·档案管理 | ✅ 真 | 是 | T2：b4c03731 / 4bb8f0da 接真仓储 |
| `c2.month` | 课表·月视图 | ✅ 真 | 是 | 916dc3b3 解除不可用并接真数据 |
| `c3.day` | 课表·日视图 | ⚠️ 半接 | 是 | 1e4c57b7 接真课表；但日程条数与日程项仍写死 0 |

### d 课程/日程/作息考试（12 页：真 10 / 半 0 / 死 2 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `d1.addCourse` | 加课/编辑课表单 | ✅ 真 | 是 | 8e140fb7 + 56cc5fab / 78abfc53 收口 |
| `d1.overview` | 课程概览 | ✅ 真 | — | 传 wiring 真宿主，无单独修复批次 |
| `d2.scheduleList` | 日程列表 | ✅ 真 | 是 | 1cfbd360 日程域接真数据 |
| `d2.addSchedule` | 新建/编辑日程 | ✅ 真 | 是 | 1cfbd360 |
| `d2.dateRule` | 日程日期规则 | ✅ 真 | 是 | 1cfbd360 + ScheduleDateRuleHost |
| `d2.taskList` | 任务清单 | ✅ 真 | 是 | 任务族审核 + fc2c4520（仅剩 onCourseFilterClick 一个空回调） |
| `d2.addTask` | 新建/编辑任务 | ✅ 真 | 是 | 任务族审核 + 8a1270be 两个子弹层 |
| `d3.timeSchemes` | 时间模板 | ✅ 真 | 是 | 时间模板审核 + 9c2ec06a / 28d703b7 |
| `d3.timeSchemeEditor` | 编辑节次 | ✅ 真 | 是 | 时间模板审核（整屏新建） |
| `d3.examList` | 考试列表 | ✅ 真 | 是 | 0f160480 接真仓储 |
| `d3.locationMatch` | 地点作息匹配 | ❌ 死 | 是 | 时间模板审核点名「仍是演示数据」，模型空 + 5 个空回调 |
| `d3.addExam` | 加考试 | ❌ 死 | — | AddExamViewState(isEditing=false) + 14 个空回调 |

### e 统计族（4 页：真 3 / 半 1 / 死 0 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `e.statisticsSettings` | 统计·设置 | ✅ 真 | 是 | 32d30365 周报开关接活 |
| `e.analysis` | 统计·深度分析 | ✅ 真 | — | 已读 StatisticsFeed 真数据，无单独修复批次 |
| `e.session` | 统计·单节课明细 | ✅ 真 | — | 已读 StatisticsFeed 真数据，无单独修复批次 |
| `e.statistics` | 统计·主页 | ⚠️ 半接 | 是 | d8fa37a8 改读真课表；但 onOpenShare 仍是空回调 |

### f 同步与备份（3 页：真 1 / 半 2 / 死 0 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `f.couple` | 情侣课表 | ✅ 真 | 是 | 情侣课表审核 + 02698142 / c6012a18 |
| `f.cloudSync` | 云同步 | ⚠️ 半接 | 是 | 41db72ca 接 WebDAV 真收发；「备份详情」仍是 Toast 占位 |
| `f.backupList` | 备份列表 | ⚠️ 半接 | 是 | 41db72ca；「备份详情」仍是 Toast 占位 |

### g1-g2 导入与教务适配（9 页：真 0 / 半 1 / 死 8 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `g1.importEntry` | 导入入口 | ❌ 死 | — | ImportEntryViewState() 默认值 + 3 个空回调 |
| `g1.icsImport` | ICS 导入 | ❌ 死 | — | 默认 state + onChooseFile 空 |
| `g1.spreadsheetImport` | 表格导入 | ❌ 死 | — | 默认 state + 两个空回调 |
| `g2.schoolAdapters` | 学校适配器列表 | ❌ 死 | — | SHELL_DEMO_SCHOOL + adapters=emptyList() |
| `g2.adapterDetail` | 适配器详情 | ❌ 死 | — | SHELL_DEMO_SCHOOL / SHELL_DEMO_ADAPTER 演示对象 |
| `g2.warehouseImport` | 仓库导入 | ❌ 死 | — | 无参渲染 + 6 个空回调 |
| `g2.webLogin` | 教务网页登录 | ⚠️ 半接 | 是 | 50fbcc13 给了可加载地址；仍是占位 URL，网页桥接回调空 |
| `g2.customDebug` | 自定义调试 | ❌ 死 | — | 无参渲染 + 4 个空回调 |
| `g2.aiImageImport` | AI 图片导入 | ❌ 死 | — | 无参渲染 + 4 个空回调 |

### g3 导出与传输（6 页：真 3 / 半 0 / 死 3 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `g3.dataTransfer` | 数据备份与迁移 | ✅ 真 | 是 | 数据备份审核 + 7c8d11b6 逐项复刻 |
| `g3.qrSend` | 二维码发送 | ✅ 真 | 是 | 7c8d11b6 发真传输包 |
| `g3.qrScan` | 二维码扫码 | ✅ 真 | 是 | 7c8d11b6 扫码真落地 |
| `g3.icsExport` | ICS 导出 | ❌ 死 | 是 | I3 41590167 只交了模型层与分享适配器；壳里仍 10 个空回调 |
| `g3.lanEdit` | 局域网编辑 | ❌ 死 | — | LanEditModel() + 3 个空回调 |
| `g3.pickupCodes` | 取件码 | ❌ 死 | — | onEntryClick 空 |

### h 诊断（4 页：真 4 / 半 0 / 死 0 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `h.log` | 应用日志查看器 | ✅ 真 | 是 | 诊断族审核 + 141ff16d |
| `h.memory` | 内存统计 | ✅ 真 | 是 | 诊断族审核 + 57ad8ca5 |
| `h.perfReport` | 性能报告 | ✅ 真 | 是 | 诊断族审核 + 7339b35e |
| `h.fixture` | 临时测试夹具 | ✅ 真 | 是 | 诊断族审核 + 2d171f22 |

### i 引导与展示（6 页：真 1 / 半 1 / 死 2 / 静 2）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `i.userGuide` | 使用引导 | ✅ 真 | 是 | 1e4c57b7 引导接线（权限探测 + 设置读写） |
| `i.startup` | 启动引导流程 | ❌ 死 | — | StartupFlowPage(onBack) 三个关键回调走默认空实现（完成不落盘） |
| `i.more` | 全部功能 | ❌ 死 | — | MoreFeaturesWithSearch 的 onOpenFeature 是空回调 |
| `i.moreSearch` | 全部功能·搜索 | ⚠️ 半接 | — | 选中只关浮层、不跳页 |
| `i.hyperosShowcase` | HyperOS 展示册 | ▫️ 静态 | — | 组件展示页，无需接线 |
| `i2.showcase` | Miuix 展示册 | ▫️ 静态 | — | 组件展示页，无需接线 |

### j 实时活动与天气（6 页：真 2 / 半 0 / 死 4 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `j.keepAlive` | 后台保活 | ✅ 真 | 是 | c4b9bf72 开关对齐 Dart（写 SharedPreferences + appTasks） |
| `j.weatherCity` | 天气城市 | ✅ 真 | — | 传 weatherProvider 真天气源，无单独修复批次 |
| `j.live` | 实时活动·显示设置 | ❌ 死 | — | DisplaySettingsPage 三个回调走默认空实现 |
| `j.displayBefore` | 实时活动·显示前 | ❌ 死 | — | 同上 |
| `j.displayDuring` | 实时活动·显示中 | ❌ 死 | — | 同上 |
| `j.reminderTiming` | 提醒时机 | ❌ 死 | — | LiveReminderTimingPage 的 onPersist 空回调 ⇒ 改了不落盘 |

### k 冲突与反馈（2 页：真 1 / 半 0 / 死 1 / 静 0）

| 路由 | 页面 | 现状 | 单独修过 | 证据 / 缺什么 |
|---|---|---|---|---|
| `k.conflict` | 课程冲突 | ✅ 真 | — | 读仓储快照真数据，只做过样式对齐 |
| `k.feedback` | 问题反馈 | ❌ 死 | — | FeedbackPage 的 onOpenChannel / onCopyChannel 空回调 |

## 五、还是死的 33 页（下一批该修的）

按「一修就能活」的容易程度排：

| 类 | 页 | 缺什么 |
|---|---|---|
| 只差几个回调 | `j.live` `j.displayBefore` `j.displayDuring` `j.reminderTiming` `k.feedback` `i.more` `i.moreSearch` `g3.pickupCodes` `g3.lanEdit` | 页面渲染层都已就绪，只缺壳把回调接到仓储/系统服务（最省力） |
| 只差数据源 | 设置族 10 页：`b.appearanceEditor` `b.materialGeneral` `b.materialCourseCard` `b.backdropFlow` `b.recentWallpaper` `b.bingGallery` `b.homeWidget` `b.live` `b.liveSelfCheck` `b.glassDockIcon` `b.reset` | 都是 `SettingsScreen(spec(SettingsPageState()))`——一份渲染层服务 24 页，缺的是把状态换成真值 |
| 缺能力层 | `a.support`（鸣谢网络服务） `a.contributors`（仓储服务） `g1.importEntry` `g1.icsImport` `g1.spreadsheetImport`（文件选择） `g2.schoolAdapters` `g2.adapterDetail` `g2.warehouseImport` `g2.customDebug` `g2.aiImageImport` | Kotlin 侧还没移植对应的 Dart 服务/适配器 |
| 缺整块页面逻辑 | `d3.addExam`（14 个空回调 + 无编辑态） `d3.locationMatch` `g3.icsExport` `i.startup` | 渲染层在，宿主的表单状态机/落盘没接 |

## 六、诚实边界

1. **纯静态代码判读**，没有一页在真机点过。判「真」= 代码上数据和动作都有落点，   **不等于**点上去一定对；判「死」的把握更高（空回调是显式的）。
2. **「空回调」判据只看显式 `= {}` 与默认参数**。页面内部自己处理的交互（如 `d2.addTask` 的   选课程弹层由页面自己弹）会被误判，已在明细里注明。
3. 路由口径按 `ShellPageIndex.kt` 的 87 个分派分支；`ShellPageCatalog` 的 DEMO/DIRECT 标记   **已经过期不可用**（例如 P3-H 四页全标 DEMO，但 10-29 已全部接成真的）。
4. 工作区此刻仍有别的会话在改（`ShellPageIndex.kt` 有未提交改动），数字按当前文本算。
