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

1. `test/architecture/`（实测 21 条 / 5.8 秒，全是扫文件的纯逻辑测试）：
   行数棘轮、依赖扇入棘轮、模糊出界、液态玻璃单入口、第三方模糊库补丁的锁定
   commit、以及备份规则等新增守卫。
2. **analyze 门禁**（2026-10-11 新增）：暂存的 `.dart` 文件逐个过
   `dart analyze --fatal-infos`（info 级也算失败，与 CI 同一口径）。首跑约 20 秒、
   之后快；只分析暂存的文件，不碰其他 Agent 正在改的半成品。起因是 10-08 两个
   测试提交带进两条 info 级 lint，本地没人跑 analyze，CI 从 10-09 连红十几次。

触发条件：暂存区动到 `lib/`、`test/`、`android/` 或 `pubspec.yaml`
（Dart 文件才会触发 analyze；纯文档/站点提交不付这几秒）。

## 为什么不跑全量 `flutter test`

要几分钟。门禁一旦慢到让人习惯性敲 `--no-verify`，就等于没装。

## 为什么不把 CJK 硬编码审计也放进来

`tool/audit_cjk_hardcode.py --baseline` 在棘轮发现改善时会**自动改写**
`tool/cjk_hardcode_baseline.txt`。放进钩子会让每次提交都可能把工作区弄脏出一个
未暂存的改动，比它拦住的回归更烦人。它留在 CI 里。

## 为什么 analyze 只跑暂存文件

全仓 `dart analyze` 约 21 秒，而且会把**其他 Agent 正在改的半成品**也报出来——
在这个约 5 个 Agent 并行的共享工作区里，那等于用别人的未完成代码拦你的提交。
只分析暂存文件：自己的改动自己负责，CI 照旧全量兜底。

## 逃生舱

```bash
git commit --no-verify
```

误伤时用，但请**立刻**手动补跑：

```bash
flutter test test/architecture/ --timeout 60s
dart analyze --fatal-infos <刚才暂存的 .dart 文件>
```

并在 `.agents/no-verify-log.md` 追加一行留痕（时间 / 提交号 / 红项归属 / 补跑结果）——
跳过次数涨起来就是规则失效的信号。

## 守卫读「本次提交的快照」，不读工作区（2026-10-20 晚改）

守卫原先读**整个工作区**，并行会话的在途改动会顶爆别人的棘轮（2026-10-19 一晚
约 45 次 `--no-verify` 大半是这类误伤）。中间试过「红项归因」脚本，但
「域内混入在途改动就放行」在设置域经常有脏文件的现实下，会连真实回归一起放过去
——当天即废。最终机制：

1. 钩子先 `git checkout-index` 把**索引**物化到临时目录，经 `MIKCB_GUARD_SNAPSHOT`
   交给守卫。索引=本次提交的内容（普通提交与路径限定提交 `git commit -- 路径`
   都成立，后者 git 会给钩子一个只含本次路径更新的临时索引）。
2. 守卫的文件读取统一走 `test/architecture/guard_source.dart` 的 `resolve()`；
   纪律扫描测试盯着新守卫不许直读 `File/Directory`。
3. 守卫红了再以 **HEAD 快照**对照复跑一次：
   - HEAD 绿 ⇒ 红项由本次提交引入，拦下（棘轮只减不增不变）；
   - HEAD 也红 ⇒ 基线早已失守（先前提交越过基线没同步），先同步基线再提交。

## 工具链起不来时会放行

本钩子的定位是「快速本地反馈」，不是第二道 CI。所以 **flutter 自己没跑起来时
它会放行并把报错打出来**，而不是拦住提交——本机 Flutter 一出毛病就锁死所有提交，
而那报错与你的代码无关、也没法就地修，门禁一旦这样就只会被 `--no-verify` 绕过。

已验证会落到这条分支的报错签名（`Error: Unable to...` 一族）：

- `Unable to determine engine version` — 引擎版本戳过期，或 PATH 里的 `git` 有问题
  （Flutter 靠 `git` 算自己的版本号，`git` 被抢占就会报这个）
- `Could not find a command named ...`

守卫**真的**不通过时报的是另一套东西（会带
`架构守卫红，HEAD 上是绿的` 与棘轮说明），两者不会混淆。

## 不想用

不设 `core.hooksPath` 就行，没有别的副作用。CI 侧的门禁与本钩子无关，照常生效。
