# 源码守卫写法（怎么写一条不会骗绿的守卫）

> 适用：`android/app/src/test/kotlin/**` 里**读源码做断言**的守卫（`*GuardTest` / `*ContractTest` 的源码面）。
> 行为断言（直接调被测函数）不受本文约束，按 `testing-policy` 的要求写就行。
> 本文只写「必须怎么做 / 不许怎么做」；为什么、实测数字在 `.agents/reference/testing-policy.md` §五（本机私有）。

---

## 一、否定式断言必须先断言读取结果非空

**判据**：`assertFalse(src.contains("旧写法"))`、`"旧写法" !in src` 这类断言，前面必须有一步
`assertTrue(src.isNotBlank())`（或等价），**除非**同一断言块里已有正向断言会在空读时先红。

**为什么**：读成空串时「没找到」和「没这段代码」无法区分，断言恒真。

**活例**（2026-11-12 审计，全仓唯一坐实的一条）：`pages/shell/HomePullQuickImportWiringGuardTest.kt`
的**历史形态**——快照 `25595fb7a` 的 `:60-63`：

```kotlin
val enabledLine = source.lineSequence()
    .firstOrNull { it.contains("val pullImportEnabled =") }.orEmpty()
assertTrue(..., "homeViewMode" !in enabledLine)   // 锚点一改名 ⇒ enabledLine="" ⇒ 恒真
```

> **该洞已修**：`522c4f3af` 补了 `enabledLine != null` 前置断言（消息原文「下面那条判据在空串上会恒真，等于没守」）。
> 当前 HEAD 里 `:63` 早就不是那条断言了——**活例指向已修代码是最容易误导后来人的一种过期**，所以这里只留历史快照 + 修复提交（见第六条）。

**推荐写法**：直接用 `testutil/SourceAssertions.kt`
- `assertSourceContains(source, needle, label)` —— 必须出现，空读即红；
- `assertSourceLacks(source, needle, label)` —— 不许出现，**内部先判空**。

失败消息已带 `[label]` + needle + 实际内容（区分「空（0 字符）」与「只有 N 个空白字符」）。

---

## 二、一处先红，就不必管第二处（判据层面）

**判据**：空读时**同一断言块里已有正向断言会先变红**，第二条否定断言不需要再补判空。

**反面教训**（2026-11-12 审计把这两条误判成恒真）：
- `pages/shell/DiagnosticsWiringGuardTest.kt`：空分支 → `code=""` → `symbols.filter { it !in "" }` 返回**全部符号** → `assertEquals(emptyList, wrong)` 直接红（只是消息误导，现已前置 `code.isNotBlank()` 让真因先说）。
- `pages/sync/TimetableSnapshotBridgeMacroFailureTest.kt`：`assertTrue(raw.contains("remote"))` 在空读时先红，紧随的 `assertFalse(raw.contains("local"))` 被兜住。

> 审计时必须**连相邻正向断言一起看**：只判「操作数能否为空」，会把有兜底的断言算成恒真。
> 参考分母（**快照 `25595fb7a`**，2026-11-12 实测）：748 个 `*Test.kt` → 否定式断言 624 条 → 读文件的 82 条 → 真正空读即静默通过的 **1 条**。
> 复现量法：`git ls-tree -r --name-only 25595fb7a -- android/app/src/test | grep 'Test.kt$' | wc -l`。
> 当前 HEAD（`2f45b9121`）是 **749** 个 `*Test.kt`；624 / 82 / 1 三个数**未在 HEAD 复测**，引用时请连快照一起引。

---

## 三、读源码必须走共享剥离器，档位由调用方显式选

**判据**：
- 一律用 `testutil/SourceText.kt` 的 `readKotlinSourceNormalized`（默认档：剥注释、留字符串）或
  `readKotlinSourceNoStrings`（中性化档：连字符串内容一起抹成空格）；**不许**自己 `readText()` 再手搓。
- **档位不许藏进 helper**：helper 里隐式决定档位，调用点就看不出「这条判据吃的是哪种文本」。
  判**字面量本身**必须用默认档；判**调用/接线结构**才用中性化档。
- 空读/读不到文件要在 helper 里直接 `error(...)`，**不许**返回 `""` 或 `orEmpty()`（否则下游否定断言恒真）。

**活例**：`pages/timetable/day/DayAgendaWallpaperInkWiringGuardTest.kt` 的教训——同一文件里既有判代码结构的
`readCallSource`（中性化档），也有判字面量的 `readLiteralSource`（默认档）；两者一旦用反，被查的字面量会被
自己擦掉 ⇒ 判据在空集上恒真。

---

## 四、新增守卫必须附两组探针

**判据**（两组都要做，做完在提交信息里留痕）：
1. **改坏 → 红**：把被测的接线/行为改反，确认守卫变红，再还原；
2. **注释掉 → 也红**：把被测的那一行**注释掉**（不是删掉），守卫仍须变红——这条专抓「读法没剥注释 / 判据锚点被注释绕过」。

第 2 条是 2026-11-12「消灭恒真断言」专项的直接产物：只做第 1 条时，`readText()` 不剥注释的守卫会把
注释掉的代码当成还在。

---

## 五、不许用「读不到就跳过」当兜底

**判据**：`if (source.isEmpty()) return`、`runCatching { … }.getOrNull() ?: return` 这类「读不到就跳过」，
在守卫里等于**静默免检**。守卫宁可红，也不许在缺输入时变成通过。

例外只有一种：**同一用例里前面已经显式断言了输入非空**（见第二条），此时跳过分支不可达。

---

## 六、本文这类文档的引用纪律

引用「当前代码」的文档，**要么带快照 HEAD，要么带可复现命令**；两者都没有的引用，半年后一定会漂。

- 行号一律写成 `提交:文件:行`（例：快照 `25595fb7a` 的 `HomePullQuickImportWiringGuardTest.kt:60-63`），不要只写 `文件:行`；
- 数字写清快照 HEAD 与量法（例：`git ls-tree -r --name-only <sha> -- android/app/src/test | grep 'Test.kt$' | wc -l`）；
- 被引用的代码修掉之后**别删历史形态**：标成「历史形态（`<旧sha>`）+ 已由 `<新sha>` 修复」。活例指向已修代码，是最容易误导后来人的一种过期。

---

## 与其它文档的关系

- 行为/契约测试怎么写：`testing-policy`（本机私有）+ `AGENTS.md`「测试与验证策略」。
- 门禁与文案的**事实清单**（当前数值、执行边界）：`gating-and-copy-standards.md`（归掌舵）。
- 代码侧落点：`testutil/SourceText.kt`（剥离器，P6-G2 所有）、`testutil/SourceAssertions.kt`（守卫断言 API）。
