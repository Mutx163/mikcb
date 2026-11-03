package com.mutx163.qingyu.components

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 全站玻璃「单一实现」守卫（2026-11-03）。
 *
 * ## 用户口径
 *
 * 「同一个参数在两处应该是同一个效果」。要做到这点，必须保证：
 *
 * 1. 参数只在 [com.mutx163.qingyu.core.GlassSpecResolver] 里被解释一次；
 * 2. 模糊 / 折射 / backdrop 的调用点只有 [QingyuGlassSurface] 一处；
 * 3. 页面不得自己拼玻璃链，也不得自己 new 一份 [com.mutx163.qingyu.core.GlassSpec]。
 *
 * ## 白名单是「待接力清单」，不是豁免
 *
 * 课表域（周/日卡、顶栏带）与弹窗 fork 试验本轮按用户要求不碰，先登记在这里；
 * 迁移完成后**必须删掉对应行**，否则本条测试会红（过期必红，不许只进不出）。
 */
class GlassSingleChainGuardTest {

    private data class Pending(
        val path: String,
        val reason: String,
    )

    /** 玻璃链 API：出现即说明该文件自己拼了一层玻璃。 */
    private val glassChainApis = listOf(
        "drawBackdrop(",
        "progressiveTextureBlurEffect(",
        "textureBlurEffect(",
        "vibrancy(",
        "colorControls(",
        "lens(",
        "blur(",
    )

    /** 允许持有 miuix 调用的底层封装（共享件本体）。 */
    private val allowedOwners = listOf(
        "components/glass/QingyuGlassSurface.kt",
        "components/liquid/LiquidVibrancy.kt",
        "components/liquid/LiquidLens.kt",
        "components/liquid/LiquidCombinedBackdrop.kt",
    )

    /** 待接力：迁移完成后必须删行。 */
    private val pending: List<Pending> = listOf(
        Pending(
            "pages/shell/GlassDockNavigationBar.kt",
            "底栏坞：交互驱动折射/按压缩放，本轮未迁；下一批迁 QingyuGlassSurface",
        ),
        Pending(
            "components/BackToTodayFab.kt",
            "回今日/本周浮钮：本轮未迁；下一批迁 QingyuGlassSurface",
        ),
        Pending(
            "pages/timetable/CourseGridCard.kt",
            "周视图课卡：课表域在改，按用户要求本轮不碰",
        ),
        Pending(
            "pages/timetable/TimetableChromeBandGlass.kt",
            "课表顶栏玻璃带：课表域在改，按用户要求本轮不碰",
        ),
        Pending(
            "pages/timetable/day/DayAgendaSurface.kt",
            "日视图议程卡：课表域在改，按用户要求本轮不碰",
        ),
        Pending(
            "pages/timetable/TimetableWeekPage.kt",
            "周视图预糊采样层：课表域在改，按用户要求本轮不碰",
        ),
        Pending(
            "pages/timetable/day/DayViewPage.kt",
            "日视图预糊采样层：课表域在改，按用户要求本轮不碰",
        ),
        Pending(
            "pages/timetable/HomeFloatingChip.kt",
            "浮层胶囊：课表域在改，按用户要求本轮不碰",
        ),
        Pending(
            "pages/showcase/MiuixShowcaseGlassSection.kt",
            "showcase 演示页：官方 demo 形态，属演示豁免",
        ),
        Pending(
            "pages/settings/AppearanceEditorScreen.kt",
            "壁纸预览的 Modifier.blur（图像模糊，不是玻璃表面），不属于玻璃链",
        ),
        Pending(
            "pages/shell/HomeWallpaperBackdrop.kt",
            "壁纸预糊采样层（采样源构建，不是玻璃表面）；统一采样语义时一并收编",
        ),
    )

    private fun composeRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src/composeP1/kotlin/com/mutx163/qingyu")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src/composeP1/kotlin/com/mutx163/qingyu")
            if (direct.isDirectory) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 composeP1 源根 —— 守卫无法验证，按失败处理。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    private fun relativePath(file: File, root: File): String =
        file.absolutePath.removePrefix(root.absolutePath).trimStart('\\', '/').replace('\\', '/')

    private fun allKotlinFiles(root: File): List<File> =
        root.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()

    @Test
    fun `no file outside the shared glass surface builds its own glass chain`() {
        val root = composeRoot()
        val pendingPaths = pending.map { it.path }.toSet()
        val offenders = mutableListOf<String>()
        allKotlinFiles(root).forEach { file ->
            val relative = relativePath(file, root)
            if (relative in allowedOwners || relative in pendingPaths) return@forEach
            val code = codeOnly(file.readText())
            val hit = glassChainApis.firstOrNull { code.contains(it) }
            if (hit != null) offenders += "$relative -> $hit"
        }
        assertTrue(
            "这些文件绕过共享件自己拼玻璃链（应改用 QingyuGlassSurface）：$offenders",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `every pending entry still exists and is still a real offender`() {
        val root = composeRoot()
        val stale = pending.filter { entry ->
            val file = File(root, entry.path)
            if (!file.isFile) return@filter true
            val code = codeOnly(file.readText())
            glassChainApis.none { code.contains(it) }
        }
        assertTrue(
            "待接力清单已过期（文件已迁移或已删除），必须删掉这些行：${stale.map { it.path }}",
            stale.isEmpty(),
        )
    }

    @Test
    fun `GlassSpec is only constructed by the resolver`() {
        val root = composeRoot()
        val offenders = allKotlinFiles(root)
            .map { relativePath(it, root) to codeOnly(it.readText()) }
            .filter { (relative, code) ->
                relative !in listOf("core/GlassSurfaceSpec.kt") && code.contains("GlassSpec(")
            }
            .map { it.first }
        assertTrue(
            "不得在页面里自己拼 GlassSpec（必须走 GlassSpecResolver.resolve）：$offenders",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `pending entries carry a reason`() {
        assertTrue(
            "待接力清单每一项都必须写明原因，否则日后无法判断能否删",
            pending.all { it.reason.isNotBlank() },
        )
    }
}
