# 发行教程

这份文档只写当前仓库实际在用的发布方法。

先记住 9 句话：

- `push` / `pull_request` 会触发 CI 质量门禁。
- 只有推送 `v*` tag 才会自动构建正式 APK 并创建 / 更新 GitHub Release，并同步 GitCode 镜像（需一次性配置，见第一节）。
- **GitHub 预发布 / 正式，唯一由 pubspec 的 `version:` 是否含 `-` 决定；commit message 里的 `prerelease` 无效。**
- 三位数版本和四位数版本都可以是正式版，也都可以是预发布版；关键看 pubspec 有没有 `-`。
- 四位数版本可以先作为预发布发出，后面再原地转成正式版。
- **默认只升第 4 位（如 `2.0.4` → `2.0.4.1`）；不要因本地草稿就默认升第 3 位到 `2.0.5`…`2.0.9`。**
- 应用里比较版本时，`1.1.10-6+36` 会按 `1.1.10.6` 去比较。
- **推送 tag 后必须完成第六节 Post-tag 验证（CI 绿勾 + APK > 5 MB + Release 渠道状态正确）才能宣告发布完成。**
- **已打 tag / 已出现在 `docs/releases/latest.json` 的 `docs/releases/v*.md` 视为只读历史：禁止再追加功能条目；新内容写下一版文件（默认第四位 +1）。**

## 写更新日志前：已发版判定（强制）

以下规则在**任何场景**都适用：正式 cut、本地提交、用户只说「写好更新日志」。  
**不**改变日常代码提交习惯：未要求写更新日志时，不必创建/修改 `docs/releases/`。

### 1. 先判定「最后已发布」

在编辑任何 `docs/releases/v*.md` 之前，至少做一项：

| 来源 | 怎么看 |
|------|--------|
| Git tag | `git tag -l 'v*' --sort=-v:refname`（并对照远程是否已 push） |
| 应用更新源 | `docs/releases/latest.json` 的 `stable.version` / `prerelease.version` |

**最后已发布** = 已存在对应 `v*` tag，和/或已写入 `latest.json` 的版本号（预发布也算已发布）。

### 2. 文件能不能改

| 情况 | 允许的操作 |
|------|------------|
| `docs/releases/vX.md` 对应版本 **已发布** | **禁止**追加「新增 / 优化 / 移除」功能条目。仅允许笔误、错别字、断行等不改变产品含义的修正（且应极少用）。 |
| 对应版本 **从未 tag、从未上架** | 可编辑；若多份未发草稿，合并进**即将 cut 的下一版**文件（见第三节「多版本连在一起」）。 |
| 用户只说「写更新日志 / 提交并写 changelog」 | 写入 **下一未发布版本** 文件，默认第四位：已发 `v2.0.5` → 写 `docs/releases/v2.0.5.1.md`；**不要**改 `v2.0.5.md`。 |
| 用户只说「本地提交 / 提交代码」且未提更新日志 | **不要**主动改 `docs/releases/`，正常 `git commit` 即可。 |

### 3. 「合并草稿」≠「改已发版」

- **正确**：多份**未 tag** 的 notes → 合并进**下一次要 cut** 的那一个 `v{next}.md`。
- **错误**：把未推送代码的新能力写回**已经发过**的 `v2.0.5.md`（即使 pubspec 仍停在 `2.0.5-0`）。

`pubspec.yaml` 的 `version:` **不能**单独当作「这一版还没发」：发版后 pubspec 可能暂时仍停在旧号；以 **tag / latest.json** 为准。

### 4. 与正常发版的关系

- **正常 cut**：仍按第三节升第四位、写 `v{ship}.md`、改 pubspec、打 tag；本规则只禁止动**已经发过的** notes 文件。
- **预发布转正式**：仍可只改 GitHub Release 渠道，不必改写已发 notes 正文。
- **可选习惯**（非强制）：tag 成功后把 pubspec 抬到下一预发布号（如 `2.0.5.1-0+…`），减少「代码已前进、版本号还像停在已发号」的误导；不抬号也不构成可以改已发 notes 的理由。

## 更新日志写法规则（强制）

以后写 `docs/releases/v*.md` 时，必须按**用户视角**写，只写这三类：

1. **新增**
   - 新功能
   - 新入口
   - 新页面
   - 新能力

2. **优化**
   - 体验优化
   - 设计优化
   - 性能优化
   - 稳定性优化
   - 现有功能体验变好

3. **移除**
   - 删除功能
   - 下线入口
   - 去掉旧逻辑

### 严禁这样写

- 不要写“修复英语”
- 不要写“修复国际化”
- 不要写“修复某个新功能的小 bug”
- 不要写实现层、技术层、开发者视角描述

### 正确写法原则

如果这次版本的核心是**新增一个功能**，后面哪怕你修的是这个新功能里的 bug，更新日志里也优先写成：

- **新增：xxx 功能**
- **优化：xxx 功能体验**

而不是写成：

- **修复：xxx 功能 bug**

也就是说：

- 面向用户看起来是“第一次拥有这个能力” → 写 **新增**
- 面向用户看起来是“这个能力更顺、更稳、更好用” → 写 **优化**
- 面向用户看起来是“这个能力没了” → 写 **移除**

### 一个典型例子

如果这次主要工作是把国际化语言功能做出来，但过程中修了很多英文显示问题，最终更新日志应该写：

- 新增：英语与繁体中文等多语言界面支持
- 优化：多语言界面的文案与排版一致性

不要写：

- 修复：英语显示问题

### 总结

更新日志不是给开发者看的提交记录，而是给用户看的版本摘要。

默认优先级：

`新增 > 优化 > 移除 > 修复细节`

如果一个版本既有“新增功能”又有“为这个新功能补 bug”，更新日志默认归类到**新增 / 优化**，不要把重点写成“修复 bug”。

## 一、当前发布机制

当前仓库有四条 GitHub Actions 线：

- [.github/workflows/ci.yml](../.github/workflows/ci.yml)：`push` / `pull_request` 时执行依赖安装、静态分析和测试。
- [.github/workflows/android-build.yml](../.github/workflows/android-build.yml)：推送 `v*` tag 时先执行检查，再签名构建 `arm64-v8a` APK 并创建 / 更新 GitHub Release，最后同步源码 / tag / APK 到 GitCode 镜像。
- [.github/workflows/update-docs-releases.yml](../.github/workflows/update-docs-releases.yml)：GitHub Release 发布、编辑、撤销等事件后自动更新 `docs/releases/latest.json`，供应用内更新检查读取。
- [.github/workflows/update-docs-schools.yml](../.github/workflows/update-docs-schools.yml)：每天定时（及手动）从 `qingyu_warehouse` 拉取 `root_index.yaml`，生成 `docs/schools.json`，供官网已适配学校列表读取。

上游教务适配的自动同步在 [`qingyu_warehouse` 仓库](https://github.com/Mutx163/qingyu_warehouse) 的 `.github/workflows/sync-upstream.yml` 中执行（每天 09:00 北京时间）；mikcb 侧仅通过上述 schools JSON 任务跟进索引变化。

也就是说：

1. 平时 `git push origin main` 或提交 PR，会自动跑 CI 质量门禁。
2. 发布前先本地提交并推送 `main`。
3. 再推送一个 `v*` tag。
4. tag workflow 会先跑 `flutter analyze` 和 `flutter test`，通过后才继续构建 APK、上传蒲公英并创建 / 更新 GitHub Release。

release workflow 还会做这些事：

- 读取 [pubspec.yaml](../pubspec.yaml) 的 `version:`
- 读取 `docs/releases/v版本号.md`
- 用 tag 名覆盖 Android 最终产物的 `versionName`
- 使用 `flutter build apk --release --flavor prod --target-platform android-arm64` 构建正式包
- 创建或更新 GitHub Release
- 同步源码、tag 与 APK 到 GitCode 镜像仓库（国内下载加速，需一次性配置，见下）

### GitCode 镜像同步（国内下载加速）

发版时 android-build.yml 会调用 [nvdacn/sync_to_gitcode](https://github.com/nvdacn/sync_to_gitcode) 的两个可复用工作流（已按 master HEAD `18b70112` SHA pin）：

- `gitcode-push`：把 `main` 分支与全部 tag 同步到 GitCode 仓库；
- `gitcode-release`：把本次构建产物 `mikcb-*.apk` 上传为 GitCode Release 附件，正文使用 `docs/releases/v版本号.md` 全文，预发布 / 正式状态沿用 pubspec `-` 判定（`pre` / `latest`）。

触发条件与发版一致：仅当推送 `v*` tag 且构建发布（publish job）成功后执行；两个 Job 都带 `vars.GITCODE_USERNAME` 存在性门禁，变量不存在时自动跳过，Fork 仓库不会因此失败。

启用前需要一次性配置（任一项缺失时同步静默跳过，不影响 GitHub 发版）：

| 平台 | 配置 | 说明 |
|------|------|------|
| GitCode | 创建仓库 | 路径默认需与 GitHub 相同（`Mutx163/mikcb`）；不同则设 GitHub Variable `GITCODE_REPOSITORY` |
| GitCode | [个人访问令牌](https://gitcode.com/setting/token-classic) | 需具备仓库写权限（推代码 + 创建/编辑 Release） |
| GitHub | Secret `GITCODE_TOKEN` | 存 GitCode 令牌 |
| GitHub | Variable `GITCODE_USERNAME` | GitCode 用户名；同时充当同步开关 |
| GitHub | Variable `GITCODE_REPOSITORY`（可选） | 仅当 GitCode 仓库路径与 GitHub 不同时需要 |

注意：

- GitCode 仓库不会在 push 时自动创建，必须先在 GitCode 网页端建好空仓库。
- 同步从配置后的第一个新 tag 开始；历史 Release 不会自动回填（重推旧 tag 会重跑完整发版流程，一般不建议）。
- 首次同步会把 main 的全部历史与所有历史 tag 一起推到 GitCode。

## 二、先分清两套版本

### 1. 包内版本

写在 [pubspec.yaml](../pubspec.yaml) 里。

例如：

```yaml
version: 1.1.10-6+36
```

含义：

- `1.1.10` 是基线版本
- `-6` 对应第四段版本号
- `+36` 是 build number / versionCode，必须递增

### 2. 对外版本

体现在 Git tag 和 GitHub Release 上。

例如：

- tag：`v1.1.10.6`
- release notes：`docs/releases/v1.1.10.6.md`

### 3. 这两者的关系

当前代码里，版本比较会把：

- `1.1.10-6+36`
- `1.1.10.6`

当成同一个数值版本。

这点在 [lib/services/app_update_service.dart](../lib/services/app_update_service.dart) 和 [test/services/app_update_service_test.dart](../test/services/app_update_service_test.dart) 里已经覆盖到了。

## 三、三位数和四位数的真实规则

### 1. 三位数版本

例子：

- `1.1.11`

这种通常用来表示一个新的正式基线版本。

### 2. 四位数版本

例子：

- `1.1.10.6`

这种通常表示某个基线版本下面的编号版本。

但要注意：

- 四位数版本不等于“只能预发布”
- 四位数版本也可以是正式版

### 3. 当前实际发行习惯

现在这套习惯更准确的说法是：

- 新的测试包，通常继续递增第四段，例如 `11105 -> 11106`
- 如果某个四位数测试版验证通过，可以直接把这个同版本号原地转成正式版
- 不需要再单独发一个三位数版本来“接管”它

也就是说：

- `11106` 可以先是预发布
- 后面也可以还是 `11106`，只是从预发布改成正式

### 4. AI / 自动化默认怎么升版本（必守）

**默认只动第 4 位，不要默认动第 3 位。**

| 段位 | 例子 | 默认 |
|------|------|------|
| 第 1/2 位 | `2.0` | 禁止自作主张 |
| 第 3 位 | `2.0.x` | **禁止默认 +1**；仅当人工明确点名新三位数基线 |
| 第 4 位 | `2.0.4.n` | **默认 +1**（预发布与正式都优先四段） |

未指定精确版本号时：

1. 以 **最后一个已打 tag 并发布** 的版本为准（不是 `docs/releases/*.md` 草稿文件名）。
2. 已发 `v2.0.4` → 下一发 **`v2.0.4.1`**，不是 `v2.0.5`。
3. 已发 `v2.0.4.1` → 下一发 **`v2.0.4.2`**。

### 5. 多个未发布版本连在一起时

若本地写了很多 `docs/releases/v2.0.5.md`…`v2.0.9.md` 之类草稿，但 **从未打 tag / 从未上架**：

1. **不要**按草稿最大号去 cut（禁止因为写了 `v2.0.9.md` 就发 `v2.0.9`）。
2. 默认 cut 到「最后已发布基线下的下一个第四位」（如已发 `v2.0.4` → `v2.0.4.1`）；仅当人工明确点名三位数时才用三位数。
3. 把所有**未发布**草稿内容 **合并进这一次** 即将 cut 的 `docs/releases/v{ship}.md`，打 **一个** tag。  
   **若其中某文件版本其实已有 tag（例如已发 `v2.0.5`）→ 该文件不要合并、不要追加；只把其后的未发改动写进 `v2.0.5.1` 等下一版。**
4. 中间空号笔记改写成四段归档或删除，不要当成已发布历史。
5. 用户向更新日志不要写「相对完整累计 / 中间迭代未单独发」类说明。

（Agent 流程细节见用户机 `mikcb-release` / `mikcb-ship-local` skill。）

## 四、什么时候算预发布，什么时候算正式

这里不要混淆“版本号形态”“commit 文案”和“GitHub 渠道状态”这三个概念。

### 1. 唯一判定源：pubspec + CI

[android-build.yml](../.github/workflows/android-build.yml) 在创建 GitHub Release 前读取 `pubspec.yaml` 的 `version:`：

```bash
if [[ "${APP_VERSION}" == *-* ]]; then
  IS_PRERELEASE=true    # gh release … --prerelease
else
  IS_PRERELEASE=false   # 正式 Release
fi
```

因此：

| 用户意图 | pubspec 必须写成 | GitHub Release | 官网 `latest.json` |
|----------|------------------|----------------|---------------------|
| **预发布** | 含 `-` 段，如 `1.3.2-0+109` 或 `1.1.10-7+37` | `prerelease: true` | 进 `prerelease` 栏 |
| **正式版** | 不含 `-`，如 `1.3.2+109` 或 `1.1.11+37` | `prerelease: false` | 进 `stable` 栏 |

**以下全部不能决定渠道：**

- commit message 是否写了 `prerelease`
- tag 是三位数还是四位数
- release notes 文件名
- tag 名里有没有 `beta`

切版本前运行（把第二参数换成本次模式）：

```bash
bash tool/verify_release_pubspec.sh pubspec.yaml prerelease
# 或
bash tool/verify_release_pubspec.sh pubspec.yaml release
```

### 2. GitHub / 官网 / 应用各自看什么

- **GitHub Release 是不是预发布**：看 `prerelease` 字段（由上一节 CI 写入）。
- **官网下载区显示正式还是预发布**：读 `docs/releases/latest.json`，同样看 Release 的 `prerelease`。
- **应用里版本高低怎么比**：看版本号数值，与渠道无关。

例如当前代码会把：

- `1.1.10-6+36`
- `1.1.10.6`

视为同版本。

所以：

- 如果你已经安装了 `11106` 预发布
- 后面只是把 GitHub 上同一个 `11106` Release 原地转正式

应用不应该再把它判定成“更高的新版本”，因为版本号没变。

### 3. 三位数 vs 四位数（形态 ≠ 渠道）

- **四位数对外版本**（如 `v1.1.10.7`）：pubspec 写 `1.1.10-7+build`；`-7` 同时表示第四段编号，且触发预发布。
- **三位数对外版本**（如 `v1.3.2`）：若要做**预发布**，pubspec 仍必须含 `-`，通常写 `1.3.2-0+build`（`-0` 仅用于触发 CI 预发布，对外 versionName 仍来自 tag `1.3.2`）。
- **三位数正式基线**（如 `v1.1.11`）：pubspec 写 `1.1.11+build`，**不要**写 `-0`。

> **反面教材（v1.3.1 / v1.3.2 事故）**：commit 写了 `chore: cut v1.3.2 prerelease`，但 pubspec 是 `1.3.2+109`（无 `-`），CI 必然建成正式版，官网也会显示正式版。

## 五、最短发布流程

### 1. 发布一个新的预发布测试版

假设目标是发布 `11107`：

1. 修改 [pubspec.yaml](../pubspec.yaml)

```yaml
version: 1.1.10-7+37
```

2. 新建 release notes 文件：

```text
docs/releases/v1.1.10.7.md
```

3. 提交：

```bash
git add pubspec.yaml docs/releases/v1.1.10.7.md
git commit -m "chore: cut v1.1.10.7 prerelease"
```

4. 打 tag：

```bash
git tag v1.1.10.7
```

5. 推送：

```bash
git push origin main
git push origin v1.1.10.7
```

6. 去 GitHub Actions 看 `Android Build` 是否启动。

7. 完成 [Post-tag 验证](#六post-tag-验证必做)，确认 GitHub Release 的 **Pre-release** 勾选状态与预期一致。

### 1b. 发布一个新的三位数预发布（如 v1.3.2）

与四位数预发布**渠道规则相同**：pubspec 必须含 `-`。

假设目标是预发布 `v1.3.2`：

1. 修改 [pubspec.yaml](../pubspec.yaml)

```yaml
version: 1.3.2-0+109
```

2. 新建 release notes 文件：

```text
docs/releases/v1.3.2.md
```

3. 本地校验：

```bash
bash tool/verify_release_pubspec.sh pubspec.yaml prerelease
```

4. 提交、打 tag、推送：

```bash
git add pubspec.yaml docs/releases/v1.3.2.md
git commit -m "chore: cut v1.3.2 prerelease"
git tag v1.3.2
git push origin main
git push origin v1.3.2
```

> 常见错误：写成 `version: 1.3.2+109` 会落成**正式版**，与 commit message 无关。

### 2. 把已有四位数预发布原地转正式

假设 `v1.1.10.6` 已经发成预发布，现在你决定它直接转正式：

1. 不新增 `v1.1.10`
2. 不改成别的版本号
3. 直接保留 `v1.1.10.6`
4. 去 GitHub Release 页面编辑这个已有 Release
5. 把它从 `prerelease` 改成正式发布

这一步的关键是：

- 改的是 Release 状态
- 不是重新发一个三位数版本

### 3. 发布一个新的正式基线

假设目标是发布 `1.1.11`：

1. 修改 [pubspec.yaml](../pubspec.yaml)

```yaml
version: 1.1.11+37
```

2. 新建 release notes 文件：

```text
docs/releases/v1.1.11.md
```

3. 提交：

```bash
git add pubspec.yaml docs/releases/v1.1.11.md
git commit -m "chore: cut v1.1.11 release"
```

4. 打 tag：

```bash
git tag v1.1.11
```

5. 推送：

```bash
git push origin main
git push origin v1.1.11
```

## 六、Post-tag 验证（必做）

推送 `v*` tag **不等于**发布完成。必须等 CI 产出有效 APK 后才能对用户或渠道宣告 release 就绪。

### 检查清单

| 步骤 | 检查项 | 通过标准 |
|------|--------|----------|
| 1 | GitHub Actions **Android Build**（对应 tag） | **Analyze and Test** 与 **Build and Publish Android APK** 均为 green |
| 2 | Workflow 产物 **`android-release-apk`** | 体积 **> 5 MB**（CI 在 Prepare artifact 与上传 Release 前各校验一次） |
| 3 | GitHub Release 页面同名 tag | 附件 APK **> 5 MB**；约 12 KB / ≤1 MB 视为失败产物 |
| 4 | **Release 渠道状态** | 若本次为预发布 cut，Release 必须显示 **Pre-release**；若为正式 cut，必须**未**勾选 Pre-release |
| 5 | 禁止手工绕过 | 不得 `gh release create` 不带 APK，或上传占位/空资产 |

### 发布前本地脚本（推荐）

切版本提交前运行（与 CI 编码门禁一致；**第二参数必传**）：

```bash
# 预发布 cut
bash tool/verify_release_pubspec.sh pubspec.yaml prerelease

# 正式 cut
bash tool/verify_release_pubspec.sh pubspec.yaml release
```

### 不要用脆弱的 APK 选择方式

- **禁止**在本地或临时脚本里用 `find` / 通配符“猜”哪个 `.apk` 是正式包并当作 release 依据。
- 仓库已在 [.github/workflows/android-build.yml](../.github/workflows/android-build.yml) 固化：显式路径 → 最大 eligible 回退 → **5 MB** 体积门禁 → `file(1)` 归档类型检查 → 上传 Release 前再次校验体积。
- 应用内 `latest.json` 更新（[update-docs-releases.yml](../.github/workflows/update-docs-releases.yml)）也会跳过 **< 5 MB** 的 APK 资产。

### Tag 恢复（远端已有坏 release）

若某次 tag 指向了错误构建（例如 Release 上只有 ~12 KB stub APK）：

1. 在 `main` 上合并修复（workflow / 构建问题），确保本地 `flutter analyze` / `flutter test` 通过。
2. 删除远端坏 tag：`git push origin :refs/tags/vX.Y.Z.W`
3. 在**当前** `main` HEAD 重新打同名 tag：`git tag -f vX.Y.Z.W`
4. 再次推送 tag：`git push origin vX.Y.Z.W`
5. 重新执行本节 Post-tag 验证清单，确认 Release APK **> 5 MB** 后再宣告完成。

## 七、推荐发布前检查

发布前本地至少跑这组命令，和 CI / release workflow 保持一致：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --flavor prod --target-platform android-arm64
```

同时检查这几项：

1. `bash tool/verify_release_pubspec.sh pubspec.yaml prerelease` 或 `… release`（与本次 cut 模式一致）
2. `pubspec.yaml` 版本号是否改对（预发布必须含 `-`）
3. `docs/releases/` 文件名是否和 tag 完全一致
4. `build number` 是否比上一个版本大
5. 工作区是否干净：`git status`
6. 如果要验证预发布检测，新的测试包版本号必须严格高于当前已安装版本

推送 `v*` tag 后，release workflow 也会强制执行 `flutter analyze` 和 `flutter test`；只有检查通过才会进入签名构建和发布步骤。

## 八、常见坑

### 1. 为什么发布 workflow 没跑

CI 会在 `push` / `pull_request` 时运行；正式 APK 发布 workflow 只有推送 `v*` tag 才会运行。发布没跑通常只有这几种原因：

- 只推了 `main`，没推 tag
- tag 不是 `v*`
- tag 还在本地，没 `git push origin vX.Y.Z`

### 2. 为什么 Release 说明没生效

workflow 读的是：

```text
docs/releases/v${VERSION_NAME}.md
```

所以：

- tag 是 `v1.1.10.6`
- 文件就必须叫 `docs/releases/v1.1.10.6.md`

少一个点、少一个数字、写成别的名字，都不会自动读取到。

### 3. 为什么预发布检测不到新版本

先检查这几件事：

1. 当前安装包版本是否真的低于新的测试版本
2. 应用内是否打开了“检测预发布版本”
3. 远端对应 Release 是否仍然是 `prerelease`

如果你只是把同一个 `11106` 从预发布改成正式：

- 这是渠道状态变化
- 不是版本号升级

所以应用不应该把它提示成“比当前更高的新版本”。

### 4. 为什么本地 commit 了还是没反应

因为本地 commit 不会触发 GitHub Actions。

一定要：

```bash
git push origin main
git push origin v你的版本号
```

### 5. 为什么 GitHub Release 上是几 KB 的假 APK

根因通常是 CI 用松散规则选错了 `.apk`（例如 stub 或未签名碎片），而不是真正的 `app-prod-release.apk`。

**不要**在本地用 `find` 猜路径上传。**必须**依赖仓库 workflow 内的显式路径、5 MB 门禁与 Post-tag 验证（见第六节）。若已发布坏资产，按第六节 Tag 恢复流程处理。

### 6. pubspec.yaml 出现乱码或 description 异常

写入 `pubspec.yaml` 时必须 **UTF-8 无 BOM**。带 BOM 会导致 `description` 等字段乱码；CI 与 `tool/verify_release_pubspec.sh` 会在 PR 与发布前拦截。

### 7. 为什么 commit 写了 prerelease，官网却是正式版

根因几乎总是 **pubspec 没写 `-` 段**。

- `version: 1.3.2+109` → CI 建**正式** Release → 官网 `latest.json` 的 `stable` 指向它
- `version: 1.3.2-0+109` → CI 建**预发布** Release → 官网 `latest.json` 的 `prerelease` 指向它

修复已发布的错误渠道：在 GitHub Releases 编辑对应版本勾选/取消 Pre-release，然后触发 `Update Docs Releases JSON` workflow。下次 cut 务必先跑 `verify_release_pubspec.sh … prerelease`。

## 九、最常用模板

### 新预发布模板（四位数，如 v1.1.10.7）

```bash
git add pubspec.yaml docs/releases/v1.1.10.X.md
git commit -m "chore: cut v1.1.10.X prerelease"
git tag v1.1.10.X
git push origin main
git push origin v1.1.10.X
```

`pubspec.yaml`：

```yaml
version: 1.1.10-X+递增编号
```

切前校验：`bash tool/verify_release_pubspec.sh pubspec.yaml prerelease`

### 新预发布模板（三位数，如 v1.3.2）

```bash
git add pubspec.yaml docs/releases/v1.3.2.md
git commit -m "chore: cut v1.3.2 prerelease"
git tag v1.3.2
git push origin main
git push origin v1.3.2
```

`pubspec.yaml`：

```yaml
version: 1.3.2-0+递增编号
```

切前校验：`bash tool/verify_release_pubspec.sh pubspec.yaml prerelease`

> `-0` 仅用于满足 CI 预发布判定；Android `versionName` 仍来自 tag `v1.3.2`。

### 四位数预发布转正式模板

```text
GitHub Releases 页面
找到 v1.1.10.X
编辑 Release
取消 prerelease
保存
```

### 新正式基线模板

```bash
git add pubspec.yaml docs/releases/v1.1.11.md
git commit -m "chore: cut v1.1.11 release"
git tag v1.1.11
git push origin main
git push origin v1.1.11
```

`pubspec.yaml`：

```yaml
version: 1.1.11+递增编号
```

切前校验：`bash tool/verify_release_pubspec.sh pubspec.yaml release`
