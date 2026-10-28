package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「页面索引目录 ↔ 分派层」一致性守卫（2026-10-28 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 壳里的页面索引是两份数据：`ShellPageCatalog`（**有什么**，纯 Kotlin，JVM 可测）
 * 与 `ShellPageIndex.kt` 的 `when (pageId)`（**点进去渲染谁**，Compose）。
 * 两份分开写，于是有三种典型错法，**每一种都不会让编译失败**：
 *
 * 1. 目录里写了「可进入」，分派里没有分支 → 用户点进去看到的是 `ShellMissingPage`；
 * 2. 分派里有分支，目录里没有这一条 → 这一页**谁也点不到**（等于没做）；
 * 3. 目录标着「暂不可用」（缺渲染层 / 缺宿主槽位），分派里却有分支 →
 *    说明其实能做，标注是过时的，L4 清单会跟着骗人。
 *
 * 2026-10-27 的 `l4-recon` 正是靠人读代码才发现「更新日志 / 课表页面设置 /
 * 实时活动·保活」三处台账虚标；人工登记会失真，**能编译 + 能构造**不会。
 * 这条守卫把第 1、3 两种错法变成机器可判。
 *
 * ## 为什么读文件文本而不是反射
 *
 * 分派层的「id → Composable」写在 `when` 的字符串字面量里，Kotlin 反射拿不到
 * （`when` 编译成字节码分支，字面量不保留）。所以这里读源码文本——
 * 与 Dart 侧 `test/architecture/` 的守卫同一套思路（那边经 `guard_source.dart` 读）。
 *
 * **代价必须写清**：文本解析对格式敏感。分派层的 id **必须**写成
 * `"<id>" ->` 且独占一行（现有 75 条全部如此）；若哪天改成多 id 合并分支
 * （`"a" , "b" ->`）或多行折行，这条守卫会先红——那是**故意的**，
 * 提醒改格式的人同时更新这里，而不是静默失效。
 *
 * ## 与 `ShellPageCatalogTest` 的分工
 *
 * 那个文件管目录**内部**的自洽（id 唯一、有标题、暂不可用必须写原因与分类）。
 * 本文件管目录与**分派层之间**的一致性。两者合起来才覆盖「点得进去且不空白」。
 */
class ShellPageDispatchCoverageTest {

    /** 目录里「应当点得进去」的条目（有渲染层、不需要外部图形或数据）。 */
    private fun enterableIds(): Set<String> =
        ShellPageCatalog.batches
            .flatMap { it.pages }
            .filter {
                it.kind == ShellPageDataKind.DIRECT || it.kind == ShellPageDataKind.DEMO
            }
            .map { it.id }
            .toSet()

    /** 目录里标着「暂不可用 / 常驻」的条目——这些**不该**有分派分支。 */
    private fun nonEnterableIds(): Set<String> =
        ShellPageCatalog.batches
            .flatMap { it.pages }
            .filter {
                it.kind == ShellPageDataKind.UNAVAILABLE ||
                    it.kind == ShellPageDataKind.ALWAYS_VISIBLE
            }
            .map { it.id }
            .toSet()

    /** 分派层里真的写了分支的 id（顺序 = 源码顺序）。 */
    private fun dispatchIds(): List<String> =
        DISPATCH_BRANCH.findAll(dispatchSource().readText(Charsets.UTF_8))
            .map { it.groupValues[1] }
            .toList()

    // ------------------------------------------------------------------ 守卫

    @Test
    fun `目录里每一条可进入的页面都有分派分支`() {
        val missing = (enterableIds() - dispatchIds().toSet()).sorted()
        assertEquals(
            "这些条目在目录里标着可进入，但 ShellPageIndex.kt 里没有对应分支——" +
                "用户点进去只会看到「页面缺失」：\n" +
                missing.joinToString("\n") { "  $it" },
            emptyList<String>(),
            missing,
        )
    }

    @Test
    fun `分派里的每个 id 都在目录里且标着可进入`() {
        val known = ShellPageCatalog.batches.flatMap { it.pages }.map { it.id }.toSet()
        val orphan = dispatchIds().filter { it !in known }.sorted()
        assertEquals(
            "这些分派分支的 id 在目录里不存在——这一页谁也点不到（等于没做）：\n" +
                orphan.joinToString("\n") { "  $it" },
            emptyList<String>(),
            orphan,
        )

        val blocked = dispatchIds().filter { it in nonEnterableIds() }.sorted()
        assertEquals(
            "这些 id 在目录里标着「暂不可用 / 常驻」，却已经有分派分支——" +
                "说明标注过时了，L4 清单会跟着骗人：\n" +
                blocked.joinToString("\n") { "  $it" },
            emptyList<String>(),
            blocked,
        )
    }

    @Test
    fun `分派里没有重复分支`() {
        // 同一个 id 写两遍时 Kotlin 只认第一条，第二条是死代码：
        // 改页面的人很可能改到不生效的那一条上。
        val dup = dispatchIds().groupingBy { it }.eachCount().filterValues { it > 1 }.keys
        assertEquals("这些 id 在分派层里出现了多次：$dup", emptySet<String>(), dup)
    }

    @Test
    fun `未知 id 有兜底分支而不是抛异常`() {
        // 目录与分派是两份数据，任何一次改动都可能短暂不一致；此时给一个
        // 「页面缺失」的兜底页，比让壳闪退好。这条钉住兜底分支还在。
        val source = dispatchSource().readText(Charsets.UTF_8)
        assertTrue(
            "ShellPageIndex.kt 的 when 必须有 else -> 兜底分支（未知 id 不该让壳崩）",
            Regex("""else\s*->""").containsMatchIn(source),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：文本解析若因格式变化失效（返回空清单），上面几条「零违规」
        // 会全部变绿——那比没有守卫更糟。这里把两个集合的下限钉住。
        val enterable = enterableIds()
        val dispatch = dispatchIds()
        assertTrue("目录里可进入的条目太少（${enterable.size}），解析或数据可能坏了", enterable.size >= 70)
        assertTrue("分派层解析出的分支太少（${dispatch.size}），正则可能失效了", dispatch.size >= 70)
        assertEquals(
            "两边条数应当相等（相等性由上面两条断言保证）",
            enterable.size,
            dispatch.toSet().size,
        )
    }

    // ------------------------------------------------------------------ 定位

    /**
     * 从工作目录向上找仓库根，再定位分派层源码。
     *
     * 与 `SettingsSpecTestSupport.ArbZh.findArb()` 同一套做法：L0 脚本与 Gradle
     * 的工作目录不同，所以按「向上找标志文件」而不是写死相对路径。
     */
    private fun dispatchSource(): File {
        val relative = "android/app/src/composeUi/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate
            dir = dir?.parentFile
        }
        error(
            "找不到 ShellPageIndex.kt（工作目录 ${File("").absolutePath}）；" +
                "路径若已移动，请同步本测试的 relative 常量",
        )
    }

    private companion object {
        /**
         * 分派分支：行首空白 + 引号 id + 箭头。
         *
         * id 允许驼峰（`b.settingsHome` 这类），所以字符集必须带 `A-Z`——
         * 2026-10-28 写这条守卫时第一版漏了 `A-Z`，75 条只解析出 29 条，
         * 差点把守卫本身写成永远绿。防空转那条断言就是为这种情况留的。
         */
        val DISPATCH_BRANCH = Regex("""^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->""", RegexOption.MULTILINE)
    }
}
