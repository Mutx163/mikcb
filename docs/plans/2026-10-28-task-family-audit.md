# 「任务清单」页族 · 迁移质量审核与完善（2026-10-28 夜）

> **范围**：任务清单列表页 `TaskListPage` + 添加/编辑任务表单 `AddTaskPage` + 两个子弹层
> `TaskPickerSheets`（选课程 / 选日期）。
> **对照物**：Flutter `lib/screens/task_list_screen.dart`(524) / `add_task_screen.dart`(467)。
> **被审对象**：`composeP1/.../pages/task/*`（渲染层）+ `main/.../pages/task/*`（模型/控制器）。

---

## 一、结论

**页面骨架、模型/控制器层已经很扎实**（`TaskListController` 之前已接真仓储，`TaskModel`/`TaskFilterLogic`/
`AddTaskFormReducer` 判据齐全且有 24 例单测）。**本轮真正的缺口集中在「壳接线 + 渲染层交互」**：
课程筛选点了没反应、编辑既有任务没接、看课程入口不显示、删除没有二次确认、勾选/删除落盘失败无提示。
以上五类已在可控范围内补齐。

---

## 二、逐页缺口矩阵

| # | 子功能 | Flutter | 本轮前 Compose 现状 | 严重度 | 本轮处理 |
|---|---|---|---|---|---|
| 1 | 日期分段（全部/今日/本周） | 有 | ✅ 已实现 | — | — |
| 2 | **课程筛选弹层** | `_pickCourseFilter`（全部/无/各课程名） | ❌ `onCourseFilterClick={}` 点了没反应 | P0 | ✅ 复用 `TaskCoursePickerSheet`（加 `title` 参数）弹层 + `controller.courseOptions()/setCourseFilter` |
| 3 | 任务分组（已逾期/清单/已完成）× 行内勾选/课时直达 | 有 | ✅ 分组在；勾选真写库；**课时直达没接** | P1 | ✅ `onViewCourse` 接 `wiring.pendingEditCourse → d1.addCourse` |
| 4 | **点行编辑既有任务** | `_editTask → AddTaskScreen(task:)` | ❌ `onEditTask={}` 点了没反应 | P0 | ✅ 新增 `AddTaskFormReducer.initialFromTask` + `ShellWiring.pendingTaskForEdit` + 壳编辑路径（保存走 `updateTask`） |
| 5 | **删除二次确认** | `showHyperosConfirmDialog`（列表长按/侧滑 + 编辑页删除） | ❌ 删除按钮直接删，无确认 | P1 | ✅ 列表页 + 编辑页各加 `OverlayDialog` 确认（取消/删除） |
| 6 | 勾选/删除失败提示 | `showAppToast(saveFailed)` | ❌ 异常无人接、勾选框静默弹回 | P1 | ✅ 壳里 `runCatching` + `Toast`（勾选/删除/保存） |
| 7 | 保存错误区分 | task_title_required / task_course_not_found / saveFailed | 仅标题必填 | P2 | ✅ 保存失败走 `TaskFilterLogic.mapSaveError` Toast 三态 |
| 8 | 子弹层：选课程 / 选日期 | 有 | ✅ 已实现（日期用 ± 步进而非滚轮） | — | 见「诚实清单」 |
| 9 | 纯新建自动聚焦标题 | `autofocus` | ❌ Compose 未请求焦点 | P3 | 未做（见诚实清单） |

---

## 三、本轮已落地

| 文件 | 改动 |
|---|---|
| `main/.../pages/task/AddTaskFormReducer.kt` | 新增 `initialFromTask(task, courses)`：编辑态载入原任务全字段（标题/备注/课程/周次/到期日/完成态），空标题退「课程作业」兜底，编辑不抢焦点 |
| `composeUi/.../pages/ShellWiring.kt` | 新增 `pendingTaskForEdit: CourseTask?`；「从课程加作业」路径顺手清空它（防串味） |
| `composeP1/.../pages/task/TaskPickerSheets.kt` | `TaskCoursePickerSheet` 增加 `title` 参数（表单=来源课程 / 筛选=课程筛选，复用同一弹层） |
| `composeP1/.../pages/task/TaskListPage.kt` | 课程筛选弹层（内部开关 + 复用选择层）；删除二次确认 `OverlayDialog` |
| `composeP1/.../pages/task/AddTaskPage.kt` | 编辑态删除按钮改为**先弹确认**再删（对齐 Dart `_confirmDelete`） |
| `composeUi/.../pages/ShellPageIndex.kt` | `d2.taskList`：接课程筛选、编辑跳转、课时直达、勾选/删除失败 Toast；`d2.addTask`：编辑/新建两路初始化，保存走 `updateTask`/`addTask`，删除确认后 `deleteTask`，保存失败三态 Toast |
| `test/.../pages/task/AddTaskFormReducerEditTest.kt` | 新增 2 例契约测试（编辑载入字段 / 空标题兜底），含咬合探针 |

---

## 四、验证（口径：只声明编译过 + JVM 单测过，未真机）

- **L0** `pwsh scripts/test-kotlin-module.ps1 -Module "pages/task"` → **OK (26 tests)**（原 24 + 新增 2）。
- **咬合探针**：把 `initialFromTask` 的 `note = task.note.orEmpty()` 改成 `note = ""` → 立即 **1 例红**；还原后 26 全绿（证明新测试有牙齿）。
- **L1** `pwsh scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin` → **BUILD SUCCESSFUL**。
- **样式守卫** `compose-style-lint -Domain task` → **0 违规**。
- **真机未验**（无设备控制权限）。

---

## 五、诚实清单（没做到 / 只到「编译+单测」）

1. **侧滑删除 / 长按删除**：Dart 用 `Dismissible` 侧滑 + 长按；Compose 目前是**行内可见删除按钮 + 二次确认**（比「藏起来的长按」更易发现），**没有做侧滑手势**。
2. **日期选择器是滚轮**：Dart 用 `MiuixFlingNumberPicker` 惯性滚轮；miuix 0.9.4 Kotlin 侧无滚轮控件，Compose 用**年/月/日 ± 步进**（`TaskPickerSheets` 已注明，语义一致、交互形式不同）。
3. **纯新建自动聚焦标题**：Dart 纯新建会弹键盘聚焦标题；Compose 未接 `FocusRequester`（多一次点击，不影响功能）。
4. **保存图标**：官方图标包里没有「对勾」图标，暂用近似矢量（不影响功能）。
5. **查看课程**：跳到课程编辑页 `d1.addCourse`（与课程总览一致），但**没有**像 Dart 那样带 `initialWeek` 高亮到来源周。
6. **真机**：以上全部需在 composeUi 壳里点一遍（勾选/删除/筛选/编辑/看课程），归用户 L4。
