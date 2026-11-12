# `.githooks/` — 提交钩子（2026-11-12 起：提交期零拦截已补上）

Kotlin/Compose 的编译与单测**不进提交钩子**：

```bash
pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>"   # L0，约 20 秒
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin    # L1，分钟级
```

放进来只会让人养成 `--no-verify` 的习惯——那样的门禁等于没有。

## `pre-commit` 现在跑什么（目标 2–5 秒）

| # | 检查 | 什么时候触发 | 耗时（实测） |
|---|---|---|---|
| 1 | **探针 / canary 文件**：`android/app/src` 下文件名命中 `(?i)canary\|probe` 且不在白名单 ⇒ 拒 | 仅当暂存里有这类文件名 | <0.2s |
| 2 | **ARB 可解析 + ArbCatalog 同步**：改动的 `i18n/*.arb` 必须能 JSON 解析；碰了 ARB / `ArbCatalog.kt` 跑 `tool/gen_compose_arb_catalog.py --check` | 仅当暂存里有 `*.arb` 或 `ArbCatalog.kt` | ~0.1–0.3s |
| 3 | **发布说明镜像**：`docs/releases/*.md` ↔ `android/app/src/main/assets/docs/releases/*.md` 同名**逐字节相同**（`v*` 版本说明缺镜像也算错） | 仅当暂存里有 releases 目录的 `.md` | <0.2s |
| 4 | **棘轮只降不升**：`i18n-cjk-baseline.py --check`（碰 `.kt`）、`i18n-copy-gap.py --check`（碰 `.arb`） | 按暂存文件类型短路 | ~1.0s / ~0.1s |

**严格路径限定**：每一步都只看 `git diff --cached --name-only --diff-filter=ACMR` 命中的文件，
不扫全仓。只改普通文档（如 `README.md`、`docs/PRODUCT.md`）时**一条检查都不跑**，秒过。

探针判据与 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/crossguard/CanaryFileGuardTest.kt`
同一套，**白名单直接从那份测试里读**，不维护第二份清单。

## 启用（opt-in，每台机器一次）

钩子**不会自动生效**，也不会被谁替你开：

```bash
git config core.hooksPath .githooks    # 启用
git config core.hooksPath             # 确认（输出 .githooks 即生效）
git config --unset core.hooksPath      # 关闭
```

`.githooks/` 本身在版本控制里（`git ls-tree HEAD .githooks` 可查），所以 clone 下来就有文件，
只差上面那条配置。CI 不受影响：CI 用 `git commit` 之外的路径，不依赖钩子。

## 逃生口：`--no-verify`

用 git 原生的：

```bash
git commit --no-verify
```

**不要再造一个更隐蔽的绕过开关**（环境变量、配置项、`SKIP_*` 之类）——那种开关的最后归宿
是没人记得它存在。`post-commit` 会把这次跳过写进 `.agents/no-verify-log.md`（时间 / 提交号 /
标题 / 改动量），跳过率因此看得见。

跳过后**手动补跑**被跳过的东西（按你改了哪类文件挑）：

```bash
python tool/gen_compose_arb_catalog.py --check        # 改了 ARB / ArbCatalog
python scripts/i18n-cjk-baseline.py --check           # 改了大量中文硬编码
python scripts/i18n-copy-gap.py --check               # 改了 ARB 键
# 发布说明镜像：目视或自己 cmp 一遍 docs/releases 与 assets/docs/releases
```

## 工具链缺失时

与 `pre-push` 同一口径：**python 起不来就放行并提醒**，不拦提交。门禁因环境问题锁死所有提交，
最后只会被绕过，比不做更糟。纯 shell 能做的检查（探针文件名）不受影响。

## 不要删 `pre-commit`

`post-commit` 靠它写的 `pre-commit-ok` 标记区分「正常提交」与「`--no-verify` 跳过」，
删了会把每次提交都记成跳过门禁。

## 历史

- Flutter 时代的提交快照守卫、`dart analyze` 门禁、工具链崩溃放行与超时护栏：
  `bab26f1c5`、`4ae35d13e`、`303220db1`，以及
  `.agents/notes/implemented/process/2026-11-07-precommit-kotlin-and-flutter-crash.md`。
- 2026-11-07 去 Flutter 化后钩子只剩记账标记；2026-11-12 补回「红得快、修得便宜」的四项检查
  （见上表），并保持 opt-in。
