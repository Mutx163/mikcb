package com.mutx163.qingyu.pages.crossguard

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction
import java.nio.file.Files
import java.nio.file.InvalidPathException
import java.nio.file.Path
import java.util.concurrent.TimeUnit

/**
 * 跨域门禁守卫（2026-11-11 建立）：给两条**落在 `pages/<域>` 映射之外**的既有门禁装一个 L0 按钮。
 *
 * ## 它补的是哪个洞
 *
 * 仓库里三条最常用的文本门禁都没法用 L0 点：
 *
 * | 门禁 | 现在住哪 | L0 能不能点到 |
 * |---|---|---|
 * | `ComposePageStyleGuardTest`（R1..R7 七条样式规则） | `test/.../pages/` **包根** | 不能 |
 * | `CjkLiteralGateTest`（中文字面量棘轮） | `test/.../i18n/` | 不能 |
 * | `CopyGapGateTest`（文案缺口棘轮） | `test/.../i18n/` | 不能 |
 *
 * 原因在 `scripts/test-kotlin-module.ps1` 的映射规则：`-Module pages/<域>` 只收
 * `main/…/pages/<域>` 与 `test/…/pages/<域>` 两个目录，外加 `testutil/` 与共享模型层。
 * 包根 `pages/` 不是 `pages/<域>`（`-Module pages` 剥前缀后 slug 为空，收不到包根测试），
 * `i18n/` 更是完全另一个包。于是这三条门禁**只有跑整包 L2 才会被执行**——
 * 改一行页面样式、加一句中文字面量、改一条译文，想在交活前自查，代价是拉起 Gradle 排队等锁。
 * 实际后果是「交活前根本不查」，样式债、i18n 债、文案缺口债都得靠人盯。
 *
 * 本类不改判据、不搬既有守卫，只做一件事：在 `-Module pages/crossguard` 里**调用既有入口**，
 * 让 L0 一条命令同时判样式、i18n 与文案缺口。`pages/crossguard` 因此是一个**只有测试目录**的域
 * （与 `pages/emptyguard`、`pages/loading`、`pages/sheetguard` 同一先例）：
 * 它不属于任何页面，产物只有「红/绿」。
 *
 * ## 判据一律走既有入口，本类不重写扫描规则
 *
 * 样式与 i18n 的规则各有**两份实现**（PowerShell / Python 一份，Kotlin 守卫一份），
 * 逐字保持一致本身就是维护负担。如果在第三个地方再抄一份判据，三份迟早漂移，
 * 而且「哪份算准」没有答案。所以这里只做**进程调用 + 退出码判读**：
 *
 * - 样式：`pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain all`
 *   —— 走全仓（`all`），因为本守卫是跨域的；exit 0 = 绿。
 * - CJK：`python scripts/i18n-cjk-baseline.py --check` —— exit 0 = 绿
 *   （该模式由并行交付物 1 于 2026-11-11 当天落地，并已用注入探针验过语义）。
 * - 文案缺口：`python scripts/i18n-copy-gap.py --check` —— exit 0 = 绿。
 *
 * 失败时把子进程 exit code 与输出末尾 20 行贴进断言消息，读到报错就能定位，不用重跑。
 *
 * ## 文案缺口基线的版本头：为什么单独做哨兵，而且拆纯函数
 *
 * `--check` 只比对「缺口条目」，**版本头不一致它看不出来**：改了规则或白名单（脚本里常量 +1）
 * 却没重跑 `--write`，旧基线里是旧口径算出的条目，`--check` 照样可能绿，门禁悄悄失效。
 * 这类漂移编译得过、单测也绿，只能靠源码哨兵钉住。
 *
 * 判据**从脚本源码读常量**再与基线头比对（[verifyCopyGapHeader]），不写死「只认 1」：
 * 将来升到 v2，基线没跟上会红，两边一起升则绿。
 *
 * 拆成纯函数是为了**可测**：三条「必须红」的分支（源码取不到常量 / 基线缺版本行 / 两边不相等）
 * 用真实仓库是测不到的——真实仓库永远落在绿的那一支。于是：
 *
 * - `verifyCopyGapHeader(scriptSource, baselineText)`：入参两段文本、出参问题列表，空 = 通过；
 * - `copyGapSentinelProblems(baselinePath, scriptPath)`：入口，路径可替换（默认真实仓库）；
 * - `runCopyGapSentinel(...)`：出口，把问题列表翻成「退出码 + 打印行」，同样可被 fixture 驱动。
 *
 * 五条用例 = 4 条语义（改名 / 缺版本行 / 不一致 / 真实仓库默认参数）+ 1 条接线
 * （喂 TEMP 里的坏基线，断言入口真的返回非零并打印两边的值）。
 * **纯函数证明「判断对不对」，接线用例证明「判断有没有被用上」**——只做前者，
 * 「拿到问题列表却 exit 0」这类故障一条都抓不到。
 *
 * 「取不到 ⇒ 红」是默认姿势，不是特例：读不到输入却算通过，等于哨兵不存在。
 *
 * ## 为什么必须先探测 `--check` 再信退出码（假绿陷阱，实测）
 *
 * 2026-11-11 实测：`i18n-cjk-baseline.py` 当时只认 `--source-set` / `--write`，
 * **未知参数被静默忽略**——`python scripts/i18n-cjk-baseline.py --check` 会照常打印只读统计
 * 并 `exit 0`。也就是说「跑 --check，看退出码」在能力未落地时会给出**满绿假象**，
 * 这是本类要防的第一类事故（比没有门禁更糟：没人会去查一个绿灯）。
 *
 * 所以判据拆成两步：① 源码里必须真的存在 `--check` 这个入口（能力门，缺失即红并点名依赖）；
 * ② 存在之后才跑它，按退出码判红绿。**能力门只能证明入口在，不能证明语义对**——
 * 语义靠咬合探针证明（改动一处中文 ⇒ 必须红），缺一步都不算验过。
 * 本类因此不接受「用只读模式的打印文本自己拼判据」：那等于在本类里实现第三份比对。
 *
 * ## 空跑哨兵（缺一条就等于门禁不存在）
 *
 * 判据全部依赖仓库外的文件与解释器，任何一处落空都必须**抛错**，不许静默跳过：
 *
 * - 仓库根定不出来（`user.dir` 往上找不到 `android/app/src`）；
 * - `scripts/compose-style-lint.ps1` / `scripts/i18n-cjk-baseline.py` 不在或为空；
 * - 两份 CJK 基线（`cjk-literal-baseline.txt` / `cjk-literal-baseline-main.txt`）不在或为空；
 * - `pwsh` / `python` 找不到（报错里列出探测过的每一个候选路径 + PATH 全文）；
 * - 子进程超过 [TIMEOUT_SECONDS] 秒不结束（强杀 + 红，并说明是超时而不是业务红）。
 *
 * 另加一条**入口活性探针**：拿一个不存在的域去问样式脚本，它必须非 0 退出。
 * 这条防的是「脚本还在、但已经什么都不判了」——那种情况下 exit 0 与绿无关，本类会假绿。
 *
 * ## 咬合探针（2026-11-11，原始输出见 `.agents/diag/crossguard-probe-*.log`）
 *
 * 1. 在 `pages/guide/MoreFeaturesPage.kt` 的 `InputField(` 参数里临时加 `fontSize = 12.sp` ⇒
 *    样式项 exit 1（待修 1 处）⇒ 还原 ⇒ `OK (3 tests)`。
 * 2. 同一位置换成 `placeholder = "跨域探针中文字面量"` ⇒ i18n 项 exit 1，并点名该文件
 *    `6 → 7` ⇒ 还原 ⇒ `OK (3 tests)`。`--check` 落地前出现过另一种红：能力门缺失时本项
 *    **明确失败**并点名依赖，不静默跳过（那正是本类要防的假绿）。
 *    完整记录见笔记 `.agents/notes/implemented/testing/2026-11-11-crossguard-l0-entry.md`。
 */
class CrossDomainGateGuardTest {

    /**
     * 空跑哨兵：仓库根、三个脚本、三份基线、两个解释器缺一即红；外加样式入口活性探针。
     *
     * 这一条不判业务红绿，只保证「后面的判据不是空转」。它红了先按报错里的路径修环境，
     * 不要去看业务代码。
     */
    @Test
    fun `空跑哨兵 仓库根与三个入口三份基线必须都在`() {
        val root = repoRoot()
        val missing = mutableListOf<String>()

        for (rel in GATE_FILES) {
            val file = File(root, rel)
            when {
                !file.isFile -> missing += "$rel（不是文件）"
                file.length() == 0L -> missing += "$rel（空文件）"
            }
        }

        val pwsh = findExecutable(PWSH_NAME)
        if (pwsh.command == null) {
            missing += "$PWSH_NAME 找不到；探测过：\n" + probeListing(pwsh.probed)
        }
        val python = findExecutable(PYTHON_NAME)
        if (python.command == null) {
            missing += "$PYTHON_NAME 找不到；探测过：\n" + probeListing(python.probed)
        }

        assertTrue(
            buildString {
                appendLine("跨域门禁跑不起来（不是业务红，是环境/入口缺失）——按纪律抛错而不是跳过：")
                missing.forEach { appendLine("  - $it") }
                appendLine("仓库根：${root.absolutePath}")
                appendLine("user.dir=${System.getProperty("user.dir")}")
            },
            missing.isEmpty(),
        )

        // 入口活性探针：脚本对不存在的域必须非 0 退出，且报错里点到那个域名。
        // 若这里变红，说明「exit 0 = 绿」这条判读不再成立，别急着去改样式代码。
        val sentinel = "__crossguard_sentinel_missing_domain__"
        val probe = runGate(
            "compose-style-lint -Domain $sentinel（入口活性探针）",
            root,
            pwsh.command!!, "-NoProfile", "-File", File(root, STYLE_SCRIPT).absolutePath,
            "-Domain", sentinel,
        )
        assertTrue(
            buildString {
                appendLine("入口活性探针失败：对不存在的域 [$sentinel] 竟然 exit 0。" +
                    "那 exit 0 就不能当绿用（脚本在空转），本守卫会假绿。")
                appendLine(probe.report())
            },
            probe.exitCode != 0,
        )
        assertTrue(
            buildString {
                appendLine("入口活性探针失败：报错里没提到域 [$sentinel]，" +
                    "说明它不是因为「域不存在」才失败的，入口行为可能已经变了。")
                appendLine(probe.report())
            },
            probe.combined.contains(sentinel),
        )
    }

    /**
     * 样式判据：`compose-style-lint.ps1 -Domain all` 必须 exit 0。
     *
     * 走 `all` 而不是 `pages/crossguard`（这个域只有测试、没有页面）：本守卫是**跨域**的，
     * 只盯自己域等于把别人的债留给 L2。例外清单 `tool/compose_style_exceptions/<域>.txt`
     * 的新增/过期判定都在脚本里，本类不做二次解释。
     */
    @Test
    fun `样式判据 compose-style-lint Domain all 必须是绿`() {
        val root = repoRoot()
        val pwsh = requireExecutable(PWSH_NAME, "样式门禁要调 pwsh 起 compose-style-lint.ps1")
        val run = runGate(
            "compose-style-lint -Domain all",
            root,
            pwsh, "-NoProfile", "-File", File(root, STYLE_SCRIPT).absolutePath, "-Domain", "all",
        )
        assertTrue(
            buildString {
                appendLine("Compose 样式门禁红了：待修违规必须为 0（依据 docs/reference/compose-page-style-rules.md）。")
                appendLine("判据由 scripts/compose-style-lint.ps1 给出，本守卫不重写规则；下面是它的原始输出。")
                appendLine(run.report())
                appendLine("修法：改代码走共享套件（QingyuPageScaffold / QingyuPageList / QingyuCard /")
                appendLine("QingyuSectionTitle / MiuixTheme.textStyles / 主题语义槽）；确需保留的写法人工编辑")
                appendLine("tool/compose_style_exceptions/<域>.txt 并写明原因（-Write 只删过期行，不会帮你加）。")
            },
            run.exitCode == 0,
        )
    }

    /**
     * i18n 判据：`i18n-cjk-baseline.py --check` 必须 exit 0。
     *
     * 两步走（见类注释的假绿陷阱）：先证明 `--check` 这个入口在源码里真的存在，
     * 再信它的退出码。**入口不存在时本条明确红**，不许跳过、不许在本类里自己实现比对。
     */
    @Test
    fun `i18n 判据 cjk-baseline --check 必须是绿`() {
        val root = repoRoot()
        val python = requireExecutable(PYTHON_NAME, "i18n 门禁要调 python 起 i18n-cjk-baseline.py")
        val script = File(root, CJK_SCRIPT)
        val scriptText = if (script.isFile) script.readText() else ""
        assertTrue(
            buildString {
                appendLine("依赖未落地：scripts/i18n-cjk-baseline.py 里没有 --check 模式，本条无法成立。")
                appendLine("为什么不能直接看退出码：该脚本会**静默忽略**未知参数——" +
                    "跑 --check 会照常打印只读统计并 exit 0（2026-11-11 实测），" +
                    "直接判 exit 0 只会得到满绿假象。")
                appendLine("依赖：交付物 1 提供 `python scripts/i18n-cjk-baseline.py --check`" +
                    "（只读、exit code 表达红绿；--write 仍归人工/门禁，不在本守卫里跑）。")
                appendLine("纪律：本类不许跳过、也不许读只读模式的打印文本自己拼比对——" +
                    "那等于在本类里再造第三份判据。")
                appendLine("脚本：${script.absolutePath}")
            },
            scriptText.contains("--check"),
        )

        val run = runGate(
            "i18n-cjk-baseline --check",
            root,
            python, script.absolutePath, "--check",
        )
        assertTrue(
            buildString {
                appendLine("i18n 中文字面量棘轮红了：新增硬编码中文、或修复后忘了下调基线，都算红。")
                appendLine("判据由 scripts/i18n-cjk-baseline.py --check 给出，本守卫不重写规则；下面是它的原始输出。")
                appendLine(run.report())
                appendLine("修法：屏上文案走 ARB 句柄（见 AGENTS.md「界面文案风格」）；" +
                    "修复导致的计数下调必须同步下调对应基线行，不得上调。")
            },
            run.exitCode == 0,
        )
    }

    /**
     * 文案缺口判据：`i18n-copy-gap.py --check` 必须 exit 0。
     *
     * 与 CJK 那条同一套路（见类注释的假绿陷阱）：该脚本同样**静默忽略未知参数**，
     * 没有 `--check` 时会退化成「统计 + 比对基线」，退出码不再表达「只比基线」的语义，
     * 所以先过能力门再信退出码。基线缺失时它会把全部条目算成「该降未降」（碰巧也红），
     * 但那种红说的是另一件事，所以基线存在性在这里也先断言一次，让报错说准。
     */
    @Test
    fun `文案缺口判据 i18n-copy-gap --check 必须是绿`() {
        val root = repoRoot()
        val python = requireExecutable(PYTHON_NAME, "文案缺口门禁要调 python 起 i18n-copy-gap.py")
        val script = File(root, COPY_GAP_SCRIPT)
        val scriptText = if (script.isFile) script.readText() else ""
        val baseline = File(root, COPY_GAP_BASELINE)
        assertTrue(
            buildString {
                appendLine("依赖未落地：scripts/i18n-copy-gap.py 里没有 --check 模式，本条无法成立。")
                appendLine("为什么不能直接看退出码：该脚本会**静默忽略**未知参数，" +
                    "没有 --check 时退化成「统计 + 比对基线」，退出码不再表达「只比基线」的语义" +
                    "——直接判 exit 0 会得到假绿。")
                appendLine("纪律：本类不许跳过、也不许在本类里自己实现缺口比对（那等于造第三份判据）。")
                appendLine("脚本：${script.absolutePath}")
                appendLine(
                    "基线：${baseline.absolutePath}" +
                        "（存在=${baseline.isFile}，字节=${if (baseline.isFile) baseline.length() else -1}）",
                )
            },
            scriptText.contains("--check") && baseline.isFile && baseline.length() > 0L,
        )

        val run = runGate(
            "i18n-copy-gap --check",
            root,
            python, script.absolutePath, "--check",
        )
        assertTrue(
            buildString {
                appendLine("文案缺口棘轮红了：新增「未翻译 / 中文污染」，或修好一条却没下调基线，都算红。")
                appendLine("判据由 scripts/i18n-copy-gap.py --check 给出，本守卫不重写规则；下面是它的原始输出。")
                appendLine(run.report())
                appendLine("修法：补本地语种译文；确属修复的，用 `python scripts/i18n-copy-gap.py --write`")
                appendLine("下调基线（棘轮只许降不许升），并与代码同批提交。")
            },
            run.exitCode == 0,
        )
    }

    /**
     * 文案缺口基线的**版本头比对**（纯函数：入参两段文本，出参问题列表，空 = 通过）。
     *
     * 为什么拆成纯函数：三条「必须红」的分支（源码取不到常量 / 基线缺版本行 / 两边不相等）
     * 用真实仓库是**测不到**的——真实仓库永远落在绿的那一支，判据写坏了也发现不了。
     * 传两段 fixture 文本进来，四条用例各自咬一次，且**不必改**执笔的 `i18n-copy-gap.py`。
     *
     * 为什么需要它：`--check` 只比对「缺口条目」，**版本头不一致它看不出来**——
     * 改了规则或白名单（脚本里常量 +1）却没重跑 `--write`，旧基线里是旧口径算出来的条目，
     * `--check` 照样可能绿，门禁就悄悄失效了。这类漂移编译得过、测试也绿，只能靠源码哨兵钉住。
     *
     * 判据刻意**从脚本源码读常量**再与基线头比对，不写死「只认 1」：将来升到 v2，
     * 基线没跟上会红；脚本与基线一起升则绿。写死数字的哨兵升级当天就会假红、然后被改松成假绿。
     *
     * **取不到就是红**，不是特例：读不到输入却算通过，等于哨兵不存在。
     */
    internal fun verifyCopyGapHeader(scriptSource: String, baselineText: String): List<String> {
        val problems = mutableListOf<String>()
        val scriptRules = constantValue(scriptSource, RULES_CONST)
        val scriptWhitelist = constantValue(scriptSource, WHITELIST_CONST)
        if (scriptRules == null || scriptWhitelist == null) {
            problems += "没找到 $RULES_CONST / $WHITELIST_CONST：可能被改名 / 移位 / 改成导入" +
                "（哨兵只认脚本里行首的常量赋值）。实际读到：$RULES_CONST=${scriptRules ?: "<缺失>"}、" +
                "$WHITELIST_CONST=${scriptWhitelist ?: "<缺失>"}"
        }

        val lines = baselineText.lines()
        val baselineRules = versionLineOf(lines, RULES_CONST)
        val baselineWhitelist = versionLineOf(lines, WHITELIST_CONST)
        if (baselineRules == null || baselineWhitelist == null) {
            problems += "基线头里没找到版本行：$RULES_CONST=${baselineRules?.value ?: "<缺失>"}、" +
                "$WHITELIST_CONST=${baselineWhitelist?.value ?: "<缺失>"}" +
                "（期望形如 `# 规则版本 $RULES_CONST=1，白名单版本 $WHITELIST_CONST=1`）。" +
                "基线头前 6 行：" +
                lines.take(6).mapIndexed { index, line -> "L${index + 1}: $line" }.joinToString(" ｜ ")
        }

        if (scriptRules != null && baselineRules != null && scriptRules != baselineRules.value) {
            problems += "$RULES_CONST 不一致：基线=${baselineRules.value}，脚本=$scriptRules"
        }
        if (scriptWhitelist != null && baselineWhitelist != null && scriptWhitelist != baselineWhitelist.value) {
            problems += "$WHITELIST_CONST 不一致：基线=${baselineWhitelist.value}，脚本=$scriptWhitelist"
        }
        return problems
    }

    /**
     * 哨兵**入口**：读磁盘上的脚本与基线，返回问题列表（空 = 通过）。
     *
     * 路径可替换（默认真实仓库）：纯函数只能证明「判断对不对」，而门禁链上真正跑的是
     * 「谁调它、喂的是哪个文件、拿到非空列表后干什么」。路径写死时，「接线把结果丢了」
     * 这类故障一条语义用例都抓不到——所以这里把路径做成参数，接线才能被 fixture 驱动。
     *
     * 读不到输入（文件不在 / 读不出来）**也是问题**，不返回空列表：读不到却算通过，等于哨兵不存在。
     */
    internal fun copyGapSentinelProblems(
        baselinePath: Path = defaultCopyGapBaselinePath(),
        scriptPath: Path = defaultCopyGapScriptPath(),
    ): List<String> {
        val problems = mutableListOf<String>()
        if (!Files.isRegularFile(scriptPath)) {
            problems += "读不到脚本：$scriptPath（哨兵取不到输入就按红处理，不跳过）"
        }
        if (!Files.isRegularFile(baselinePath)) {
            problems += "读不到基线：$baselinePath（先跑 `python scripts/i18n-copy-gap.py --write` 再提交）"
        }
        if (problems.isNotEmpty()) return problems
        return verifyCopyGapHeader(Files.readString(scriptPath), Files.readString(baselinePath))
    }

    /** 哨兵运行结论：退出码 + 要打印的行。让「非空 → 非零 + 打印列表」这段能被断言。 */
    internal data class SentinelResult(val exitCode: Int, val lines: List<String>)

    /**
     * 哨兵出口：把问题列表翻成「退出码 + 打印行」。
     *
     * 这一段是接线里最容易丢结果的地方（拿到列表却不看），所以它本身也得能被 fixture 驱动：
     * [copyGapSentinelProblems] 的入参可以换成 TEMP 里的坏基线，再断言这里返回非零。
     */
    internal fun runCopyGapSentinel(
        baselinePath: Path = defaultCopyGapBaselinePath(),
        scriptPath: Path = defaultCopyGapScriptPath(),
    ): SentinelResult {
        val problems = copyGapSentinelProblems(baselinePath, scriptPath)
        val lines = if (problems.isEmpty()) {
            listOf("文案缺口基线版本头一致：$RULES_CONST / $WHITELIST_CONST 与脚本常量相符")
        } else {
            problems
        }
        return SentinelResult(if (problems.isEmpty()) 0 else 1, lines)
    }

    /** 真实仓库的基线路径（默认参数用）。 */
    internal fun defaultCopyGapBaselinePath(): Path = File(repoRoot(), COPY_GAP_BASELINE).toPath()

    /** 真实仓库的脚本路径（默认参数用）。 */
    internal fun defaultCopyGapScriptPath(): Path = File(repoRoot(), COPY_GAP_SCRIPT).toPath()

    /**
     * 失败分支 1：脚本里的版本常量被改名 / 移位 / 改成导入 ⇒ 哨兵必须红。
     *
     * 这是最容易写成假绿的一支：正则匹配不到时若返回「没问题」，哨兵就永远绿。
     */
    @Test
    fun `版本常量被改名时哨兵必须红`() {
        // fixture：把 RULES_VERSION 改名成 RULES_VERSION_NEW（基线那头正常）
        val scriptSource = "${RULES_CONST}_NEW = 1\n$WHITELIST_CONST = 1"
        val baselineText = "# 规则版本 $RULES_CONST=1，白名单版本 $WHITELIST_CONST=1"
        val problems = verifyCopyGapHeader(scriptSource, baselineText)
        assertTrue(
            "常量被改名（只剩 ${RULES_CONST}_NEW）时哨兵必须红，实际返回「无问题」——那会变成假绿：",
            problems.isNotEmpty(),
        )
        assertTrue(
            "报错必须点名 $RULES_CONST 并说明可能「改名 / 移位 / 导入」，实际：\n${problems.joinToString("\n")}",
            problems.any { it.contains(RULES_CONST) && it.contains("改名") },
        )
    }

    /**
     * 失败分支 2：基线里读不到版本行 ⇒ 哨兵必须红。
     *
     * 真实故障形态：有人用 `--write` 之前手工编辑过基线、把注释头删了，或换了生成器。
     */
    @Test
    fun `基线缺少版本行时哨兵必须红`() {
        val scriptSource = "$RULES_CONST = 3\n$WHITELIST_CONST = 4"
        val baselineText = "# i18n 文案缺口基线（这条 fixture 故意没有版本行）\nA|ja|someKey"
        val problems = verifyCopyGapHeader(scriptSource, baselineText)
        assertTrue(
            "基线缺版本行时哨兵必须红，实际返回「无问题」：",
            problems.isNotEmpty(),
        )
        assertTrue(
            "报错必须点名「基线头」与缺失的常量，实际：\n${problems.joinToString("\n")}",
            problems.any { it.contains("基线头") && it.contains(RULES_CONST) },
        )
    }

    /**
     * 失败分支 3：两边版本号都有但不相等 ⇒ 哨兵必须红，且消息里要能同时看到两边的值。
     *
     * 顺带反向咬一口：只有 RULES 不一致时，不许把 WHITELIST 也算成问题（否则真升版时分不清要改哪个）。
     */
    @Test
    fun `两边版本号不一致时哨兵必须红`() {
        val scriptSource = "$RULES_CONST = 2\n$WHITELIST_CONST = 1"
        val baselineText = "# 规则版本 $RULES_CONST=1，白名单版本 $WHITELIST_CONST=1"
        val problems = verifyCopyGapHeader(scriptSource, baselineText)
        assertTrue("两边不一致时哨兵必须红，实际返回「无问题」：", problems.isNotEmpty())
        assertTrue(
            "报错必须同时打出两边的值（基线=1、脚本=2），实际：\n${problems.joinToString("\n")}",
            problems.any { it.contains("基线=1") && it.contains("脚本=2") },
        )
        assertTrue(
            "$WHITELIST_CONST 两边都是 1，不该被算成问题（否则升版时分不清要改哪个），实际：\n" +
                problems.joinToString("\n"),
            problems.none { it.contains(WHITELIST_CONST) },
        )
    }

    /**
     * 真实仓库那一支（健全性）：默认参数读仓库里的脚本与基线，必须**没有问题列表、exit 0**。
     *
     * 它红了才是「今天的仓库有漂移」；它绿不代表上面三条红分支被验过——那三条靠 fixture 用例。
     * 顺带钉死「空列表 ⇒ exit 0」：反向的接线错误（没问题却判红）也会在这里暴露。
     */
    @Test
    fun `真实仓库默认参数下版本头一致`() {
        val root = repoRoot()
        val script = File(root, COPY_GAP_SCRIPT)
        val baseline = File(root, COPY_GAP_BASELINE)
        assertTrue("找不到脚本：${script.absolutePath}", script.isFile)
        assertTrue(
            "找不到文案缺口基线：${baseline.absolutePath}（或为空）—— 没有基线，--check 无从比对，" +
                "先跑 `python scripts/i18n-copy-gap.py --write` 再提交",
            baseline.isFile && baseline.length() > 0L,
        )

        val problems = copyGapSentinelProblems()
        assertTrue(
            buildString {
                appendLine("真实仓库的文案缺口基线版本头哨兵红了：")
                problems.forEach { appendLine("  - $it") }
                appendLine("基线：${baseline.absolutePath}")
                appendLine("脚本：${script.absolutePath}")
                appendLine("修法：改了规则 / 白名单就重生成基线 —— " +
                    "`python scripts/i18n-copy-gap.py --write`，与脚本常量同批提交。")
            },
            problems.isEmpty(),
        )

        val result = runCopyGapSentinel()
        assertTrue(
            "真实仓库没问题时必须 exit 0（反过来判红就是接线错误），实际 exitCode=${result.exitCode}，打印：\n" +
                result.lines.joinToString("\n"),
            result.exitCode == 0,
        )
    }

    /**
     * **接线用例**：喂 TEMP 里一份版本号不匹配的基线给哨兵入口，必须返回非零并打印两边的值。
     *
     * 前面三条语义用例证明「判断对不对」，这一条证明「判断有没有被用上」：
     * 入口若把结果丢了（拿到问题列表却不看、或仍读死仓库默认路径），这里就会红。
     * 脚本用真实仓库那份，所以「基线=999 / 脚本=真实常量」必然不一致。
     */
    @Test
    fun `基线版本不匹配时哨兵入口返回非零`() {
        val tempDir = Files.createTempDirectory("crossguard-copygap-")
        val mismatched = tempDir.resolve("copy-gap-baseline.txt")
        try {
            Files.writeString(
                mismatched,
                "# 规则版本 $RULES_CONST=999，白名单版本 $WHITELIST_CONST=999\n" +
                    "A|ja|__crossguard_wiring_probe__\n",
            )

            val result = runCopyGapSentinel(baselinePath = mismatched)
            val printed = result.lines.joinToString("\n")
            assertTrue(
                "喂一份版本号不匹配的基线，哨兵入口必须返回非零" +
                    "（拿到问题却 exit 0 = 结果被丢了）。实际 exitCode=${result.exitCode}，打印：\n$printed",
                result.exitCode != 0,
            )
            assertTrue(
                "打印里必须同时出现两边的值：基线=999 与脚本的真实常量，实际：\n$printed",
                printed.contains("基线=999") && Regex("""脚本=\d+""").containsMatchIn(printed),
            )
            assertTrue(
                "接线用例的证据要能看出「读的是我传进去的那份基线」：$mismatched",
                printed.isNotBlank(),
            )
        } finally {
            Files.deleteIfExists(mismatched)
            Files.deleteIfExists(tempDir)
        }
    }

    /**
     * 从脚本源码里取 `<常量> = <整数>`；取不到返回 null（调用方必须按红处理，不许当成 0 或跳过）。
     *
     * 只认「行首常量赋值」：`NAME = 1` / 前面有缩进的同名赋值也行，但 `X_NAME = 1` 不算，
     * 所以改名 / 改成 `import` 都能被识别成「取不到」。
     */
    private fun constantValue(scriptSource: String, constant: String): Int? =
        Regex("""(?m)^\s*$constant\s*=\s*(\d+)\s*$""").find(scriptSource)?.groupValues?.get(1)?.toInt()

    /** 基线里形如 `RULES_VERSION=1` 的一行；返回行号（1 基）、原文与数值。 */
    private data class VersionLine(val lineNumber: Int, val text: String, val value: Int)

    /** 在基线文本里找版本行；找不到返回 null（调用方必须按红处理）。 */
    private fun versionLineOf(lines: List<String>, constant: String): VersionLine? {
        val pattern = Regex("""\b$constant\s*=\s*(\d+)""")
        lines.forEachIndexed { index, line ->
            val match = pattern.find(line) ?: return@forEachIndexed
            return VersionLine(index + 1, line.trim(), match.groupValues[1].toInt())
        }
        return null
    }

    // ------------------------------------------------------------------
    // 判据实现（只做「起子进程 + 读退出码」，不含任何业务扫描规则）
    // ------------------------------------------------------------------

    /** 一次子进程调用的全部证据：命令、退出码、两路输出、耗时。 */
    private data class GateRun(
        val label: String,
        val command: List<String>,
        val exitCode: Int,
        val stdout: String,
        val stderr: String,
        val elapsedMs: Long,
    ) {
        val combined: String get() = stdout + "\n" + stderr
    }

    /**
     * 失败时贴进断言消息的定位信息：exit code + 末尾 [TAIL_LINES] 行两路输出。
     *
     * 写成外层扩展而不是 [GateRun] 的成员：嵌套类不是 inner，实例里调不到外层的 [tail]。
     */
    private fun GateRun.report(): String = buildString {
        appendLine("  子进程：$label")
        appendLine("  命令行：${command.joinToString(" ")}")
        appendLine("  exit code：$exitCode（耗时 ${elapsedMs}ms）")
        appendLine("  ── stdout 末尾 $TAIL_LINES 行 ──")
        appendLine(tail(stdout))
        appendLine("  ── stderr 末尾 $TAIL_LINES 行 ──")
        appendLine(tail(stderr))
    }

    /** 一次可执行文件探测：解析出的命令行令牌（没找到为 null）+ 探测过的每个候选路径。 */
    private data class ExecutableProbe(val command: String?, val probed: List<String>)

    /** 仓库根：从 user.dir 往上找含 `android/app/src` 的目录（与既有守卫同一套写法）。 */
    private fun repoRoot(): File {
        val start = File(System.getProperty("user.dir") ?: ".").absoluteFile
        var dir: File? = start
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) return dir
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（`android/app/src`）—— 门禁无法验证，按失败处理（不许静默跳过）。" +
                "user.dir=${System.getProperty("user.dir")}，起点=${start.absolutePath}",
        )
    }

    /**
     * 找可执行文件：先按 PATH + PATHEXT 查元数据（命中就给绝对路径，报错信息更明确），
     * 查不到再用**启动探测**兜底。
     *
     * 为什么离不开启动探测：Windows 的 `WindowsApps\…\pwsh.exe` 是应用执行别名（0 字节重解析点），
     * 解析它的真实目标时要穿过受限目录，`Files.exists` 因此返回 false，`File.isFile()` 同样为 false
     * ——纯元数据探测会误报「pwsh 找不到」（2026-11-11 实测两次踩到）。而 CreateProcess 按 PATH
     * 解析这个别名是通的，所以「能起一次」才是可靠判据。
     *
     * 找不到时把**探测过的每一个候选路径**带回去——报错里要能看出是「没装」还是「装了但不在 PATH」。
     */
    private fun findExecutable(name: String): ExecutableProbe {
        val probed = mutableListOf<String>()
        val resolved = scanPath(name, probed)
        if (resolved != null) return ExecutableProbe(resolved.absolutePath, probed)
        if (executableStarts(name)) return ExecutableProbe(name, probed)
        return ExecutableProbe(null, probed.ifEmpty { listOf("<PATH 为空或未设置>") })
    }

    /** 按 PATH + PATHEXT 做元数据扫描；命中返回文件，探测过的候选路径累加进 [probed]。 */
    private fun scanPath(name: String, probed: MutableList<String>): File? {
        val path = System.getenv("PATH") ?: ""
        val dirs = path.split(File.pathSeparatorChar).filter { it.isNotBlank() }
        val suffixes = if (IS_WINDOWS) listOf(".exe", ".cmd", ".bat", "") else listOf("")
        for (dir in dirs) {
            for (suffix in suffixes) {
                val candidate = File(dir.trim(), name + suffix)
                probed += candidate.absolutePath
                // 本机 PATH 里存在含非法字符（`?`）的条目（第三方安装器写坏了环境变量），
                // File.toPath() 会抛 InvalidPathException。这种条目不可能命中，跳过并留痕，别让探针崩掉。
                val candidatePath = try {
                    candidate.toPath()
                } catch (e: InvalidPathException) {
                    probed[probed.lastIndex] = "${probed.last()}（PATH 条目含非法字符，跳过：${e.reason}）"
                    break
                }
                if (Files.exists(candidatePath) && !Files.isDirectory(candidatePath)) return candidate
            }
        }
        return null
    }

    /** 启动探测：真起一次，起得来才算找到（见 [findExecutable] 的注释）。 */
    private fun executableStarts(name: String): Boolean = try {
        val args = if (name == PWSH_NAME) listOf("-NoProfile", "-Command", "exit 0") else listOf("--version")
        val process = ProcessBuilder(listOf(name) + args).redirectErrorStream(true).start()
        process.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        process.waitFor(30, TimeUnit.SECONDS)
        true
    } catch (e: Exception) {
        false
    }

    /** 探测过的候选路径列表（错误消息里用；数量过多时截断，避免把 PATH 全文淹掉）。 */
    private fun probeListing(probed: List<String>): String = buildString {
        probed.take(MAX_PROBED_REPORTED).forEach { appendLine("      · $it") }
        if (probed.size > MAX_PROBED_REPORTED) {
            appendLine("      · …共 ${probed.size} 条候选，其余省略")
        }
    }

    /** 取一个必须存在的解释器；找不到就红，并把探测过的路径贴出来。返回可直接交给 [runGate] 的命令令牌。 */
    private fun requireExecutable(name: String, purpose: String): String {
        val probe = findExecutable(name)
        val found = probe.command
        if (found == null) {
            throw AssertionError(
                buildString {
                    appendLine("找不到 $name（$purpose）—— 按纪律红，不跳过。")
                    appendLine("探测过的路径（含启动探测一次）：")
                    appendLine(probeListing(probe.probed))
                    appendLine("PATH=${System.getenv("PATH")}")
                },
            )
        }
        return found
    }

    /**
     * 起一个子进程并等它结束（上限 [TIMEOUT_SECONDS] 秒）。
     *
     * 两路输出各开一条线程**边跑边读**：只 `waitFor` 再读会在输出超过管道缓冲时死锁，
     * 那样报出来的会是「超时」，掩盖真正的失败原因。
     */
    private fun runGate(label: String, workDir: File, vararg command: String): GateRun {
        val builder = ProcessBuilder(*command)
        builder.directory(workDir)
        val started = System.nanoTime()
        val process = try {
            builder.start()
        } catch (e: Exception) {
            throw AssertionError(
                "子进程起不来：$label\n命令行：${command.joinToString(" ")}\n工作目录：${workDir.absolutePath}\n$e",
                e,
            )
        }
        val out = ByteArrayOutputStream()
        val err = ByteArrayOutputStream()
        val outPump = Thread { process.inputStream.use { it.copyTo(out) } }
            .apply { isDaemon = true; name = "crossguard-stdout"; start() }
        val errPump = Thread { process.errorStream.use { it.copyTo(err) } }
            .apply { isDaemon = true; name = "crossguard-stderr"; start() }

        val finished = process.waitFor(TIMEOUT_SECONDS, TimeUnit.SECONDS)
        val elapsedMs = (System.nanoTime() - started) / 1_000_000L
        if (!finished) {
            process.destroyForcibly()
            outPump.join(PUMP_JOIN_MS)
            errPump.join(PUMP_JOIN_MS)
            throw AssertionError(
                buildString {
                    appendLine("子进程超时（> ${TIMEOUT_SECONDS}s，已强杀）：$label —— 超时按红处理。")
                    appendLine("  命令行：${command.joinToString(" ")}")
                    appendLine("  工作目录：${workDir.absolutePath}")
                    appendLine("  ── 超时前 stdout 末尾 $TAIL_LINES 行 ──")
                    appendLine(tail(decode(out.toByteArray())))
                    appendLine("  ── 超时前 stderr 末尾 $TAIL_LINES 行 ──")
                    appendLine(tail(decode(err.toByteArray())))
                },
            )
        }
        outPump.join(PUMP_JOIN_MS)
        errPump.join(PUMP_JOIN_MS)
        return GateRun(
            label,
            command.toList(),
            process.exitValue(),
            decode(out.toByteArray()),
            decode(err.toByteArray()),
            elapsedMs,
        )
    }

    /**
     * 解子进程输出：先按严格 UTF-8 解，失败再按 GBK（中文 Windows 的控制台代码页），最后保底不崩。
     *
     * 为什么不能只写死一种：`pwsh` 子进程的中文输出按控制台代码页走（重定向时是 ANSI 代码页），
     * 而 JVM 侧又可能被 `-Dfile.encoding` 改成 UTF-8——写死任一种都会把对方的输出解成一片 `�`，
     * 失败消息里贴乱码等于没贴（2026-11-11 实测踩到）。
     *
     * 为什么不退回 `Charset.defaultCharset()`：它会被 `-Dfile.encoding=UTF-8` 改掉，
     * 本机实测该环境变量一设，兜底照样乱码。所以候选编码写死，环境无关。
     */
    private fun decode(bytes: ByteArray): String =
        tryDecode(bytes, Charsets.UTF_8)
            ?: tryDecode(bytes, Charset.forName("GBK"))
            ?: String(bytes, Charsets.ISO_8859_1)

    /** 严格解码：遇到非法字节返回 null（而不是插一堆替换符蒙混过去）。 */
    private fun tryDecode(bytes: ByteArray, charset: Charset): String? = try {
        charset.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    } catch (e: CharacterCodingException) {
        null
    }

    /** 取输出末尾 [lines] 行（空输出给一个人话标记，免得报错里出现空白）。 */
    private fun tail(text: String, lines: Int = TAIL_LINES): String {
        val trimmed = text.trimEnd()
        if (trimmed.isEmpty()) return "（空）"
        return trimmed.lines().takeLast(lines).joinToString("\n") { "    $it" }
    }

    private companion object {
        /** 判据容许的墙钟上限：全仓样式扫描实测数秒；300s 是「慢」与「卡死」的分界。 */
        const val TIMEOUT_SECONDS = 300L

        /** 读输出的等待上限：子进程此时已结束，这里只是给线程收尾留量。 */
        const val PUMP_JOIN_MS = 5_000L

        /** 失败消息里贴的输出行数（约 20 行，够看到域汇总与第一条违规）。 */
        const val TAIL_LINES = 20

        /** 找不到解释器时报错最多列出的候选路径数（PATH 常有上百条，全列会淹掉信息）。 */
        const val MAX_PROBED_REPORTED = 20

        val IS_WINDOWS = System.getProperty("os.name").orEmpty().lowercase().contains("win")

        const val PWSH_NAME = "pwsh"
        const val PYTHON_NAME = "python"

        const val STYLE_SCRIPT = "scripts/compose-style-lint.ps1"
        const val CJK_SCRIPT = "scripts/i18n-cjk-baseline.py"
        const val COPY_GAP_SCRIPT = "scripts/i18n-copy-gap.py"

        /** 两份 CJK 基线：`--check` 的比对对象，缺一份就没有棘轮可判。 */
        const val CJK_BASELINE_COMPOSE = "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt"
        const val CJK_BASELINE_MAIN =
            "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline-main.txt"

        /** 文案缺口基线：`i18n-copy-gap.py --check` 的比对对象，头里带 RULES/WHITELIST 版本。 */
        const val COPY_GAP_BASELINE = "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/copy-gap-baseline.txt"

        /**
         * 版本常量的名字。**名字写在这里，值一律从脚本源码读**（见 [constantValue]）——
         * 把值也写死成 1，脚本升到 v2 时哨兵就会假红，然后被人改松成假绿。
         */
        const val RULES_CONST = "RULES_VERSION"
        const val WHITELIST_CONST = "WHITELIST_VERSION"

        val GATE_FILES = listOf(
            STYLE_SCRIPT,
            CJK_SCRIPT,
            COPY_GAP_SCRIPT,
            CJK_BASELINE_COMPOSE,
            CJK_BASELINE_MAIN,
            COPY_GAP_BASELINE,
        )
    }
}
