# `.githooks/` — 提交前门禁

## 怎么启用（每台机器一次）

钩子放在仓库里是**故意**的：这样它能跟着代码走、能被 review、不会在某次
`git clone` 后凭空消失。但 git 默认只看 `.git/hooks/`，所以每台机器要指一次：

```bash
git config core.hooksPath .githooks
```

Windows 上在 Git Bash 里执行同一条命令即可（仓库根目录）。

## 校验装好了

```bash
# 改一个 lib/ 下的文件后正常提交，应当看到「跑架构守卫」那行
git commit -m "..."

# 确认 git 认的是 .githooks 而不是 .git/hooks
git config core.hooksPath
```

## 现在拦什么

只有 `test/architecture/`（实测 21 条 / 5.8 秒，全是扫文件的纯逻辑测试）：
行数棘轮、依赖扇入棘轮、模糊出界、液态玻璃单入口、第三方模糊库补丁的锁定
commit、以及备份规则等新增守卫。

触发条件：暂存区动到 `lib/`、`test/architecture/`、`android/` 或 `pubspec.yaml`。
纯文档/站点提交不付这 6 秒。

## 为什么不跑全量 `flutter test`

要几分钟。门禁一旦慢到让人习惯性敲 `--no-verify`，就等于没装。

## 为什么不把 CJK 硬编码审计也放进来

`tool/audit_cjk_hardcode.py --baseline` 在棘轮发现改善时会**自动改写**
`tool/cjk_hardcode_baseline.txt`。放进钩子会让每次提交都可能把工作区弄脏出一个
未暂存的改动，比它拦住的回归更烦人。它留在 CI 里。

## 逃生舱

```bash
git commit --no-verify
```

误伤时用，但请**立刻**手动补跑：

```bash
flutter test test/architecture/ --timeout 60s
```

## 工具链起不来时会放行

本钩子的定位是「快速本地反馈」，不是第二道 CI。所以 **flutter 自己没跑起来时
它会放行并把报错打出来**，而不是拦住提交——本机 Flutter 一出毛病就锁死所有提交，
而那报错与你的代码无关、也没法就地修，门禁一旦这样就只会被 `--no-verify` 绕过。

已验证会落到这条分支的报错签名（`Error: Unable to...` 一族）：

- `Unable to determine engine version` — 引擎版本戳过期，或 PATH 里的 `git` 有问题
  （Flutter 靠 `git` 算自己的版本号，`git` 被抢占就会报这个）
- `Could not find a command named ...`

守卫**真的**不通过时报的是另一套东西（会带 `架构守卫没过` 与棘轮说明），两者不会混淆。

## 不想用

不设 `core.hooksPath` 就行，没有别的副作用。CI 侧的门禁与本钩子无关，照常生效。
