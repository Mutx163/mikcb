# Compose 迁移 · 现状交接（2026-11-03）

> 给下一班人（或另一台机器）的一页纸。先读这页，再按需进 [派工大表](2026-10-28-compose-master-dispatch-table.md)、
> [页面台账](2026-10-26-compose-phase3-page-ledger.md)、[弹窗审计](2026-11-02-compose-dialog-full-audit.md)。
> 本文只陈述**当日核实过**的状态，每条带出处；本文落笔时工作区有多路并行改动在途（见「仍在途」）。

## 一、四道门最后一次可考结果（本文未重跑，均为书面证据）

| 门 | 最后一次结果 | 出处 / 时间 |
|---|---|---|
| L0 模块单测 | 各域随批交付时绿；**`pages/timetable` 域 L0 当前跑不起来**（跨域引用，见「仍缺 ②」） | `206a10df`（timetable 9 条探针）、`da42188c`（course 域探针复绿），2026-11-03 |
| L1 编译 | 分支顶曾经断裂（`QingyuTheme.primary` 签名变更撞了旧调用），已修（`37c59d44`，2026-11-03）；此后 `da42188c` 收口时守卫复绿 | `37c59d44` 提交说明，2026-11-03 |
| L2 全量单测 | 5569 例全绿（此后又落了多批提交，**本文之后最新状态需重跑确认**） | 2026-11-01 Lead 重跑，台账 §9.10 |
| L4 真机逐页对照 | **0 页**，仍归用户 | 台账 §9.8⑤、派工大表 §五 |

三套棘轮账（只减不增，均为 2026-11-03 实测文件内容）：

| 账 | 状态 |
|---|---|
| 文案三本账（超宽 / 死键 / 复述） | **全部清零**，三份基线只剩注释头（超宽 203 条 `5f21e99a`；死键末条随键删；复述 0 条） |
| 页面样式基线 21 域 | **0 待还债**；仅 timetable 9 条例外（7×R5 用户数据色 + 2×R2 结构性，均注明原因，`206a10df`） |
| 弹层守卫基线（app/course 两域） | **0 存量**（最后一行 ClassAlarmSheet S1D 由 `da42188c` 删除） |

## 二、近期已完成的大项（都已提交，别再当缺口做）

| 大项 | 证据 |
|---|---|
| 正式包入口切 Compose 壳 | `1158ee20`（回退方式在 `main/AndroidManifest.xml:159-160` 注释） |
| 云备份恢复改两步制：先算差异概要 → 确认 → 写回同一份快照字节；撤销入口可用 | `27f8ac2e`/`8ee25744`/`c6e374cd`/`f11b5be6` + 撤销 `bc0a02c6`（`CloudSyncController.kt:463-485`、`:587`） |
| 局域网：导入撤销端点 + 整份快照恢复放行（分层拒绝矩阵）+ 预演标记 | `eb32ae25`/`45cfb149`/`6c4a40dd`（`LanTransferLogic.kt:118`） |
| 单节课提醒 `classReminders` 全链：字段 → 统计/课卡 → 课程弹层「已设提醒 + 取消」→ 壳侧回调 | `50e8af4c` + `7adf26a2` |
| 通知换通道收口：壳侧 `POST_NOTIFICATIONS` + 四处点击 Intent 走 `NotificationLaunchTarget`（含超级岛） | `bd1bbeb0`（`NotificationLaunchTarget.kt:35-49`，六处引用已核） |
| 弹窗全量审核 138 条 + 大批修复 | 审计文档逐条回填，现 **107 已不成立 / 26 仍成立 / 5 部分成立**（成就 3 条 `bcbc8ab6` 修掉） |
| 教务抓课写回当前档案 | `83e8426a` |

## 三、仍缺（接手优先级大致从高到低）

1. **宽屏适配**：`AdaptiveTopAppBar` / `NavigationRail` 全仓 **0 处使用**（`QingyuPageScaffold.kt:108-110` KDoc 自认只给 `maxContentWidth` 保守增强）；方案文档正在写。
2. **`pages/timetable` 域 L0 跑不起来**：该域大量跨域引用 `pages.settings`（`HomeMaterialRenderSpec`/`SurfaceMaterialState` 等）与 `pages.shell`（`HomeBackgroundModel` 等），`-Module pages/timetable` 只编本目录 ⇒ 跨域符号 Unresolved。需要 Lead 定方案（挪文件 / 扩源集 / 换宿主域）。
3. **三件进行中**（工作区在途，认领后再动）：截屏后提示面板（`ScreenshotSharePromptHost.kt`）、教务网页原生 confirm/prompt/单选对话框（`WarehouseBridgeDialogHost.kt`）、埋点管道（core+接线已提交 `b9e5cdb6`/`9cd1e337`，落位仍在调整）。
4. **I2 剩余**：`saveCourseConfig`/`savePresetTimeSlots` 落盘、「替换/合并」与开学日/周次映射弹窗。
5. **弹窗审计仍成立 26 条**：多为已拍板保留或等上游组件能力；真实待修集中在**云备份详情弹层整组 4 条**（条件挂载退场 / 正文左对齐 / 动作顺序反 / 静态 show）与情侣 WebDAV 连接弹层 2 条。
6. **超级岛**：展示层方案 `P3-L` ⏸ 待拍板（RemoteViews vs Glance）；壳当前不读通知 Intent 的页面参数，点通知落默认主屏。

## 四、需要人（用户）做的事

- **L4 真机逐页对照**（最大缺口，0 页）：`dev` 变体壳里 89 条入口逐页走；已知必验点——扫码取景/解码、WebDAV 全链（上传→下载→冲突）、通知点击落页、键盘不顶按钮、矮屏弹窗不裁切、课卡铃铛与「已设提醒」取消。
- **L3 出包**：`flutter build apk` / `assemble*Bench` 归你跑；**性能数字只认 `Bench` 或 release**。
- 真机验证后回填台账 §9.8 式快照，别只口头说「能跑」。

## 五、需要 Lead 拍板的事

| # | 事项 | 现状 |
|---|---|---|
| 1 | 超级岛展示层（`P3-L`） | RemoteViews vs Compose Glance，未定 |
| 2 | 弹窗拍板 #1 追问：课表管理新建/重命名已加的自动聚焦是否回退 | 与「默认不加」分裂 |
| 3 | `src/perf/AndroidManifest.xml` 是否删除 | 启动页上移后疑似多余（未删，工作区未提交） |
| 4 | F24 C 线 `transformable` 手势的 miuix-first 例外登记 | 登记表尚未写入，待用户确认 |
| 5 | `pages/timetable` L0 跨域引用的解法 | 挪文件 / 扩源集 / 换宿主域，三选一 |
| 6 | 宽屏适配方案 | 文档编写中，出稿后拍板 |
| 7 | R2 删 Flutter 时机 | 等真机对照走完 + Phase 4 剩余收口（回退窗口在 Phase 5 才关） |

## 六、仍在途（本文落笔时工作区的未提交改动，属其他会话，勿动勿并）

`TimetableHost.kt`/`TimetableRepository.kt`/`TimetableSettingsModel.kt` 等大量 `M`（通知调度器族、widget 字符串、埋点三文件搬移 D+??、`ScreenshotSharePrompt*`、`WarehouseBridgeDialog*` 未跟踪）——均为进行中泳道的现场；开工先 `git status` 避让，提交一律路径限定。
