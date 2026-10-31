# 「关于」页族 · 迁移质量审核与完善（2026-10-28 夜）

> **范围**：关于主页 + 全部子页（版本更新 / 更新日志 / 开源许可 / 支持作者 / 代码贡献者）。
> **口径**：对照物是 Flutter 原版 `lib/screens/`；被审对象是 Compose 渲染层
> `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/` 与模型层
> `android/app/src/main/kotlin/com/mutx163/qingyu/pages/about/`。
>
> **一句话结论**：**页面骨架与文案对拍做得不错（更新日志几乎是 1:1），但「关于」这一族恰恰是全仓
> 派工大表 §五 自己承认的覆盖盲区**（`页面在、真数据未接，13 行无一行覆盖`）。实测三处硬伤：
> ① 关于主页**整块头部信息卡缺失**、② **10 个入口全部点了没反应**（`onEntryClick = {}`）、
> ③ 开源许可 / 支持作者 / 代码贡献者**要么空数据、要么根本没页面**。

---

## 一、逐页缺口矩阵

| # | 子页 | Flutter 原版 | Compose 现状 | 功能复刻 | UI 一致 | 严重度 |
|---|---|---|---|---|---|---|
| 1 | **关于主页** | `about_screen.dart` `AboutScreen`（207–603） | `AboutStaticPage.kt`（110 行，仅三段列表） | ✗ 10 入口全死 | ✗ 头部信息卡整块缺失、标题写成「关于」 | **P0** |
| 2 | **版本更新** | `AboutUpdateScreen`（605–1720）+ `_AdvancedOptionsScreen`（1722–2290） | 只有 `AboutUpdateCard.kt`（3 态卡渲染）+ `AboutUpdateLogic.kt`（判据） | ✗ 无页面、无检查/下载 | ✗ 仅有一张状态卡渲染层 | **P1（受依赖阻塞）** |
| 3 | **更新日志** | `changelog_screen.dart`（345） | `ChangelogPage.kt`（453，资产扫描+摘要+展开） | ✓ 基本完整 | ✓ | **P3（收尾）** |
| 4 | **开源许可** | `open_source_licenses_screen.dart`（259，`LicenseRegistry`） | `OpenSourceLicensesPage.kt`（219，UI 全）+ `OpenSourceLicensesModel.kt` | ✗ 数据永远空（壳喂 `emptyList()`）、详情点击无响应 | ⚠ UI 在，但列表恒空 | **P1** |
| 5 | **支持作者** | `support_creator_screen.dart`（782，真二维码+保存+网络鸣谢） | `SupportCreatorPage.kt`（287，骨架） | ✗ 二维码是占位文字、保存是空回调、鸣谢恒空 | ⚠ 大体结构在，关键件缺 | **P1** |
| 6 | **代码贡献者** | `ContributorsScreen`（about_screen 2291–2557） | **无对应页面/模型** | ✗ 完全没有 | ✗ | **P0（整页缺）** |

---

## 二、分页细节（证据级）

### 1. 关于主页 —— 最高优先级

**Flutter 结构**（`AboutScreen.build`，:234–463）：
1. **头部信息卡**（:252–294）：`AppIconBadge(84)` + 应用名 `轻屿课表` + 版本号 + 一句定位副标题
   + **三格元信息条**（平台 / 重点 / 更新：仅正式版 or 含预发布）+ 第三方免责声明。
2. **支持与更新**组（:297–366）：请喝咖啡→支持作者页、问题反馈→反馈页、版本更新→更新页、
   更新日志→更新日志页、应用日志→日志查看器。
3. **产品**组（:369–411）：项目定位、导入与迁移→**说明弹层**（各 4 条 bullet）。
4. **社区**组（:414–459）：代码贡献者→贡献者页、开源仓库→**仓库弹层**（打开 GitHub/适配仓/复制地址）、
   开源许可→许可页。

**Compose 现状**（`AboutStaticPage.kt`）：
- 只有三段列表，`QingyuRow` 渲染标题/副标题/图标 —— 这部分与模型层 `aboutInfoSections()` 逐行对应，OK。
- ❌ **头部信息卡整块没有**（无应用图标、无版本号、无副标题、无元信息条、无免责声明）。
- ❌ `title = "关于"`（硬编码），而 Flutter 是 `aboutTitle = "关于软件"`。
- ❌ 壳里 `"a.about" -> AboutStaticPage(onBack = onBack, onEntryClick = {})` —— **点击任何一行都没反应**。
- ❌ `AboutInfoSheetContent` 虽已存在于同文件，但**从未被放进任何弹层**（定位/导入迁移点了没反应）。
- ❌ 仓库弹层不存在。

**影响**：用户从设置进「关于」，看到的是一个没有应用信息、且点什么都没反应的列表。这是**最刺眼**的复刻缺口。

### 2. 版本更新 —— 能力层大半没搬，且有依赖阻塞

Flutter `AboutUpdateScreen` 是一条完整链路：检查（GitHub/GitCode/蒲公英多渠道 + 镜像探针）→
三态状态卡 → release 说明预览（摘要/分块）→ 下载进度条 → 应用内下载安装 / 系统下载器 →
**高级选项页**（下载渠道、下载方式、镜像预设探测、诊断入口）。

Compose 只搬了：
- `AboutUpdateLogic.kt`：纯判据（主按钮去向、三态、镜像推荐/回退）—— 有测试，OK。
- `AboutUpdateCard.kt`：三态卡 + 检查中卡的**渲染层**。

**没搬的**：页面本体、更新检查网络、下载/安装、高级选项页、页面路由。
`infra/UpdateUrls.kt`（URL 构建/信任校验/release 解析）与 `UpdateVersion.kt`（版本比较/挑选）已在，
**但缺 HTTP 抓取与下载器；且 `appUpdateIncludePrerelease/DownloadChannel/MirrorPreset` 这些设置键
在 Kotlin `TimetableSettingsModel` 里尚未移植**（S1 包在改同一个模型）。
⇒ **诚实结论：完整更新流程不是本页能独立补齐的，它卡在「设置模型 + 更新服务 + 下载器」三件前置上。**
本轮不伪造该流程；只把入口接到一个「诚实暴露当前版本 + 打开 Release 页」的最小页，并明确标注未完成项。

### 3. 更新日志 —— 已基本 1:1（收尾即可）

`ChangelogPage.kt` 与 Flutter `changelog_screen.dart` 对齐得相当好：资产扫描路径（`flutter_assets/docs/releases`）、
文件名正则、版本倒序、`knownChangelogVersions` 回退、摘要三段式（重点/分类计数/展开）、原文分块回退、
版本标签、文案全走 `ChangelogStrings`（无中文字面量）。
**待核**：`knownChangelogVersions()` 的回退列表是否与 Dart `_getKnownVersions()` 同步（防止回退态版本缺项）。
**唯一硬伤是入口死**（见 #1）。

### 4. 开源许可 —— UI 完整，但数据是空的

`OpenSourceLicensesPage` UI 齐全（搜索框/许可说明卡/组件列表/详情页排版）；`OpenSourceLicensesModel`
的聚合/过滤/排序逻辑也已移植且有测试。
**缺的是数据源**：Flutter 用 `LicenseRegistry.licenses`；Compose 壳直接喂 `packages = emptyList()`，
且 `onOpenPackage = {}`（详情点了没反应）。
**可行修复**：APK 里 `flutter_assets/NOTICES.Z`（gzip，实测 128KB→解压 1.5MB）就是 `LicenseRegistry` 的同一份来源。
在 main 层加一个「解压 + 按 Flutter 分隔规则解析成 `LicenseRegistryEntry`」的纯函数（可单测），
复用现有 `buildOpenSourcePackageLicenses`，即可让列表**真的有内容**；详情页用 `OpenSourceLicenseDetailPage` 路由。

### 5. 支持作者 —— 骨架在，关键件缺

Flutter（782 行）关键件：紧凑头图（launcher 图标 + 「运行中」徽标 + 3 个带底色能力胶囊）、
收款卡（**真二维码图** wechatpay.png/alipay.png + 点击放大弹窗 + 保存到相册 + 「已支持」toast）、
分段控件选微信/支付宝、鸣谢名单（网络拉取 + 缓存 + 刷新 + 更新时间/副标题/备注）。
Compose（287 行）现状：头图无图标/无徽标/胶囊无底色；**二维码是占位文字**（`Text(hintFor(method))`）；
保存按钮是空回调；鸣谢 `donorData = null`（壳喂 null）→ 恒空；无放大弹窗。
**可行修复**：`assets/donate/*.png`（在 APK 里位于 `flutter_assets/assets/donate/`）用 `BitmapFactory` 加载，
接真 `Image` + 点击放大 `OverlayBottomSheet` + 保存到相册（MediaStore）；徽标与胶囊配色照 Dart 常量；
鸣谢数据先支持「有数据就渲染」，网络拉取作为后续。

### 6. 代码贡献者 —— 整页缺失

Flutter `ContributorsScreen`：开发人员卡（Mutx163）+ 教务适配者卡（从 `qingyu_warehouse` 拉 maintainer 汇总，
本地缓存优先 + 后台刷新）+ 参与适配卡（打开适配仓/复制地址）。
Compose **没有这个页面**，模型层也没有对应结构（`infra/WarehouseInfra.kt` 已有 `MaintainerGroup` /
`groupMaintainerLabels` / `encode/decodeMaintainersCache` 可复用）。
**可行修复**：新建 `ContributorsModel.kt`（main）+ `ContributorsPage.kt`（composeP1）+ 路由 `a.contributors`。

---

## 三、跨页共性问题

1. **壳接线整体缺位**：`ShellPageIndex.kt` 里 `a.about` 的 `onEntryClick={}`、`a.licenses` 空数据、
   `a.support` null 数据；没有 `a.contributors`、没有更新页路由。这是「功能没复刻完」的根因。
2. **i18n 棘轮**（`CjkLiteralGateTest`）：渲染层不许新增中文字面量。新文案一律进 main 层字符串对象，
   基线 `cjk-literal-baseline.txt` 里 `AboutStaticPage.kt:1` 那条随「关于」硬编码一并修掉（下调基线）。
3. **样式守卫**（`ComposePageStyleGuardTest`）：新页面/改版必须走 `QingyuPageScaffold / QingyuPageList /
   QingyuCard / MiuixTheme.textStyles / QingyuSectionTitle`，禁止裸 `Card(`、写死字号/颜色。
4. **资产读取口径**：Compose 目前**允许**读 `flutter_assets/`（`ChangelogPage` 已在读 `docs/releases`）。
   QR 图/图标同此口径读取；Phase 5 删 Flutter 前需把这类资产迁到 `android/app/src/main/res/`（记一笔待办）。

---

## 四、修复计划（按价值排序）

| 波次 | 内容 | 产出文件 | 门禁 |
|---|---|---|---|
| **W1** | 关于主页头部卡（图标/名称/版本/副标题/元信息条/免责声明）+ 说明弹层 + 仓库弹层 + **10 入口全接线** | `AboutInfoModel.kt`、`AboutStaticPage.kt`、`ShellPageIndex.kt`、`ShellWiring.kt`、`cjk-literal-baseline.txt` | L0 `pages/about`；CJK 棘轮；样式守卫 |
| **W2** | 代码贡献者页（新） | `ContributorsModel.kt`、`ContributorsPage.kt`、测试、`ShellPageIndex.kt` | L0；样式守卫 |
| **W3** | 开源许可真实数据（解析 `NOTICES.Z`）+ 详情路由 | `OpenSourceLicensesModel.kt`、`OpenSourceLicensesPage.kt`、测试、壳 | L0；样式守卫 |
| **W4** | 支持作者真实二维码 + 保存到相册 + 徽标/胶囊配色 | `SupportCreatorPage.kt`、`SupportCreatorModel.kt`、壳 | L0；样式守卫 |
| **W5** | 版本更新：接最小可用页（当前版本 + 打开 Release），完整流程标注依赖；更新日志回退列表核对 | 视前置而定 | 诚实标注 |

> 说明：W1 是本轮第一优先（最刺眼、且完全自足）。W2–W4 每个都能独立交付与自证。
> W5 的「检查→下载→安装→高级选项」**不是本页能独立完成的**，前置为设置模型（S1）+ 更新服务 + 下载器。

---

## 五、本轮已交付（2026-10-28 夜）

> 口径：只声明「编译通过（L1）」与「JVM 模型单测通过（L0）」。**未在真机上验证**（无设备控制权限）。

### 已落地

| 项 | 文件 | 状态 |
|---|---|---|
| **W1 关于主页头部卡** | `AboutStaticPage.kt`（重写）、`AboutInfoModel.kt`（+文案/仓库常量） | 应用图标(读 `flutter_assets/assets/branding`)+应用名+版本号(PackageManager)+定位副标题+三格元信息条+第三方免责声明，全部补齐 |
| **W1 10 入口全接线** | `AboutStaticPage.kt` + `ShellPageIndex.kt`（`a.about` 传 `onOpenPage`） | 咖啡→`a.support`、反馈→`k.feedback`、更新→`a.update`、日志→`a.changelog`、应用日志→`h.log`、贡献者→`a.contributors`、许可→`a.licenses`；定位/导入→说明弹层；仓库→仓库弹层 |
| **W1 说明弹层 + 仓库弹层** | `AboutStaticPage.kt`（`OverlayBottomSheet`） | 定位/导入迁移 4 条 bullet；仓库弹层 3 动作（打开 GitHub / 打开适配仓 / 复制地址） |
| **W2 代码贡献者页（新）** | `ContributorsModel.kt`（新）、`ContributorsPage.kt`（新）、`ShellPageIndex.kt`（`a.contributors`） | 开发人员 + 教务适配者（加载/失败/空/分组）+ 参与适配卡；适配者名单待仓储服务接线（当前空态文案） |
| **W3 开源许可真实数据** | `OpenSourceLicensesModel.kt`（+`parseFlutterNotices`）、`OpenSourceLicensesHost.kt`（新）、`ShellPageIndex.kt`（`a.licenses`） | 解压 `flutter_assets/NOTICES.Z`(gzip) → 解析 → 聚合；列表真有内容；点包名进详情页 |
| **W4 支持作者真二维码** | `SupportCreatorPage.kt`（重写） | 微信/支付宝真二维码图 + 点击放大弹层 + 保存到相册(MediaStore) + 「运行中」徽标 + 应用图标 + 能力胶囊 |
| **i18n 棘轮** | `cjk-literal-baseline.txt` | 修掉 `AboutStaticPage.kt` 唯一 1 条硬编码「关于」→ 走 `AboutInfoStrings.aboutTitle`；基线同步下调 |
| **模型单测** | `AboutFamilyModelTest.kt`（新，7 例） | NOTICES 解析/空块跳过/聚合/贡献者排序/新增文案与 ARB 逐字对拍 |

### 验证结果（必须是这个口径）

- **L0** `pwsh scripts/test-kotlin-module.ps1 -Module "pages/about"` → **OK (134 tests)**（原 127 + 新增 7）。
- **反证（咬合探针）**：把 `parseFlutterNotices` 的 80 连字符分隔符改成 79，立即 **3 例红**；还原后 134 全绿。
- **L1** `pwsh scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin` → **BUILD SUCCESSFUL**（壳+全部 composeP1 渲染层编译通过）。
- **样式守卫** `compose-style-lint -Domain about` → **0 违规**。
- **未跑**：CJK 门禁单测与 L2 全量单测（需 `:app:testComposeUiDebugUnitTest`，重活且有并发构建；已用「相关文件 0 中文字面量 + 基线下调」保守确保一致）。**真机未验**。

### 明确未做（诚实清单）

1. **版本更新页（`a.update`）**：**移交并行的「版本更新页 1:1 复刻」批次**（已提交模型层 `e5f43973`，`AboutUpdatePageModel`/`AppUpdateSettings`/`AppUpdateCheckParser`，正在补 `AboutUpdatePageStrings` 与渲染层）。为免同一条 `when` 分支/同名文件撞车，本轮**不再重复实现**；关于主页入口已指向 `a.update`，该批次接好即通。→ 这是当前唯一的「入口在、页面由他人批次补」项。
2. **贡献者「教务导入适配者」在线数据**：Compose 侧尚未移植 `WarehouseRepositoryService`（网络层），当前显示空态。
3. **支持作者「鸣谢名单」在线数据**：同上，`SupportCreatorService` 网络层未移植，当前显示空态。
4. **像素级对齐**：头部卡/收款卡等按 Flutter 结构与尺寸近似复刻，**未做逐像素真机比对**（需 L4）。

