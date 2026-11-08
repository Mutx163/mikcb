# `.githooks/` — 提交钩子（2026-11-07 去 Flutter 化 P4-C 后）

## 现在还有什么

Dart 层已删除（`lib/`、`test/`、`integration_test/`、`pubspec.yaml`），
原 Flutter 架构守卫（`test/architecture/`）与 `dart analyze` 门禁**整条退役**。

Kotlin/Compose 的验证走：

```bash
pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>"   # L0
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin    # L1
```

这些**不放进 pre-commit**：L0 单次约 20 秒、L1 分钟级，放进来只会让
`--no-verify` 变成习惯。

`pre-commit` 现在只负责在正常提交时写 `pre-commit-ok` 标记；
`post-commit` 靠它区分「正常提交」与「`--no-verify` 跳过」，并自动往
`.agents/no-verify-log.md` 记账。**不要删除 `pre-commit`**，否则每次提交都会被
记成跳过门禁。

## 启用

每台机器一次：

```bash
git config core.hooksPath .githooks
```

确认生效：

```bash
git config core.hooksPath
```

## 历史

Flutter 时代的提交快照守卫、`dart analyze` 门禁、工具链崩溃放行与超时护栏，
见 git 历史（`bab26f1c5`、`4ae35d13e`、`303220db1`）以及
`.agents/notes/implemented/process/2026-11-07-precommit-kotlin-and-flutter-crash.md`。
