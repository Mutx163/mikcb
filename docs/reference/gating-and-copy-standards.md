# 门禁与文案口径（可验证事实清单）

> 本文只记录**能从代码/脚本现场验证的事实**：路径、命令、当前数值、判定位置。
> 不记录流程偏好与团队习惯（那些在 `AGENTS.md`，它不在仓库里）。
> 所有数字与断言均标注实测日期与复核命令；与代码不一致时以代码为准，并回来改本文。
>
> 最近一次全文复核：2026-11-12。

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

`CrossDomainGateGuardTest`（包 `com.mutx163.qingyu.pages.crossguard`，文件 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/crossguard/CrossDomainGateGuardTest.kt`）在一次测试里跑三类判据：

1. 样式：`scripts/compose-style-lint.ps1`，`-Domain all` 必须绿（`:193-199`）；
2. i18n：`scripts/i18n-cjk-baseline.py --check` 必须绿（`:221-224`）；
3. 文案缺口：`scripts/i18n-copy-gap.py --check` 必须绿，含基线路径检查（`:270-275`）；
4. 另有哨兵用例：仓库根与三个入口三份基线必须都在，版本常量被改名/基线缺版本行/两边版本号不一致时必须红（`:127`、`:413-454`）。

**执行入口的事实边界（2026-11-12 实测）**：
- 它随全量单测一起跑（CI 侧见 `.github/workflows/ci.yml:84` 的 `:app:testProdDebugUnitTest`）；
- `scripts/_l0-sweep.sh` 的 `MODS` 清单里**没有** crossguard；全仓 `*.sh/*.ps1/*.yml/*.md` 中**无** `pages/crossguard` 引用（grep 无命中）。也就是说：**L0 模块巡检不覆盖它，只有全量单测覆盖**。

## 3. 文案宽度 11/17：没有自动检查

事实：**仓库里没有任何脚本或测试会校验 11/17 宽度上限**。已核查 `scripts/i18n-copy-gap.py`、`scripts/i18n-cjk-baseline.py` 与 `scripts/typecheck-compose.ps1`：前者只管缺口与 CJK 字面量，后者命中的 `11` / `17` 全是 Maven 依赖版本号（如 `barcode-scanning:17.3.0`），不是宽度判定。

- 口径正文在 `AGENTS.md`「界面文案风格」段（标题 ≤11、说明 ≤17、渲染宽度算法：汉字 1 / 全角标点 1 / 半角 0.55 / 占位符整体 3）。**该文件不在仓库里**（见 §4）。
- Kotlin 侧只有**测试镜像**，不是第二处定义：`CopyWidthMirror`（`android/app/src/test/kotlin/com/mutx163/qingyu/pages/settings/SettingsSpecTestSupport.kt:138`），上限常量 `TITLE_MAX_WIDTH = 11.0` / `SUBTITLE_MAX_WIDTH = 17.0`（同文件 `:152-153`），消费方 `SettingsCopyWidthTest.kt`。

因此改动宽度口径时**没有任何门禁会红**，只能靠人核；这也是本文把这条单列的原因。

## 4. 已删除的 Dart 时代判据

| 路径 | 状态（2026-11-12 实测） |
|---|---|
| `tool/copy_style_rules.dart` | 不存在（`Test-Path` = False）；`tool/` 下已无任何 `.dart` |
| `test/architecture/copy_style_guard_test.dart` | 不存在 |

它们随去 Flutter 化 P4-C 删除。历史上引用过它们的位置已改为指向 `AGENTS.md` 文案段（`SettingsSpecTestSupport.kt`、`SettingsCopyWidthTest.kt`）。

## 5. 相关但不在本文

- 版本号闸与 tag 换算：`docs/RELEASE.md` 第四、六节；脚本 `tool/verify_release_version.sh`、`tool/release_preflight.sh`、`tool/check_release_highlights.py`。
- 样式门禁细则：`docs/reference/compose-page-style-rules.md`。
