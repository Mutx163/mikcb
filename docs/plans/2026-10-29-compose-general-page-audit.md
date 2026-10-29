# 通用设置页（`b.general`）重构质量审核 + 补齐

- 日期：2026-10-29
- 对象：`lib/screens/settings/settings_general.dart`（Flutter 原件） ⇄
  `SettingsGeneralPage.kt` + `SettingsPageBridge.kt` + `SettingsHost.kt` + `SettingsPageRenderers.kt`（Compose 迁移版）
- 详细底稿（逐条带两侧行号）：
  - 功能闭环：`.agents/compose-phase3/audits/general-behavior-audit.md`
  - 视觉/尺寸：`.agents/compose-phase3/audits/general-visual-audit.md`
- 落地笔记：`.agents/notes/implemented/compose-phase35-settings-general-autorefresh.md`

## 一、审核结论（改之前）

| 维度 | 结论 |
|---|---|
| 结构 | 屏上只有 4 行（语言 / 转场速度 / 震动 / 下拉导入）。Flutter 原件里最长的一块「课表自动更新」（分组标题 + 5 行 + 底部灰字）**整块不渲染** |
| 功能 | **真正闭环 0 项**：4 行都能写盘并在屏上回显，但全仓**没有任何一处**读这四个值去改变行为（语言不换、转场不变、震动不关、首页没有下拉手势） |
| 视觉 | P0 × 1（上面的整块缺失）+ P1 × 6（分组卡圆角 24 vs 16、行标题 w500 vs w400、分组标题左缘 16 vs 32、行垂直内边距 16 vs 13、转场滑杆右侧少 chevron、顶栏缺磨砂/正文不穿过）；底色/字号/开关尺寸/折叠栏等 30 余项已一致 |
| 写盘策略 | 滑杆**每拖动一 tick 就在主线程同步 `commit()` 一次**（Dart 是 250ms 防抖 + 离页 flush）；写失败**完全静默**（Dart 会提示并把草稿拉回真值） |

## 二、这一批改了什么

1. **「课表自动更新」整块接活**（P0）
   - 新增 `CourseAutoRefreshStore`：配置 `course_auto_refresh_v1`（JSON）+ 台账
     `course_auto_refresh_last_success_v1` / `_last_attempt_v1`（epoch 毫秒），键名与值类型逐字对齐 Dart；
   - 桥新增 `toAutoRefreshState(...)`，`toSettingsPageState` 收 `autoRefresh` 参数（原来是写死 null）；
   - 宿主读 store → 喂状态 → 整块按真值渲染；五行走独立写路径（开关 / 档位 / 间隔 / 定时 / 立即试一次）；
   - 定时行弹官方 `NumberPicker` 双列滚轮（时 0–23 / 分 0–59，补零，对应 Dart `showMiuixTimePickerSheet`）；
   - 「立即试一次」**不假装能跑**：执行器（无头 WebView 回放教务宏）还没随壳迁移，点下去给一句实话
     （标题「立即试一次」+ 正文取 ARB 已有的 `aboutUnavailable`）。开关/档位/时刻是真的写盘的，执行器一到位就能跑。
2. **转场速度真的生效**：壳里 `NavTransitions.MiuixDefault` 外包一层**只改时长**的委托转场
   （500ms / speed，clamp 0.5–2.5，几何与官方预设逐字相同）；设置页拖滑杆当场广播，不用重启。
3. **震动总开关真的生效**：壳根部按开关把 `LocalHapticFeedback` 换成空实现 ⇒ miuix 组件自带的
   滚轮/滚到底触感一起静音，不用逐个调用点判开关。
4. **滑杆防抖 + 离页 flush**：250ms 一次落盘（与 Dart 同一个数），拖动中只改内存。
5. **写失败/未识别不再静默**：`Ignored` 落 logcat；自动更新的落盘失败会保留屏上旧值并记日志。

## 三、还没通的（结构性的，不是遗漏）

| 项 | 为什么现在通不了 |
|---|---|
| 语言下拉 | Compose 壳**没有本地化**：`ArbText` 只有 `zh` 一个字段，`values-en/ja/…` 只覆盖通知与小组件，全仓没有 `setApplicationLocales`。要生效得先搬一份 Kotlin 文案表 —— 属单独一批 |
| 首页下拉快捷导入 | Compose 首页**没有下拉手势**（`TimetableWeekPage` 的已知未复刻清单里就写着），开关写了没人读 |
| 「立即试一次」真跑 | 缺三个件：后台导入执行器、真实登录页（现在是 `example.com` 演练壳）、宏记录存储格式（Kotlin 侧 0 命中） |
| 视觉 P1 五条（圆角/字重/缩进/内边距/chevron/顶栏磨砂） | 都落在 `SettingsPageRenderers.kt` 或 miuix 内部默认值上，而该文件当时正被另一条泳道改写（+163 行）。**动它之前先 `git status`**。圆角那条的真相：Flutter 设置组走 `MiuixCardDefaults.cornerRadius = 16`，`settingsGroupRadius = 24` 现在只被 `HyperosTokens.cardRadius`（QR 传输等自绘卡）用 —— 别直接改 `QingyuShapes.SETTINGS_GROUP_RADIUS` |

## 四、验证状态

- **JVM 单测**：`pages/settings` L0（带 `SettingsPageBridge.kt` 等三个 ExtraSources）
  → `Tests run: 642`，失败 2 条全在 `HolidayEditorLogicTest`（别的泳道在途）；
  本批新增 `SettingsAutoRefreshStateTest`（9 例）全绿；`pages/import` L0 `OK (240 tests)`。
- **编译（L1）**：本批文件的错误已清零；当时全仓仍有其它泳道在途文件的编译错误
  （`PerfProbe` / `TimeSchemeHost` / `LiveTestingFixtureHost` / `CourseActionSheet` 调用点），
  所以**本批不宣称 L1 全绿**。
- **真机**：未验。要用户按 `docs/plans/2026-10-27-compose-phase3-l4-checklist.md` 在 `dev` 壳里逐项对照：
  1) 通用页往下滚，能看到「课表自动更新」整块；2) 开关→档位→间隔/定时联动；
  3) 定时行弹双列滚轮；4) 「立即试一次」弹说明；5) 返回再进，设置仍在；
  6) 拖转场速度滑杆，随后进出页面，动画快慢跟着变；7) 关掉震动后滚轮与滚到底不再震。
