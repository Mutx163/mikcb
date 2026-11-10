package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.testutil.readSourceNormalized
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「圆钮必须消费 `glassDockButtonIconName`」守卫（2026-11-01 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 设置里 156 格图标选得好好的、也落盘了，首页圆钮却永远画默认加号：
 * 坞（`HomeGlassDock.kt`，2026-11-01 之前住在 `PagesShellActivity.kt`）拿的是
 * `HomeNavIcons.iconOf(roundActionId)`，从头到尾没读过 `glassDockButtonIconName`。
 * 「设置写了没人读」不会让编译失败，模型层单测也全绿——错的只有渲染点少接一根线。
 *
 * ## 为什么读源码文本
 *
 * 判据是「这个调用点传了哪个值」，Compose 调用在编译产物与反射里都不保留。
 * 与同目录的 `TaskWiringGuardTest` / `DiagnosticsWiringGuardTest` 同一套做法。
 * 另外，L0 轻量单测只把 `main/.../pages/shell` 收进 kotlinc，**收不到 `composeP1`
 * 与 miuix**，所以不能直接 `import` 渲染层的 [glassDockRoundButtonIcon] 来调用；
 * 读文本是这里唯一可跑的选择。
 *
 * ## 咬合探针（不产生第二次运行）
 *
 * 每个判据都写成「文本 → 布尔」的函数，并在同一用例里喂一份**故意改坏**的副本：
 * 删掉宿主传参、把 `byName` 换成恒 null、从矢量表删一个键……改坏后必须为假。
 * 这样探针本身随 L0 一次运行一起验证，不需要改真文件再跑第二遍。
 *
 * ## 前提
 *
 * 矢量表与清单必须一一对应（156 项）。哪天后人只给清单加名字、忘了补映射，
 * 「用户选中后圆钮仍是加号」会立刻复发，这里直接红。
 */
class GlassDockRoundButtonIconWiringGuardTest {

    // ---------------------------------------------------------------- 宿主接线

    @Test
    fun `宿主把设置里的图标名交给圆钮`() {
        // 2026-11-01 底栏搬进页面层：坞（含圆钮）由 `HomeGlassDock.kt` 画，
        // 壳不再自己拼这一块 —— 判据跟着搬到新文件，盯的还是同一件事。
        val dock = source(DOCK)
        assertTrue(
            "HomeGlassDock 的圆钮块没有把 `settingsModel.glassDockButtonIconName` " +
                "交给 `glassDockRoundButtonIcon(...)`——设置里选的图标就又被丢掉了",
            roundButtonUsesChosenIcon(dock),
        )
        // 反向探针：把传参删掉，判据必须红。
        assertFalse(
            "咬合探针失效：删掉 `glassDockButtonIconName` 后判据仍为真",
            roundButtonUsesChosenIcon(
                dock.replace("settingsModel.glassDockButtonIconName", "null"),
            ),
        )
        // 反向探针 2：绕开统一解析、退回只查目录图标，判据必须红。
        assertFalse(
            "咬合探针失效：把 `glassDockRoundButtonIcon(` 换成 `HomeNavIcons.iconOf(` 后判据仍为真",
            roundButtonUsesChosenIcon(
                dock.replace("glassDockRoundButtonIcon(", "HomeNavIcons.iconOf("),
            ),
        )
    }

    @Test
    fun `回首页会重读设置 不是只在进程重启后生效`() {
        val activity = stripLineComments(source(ACTIVITY))
        assertTrue(
            "PagesShellActivity 找不到「回到主屏重读设置」的效果——" +
                "设置页改完圆钮图标后，首页必须当场取到新值",
            reloadsSettingsOnRoot(activity),
        )
        assertFalse(
            "咬合探针失效：删掉 `load()` 调用后判据仍为真",
            reloadsSettingsOnRoot(
                activity.replace("wiring.settingsModel.load()", "wiring.settingsModel"),
            ),
        )
    }

    // ---------------------------------------------------------------- 解析顺序

    @Test
    fun `用户名字优先 查不到才回退绑定动作的图标`() {
        val bar = stripLineComments(source(NAV_BAR))
        val block = roundIconResolution(bar)
        assertTrue(
            "glassDockRoundButtonIcon 没有用 GlassDockIconVectors.byName 解析用户选的名字——" +
                "不许在渲染层另抄一份图标表",
            resolvesByNameThenFallsBack(block),
        )
        // 反向探针：删掉回退，未知名字就会变成空白/崩溃。
        assertFalse(
            "咬合探针失效：删掉 HomeNavIcons.iconOf 回退后判据仍为真",
            resolvesByNameThenFallsBack(
                block.replace("HomeNavIcons.iconOf(roundActionId)", "null"),
            ),
        )
        // 反向探针 2：把查表换成恒 null（等价于「映射改坏」）。
        assertFalse(
            "咬合探针失效：把 byName 换成 null 后判据仍为真",
            resolvesByNameThenFallsBack(
                block.replace("GlassDockIconVectors.byName(it)", "null"),
            ),
        )
        // 渲染文件整体不许出现图标表（`"add" to MiuixIcons.Add` 这种）。
        assertFalse(
            "GlassDockNavigationBar.kt 里出现了图标映射表——名字 → 矢量只能在 " +
                "GlassDockIconVectors 一处维护",
            Regex("""["'][A-Za-z0-9]+["']\s+to\s+MiuixIcons\.""").containsMatchIn(bar),
        )
    }

    // ---------------------------------------------------------------- 数据源

    @Test
    fun `清单里的每个名字都有矢量映射`() {
        val names = catalogNames(source(CATALOG))
        val keys = vectorKeys(stripLineComments(source(VECTORS)))
        assertEquals("图标清单应是 156 项", 156, names.size)
        assertEquals("清单与矢量表必须逐项对应，否则用户选中就会静默回退加号",
            names.toSet(), keys)
        // 反向探针：从矢量表删掉一个键，差集必须正好是它。
        val broken = keys - "home"
        assertEquals(
            "咬合探针失效：删掉 home 映射后没有报缺项",
            listOf("home"),
            (names.toSet() - broken).sorted(),
        )
    }

    @Test
    fun `byName 真的查表 不是恒返回 null`() {
        val text = stripLineComments(source(VECTORS))
        val lookup = Regex(
            """fun\s+byName\s*\([^)]*\)\s*:\s*ImageVector\?\s*=\s*ICONS\s*\[\s*name\s*]""",
        )
        assertTrue(
            "GlassDockIconVectors.byName 必须查 ICONS 表；恒返回 null 等于所有自定义图标都失效",
            lookup.containsMatchIn(text),
        )
        assertFalse(
            "咬合探针失效：把 `ICONS[name]` 换成 null 后判据仍为真",
            lookup.containsMatchIn(
                text.replace("= ICONS[name]", "= null"),
            ),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        val dock = source(DOCK)
        val bar = stripLineComments(source(NAV_BAR))
        val block = roundIconResolution(bar)
        // 文本定位一旦因格式化失效，上面几条「零违规」会全部变绿——比没有守卫更糟。
        assertTrue("解析出的坞圆钮块太短（${roundButtonBlock(dock).length} 字符）",
            roundButtonBlock(dock).length >= 80)
        assertTrue("解析出的图标解析函数太短（${block.length} 字符）",
            block.length >= 80)
        assertTrue("圆钮块里找不到 roundActionId", roundButtonBlock(dock).contains("roundActionId"))
    }

    // ------------------------------------------------------------------ 判据

    /** 宿主 `trailingContent` 块：必须读设置里的名字，并走统一解析函数。 */
    private fun roundButtonUsesChosenIcon(text: String): Boolean {
        val block = roundButtonBlock(text)
        return block.contains("settingsModel.glassDockButtonIconName") &&
            block.contains("glassDockRoundButtonIcon(") &&
            block.contains("roundActionId = roundActionId")
    }

    /** 圆钮块：从 `trailingContent = if (settingsModel.glassDockShowAddButton)` 起截一段。 */
    private fun roundButtonBlock(text: String): String {
        val marker = "trailingContent = if (settingsModel.glassDockShowAddButton)"
        val start = text.indexOf(marker)
        if (start < 0) return ""
        return text.substring(start, minOf(text.length, start + MAX_BLOCK_CHARS))
    }

    /** 回主屏重读设置：效果体里同时出现 `atRoot`、`settingsModel`、`load()`。 */
    private fun reloadsSettingsOnRoot(text: String): Boolean {
        val start = text.indexOf("LaunchedEffect(atRoot)")
        if (start < 0) return false
        val body = text.substring(start, minOf(text.length, start + MAX_BLOCK_CHARS))
        return body.contains("atRoot") && body.contains("settingsModel") &&
            body.contains("load()")
    }

    /**
     * 解析函数体：从 `fun glassDockRoundButtonIcon(` 到下一个空行（表达式体内部没有空行）。
     * KDoc 在 marker 之前，不会被收进来，避免注释里提到 `byName` 造成假阳性。
     */
    private fun roundIconResolution(text: String): String {
        val marker = "fun glassDockRoundButtonIcon("
        val start = text.indexOf(marker)
        if (start < 0) return ""
        val rest = text.substring(start)
        val end = rest.indexOf("\n\n")
        return if (end >= 0) rest.substring(0, end) else rest
    }

    /** 先后顺序 + 不许复制图标表：byName 在前、iconOf 回退在后。 */
    private fun resolvesByNameThenFallsBack(block: String): Boolean {
        val byName = block.indexOf("GlassDockIconVectors.byName(")
        val fallback = block.indexOf("HomeNavIcons.iconOf(roundActionId)")
        if (byName < 0 || fallback < 0 || byName > fallback) return false
        return "MiuixIcons." !in block && "linkedMapOf" !in block && "mapOf(" !in block
    }

    private fun catalogNames(catalogSource: String): List<String> {
        val block = catalogSource.substringAfter("listOf(", "").substringBefore(")", "")
        return Regex(""""([A-Za-z0-9]+)"""").findAll(block)
            .map { it.groupValues[1] }
            .toList()
    }

    private fun vectorKeys(vectorsSource: String): Set<String> =
        Regex("""["']([A-Za-z0-9]+)["']\s+to\s+MiuixIcons\.""")
            .findAll(vectorsSource)
            .map { it.groupValues[1] }
            .toSet()

    // ------------------------------------------------------------------ 定位

    /**
     * 从工作目录向上找仓库根，再读文件（**行尾已归一**：CRLF→LF）。
     *
     * 本仓工作区是 CRLF、索引是 LF；下面 `roundIconResolution()` 靠 `"\n\n"` 切函数体，
     * 不归一会把切点打空、整段吞到文件尾，判据随机红/绿。
     */
    private fun source(relativePath: String): String = readSourceNormalized(relativePath)

    /** 去掉 `//` 行注释，避免注释里解释「旧写法 `ICONS[name]`」被当成代码。 */
    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }

    private companion object {
        const val ACTIVITY =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"

        /** 坞（药丸 + 圆钮）的渲染点；2026-11-01 从壳搬到这里。 */
        const val DOCK =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/shell/HomeGlassDock.kt"
        const val NAV_BAR =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/shell/GlassDockNavigationBar.kt"
        const val VECTORS =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/GlassDockIconVectors.kt"
        const val CATALOG =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/GlassDockIconCatalog.kt"

        /** 圆钮块/效果体的截取上限（当前约 300~500 字符，留足余量）。 */
        const val MAX_BLOCK_CHARS = 1500
    }
}
