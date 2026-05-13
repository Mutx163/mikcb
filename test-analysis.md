# 测试用例分析报告

## 总览

共 36 个测试文件，约 130+ 个测试用例。整体测试质量**较高**，覆盖了模型层、Provider 层、服务层和 Widget 层的核心功能。

---

## 一、有用的测试用例

### Models（核心数据模型，序列化/反序列化逻辑）

| # | 文件 | 评价 | 测试内容 |
|---|------|------|----------|
| 1 | `test/models/course_test.dart` | ✅ 有用 | Course.copyWith 清空可空字段、自定义周次过滤、周次描述压缩 |
| 2 | `test/models/exam_test.dart` | ✅ 有用 | ExamReminderPreset、序列化往返、缺失可选字段处理、copyWith、过期判断、倒计时 |
| 3 | `test/models/time_scheme_test.dart` | ✅ 有用 | TimeScheme 序列化、快速节次构建器、长课间覆盖规则、跨午夜校验 |
| 4 | `test/models/timetable_profile_test.dart` | ✅ 有用 | 配置文件序列化往返、currentWeek 边界钳制 |
| 5 | `test/models/timetable_settings_test.dart` | ✅ 有用（核心） | 默认值完整性验证、全部字段序列化往返、Live 显示设置独立配置、遗留间距迁移、镜像预设解析、遗留镜像前缀推断 |

### Providers（业务逻辑核心）

| # | 文件 | 评价 | 测试内容 |
|---|------|------|----------|
| 6 | `test/providers/import_dedup_test.dart` | ✅ 有用（核心） | 课程去重、同步导入（保留本地字段）、拆分周次合并、替换导入并保留本地元数据 |
| 7 | `test/providers/timetable_provider_day_view_test.dart` | ✅ 有用 | getCourseInProgress（时间匹配/不匹配/非当天）、syncTemporalContext 保持查看周次 |
| 8 | `test/providers/timetable_provider_exam_test.dart` | ✅ 有用 | 考试 CRUD、查询（按课程筛选、即将考试、下一门考试、日期匹配） |
| 9 | `test/providers/timetable_provider_profiles_test.dart` | ✅ 有用（核心，最全面） | 配置切换、周次通知、清空课程保留设置、备份导入周次钳制、冲突地图（含周次感知）、作息方案 CRUD、课时覆盖、删除锁定方案、编辑同步同名课程、Live 活动逻辑、时间校准、日历快照、调课/删课、导入扩容学期、导入替换模式 |
| 10 | `test/providers/timetable_provider_schedule_test.dart` | ✅ 有用 | 日程 CRUD、持久化、跨日日程可见性 |

### Services（服务层）

| # | 文件 | 评价 | 测试内容 |
|---|------|------|----------|
| 11 | `test/services/ai_course_import_service_test.dart` | ✅ 有用 | JSON 解析、Markdown 代码块包裹、非法字段拒绝、课程性质推断、周次表达式解析 |
| 12 | `test/services/app_update_service_test.dart` | ✅ 有用（核心，最详尽） | GitHub API 与 Releases 页面竞速、debug 后缀版本号比较、预发布版本选择、APK 资产过滤、下载取消与清理、旧 APK 清理、Range 探测降级、镜像回退链路、超时不等待、Release 页面 HTML 解析（API 403 降级） |
| 13 | `test/services/data_transfer_service_test.dart` | ✅ 有用 | 备份 JSON 保留配置名、周次钳制、完整备份保留多配置和作息方案 |
| 14 | `test/services/home_widget_snapshot_service_test.dart` | ✅ 有用 | 隐藏已完成课程、精确结束时间处理、刷新触发点包含精确结束边界 |
| 15 | `test/services/ics_import_service_test.dart` | ✅ 有用 | WakeUp 格式单周导入、连续周导入、偶数周合并、教室/教师信息提取 |
| 16 | `test/services/import_week_alignment_service_test.dart` | ✅ 有用 | 推断首课周次、周次偏移、奇偶周翻转 |
| 17 | `test/services/storage_service_profile_test.dart` | ✅ 有用（核心） | 遗留单配置迁移、配置持久化、作息方案持久化、隐藏前缀文字迁移、损坏数据备份恢复 |
| 18 | `test/services/support_creator_service_test.dart` | ✅ 有用 | 镜像优先、镜像失败回退、UTF-8 捐赠人名称解码 |
| 19 | `test/services/warehouse_import_preferences_service_test.dart` | ✅ 有用 | 安全存储记忆登录、遗留 SharedPreferences 迁移、清除安全和遗留存储 |
| 20 | `test/services/warehouse_repository_service_test.dart` | ✅ 有用 | GitHub 源解析和 Raw URL 构建、Root Index 和 Adapters Index 拉取 |

### Utils

| # | 文件 | 评价 | 测试内容 |
|---|------|------|----------|
| 21 | `test/utils/hex_color_test.dart` | ✅ 有用 | 有效/无效 hex 颜色解析和回退 |

### Widgets（UI 组件，较大文件覆盖核心交互）

| # | 文件 | 评价 | 测试内容 |
|---|------|------|----------|
| 22 | `test/widgets/about_update_action_test.dart` | ✅ 有用 | 更新操作按钮决策逻辑（平台/源/缺失资产）、镜像推荐、镜像回退 |
| 23 | `test/widgets/add_course_screen_test.dart` | ✅ 有用 | 编辑模式删除按钮、无效颜色容错、单次课默认星期、窄屏自定义周布局、范围周筛选奇偶芯片 |
| 24 | `test/widgets/course_overview_conflict_test.dart` | ✅ 有用 | 课程总览冲突标记、非重叠周次不标记 |
| 25 | `test/widgets/live_diagnostics_log_viewer_screen_test.dart` | ✅ 有用 | 日志按等级筛选、原文视图跟随筛选、导出/清空操作 |
| 26 | `test/widgets/release_notes_markdown_test.dart` | ✅ 有用 | Markdown 渲染标题/列表/链接 |
| 27 | `test/widgets/timetable_conflict_badge_test.dart` | ✅ 有用 | 冲突标记显示/隐藏、重叠课程渲染、点击展开两张卡片、非本周课程显示/重叠/最近优先 |
| 28 | `test/widgets/timetable_day_view_test.dart` | ✅ 有用（核心，最庞大 ~1900 行） | 日/周视图切换与恢复、同一/不同星期切换、添加内容面板、日程时间排序、跨日日程、进行中样式、即将结束文字、切换防闪烁、返回今天（跨周/边界滑动/即时内容更新/方向箭头）、周滑动连贯、浮动返回按钮、恢复时保留查看周、外部周同步跟随、摘要拖拽跟随、内容滑动切日、指示条跟手、连续多日滑动、边界跨周滑动、非本周课程日视图、冲突课程日视图、冲突进行中双样式、点击编辑、添加课程默认星期 |
| 29 | `test/widgets/timetable_settings_screen_test.dart` | ✅ 有用 | 诊断自动刷新、课前提醒 30-60 分钟选项 |
| 30 | `test/widgets/timetable_switcher_test.dart` | ✅ 有用 | 快速切换课表、品牌标题显示配置名、溢出菜单课表管理、切换配置恢复视图状态 |
| 31 | `test/widgets/user_guide_screen_test.dart` | ✅ 有用 | 设置页隐私说明（无勾选）、首次运行隐私勾选、自启动检测、同意并开始返回结果、前/后翻页、非同意模式无勾选 |

---

## 二、多余的/无用的测试用例

### 1. 占位/模板代码（应删除）

| # | 文件 | 问题 |
|---|------|------|
| 24 | **`test/widget_test.dart`** | **纯占位**。仅包含 `expect(true, isTrue)`，不测试任何项目功能。这是 Flutter 项目初始创建时的模板文件，应直接删除。 |

### 2. 测试过于简单/价值低（建议改进或删除）

| # | 文件 | 问题 | 建议 |
|---|------|------|------|
| 25 | **`test/widgets/course_card_test.dart`** | 仅 1 个测试用例，只验证无效颜色不崩溃。CourseCard 是高频使用的组件，但几乎无测试覆盖。 | 补充正常渲染测试（名称/教师/地点/时间段显示）、不同设置下的布局变化、边界情况（超长课程名）等。如果短期内不补充，保留现有用例也无害。 |
| 12 | **`test/services/app_log_service_test.dart`** | 仅 1 个测试用例，验证损坏 JSON 不崩溃。AppLogService 是日志基础设施，但测试仅覆盖初始化容错。 | 补充日志记录/读取/清空/导出等核心功能测试。如果短期内不补充，现有用例仍有防护价值，建议保留。 |
| 26 | **`test/widgets/course_import_screen_test.dart`** | 仅 1 个测试用例，验证 Scaffold 的 `resizeToAvoidBottomInset` 为 true。这更像是防止回归的配置检查，对业务逻辑无覆盖。 | 如果短期内不补充更实质性的导入流程测试，该用例可保留作为回归防护，但价值有限。 |

### 3. 重复测试相同功能（跨层重叠，可选择性精简）

以下情况是**正常的测试分层**（单元测试 + 集成测试），但存在冗余：

| 被测功能 | 涉及文件 | 说明 |
|----------|----------|------|
| **课程冲突检测** | `timetable_provider_profiles_test.dart`（冲突地图逻辑）<br>`timetable_conflict_badge_test.dart`（冲突标记 UI）<br>`course_overview_conflict_test.dart`（总览冲突 UI）<br>`timetable_day_view_test.dart`（日视图冲突渲染） | Provider 测逻辑正确性，Widget 测 UI 表现。重叠是合理的，但 Widget 层 4 个文件都测冲突，可考虑将 `course_overview_conflict_test.dart` 中非重叠周次测试合并到 `timetable_conflict_badge_test.dart`。 |
| **非本周课程显示** | `timetable_conflict_badge_test.dart`（3 个测试）<br>`timetable_day_view_test.dart`（1 个测试） | 两处测试内容几乎相同（非本周课程可见性、重叠只显示最近一个、"非本周"标签）。建议只保留 `timetable_day_view_test.dart` 中的用例。 |
| **Profile 切换** | `timetable_provider_profiles_test.dart`（2 个测试）<br>`timetable_switcher_test.dart`（4 个测试） | Provider 测数据层，Widget 测 UI 交互。这是合理的分层，无需精简。 |

### 4. 可能脆弱的测试（值得关注）

| # | 文件 | 问题 |
|---|------|------|
| 33 | `test/widgets/timetable_day_view_test.dart` | 大量测试依赖 `DateTime.now()` 构建"今天"的课程，导致**每天运行结果不同**。虽然使用了动态 weekday 适配，但增加了理解和维护难度。建议考虑使用固定日期 mock。 |
| 9 | `test/providers/timetable_provider_profiles_test.dart` | 部分测试依赖 `DateTime.now().add(Duration(days: N))`，在跨午夜边界运行时可能出现边界问题。 |

---

## 三、总结

### 应删除的文件

| 文件 | 理由 |
|------|------|
| `test/widget_test.dart` | 纯占位 `expect(true, isTrue)`，零价值 |

### 建议改进的文件

| 文件 | 建议 |
|------|------|
| `test/widgets/course_card_test.dart` | 补充核心渲染测试，当前仅 1 个防崩溃用例 |
| `test/services/app_log_service_test.dart` | 补充日志记录/读取/清空功能测试 |
| `test/widgets/course_import_screen_test.dart` | 补充导入流程核心交互测试 |
| `test/widgets/timetable_day_view_test.dart` | 考虑用固定日期 mock 替代 `DateTime.now()` 以提高稳定性 |

### 精简建议

| 操作 | 说明 |
|------|------|
| 合并非本周课程 UI 测试 | `timetable_conflict_badge_test.dart` 中的 3 个非本周课程测试与 `timetable_day_view_test.dart` 重复，可精简 |
| 合并冲突总览测试 | `course_overview_conflict_test.dart` 可考虑合并到 `timetable_conflict_badge_test.dart` |

### 整体评价

测试套件质量**优秀**。核心业务逻辑（导入去重、配置管理、更新检查、日视图交互）覆盖全面且深入。约 **92% 的测试文件是有价值的**，仅 `widget_test.dart` 是纯垃圾需要删除。剩余 3 个文件（course_card、app_log、course_import）虽测试用例少，但各自用例仍有防护价值，问题在于覆盖不足而非无效。
