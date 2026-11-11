# 发行教程

这份文档只写当前仓库实际在用的发布方法。Dart 层已删除（去 Flutter 化 P4-C），文中不再有 `flutter` 命令；构建一律走 Gradle。

先记住 8 句话：

- `push` 到任意分支或提 PR，会跑 `ci.yml` 的 JVM 单测门禁。
- 只有推送 `v*` tag，才会触发 `android-build.yml` 构建正式 APK、创建或更新 GitHub Release，并同步 GitCode 镜像。
- **预发布还是正式，唯一由 `android/version.properties` 的 `versionName` 是否含 `-` 决定；commit message 写什么都无效。**
- tag 名必须和 `versionName` 配套，`android-build.yml` 会在出包前逐字校验（见第四节）。
- 默认只升第 4 位（`2.0.4` → `2.0.4.1`）；不要因为本地草稿就升第 3 位。
- 出包归维护者：`assemble*` / `bundle*` 与真机操作由人在 Windows 侧跑，agent 不跑。
- 推送 tag 后必须完成第八节的产物核验，才能宣告发布完成。
- 已打 tag、已进 `docs/releases/latest.json` 的 `docs/releases/v*.md` 是只读历史：不许再追加功能条目。

## 一、现在这条发版链

| 工作流 | 触发 | 做什么 |
|---|---|---|
| [ci.yml](../.github/workflows/ci.yml) | 任意分支 push、PR | 校验 `version.properties`（BOM + 格式）、校验 Action 固定 SHA、跑 `:app:testProdDebugUnitTest` |
| [android-build.yml](../.github/workflows/android-build.yml) | `v*` tag push、手动 | 校验发版元数据 → 签名构建 → 5 MB 门禁 → 建或改 GitHub Release → 触发 `latest.json` 更新 → 同步 GitCode |
| [update-docs-releases.yml](../.github/workflows/update-docs-releases.yml) | Release 事件、每 6 小时、手动 | 扫全部 Release，重写 `docs/releases/latest.json` 与 `feed.json`，跳过小于 5 MB 的附件 |
| [sync-main-to-gitcode.yml](../.github/workflows/sync-main-to-gitcode.yml) | push 到 `main`、文档工作流结束、每天 | 把 `main` 同步到 GitCode 镜像仓库 |
| [sync-release-channel-to-gitcode.yml](../.github/workflows/sync-release-channel-to-gitcode.yml) | Release 事件、手动 | 把预发布 / 正式状态同步到 GitCode 对应 Release |
| [gitcode-backfill.yml](../.github/workflows/gitcode-backfill.yml) | 手动 | 把某个历史 tag 补同步到 GitCode（真 APK + 说明） |
| [gradle-cache-warm.yml](../.github/workflows/gradle-cache-warm.yml) | Gradle 相关文件改动进 `main`、每周一 | 预热 Gradle 依赖缓存；tag 构建读到的就是这份缓存 |
| [update-docs-schools.yml](../.github/workflows/update-docs-schools.yml) | 每天、手动 | 从 `qingyu_warehouse` 拉 `root_index.yaml` 生成 `docs/schools.json` |

[android-build.yml](../.github/workflows/android-build.yml) 分五个 job：

1. `Analyze and Test`：先看同 SHA 的 `ci.yml` 有没有 `main` 上的全绿记录，有就跳过单测（约 7～8 分钟省下来），没有才跑 `:app:testProdDebugUnitTest`。不管是否复用，发版元数据校验每次必跑；手动触发（`workflow_dispatch`）时 `inputs.tag` 填要校验的版本号（不带 `v`），留空则按 `GITHUB_REF_NAME` 推断。
2. `Build and Publish Android APK`：只在 `refs/tags/v*` 上跑。读版本号 → 准备签名 → `:app:assembleProdRelease` → 选包 + 两道 5 MB 门禁 → 上传 artifact 与蒲公英 → 建或改 GitHub Release。
3. `Sync releases JSON to docs`：触发 `update-docs-releases.yml`。
4. `Sync code to GitCode`：把 `main` 与全部 tag 同步到 GitCode 镜像。
5. `Sync release to GitCode`：把本次 APK 挂成 GitCode Release 附件。

后两个需要仓库变量 `GITCODE_USERNAME`，没配就整个 job 跳过，不会让发版失败。

CNB 侧（[.cnb.yml](../.cnb.yml)）另有一条配合流水线：push / PR 跑 JVM 单测，`tag_push` 用密钥仓库里的签名出包。**当前不作为发布通道**：根组织的「云原生构建-CPU」配额自 2026-09-03 起耗尽，push / PR 流水线在 Prepare 阶段直接报错（`.cnb.yml:119-138`）。CNB 的 tag 流水线只按 tag 名取版本号，没有 GitHub 那三道校验，即使跑通也不作权威产物。代码镜像照推（`git push origin` 会同时推 GitHub 与 CNB），CNB 的 Release 失败不算发布失败。

## 二、本地三层门禁（L0 / L1 / L2）

这三层由开发这侧跑，出包之前必须先绿。

| 层 | 命令 | 证明什么 | 不能证明什么 |
|---|---|---|---|
| L0 | `pwsh -File scripts/test-kotlin-module.ps1 -Module "<域>"`，域就是 `android/app/src/*/kotlin/com/mutx163/qingyu/pages/` 下的目录名（`export`、`schedule`、`sync`、`sheetguard` 等；共享模型层 `app` / `core` / `theme` 等会自动带上） | 该域模型层 JVM 单测通过 | 渲染层编译；`composeP1` 里的 Compose 检查 |
| L1 | `pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` | Kotlin 全量编译通过（含 `composeP1` 渲染层） | R8 规则对不对；装得上装不上 |
| L2 | `pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest` | 全部 JVM 单测通过 | 真机行为；性能 |

三条纪律：

- **L1 / L2 必须走 `safe-gradle.ps1`**，它内置全机互斥锁，同一时刻只允许一个 Gradle；裸跑 `./gradlew` 会和别人的构建互抢。
- L0 的编译面只含 `main` 源集（`composeP1` 用了 `androidx.compose` / `miuix`，纯 JVM 的 kotlinc 编不了）。**改动 `composeP1` 下的文件，L0 绿不代表编得过**，最后要等 L1。
- 声明纪律：只能说「编译通过」（L1）或「JVM 单测通过」（L2），不能说「能跑 / 能装上 / 已验证」。

配套的几条检查，改到对应范围就跑：

```powershell
# 页面样式守卫（只跑自己域；-Write 只删过期例外，绝不新增）
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain <域>

# 文案编排守卫（六份 ARB → ArbCatalog 同源）
pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest

# composeP1 免 Gradle 早筛：不抢编译锁也能查悬空引用 / 签名不匹配 / import 缺失
pwsh -File scripts/typecheck-compose.ps1

# CJK 字面量棘轮：当前树 vs 基线，只报增减
python scripts/i18n-cjk-baseline.py
python scripts/i18n-cjk-baseline.py --source-set main
```

`typecheck-compose.ps1` 只是早筛，它没有 Compose 编译器插件，绿了也不能替代 L1。CJK 基线文件由多条线共写，每块带手写理由注释，**不要为了对齐去跑 `--write` 整文件重生成**，那会冲掉别人的注释；发现计数不一致，让写那块代码的人自己登记。

L3 / L3.5 / L4 不在这张表里，归维护者，见下一节。

## 三、出包（L3）：只有一条命令

[android-build.yml](../.github/workflows/android-build.yml) 的生产出包是：

```bash
cd android && ./gradlew :app:assembleProdRelease --no-daemon
```

Windows 本地等价写法：

```powershell
cd C:\cursor\mikcb\android
.\gradlew.bat :app:assembleProdRelease -POVERRIDE_VERSION_NAME=3.0.0
```

- `-POVERRIDE_VERSION_NAME` 让本地包的 `versionName` 与 CI 产物一致（CI 用 tag 名覆盖，见 `android-build.yml:195-202` 与 `android/app/build.gradle:38`）。不加时显示 `version.properties` 里的原值，例如 `3.0.0-0`。
- `versionCode = versionCodeBase + 100000`（`android/app/build.gradle:69`）。这个偏移是分 ABI 打包时代留下的，防止新版被系统判成降级。`versionCodeBase=150` ⇒ `100150`。
- `prodRelease` 是唯一「同包名 + 同签名 + R8 开启」的变体：`minifyEnabled true`、`shrinkResources true`（`android/app/build.gradle:186-187`），ABI 只有 `arm64-v8a`（`:80`），minSdk 33（`:59`）。
- 签名读 `android/key.properties`（四键：`storeFile` / `storePassword` / `keyAlias` / `keyPassword`），或环境变量 `ANDROID_KEYSTORE_PATH` 等。缺签名会在任务图阶段直接报错，不会产出未签名包（`:327`）。
- 产物在仓库根的 `build/app/outputs/apk/prod/release/app-prod-release.apk`（`android/build.gradle` 把产物统一到根 `build/`）。

几条硬要求：

- **不要从 Android Studio 拷 APK**：AGP 会给它注入 `android:testOnly="true"`，普通安装被系统拒绝。AS 里点 Run 出的包同样不要用。
- **不要用 `prodDebug`**：debug 签名 + 正式包名，会和手机上的正式版撞签名，装不上。
- `prodBench` 已白名单关闭（`android/app/build.gradle:250`）。性能只有 `assemblePerfBench` 一个变体可用，包名带 `.profile`、数据是空的，只能比启动与帧率，不能代表真实数据量。
- 出包前先做一次应用内备份：卸载会清数据，回滚只能靠备份。

装前逐条核对（`<sdk>` 换成本机 SDK 路径，build-tools 用 36.0.0）：

```powershell
$apk = 'build\app\outputs\apk\prod\release\app-prod-release.apk'
& "$bt\aapt2.exe" dump badging $apk | Select-String 'versionCode|versionName|minSdk'
& "$bt\aapt2.exe" dump xmltree $apk --file AndroidManifest.xml | Select-String 'testOnly'
& "$bt\apksigner.bat" verify --print-certs $apk
```

预期：`versionCode` 等于 `versionCodeBase + 100000`、`minSdkVersion` 为 33、`testOnly` 无输出、证书指纹与已发布版本一致（不一致会 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`）。

R8 冒烟（`prodRelease` 包必过）：冷启动 3 次、桌面小组件各看一张、教务导入走一遍网页登录、相机扫码、云备份恢复。logcat 过滤 `FATAL EXCEPTION`、`ClassNotFoundException`、`NoClassDefFoundError`、`NoSuchMethodError` 为空。任何一条不过，先补 `proguard-rules.pro` 的 keep 再重出包，**不许关掉 R8 出货**。

## 四、版本号与 tag 规则

### 1. 包内版本：唯一事实源是 `android/version.properties`

```properties
versionName=3.0.0-0
versionCodeBase=150
```

- `versionName`：对外显示的版本号。带 `-` 即预发布。
- `versionCodeBase`：Android 的 versionCode 基数，脚本加 100000 后写进包。
- 文件必须 UTF-8 **无 BOM**：带 BOM 会让字段读不出来，CI 与 `tool/verify_release_version.sh` 都会拦。

### 2. 对外版本：tag 与发版说明文件

- tag：`v<对外版本>`，例如 `v3.0.0`。
- 发版说明：`docs/releases/v<对外版本>.md`，**首行必须是 `# v<对外版本>`**，一字不差。

### 3. tag 与 versionName 的配套规则（CI 逐字校验）

`android-build.yml:59-84` 会在出包前把 `versionName` 换算成应有的 tag 名，和本次 tag 比对：

| `versionName` | 换算 | 应打的 tag |
|---|---|---|
| `3.0.0-0` | 去掉 `+` 段，去掉结尾的 `-0` | `v3.0.0` |
| `2.1.4.1-0` | 去掉结尾的 `-0` | `v2.1.4.1` |
| `1.1.10-6` | 末尾的 `-6` 变成 `.6` | `v1.1.10.6` |
| `1.1.11` | 原样 | `v1.1.11` |

同一层还会检查：说明文件存在、首行是 `# v<tag>`、`> 本次重点` 在不在。前两项不匹配直接失败，第三项只警告。

### 4. 升哪个位

| 段位 | 例子 | 默认 |
|---|---|---|
| 第 1 / 2 位 | `2.0` | 禁止自作主张 |
| 第 3 位 | `2.0.x` | 禁止默认 +1；只在人工明确点名新基线时动 |
| 第 4 位 | `2.0.4.n` | 默认 +1，预发布与正式都优先四段 |

未指定版本号时，以最后一个**已打 tag 并发布**的版本为准（不是本地草稿文件名）：已发 `v2.0.4` → 下一发 `v2.0.4.1`。

### 5. 多个未发布草稿

本地写了好几份 `v2.0.5.md` 到 `v2.0.9.md`、但一次都没打过 tag：不要按最大号发。默认按「最后已发布基线 + 第四位 +1」发一版，把所有未发布草稿合并进这一份即将发版的说明文件，只打一个 tag。已经发过的文件不要合并、也不要追加。

## 五、渠道：这次是预发布还是正式

唯一判定源是 `versionName` 里有没有 `-`（`android-build.yml:136-140`）：

| 意图 | `versionName` 写法 | GitHub Release | `latest.json` |
|---|---|---|---|
| 预发布 | 含 `-`，如 `3.0.0-0`、`1.1.10-6` | `prerelease: true` | 进 `prerelease` 栏 |
| 正式 | 不含 `-`，如 `3.0.0`、`1.1.11` | `prerelease: false` | 进 `stable` 栏 |

**不能决定渠道的东西**：commit message 有没有写 `prerelease`、tag 是三位数还是四位数、说明文件叫什么、tag 里有没有 `beta`。

三位数版本也能预发布：`versionName=1.3.2-0` + tag `v1.3.2`。`-0` 只用来触发预发布判定，对外显示仍是 tag 里的 `1.3.2`。

原地转正式：不换版本号、不重发，去 GitHub Release 页面把这条 Release 的 Pre-release 取消即可。`sync-release-channel-to-gitcode.yml` 会把状态同步到 GitCode，不用再去国内镜像手改一遍。

## 六、发版前置检查

切版本、推送前按顺序跑这三条：

```bash
# 1) 版本号格式与渠道是否匹配（按本次渠道二选一：prerelease 要求含 '-'，release 要求不含）
bash tool/verify_release_version.sh prerelease
# bash tool/verify_release_version.sh release

# 2) 发版体检：版本 / tag 重名 / 说明文件 / 工作区脏文件 / 落后远端 / 当前 HEAD 的 CI
bash tool/release_preflight.sh

# 3) 「本次重点」那行能不能认回正文条目（Windows 上把 python3 换成 python）
python3 tool/check_release_highlights.py
```

`release_preflight.sh` 输出 PASS / WARN / FAIL：

- 有 **FAIL** 就别打 tag。
- **WARN** 允许继续，但逐条看一眼它说的是什么（常见：工作区有未提交文件、落后远端、HEAD 的 CI 还没跑）。
- `--offline` 跳过联网项，`--retag` 只在 Tag recovery 时用（重打同名 tag 前先删远端 tag）。
- 它还会检查许可快照：`NOTICES.gz` 必须已按 Android 依赖重生成（快照里要有 `androidx` 条目）。依赖有变时重跑许可生成脚本，并同步 `FlutterAssetsDecouplingGuardTest` 里的钉值，否则体检判红。

推送顺序固定：**先 main 绿，再打 tag**。两步并行会拿到「main 红、tag 必挂」的结果。

## 七、发版步骤

### A. 推 main，等 CI 绿

```bash
git status --short          # 期望：空
git fetch origin
git push origin main        # 同时推 GitHub 与 CNB
gh run list --workflow=ci.yml --branch main --limit 1
gh run watch <run-id> --exit-status
```

失败先修 main，**绝不在红树上打 tag**：tag 的检查与 CI 同源，main 红 tag 必红。

### B. 打 tag，推 tag

```bash
git tag -a v3.0.0 -m "chore: cut v3.0.0 prerelease"   # 正式版写 release
git show v3.0.0 --no-patch --format='%H %s'           # 确认指向 main HEAD
git push origin v3.0.0
```

推 tag 前再确认一次：`version.properties`、说明文件名、tag 名三者配套（第四节）。本地打错还没推时，`git tag -d v3.0.0` 删掉重打是安全的。

### C. 等构建，验产物

```bash
gh run list --workflow=android-build.yml --limit 1
gh run watch <run-id> --exit-status
gh run view <run-id> --json jobs --jq '.jobs[] | "\(.name) => \(.conclusion)"'
```

预期五个 job 全绿（`GITCODE_USERNAME` 没配时后两个会显示跳过）。时长 15～30 分钟，无缓存更久。

失败处置：

- 临时故障（网络、runner 抽风）→ `gh workflow run android-build.yml --ref v3.0.0` 重跑。**`--ref` 必须选 tag**，选分支会让 `publish` 被跳过。
- 代码或 workflow 本身有问题 → 走第十二节的 Tag recovery，先报维护者批准。
- CNB 报配额错 → 已知问题，忽略。

可选收尾：tag 成功后把 `version.properties` 抬到下一预发布号（例如已发 `v3.0.0` 就写 `versionName=3.0.0.1-0` 并把 `versionCodeBase` 加一），避免「代码已经往前走了、版本号还停在上一个已发号」的误导。不抬也不构成修改已发说明的理由。

## 八、Post-tag 验证（必做）

推送 tag 不等于发布完成。以下五项全过才算发好：

| # | 检查 | 通过标准 |
|---|---|---|
| 1 | GitHub Actions `Android Build` | `Analyze and Test` 与 `Build and Publish Android APK` 都绿 |
| 2 | artifact `android-release-apk` | APK 大于 5 MB（CI 在选包与上传前各校验一次） |
| 3 | GitHub Release 附件 | 恰一个 `mikcb-<版本>-arm64-v8a.apk`，大于 5 MB |
| 4 | Release 渠道 | 预发布这次必须勾着 Pre-release，正式这次必须没勾 |
| 5 | 包的身份 | `versionCode`、`versionName`、签名三项与预期一致 |

第 5 项 CI 不做，必须自己核。把已发布的包拉下来查：

```powershell
$dir = Join-Path $env:TEMP 'relcheck'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
gh release download v3.0.0 --pattern 'mikcb-*.apk' --dir $dir

& "$bt\aapt2.exe" dump badging "$dir\mikcb-3.0.0-arm64-v8a.apk" | Select-String 'versionCode|versionName|minSdk'
& "$bt\apksigner.bat" verify --print-certs "$dir\mikcb-3.0.0-arm64-v8a.apk"
```

任何一项不符，按坏包处理：走 Tag recovery，**不许手工 `gh release create` 补空资产或占位资产**。

再等两件事落地：

- `latest.json` / `feed.json`：`update-docs-releases.yml` 通常 1 分钟内提交，`git fetch origin` 后看 `docs/releases/latest.json`。没触发就手动 `gh workflow run update-docs-releases.yml`。
- GitCode 镜像：构建里的 `Sync code to GitCode` / `Sync release to GitCode` 绿即完成。附件上传是异步的，不用等。补建历史版本用 `gh workflow run gitcode-backfill.yml -f tag=v3.0.0`。

## 九、镜像与渠道配置

GitHub 侧需要这些东西（缺哪条，对应环节静默跳过或报错）：

| 类型 | 名称 | 用途 |
|---|---|---|
| Secret | `ANDROID_KEYSTORE_BASE64` | 签名 keystore 的 base64 |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | keystore 口令 |
| Secret | `ANDROID_KEY_ALIAS` | 密钥别名 |
| Secret | `ANDROID_KEY_PASSWORD` | 密钥口令 |
| Secret | `PGYER_API_KEY` | 蒲公英上传（第二镜像，失败不阻塞） |
| Secret | `GITCODE_TOKEN` | GitCode 写权限令牌 |
| Variable | `GITCODE_USERNAME` | GitCode 用户名，**同时当同步开关** |
| Variable | `GITCODE_REPOSITORY`（可选） | GitCode 仓库路径与 GitHub 不同名时才要 |

- GitCode 仓库要先在网页端建好空仓库，推送不会自动创建。首次同步会把 `main` 全部历史与全部 tag 一起推过去。
- GitCode Release 正文是发版说明全文 + 一行 `SHA-256:` 摘要（GitCode 没有附件摘要，应用内校验靠这一行）。不要手工改写这段摘要，包换了要重新发。
- CNB 的签名密钥在独立密钥仓库 `Mutx163/qingyukb-keys` 的 `android-release.yml`（CNB 网页维护，禁止 clone / push），只在 `tag_push` 流水线注入。
- 蒲公英是可选第二镜像，`continue-on-error`，它失败不影响 GitHub Release。

## 十、更新日志写法

`docs/releases/v*.md` 是给用户看的版本摘要，不是提交记录。

### 1. 先判「最后已发布」

动手前至少核一项：

- `git tag -l 'v*' --sort=-v:refname`，并确认是否已推远端；
- `docs/releases/latest.json` 里的 `stable.version` / `prerelease.version`。

**最后已发布 = 已有对应 tag，或已进 `latest.json`**（预发布也算已发布）。`version.properties` 里的版本号不能单独当依据。

### 2. 哪些文件能改

| 情况 | 允许做什么 |
|---|---|
| 对应版本已发布 | 只允许改错别字、断行；可补一行 `> 本次重点：…`。**不许追加功能条目** |
| 从没打过 tag、从没上架 | 可编辑；多份未发草稿合并进即将发版的那一份 |
| 只说「写更新日志」 | 写进下一个未发布版本，默认第四位 +1 |
| 只说「提交代码」 | 不要动 `docs/releases/` |

### 3. 版式

按分类分组，条目本身不重复类型词：

```markdown
# v3.0.0

> 本次重点：全站界面换成 Compose 重写版、首页多了月视图

## 新增 · 2

- 全站界面换成 Compose 重写版：……
- 首页多了月视图：……

## 优化 · 3

- ……

## 修复 · 5

- ……
```

规则：

- 分组标题用 `##`，条数是给人扫读的；空分类整节不写。
- 顺序固定：新增 → 优化 → 修复 → 移除。
- 顶部 `> 本次重点` 最多 3 条，用「、」分隔。
- **重点必须能认回下面的条目**：直接抄条目里的原话最稳。自己另起一种说法（条目写「转场更顺」、重点写「转场掉帧」）就认不回来，App 里那条会变成没有分类标签的灰色重点。发版前跑 `python3 tool/check_release_highlights.py` 自检。
- 历史版本（v2.1.3.4 及以前）是扁平列表 + 类型前缀，解析器两种都认，**不需要重写历史**。

### 4. 写什么、不写什么

只写用户能感知的三类：**新增**（第一次拥有这个能力）、**优化**（这个能力更顺更稳）、**移除**（这个能力没了）。

不要写：

- 「修复英语」「修复国际化」这类按实现层分类的说法；
- 只对开发者有意义的重构、守卫、测试、依赖升级；
- 某个新功能内部的小 bug（写进「新增」或「优化」的那条里）。

`> 本次重点` 这一行同时决定三个地方的第一屏：App 更新弹窗、App 历史版本页、官网更新日志。没写就只能按「新增 > 优化 > 修复 > 移除」猜前三条。

## 十一、常见坑

**1. tag 推了，构建没跑**

- 只推了 `main`，没推 tag；
- tag 名不是 `v*`；
- tag 还在本地。

**2. tag 构建在元数据检查就失败**

三类原因：`version.properties` 带 BOM、tag 与 `versionName` 不配套、说明文件不存在或首行不是 `# v<tag>`。报错会写出「按某个版本应打 v…」的推导；提示文案里还留着 `pubspec` 字样，那是去 Flutter 化时漏改的措辞，不影响判据。

**3. 说明文件没生效**

Release 正文读的是 `docs/releases/v<tag 去掉 v>.md`。tag 是 `v1.1.10.6`，文件就必须叫 `v1.1.10.6.md`，少一个点都读不到。

**4. 渠道反了，官网显示正式版**

几乎都是 `versionName` 没写 `-`。`1.3.2+109` 会建成正式版，`1.3.2-0+109` 才是预发布。已经发错渠道：在 GitHub Release 勾 / 取消 Pre-release，再触发一次 `Update Docs Releases JSON`。

**5. Release 上挂着几 KB 的假 APK**

那是选错了包（stub 或未签名碎片）。仓库里的流程已经固化成：显式路径 → 最大候选 → 5 MB 门禁 → `file(1)` 类型检查 → 上传前再验一次体积。**不要在本地用 `find` 猜包路径上传**。已经发了坏包，走第十二节。

**6. `version.properties` 写坏了**

必须 UTF-8 无 BOM；`versionCodeBase` 必须是非负整数。CI 与本地脚本都会拦，报错信息会指出缺哪一行。

**7. CNB 报配额不足**

已知问题，不是代码问题。发布以 GitHub + GitCode 为准，CNB 的红不影响交付。

**8. 手动补 Release**

禁止 `gh release create` 不挂 APK，或挂空文件、占位文件。坏包只能走 Tag recovery。

## 十二、Tag recovery（远端已有坏 release）

破坏性操作，**先报维护者批准**。`git push origin :refs/tags/…` 会同时删 GitHub 与 CNB 的 tag；GitHub 上已建的 Release 会变成 untagged，删之前先决定要不要保留。

```bash
# 1) 在 main 上修好 workflow / 构建问题，门禁跑绿
# 2) 删远端坏 tag（两个远端一起失效）
git push origin :refs/tags/vX.Y.Z
# 3) 在当前 main HEAD 重打同名 tag
git tag -f vX.Y.Z
# 4) 重推
git push origin vX.Y.Z
```

重打前用 `bash tool/release_preflight.sh --retag` 复跑体检；重推后把第八节的五项再验一遍。

如果只想修 GitCode 上那一条，用 `gh workflow run gitcode-backfill.yml -f tag=vX.Y.Z`，不用动 GitHub 的 tag。

## 十三、模板

### 预发布（四位数，如 v2.1.4.1）

```properties
# android/version.properties
versionName=2.1.4.1-0
versionCodeBase=<上一版 +1>
```

```bash
git add android/version.properties docs/releases/v2.1.4.1.md
git commit -m "chore: cut v2.1.4.1 prerelease"
git push origin main          # 等 CI 绿
git tag -a v2.1.4.1 -m "chore: cut v2.1.4.1 prerelease"
git push origin v2.1.4.1
```

### 预发布（三位数，如 v3.0.0）

```properties
versionName=3.0.0-0
versionCodeBase=150
```

tag 推 `v3.0.0`，说明文件 `docs/releases/v3.0.0.md`。CI 会把 `-0` 剥掉再和 tag 比对。

```bash
git add android/version.properties docs/releases/v3.0.0.md
git commit -m "chore: cut v3.0.0 prerelease"
git push origin main
git tag -a v3.0.0 -m "chore: cut v3.0.0 prerelease"
git push origin v3.0.0
```

### 正式基线（如 v1.1.11）

```properties
versionName=1.1.11
versionCodeBase=<上一版 +1>
```

说明文件 `docs/releases/v1.1.11.md` 与 `version.properties` 同笔提交、推 main 等 CI 绿，再打 tag：

```bash
git tag -a v1.1.11 -m "chore: cut v1.1.11 release"
git push origin v1.1.11
```

### 预发布原地转正式

GitHub Release 页面 → 编辑该版本 → 取消 Pre-release → 保存。不换版本号、不重推 tag，GitCode 由 `sync-release-channel-to-gitcode.yml` 自动跟上。
