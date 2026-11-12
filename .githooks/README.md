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

## 历史：旧钩子为什么是空的（以及这次为什么敢放回来）

**旧钩子不是忘了写门禁，是刻意清空的。** 2026-11-07 去 Flutter 化（`8518c5b89`）时，
Flutter 时代的架构守卫与 `dart analyze` 整条退役，文件里写明了决定：

> Kotlin/Compose 的验证走 L0（约 20 秒）与 L1（分钟级），**不放进提交钩子**：
> 放进来只会让 `--no-verify` 变成习惯。

这个判断是对的：门禁成本高于人们对「提交」这件事的耐心时，结果不是「大家都跑」，
而是「大家都加 `--no-verify`」——门禁还在，但没人真跑。所以那一版钩子只写
`pre-commit-ok` 记账标记。

**2026-11-12（`73af0f09c`）不是「补上没人想到的门禁」，而是「把预算降到 1 秒级，
让当年被否掉的那条路重新可行」。** 这次放进来的四项全是秒级检查：

| 场景 | 实测 |
|---|---|
| 无暂存 | ~0.3s |
| 只改普通文档 | ~0.6s |
| 探针文件名 / 镜像比对 / ARB 解析 | 0.7–0.8s |
| 碰 `.kt`（含 CJK 棘轮 ~1s） | 2.0–2.5s |

**两种解法，别混为一谈：**

- **取消门禁**（旧做法）：承认「没人会跑」，于是不跑——代价是这类错误只能靠 CI / 评审兜；
- **降低门禁成本**（这次做法）：把单次成本压到 1 秒级、只查「红得快、修得便宜」的那几项，
  让「每次提交都跑」重新变回理性选择。

遇到一个「没人跑的门禁」，先算它的**单次成本**，再决定是取消还是降价；
不要默认「加进去大家就会跑」，也不要默认「前人删掉就是偷懒」。

## 历史

- Flutter 时代的提交快照守卫、`dart analyze` 门禁、工具链崩溃放行与超时护栏：
  `bab26f1c5`、`4ae35d13e`、`303220db1`，以及
  `.agents/notes/implemented/process/2026-11-07-precommit-kotlin-and-flutter-crash.md`。
- 2026-11-07 去 Flutter 化后钩子**刻意**只剩记账标记（理由见上一节）；
  2026-11-12 `73af0f09c` 把成本降到秒级，补回四项检查并保持 opt-in。

