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
import java.util.concurrent.TimeUnit

/**
 * 跨域门禁守卫（2026-11-11 建立）：给两条**落在 `pages/<域>` 映射之外**的既有门禁装一个 L0 按钮。
 *
 * ## 它补的是哪个洞
 *
 * 仓库里两条最常用的文本门禁都没法用 L0 点：
 *
 * | 门禁 | 现在住哪 | L0 能不能点到 |
 * |---|---|---|
 * | `ComposePageStyleGuardTest`（R1..R7 七条样式规则） | `test/.../pages/` **包根** | 不能 |
 * | `CjkLiteralGateTest`（中文字面量棘轮） | `test/.../i18n/` | 不能 |
 *
 * 原因在 `scripts/test-kotlin-module.ps1` 的映射规则：`-Module pages/<域>` 只收
 * `main/…/pages/<域>` 与 `test/…/pages/<域>` 两个目录，外加 `testutil/` 与共享模型层。
 * 包根 `pages/` 不是 `pages/<域>`（`-Module pages` 剥前缀后 slug 为空，收不到包根测试），
 * `i18n/` 更是完全另一个包。于是这两条门禁**只有跑整包 L2 才会被执行**——
 * 改一行页面样式、加一句中文字面量，想在交活前自查，代价是拉起 Gradle 排队等锁。
 * 实际后果是「交活前根本不查」，样式债与 i18n 债都得靠人盯。
 *
 * 本类不改判据、不搬既有守卫，只做一件事：在 `-Module pages/crossguard` 里**调用既有入口**，
 * 让 L0 一条命令同时判样式与 i18n。`pages/crossguard` 因此是一个**只有测试目录**的域
 * （与 `pages/emptyguard`、`pages/loading`、`pages/sheetguard` 同一先例）：
 * 它不属于任何页面，产物只有「红/绿」。
 *
 * ## 判据一律走既有入口，本类不重写扫描规则
 *
 * 样式与 CJK 的规则各有**两份实现**（PowerShell / Python 一份，Kotlin 守卫一份），
 * 逐字保持一致本身就是维护负担。如果在第三个地方再抄一份判据，三份迟早漂移，
 * 而且「哪份算准」没有答案。所以这里只做**进程调用 + 退出码判读**：
 *
 * - 样式：`pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain all`
 *   —— 走全仓（`all`），因为本守卫是跨域的；exit 0 = 绿。
 * - CJK：`python scripts/i18n-cjk-baseline.py --check` —— exit 0 = 绿（该模式由并行交付物 1 提供）。
 *
 * 失败时把子进程 exit code 与输出末尾 20 行贴进断言消息，读到报错就能定位，不用重跑。
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
 * ## 咬合探针（2026-11-11，原始输出见 `.agents/diag/`）
 *
 * 1. 在 `pages/timetable/` 的页面源码里临时加一处 `fontSize = 12.sp` ⇒ 样式项红；
 *    还原 ⇒ 绿。
 * 2. CJK 项：注入中文那条依赖 `--check` 先落地；未落地时本项按能力门**明确红**，
 *    不复用只读模式打印出的统计充当判据。探针记录与结论见笔记
 *    `.agents/notes/implemented/testing/2026-11-11-crossguard-l0-entry.md`。
 */
class CrossDomainGateGuardTest {

    /**
     * 空跑哨兵：仓库根、两个脚本、两份基线、两个解释器缺一即红；外加样式入口活性探针。
     *
     * 这一条不判业务红绿，只保证「后面的判据不是空转」。它红了先按报错里的路径修环境，
     * 不要去看业务代码。
     */
    @Test
    fun `空跑哨兵 仓库根与两个入口两份基线必须都在`() {
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

        /** 两份 CJK 基线：`--check` 的比对对象，缺一份就没有棘轮可判。 */
        const val CJK_BASELINE_COMPOSE = "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt"
        const val CJK_BASELINE_MAIN =
            "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline-main.txt"

        val GATE_FILES = listOf(STYLE_SCRIPT, CJK_SCRIPT, CJK_BASELINE_COMPOSE, CJK_BASELINE_MAIN)
    }
}
