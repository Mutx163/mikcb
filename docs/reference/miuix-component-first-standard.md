# 软件标准：miuix 组件优先（禁止自研 UI / 交互 / 动画）

> 状态：**生效**。由用户于 2026-10-28 明确拍板。适用于本项目全部前端界面（Flutter 端按 `flutter_miuix`/官方口径对齐；Compose 端 `composeP1` / `composeUi` 全部页面）。
> 关联：`docs/reference/miuix-api-mapping.md`、`docs/reference/miuix-demo/`（官方 demo 只读副本）、`AGENTS.md`。

## 一句话标准

**能用 miuix 组件的，一律用 miuix 组件。不自研。**

## 硬规则

1. **组件**：所有可见 UI（按钮、卡片、列表、顶栏、底栏、弹层、对话框、开关、选择器、图标等）
   必须来自 `top.yukonga.miuix.kmp.*`（`miuix-ui` / `miuix-preference` / `miuix-icons` /
   `miuix-blur` / `miuix-squircle` / `miuix-shader` / `miuix-nav` 等官方 artifact），
   或官方 demo 里对它们的直接用法。
2. **交互与动画/转场**：必须使用 miuix 官方能力，**不得**用底层 Compose/Flutter 原语
   手搓一套替代品。典型禁止项：
   - 页面/视图转场用 `AnimatedContent` / 自写 `slideIn*` `fadeIn*` / `PageRouteBuilder`
     之类自研转场 —— **必须**用 `miuix-nav` 的 `NavDisplay`
     （`NavTransitions.MiuixDefault` + `NavDisplayEffects.Default`）。
   - 手搓弹层、下拉、气泡、设置行 —— 用 `Overlay*` / `*Preference` 等官方组件。
   - 手写模糊/圆角/折射 —— 用 `miuix-blur` / `miuix-squircle`。
3. **本地薄封装只允许「不改变行为」的情形**：例如 `QingyuCard` 仅在内部直接调用 miuix `Card`
   并做主题/内边距透传时才允许；一旦开始自己画形状、自己写动画、自己模拟按压反馈，即视为自研，
   触碰第 2 条。能直接用 miuix 组件的，**优先直接用**，不要为封装而封装。
4. **例外（迫不得已才自研）**：
   - 前提：miuix 明确没有该能力，且无法用现有 miuix 组件组合出来。
   - 流程：**必须先取得用户明确同意**，并在下方「例外审批登记」里写明：自研内容、理由、
     miuix 为何不可行（贴源码出处）、影响范围、后续替换计划。
   - 未经审批的自研 = 违规，评审/守卫应拦截。

## 落地与守卫

- 评审时按本文件逐条核对；发现自研替代 miuix 已有能力即打回。
- 后续应补一条架构守卫（源码级）拦截常见自研转场（如 `AnimatedContent` / `slideInHorizontally`
  出现在页面导航处），把本文件变成可执行的闸门；在守卫落地前，由评审人工把关。
- 本文件由 `AGENTS.md` 引用；新增/修改页面时先读本文件。

## 例外审批登记（当前 1 条：桌面小组件「效果预览」轮播，2026-10-31）

| 日期 | 位置（文件:行） | 自研内容 | 为什么 miuix 不行（出处） | 影响范围 | 负责人/审批 |
|---|---|---|---|---|---|
| 2026-10-31 | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/HomeWidgetPreviewCarousel.kt`（`WidgetPreviewSection` / `PreviewDots` / `PreviewImage`） | ① 用 `androidx.compose.foundation.pager.HorizontalPager` 做**卡片位图轮播**；② 自绘 10 个指示点（当前页 14×5、其余 5×5、圆角 3、`animateDpAsState`）；③ 位图本身用 `Modifier.shadow` 加投影（Dart 是 `blurRadius 18 / offset(0,5) / spread -2`） | miuix 0.9.4 的组件清单里**没有轮播 / 图片分页控件**：`miuix-ui` 的 `basic` 包只有 Card/Button/List/Scaffold 等，`utils` 里只有一个 `PagerGestureUtils.kt`（手势接管工具，不含分页容器本身）；`Card` 也没有 elevation/shadow 参数（`basic/Card.kt:163-183` 的 `BasicCard` 只画 `squircleSurface`），指示点更没有对应物。同仓先例：`pages/settings/MaterialSheetBody.kt:208` 的 `HorizontalPager` 也是同一路做法 | 仅「桌面小组件」设置页的效果预览区（10 张真实卡片位图）；不影响其它页面、不影响桌面下发路径 | Lead 代为登记；审批依据「用户要求页面与 Flutter 原版一致」（`settings_home_widget.dart:405-499`） |

## 当前落地状态（2026-10-28，已落地）

- Compose 页面壳 `PagesShellActivity` 已接入 **miuix-nav 的 `NavDisplay`**：底部四槽与页面层
  都放进返回栈（`ShellRoute = Dock(slotId) | Page(id)`），转场统一用
  `NavTransitions.MiuixDefault` + `NavDisplayEffects.Default` —— **没有一行自研动画**。
- 因 `miuix-nav` 0.9.4 是 Java21 字节码且 `entry<T>` 为 `inline`，`:app` 已整体迁到 JVM21：
  - 根 `android/build.gradle`：`subprojects` 里 `:app` → `JVM_21`，其余子项目仍 `JVM_17`。
  - `android/app/build.gradle`：`compileOptions` 21 + `miuix-nav` 依赖。
  - `android/gradle/gradle-daemon-jvm.properties`：`toolchainVersion=21`。
  - `.github/workflows/*.yml`：`setup-java` 的 `java-version` 17 → 21。
  - 本机：`~/.gradle/gradle.properties` 的 `org.gradle.java.home` 指向已装的 Temurin JDK 21。
- 验证：`L1 :app:compileComposeUiDebugKotlin` 绿、`L2 :app:testComposeUiDebugUnitTest` 绿（均在 JDK21）。
  真机观感（L4）待用户核对。
- 迁移的坑与结论见 `.agents/notes/proposed/architecture/2026-10-28-compose-shell-page-transition-miuix-nav.md`。

