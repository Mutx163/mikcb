# miuix-ui（本地 fork）

这是 `top.yukonga.miuix.kmp:miuix-ui-android` 的源码级 fork，进仓是为了在库内部改弹窗的
**表面材质**（玻璃要画在官方容器 `DialogContentLayout` 的同一个节点里、并按容器圆角裁切，
调用侧再包一层做不到）。用户 2026-11-03 明确批准「改库」。

- 上游：`compose-miuix-ui/miuix`，**版本 0.9.4**，Apache-2.0（每个源文件保留 SPDX 头）。
- 源码来源：Maven 官方 `miuix-ui-android-0.9.4-sources.jar`，把 `commonMain/` 与
  `androidMain/` 两个源集**平铺**进 `src/main/kotlin/`（本仓不是 KMP 工程，单源集）。

## 接法（两处，`app/build.gradle` 一字不改）

1. `android/settings.gradle`：`include ":third_party:miuix-ui"`。
2. `android/build.gradle` 的 `allprojects { configurations.configureEach { ... } }` 里用
   **依赖替换**把 `top.yukonga.miuix.kmp:miuix-ui-android` 指向本工程。这样 `:app` 的直接依赖
   和 `miuix-preference` / `miuix-icons` / `miuix-nav` 的传递依赖都解析到这份源码，不会出现
   「官方 AAR 与 fork 同名类」的重复类错误。

**回滚**：删掉上面两处接线（或只注释掉 `include` 与替换块），`:app` 立刻回到官方 AAR；
本目录留着不参与构建。

## 相对上游的改动（逐文件）

| 文件 | 改动 |
|---|---|
| `layout/DialogGlass.kt` | **新增**。弹窗玻璃参数（`backdrop` / `blurRadius` / `saturation` / `dark`）。 |
| `layout/DialogContentLayout.kt` | `DialogContentLayout` / `DialogContent` 各加一个默认 `null` 的 `glass: DialogGlass?` 参数；`DialogContent` 在 `squircleSurface` 之前挂 `Modifier.drawBackdrop(...)`（实时模糊 + 饱和度增益 + 边缘高光），在其后挂降级用的 1dp `squircleBorder`。`glass == null` 时链上一个参数都不加，与上游完全一致。 |
| `overlay/OverlayDialog.kt` | 透传 `glass` 参数（默认 `null`）。 |
| `theme/DynamicColors.kt` | **删除**（上游 `commonMain` 只有 `expect` 声明）；对应 `DynamicColors.android.kt` 去掉 `actual` 修饰符。 |
| `utils/WindowNavigationEventScope.kt` | **删除**（同上）；`WindowNavigationEventScope.android.kt` 去掉 `actual` 并保留合并后的 KDoc。 |
| `build.gradle` | 上游是 KMP 工程，本仓用 `com.android.library` + `org.jetbrains.kotlin.android`，并新增 `miuix-blur` 依赖（玻璃需要 `drawBackdrop` / `Highlight`）；`missingDimensionStrategy "env", "prod"` 兜住 `:app` 的 flavor 维度。 |

除此之外的源文件与上游 0.9.4 **逐字一致**。

## 合并上游新版本

1. 取新版本官方 `miuix-ui-android-<ver>-sources.jar`，解压出 `commonMain/` 与 `androidMain/`；
2. 用它们**整体覆盖** `src/main/kotlin/`（先删旧文件，别留被上游删掉的残留）；
3. 重做上表里的最小改动：删除两个 `commonMain` 的 `expect` 文件、给同名 `.android.kt` 去掉
   `actual`、重贴 `DialogGlass.kt` 与 `DialogContentLayout.kt` 的玻璃段（上游若改动了
   `DialogContent` 的 modifier 链，按「模糊在 `squircleSurface` 之前、描边在其之后」重排）；
4. 同步 `build.gradle` 里的依赖版本（对齐上游 POM）；
5. `pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` 必须真绿，再跑 course 域 L0。

> 上游一旦自己支持了弹窗玻璃，直接删本目录并回滚接线，改用官方参数。
