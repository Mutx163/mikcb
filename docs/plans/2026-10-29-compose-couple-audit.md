# Compose 情侣课表设置页 · 重构质量审核（2026-10-29）

> 触发：用户「情侣课表页面审核一下重构质量，功能有没有复刻完，页面有没有一模一样做过来，把他完善好」。
> 审核对象：`CoupleTimetableSettingsPage`（渲染层）+ `CoupleTimetableSettingsModel` / `CoupleStrings` / `CoupleSyncCoordinator`（模型层）
> + `ShellPageIndex` 的 `f.couple` 分支（接线层）。
> 对照物：Flutter 正式版 Dart 源码与 ARB 文案（唯一判据）。本仓文档（含 L4 清单、旧认领文件）只作线索。

---

## 零、结论（先看这段）

**旧版判定：渲染骨架「搬过来了」，但功能一行都没接、三处版式与 Dart 不同、两个交互面（连接弹层 / 解绑确认）根本不存在。**

`docs/plans/2026-10-28-full-software-audit-and-completion-plan.md:141` 早把 `f.couple`(3) 记进「多空回调」榜单，
但当时只当成「回调是空的」，本次逐条对照后可以给出更准确的定性：

| 维度 | 旧版实况 | 本次处置 |
|---|---|---|
| 数据 | `ShellPageIndex.kt:1021` 把 `binding = null` / `webdavConfig = CoupleWebdavConfig()` 写死 ⇒ 页面**永远停在「尚未绑定」**，用户已有的情侣绑定在壳里看不见 | 新增 `CoupleTimetableSettingsController` + 真实存储（绑定 / 坚果云配置 / 密码），页面按真数据渲染 |
| 动作 | 三个回调全空（`onAction = {}`、`onShiftWeekOffset = {}`、`onPickColor = {_,_->}`）⇒ 九个按钮点了没反应、颜色点了不变、±号不动 | 九个动作全部接线：连接 / 断开 / 拉取 / 上传 / 导出 / 导入 / 解绑 / 周偏移 / 换色 |
| 连接坚果云 | **弹层不存在**（Dart 是一整张 sheet：账号 + 应用专用密码 + 槽位 1/2 + 测试连接 + 连接并拉取） | 新增 `CoupleWebdavConnectSheet`（Compose） |
| 解绑确认 | **弹框不存在**（Dart `showHyperosDialog` 两按钮） | 页内补确认弹框 |
| 结果提示 | 一条 Toast 都没有（Dart 有 12 条：成功 / 失败 / 无变化 / 部分损坏已跳过…） | 全部走控制器返回的 `SyncToast`，壳层统一弹 |
| 动作按钮版式 | Dart 是 `Wrap` 流水布局 + 主/次两种样式；旧版是**整宽竖排同一主色** | 改成流水布局 + 主/次样式（首个主色，其余次要色） |
| 叠加颜色 | Dart 色块 **42dp 圆角方**、间距 12、未选中 1dp 描边、选中 2dp 描边 + 勾；旧版是 **28dp 正圆**、间距 8、无未选中描边、无勾 | 按 Dart 重做 |
| 字阶 | 状态文字 `body1`(16) / 说明 `footnote1`(13)；Dart 是 `listTitle`(17) / `listDetail`(14) | 按 `miuix-api-mapping.md` 映射改回 `main`/`body2` |
| 轴线 | 列表 `horizontalPadding = 16` + 卡内 14 —— 文字左缘 30，与分组标题自带的 28 差 2dp | 改 `QingyuPageCardMargin`(12) + `ContentInsideMargin`(16) = 28 |

**修完到什么程度**：见 §七「修复记录」。**真机一次都没验**（agent 只能声明编译与 JVM 单测）。

---

## 一、审核方法

1. 读 Dart 全部相关源码：`lib/screens/couple_timetable_settings_screen.dart`（777 行）、
   `lib/widgets/couple_webdav_connect_sheet.dart`（244）、`lib/services/couple_webdav_service.dart`（314）、
   `lib/services/couple_webdav_config.dart`、`lib/services/couple_webdav_credentials_store.dart`、
   `lib/services/partner_timetable_service.dart`、`lib/domain/couple_timetable_logic.dart`、
   `lib/models/partner_timetable_binding.dart`、`lib/data/timetable_repository.dart`、`lib/services/storage_service.dart`；
2. 逐件对照 Compose 侧（渲染 / 模型 / 接线），把「Dart 有 Kotlin 没有」「Kotlin 自造」「两边不一致」三类分开记；
3. 版式口径以 `docs/reference/miuix-api-mapping.md`（字阶/颜色映射）与
   `docs/reference/compose-page-style-rules.md`（28dp 轴线）为准；**行为以 Dart 为准、样式以 demo 为准**；
4. 修完收口证据：L0 模块 JVM 单测 + 样式守卫 + L1 编译闸门（详见 §六）。

---

## 二、逐项对照（Dart 出处 → 旧 Compose → 现在）

### A. 页面骨架与分区顺序

| # | Dart 行为（出处） | 旧 Compose | 现在 |
|---|---|---|---|
| A1 | `HyperosSubpage(onBack, title=情侣课表)` + `HyperosListView`（`couple_timetable_settings_screen.dart:78-177`） | `QingyuPageScaffold(smallTopBar=true)` + `QingyuPageList` | 保持（R1/R2 合规） |
| A2 | 分区顺序：绑定态标题 → 对方信息卡 → **坚果云拉取** → 情侣课表动作 → 周次偏移 → 叠加颜色（未绑定只留前四段里的前三段） | 顺序一致 | 保持 |
| A3 | 每个分区之间 `HyperosSectionGap` | `Arrangement.spacedBy(12)` | 保持 |
| A4 | 列表左右留白 = 卡外边距 + 卡内 16 ⇒ 文字左缘 28 | `horizontalPadding=16` + `insideMargin=14` ⇒ 左缘 30（与分组标题差 2dp） | 改 12 + 16 = 28 |

### B. 绑定信息卡

| # | Dart 行为（`:88-111`） | 旧 Compose | 现在 |
|---|---|---|---|
| B1 | 未绑定：只有分组标题，**没有卡片** | 一致 | 保持 |
| B2 | 已绑定：两行「对方名称 → 值」「课程数量：N 门 → 上次导入时间」 | 一致 | 保持 |
| B3 | 名称优先取本地档案名（`partnerProfile?.name ?? binding.partnerName`） | 由 viewState 传入（壳写死 null） | 控制器按真档案取 |
| B4 | 上次导入为 `null` 时显示 `-` | 一致（`formatDateTimeOrDash`） | 保持 |
| B5 | 每行 `Padding(bottom: 8)`，末行也留 | 行间 `Spacer(8)` | 保持（视觉等价） |
| B6 | 标签 `listTitle`(17) / 值 `listDetail`(14) | `body2`(14) / `footnote1`(13) | 改 `main` / `body2` |

### C. 坚果云段

| # | Dart 行为（`:180-248`） | 旧 Compose | 现在 |
|---|---|---|---|
| C1 | 状态行：已连接 `已连接：{username}` / 未连接 `尚未连接坚果云`（`listTitle`） | 有，但字阶 `body1` | 改 `main` |
| C2 | 远程路径 `远程文件路径：{path}`（`listDetail`，恒显示） | 有，字阶 `footnote1` | 改 `body2` |
| C3 | `lastPulledAt != null` 才多一行 `上次拉取：{time}`（`listDetail`） | 有（null 不渲染） | 改 `body2` |
| C4 | 按钮组：未连接 = `连接坚果云`(主)；已连接 = `立即拉取对方课表`(主) + `上传我的课表到坚果云`(次) + `断开连接`(次)；`Wrap` 流水换行、间距 8 | **整宽竖排、同一主色** | 改流水布局 + 主/次样式 |
| C5 | 忙碌态：文案接 `...`、按钮禁用、左侧转圈 | 有（模型 + 渲染） | 保持 |

### D. 情侣课表动作段

| # | Dart 行为（`:120-154`） | 旧 Compose | 现在 |
|---|---|---|---|
| D1 | `导出我的课表给对方`(主) + `导入对方课表`(次) + 已绑定时 `解除绑定`(次) | 整宽竖排同一主色 | 改流水 + 主/次 |
| D2 | 忙碌态同上 | 有 | 保持 |

### E. 周次偏移（仅绑定）

| # | Dart 行为（`:514-567`、`:741-777`） | 旧 Compose | 现在 |
|---|---|---|---|
| E1 | 左 `−` / 右 `+` 44×44 方块按钮、圆角控制级，中间居中显示 `无偏移` / `+2 周`（`listTitle`） | 有（44dp、圆角 12） | 字阶改 `main` |
| E2 | 边界：`weekOffset > -15` / `< 15` 才能点，禁用时图标 alpha .35 | 有（模型常量 -15/15） | 保持 |
| E3 | 预览句 `查看你的第 {myWeek} 周时，显示对方第 {partnerWeek} 周的课`（`listDetail`），周次取**当前浏览周**与偏移后的对方周 | 有，但壳写死 `myWeek=1/partnerWeek=1` | 控制器取真实当前周，字阶改 `body2` |
| E4 | 落盘失败 → `保存失败` Toast，且界面回退 | 无（无动作） | 控制器写入前取值、失败回退 |

### F. 叠加颜色（仅绑定）

| # | Dart 行为（`:394-509`、`hyperos_color_chip.dart:162-215`） | 旧 Compose | 现在 |
|---|---|---|---|
| F1 | 三行：`我的课` / `TA的课` / `一起上课`，标签 `listTitle`(17) | 有，标签 `body2`(14) | 改 `main` |
| F2 | 色板 = 19 色快选（`kCourseColorQuickPickHexes`），选中色不在表里就补到行首 | 有（模型 `paletteIncluding`） | 保持 |
| F3 | 色块 **42dp**、圆角 = `chipRadius(42)`、间距 12/12、**未选中 1dp `outline` 描边**、**选中 2dp `onSurface` 描边 + 45% 大小勾**、带同色投影、点按触觉反馈 | 28dp 正圆、间距 8、无未选中描边、无勾、无投影、固定 8 个一行 | 按 Dart 重做 |
| F4 | 三行之间间距 14 | 一致 | 保持 |
| F5 | 落盘失败 → `保存失败` Toast | 无 | 控制器落盘失败弹 Toast |

### G. 两个交互面（旧版完全没有）

| # | Dart 行为 | 旧 Compose | 现在 |
|---|---|---|---|
| G1 | 连接弹层 `CoupleWebdavConnectSheet`：标题「连接坚果云情侣课表」+ 副标题、账号/应用专用密码两个输入框、槽位 1/2 二选一（选中主色）、槽位说明、底部「测试连接」(次) + 「连接并拉取」(主)，两个都填了才可点；测试成功弹 `坚果云连接成功`，失败弹 `连接失败…` | **不存在** | 新增 Compose sheet（文案逐字来自 ARB） |
| G2 | 解绑确认 `showHyperosDialog(标题 / 正文 / 取消 / 解除绑定)`，确认后才解绑并弹 `已解除绑定` | **不存在** | 页内确认弹框 |
| G3 | 连接成功后串联一次 `force=true` 的拉取（不再显示进度条） | 不存在 | 控制器 `connect()` 内串联 |

### H. 动作 → 结果（Dart 出处 → 旧 Compose → 现在）

| # | 动作 | Dart 口径 | 旧 Compose | 现在 |
|---|---|---|---|---|
| H1 | 立即拉取 | `force=false`（走内容哈希短路，命中弹 `对方课表无变化`）；四态 Toast；错误码走 `localizeServiceMessage` | 无 | 控制器 `pullNow()` |
| H2 | 上传 | 组单档包 → `PUT` 本机槽位文件；成功 `已上传课表，对方可拉取`，错误码弹对应文案 | 无 | 控制器 `uploadMine()` |
| H3 | 连接 | `connect` = 测试连接 → 存密码 → 存配置（username/mySlot）→ 立即拉取 | 无 | 控制器 `connect()` |
| H4 | 断开 | 先清配置（username / lastPulledAt / hash），再尽力删密码（删不掉不影响「已断开」）；失败弹 `保存失败` | 无 | 控制器 `disconnect()` |
| H5 | 导出给对方 | 组单档包 → 系统分享（分享文案 `这是我的课表，导入到轻屿课表的情侣课表即可一起查看`） | 无 | 控制器组包 + 壳层分享 |
| H6 | 导入对方课表 | 选文件（`json/mikcb`，有体积上限）→ 导入 → `已导入对方课表` / `已更新对方课表` + `，其中 N 条格式损坏已跳过` | 无 | 壳层 SAF 选文件 → 控制器导入 |
| H7 | 解除绑定 | 确认弹框 → 删绑定 + 删对方档案 → `已解除绑定` | 无 | 控制器 `unlink()` |

### I. 拉取/上传的协议细节（Dart `couple_webdav_service.dart`，Kotlin 已有传输层）

| # | 判定 | Dart 错误码 | Kotlin 状态 |
|---|---|---|---|
| I1 | 未连接（无用户名 / 无密码） | `couple_webdav_not_connected` | 已有传输层，接线层需按此返回 |
| I2 | 远端文件 404 / 空 | `couple_webdav_partner_file_missing` | 同上 |
| I3 | 非 UTF-8 | `couple_webdav_partner_file_not_utf8` | 同上（→ 走兜底文案） |
| I4 | 不是 JSON | `couple_webdav_partner_file_not_json` | 同上 |
| I5 | 是整机全量备份 | `partner_import_requires_single_profile` | **文案映射缺失**（Dart 映射到 `partnerImportRequiresSingleProfile`） |
| I6 | 其它失败 | `couple_webdav_pull_failed` | 已有 |
| I7 | 上传前组包 | `buildBackupJson(profileName, courses, scheduleItems, settings, currentWeek)` → 单档包（**不是**全量包） | `buildTransferPackageJson` 已具备 |

---

## 三、模型层对照

| # | 项 | 状态 |
|---|---|---|
| M1 | 周偏移上下限 -15/15、`clampWeekOffset` | ✅ 已有（`MIN/MAX_WEEK_OFFSET`），但**页内 ± 没有过一次 clamp**（旧版无动作） |
| M2 | 三色默认值 `#2196F3/#E91E63/#9C27B0` | ✅ 与 Dart 一致 |
| M3 | 19 色快选表 | ✅ 与 `kCourseColorQuickPickHexes` 逐项一致 |
| M4 | 按钮忙碌态文案 `label + "..."` | ✅ |
| M5 | 时间格式 `yyyy-MM-dd HH:mm` | ✅（复用 `CloudBackupListLogic.formatBackupDateTime`） |
| M6 | 服务错误码 → 屏上文案 | ⚠️ 缺 `partner_import_requires_single_profile`（Dart `service_message_localizer.dart:85`） |
| M7 | 按钮主/次样式 | ❌ 模型没有这个字段（渲染层只能全画主色） |
| M8 | 弹层/弹框文案 | ⚠️ 解绑弹框文案有；连接弹层 8 条文案**没有**（`coupleWebdavLoginSheetTitle/Subtitle`、`coupleWebdavConfirmConnect`、`coupleWebdavMySlotLabel/Hint`、`coupleWebdavSlotOne/Two`、`coupleWebdavTestSuccess`、`cloudSyncUsername*/Password*/TestConnection`） |
| M9 | 对方课表导入（单档包解析 + 落档案 + 落绑定 + 部分损坏计数） | ❌ 全缺（Kotlin 侧此前只有「传字节」的协调层） |
| M10 | 绑定持久化（`partner_timetable_binding`）与对方档案（`timetable_profiles` 里 id=`partner-imported`） | ❌ 全缺（`TimetableStore` 没有这个键） |

---

## 四、接线缺口（`ShellPageIndex.kt:1021-1037`）

```kotlin
"f.couple" -> CoupleTimetableSettingsPage(
    viewState = CoupleTimetableSettingsLogic.buildViewState(
        binding = null,                       // ← 永远未绑定
        webdavConfig = CoupleWebdavConfig(),  // ← 永远默认配置（假远程路径）
        hasStoredPassword = false,            // ← 永远「未连接」
        busy = CoupleBusyState(),
        partnerCourseCount = 0,
        partnerProfileName = null,
        myWeek = 1, partnerWeek = 1,          // ← 周偏移预览永远是「第 1 周」
    ),
    onBack = onBack,
    onAction = {}, onShiftWeekOffset = {}, onPickColor = { _, _ -> },   // ← 全空
)
```

缺的件（本次补）：

1. **配置存储**：`couple_webdav_config_v1`（JSON，`CoupleWebdavConfig.toJson` 同键同形）+ 密码（密文，独立键，不落明文）；
2. **绑定存储**：`partner_timetable_binding`（JSON）+ 对方档案写进 `timetable_profiles`（id=`partner-imported`，`profileKind=partnerImported`）；
3. **控制器**：把「读状态 / 九个动作 / 忙碌态 / Toast」收在一个可 JVM 单测的类里；
4. **弹层与弹框**：连接 sheet、解绑确认；
5. **系统交互**：SAF 选文件（导入）、分享（导出）。

---

## 五、验证与未验

- 已做：L0 模块 JVM 单测（`pages/sync`，`OK (213 tests)`）+ 咬合探针（clamp 去掉立即红、还原后绿）+
  样式域检查（`compose-style-lint -Domain sync` = 0 条）+ L1 编译闸门（`BUILD SUCCESSFUL`，
  复跑 `UP-TO-DATE`）。
- **L1 的过程波折**：前两次跑红是**同仓其它会话的在途改动**（`PagesShellActivity` 语法错误、
  `ShellWiring` / `PerfProbe` / `TimeSchemeHost` 类型不匹配），报错文件无一属于本批；
  等它们落地后重跑才转绿。以后遇到同样情况：**不要**把这批的红记在自己头上，也不要跳过 L1。
- **未做（agent 不能声明）**：真机逐项对照，清单见 §七.7。

---

## 六、剩余缺口（本页之外）

| # | 缺口 | 属谁 |
|---|---|---|
| R1 | 课表页的**情侣叠加渲染**未接（情侣数据不在 `TimetableSnapshot`，见 `2026-10-29-compose-week-view-audit.md:261` P2）——本页改完颜色后，周视图**看不到**叠加效果 | 周视图接线批次 |
| R2 | 云同步页的备份详情 / 恢复 SAF 同样未接（`f.backupList` 还是诚实提示「尚未开放」） | 同步族接线批次 |
| R3 | 情侣数据的**云同步/备份恢复**（绑定随快照走）未接 | 云同步批次 |
| R4 | 首页小组件的「情侣合并」走的是另一套（`WidgetCoupleMergeLogic`），与本页共用绑定数据，需一起验 | 小组件批次 |

---

## 七、修复记录（2026-10-29 收口）

### 7.1 渲染层（`composeP1/.../pages/sync/`）

| # | 改动 | 出处 |
|---|---|---|
| 1 | 轴线 `16 + 14` → `QingyuPageCardMargin(12) + ContentInsideMargin(16)` = **28**，与分组标题对齐 | `compose-page-style-rules.md` R6 / 28dp 轴线 |
| 2 | 字阶：状态行 `body1`→`main`(17)、说明行 `footnote1`→`body2`(14)、信息行标签→`main`、值→`body2`、周偏移标签→`main`、预览句→`body2`、色行标签→`main` | `miuix-api-mapping.md`（listTitle→main / listDetail→body2） |
| 3 | 动作按钮：整宽竖排同一主色 → **`FlowRow` 流水布局** + 主/次两种样式（主 = 默认按钮色、次 = `primarySurface` tonal 填充），忙碌仍转圈 + 禁用 | Dart `Wrap(spacing: 8)` + `HyperosButtonVariant` |
| 4 | 色块：28dp 正圆/间距 8/固定 8 个一行 → **42dp 圆角方（11.3dp）/间距 12/自动换行/未选中 1dp outline/选中 2dp onSurface + 45% 勾/同色投影** | `hyperos_color_chip.dart` |
| 5 | **新增**解绑二次确认 `OverlayDialog`（取消 / 解除绑定，确认后才回调解绑） | Dart `showHyperosDialog` |
| 6 | **新增** `CoupleWebdavConnectSheet`（`OverlayBottomSheet`）：标题/副标题/账号/应用专用密码/槽位 1-2/槽位说明/测试连接/连接并拉取，两项都填才可点 | `couple_webdav_connect_sheet.dart` |

### 7.2 模型层（`main/.../pages/sync/`）

| # | 改动 |
|---|---|
| 1 | `CoupleActionButton` 增加 `variant`（`CoupleButtonVariant.PRIMARY/SECONDARY`）；连接/拉取/导出 = PRIMARY，上传/断开/导入/解绑 = SECONDARY |
| 2 | `PartnerTimetableBindingModel` 补 `partnerProfileId` / `linkedAtIso` / `sourceFileHash` —— 落盘往返不再洗掉「何时绑定、来源文件哈希」 |
| 3 | 新增 `CoupleWebdavSheetTexts` 并挂到 viewState（弹层 12 条文案） |
| 4 | `CoupleStrings` 补 16 条 ARB（弹层 12 + 分享 1 + 服务码 3：`partner_import_requires_single_profile` / `unrecognized_mikcb_data_file` / `missing_settings_data`），全部加进 `allTexts` 参与逐字对拍 |
| 5 | 新增 `CouplePartnerPackage.kt`：单档包解析（信封门 / 整机备份门 / 全丢守卫 / 部分损坏计数）与组包（复用 `buildTransferPackageJson`，不自己拼键） |
| 6 | 新增 `CoupleStores.kt`：`CoupleConfigStorePort` / `CouplePartnerPort` 两个端口 + `CoupleBindingCodec`（绑定 JSON 往返）+ `clampWeekOffset` / `partnerWeekFor` |

### 7.3 控制器与生产实现

| # | 文件 | 内容 |
|---|---|---|
| 1 | `pages/sync/CoupleTimetableSettingsController.kt` | 状态持有者 + 九个动作 + 忙碌态 + 结果 Toast。**手动拉取 `force=false`**（命中内容哈希 → 「对方课表无变化」）、**连接后强制拉一次**、404/空归 `partner_file_missing`、上传走 `ensureRemoteFolder → putBytes`、周偏移 clamp 后落盘且失败不假装成功 |
| 2 | `platform/CoupleConfigStoreImpl.kt` | 配置 `couple_webdav_config_v1` 读-合并-写；密码走**独立密文键**（`couple_webdav_password_blob_v1`，不进明文） |
| 3 | `platform/CouplePartnerPortImpl.kt` | 绑定 `partner_timetable_binding`（坏值留档）+ 对方档案写进 `timetable_profiles`（id=`partner-imported`，`profileKind=partnerImported`），两者一次动作一起落 |
| 4 | `platform/CoupleTransferAdapter.kt` | SAF 读写（`OpenDocument` / `CreateDocument`），限长 20MB（与 Dart `maxImportFileBytes` 同口径） |

### 7.4 接线

`ShellPageIndex` 的 `f.couple` 从「`binding = null` + 默认配置 + 三个空回调」改为一行 `CoupleTimetableSettingsHost(...)`
（宿主在 `composeP1/.../pages/sync/CoupleTimetableSettingsHost.kt`：造控制器 → 订阅 `revision` 重组 → 九个动作落到控制器
→ 导入走 SAF、导出走 SAF、结果统一 Toast、阻塞动作一律 `Dispatchers.IO`）。

### 7.5 证据

| 项 | 结果 |
|---|---|
| L0（模块 JVM 单测） | `OK (213 tests)`（原 169 + 新增 44：单档包 13 / 绑定编解码 7 / 控制器 24） |
| 咬合探针 | 把 `shiftWeekOffset` 里的 `clampWeekOffset` 去掉 → `shiftWeekOffsetClampsAtUpperBound` 立刻红（`expected:<15> but was:<18>`），还原后绿 |
| L1（编译闸门） | `pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` → **BUILD SUCCESSFUL**；随后复跑为 `:app:compileDevDebugKotlin UP-TO-DATE`（说明当前输入（含本批全部文件）上一次编译是成功的）。**过程说明**：中途两次 L1 因同仓其它会话的在途改动打红（`PagesShellActivity` 语法错误、`ShellWiring` / `PerfProbe` / `TimeSchemeHost` 类型不匹配），报错文件无一属于本批；等那批落地后重跑才转绿 |
| 提交 | `02698142`（模型/控制器/存储/渲染/文案/测试，15 文件 +3013/-189）、`c6012a18`（`ShellPageIndex` 的 `f.couple` 换成真宿主入口） |

### 7.6 与 Dart 的已知差异（诚实清单）

| # | 差异 | 原因 |
|---|---|---|
| 1 | ~~**导出**用 SAF「保存到…」，不是系统分享面板~~ **已于二轮修复（2026-10-29 晚）** | 原文写的理由「本仓 `AndroidManifest.xml` 没有 `FileProvider` 声明」**当时就已过期**：`7c8d11b6`（19:04）已注册 `${applicationId}.fileprovider` 与 `res/xml/file_paths.xml` 的 `transfer_share`，比本文档所属提交 `02698142`（19:07）早 3 分钟。现在导出走 `AndroidTransferShareAdapter`（系统分享面板，Dart `share_plus` 同口径），SAF 只作兜底 |
| 2 | **非 JSON 远端文件**的提示是「发生未知错误」 | Dart `service_message_localizer.dart` 没登记 `couple_webdav_partner_file_not_json`，走 default 兜底。照抄，不擅自改文案 |
| 3 | **次要按钮**用 tonal 填充，不是 `TextButton` | 官方 `TextButtonColors` 与 `ButtonColors` 是两个类型（编不过），且 `TextButton` 只收 `text: String`、塞不进「转圈 + 文案」 |
| 4 | 拉取**不经** `CoupleSyncCoordinator` | 那个协调器把 404/空归成 `couple_webdav_pull_failed`，与 Dart 的 `couple_webdav_partner_file_missing` 不一致；控制器直连传输层以保真 |

### 7.7 未验（agent 不能声明）

真机路径一条都没验，需要用户按下面 6 条走一遍：

1. 连接坚果云（槽位 1）→ 顶部状态变「已连接：账号」；
2. 「立即拉取对方课表」→ 成功 / 无变化 / 未找到对方文件三种提示至少见到一种；
3. 「上传我的课表到坚果云」→ 成功提示；
4. 「导出我的课表给对方」→ 能选保存位置并写出文件；把该文件用「导入对方课表」导入 → 出现「已导入对方课表」且对方课节数 > 0；
5. 「周次偏移」± 到边界（±15）后按钮变灰；改完回课表页看对方课是否跟着挪周（**注意 §六 R1：叠加渲染本身还没接，课表页看不到颜色/叠加**）；
6. 「解除绑定」→ 弹确认框 → 确认后回到「尚未绑定对方课表」。

