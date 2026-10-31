# 剩余页面收尾 · 可接单任务清单（12 批次 / 39 页）

> **定位**：这份是**任务清单**，不是审核报告。审核结论与逐页证据见
> [页面覆盖普查](2026-10-29-page-coverage-census.md)。
> **读者**：任何接单的 agent —— **包括没读过本次对话的独立会话**，每一批都自带根因、写作用域、
> 验收门槛，不需要回来问。
>
> **数字口径**（快照 2026-10-29 20:25）：壳里可进入路由 **87** 条，其中
> **✅ 真 46 / ⚠️ 半接 6 / ❌ 死 33 / ▫️ 静态 2**。
> 本清单只收 **死 33 + 半接 6 = 39 页**，拆成 12 个批次，每批 1~6 页。

---

## 零、接单前 60 秒（照做，别跳）

**多个 agent 同时在线时，一律按 §七 的队列顺序抢单，算法照抄 §八。** 单干时走下面四步。

1. `ls .agents/compose-phase3/claims/` —— 有 `F<NN>-*.md` 且 `状态：进行中` = 那批有人在跑，**换一批**。
2. 按 §七 顺序挑第一个可用的，**原子新建**认领文件（`set -C` 写法见 §八；新建成功才算领到）：

   ```bash
   FILE=.agents/compose-phase3/claims/F01-live-display.md
   ( set -C; printf '# 认领：F01

- 状态：进行中
- 领用者：%s
- 领用时间：%s
'        "$ME" "$(date '+%F %H:%M %z')" > "$FILE" ) 2>/dev/null && echo WON || echo LOST
   ```

   抢到后立刻补：本批页面清单 / 写作用域 / 是否要抢共享件锁。可直接抄 `claims/_template.md`。
3. **开工前先把这一批的页面各点开看一眼根因**（本清单给了行号与证据，用 `grep -n` 复核，
   行号会漂）。根因没对上就先去认领文件里记一笔，别硬按本清单改。
4. 交付按 §三 的门槛，**证据写进认领文件、状态改成 `已交付`**；真机对照归用户，
   agent 只声明「编译通过 / JVM 单测通过」。**交付后把 `_SHARED-WRITER.md` 删干净再走。**

---

## 一、规则（比任务本身更重要，违反就算没做完）

### 1.1 「接线」是指回路闭合，不是把参数传进去

一页算「活」必须同时满足：

- **数据**：来自真仓储 / 真系统服务 / 真文件，不是 `emptyList()`、不是 `SettingsPageState()`、不是演示对象；
- **动作**：每个能点的东西都有落点（写仓储 / 落盘 / 开系统 Intent / 跳页），**空 lambda 一个都不许留**；
- **回显**：改完之后重新进这一页，看到的是改后的值（这条最容易漏，也是用户最容易发现的）。

### 1.2 不许「假装能跑」

能力层（网络、WebView、文件选择、前台服务）**没到位就不许装成能用**。正确做法是
**控件照常渲染 + 点了给一句实话**（本仓已有先例：`b.general` 的「立即试一次」取 ARB 里的
`aboutUnavailable`）。**这条比「按钮有反应」优先级更高** —— 假成功比没反应更糟。

### 1.3 改断言 / 加守卫 / 调棘轮基线 → 必须做咬合探针

把被测行为故意改坏（改反判据、删一个条件），确认测试**真的会红**，再还原并确认 `git diff` 干净。
只证明「改完变绿」是不够的——把断言整条删掉，测试也会绿。

### 1.4 共享件的写权要抢（一把锁，管所有共享文件）

多个批次同时改**同一个文件**必撞。下面这些是「跨批次共享」的，动它们之前必须拿锁：

- 壳：`pages/ShellPageIndex.kt`、`ShellWiring.kt`、`ShellPageCatalog.kt`
- 设置族：`pages/settings/SettingsPageBridge.kt`、`SettingsPageRenderers.kt`、`SettingsRowRenderTable.kt`
- 各域 `*Strings.kt` 汇总文件（`SettingsStrings*.kt`、`GuideStrings.kt`、`TransferStrings.kt` …）
- `components/`、`main: platform/`、`main: app/`（`TimetableStore` / `TimetableRepository` / 仓储）
- **Lead 专属，任何批次都不要碰**：`android/app/build.gradle`、`android/app/src/main/AndroidManifest.xml`、`theme/`、两个壳的 Activity（`PagesShellActivity` / `MainActivity`）

**拿锁 = 原子新建**（文件已存在就失败，这是唯一的互斥机制，别用 `touch`/`echo >` 覆盖）：

```bash
LOCK=.agents/compose-phase3/claims/_SHARED-WRITER.md
if ( set -C; echo "批次=F04 会话=$ME 时间=$(date '+%F %H:%M')" > "$LOCK" ) 2>/dev/null; then
  echo WON
else
  echo LOST      # 有人在改共享件
fi
```

- **只在真要写的那一刻拿锁，写完立刻 `rm` 掉**：不要开着锁跑测试、不要开着锁读文档。
- 拿不到就先去干不需要共享件的部分（模型层、自己域里的渲染层），并在认领文件里写一份
  **「共享件改动待合入」**区块（文件 + 行区间 + 改后代码片段），回头拿锁一次性合入。
- 单次持锁**不超过 15 分钟**；超了先 `rm` 再重新抢。
- **忘了删锁是全仓最严重的阻塞**：每次提交前后都 `ls` 一眼这个文件；
  看到自己的名字而自己已经不在改共享件了，**立刻删**。

### 1.5 同域互斥（硬约束，不是建议）

| 组合 | 规则 | 原因 |
|---|---|---|
| **F05 ↔ F06** | **F06 必须等 F05 交付后才能开** | 都改 `pages/settings/` 的桥接与渲染表 |
| **F07 ↔ F08** | 可以并行，但 `main: platform/` 只允许 **F07** 改，F08 只读 | 两边都要文件/网络适配器 |
| **F02 ↔ F11** | 可以并行，但 `pages/guide/GuideStrings.kt` 谁先拿锁谁改 | 同目录 |
| 其余任意两批 | 目录不重叠，可并行 | — |

> 接单时**先看这张表**：如果和你同时开工的那批撞了，退一步——去抢队列里下一批没被占的。

### 1.6 禁止的操作

`flutter build *`、`assemble*`、`bundle*`、`adb install`、任何真机操作（点、滑、改设置）。
L1/L2 必须走 `scripts/safe-gradle.ps1`，**裸跑 `./gradlew` 违规**。

---

## 二、十二个批次

> **难度**：A = 页面与能力层都齐了，只缺接线（1 天内）；B = 缺一个数据源或适配器（1~2 天）；
> **C** = 缺一整块能力层，得先移植（2~5 天，可能再拆）。
> **行号**是 2026-10-29 20:25 快照，用 `grep -n '"<路由id>"' ShellPageIndex.kt` 复核。

### 总览

| 批次 | 名称 | 页数 | 难度 | 认领文件 | 覆盖路由 |
|---|---|---|---|---|---|
| **F01** | 实时活动显示与提醒 | 4 | A | `F01-live-display.md` | `j.live` `j.displayBefore` `j.displayDuring` `j.reminderTiming` |
| **F02** | 反馈渠道与全部功能导航 | 3 | A | `F02-feedback-more.md` | `k.feedback` `i.more` `i.moreSearch` |
| **F03** | 取件码与局域网编辑 | 2 | B | `F03-pickup-lan.md` | `g3.pickupCodes` `g3.lanEdit` |
| **F04** | ICS 导出接壳 | 1 | A | `F04-ics-export.md` | `g3.icsExport` |
| **F05** | 设置族·材质与外观数据源 | 6 | B | `F05-settings-material.md` | `b.appearanceEditor` `b.materialGeneral` `b.materialCourseCard` `b.backdropFlow` `b.recentWallpaper` `b.bingGallery` |
| **F06** | 设置族·组件/实时/重置 | 5 | B | `F06-settings-component.md` | `b.homeWidget` `b.live` `b.liveSelfCheck` `b.glassDockIcon` `b.reset` |
| **F07** | 导入·文件选择三页 | 3 | A | `F07-import-files.md` | `g1.importEntry` `g1.icsImport` `g1.spreadsheetImport` |
| **F08** | 教务适配族 | 6 | C | `F08-warehouse.md` | `g2.schoolAdapters` `g2.adapterDetail` `g2.warehouseImport` `g2.customDebug` `g2.aiImageImport` `g2.webLogin` |
| **F09** | 关于族收尾 | 2 | C | `F09-about-tail.md` | `a.support` `a.contributors` |
| **F10** | 加考试与地点作息匹配 | 2 | C | `F10-exam-location.md` | `d3.addExam` `d3.locationMatch` |
| **F11** | 启动引导落盘 | 1 | A | `F11-startup-flow.md` | `i.startup` |
| **F12** | 半接收尾 | 4 | A | `F12-half-close.md` | `c3.day` `e.statistics` `f.cloudSync` `f.backupList` |

**波次建议**（想尽快看到效果就按这个顺序派）：

| 波次 | 批次 | 页数 | 理由 |
|---|---|---|---|
| Wave 1 | F04 → F01 → F02 → F11 | 9 | 能力层全在，纯接线，一批一个下午 |
| Wave 2 | F05 → F06 | 11 | 同域必须串行；一份渲染层服务 24 页，换真状态就活一片 |
| Wave 3 | F07 · F03 · F09 · F10 | 9 | F07 已经把 SAF/FileProvider 这些地基备好了，最先开；F03/F09/F10 各自独立、可并行，但都要先补一小块能力层 |
| Wave 4 | F08 | 6 | 最大的一块，建议单独一个会话长期跟 |
| Wave 5 | F12 | 4 | 主链路已经真，改动最小但最忌回归 |

---

### F01 · 实时活动显示与提醒（4 页 · A）

- **路由**：`j.live`(L1280) `j.displayBefore`(L1281) `j.displayDuring`(L1282) `j.reminderTiming`(L1283)
- **根因（实测）**：
  - `DisplaySettingsPage.kt:73-75`（与 `:530-532` 两处）的三个回调 `onOpenDoNotDisturbAccess` /
    `onStagePreviewStart` / `onStagePreviewStop` **都是默认空实现**，壳调 `DisplaySettingsPage(forDuringEnd = …, onBack)` 时一个都没传。
  - `ReminderTimingPage.kt:235` 的 `onPersist` 默认空 ⇒ **提醒时机改了不落盘**。
  - 三页 `j.live` / `j.displayBefore` / `j.displayDuring` 指向同一个 `DisplaySettingsPage`，只有
    `forDuringEnd` 不同 ⇒ **改一处三页一起活**，但验收要逐页点。
- **已有可复用件**（不用重写）：`main/pages/live/DisplaySettingsModel.kt`、`ReminderTimingModel.kt`、
  `DisplaySettingsStrings.kt`、`ReminderTimingStrings.kt`（模型层已搬完，缺的是「谁来读写」）。
- **写作用域**：
  - `composeP1: pages/live/`
  - `main: pages/live/`
  - `composeP1: app/`（新增 `LiveDisplayHost.kt`，照 `SettingsHost.kt` 的写法）
  - `test: pages/live/`
  - 壳：`main: pages/ShellPageIndex.kt` 的 4 条分支（**要抢共享件写权，见 §1.4**）
- **要做的事**：
  1. 找到 Dart 侧这几个值存在哪个 settings 键（`lib/screens/` 里对应页 + `lib/services/` 的 settings service）；
  2. 在模型层加「读快照 / 写补丁」两个纯函数（**JVM 可测**），键名与 Dart 逐字一致；
  3. 新增 Host：读快照 → 构造 `DisplaySettingsState` → 渲染 → 写回；
  4. 「免打扰权限」走系统 Intent（`Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`）；
  5. 预览的 start/stop 若无真能力（超级岛未拍板），**点了给实话**，不许假装在跑。
- **agent 可自证**：L0 `-Module "pages/live"`（往返单测：改一个键不能清掉存档里其它键）+
  L1 `:app:compileDevDebugKotlin` + 样式 `-Domain live`
- **用户真机验收**：开/关显示设置 → **杀进程重开** → 值还在；提醒时机改完重进页面仍是新值。

---

### F02 · 反馈渠道与全部功能导航（3 页 · A）

- **路由**：`k.feedback`(L1350) `i.more`(L1268) `i.moreSearch`(L1269)
- **根因（实测）**：
  - `FeedbackPage.kt:69-70` 的 `onOpenChannel` / `onCopyChannel` 是默认空实现，壳调 `FeedbackPage(onBack = onBack)`
    ⇒ **点反馈渠道（邮件/QQ/仓库）没反应、复制账号没反应**。
  - `ShellPageIndex.kt` 里 `MoreFeaturesWithSearch` 的 `onOpenFeature = {}` ⇒ **「全部功能」页每一行点了都不跳**。
  - 搜索浮层的 `onSelectFeature = { searchOpen = false }` ⇒ 选中只关浮层、不跳页（**半接**）。
- **写作用域**：
  - `composeP1: pages/feedback/`、`main: pages/feedback/`
  - `composeP1: pages/guide/`（`MoreFeaturesPage.kt` / `MoreFeaturesSearchOverlay.kt`）
  - `main: pages/guide/`（`MoreFeaturesModel.kt` 里已有条目表与路由映射，先确认）
  - `test: pages/feedback/`、`test: pages/guide/`
  - 壳：`ShellPageIndex.kt`（**抢锁**）
- **要做的事**：
  1. 渠道打开：按 Dart 用 `Intent`（`mailto:` / 网页 / 复制到剪贴板）+ `Toast` 回执；
  2. 「全部功能」每一条的 `onOpenFeature` 接到 `shellPageIdForRoute(...)` → `onOpenPage(...)`
     （**别新造一张路由映射表**，`MoreFeaturesModel` 里已有条目 → 目标页的映射，先核对再补）；
  3. 搜索浮层选中 = 关浮层 + 跳页，两步都要；
  4. 反馈页若「提交」需要网络（GitHub issue / 邮箱），**先确认 Dart 到底发不发网络**；
     不发的话就是纯跳转 + 复制，不许凭空加一个假的提交按钮。
- **agent 可自证**：L0 `-Module "pages/guide"`（**契约测试**：每个条目 id 都能解析到一个壳路由 id，
  而不是 `expect(页面打开了)`）+ L1
- **用户真机验收**：反馈页点邮箱/复制有真动作；「全部功能」随便点 5 行都跳到对的页。

---

### F03 · 取件码与局域网编辑（2 页 · B）

- **路由**：`g3.pickupCodes`(L1207) `g3.lanEdit`(L1200)
- **根因（实测）**：
  - `g3.pickupCodes`：`PickupCodesPage(onBack = onBack, onEntryClick = {})` —— **整个页面没有数据源**，入口点击空。
  - `g3.lanEdit`：`LanEditPage(model = LanEditModel(), …)` —— 传的是**新建的空模型**（不是仓储快照），
    `onToggleRunning` / `onCopyAddress` / `onKeepAliveChange` 三个回调全空 ⇒ 开关不启服务、地址复制不了。
  - 底层是好的：`LanEditApiRouter` 的 A/B 组端点已全部接在仓储上（`751b6411` `7e83433c` `090aa000`），
    `LanEditForegroundService` 也在仓库里 ⇒ **缺的只是页面 ↔ 服务这一段**。
- **写作用域**：
  - `composeP1: pages/transfer/`（`LanEditPage.kt`、`PickupCodesPage.kt`）
  - `main: pages/transfer/`（`LanEditModel.kt`、`PickupCodesModel.kt`）
  - `main: platform/`（新增前台服务控制、网卡地址读取、剪贴板；若已有件就复用）
  - `test: pages/transfer/`
  - 壳：`ShellPageIndex.kt`（**抢锁**）
- **要做的事**：
  1. 读本机 IP + 端口 → 渲染成「在浏览器打开 `http://<ip>:<port>`」；
  2. 开/关 → 启停 `LanEditForegroundService`（**权限与前台通知**要按 Dart 对齐）；
  3. `onCopyAddress` → `ClipboardManager` + Toast；
  4. 取件码：找到 Dart 侧它读什么（多半是某个 settings 或本地表），没有真数据就**空态要写明为什么空**，
     `onEntryClick` 要么接真页、要么给一句实话，**不许留空 lambda**。
- **已知缺口（照实写进认领文件，不要顺手承诺）**：局域网 `import/apply` 端点仍回 **501**
  （缺传输包应用服务，台账 §9.4 ② 自认「唯一真缺的能力」）——**这一条不在本批范围内**。
- **agent 可自证**：L0 `-Module "pages/transfer"` + L1；开关状态与地址拼接要有纯逻辑单测。
- **用户真机验收**：开着局域网编辑，另一台设备浏览器能打开；关掉后打不开；地址复制进剪贴板。

---

### F04 · ICS 导出接壳（1 页 · A · 单项最省力）

- **路由**：`g3.icsExport`(L1180)
- **根因（实测）**：壳里 `IcsExportViewState(options = IcsExportOptions(今天-7天, 今天))` 是**写死的默认值**，
  后面跟 **10 个空回调**（`onSelectProfile` `onFromDateChange` `onToDateChange` `onToggleEventKind`
  `onSkipHolidayCoursesChange` `onExport` `onShareExported` `onSaveExported` `onDismissExportMenu`
  `onSyncCalendar` `onRemoveCalendar`）。
  **能力层已经交了**：`main/pages/export/` 有 `IcsExportModel.kt` / `IcsShareModel.kt` /
  `IcsShareWiring.kt`，`41590167` 还补了「生成→分享」接线层与契约测试 ⇒ **只差壳这一段**。
- **写作用域**：
  - `composeP1: pages/export/`
  - `main: pages/export/`
  - `composeP1: app/`（新增 `IcsExportHost.kt`）
  - `test: pages/export/`
  - 壳：`ShellPageIndex.kt` 一条分支（**抢锁**）
- **要做的事**：
  1. Host 持表单状态（档案 / 起止日期 / 事件类型 / 跳过节假日课）；
  2. `onExport` → 调 `IcsShareWiring` 生成 `.ics`；
  3. `onShareExported` → 系统分享面板。**FileProvider 已经在 `AndroidManifest.xml:137-151`
     注册好了**（Lead 2026-10-29 添加，`res/xml/file_paths.xml` 只授 `cacheDir` 下两个子目录）
     ⇒ 直接把文件写进已登记子目录再分享，**不要自己加 provider**；
  4. `onSaveExported` → 直接复用 `platform/AndroidSafBackupAdapter.kt`
     （`createDocumentIntent` / `write` 都是现成的），**别新写一套 SAF**；
  5. `onSyncCalendar` / `onRemoveCalendar` → 日历 Intent，
     **依赖缺失就给实话**（不许假成功）。
- **agent 可自证**：L0 `-Module "pages/export"`（已有时序化单测可直接用）+ L1
- **用户真机验收**：选 7 天导出 → 分享面板出现 → 存到文件管理器 → 能被日历应用导入。

---

### F05 · 设置族·材质与外观数据源（6 页 · B）

- **路由**：`b.appearanceEditor`(L338) `b.materialGeneral`(L339) `b.materialCourseCard`(L340)
  `b.backdropFlow`(L341) `b.recentWallpaper`(L342) `b.bingGallery`(L343)
- **根因（实测）**：六条都是**一行**：
  `SettingsScreen(SettingsXxxPage.spec(SettingsPageState()), onBack)` ——
  传的是**全新的空 state**，所以屏幕上是页面骨架、值全是默认、点了写不进去。
  对照：同族的 `b.general` / `b.appearance` / `b.theme` / `b.courseCard` 已换成真宿主
  （`SettingsHost(store = wiring.settingsModel, …)`），**照它们的写法改就行**。
- **写作用域**：
  - `main: pages/settings/`（各页 `spec(...)` + **`SettingsPageBridge.kt` 里补 `toXxxState`**）
  - `composeP1: pages/settings/`（渲染层，一般不用动）
  - `test: pages/settings/`
  - 壳：`ShellPageIndex.kt` 6 条分支（**抢锁**）
- **要做的事**：
  1. **先查这 6 页在 Dart 侧到底读哪些键**（`lib/screens/settings/*.dart`）；
  2. 设置模型已有 61 键（`4be6c4ad` / `88c33cad`）——**缺的键先在模型里加**，别在渲染层写死；
  3. `SettingsPageBridge` 里给每页加一个 `toXxxState(settings) -> XxxPageState`，
     **纯函数，可 JVM 直测**（这是本批的核心产出）；
  4. 动作走已有的 `SettingsActionDispatcher.kt`（壳侧已有这条路，**不要另造第二条写入路径**）；
  5. 壁纸相册类（`b.bingGallery` / `b.recentWallpaper`）若要网络图，复用
     `platform/AndroidImageLoader.kt`（`P35-B4` 已交付）。
- **避让**：`SettingsPageBridge.kt` 与 `SettingsPageRenderers.kt` 是全族共享 ⇒
  **F05 与 F06 必须串行，不许同时开**。
- **agent 可自证**：L0 `-Module "pages/settings"`（**每页一例往返**：改键 → 状态变 → 回写 →
  存档其它键一个不少）+ L1 + 样式 `-Domain settings`
- **用户真机验收**：六页各改一个值 → 杀进程重开 → 值还在；外观编辑改完回上一页，缩略预览跟着变。

#### F05 交付状态（2026-10-29 · `6116529c`）

**外观编辑页 + 材质/壁纸两个面板：已按 Dart 原件重建并接真数据**（本条原计划只把六页换成
「有真 state 的设置列表」；实际做成了原件那一版沉浸式整页 + 两个半屏底部面板，原因是
原件的形态就是那样，列表形态不是「少做一点」而是**形态错了**）。

- 路由：`b.appearanceEditor` → `AppearanceEditorHost`；`b.materialGeneral` /
  `b.materialCourseCard` / `b.backdropFlow` / `b.recentWallpaper` → **同一宿主 + 预开对应
  面板页签**（这四条在原版里本来就是面板页签，不是独立页面）。
- 数据：材质 11 键 + 壁纸 7 键进 `TimetableSettingsModel`（五处齐全）；`SettingsActionDispatcher`
  补 15 条 rowId；`AppearanceEditorState` 是逐键同源的状态桥（每条带 Dart 行号）。
- 证据：`:app:compileDevDebugKotlin` 绿；L0 `pages/settings` 655 例、含 app 层 757 例绿；
  compose-style `-Domain settings` 0 条。
- **仍缺（不假装做完）**：
  1. `b.bingGallery` 未动，仍走空 state（图库页本身存在，数据源是本批下一刀）；
  2. 选图落盘：面板只发意图，`URI → 受管目录 → 写 path + 补历史` 缺 Kotlin 侧的
     `managedImageStorage` 对应物；
  3. 「调整位置」行缺宿主页（点了不发请求，也就不会假成功）；
  4. 图库「每天自动更换」缺台账真源 ⇒ 该行按只读「不可用」渲染；
  5. 顶部渐变模糊带未接线（全仓 miuix-blur 真实页面 0 处，属独立批次）；
  6. **真机未验**：屏幕几何、预览是否随改随变、两个面板手感，等用户真机确认。

> 详细逐条对拍与「已知差异」见 `docs/plans/2026-10-29-compose-appearance-editor-audit.md`
> 与本机笔记 `.agents/notes/implemented/compose-phase35-appearance-editor-shell.md`、
> `compose-phase35-wallpaper-sheet.md`。

---

### F06 · 设置族·组件/实时/重置（5 页 · B）

- **路由**：`b.homeWidget`(L344) `b.live`(L369) `b.liveSelfCheck`(L376) `b.glassDockIcon`(L405) `b.reset`(L406)
- **根因（实测）**：与 F05 同一类——空 `SettingsPageState()` 渲染。
  额外两点：
  - `b.live` 虽然 `onAction` 能跳页（导航是真的），但**状态仍是空的**；
  - `b.reset` 是**危险动作**：`SettingsResetPage` 现在连确认都没有，更没落点。
- **写作用域**：同 F05（`main/pages/settings/` + `test/pages/settings/` + 壳 5 条分支）。
  **与 F05 串行**。
- **要做的事**：
  1. 前四页照 F05 的 1~4 步；
  2. `b.reset` 单独处理：**先**弹二次确认（`OverlayDialog`，照 `d2.taskList` 删除确认的写法）→
     再调仓储的重置入口；**重置范围按 Dart 逐项对拍**（是清设置？清课表？清全部？），
     别自己扩大范围；`b.reset` 的重置入口若仓储里没有，**先在仓储加一个纯函数并单测**。
  3. `b.homeWidget` 涉及桌面小组件：**只做「设置项读写」，不做小组件刷新**
     （刷新是另一条线 `W1`，别顺手改 `WidgetRefreshWorker`）。
- **agent 可自证**：L0 `-Module "pages/settings"`（**重置要有「只清该清的」用例**：
  塞入一课表 + 若干设置 → 重置 → 断言该清的清了、不该清的还在）+ L1
- **用户真机验收**：重置点了先问、确认后真的清掉；桌面小组件设置改完重开仍在。

---

### F07 · 导入·文件选择三页（3 页 · A）

- **路由**：`g1.importEntry`(L1076) `g1.icsImport`(L1083) `g1.spreadsheetImport`(L1088)
- **根因（实测）**：
  - `g1.importEntry`：`ImportEntryViewState()` 默认值 + 3 个空回调（随机配色开关、配色组选择、目标课表）。
  - `g1.icsImport`：`IcsImportViewState()` 默认值 + `onChooseFile = {}`。
  - `g1.spreadsheetImport`：`SpreadsheetImportViewState()` 默认值 + `onDownloadTemplate` / `onChooseFile` 空。
  - ⚠️ **别被旧文档带偏（2026-10-29 复核已过期）**：派工大表说「全仓 `ActivityResultContracts` 只有 1 处、
    SAF 入口不存在」——**现在已经不是这样了**。仓库里已有：
    `platform/AndroidSafBackupAdapter.kt`（`openDocumentIntent` / `createDocumentIntent` / `read` / `write`，带大小上限）、
    `pages/transfer/DataTransferHost.kt:198` 的 `OpenDocument()`、
    `pages/sync/CoupleTimetableSettingsHost.kt:70,106` 的 `CreateDocument` / `OpenDocument`，
    `AndroidManifest.xml:137-151` 的 `FileProvider` 也已注册。
    ⇒ **本批是把这些现成件接上去，不是从零造 SAF。**
- **写作用域**：
  - `composeP1: pages/import/`、`main: pages/import/`（解析模型已搬完：`IcsImportModel.kt` /
    `SpreadsheetImportModel.kt` / `ImportEntryModel.kt`）
  - `main: platform/`（**复用** `AndroidSafBackupAdapter`；只在真不够用时才扩它，别新建第二套）
  - `test: pages/import/`
  - 壳：`ShellPageIndex.kt` 3 条分支（**抢锁**）；**壳 Activity 若要注册新 contract 属 Lead**（提需求）
- **要做的事**：
  1. 选文件走现成的 `AndroidSafBackupAdapter` / `OpenDocument()`（**注意它带 `MAX_FILE_BYTES` 上限，
     超限要走「文件太大」这条真错误分支，不是静默失败**）；
  2. 选完文件 → 交给已有解析模型 → **预览**（绝不直接落盘）→ 用户确认 → 写仓储；
  3. 解析失败要有具体错误（哪一行、少了什么字段），不许一句「导入失败」；
  4. 「下载模板」→ 生成示例表格 → 写进 `cacheDir` 已登记子目录 → 分享（和 F04 同一套）；
  5. 随机配色开关与目标课表：读设置、写设置，照 F05 的桥接写法。
- **agent 可自证**：L0 `-Module "pages/import"`（解析侧：空文件 / 超长 / 格式错 / 字段缺失 / 重复课，
  五类反例都要有）+ L1
- **用户真机验收**：选一个真 `.ics` / `.xlsx` → 预览 → 导入 → 首页看得到课。

---

### F08 · 教务适配族（6 页 · C · 最大的一块）

- **路由**：`g2.schoolAdapters`(L1096) `g2.adapterDetail`(L1101) `g2.warehouseImport`(L1106)
  `g2.webLogin`(L1107) `g2.customDebug`(L1143) `g2.aiImageImport`(L1144)
- **根因（实测）**：
  - `g2.schoolAdapters`：`school = SHELL_DEMO_SCHOOL, adapters = emptyList()` —— **演示学校 + 空列表**。
  - `g2.adapterDetail`：`SHELL_DEMO_SCHOOL` / `SHELL_DEMO_ADAPTER` —— **两个都是演示对象**。
  - `g2.warehouseImport` / `g2.customDebug` / `g2.aiImageImport`：`WarehouseXxxPage(onBack = onBack)`，
    文件内分别有 6 / 4 / 4 个空 lambda，**没有 LocalContext、没有仓库依赖** ⇒ 整页死。
  - `g2.webLogin`（半接）：`SHELL_DEMO_LOGIN_URL` 是**占位地址**，`onWebBridgeMessage` 是空实现
    （源码注释自认「导入执行链路未接，见 I2 认领文件 §7」）。
  - **能力层部分到位**：WebView 宿主 `WarehouseWebViewHost.kt` 已交付（`ca94d1a6`），
    但 `WarehouseRepositoryService`（学校/适配器仓库）**Kotlin 侧还没移植**。
- **写作用域**：
  - `composeP1: pages/import/warehouse/`、`main: pages/import/warehouse/`
  - `main: platform/`（WebView、Cookie、网络）
  - `main: pages/import/`（与 F07 相邻，**先确认 F07 有没有在跑**；共享件冲突就先串行）
  - `test: pages/import/warehouse/`
  - 壳：`ShellPageIndex.kt` 6 条分支（**抢锁**）
- **建议再拆成三刀**（一个会话吃不下就按这个顺序交付，不要憋成一个大提交）：
  - **8a 仓库数据层**：移植 `WarehouseRepositoryService`（学校清单 / 适配器清单 / 适配器详情）→
    L0 单测 → 这是后面三刀的地基；
  - **8b 三个列表页**：`schoolAdapters` / `adapterDetail` / `warehouseImport` 换真数据源，
    删掉 `SHELL_DEMO_*`；
  - **8c 网页登录与调试页**：`webLogin` 真地址 + Cookie 提取 + `onWebBridgeMessage` 接抓取；
    `customDebug` / `aiImageImport` 补宿主与动作。
- **诚实清单（写进认领文件，别当承诺）**：登录后的「抓取适配器」若还依赖 Dart 侧脚本引擎没移植，
  **就只做到「能登录 + 拿到 Cookie + 页面提示能力未就绪」**，不许假装能拉到课。
- **agent 可自证**：L0 `-Module "pages/import/warehouse"`（仓库层：空清单 / 单校 / 多校 / 适配器缺失）
  + L1
- **用户真机验收**：适配器列表看到真学校；点进详情；网页登录能过；登录态保持（切出去再回来不掉）。

---

### F09 · 关于族收尾（2 页 · C）

- **路由**：`a.support`(L273) `a.contributors`(L282)
- **根因（实测）**：
  - `a.support`：壳传 `donorData = null, onReload = {}` ⇒ **鸣谢名单恒空、刷新点了没反应**。
    源码注释自己写明「Compose 侧还没有移植 `SupportCreatorService` 的网络拉取」。
  - `a.contributors`：壳传 `maintainers = emptyList(), onReload = {}` ⇒ **恒空态**。
    注释写明「`WarehouseRepositoryService` 未移植」。
  - 两页的**渲染层与空态都是完整的**（关于族审核已确认），缺的纯粹是「谁来拉数据」。
- **写作用域**：
  - `composeP1: pages/about/`（一般不用动）
  - `main: pages/about/`
  - `main: platform/`（HTTP 客户端；**若仓库里已有网络层就复用，别新造**）
  - `test: pages/about/`
  - 壳：`ShellPageIndex.kt` 2 条分支（**抢锁**）
- **要做的事**：
  1. 先确认 Dart 侧这两个服务的**真实数据源**（URL / 缓存策略 / 失败重试）；
  2. 移植成「接口 + Android 实现 + 纯 Kotlin 解析器」，**解析器可 JVM 直测**；
  3. 三态齐活：加载中 / 成功 / 失败（**失败必须显示真错误并能重试**，`onReload` 接到真拉取）；
  4. 网络失败**绝不许假成功**、也不许把上次缓存当成新数据（要标缓存时间）。
- **agent 可自证**：L0 `-Module "pages/about"`（解析器：正常 / 空 / 格式错 / 超时 / 304）
  + L1
- **用户真机验收**：断网进支持作者页 → 有错误提示 → 点重试；联网 → 名单出来。

---

### F10 · 加考试与地点作息匹配（2 页 · C）

- **路由**：`d3.addExam`(L823) `d3.locationMatch`(L814)
- **根因（实测）**：
  - `d3.addExam`：`AddExamViewState(isEditing = false)` + `selectedCourse = null` + **14 个空回调**
    （保存/删除/改名/选课/选日期/起止时间/地点/座位/备注/三种提醒）⇒ 整页是**一张静态图**，
    而且 `isEditing` 永远是 false ⇒ **编辑既有考试这条路根本不存在**。
  - `d3.locationMatch`：`LocationTimeMatchPage(model = LocationTimeMatchModel(), …)` 传**空模型**，
    `onCreateGroup` / `onEditGroup` / `onDeleteGroup` / `onToggleGroup` / `onApplyActive` **全空**。
    时间模板审核（`docs/plans/2026-10-29-compose-time-scheme-audit.md`）已把它列为「仍是演示数据」的余量。
- **写作用域**：
  - `composeP1: pages/exam/`、`main: pages/exam/`（`AddExamModel.kt` / `ExamStrings.kt` 已有）
  - `composeP1: pages/time_scheme/`（`LocationTimeMatchPage.kt` / `LocationTimeGroupEditorPage.kt`）
  - `main: pages/time_scheme/`
  - `test: pages/exam/`、`test: pages/time_scheme/`
  - 壳：`ShellPageIndex.kt` 2 条分支（**抢锁**）
- **要做的事**：
  1. **先补表单状态机**：`AddExamFormReducer`（照 `AddTaskFormReducer.kt` 的现成范式：
     `initial` / `initialFromExam` / `withXxx` / `validate` / `toPayload`，**纯函数、JVM 可测**）；
  2. 写入口复用 `TimetableExamService`（`f70604b0` 已交付，`d3.examList` 就是这么接的）；
  3. 编辑路径：`d3.examList` 的 `onOpenExam` 现在是 `onOpenPage("d3.addExam")` 但不传 id ⇒
     壳要像 `pendingEditCourse` 那样加一个 `pendingEditExam`（**这条要抢壳写权**）；
  4. 提醒：`onAddCustomReminder` 等三项与通知通道相关，**通知换通道排在 Phase 4**
     ⇒ 先做到「存得住、回显得出来」，调度落地说实话；
  5. 地点作息：Group 的增删改走 `TimetableRepository` 已有的 `location_time_groups` 读写
     （时间模板那一批已加，`+41` 行）——**先去核，别再写一份**。
- **agent 可自证**：L0 `-Module "pages/exam"` + `-Module "pages/time_scheme"`（表单：
  必填校验 / 起止时间倒挂 / 同天重复 / 编辑态不丢字段）+ L1
- **用户真机验收**：加一场考试 → 列表出现 → 点进去能改 → 改完列表跟着变；地点分组能加能删能启用。

---

### F11 · 启动引导落盘（1 页 · A）

- **路由**：`i.startup`(L1226)
- **根因（实测）**：壳调 `StartupFlowPage(onBack = onBack)`，而
  `StartupFlowPage.kt:65-67` 三个回调**全是默认空实现**：
  `onOpenOldApp` / `onGoImportBackup` / `onFinishStartupFlow(semesterStartDate, totalWeeks)`。
  ⇒ **引导走完了，学期开始日与周数根本没落盘**，用户白填一遍。
- **写作用域**：
  - `composeP1: pages/guide/`（`StartupFlowPage.kt`）
  - `main: pages/guide/`（`StartupFlowModel.kt`）
  - `test: pages/guide/`
  - 壳：`ShellPageIndex.kt` 一条分支（**抢锁**）
- **要做的事**：
  1. `onFinishStartupFlow` → 写学期开始日与总周数（**键名与 Dart 逐字一致**，
     并复用 `b.semester` 用的同一个写入入口，**别另造一条**）；
  2. `onGoImportBackup` → `onOpenPage("f.backupList")`；
  3. `onOpenOldApp` → 按 Dart 的处理（是跳旧版还是提示），**没把握就给实话**；
  4. 还要确认「引导是否已完成」这个标记也真的写（否则下次启动又弹一遍）。
- **agent 可自证**：L0 `-Module "pages/guide"`（往返：提交 → 快照里字段对 → 再读一致）+ L1
- **用户真机验收**：走完引导 → 杀进程重开 → 不再弹引导，且课表周次按填的日期算。

---

### F12 · 半接收尾（4 页 · A · 改动最小、最忌回归）

| 路由 | 现在的问题（实测） | 要做的事 |
|---|---|---|
| `c3.day`(L477) | 数据是真的（读仓储快照、能跳编辑课），但 `DayViewSummaryLogic` 的 **`scheduleCount = 0` 写死**，`agendaEntries` **只映射课程、日程项全丢** | 把快照里的日程项也映射进 `DayAgendaEntry`，`scheduleCount` 取真实条数 |
| `e.statistics`(L874) | `onOpenShare = {}` ⇒ 统计页的**分享点了没反应** | 接分享（成果图或文本，按 Dart 对拍）；无产物能力就给实话 |
| `f.cloudSync`(L997) | `onOpenBackup = { Toast("备份详情尚未开放") }` ⇒ 备份详情是**占位文案** | 要么接真详情页（复用 `f.backupList` 的 controller），要么把入口从界面上去掉——**不要留着假入口** |
| `f.backupList`(L1043) | 同上（同一个 Toast 占位） | 同上 |

- **写作用域**：
  - `composeP1: pages/timetable/day/`、`pages/statistics/`、`pages/sync/`
  - `main: pages/statistics/`、`main: sync/`（`f.*` 的模型在 `sync/`）
  - `test:` 对应域
  - 壳：`ShellPageIndex.kt` 4 条分支（**抢锁**）
- **为什么单列一批**：这四页**主链路已经是真的**，收益小但风险最大——
  改坏它比留着一个占位更难发现。**必须做咬合探针**（改坏一处 → 红 → 还原）。
- **agent 可自证**：L0 对应三个 Module + L1；`c3.day` 要有「同日同时有课与日程」的用例。
- **用户真机验收**：日视图同一天既有课又有日程 → 两块都在、条数对；统计页分享有反应；云同步页不再有假入口。

---

## 三、交付门槛（每批都按这个交，缺一条不算完）

| 层 | 谁做 | 命令 | 能证明什么 |
|---|---|---|---|
| L0 模块单测 | agent | `pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>"` | 模型逻辑、文案对拍、咬合探针 |
| L1 编译 | agent | `pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` | 代码无编译错误（**≠ 能装上**） |
| 样式守卫 | agent | `pwsh -File scripts/compose-style-lint.ps1 -Domain <域>` | R1~R6 六条不新增违规 |
| 文案自查 | agent | `dart run tool/copy_style_lint.dart` | 新增文案不超宽 / 不复述标题 |
| 咬合探针 | agent | 手工：改坏 → 跑 → 红 → 还原 → 绿 → `git diff` 干净 | 证明了测试有牙齿 |
| L2 单测 | agent（每批一次） | `pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest` | 能编 + 全仓单测不红 |
| L3 出包 | **用户** | AS 里点 / `flutter build` | APK 能出来 |
| L4 真机 | **用户** | AS Run | 真的能用 |

**声明纪律**：agent 只能说「编译通过」（L1）或「JVM 单测通过」（L2），
**不得**说「能跑 / 能装上 / 已验证」。真机那一行留空，或写「未对照」。

---

## 四、认领文件模板（新建即领到）

```markdown
# 认领：F<NN> <批次名>

- 状态：进行中
- 领用者：<会话名>
- 领用时间：<YYYY-MM-DD HH:MM +08:00>
- 最后更新：<每有进展就改>
- 拿壳写权：☐ 已建 _SHARED-WRITER.md / ☐ 不需要 / ☐ 排队中

## 写作用域（我实际会碰的文件）
- ...

## 页面进度

| 路由 | 根因复核 | 数据层 | 动作层 | 回显 | 单测 |
|---|---|---|---|---|---|
| `j.live` | ☐ | ☐ | ☐ | ☐ | ☐ |

## 壳改动（要抢锁）
- 路由 `xxx`（Lnnn）：把 A 换成 B，附改后代码片段

## 交付证据
- 提交：<短号 + 标题>
- L0：<模块 / 结果>
- L1：<结果>
- 咬合探针：<改坏了什么 / 是否红 / 是否还原>
- 样式 & 文案：<结果>
- 真机：未对照

## 备注
- <挖到的新坑、与别的批次的冲突、需要 Lead 裁决的事>
```

---

## 五、通用接单指令（同一段发给 N 个 agent，各自抢单）

> **这段是给「同时发 5~6 个 agent」用的**：内容完全一样，谁都不要手改。
> 每个 agent 自己按 §七 队列 + §八 算法抢，抢到哪批做哪批。详见文末 §八 / §九。

```text
你现在是轻屿课表 Compose 迁移的接单 agent。仓库 C:\cursor\mikcb（共享工作区，会有别的 agent 同时在改）。

第一步（先抢，再读，抢单要快，不要先做调研）：
  1. 先读 docs/plans/2026-10-29-remaining-pages-tasklist.md 的 §七（接单队列）和 §八（抢单算法）。
  2. 严格照 §八 的 bash 片段，从 §七 第 1 顺位开始逐个用 `set -C` 原子新建认领文件，第一个成功的
     就是你的批次。抢到立刻写「状态：进行中 / 领用者 / 领用时间」，然后 break。
  3. 一个会话手上最多持 1 个未交付批次。抢不到任何一批 → 回一句「队列已空，等它人回收」，然后停，
     不要自己造活、不要新建清单外的批次、不要接手别人的认领文件。

第二步（干活）：
  4. 回头读该批次的 §二 小节：根因、写作用域、要做的事、验收门槛，全在里面。
  5. 只在该批次的写作用域里写文件。要改壳 / 设置桥接 / Strings 汇总 / platform / app 仓储这些
     跨批共享文件，先按 §1.4 抢 _SHARED-WRITER.md，改完立刻删——忘了删会堵死其他 5 个 agent。
  6. F05 与 F06 互斥（F06 必须等 F05 交付）；其余互斥关系见 §1.5。

第三步（交付）：
  7. 按 §三 走 L0 模块单测 + L1 编译闸门（L1/L2 必须用 scripts/safe-gradle.ps1，禁止裸跑 gradlew），
     必要时做咬合探针。证据写进认领文件，状态改成「已交付」。
  8. 提交用 `git commit -- <你自己的路径>`，禁止 git add . / -A / commit -am；别人的未提交改动不碰。
  9. 交完如果还有余力，回队列按 §七 顺序抢下一批。

红线（违反就算没交付）：
  - 不许跑 flutter build / assemble* / bundle* / adb install，不许任何真机操作。
  - 不许声明「能装上 / 已验证」，只能说「编译通过 / JVM 单测通过」，真机对照归用户。
  - 不许留空回调（`= {}`）当交付；能力没到位就给用户一句实话，不许假装能跑。
  - 不许删改别人的认领文件；不许为了变绿往守卫基线里加行。

做完请用一段白话汇报：抢到哪批、改了哪些页、L0/L1 结果、还剩什么没做。
```

## 六、这份清单没覆盖的（别当成已经没事了）

- **真正的缺口不在「页面死」，在「能力没移植」**：`WarehouseRepositoryService`、`SupportCreatorService`、
  `LanEdit` 的 `import/apply`（端点仍回 **501**）、通知换通道（排 Phase 4）、超级岛判据（`P3-L` 仍 ⏸ 待拍板）。
  本清单把这些包在 C 级批次里，但**能不能真做完取决于这几块**。
- **一页都没真机对照过**（台账 §9.5 自认）：87 页里 46 页「代码上真」，但**没有一页被用户在真机上确认过**。
  这条不解决，本清单交付完也只是「应该能用」。
- **演示数据仍散落在壳里**：`SHELL_DEMO_SCHOOL` / `SHELL_DEMO_ADAPTER` / `SHELL_DEMO_LOGIN_URL`
  （F08 会清）。清完要回来把这三个常量删掉，否则下一个人会以为它们还有用。

---

## 七、接单队列（唯一权威顺序，多个 agent 同时抢单看这里）

> 6 个以上 agent 同时在线时，**谁都不要自己挑批次**——一律按这张表的顺序，从第一个还没被占的开始试。
> 顺序同时决定了「谁先拿到好做的活」，所以别跳号。

| 序 | 批次 | 页数 | 状态（2026-10-31） | 认领文件（原子新建它） | 前置 / 互斥 |
|---|---|---|---|---|---|
| 1 | F01 | 4 | ✅ 已交付 | `F01-live-display.md` | — |
| 2 | F02 | 3 | ✅ 已交付 | `F02-feedback-more.md` | 与 F11 同目录（§1.5） |
| 3 | F11 | 1 | ✅ 已交付 | `F11-startup-flow.md` | 与 F02 同目录（§1.5） |
| 4 | F04 | 1 | ✅ 已交付（L2 未跑） | `F04-ics-export.md` | — |
| 5 | F07 | 3 | ✅ 已交付 | `F07-import-files.md` | 与 F08 共存时独占 `platform/` |
| 6 | F09 | 2 | ✅ 已交付（L2 未跑） | `F09-about-tail.md` | — |
| 7 | F10 | 2 | ✅ 已交付 | `F10-exam-location.md` | — |
| 8 | F12 | 4 | ✅ 已交付（`c3.day` 由他人代修） | `F12-half-close.md` | — |
| 9 | F03 | 2 | ✅ 已交付（页面已真；账目 10-31 结清） | `F03-pickup-lan.md` | — |
| 10 | F05 | 6 | ✅ 已交付 | `F05-settings-material.md` / `F05-appearance-editor.md` | 与 F06 互斥 |
| 11 | F06 | 5 | 🔄 剩 2 页：`b.live` / `b.liveSelfCheck` | `F06-settings-components.md` | 与 F05 互斥 |
| 12 | F08 | 6 | ✅ 已交付（L2 待补跑） | `F08-warehouse.md` | 与 F07 共存时 `platform/` 只读 |
| 13 | F13 | — | ✅ 已交付 | `F13-copy-style-kotlin-corpus.md` | 无 |
| 14 | F14 | — | ✅ 已交付 | `F14-wiring-guard-expand.md` | 无 |
| 15 | F15 | — | ✅ 已交付 | `F15-statistics-share-image.md` | 无 |
| 16 | F16 | — | ✅ 已交付 | `F16-transfer-diff-preview.md` | 无 |
| 17 | F17 | — | ✅ 已交付 | `F17-lan-apply-501.md` | 无 |
| 18 | F18 | — | 🔒 等前置 | `F18-wallpaper-routes.md` | **前置 F06**（同域） |
| 19 | F19 | — | 🔒 等前置 | `F19-final-gate.md` | **前置 F06**（原列的 F08 已交付，不再是前置） |
| 20 | F20 | 1 | ✅ 已交付（认领 2026-10-31 18:40） | `F20-home-widget.md` | — |

> **F01~F17 与 F20 已全部交付**，别再重复领。还开着的只有：F06 的两页
> （`b.live` / `b.liveSelfCheck`，见认领文件），以及等 F06 的 F18 / F19。
> 新接单的会话从这三处挑，不要按老表去抢「待领」的 F13~F17。

**「可用」的判定**（三者全满足才算可抢）：

1. 认领文件**不存在**；或存在但里面写着 `状态：已放弃` / `状态：已回收`；
2. 前置批次已交付（F18 前置 F06、F19 前置 F06；F19 原先列的 F08 已交付，不再是前置）；
3. 没有与**当前正在跑**的批次撞 §1.5 的互斥表。

**「已占」的判定**：认领文件存在且 `状态：进行中`。

---

## 八、抢单算法（照抄，别自己发明）

> 目标：**3 条命令内定输赢**。抢到再读文档；抢不到立刻试下一个，不要在这里纠结。

```bash
ME="<你的会话名>"        # DSH 会在系统提示里给你名字；没有就用 "agent-$(date +%H%M%S)"
CD=.agents/compose-phase3/claims

# 按 §七 的顺序表逐个试（示例是第 1 顺位；换下一行就是第 2 顺位）
for BATCH in F04:F04-ics-export F01:F01-live-display F02:F02-feedback-more F11:F11-startup-flow \
             F07:F07-import-files F03:F03-pickup-lan F09:F09-about-tail F10:F10-exam-location \
             F05:F05-settings-material F06:F06-settings-component F12:F12-half-close F08:F08-warehouse; do
  ID=${BATCH%%:*}; FILE=$CD/${BATCH##*:}.md

  # F06 的前置：F05 必须已交付
  if [ "$ID" = F06 ] && ! grep -qs '状态：已交付' "$CD/F05-settings-material.md"; then continue; fi

  # 原子占用：文件已存在则 set -C 会让重定向失败
  if ( set -C; printf '# 认领：%s\n\n- 状态：进行中\n- 领用者：%s\n- 领用时间：%s\n\n' \
        "$ID" "$ME" "$(date '+%F %H:%M %z')" > "$FILE" ) 2>/dev/null; then
    echo "WON $ID"
    break
  fi
done
```

**要点（每一条都是踩过的坑）**：

- **`set -C` 是唯一可靠写法**。`touch`、`> file`、`cat > file` 都会**覆盖**别人的认领，
  等于两个 agent 都以为自己抢到了。
- **抢到立刻写头**（`状态 / 领用者 / 领用时间`），别先读文档再回来补——中间这段时间
  别人看到的是空文件，会判成「已放弃」。
- **抢到就停**：`break`。**一个会话手上最多持 1 个未交付批次**，做完交付、把状态改成
  `已交付` 之后，再回队列抢下一个。一次抢好几批 = 别的人没活干、你自己也做不完。
- **抢不到不要重试同一个**，直接试下一个顺位；12 个都试完还输 → 回一句「队列已空，等回收」就停，
  **不要自己造活**。
- **抢到后 3 分钟内必须动第一刀**（哪怕只是读根因 + 把页面清单填进认领文件）。
  认领文件超过 **24h 没有「最后更新」变化**，任何人都可以往里追加一行 `> [申请回收]`；
  **不许删改别人的认领文件**。

---

## 九、六个 agent 同时在线时的行为约定

| 场景 | 正确做法 | 错误做法 |
|---|---|---|
| 你抢到 F04，同事抢到 F01 | 各自只在自己 §二 的写作用域里写 | 顺手把别人页面的空回调也填了（会撞） |
| 你抢不到任何批次 | 回「队列已空，等回收」，然后停 | 自己新建一个 F13 批次开干 |
| 你要改 `ShellPageIndex.kt` | 先拿 `_SHARED-WRITER.md`，改完立刻删 | 直接改（会和同事的补丁互相覆盖） |
| 同事的认领文件是空的 | 视为「刚抢到、正在写头」，**跳过** | 判定为放弃并删掉它 |
| 同事交了半成品就失联 | 24h 后追加 `> [申请回收]`，等 Lead 裁 | 直接接手改他的文件 |
| 你改了别人的文件 | 立刻停手，在认领文件里说明，等 Lead | 悄悄改回去（会丢他的改动） |

**提交纪律（6 个会话共用一个工作区，必有别人的未提交改动）**：
`git commit -- <你自己的路径>`，**禁止** `git add .` / `-A` / `commit -am`；
提交前 `git status` 看一眼，别人的文件不暂存、不提交、不格式化。

---

## 十、执行结果核查（2026-10-30 11:30，Lead 独立复核）

> 复核方式：**不信认领文件的自述**。做法是——把 HEAD 的 `ShellPageIndex.kt` 单独取出来逐条扫
> （空回调 / `emptyList()` / 演示常量 / 空 `SettingsPageState()`），再抽一个模块自己跑 L0，最后读代码看「是不是真回路」。

### 10.1 总账

| 项 | 数 |
|---|---|
| 本清单目标页 | 39 |
| **已落地（代码上真）** | **28** |
| 未完成 | **11**（F06 5 页 + F08 6 页，两批都在进行中） |
| 全仓「壳里是死的」页 | 由 **33 页降到 11 页** |

### 10.2 逐批判决

| 批次 | 判决 | 复核证据 |
|---|---|---|
| F01 实时活动 | ✅ 扎实 | 4 条路由 0 空回调；做了**对抗审核**并修了 3 处（`85e1d46b`） |
| F02 反馈+全部功能 | ✅ 扎实 | 反馈五行真打开/真复制；「全部功能」39 行真跳页；自述第三次探针被他人阻塞**如实记为未验** |
| F03 取件码+局域网 | ⚠️ 页面真、账未结 | 两页已干净；但认领至今写「进行中（L1 待闸门）」，**没人回填**；`import/apply` 仍 501（见 F17） |
| F04 ICS 导出 | ✅ 扎实 | 我独立跑 L0 → `OK (79 tests)`（认领写 76，数字是**涨的**不像是编的）；L2 自述未跑 |
| F05 设置族材质 | ✅ 6/6（工作区未提交） | 5 页走 `AppearanceEditorHost`，`b.bingGallery` 11:2x 刚补上 `BingGalleryHost`；**认领文件写「已回收（未开工）」与实际不符** |
| F06 设置族组件 | 🔄 11:27 刚接手 | 5 页仍空状态；已有人拿锁改 `b.reset` |
| F07 导入三页 | ✅ 扎实 | 真 SAF 全链路（选文件→解析→预览→落盘→模板分享） |
| F08 教务适配 | 🔄 11:20 开工 | 6 页原来全是 `SHELL_DEMO_*`；刚接上 4 条，`customDebug`/`aiImageImport` 还空 |
| F09 关于族 | ✅ 扎实 | 真网络拉取 + 缓存时间 + 失败重试；L2 自述未跑 |
| F10 考试+地点 | ✅ 扎实 | 补了 `AddExamFormReducer`（编辑态从不存在到有）；两模块 L0 = 105 / 148 例 |
| F11 启动引导 | ✅ 扎实 | 开学日期/周数/完成标记真落盘；新增 `StartupFlowWiringTest` 11 例 |
| F12 半接收尾 | ✅ 3/4 | 假入口删了、统计分享接了文本；`c3.day` 甩给另一会话（至今**未提交**） |

### 10.3 这批人自己做出来的、比任务书更有价值的东西

**新增了 3 个「壳分支必须接真宿主」守卫**（`DiagnosticsWiringGuardTest` / `TaskWiringGuardTest` /
`LiveWiringGuardTest`）。它读 `ShellPageIndex.kt` 的**源码文本**，断言受管路由里
「不许出现空数据 / 空回调 / 空构造 state」。这把「渲染层交付 ≠ 页面可用」这个坑变成了机器可判——
是全仓第一次有东西能拦住「页面能打开、永远没数据」这种交付。
**但目前只覆盖 9 条路由**（见 §十一 F14）。

### 10.4 复核发现的四个问题（都已安排处理）

| # | 问题 | 处理 |
|---|---|---|
| 1 | **死键基线被放宽 5 条**：F01 新增的 5 个 ARB 键只有 Kotlin 消费，判据只扫 Dart ⇒ 写进了 `tool/copy_style_dead_keys_baseline.txt`（有写原因，不算违规，但确实放宽了守卫）。**复核还发现更早的老账：542 条基线里有 66 条其实被 Kotlin 真引用**——基线虚高 66 条，棘轮已经软了 | **F13** 根治（清掉 66+5 条假阳性） |
| 2 | **接线守卫只覆盖 9 条**，其余已接线的 20 多条没人守，随时能被改回空回调 | **F14** 扩面 |
| 3 | **两个壁纸路由被合并**：`b.backdropFlow`（背景流转）与 `b.recentWallpaper`（最近壁纸）都进同一个壁纸面板同一页签，Dart 侧是两个文件 —— 可能丢了一个入口语义 | **F18** 核对（等 F06） |
| 4 | **账目不一致**：F05 写「已回收（未开工）」实际 6 页都做了；F03 页面真了却仍写「进行中」 | **F19** 统一结账 |

### 10.5 复核时点的重要提醒

- **11:30 工作区：`F05` 与 `c3.day` 的修复都还没提交**。别在别人收口前跑全仓闸门，结论会冤枉人。
- `BingGalleryHost.kt` 一度有 9 个编译错误（半成品），11:2x 已修好；**这期间谁跑 L1 都会红**，
  这正是 AGENTS.md「禁止在半成品上跑 L1」要防的事。
- 另有一条**非本清单**的工作流在跑（月视图/周视图外观 + `lib/` Dart 源码 + 6 份 ARB，149 个文件未提交），
  与 §十一 的批次**目录不重叠**，可并行。

---

## 十一、第二批队列（F13~F19 + 用户任务 U1）

> 这七批都不碰 `pages/settings/`（F18 除外）与 `pages/import/warehouse/`，
> **所以现在就能发，不会打断正在跑的 F06 / F08**。

### F13 · 死键判据扩到 Kotlin 源集（A · 无前置）

- **为什么**：`tool/copy_style_lint.dart` 的死键判据只扫 `lib/` 与 `test/`（脚本自己的注释就写着
  「ARB 里有、但 `lib/` 与 `test/` 的代码从不引用」）。Compose 迁移后大量 ARB 键只被 Kotlin 读
  ⇒ 一律被判成「死键」。
- **实测（2026-10-30 11:35，Lead 复核）**：基线共 **542** 条死键，其中 **66 条其实在
  `android/app/src/**/*.kt` 里被真引用**（`aboutUnavailable` / `aboutUpdateStatusTitle` /
  `courseActionSuspend` / `coupleTimetableLastImportedAt` …）。
  ⇒ **基线虚高了 66 条**，不是 F01 加的那 5 条的问题——那 5 条只是把这层老账又抬高了一点。
  **这把棘轮现在是软的：真正没人用的键被 66 条假阳性淹在里面。**
- **做什么**：判据的 corpus 扩到 `android/app/src/**/*.kt`（`main` + `composeP1` 都要），
  然后**把 66 条假阳性 + F01 新加的 5 条一起从基线删掉**（删完基线应降到约 471 条），确认判据仍能抓真死键。
- **写作用域**：`tool/copy_style_lint.dart`、`tool/copy_style_rules.dart`、
  `tool/copy_style_dead_keys_baseline.txt`、`test/architecture/copy_style_guard_test.dart`
- **门槛**：`dart run tool/copy_style_lint.dart` 干净；`flutter test test/architecture/copy_style_guard_test.dart` 绿。
- **咬合探针（必做）**：往 Dart ARB 里塞一个**真的没人用**的键 → 判据必须报出来（证明扩 corpus 没把判据弄哑）；
  再把某个 Kotlin 里在用的键从 ARB 删掉 → 必须报缺失。两次都红，还原。
- **红线**：**不许再往基线加任何行**。扩完仍有残留就在批次里写清哪几条、为什么。

### F14 · 接线守卫从 9 条扩到「已干净的全部路由」（B · 无前置）

- **为什么**：见 §10.3。现在只有 9 条被守，其余 20 多条已接线的路由没有任何机器约束。
- **做什么**：把 `MANAGED` 清单扩到 **2026-10-30 11:30 时已干净的全部已交付路由**（约 28 条减去分派的），
  每条登记「期望宿主名」；保持两条断言：①路由必须在分派层有分支；②分支里不许有空数据/空回调/空构造 state。
- **写作用域**：`test: pages/shell/`（扩现有的 `*WiringGuardTest` 或新建一个统一守卫）；`ShellPageIndex.kt` 只读
- **门槛**：L0 `-Module "pages/shell"`；**咬合探针**：把任意一条已交付路由改回 `= {}` → 守卫必须红 → 还原。
- **红线**：**不许把 F06 / F08 那 11 条未交付路由纳入**（会把守卫弄成必红，等于逼下一个人删断言）。

### F15 · 统计分享补「图片导出」（B · 无前置）

- **为什么**：F12 只接了文本分享；Dart 原版能导出成果图。
- **做什么**：统计页离屏渲染 → PNG → 写进 `cacheDir` 下**已登记的子目录**
  （`res/xml/file_paths.xml` 只放行两个子目录，写错地方 `getUriForFile` 会抛）→ `FileProvider` 分享。
- **写作用域**：`composeP1: pages/statistics/`、`main: pages/statistics/`、`test: pages/statistics/`
- **门槛**：L0 `-Module "pages/statistics"`；真机归用户（分享面板里要是图片，不是文本）。
- **红线**：不许把 `FileProvider` 的 authority / path 自己改（manifest 属 Lead）。

### F16 · 传输「恢复前差异预览 + 合并/覆盖选择」（C · 无前置）

- **为什么**：F12 移交。现在 Kotlin 侧是「按 id 比对两份包文本」的近似，
  Dart 是按 scope 比对**仓储真实内容**，两者在「同 id 内容改了」「新增/删除」上会给出不同结论。
- **做什么**：补按 scope 的真 diff（课程 / 档案 / 任务 / 考试 / 日程 / 设置分组分别算），
  恢复前展示差异，让用户选「合并」还是「覆盖」。
- **写作用域**：`composeP1: pages/transfer/`、`main: pages/transfer/`（`DataTransferModel` /
  `DataTransferApplyLogic`）、`test: pages/transfer/`
- **门槛**：L0 `-Module "pages/transfer"`；三类反例必须有用例：同 id 内容变 / 新增 / 删除；
  咬合探针：把「同 id 内容不同」判成「相同」→ 必须红。

### F17 · 局域网 `import/apply` 端点（现回 501）（C · 无前置 · 大件）

- **为什么**：台账 §9.4② 自认「唯一真缺的能力」。现在局域网编辑能连上、能拿到列表，
  但「把别人发来的课表应用到本机」这一步**直接回 501**。
- **写作用域**：`main: sync/`、`main: pages/transfer/`（只改 `LanEdit` 服务侧，别重写界面——F03 已交付）、`test: sync/`
- **门槛**：L0 `-Module "sync"`；端点返回真实应用结果；要有「包损坏 / 版本不兼容 / 空课表」三类反例。
- **前置知识**：先读 `.agents/compose-phase3/claims/F03-pickup-lan.md`，别重复摸一遍。

### F18 · 两个壁纸路由的语义核对（A · **前置 F06**）

- **为什么**：`b.backdropFlow`（背景流转）与 `b.recentWallpaper`（最近壁纸）现在都进
  `AppearanceEditorHost` 的 `WallpaperSheetPages.PICKER`，看起来像一条路由把另一条吃掉了。
- **做什么**：对 Dart `settings_home_backdrop_flow.dart` / `settings_recent_wallpaper.dart` 核清楚
  两个入口的差别（不同页签？不同入参？还是本来就是一个面板的两条入口）；
  **该修就修，不该修就在壳里写注释说明为什么合并是对的**——不许默默留着。
- **写作用域**：`composeP1: pages/settings/`、`composeP1: app/AppearanceEditorHost.kt`、壳 2 条分支（**抢共享锁**）
- **为什么等 F06**：同属 `pages/settings/`，同时改必撞。

### F19 · 干净树总闸门 + 统一结账（A · **前置 F06 + F08**）

- **做什么**：
  1. 确认工作区没有别的会话在写（看 `claims/_SHARED-WRITER.md` 与 `git status` 的文件 mtime）；
  2. `pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin`；
  3. `pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest`；
  4. **回填认领文件**：F03（L1/L2 → 改「已交付」）、F04 / F09（补 L2 结论）、F05（把「已回收（未开工）」
     改成事实：6/6 已交付 + 谁做的 + 提交号）；
  5. 把 §十/§十一 的判决同步回本文档。
- **门槛**：L1 绿 + L2 绿。**若红，逐条点名归因到具体批次/文件**，不许写「别人弄红的」了事。
- **红线**：这一步只能一个人跑；跑之前**先确认没有半成品**（AGENTS.md：禁止在半成品上跑 L1/L2）。

### U1 · 真机逐页对照（**用户任务**，agent 不可代做）

- 28 页「代码上真」，**零页真机验证**。建议顺序：课表三视图 → 设置族 → 导入/导出 → 关于/引导。
- 每页只需三件事：能进、数据对、点得动。发现一页坏就记一行，属于哪个批次回填到哪个认领文件。

---

## 十二、第二批派工（发给空闲的 agent）

```text
请读 docs/plans/2026-10-29-remaining-pages-tasklist.md 的 §十一（第二批队列 F13~F19）与 §八（抢单算法）。

注意：F01~F12 已交付或正在被人做，**不要去抢**；F06 / F08 正在被人做，**绝对不要碰 pages/settings/ 与
pages/import/warehouse/ 这两个目录**。直接从 §七 第 13 顺位（F13）起，按 §八 的 set -C 原子新建认领文件抢单。

其余规矩不变：只在 §十一 给的写作用域里写；改壳/桥接/Strings 汇总/platform/仓储先抢 _SHARED-WRITER.md
（写完立刻删）；按 §三 交 L0 + L1 证据；不许跑 flutter build / assemble* / adb install；
不许声明「能装上/已验证」；不许为了变绿往守卫基线加行。
```
