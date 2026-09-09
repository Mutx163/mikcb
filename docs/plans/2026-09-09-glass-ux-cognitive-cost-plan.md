# 玻璃相关设置认知成本治理方案（评审稿）

> 日期：2026-09-09 · 作者：AI 编码会话（本评审稿由用户指定供其他 AI 评优）
> 状态：评审稿。批准后按改造项分三次小步提交实施。
> 铁律：保留全部现有功能与持久化字段，只做重排、分组、接线、文案。落地后用户可操作的功能集合与今天完全一致。

---

## 0. 背景与目标

近期已把玻璃相关设置收敛一轮（见 1.1 基线）。仍存三处认知成本问题（见第 3 节）：主页控件过多、同类概念分两页且互不指路、多处“说明/标题”的 l10n 键定义了却从未渲染。

用户目标：降低认知成本、保留全部功能、操作容易。
手段：渐进披露（主页只留选择）+ 单一事实来源（一页管一个维度）+ 关闭后果显式化 + 词汇表统一。

## 1. 基线：本会话已完成的提交（评审上下文，不必重评其必要性）

| 提交 | 内容 |
|---|---|
| b84c7b1 | 模糊关闭说明文案修正：弹窗→不透明纯色底；首页模糊区域/回本周按钮→半透明 |
| e39d5541 | 玻璃模式四档→三档（实体卡片/高斯模糊/液态玻璃）；新增 GlassModeChoice 映射与 9 例单测；删无渲染差异的 translucent 枚举 |
| c1614a34 | 实体卡片档锚定弹窗白墨写白板修复：solidSurfaceActive 判定 + 弹窗实底面墨色回退 |
| aaefaa8 | 壁纸页开关更名「顶栏/信息栏玻璃」+ 接线副标题键 + 清理 4 个死键 |

## 2. 现状清单（控件 → 文件 → 行为）

### 2.1 外观与配色页 §3「磨砂玻璃」块
文件：lib/screens/settings/settings_appearance.dart（part of lib/screens/timetable_settings_screen.dart 库）

| 控件 | 类型 | 展示条件 | 备注 |
|---|---|---|---|
| 块标题 frostedSheetSectionTitle（zh 磨砂玻璃） | 节标题 | 恒显 | 消费点：本页 244、预览卡 144、高级材质子页 61 |
 | 玻璃模式三档选择器 HyperosSelectTile<GlassModeChoice> | 选择器 | 恒显 | 实体卡片=关模糊+归位 frosted；高斯=开模糊+gaussian；液态=开模糊+liquidGlass（映射在 lib/models/glass_mode_choice.dart） |
| 实时预览 FrostedSheetPreView | 卡片 | 恒显 | 标题文字复用 frostedSheetTitle |
| 模糊强度/磨砂亮度 2 滑杆 | 滑杆 | 仅「开模糊且非液态」即高斯档 | 条件 blurEnabled && mode != liquidGlass |
| 「液态玻璃调优」入口行 | 入口行 | 仅液态档 | 现值标题 advancedMaterialTitle（zh 高级材质）、详情 advancedMaterialSubtitle（zh 液态玻璃参数微调） |
| 液态玻璃作用范围块（6 开关） | 开关组 | 仅液态档 | 6 开关：闭锁弹窗/全屏选择面板/弹窗与对话框/首页玻璃带/玻璃坞/壁纸选点按钮（liquidGlass*Enabled 六字段） |

### 2.2 高级材质子页
文件：lib/screens/advanced_material_settings_screen.dart（独立文件）
含：预览 + 提示 frostedLiquidHint（液态玻璃需高性能设备）+ 液态预设选择 + 自定义 5 滑杆（厚度/模糊/染色/高光/环境）。

### 2.3 课表页面设置·背景（§5）
文件：lib/screens/settings/settings_timetable_page.dart §5
底色色卡、背景图、背景填充模式、背景随周次滑动；背景显示区域 4 开关（状态栏/顶栏/信息栏/课表）——节标题键 homePageBackdropScope （背景显示区域）及其说明键在 arb 存在但从未渲染；顶栏玻璃/信息栏玻璃 2 开关（已带副标题）。

## 3. 认知成本问题诊断

| # | 现象 | 根因 | 影响面 |
|---|---|---|---|
| Q1 | 外观主页在液态档额外铺 6 行作用范围开关 | 渐进披露只收了一半：模式收敛成 3 档，范围开关仍平铺主页 | 主页噪声大；开关只对液态档有意义 |
| Q2 | 范围开关副标题只讲是什么、不讲关了会怎样 | 无回退语义文案 | 用户不知道 OFF 后各部位回退高斯磨砂 |
| Q3 | 壁纸页 4 个区域开关无节标题，与 2 个玻璃开关混排 | homeBackdropScope 标题键定义了但没渲染 | “壁纸铺哪”与“哪里铺玻璃”两维度分不清 |
| Q4 | 块标题还叫磨砂玻璃 | 词汇未统一 | 实体卡片档下名不副实，与「玻璃模式/玻璃」词汇不齐 |
| Q5 | 液态需高性能提示只在子页出现 | 依赖信息未前置 | 用户选了液态才发现 |

## 4. 改造方案（全功能保留）

### P1 — 渐进披露：外观主页液态档瘦身
P1-1 将 6 个「液态玻璃作用范围」开关整体搬入高级材质子页顶部：
- 改动：settings_appearance.dart 删该块；advanced_material_settings_screen.dart 在预览之下/预设之上新增同结构块。
- 字段/持久化：liquidGlass*Enabled 六字段、json key、默认值一律不动。
- 入口行改名：advancedMaterialTitle「高级材质」→「液态玻璃调优」；advancedMaterialSubtitle「液态玻璃参数微调」→「预设 · 应用范围 · 参数」（6 语言）。
- 子页新增组说明键 liquidGlassScopeSectionDescription：「关闭任一部位后，该部位回退高斯磨砂材质；首页玻璃带在『课表页面 背景』另有区域开关」。
- 验收：外观主页液态档可见控件＝模式选择＋预览＋1 入口行；子页含原 6 开关，行为不变；现有 liquid_glass_scope 测试（仅断 provider 字段）不改仍全过。

### P2 — 壁纸页维度切分 + 死键接线
- P2-1 复活 homePageBackgroundScopeTitle/Subtitle（“背景显示区域”＋现有副文案），渲染为 4 个区域开关上方的小节标题，样式与 §5 现已用的底色小节标题一致。
- P2-2 新键 homePageChromeGlassSectionTitle（zh 建议「区域玻璃」），渲染于“顶栏玻璃/信息栏玻璃”两开关上方。
- 验收：壁纸页三层分级可目视辨：壁纸来源（底色/图片/随窗滑动）→ 壁纸显示区域（4）→ 区域玻璃（2）。

### P3 — 词汇统一 + 提示前置
 - P3-1 frostedSheetTitle 值 磨砂玻璃 → 玻璃材质（6 语言全表；英文 Material / Glass？本文给出建议表，评审可改）。
 - P3-2 新增 glassModeSectionSubtitle（zh 建议「统一弹窗、卡片与玻璃带的材质；液态玻璃需高性能设备」），挂到玻璃模式选择器副标题——液态性能提示在“选的时候”就可见（子页 frostedLiquidHint 保留不冲突）。
 - P3-3（可选）壁纸页区域玻璃节加说明「玻璃材质跟随『外观 · 玻璃模式』」，复用已接线副标题，不新增。

## 5. 兼容性与边界

- 持久化：无 schema/字段变化；纯 UI 重排＋l10n；旧存档直接加载，无需迁移。
- 行为：不触碰任何渲染分支（home_page_region_blur、HyperosSelectPopupGlass、HyperosSheetFrame 等均不动）。
- 测试：liquid_glass_scope_test、frosted_sheet_settings_preview_test、glass_mode_choice、home_top_menu 全部保持绿（字段/渲染语义未变）；可新增 1 条轻量断言（外观页液态档入口存在 + 子页 6 开关存在），前置：外观页无 pump 用例先例，列入实验项。
- 多 agent：settings_appearance.dart 为 part 文件（依赖父库 import）；advanced_material_settings_screen.dart 独立且已有 AppLocalizations；搬迁仅移动 UI 代码。
- 文案 6 语言一致，且与引导页「视觉三档」（实体卡片/高斯模糊/液态玻璃）一致。

## 6. 明确不做什么（防 scope creep）

1. 不删除任何功能/字段/ json key；不复活已清理的键。
2. 不改壁纸 scope 与铬带玻璃的渲染判定逻辑（上几轮已定语义）。
3. 不做多选题 chips、模式缩略图、跨页跳转（记为后续可选：chips 需新组件、缩略图需绘制、跳转行可后议）。
4. 不引入新的持化字段（如液态简化开关）。

## 7. 待改动 l10n 键清单（zh 口径；各语言按既有习惯翻）

| 键 | 现值 | 新值建议 |
|---|---|---|
| frostedSheetTitle | 磨砂玻璃 | 玻璃材质 |
| advancedMaterialTitle | 高级材质 | 液态玻璃调优 |
| advancedMaterialSubtitle | 液态玻璃参数微调 | 预设 · 应用范围 · 参数 |
| liquidGlassScopeSectionDescription | （新） | 关闭后回退高斯磨砂；首页玻璃带见「课表页面 · 背景」 |
| homeChromeGlassSectionTitle | （新） | 区域玻璃 |
| glassModeSectionSubtitle | （新） | 统一弹窗、玻璃卡与玻璃带的材质；液态需高性能设备 |
| homeBackdropScopeTitle/Subtitle | 存在未接线 | 接线，值不变 |

## 8. 验收与验证计划

1. flutter analyze 0 issues。
2. 四组既有测试全绿（见 5），可选新增外观首页断言。
3. 手动路径：三档切换观察控件集不跳动；液态进子页见 6 开关+预设+参数且持久化；壁纸页三段标题可见；右上角菜单字色三档均正常。

## 9. 请评优 AI 重点回答

1. 渐进披露是否伤可发现性？6 个作用范围开关收子页 vs 现状平铺即见；入口文案「预设 · 范围 · 参数」是否够。有无更优（如折叠组而非移子页）？
2. 命名：区域玻璃 vs 玻璃显示区域？玻璃材质块标题在玻璃模式选择器之上层级是否清晰？
3. 死键复活：壁纸 4 个区域开关补节标题，原设计是否刻意隐掉以缩短设置线？
4. 高斯滑杆留在主页（本方案）vs 也进子页（更激进渐进披露），取舍是否合理？
5. 「玻璃」（区域开关）与「玻璃模式」（模式名）会不会被用户当成同一概念重复摆放？
6. 「液态玻璃调优」里的「调优」定位是否恰当（参数 vs 范围）？6 语言中这个词的承受力？

## 附：与已提交基线的 git 关系

本文档为评审稿，未归属任何改动。批准后按 P1→P2→P3 三次小步提交，严格执行精确路径 add、不触碰其他 agent 文件。
