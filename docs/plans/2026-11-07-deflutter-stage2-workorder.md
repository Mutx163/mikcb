# 去 Flutter 化阶段 2 施工单（删 Dart、pubspec、撤 CI 的 Flutter 步骤）

- 日期：2026-11-07
- 状态：**已执行**（2026-11-07 ~ 11-08 陆续落地，见下「落地注记」；本单保留作施工记录）
- 前置：阶段 1 已提交 `c06ada02f`（编译期依赖已切断，默认路径与 `-PwithFlutter=false` 均编译通过）
- 复核：2026-11-07 晚（阶段 1 之后又进了 6 个提交；`f0a8426e4`/`9ec57c022` 把「Compose 按 locale 取 ARB 文案」落了地，ARB 从此多了一个**代码生成器**读者，见 §0 第 1 行）
- 适用范围：`lib/` 600 个 Dart、`test/` 578 个 Dart、`integration_test/` 13 个、`pubspec.yaml`、CI 的 Flutter 步骤

> **落地注记（2026-11-08）**：§0 的 4 处隐性耦合已按「P1 ARB 搬家（`fd7510ee8`）+ P2 发版解耦（`2af760bf2`）
> + P4-A 版本号迁到 `version.properties`（`dad3a9359`）+ P4-B 删插件与最后 3 个 io.flutter 文件（`1e8b953b7`）
> + P4-C 删 Dart 整层（`303220db1`）+ P4-D 流水线去 Flutter（`297184477`）」的顺序处理完毕；
> §0 第 3 条的三个审计步骤随 Dart 层一并退役（`tool/hyperos_audit.py` 等以 `lib/` 为对象者已失效，
> Kotlin 守卫取代）。`withFlutter` 门在 P4-B 时整套移除——默认**就是**无 Flutter 构型。
> 唯一未销的区别：文案守卫（`copy_style_lint` 链）移植到 Kotlin 尚未做，见 AGENTS.md 文案节。

## 0. 结论先行

删除本身是机械动作，真正会卡住的是**四处隐性耦合**，必须按顺序先解开，否则删到一半发布链路就断：

| # | 隐性耦合 | 证据 | 不解开的后果 |
|---|---|---|---|
| 1 | **ARB 文案住在 `lib/l10n/`**，但 Kotlin 构建、单测与代码生成器都读它 | `android/app/build.gradle:283` 把 `../../lib/l10n/app_zh.arb` 声明成 Gradle 测试输入；`AppLocaleRuntimeTest.kt:112`、`AddTaskFormReducerTest.kt:331` 用 `lib/l10n/app_zh.arb` 当仓库根哨兵；**`tool/gen_compose_arb_catalog.py:19` 的 `ARB_DIR = ROOT / "lib" / "l10n"`** 生成 `ArbCatalog.kt`（Compose 壳取文案的唯一真源） | 删 `lib/` 当天：Gradle 配置期报输入文件不存在，L2 直接红；生成器也断源，`ArbCatalog.kt` 与 ARB 脱钩 |
| 2 | **发布包是 Flutter 工具链打的** | `.github/workflows/android-build.yml:221` `flutter build apk --release --flavor prod` | 删 `pubspec` 后发不出正式包；必须换成 `assembleProdRelease` |
| 3 | **三个 CI 审计步骤以 `lib/` 为扫描对象** | `tool/hyperos_audit.py:104`（默认扫 `lib/screens`、`lib/widgets`）、`tool/cjk_hardcode_baseline.txt`（整表都是 `lib/...`）、`tool/audit_lint_ratchet.py`（`dart analyze`） | 删完这些步骤要么报错、要么变成空扫「假绿」 |
| 4 | **Flutter 依赖不只是「页面不用了」** | `.flutter-plugins-dependencies`（19KB，插件 Android 工程来源）、`GeneratedPluginRegistrant.java`（18 个插件类）、`settings.gradle` 的 flutter 插件请求与空实现兜底 | 只删 `lib/` 不删这些，默认构建仍然要 Flutter SDK，`withFlutter` 门永远撤不掉 |

另外两条纪律冲突要先讲明：

- `AGENTS.md` 写着「`test/widgets`、`test/screens`、`test/ui` 存量一律保留、不删不改」。阶段 2 要删的正是这批文件（三处合计 164 个）。**执行前必须把这条规则同步改写**，否则下一位 agent 会按旧规则把它们当成不可动资产。
- `AGENTS.md` 还写着「CI 里的 `flutter test` 保留不动」。阶段 2 撤掉它属于**用户已批的例外**，需要在同一提交里更新这句。

## 1. 阶段划分与顺序

五个阶段，每阶段一个独立提交，任何一步都能单独 `git revert`。顺序不可调换，原因写在每阶段的「为什么必须在这」。

### P0 · 冻结窗口与锚点（0 行代码）

- 确认没有任何会话正在改 `lib/`、`test/`、`pubspec.yaml`：当前工作区有 267 个未提交改动，必须等这些会话各自提交或明确放弃。
- 打锚点：`git tag pre-deflutter-stage2`（删除前最后一版可整体回来看）。
- 记录基线：当前 `c06ada02f` 的 L1/L2 结论（默认编译绿、`testDevDebugUnitTest` 337 任务绿）。

**回滚点 R0**：无代码变化，删错 tag 即可。

### P1 · 先把 ARB 搬出 `lib/`（行为零变化）

- 目标位置建议：仓库根 `i18n/`（与 `lib/` 平级，语义上不再是 Dart 资产）。
- 搬 `lib/l10n/*.arb`（**6 份**：zh / en / ja / ko / zh_HK / zh_TW）→ `i18n/`，同步改这几处读取方：
  - `android/app/build.gradle:283` 的 `test.inputs.file`
  - `AppLocaleRuntimeTest.kt`、`AddTaskFormReducerTest.kt` 等以 `lib/l10n/app_zh.arb` 当仓库根哨兵的 Kotlin 单测
  - **`tool/gen_compose_arb_catalog.py:19` 的 `ARB_DIR`**（`ROOT / "lib" / "l10n"` 写死）：改完必须重跑
    `python tool/gen_compose_arb_catalog.py` 刷新 `ArbCatalog.kt`，再用 `--check` 确认无漂移
  - 受影响的 3 个 Kotlin 单测：`ArbCatalogTest`、`AppLocaleRuntimeTest`、`NoRawChineseAccessorTest`
    （后者若按路径白名单判「不许裸中文」，搬目录后白名单要同步）
  - `l10n.yaml`（若保留 `gen-l10n` 过渡期）与 `tool/copy_style_lint.dart` 里的 ARB 路径
- 顺手补一道防漂：生成器目前**只被自己引用**（`scripts/`、`.github/`、`docs/` 里都没有调用点），
  搬完建议在 CI 加 `python tool/gen_compose_arb_catalog.py --check`，否则 ARB 一改、`ArbCatalog.kt` 就悄悄过期。
- **为什么必须在这**：`lib/` 一删，ARB 就没了；而 ARB 是 Kotlin 侧文案的唯一真源。

**验收**：L2 `:app:testDevDebugUnitTest` 绿（重点看 i18n 对拍与 CJK 棘轮）。

**回滚点 R1**：`git revert <P1>`，ARB 回到 `lib/l10n/`。

### P2 · 撤 CI / 发布链路里的 Flutter（先换发版命令，再删步骤）

- `android-build.yml`：
  - `flutter build apk --release --flavor prod --target-platform android-arm64` → `./gradlew :app:assembleProdRelease`（签名与 `OVERRIDE_VERSION_NAME` 注入方式保持现状）。
  - 删 `flutter pub get` / `flutter analyze` / `flutter test` 三步；`Set up Flutter` 若不再需要一并删。
  - 注意 L32 的「Reuse green CI for this commit」依赖 `ci.yml` 的结论，撤步骤时别把这条判据弄坏。
- `ci.yml`：删 `flutter pub get`、`Analyze`、`Test` 三步；`HyperOS 页面合规审计`、`CJK 硬编码审计` 改成只扫 Kotlin/Compose 源（或暂时跳过并在后续单里补新判据）；`Lint ratchet` 停用或换 `ktlint` 口径。
- `gradle-cache-warm.yml`：删 `flutter pub get`。
- **为什么必须在这**：发版命令没换成 Gradle 之前删 `pubspec`，等于把发布链一起删掉。

**验收**：`tool/verify_action_pins.sh` 过；用户在本地或分支上试跑一次 `assembleProdRelease`（**L3 出包只能用户跑**，agent 不做）。

**回滚点 R2**：`git revert <P2>`，发版命令回到 `flutter build apk`。

### P3 · 构建改为「永远无 Flutter」

- `settings.gradle`：删 flutter 的 `pluginManagement` 分支、`includeBuild` 两条路径、`plugins{}` 里的 `dev.flutter.flutter-plugin-loader`。
- `app/build.gradle`：删 `withFlutter` 门、`flutter { source }`、`flutter.versionCode/versionName` 分支、Kotlin/Java 编译任务的排除块；`versionCode`/`versionName` 改成显式值（原来从 pubspec 来，必须显式化，否则发版号会错）。
- 删文件：`android/noflutter-flutter-loader-stub/`、`src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`、`MainActivity.kt`、`FairMemoryFlutterBridge.kt`。
- 改清单：`dev/`、`perf/`、`itest/` 三份 `AndroidManifest.xml` 里对 `.MainActivity` 的引用；`itest` flavor 与 `integration_test/` 一起退场。
- **为什么必须在这**：`pubspec` 一删，flutter 插件请求就解析不到；必须先把构建改成不请求它。

**验收**：L1 `:app:compileDevDebugKotlin` 绿（此时已无 `withFlutter` 开关，绿就是真绿）；L2 绿。

**回滚点 R3**：`git revert <P3>`，恢复 `withFlutter` 门与两个 Flutter 文件。

### P4 · 删 Dart 与配套文件

- 删：`lib/`（600）、`test/`（578）、`integration_test/`（13）、`pubspec.yaml`、`pubspec.lock`、`analysis_options.yaml`、`l10n.yaml`、`.flutter-plugins-dependencies`、`.metadata`。
- **为什么必须最后**：这是不可逆的体量最大一步，前面所有读取方都已改完。

**验收**：L1 + L2 仍绿（此时仓库已无 Dart，任何残留引用都会在编译期暴露）；`git grep -n "lib/l10n\|flutter_assets\|package:flutter"` 应为零。

**回滚点 R4**：`git revert <P4>`（或 `git checkout pre-deflutter-stage2 -- lib test integration_test`，只读恢复，不用 reset）。

### P5 · 收尾

- `.gitignore` 清理 Dart/Flutter 条目；README 与 `docs/` 里的「flutter build」指令改掉。
- 更新 `AGENTS.md` 两条冲突规则（见第 0 节）。
- 笔记：`.agents/notes/implemented/architecture/` 新增阶段 2 记录，与阶段 1 笔记互链。

## 2. 回滚点总表

| 点 | 触发情形 | 动作 | 恢复后要复验 |
|---|---|---|---|
| R0 | 删除前 | `git tag pre-deflutter-stage2` | — |
| R1 | ARB 搬迁后 L2 红 | `git revert <P1>` | L2 |
| R2 | 发版命令改完发不出包 | `git revert <P2>` | 用户跑一次 `assembleProdRelease` |
| R3 | 去掉 `withFlutter` 门后 L1 红 | `git revert <P3>` | L1 + L2 |
| R4 | 删 Dart 后出现未预期引用 | `git revert <P4>` | L1 + L2 |

全部使用 `git revert` / `git checkout <锚点> -- <路径>`；**不使用** `reset --hard`、`clean`、`checkout -- .`。

## 3. 需要你拍板的四件事

1. **执行窗口**：`lib/` 现在还有别的会话在改（267 个未提交文件里含大量 Dart）。删 `lib/` 会把这些在途工作一起带走，必须等它们落地或明确放弃。什么时候开窗由你定。
2. **ARB 新家**：我建议仓库根 `i18n/`；若你更想放 `android/app/src/main/assets/i18n/`（随包走、运行时可读），顺序不变，只是读取方改法不同。
3. **`AGENTS.md` 两条规则改写**：`test/{widgets,screens,ui}` 保留规则、CI 保留 `flutter test` 规则，阶段 2 都要改。是否授权我在 P4 同一提交里改？
4. **发布验证谁跑**：`assembleProdRelease` 属 L3，agent 不许跑。P2 的验收需要你在本地或分支上跑一次；否则 P2 只能算「改了没验」。

## 4. 明确不做的事

- 不删 `docs/`、`tool/` 里与 Dart 无关的部分。
- 不动 `.agents/`（本机私有，不入库）。
- 不在本轮顺手改任何页面行为；阶段 2 只做删除与接线。
- 不声明「能装能跑」：本单所有验收只到编译与 JVM 单测，真机与出包由你确认。

## 5. 阶段 1 现状复核（2026-11-07 晚，只读静态核对）

- 构建门仍在：`app/build.gradle` 里 `withFlutter` 命中 12 处；`ci.yml` 的 `continue-on-error` 命中 3 处（两步 + 一条注释）。
- Kotlin 侧仍只有 2 个文件 `import io.flutter`（`MainActivity.kt`、`FairMemoryFlutterBridge.kt`），Java 侧只有
  `GeneratedPluginRegistrant.java` —— 与阶段 1 的剔除清单完全一致，说明这轮 300+ 文件的改动没有把 Flutter 依赖带回来。
- `python tool/gen_compose_arb_catalog.py --check` 通过：`ArbCatalog.kt` 与 6 份 ARB 同源，当前无漂移。
- **本轮未跑编译**：工作区还有 60 处其他会话的在途改动，按规矩不在半成品上跑 L1/L2。开窗前要补跑：
  默认 `:app:compileDevDebugKotlin`、`-PwithFlutter=false` 的 `:app:compileDevDebugJavaWithJavac`、
  `:app:testDevDebugUnitTest --rerun-tasks`。
