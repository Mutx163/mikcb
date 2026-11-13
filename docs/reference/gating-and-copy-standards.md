# 门禁与文案口径（可验证事实清单）

> 本文只记录**能从代码/脚本现场验证的事实**：路径、命令、当前数值、判定位置。
> 不记录流程偏好与团队习惯（那些在 `AGENTS.md`，它不在仓库里）。
> 所有数字与断言均标注实测日期与复核命令；与代码不一致时以代码为准，并回来改本文。
>
> 最近一次全文复核：2026-11-13（白鹭复核后按实测改 4 处：§2 三类判据+哨兵、crossguard 引用面、§3 结论改为「设置族有逐行门禁」、11/17 的排除证据收窄）。

## 1. 现行自动文案门禁：两套棘轮

### 1.1 文案缺口棘轮（未翻译 / 非中文语种混入中文）

| 项 | 值 |
|---|---|
| 脚本 | `scripts/i18n-copy-gap.py` |
| 基线 | `android/app/src/test/kotlin/com/mutx163/qingyu/i18n/copy-gap-baseline.txt` |
| Kotlin 侧 | `android/app/src/test/kotlin/com/mutx163/qingyu/i18n/CopyGapGateTest.kt`（脚本头部自述：判据必须与脚本逐字一致，改一边必须改另一边） |
| 复核命令 | `python scripts/i18n-copy-gap.py`（打印统计）/ `--check`（对基线）/ `--write`（重写基线）/ `--probe`（判据自检） |
| 2026-11-12 实测 | 「共 1219 条缺口」（规则 v1 / 白名单 v1，刻意例外 1 条）；`--check` 通过，基线一致 |

棘轮语义（脚本 `--write` 段自述）：**只降不升** —— 任何新增缺口都会被拒绝写入，一个字节都不动并非零退出。

### 1.2 CJK 字面量棘轮（渲染层中文硬编码）

| 项 | 值 |
|---|---|
| 脚本 | `scripts/i18n-cjk-baseline.py` |
| 基线 | `cjk-literal-baseline.txt`（composeP1 源集）、`cjk-literal-baseline-main.txt`（main 源集），同在 `android/app/src/test/kotlin/com/mutx163/qingyu/i18n/` |
| Kotlin 侧 | `android/app/src/test/kotlin/com/mutx163/qingyu/i18n/CjkLiteralGateTest.kt` |
| 复核命令 | `python scripts/i18n-cjk-baseline.py --check` |
| 2026-11-12 实测 | 「2 个源集 / 中文字面量 1866 条，未发现新增、上调或未下调」，exit 0 |

`@Preview` 豁免口径（脚本 `:69-71` 自述）：`@Preview` 必须出现在**行首（允许前导空白）**才算；KDoc 里的 ` * @Preview`、`// @Preview`、字符串里的 `"@Preview"` 都不算。这比旧守卫的全文 `indexOf` 更窄，是刻意的。

## 2. 两条棘轮接在哪里

`CrossDomainGateGuardTest`（包 `com.mutx163.qingyu.pages.crossguard`，文件 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/crossguard/CrossDomainGateGuardTest.kt`）在一次测试里跑**三类判据 + 一组哨兵**：

1. 样式：`scripts/compose-style-lint.ps1`，`-Domain all` 必须绿（`:193-199`）；
2. i18n：`scripts/i18n-cjk-baseline.py --check` 必须绿（`:221-224`）；
3. 文案缺口：`scripts/i18n-copy-gap.py --check` 必须绿，含基线路径检查（`:270-275`）；
4. 哨兵：仓库根与三个入口三份基线必须都在，版本常量被改名/基线缺版本行/两边版本号不一致时必须红（`:127`、`:413-454`）。

**执行入口的事实边界（2026-11-13 复核）**：
- 设计意图写在该类 KDoc 里：在 `-Module pages/crossguard` 里调用既有入口，让 L0 一条命令同时判样式、i18n 与文案缺口（`:37-38`）；
- **但注册没跟上**：`scripts/_l0-sweep.sh` 的 `MODS` 清单里没有 crossguard，`.github/workflows/*.yml` 与 `scripts/*.sh|*.ps1` 也没有跑它的入口 → **L0 模块巡检不覆盖它，只有全量单测覆盖**（CI 侧 `.github/workflows/ci.yml:84` 的 `:app:testProdDebugUnitTest`）；
- 唯一引用 `pages/crossguard` 的**入口文件**是 `.githooks/pre-commit:77` 与 `.githooks/README.md:24`，但它用 `sed`/`grep` 读 `CanaryFileGuardTest.kt` 里的 `PROBE_WHITELIST` 白名单，**不执行任何 crossguard 测试**。

## 3. 文案宽度 11/17：没有全站级门禁，但设置族有逐行门禁

事实拆成两句，别混：

- **没有全站 / ARB 级宽度门禁**：没有任何脚本按 11/17 扫六语 ARB 全文或 settings 之外的页面；
- **设置族的行控件有逐行门禁**：`android/app/src/test/kotlin/com/mutx163/qingyu/pages/settings/SettingsCopyWidthTest.kt`
  - `:57-66`「所有行标题不超过十一」：`CopyWidthMirror.of(title) > TITLE_MAX_WIDTH` 即红；
  - `:67-78`「所有行说明不超过十七」：同口径看 `subtitle`；
  - `:90-95` 防空转：行控件总数 `count >= 40`，否则「零违规=绿」会骗人；
  - 常量：`TITLE_MAX_WIDTH = 11.0` / `SUBTITLE_MAX_WIDTH = 17.0`（`SettingsSpecTestSupport.kt:152-153`）。
  - 结论：**`pages/settings` 域跑 L0 时，超宽会真的红**。

逐字核对过的排除项：`scripts/typecheck-compose.ps1:245-248` 里的 `17` 全是 Maven 版本号（写法是 `v = "17.3.0"` / `v = "17.0.0"`，不是宽度）；**`11` 在该脚本里没有找到，无法核实**。

- 口径正文在 `AGENTS.md`「界面文案风格」段（标题 ≤11、说明 ≤17、渲染宽度算法：汉字 1 / 全角标点 1 / 半角 0.55 / 占位符整体 3）。**该文件不在仓库里**（见 §4）。
- Kotlin 侧 `CopyWidthMirror`（`SettingsSpecTestSupport.kt:138`）是**测试镜像**，不是第二处定义。

## 4. 已删除的 Dart 时代判据

| 路径 | 状态（2026-11-12 实测） |
|---|---|
| `tool/copy_style_rules.dart` | 不存在（`Test-Path` = False）；`tool/` 下已无任何 `.dart` |
| `test/architecture/copy_style_guard_test.dart` | 不存在 |

它们随去 Flutter 化 P4-C 删除。历史上引用过它们的位置已改为指向 `AGENTS.md` 文案段（`SettingsSpecTestSupport.kt`、`SettingsCopyWidthTest.kt`）。

## 5. 发版工具链（可验证事实，2026-11-13 实读/实跑）

**版本源**：`android/version.properties`（`versionName` / `versionCodeBase`）。2026-11-13 实读值：`versionName=3.0.0-0`、`versionCodeBase=150`。`android/app/build.gradle` 读它（`:15-19`），`versionCode = appVersionCodeBase + 100000`（`:69`）、`versionName` 可被 `OVERRIDE_VERSION_NAME` 覆盖（`:38`、`:70`）。

**三条发版前命令**（均在仓库根执行，均为本机实跑过的命令形态）：

```bash
bash tool/verify_release_version.sh prerelease   # 正式版用 release
bash tool/release_preflight.sh                   # 要 0 FAIL；WARN 逐条看
python tool/check_release_highlights.py          # Windows 用 python；python3 是商店空壳
```

**tag 换算**唯一实现位置 `.github/workflows/android-build.yml:85` 的 `sed -E 's/-0$//; s/-([0-9]+)$/.\1/'`；`tool/check_release_highlights.py:36-47` 与 `tool/release_preflight.sh` 有同口径副本，边界不完全一致（py 对 `-beta` 这类非数字后缀会拼成 `vA.B.C.beta`）。

**notes 镜像**：`docs/releases/v*.md` 改动必须同笔同步 `android/app/src/main/assets/docs/releases/`（逐字节），由 `FlutterAssetsDecouplingGuardTest` 守；三份 `3.0.0-1-*` 内部文档故意不进镜像。

**判据与流程正文**在 `docs/RELEASE.md`（第四节版本与 tag 规则、第六节前置检查、第七节步骤、第八节 post-tag 验证、第十二节 Tag recovery）。

**未核实**：`gh` 系命令（`gh run list/watch`、`gh release view`）本机无凭据，未实跑；平台侧同步行为只读代码未对远端核实。

## 6. 技能参考文档的位置（注意：不入库）

`mikcb-release` 技能的参考文档在 `.agents/skills/mikcb-release/`，且 **`.agents/` 被 `.gitignore` 忽略**（见 §4 的同类问题）：新克隆拿不到它们。

因此**以仓库内文档为准**：本文 + `docs/RELEASE.md`。技能文档只是本机助手，口径与本文冲突时以本文与代码为准，并回来改本文。

## 7. 其他相关

- 样式门禁细则：`docs/reference/compose-page-style-rules.md`。
