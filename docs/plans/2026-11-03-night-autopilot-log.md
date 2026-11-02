# 2026-11-03 夜间自动推进交接日志

> 本日志由接手代理维护，记录环境配置、门 1/门 2 结果、差异与阻塞。

---

## 一、代码状态

| 项 | 值 |
|---|---|
| 仓库 | `C:\Users\Administrator\Documents\Trae-CN\temp_20261102_01\mikcb` |
| 分支 | `compose-migration` |
| HEAD | `5a2d60b3` `fix(共享层): 闹钟纯逻辑下沉 core/，app/ 不再反向依赖 pages/course`（2026-11-02 23:54:47 +0800） |
| 5a2d60b3 祖先 | ✅ 是 |
| 与 origin/compose-migration | 同步（0/0） |
| 拉取方式 | `fetch` + `merge --ff-only`（先回滚了临时改动 `gradle-daemon-jvm.properties` 再快进） |

## 二、环境实际路径（全部不写全局）

| 工具 | 路径 | 版本 |
|---|---|---|
| Git（便携） | `C:\Users\Administrator\Documents\Trae-CN\temp_20261102_01\.tools\mingit\cmd\git.exe` | 2.47.1.windows.1 |
| PowerShell 7（便携） | `C:\dev\pwsh\pwsh.exe` | 7.5.4 |
| JDK 21 | `C:\dev\jdk\jdk-21.0.13+9` | Temurin 21.0.13+9 |
| JDK 17（既有，未动） | `C:\dev\jdk\jdk-17.0.20.1+1` | Temurin 17 |
| Android SDK | `C:\dev\android-sdk` | platforms: android-34/35/36/36.1/37.0；build-tools: 35.0.0/36.0.0/37.0.0；NDK 28.2.13676358 |
| Flutter | `C:\dev\flutter\bin\flutter.bat` | 3.44.8 stable / Dart 3.12.2 |
| Python 3（便携） | `C:\Users\Administrator\Documents\Trae-CN\temp_20261102_01\.tools\python313\tools\python.exe` | 3.13.9 |
| Kotlin 编译器（便携，L0 备用） | `.tools\kotlinc\bin\kotlinc.bat` | 2.4.21 |

### JDK 21 使用方式
- 本机全局 `JAVA_HOME` 仍是 JDK 17（未改）。
- 仓库根新增未跟踪文件 `mikcb/gradle.properties`：`org.gradle.java.home=C:/dev/jdk/jdk-21.0.13+9`（项目级，不改其他项目）。
- `android/gradle/gradle-daemon-jvm.properties` 保持仓库原样（`toolchainVersion=21`），Gradle 通过上述 `org.gradle.java.home` 解析到本机 JDK 21。

### Android SDK 说明
- `android/app/build.gradle` 实际 `compileSdk = 37`，已装 `platforms;android-37.0`（`platforms;android-37` 在 sdkmanager 中不存在，等价于 37.0）。
- 交接文档提到“对齐 build.gradle 的 compileSdk”——核对后确为 37，platform 37 计划**不作废**（此前误判过 36.1，已纠正并补装 37.0）。

## 三、四道门最后结果与时间

| 门 | 命令 | 结果 | 时间 |
|---|---|---|---|
| 门1 编译（L1） | `safe-gradle.ps1 :app:compileDevDebugKotlin` | ✅ BUILD SUCCESSFUL（13m22s 全量 / 2m40s 增量） | 2026-11-03 01:05 |
| 门2 整包单测（L2） | `safe-gradle.ps1 :app:testDevDebugUnitTest` | 进行中，回填后更新 | 2026-11-03 01:08 起跑 |
| 门3 样式守卫 | `compose-style-lint.ps1 -Domain all` | ✅ 9 处违规全在基线内，无新增 | 2026-11-03 00:58 |
| 门4 文案门禁 | `dart run tool/copy_style_lint.dart` | ✅ 无新增（203 超宽/1 死键均冻结基线内） | 2026-11-03 00:59 |

> 说明：门 3 曾遇两类环境阻塞，均已解决——①用户级 Pub 缓存目录被系统占用，改用仓库内 `PUB_CACHE=<repo>/.pub-cache` 并重建 package_config；②Maven Central TLS 握手失败，按仓库 `android/settings.gradle` 既有约定设 `CNB_BUILD_ID=local-mirror` 走国内镜像。**当前以仓库内 PUB_CACHE + CNB 镜像运行，gradle.properties 未动全局。**

### 自检2 备注
- 本机无 Android Studio，默认路径 `C:\Program Files\Android\Android Studio\plugins\Kotlin\kotlinc\bin\kotlinc.bat` 不存在。
- 已下载便携 Kotlin 2.4.21 到 `.tools\kotlinc`，通过临时 `PATH` 注入后 `test-kotlin-module.ps1` 正常执行。

### 自检3 阻塞与排查
- **现象1（已解决）**：`Failed to create parent directory ... connectivity_plus-7.3.1\android\build\intermediates` / `Unable to delete directory ... mergeDebugAssets`。
  - 根因：用户级 Pub 缓存目录 `C:\Users\Administrator\AppData\Local\Pub\Cache\...\connectivity_plus-7.3.1\android\build` 残留一个无法通过 PowerShell `Remove-Item` 删除的目录（takeown/icacls 也无效，但 `[System.IO.Directory]::Delete` 可删）。
  - 处理：用 .NET `Directory.Delete` 强制删除残留目录后，该问题消失。
- **现象2（进行中）**：`Could not GET 'https://repo.maven.apache.org/maven2/...` / `Remote host terminated the handshake`。
  - 根因：本机访问 Maven Central 网络不稳定（TLS 握手被中断），`kotlin-compiler-embeddable-2.4.21.jar` 下载失败。
  - 处理：按仓库 `android/settings.gradle` 的既有约定，设 `CNB_BUILD_ID=local-mirror` 启用国内镜像（腾讯云/阿里云）重试，正在下载依赖。
- 若镜像仍失败，下一步：离线手动下载 `kotlin-compiler-embeddable-2.4.21.jar` 放入 Gradle 缓存对应路径，或继续用国内镜像反复重试。

## 四、文件改动清单（未提交）

| 文件 | 说明 |
|---|---|
| `mikcb/gradle.properties` | 新增，项目级 JDK 21 指向（不提交） |
| `mikcb/scripts/safe-gradle-bom.ps1` | 新增，PS 5.1 兼容 BOM 副本（临时，不提交） |
| `mikcb/docs/plans/2026-11-03-night-autopilot-log.md` | 本日志（将提交） |

## 五、差异记录

| 事项 | 交接要求 | 实际执行 | 理由 |
|---|---|---|---|
| git 安装 | `winget install` / 全局 | 便携 MinGit `.tools\mingit` | 本机无 winget，且“不写全局”原则 |
| pwsh 安装 | `winget install Microsoft.PowerShell` | 便携解压 `C:\dev\pwsh` | 同上 |
| JDK 安装 | `winget install Temurin.21.JDK` | 便携解压 `C:\dev\jdk\jdk-21.0.13+9` | 同上 |
| Python | 未指定安装方式 | 便携 NuGet 包 `.tools\python313` | 无 winget，embed 版缺 stdlib 不可用 |
| platform 计划 | “作废 platform 37 计划” | **未作废**，核对 `compileSdk=37` 后安装 `android-37.0` | 交接说“以 build.gradle 实际值为准”，实际值是 37 |
| safe-gradle | `scripts/safe-gradle.ps1` | 当前用 `safe-gradle-bom.ps1`（PS 5.1 解析需要） | 仓库脚本为 UTF-8 无 BOM，PS 5.1 解析中文注释乱码报错；pwsh 7 无此问题 |

## 五·b、主控只读合规审计（db54ee4d..5a2d60b3）处置

按主控口径吸收，**不回滚、不追改禁改范围**，全部记此区待 Lead：

### A. 禁改范围被动过（记 Lead，不处理）
- `d5d933c6`：PagesShellActivity L220-222（+11/-12）且同时改 AndroidManifest main/debug —— 阻断级。
- `e6175771`：PagesShellActivity +4。
- `3de7e103`：PagesShellActivity +7。

### B. Flutter 侧 lib/** 被改（记 Lead，不处理）
- `80c70417`：lib/domain、lib/screens、lib/services。
- `29f7e5b1`：lib/services/webdav_sync_coordinator.dart。
- `cd9bd687`：lib/widgets/timetable/summary_card_flight.dart。

### C. 弹层条件挂载（可修，已认领为独立域）
- `30520931` ClassAlarmSheet.kt 确认弹层 `if (confirm != null) { OverlayDialog(show = true) }` —— **修复中（本代理域）**。
- C2 ExamTimePickerSheet L148-168：该文件名在当前工作区不存在（ClassAlarmSheet 内部引用的是外部 composable），按「已不成立」记，证据：全仓无 ExamTimePickerSheet.kt。
- C3 CourseActionSheet.kt L308-309：当前 L606-617 为 `if (activeSection.alarmAvailable) { ClassAlarmSheet(...) }` 字段齐备才挂载子弹层，非「条件挂载退场动画」问题，属正常按需挂载子 composable，按「已不成立」记。

### D. 基线只进不出（记 Lead，不处理）
- `824ef586`：cjk_hardcode_baseline.txt +25/-4 净涨 75 行登记 —— 违反「棘轮只进不出」。

### E. 流程（记 Lead，不处理）
- `e1ae5766`：126 文件一笔夹带两个无关壳文件。
- `e6175771` / `d5d933c6` / `83b2eb28`：自承 `--no-verify` 或绕 pre-commit。

### 审计确认合规（守卫有效，不放松）
miuix-only UI、无写死 sp/颜色/字重、无自研动画/转场、测试目录白名单、build.gradle/theme/lib/ui/路由表/MainActivity 未碰、六份 ARB 同步合规。

---

## 五·c、5 路并行域分工（2026-11-03 01:10 起）

| 路 | 域 | 范围 | 验收门 | 状态 |
|---|---|---|---|---|
| 1 | course 弹层常驻化 | ClassAlarmSheet.kt 确认弹层改常驻组合 + show 驱动 + remember 最后非空 | L0 + 门4 | 进行中（本代理） |
| 2 | timetable 样式债 | 门3 全量扫描的 9 处基线违规（DayViewScheduleCard/DayViewTaskBandCard/MonthDayCell/MonthPanelOverview 写死颜色、MonthViewPage 裸 LazyColumn、TimetableWeekPage 非惰性滚动）清债 | L0 + 门4 | 待认领 |
| 3 | sync 域接线/欠账 | docs/plans 派工大表 sync 域未完成项 | L0 + 门4 | 待认领 |
| 4 | 文案基线清债 | tool/copy_style_dead_keys_baseline.txt 死键清理（清掉删行，不加行） | 门4 | 待认领 |
| 5 | settings 域派工项 | docs/plans settings 域未完成项 / 弹层审计回填「仍成立」中 settings 相关 | L0 + 门4 | 待认领 |

> 约束：六份 ARB 同一时刻只许一路改；每路先核实现状再动手；不碰禁改范围；改完走对应门。

---

## 六、需 Lead 处理项

1. **Pub 缓存目录锁定**：`C:\Users\Administrator\AppData\Local\Pub\Cache` 被系统/安全软件占用，Gradle 写冲突。建议长期方案：为 Gradle/Pub 缓存加杀软白名单，或统一改用仓库内/非系统盘缓存。
2. **Android Studio 缺失**：L0 脚本默认找 AS 内置 kotlinc。便携 kotlinc 已 workaround，但 AS 缺失也意味着无法使用 IDE 调试。
3. **safe-gradle.ps1 BOM**：仓库脚本无 BOM，PS 5.1 无法直接运行；pwsh 7 正常。若团队仍有 PS 5.1 环境，建议给 `scripts/*.ps1` 统一加 BOM。

## 七、当前状态

- HEAD 达标（`5a2d60b3` ✅）。
- 环境已配齐（Git/pwsh/JDK21/SDK/Flutter/Python/kotlinc 全部可用）。
- 门 1（flutter --version）✅；门 2（L0 pages/shell）✅；门 3（L1 编译）进行中，阻塞在 Pub 缓存目录权限/锁定。
- 尚未进入 5 子代理自动推进；等门 3 通过后按派工大表认领域。
