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

## 三、四道门最后结果与时间（2026-11-03 02:35 主控复核后重测）

| 门 | 命令 | 最后一次执行结果 | 时间 |
|---|---|---|---|
| 门1 编译（L1） | `safe-gradle.ps1 :app:compileDevDebugKotlin` | ✅ BUILD SUCCESSFUL（7m08s 增量） | 2026-11-03 02:20 |
| 门2 整包单测（L2） | `safe-gradle.ps1 :app:testDevDebugUnitTest` | ✅ BUILD SUCCESSFUL（5m31s，全量测试通过，exit=0） | 2026-11-03 02:26 |
| 门3 样式守卫 | `compose-style-lint.ps1 -Domain all` | ✅ 5 处违规全在基线内，无新增（exit=0） | 2026-11-03 02:35 复测 |
| 门4 文案门禁（copy_style） | `dart run tool/copy_style_lint.dart` | ✅ 无新增（203 超宽/1 死键均冻结基线内，exit=0） | 2026-11-03 02:35 复测 |
| 门4 cjk 棘轮 | `python scripts/i18n-cjk-baseline.py --source-set composeP1` | ✅ 绿（压行后 exit=0） | 2026-11-03 02:35 复测 |

> **当前阶段：四道门全绿，全部有 2026-11-03 实测证据。** 门2 的 7 类红项全部修复并复跑确认（含 ComposePageStyleGuardTest 新增的 S5 OverlayDialog insideMargin 分支）。

### 远端 HEAD 核对（2026-11-03 02:35）
- 本地 `git log -1 --format=%H` = `5d97cf489a0d1610c50d9ccb3c4db6a25e791580`
- 远端 `git ls-remote https://github.com/Mutx163/mikcb.git refs/heads/compose-migration` = `5d97cf489a0d1610c50d9ccb3c4db6a25e791580`
- **一致**（已 `git fetch` 同步 remote-tracking，`status -sb` 无 ahead/behind）。

### 三个未跟踪文件处置（2026-11-03 02:35）
| 文件 | 处置 | 理由 |
|---|---|---|
| `gradle.properties` | 加进 `.gitignore`（`/gradle.properties`），不进库 | 含本机绝对路径 `C:/dev/jdk/jdk-21.0.13+9`（各机 JDK 路径不同），是本机配置非项目资产；保留在工作区供本机 Gradle 用 |
| `scripts/safe-gradle-bom.ps1` | **删除** | 交接文档明确「全程用 pwsh 7，不要系统自带 5.1」；该 BOM 副本是给 PS 5.1 的兼容兜底，pwsh 7 下无必要 |
| `scripts/with-kotlinc.ps1` | **路径限定提交**（`5d97cf48`） | 便携 kotlinc 闸门脚本，无 Android Studio 机器跑 L0（test-kotlin-module.ps1）必需，多路子代理复用，属项目资产 |

### 门2 失败清单（28 笔新提交未验暴露）与修复状态（2026-11-03 02:00 复核）
1. `CjkLiteralGateTest`：ImportCommon 已修但基线未下调 → ✅ 已压行修复（`6daddc8b`）。
2. `ComposePageStyleGuardTest`：基线 3 行 R5 对应违规已不存在 → ✅ B 路已删行（`fd8c7f3d`，DayView×2/MonthDayCell 写死色改语义槽）。
3. `ImportTemplateModelTest`：模板正文与 assets CSV 逐字节不一致 → ✅ E 路修复（`e75cdfe8`，CONTENT `\n`→`\r\n` 对齐 CSV CRLF 字节）。
4. `SettingsDialogOverlayGuardTest` / `SettingsResetConfirmationGuardTest` ×3：函数体行首收尾 `}` 找不到 → ✅ D 路修复（`1c42a026`，守卫读源码归一 LF，根因是 Windows CRLF 行尾让 `\n}\n` 匹配不到，属守卫本身该修）。
5. `LanEditSessionTest`：并发读侧未真读 → ✅ 修复（`d6893c97`，读循环改 do-while 保证至少真读一轮；断言口径过严、依赖时序，非业务 bug）。
6. `LanEditApiRouterTest` ×3：非法 weekExpression 应回 400 实回 500 → ✅ 修复（`1bc9e4f8`，组替换处理器就地捕获 `WeekExpressionException`（RuntimeException，route 的 IAE catch 接不到）回 400）。

> 全部 7 类门2 红项已修，门2 复跑验证中（回填最终结果）。

### 门4 cjk 修复记录
- 基线 `cjk-literal-baseline.txt` 的 `ImportCommon.kt:2` → `:1`（审计「965db6df 把层面量 2→1 未压行」），已提交 `6daddc8b`。
- 审计提到的 `cjk-literal-baseline.txt` 路径实为 `android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt`（`tool/cjk-literal-baseline.txt` 不存在）。

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

## 五·c、5 路并行域分工（2026-11-03 01:35 起，按主控 A~E 切分）

| 路 | 域 | 文件级互斥范围 | 验收门 | 状态 |
|---|---|---|---|---|
| A | 文案/l10n | 独占六份 ARB + TimetableProfilesPage 中文常量迁 ARB + copy_style 203 + dead key | 门4 + L0 | ✅ 主任务完成（d98eb76f 迁移 22 常量；ef1bcbe7 cjk 36→4 压行）。卡点：死键被 test 引用记 Lead；203 条超宽债**机制性卡死**（判据只扫 lib+ARB 均禁改，子代理实测 0 条可清，典型可清项已记 Lead） |
| B | course/timetable/共享件 | 裸 Popup、未用 import、QingyuSheet IME、守卫补 OverlayDialog S5、基线删行 | L0 + 门4 | ✅ 完成（fd8c7f3d 样式+import、52379d98 裸Popup+QingyuSheet IME+ClassAlarm 16dp、19338b2a 守卫 S5 分支） |
| C | sync 族 | 云备份整组 + 情侣整组 + SyncConflictChoiceDialog 三动作竖排 | L0 + 门4 | ✅ 完成（4bb71447 常驻组合化、8bd1f535 三动作竖排） |
| D | settings | 仅 SettingsHost.kt：说明框 8→12dp、守卫函数体收尾修复 | L0 + 门4 | ✅ 完成（1c42a026，间距 12dp + 守卫读源码归一 LF 修 CRLF） |
| E | statistics + import | 成就弹层整组、I2 四件、ImportTemplateModelTest 模板对齐 | L0 + 门4 | ✅ 完成（e75cdfe8 模板 CRLF 对齐、5517bd89 成就弹层×3 + 新增守卫棘轮） |
| F（补） | transfer/lan | LanEditApiRouter 400/500、LanEditSessionTest 并发断言 | L0 + 门4 | ✅ 完成（1bc9e4f8 组替换 400、2487203d parse 400、d6893c97 并发 do-while） |

**串行约束**：门 3（L1）绿之前只用 L0 + 门4 验收；六份 ARB 只归 A；壳/拍板/真机项不进 5 路。
**已不成立（别再改，主控审计+本代理复核）**：调课 480dp、周格白字、周加/减无障碍、备注 16dp、写死中文、导入两动作排布；ExamTimePickerSheet（文件不存在）；CourseActionSheet L308（按需挂载子弹层，非条件挂载）。
**被拍板挡住（不进 5 路，记此）**：42dp 空档×4、官方字阶、自动聚焦、选周结构、ICS 菜单、滚轮抢手势。
**文档已过时（记已不成立）**：ST1 classReminders、局域网撤销点、perf manifest、台账 P3-E 成就详情、§9.10 exam、DEMO 60→63；KDoc 自相矛盾 ×2（TimetableStore.kt:44、ClassAlarmSheet.kt:50）顺手修。

---

## 五·d、明早接手第一步

1. **拉代码**：`git fetch` + `merge --ff-only`，核对 HEAD。本代理已推送至 `52379d98`（含弹层守卫 S5）。
2. **复核四道门**：门1/门2 全绿（02:26）。若远端有新提交，先复跑门2 确认。
3. **继续推进**：5 路已全部完成（A~E + 补 F）。剩余候选：
   - 弹层核实子代理标「仍成立留 Lead」：WebDAV 连接弹层静态 show+动作不固定（需套件 footer 槽）、CloudBackupDetailSheet 半宽 Row 残留。
   - 拍板挡住项（42dp 空档、官方字阶、自动聚焦、选周结构、ICS 菜单、滚轮抢手势、解绑红+10dp）。
   - copy_style 203 条超宽债（机制性卡死，需解禁 ARB 外语词条；典型可清项：ja/ko 各 10 条未翻译英文兜底、en `homePullQuickImportSubtitle` 43.4>17 可压「Runs in the background」）。
   - 死键 `cloudSyncBaseUrlSecurityNote`（被 test 引用，判据口径外）。
4. **环境**：便携工具链全在 `.tools/`（mingit/pwsh 7.5.4 在 C:\dev\pwsh、python313、kotlinc）；JDK 21 在 `C:\dev\jdk\jdk-21.0.13+9`；PUB_CACHE 用仓库内 `.pub-cache`、CNB 镜像（`CNB_BUILD_ID=local-mirror`）。L0 套 `pwsh -File scripts/with-kotlinc.ps1 <cmd>` 自动注入便携 kotlinc。

---

## 六、五线并行分工与文件域锁定（2026-11-03 02:45 起）

> **并行方式已由内部子代理切换为 5 条可见的独立会话**（用户拍板）。原因：可核验性——独立会话的产出与提交在 GitHub 上逐线可追溯，内部子代理的工作区改动混在一处难以审计归口。内部 Task 派工已停止，不再补派。
> 本代理 = **A 线（文案/l10n）+ 协调线**。

### 通用红线（各线必须遵守）
- UI 只用 miuix + `QingyuPageScaffold`/`QingyuPageList`/`QingyuCard`；**禁止写死 sp/颜色/字重**、禁止自研动画；转场只用 miuix-nav `NavDisplay`。
- 弹层必须**常驻组合 + show 驱动 + remember 保留最后非空**，禁止 `if(show){Dialog}` 条件挂载。
- 测试新增只允许：`integration_test/`、`test/services/`、`test/domain/`、`test/models/`、`test/utils/`、`android/app/src/test/kotlin/`。
- Gradle 只走 `scripts/safe-gradle.ps1`；**禁止** `flutter build`/`assemble`/`bundle`/`adb` 及任何真机操作。
- 禁改：`android/app/build.gradle`、`theme/`、两个壳 Activity（PagesShellActivity/MainActivity）、`lib/ui/`、路由表、`lib/**`、`pubspec.yaml`。
- git：禁 `--amend`、`reset --hard`、`checkout --`、`clean -fd`、`add .`、强推、推 main、打 tag；提交只做路径限定。

### 各线文件域锁定

| 线 | 文件路径白名单 | 当前任务 | 验收闸门 | 禁止触碰 |
|---|---|---|---|---|
| **A（本代理）文案/l10n + 协调** | `lib/l10n/*.arb`、`android/app/src/**/i18n/**`（含 cjk-literal-baseline.txt / cjk_hardcode_baseline.txt）、`pages/timetable/TimetableStrings.kt`、`tool/` 下文案与样式基线及 copy_style 相关脚本、`docs/plans/` 日志 | copy_style 203 条欠账收敛、dead key 1 条、ARB 六份同步与 gen-l10n | 门4 + L0 | 其他线白名单外的一切 |
| **B 课表/课程/共享件** | `android/app/src/**/pages/course/**`、`pages/timetable/**`（**不含** `TimetableStrings.kt`）、`components/QingyuSheet.kt`、`pages/ComposeSheetGuardTest.kt` | QingyuSheet IME 叠加（:104-106）、标题动作对齐、弹层毛玻璃未接（QingyuSheet 零 blur 引用）评估与实现、守卫只拦 OverlayBottomSheet 的补全 | L0 + 门3 | lib/**、ARB、build.gradle、theme/、壳 |
| **C sync 族** | `android/app/src/**/pages/sync/**` | 云备份差异预览（CloudBackupDetailHost.kt:52-54）、sync 域剩余弹层与文案一致性（不动 ARB，需要的键报给 A） | L0 + 门3 | lib/**、ARB、其他域 |
| **D settings** | `android/app/src/**/app/SettingsHost.kt`、`pages/settings/**` | 主题动作表灰实心、设置子集（LanTransferApplier.kt:30 归属按台账核）、SettingsHost 剩余样式债 | L0 + 门3 | lib/**、ARB、其他域 |
| **E statistics + import** | `android/app/src/**/pages/statistics/**`、`pages/import/**`、`pages/import/warehouse/**` | I2 四件（原生 confirm/prompt、`saveCourseConfig` 落盘、替换/合并弹窗、宏录制，见 WIRING-NOTE.md:286-348） | L0 + 门3 | lib/**、ARB、其他域 |

### 协调线职责（本代理）
- 每小时用 `git push https://github.com/Mutx163/mikcb.git compose-migration:compose-migration` 推送一次。
- 每轮收口跑门 1（L1 编译）与门 2（整包单测）并回填日志（含时间戳）。
- 各线提交只做路径限定；若发现越界，立刻记日志「越界提交 + 哈希 + 文件」，**不回滚**。

### A 线进展（2026-11-03 02:50）
copy_style 超宽债 203 → **191 条**。已清 4 键 × 三语（en/ja/ko）：`homePullQuickImportSubtitle`（af1e70de）、`liquidGlassDarkIndependentSubtitle`/`layoutShowOtherWeeksSubtitle`/`homeWidgetShowTomorrowSubtitle`（d8699c72）。
**判据确认**（推翻子代理「机制性卡死」结论）：lint 只扫 `lib/**` 行控件绑定（`HyperosSwitchTile` 等的 `title`/`subtitle`/`details`/`hint`/`caption` 参数）× 六份 ARB 词条，**改短外语 ARB 词条即可清债**——ARB 属 A 线白名单，不动 lib。方法：读 zh 模板语义 → 压缩 en/ja/ko 到 ≤17 宽（说明）/≤11 宽（标题）→ `visualWidth`（汉字1/ASCII0.55/占位符3）核验 → 删基线对应行 → 门4 复测无新增。zh/zh_HK/zh_TW 模板已合规不动。
**后续**：剩 191 条按宽度降序逐批清（en 95 / ja 56 / ko 48 / zh_HK·zh_TW 各 2），每批提交+推送。

---

## 七、需 Lead 处理项

1. **Pub 缓存目录锁定**：`C:\Users\Administrator\AppData\Local\Pub\Cache` 被系统/安全软件占用，Gradle 写冲突。建议长期方案：为 Gradle/Pub 缓存加杀软白名单，或统一改用仓库内/非系统盘缓存。
2. **Android Studio 缺失**：L0 脚本默认找 AS 内置 kotlinc。便携 kotlinc 已 workaround，但 AS 缺失也意味着无法使用 IDE 调试。
3. **safe-gradle.ps1 BOM**：仓库脚本无 BOM，PS 5.1 无法直接运行；pwsh 7 正常。若团队仍有 PS 5.1 环境，建议给 `scripts/*.ps1` 统一加 BOM。

## 八、当前状态（2026-11-03 02:45 更新）

- HEAD = 远端 = `9e604163`（已核对一致，无 ahead/behind）。
- 环境已配齐（Git/pwsh 7.5.4/JDK21/SDK android-37.0/Flutter 3.44.8/Python 3.13.9/kotlinc 2.4.21，全便携不写全局）。
- 四道门全绿（L1 编译 ✅ 02:20、L2 整包单测 ✅ 02:26、样式守卫 ✅ 02:35、文案门禁+cjk 棘轮 ✅ 02:35）。
- 5 路（A~E + 补 F）已全部完成并经 L0/门3 验证；并行方式切换为 5 条独立会话，A 线（本代理）继续 copy_style 欠账与 ARB 同步。
