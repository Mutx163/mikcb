# 文档站 × 代码一致性审计报告

> 审计日期：2026-09-13（**第二轮复核，代码基线 main @ 86043470**）
> 审计范围：`site/content/docs/**/*.mdx`（24 篇 / 4358 行）
> 对照对象：`lib/`、`android/`、`pubspec.yaml`、`.github/workflows/`、`docs/`
> 方式：5 组并行全文核对 + 主链路逐条复验
> **本轮变更**：首轮 7 条 P1 全部复现成立；新增 1 条 P1、2 条 P2；
> 2 条"未验证"转为已确认；修正 1 处代码位置。

---

## 一、结论摘要

**文档站整体是贴着代码写的，没有 P0 级硬伤**（没有"文档写了功能但代码根本没有"或
"文档说不上网但代码偷偷联网"的情况）。细节级描述精确一致：超级岛 7 类阈值、10 种
桌面小部件与 Provider 一一对应、WebDAV 备份保留策略（15 份 / 30 天 / 手动备份永不过期）、
`mikcb_ai_import_v1` schema 字段、12 枚统计徽章条件、周次上限 30、坚果云默认地址、
引导 5 页、minSdk 26（Android 8.0）。

**问题仍然集中在 `guide/customize.mdx` 一篇**，8 条 P1 里 5 条在它身上。
根因是 2026-09-12 那轮顶栏材质/玻璃重构改了语义，文档没跟上；本轮复核发现它还混入了
一份**代码里已不存在的主题名清单**。

统计：**8 条 P1** + **9 条 P2**。

---

## 二、P1 偏差清单（建议本轮修掉）

### 1. `guide/customize.mdx:50` — 玻璃模式漏掉「柔光玻璃」

- 文档：玻璃模式为「实体卡片 / 高斯模糊 / 液态玻璃」三档
- 代码：`lib/models/glass_mode_choice.dart:13`
  `enum GlassModeChoice { solid, gaussian, softGlass, liquidGlass }` **四档**；
  `settings_appearance.dart:330-334` 的选择器实打实 4 项，含
  `l10n.frostedGlassModeSoft → GlassModeChoice.softGlass`
- 影响：用户会以为柔光玻璃被砍了

### 2. `guide/changelog.mdx:32` — "四档收敛为三档"与代码不符

- 文档：「玻璃模式由四档收敛为『实体卡片 / 高斯模糊 / 液态玻璃』三档」
- 代码：`glass_mode_choice.dart:6-13` 注释写明收敛结果是
  「实体卡片 / 高斯模糊 / **柔光玻璃** / 液态玻璃」四档，被并入的是「启用模糊」开关
- 与上条同源，属历史记录写错

### 3. `guide/customize.mdx:69` — 仍写已下线的「首页玻璃带」作用范围开关

- 文档：液态玻璃作用范围里含「首页玻璃带（标题栏与星期栏的玻璃背景带）」开关
- 代码：`lib/models/timetable_settings.dart:1247-1249` 注释——
  「旧版『作用范围 → 首页玻璃带』开关的默认值。该开关**已随顶栏材质自由选择下线
  （2026-09-12）**，常量仅用于读取旧存档做迁移判定」；现由 `homeBandGlassMaterial`
  （`progressive`/`gaussian`/`soft`/`liquid`/`solid`）独立选择，与范围开关无关
- ✅ 状态更新：该重构**已提交**（首轮审计时还是未提交状态），可以放心改文档了

### 4. `guide/customize.mdx:55-58` — 高级材质的出现条件写窄了

- 文档：「这一项只在玻璃模式选了『液态玻璃』时才出现」
- 代码：`settings_appearance.dart:352-358` 柔光档同样透出 `softGlassTuning`
  （`SoftGlassTuning.defaults`）；:383 的隐藏判定是「非液态**且非柔光**」；
  `lib/models/soft_glass_tuning.dart` 有完整柔光参数集，预设枚举
  `SoftGlassPreset` 为 `clear/light/standard/dense/custom` 五档
- 附带：整篇文档对**柔光玻璃参数调校完全没写**

### 5. 🆕 `guide/customize.mdx:28` — 预设主题清单与 UI 完全对不上

- 文档：「默认蓝、暗夜紫、森林绿、暖阳橙、护眼模式、高对比度、深色极简，
  以及中性灰 / 锌灰 / 石板灰等中性色系」
- 代码：主题选择器 `settings_appearance.dart:277` 遍历 `ForuiTheme.values`，
  经 `lib/l10n/enum_localizations.dart:336-349` 映射，UI 实际显示 **11 个**：
  **默认、中性灰、锌灰、石板灰、蓝、绿、橙、红、玫红、紫、黄**
  （`app_localizations_zh.dart:6560-6590`）
- 两个硬伤：
  1. 文档列的「暗夜紫 / 森林绿 / 暖阳橙 / 护眼模式 / 高对比度 / 深色极简」
     对应 `themePreset*` 系列 l10n 串，但**除 l10n 文件外全仓无任何引用**
     （`grep -rn themePresetEyeCare lib/ --include=*.dart | grep -v l10n` → 空），
     是死资源，用户在 UI 里一个都找不到
  2. 漏了真实存在的 **红、玫红、黄**
- 影响：用户照文档找"暗夜紫"找不到 ← **首轮误判为 P2，本轮升级为 P1**

### 6. `guide/quick-start.mdx:57-59` — 设置位置已迁移

- 文档：菜单样式 / 导航形态 / 视觉效果「之后都能在『设置 → 外观与配色』里改」
- 代码：`settings_appearance.dart:15-17` 注释——「导航形态 / 玻璃坞 / 首页标题等
  结构性设置**已迁到『首页与导航』**」
- 附带：与 `interface.mdx` 自己的说法（首页与导航 → 应用形态）互相矛盾

### 7. `guide/interface.mdx:29 / 225-229` — 「回本周」样式选择器已移除

- 文档：回本周按钮「内嵌在时间栏，或右下角悬浮，样式可在设置里改」
- 代码：`settings_timetable_page.dart:200-201` 注释——「『回本周』已收敛为
  **浮钮唯一入口**，样式选择行随之移除；仅保留浮钮透明度调节」；
  实际只剩 `layoutBackToCurrentWeekButtonOpacity` 滑条（min 0.55 / divisions 9）。
  枚举 `BackToCurrentWeekButtonStyle` 虽留在 `timetable_settings.dart:241`，已无 UI 入口

### 8. `dev/contributing.mdx:25` — 本地命令与 CI 门禁冲突

- 文档：`flutter analyze --no-fatal-infos`
- CI：`.github/workflows/ci.yml:92`、`android-build.yml:48` 均为
  `flutter analyze --fatal-infos`；同文档第 35 行基线「0 error、0 warning」未提 info 也致命
- 影响：本地照文档跑通过，推上去 CI 照样红

---

## 三、P2 表述/遗漏清单

| # | 位置 | 问题 | 实际情况 |
|---|---|---|---|
| 1 | `guide/faq.mdx:147` | 卡顿建议只列「实体卡片/高斯模糊」两档 | 漏了同样可用的「柔光玻璃」；路径正确 |
| 2 | `guide/statistics.mdx:70` | 「均衡大师」称"没课的日子算 0"参与 max−min | `statistics_service.dart:771-783` `_calculateDailyBalanceGap` 只遍历 `allCourses` 建 `dailySections`，**空课日不进 map、不参与计算**。例：一三五各 4 节 → 代码 gap=0（可解锁），按文档算法 gap=4（不解锁） |
| 3 | `guide/super-island.mdx:14` | 前置条件写「HyperOS 3.0.300 及以上」 | 实际判断在 `android/app/src/main/kotlin/com/mutx163/qingyu/LiveUpdateService.kt:220-224`（**非 MainActivity.kt**，首轮位置有误）：仅 `SDK_INT >= 36`（Android 16）+ `canPostPromotedNotifications()`，不解析 HyperOS 版本号；岛标签另受 `isXiaomiFamilyDevice()` 限制（`live_island_preview.dart:219`）。口径偏窄，未说明非小米 Android 16 机型的表现 |
| 4 | `guide/organize.mdx:141` | 右上角菜单项写作「冲突」 | 实际标签 `courseConflictDetailTitle`＝「**冲突详情**」（`app_localizations_zh.dart:5140`），「冲突」仅用于首页小胶囊 |
| 5 | `guide/quick-start.mdx:16/25` | 「设置 → 关于 → 关于软件 → 版本更新」 | ⚠️ **见 §九修正**：该分组渲染出来的分区标签是 `settingsAboutSectionTitle`＝「**关于**」（`timetable_settings_screen.dart:639`），页内确有「版本更新」。原判「分组名为『关于 / 使用引导』」不成立（那只是 :1027 注释里的内部叫法），故该条**撤销**，文档保持「设置 → 关于」 |
| 6 | `dev/architecture.mdx:8-16` | 技术栈表缺 `flutter_blackbox` | `pubspec.yaml:53` 声明 `flutter_blackbox: ^0.7.0`，用于 `lib/main.dart:19`、`lib/ui/debug/blackbox_host.dart`、`lib/blackbox_adapters.dart`（自动生成：观测 `app_http_client` 的 HTTP 与日志）。⚠️ **见 §九修正**：原文"及整套 `warehouse_*` 教务录制/回放"不成立 —— 教务宏录制/回放是本仓自研（`warehouse_macro_models.dart` + `course_import_screen.dart` 的 WebView 注入 JS），`warehouse_*` 与 `course_import_screen.dart` 里 grep `BlackBox` 均为 0 命中 |
| 7 | `dev/contributing.mdx:36` | 只说"新增文案需同步各语言"，未给工具 | 仓库有完整 ARB 同步工具链（`tool/` 下 20 个 .py + `sync_arb.dart` + `merge_l10n_batch.py`），贡献者无从得知 |
| 🆕 8 | `guide/customize.mdx:17` | 字体首项写「应用默认（**Inter**）」 | `lib/ui/app_fonts.dart:136` `AppFontMode.system => const AppFontSpec()` **不指定 fontFamily**（即跟随系统）；`app_fonts.dart` 中 grep `Inter` 零命中。l10n 显示名是「应用默认」（:61），**括号里的 Inter 是错的** |
| 🆕 9 | 全站 | **渐进模糊（Progressive）整套能力文档 0 提及** | `lib/models/progressive_blur_tuning.dart:17` 有 `ProgressiveBlurPreset`（clear/light/standard/dense/custom 五档），`SurfaceMaterial.progressive` 是首页顶栏玻璃材质的第一档，提交 `d9797664` 「顶栏渐变模糊补上预设档 + 自定义档」。`grep -rn "渐进\|渐变模糊" site/content/docs/` → **0 命中** |

---

## 四、已确认成立（首轮标"未验证"，本轮查实）

| 项 | 结论 |
|---|---|
| `guide/import.mdx:134`「只读取第一个工作表」 | ✅ 正确。CSV 走 `spreadsheet_import_service.dart:237-241` `decoder.tables.values.first`；xlsx 走 `_decodeXlsxRows` 同样取单表 |
| `guide/settings-reference.mdx` 入口地图 | ✅ 与真实设置屏一一对应，未发现"文档有代码无"的项 |
| `guide/import.mdx` 的 `mikcb_ai_import_v1` schema | ✅ 字段与 `ai_course_import_service.dart:27-63` 完全一致 |
| 壁纸相关（光斑/漂移） | ✅ 无影响。提交 `f3684bc1` 删掉内置壁纸光斑漂移动画，但文档从未提及该动画，无过时描述 |
| 高刷/转场优化（`a64561a0`/`00c5d11f`/`5afb696b`/`86043470`） | ✅ 无影响。属内部性能优化，文档无对应承诺；`customize.mdx:153` 的「页面转场速度」是另一个独立设置项，仍存在 |

---

## 五、复核阶段推翻的 2 条误判（首轮已记录，保留备查）

1. ~~`docs/architecture/` 目录不存在~~ → 实际存在（`OPTIMIZATION.md`、
   `baseline-metrics.txt`），`architecture.mdx:60` 引用有效。
2. ~~`docs/releases/` 最高只到 v2.0.5.5，changelog 与 in-app 更新日志脱节~~
   → 实际有 115 个发布说明 md，最高 `v2.1.2.md`，与 `pubspec.yaml` 的
   `2.1.2+132` 及 `changelog.mdx` 三者一致。

> 教训：子代理的 `ls`/`Glob` 结论在大目录里不可信，**目录存在性、版本号这类
> "事实锚点"必须由主链路亲自验证**。

---

## 六、逐篇状态

| 文档 | 状态 | 备注 |
|---|---|---|
| `index.mdx` | ✅ 通过 | 首页宣称 7 项功能代码均存在 |
| `guide/quick-start.mdx` | ⚠️ 1×P1 + 1×P2 | 设置位置过时；minSdk/引导页数正确 |
| `guide/interface.mdx` | ⚠️ 1×P1 | 回本周样式选择器已移除 |
| `guide/courses.mdx` | ✅ 通过 | 排序三项、沿用已有课程、空课表提示全对 |
| `guide/organize.mdx` | ⚠️ 1×P2 | 仅菜单项用词 |
| `guide/customize.mdx` | 🔴 **5×P1 + 2×P2** | **问题最集中**：玻璃档位、顶栏玻璃带、高级材质条件、主题清单、字体名 + 漏渐进模糊 |
| `guide/settings-reference.mdx` | ✅ 通过 | 入口地图一一对应 |
| `guide/import.mdx` | ✅ 通过 | schema、表格列、周次上限 30、首工作表全对 |
| `guide/sync-backup.mdx` | ✅ 通过 | 情侣槽位、备份保留策略、覆盖/合并、坚果云地址全对 |
| `guide/super-island.mdx` | ⚠️ 1×P2 | 阈值/提前量/铃声/9 行详情/自检文案全部精确一致 |
| `guide/widget.mdx` | ✅ 通过 | 10 个 Provider 与尺寸一一对应 |
| `guide/statistics.mdx` | ⚠️ 1×P2 | 12 枚徽章除"均衡大师"外全部吻合 |
| `guide/faq.mdx` | ⚠️ 1×P2 | 仅漏列柔光玻璃 |
| `guide/troubleshooting.mdx` | ✅ 通过 | 引用路径均存在 |
| `guide/glossary.mdx` | ✅ 通过 | 术语与 UI 一致，作息优先级链正确 |
| `guide/about.mdx` | ✅ 通过 | 下载渠道、GPL-3.0-or-later、donors.json 均正确 |
| `guide/changelog.mdx` | ⚠️ 1×P1 | 版本号本身正确，仅"收敛为三档"描述错 |
| `guide/privacy.mdx` | ✅ 通过 | 友盟初始化经同意门控（`main.dart:788`），无硬伤 |
| `guide/feedback.mdx` | ✅ 通过 | 5 个渠道全部在 `feedback_screen.dart` 实现 |
| `dev/architecture.mdx` | ⚠️ 1×P2 | 目录引用有效，仅技术栈表漏 `flutter_blackbox` |
| `dev/contributing.mdx` | ⚠️ 1×P1 + 1×P2 | analyze 命令与 CI 冲突 |
| `dev/deployment.mdx` | ✅ 通过 | pnpm 11.22.0、`allowBuilds`、`output:'export'`、Cloudflare 重建均准确 |
| `dev/jiaowu-adapter.mdx` | ⚪ 未验证 | 核心内容指向外部仓 `Mutx163/qingyu_warehouse`，本仓无法验证；引用的内部桥接文件均真实存在 |

---

## 七、建议修复顺序

1. **重写 `customize.mdx` 的「主题」与「玻璃」两节**（P1 #1/#3/#4/#5 + P2 #8/#9）——
   六条同源，一次改完：
   - 玻璃档位补齐柔光玻璃（四档）
   - 「首页玻璃带作用范围」改写成「首页顶栏玻璃」独立材质五档（含**渐进模糊**）
   - 高级材质补柔光参数与五档预设
   - 预设主题改为 UI 真实 11 项（默认/中性灰/锌灰/石板灰/蓝/绿/橙/红/玫红/紫/黄），
     删掉不存在的「暗夜紫/森林绿/暖阳橙/护眼模式/高对比度/深色极简」
   - 字体首项「应用默认（Inter）」→ 去掉 Inter
2. **同步 `changelog.mdx:32` 与 `faq.mdx:147`**（P1 #2 / P2 #1）——档位口径统一为四档
3. **修 `quick-start.mdx` 与 `interface.mdx`**（P1 #6/#7）——设置位置与已移除的开关
4. **修 `contributing.mdx:25`**（P1 #8）——`--no-fatal-infos` → `--fatal-infos`
5. 其余 P2 顺手处理

> 前置阻塞已解除：顶栏材质重构在首轮审计时还是未提交状态，现已随
> `86e3a07f`~`86043470` 一系列提交落地，可以安全改文档了。

---

## 八、修订记录（2026-09-13 已全部改完）

`pnpm build` 通过：Next.js 16.3.4 编译成功，33 个静态页面全部生成。

### `guide/customize.mdx`（5×P1 + 2×P2 一次改完）

| 处 | 改动 |
|---|---|
| 字体（P2 #8） | 「应用默认（Inter）」→「应用默认」，并补一句"不指定字体族、跟随系统" |
| 预设主题（P1 #5） | 换成 UI 真实 11 项：默认 / 中性灰 / 锌灰 / 石板灰 / 蓝 / 绿 / 橙 / 红 / 玫红 / 紫 / 黄；删掉不存在的「暗夜紫/森林绿/暖阳橙/护眼模式/高对比度/深色极简」 |
| 磨砂玻璃（P1 #1） | 玻璃模式改为四档，逐档写明特性（柔光＝质感比高斯强、开销比液态小）。⚠️ **见 §九修正**：原写成"带**折射**与边缘高光"有误 |
| 新增「首页顶栏玻璃」小节（P1 #3 + P2 #9） | 删掉已下线的「首页玻璃带」作用范围行，改为独立材质五档：渐进模糊（默认）/ 高斯模糊 / 柔光 / 液态 / 实体，并说明它不受玻璃模式与作用范围影响。⚠️ **见 §九修正**：档位名已对齐 UI 的「柔光玻璃 / 液态玻璃」 |
| 高级材质（P1 #4） | 出现条件改为「柔光玻璃」或「液态玻璃」；补柔光参数与五档预设（清透/轻盈/标准/浓雾/自定义）；液态预设补上遗漏的「自定义」。⚠️ **见 §九修正**：柔光只有**三**个滑杆（雾面强度 / 底色浓度 / 边缘高光），原文"六参数（含折射、景深、色散）"写在折射链路删除之前 |
| 作用范围（P1 #3） | 删「首页玻璃带」行，标题改为「作用范围」并注明顶栏不在此控制；适用范围说明改为"选了柔光或液态玻璃之后" |
| 性能提示 | 中低端机建议补上「柔光玻璃」这个折中档 |

### 其余各篇

| 文件 | 改动 |
|---|---|
| `guide/changelog.mdx` | 「四档收敛为三档」→「由旧四档收敛为『实体卡片/高斯模糊/柔光玻璃/液态玻璃』四档」 |
| `guide/faq.mdx` | 卡顿建议补「柔光玻璃」；超级岛门槛补 Android 16 口径 |
| `guide/quick-start.mdx` | 「设置 → 关于」→「设置 → 关于 / 使用引导」；第 4 页视觉效果补「柔光玻璃」（引导页同为四档，见 `user_guide_screen.dart:1138`）；改后入口拆开写——菜单样式/导航形态在「首页与导航」，视觉效果/主题在「外观与配色」 |
| `guide/interface.mdx` | 「回本周」改为固定右下角悬浮按钮、无内嵌样式；设置表删「按钮样式」行，透明度注明 0.55 起、5% 步进 |
| `guide/statistics.mdx` | 「均衡大师」说明改为"**有课的日子**取最大减最小，没课的日子不参与计算" |
| `guide/super-island.mdx` | 门槛「HyperOS 3.0.300+」→「Android 16（API 36）+」+ 焦点通知权限；补充非小米机型只发通知、不显示岛标签 |
| `guide/troubleshooting.mdx` | 同上口径（**首轮审计遗漏，本轮补修**） |
| `guide/glossary.mdx` | 同上（**首轮审计遗漏，本轮补修**） |
| `guide/organize.mdx` | 菜单项「冲突」→「冲突详情」 |
| `dev/architecture.mdx` | 技术栈表补 `flutter_blackbox`（教务录制 / 回放） |
| `dev/contributing.mdx` | `--no-fatal-infos` → `--fatal-infos`；基线补 0 info；ARB 文案指向 `tool/` 下的同步脚本 |

### 首轮审计的盲区（已补修，值得记一笔）

「HyperOS 3.0.300」这个过时口径**不止 super-island.mdx 一处**，还散在
`faq.mdx`、`glossary.mdx`、`quick-start.mdx`（2 处）、`troubleshooting.mdx`。
首轮只有 B 组报了 super-island 一条，其余 4 篇是这次全站 grep 才发现的。
→ **修文档类问题时，同一口径必须先全站 grep 一遍再动手**，否则改一篇漏四篇。

---

## 九、提交前复核修正（2026-09-14）

本轮改动提交前逐条对代码复验，**推翻本报告的 3 条结论 + 修正 1 处文档措辞**。
根因一致：本报告基线是 09-13 的 main，而 09-13 晚间的「玻璃统一」系列提交
（`368da48b`/`1801fa7b`/`606d40ca`）删掉了自研柔光折射链路，报告没跟上。

| # | 原结论 | 复核结果 | 处理 |
|---|---|---|---|
| 1 | 柔光玻璃有六参数（模糊倍率、染色倍率、**折射、景深、色散**、边缘高光） | ❌ `lib/models/soft_glass_tuning.dart` 只有 3 个可调字段：`blurRadiusMultiplier` / `tintAlphaMultiplier` / `edgeHighlight`；文件头注释写明"自研折射链路（`SoftGlassRefraction`）已删除，refraction / depthEffect / chromaticAberration 在 `fromJson` 里被忽略"。`softGlassRefractionLabel`/`DepthLabel`/`ChromaticAberrationLabel` 三个 l10n 已是无引用死资源 | 文档改为「雾面强度、底色浓度、边缘高光」（UI 真实滑杆名）；同时删掉磨砂玻璃一节的"带**折射**" |
| 2 | `quick-start.mdx` 的分组名应为「关于 / 使用引导」 | ❌ 该分区渲染的标签是 `settingsAboutSectionTitle`＝「**关于**」（`timetable_settings_screen.dart:639`）。「关于 / 使用引导」只出现在 :1027 的注释里（描述这个分组含哪些行），不是用户能看到的标签 | 文档**回退**为「设置 → 关于 → 关于软件」（原始写法本来就是对的） |
| 3 | `flutter_blackbox` 用于"整套 `warehouse_*` 教务录制/回放" | ❌ `grep BlackBox` 在 `warehouse_*`、`course_import_screen.dart`（宏录制/回放主实现）中均 **0 命中**。教务宏录制/回放是本仓自研：`warehouse_macro_models.dart` + WebView 注入 JS。`flutter_blackbox` 的真实职责是**运行观测**（`blackbox_adapters.dart` 观测 `app_http_client` 的 HTTP 与日志、`main.dart` 的 `journeyObserver`）与**非 release 调试浮层** | `architecture.mdx` 该行改为「运行观测与调试浮层 / flutter_blackbox（非 release 生效）」 |
| 4 | （措辞）顶栏材质表用「柔光 / 液态 / 实体」 | UI 实际标签是「柔光玻璃 / 液态玻璃 / 实体」（`settings_appearance.dart:423-427` 的五个 items） | 表格对齐 UI 全名 |

**复核通过、未改动的部分**（逐条对代码验过）：玻璃模式四档（设置页 + 引导页
`user_guide_screen.dart:1138`）；预设主题 11 项与 `foruiTheme*` 文案逐字一致；
字体首项 `AppFontMode.system` 不指定 fontFamily；顶栏玻璃五档且默认 `progressive`
（`homeBandGlassMaterialValues`）、行恒常显示不受范围开关影响；高级材质出现条件
`isAdvancedGlassMode()`＝柔光或液态；液态预设 5 档 + 10 个滑杆名逐字一致；
超级岛门槛 `LiveUpdateService.kt:221` `SDK_INT >= 36 && canPostPromotedNotifications()`
且不解析 HyperOS 版本号、非小米机型无岛标签（`live_island_preview.dart:31`）；
「均衡大师」只算有课日（`_calculateDailyBalanceGap` 只遍历课程建 map）；回本周
浮钮唯一 + `min: 0.55 / divisions: 9`；菜单项「冲突详情」；`--fatal-infos` 与
CI 一致；`tool/sync_arb.dart`、`tool/merge_l10n_batch.py` 均存在。

> 教训补充：**审计报告自己也会过期**。报告里"顺带补的"事实（参数个数、分组名、
> 库的职责）必须与本轮文档改动**同批**再对一次代码 —— 报告写错一条，文档就跟着
> 错一条，而且因为"有报告背书"更难被发现。
