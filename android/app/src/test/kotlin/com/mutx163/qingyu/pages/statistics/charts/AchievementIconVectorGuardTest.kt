package com.mutx163.qingyu.pages.statistics.charts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 渲染层「12 枚勋章图标两两不同」守卫（2026-11-04）。
 *
 * 模型层 `AchievementModel.iconOf` 的 12 个枚举已被 `StoryAchievementModelsTest` 钉住「两两不同」，
 * 但**枚举 → 具体 miuix 图标**这一层（`StoryAchievementCards.achievementIconVector`）原本没有守卫：
 * 若两个枚举映到同一个 `MiuixIcons.X`，模型测试仍绿、用户看到的还是「两枚一样」。
 * 本守卫用源码文本核对：`achievementIconVector` 的 12 个 `AchievementIcon.X -> MiuixIcons.Y`
 * 分支各映射到一个图标，且 12 个图标**互不相同**。
 *
 * 用文本而非 ImageVector 对象：避免 JVM 单测依赖 Compose 运行时；判据先剥注释。
 * 找不到源文件/函数**判失败而不是跳过**——跳过等于守卫不存在。
 */
class AchievementIconVectorGuardTest {

    private val expectedEnums = setOf(
        "SUN", "STAR", "TROPHY", "MEDAL", "BOOK", "BALANCE",
        "MOON", "COMPASS", "FIRE", "BUILDING", "SUNRISE", "TIMER",
    )

    @Test
    fun `12 个图标语义各映到一个互不相同的 miuix 图标`() {
        val pairs = parseMappings(cardsSource())
        assertEquals("应恰好 12 个 AchievementIcon→MiuixIcons 分支，实际 ${pairs.size}", 12, pairs.size)
        assertEquals(
            "12 个枚举必须与 AchievementIcon 定义一一对应（缺/多都算漂移）",
            expectedEnums,
            pairs.map { it.first }.toSet(),
        )
        val icons = pairs.map { it.second }
        assertEquals(
            "12 枚勋章图标必须两两不同，重复项：${icons.groupBy { it }.filterValues { it.size > 1 }}",
            12,
            icons.toSet().size,
        )
    }

    // 咬合探针（负例自测）：把两个枚举映到同一图标，distinct 判据必须变红。
    @Test
    fun `负例自测_两个枚举映到同一图标应判红`() {
        val real = cardsSource()
        assertTrue("真实源码应通过 distinct 判据", distinct12(real))
        val broken = real.replace(
            "AchievementIcon.STAR -> MiuixIcons.Ok",
            "AchievementIcon.STAR -> MiuixIcons.Alarm",
        )
        assertTrue("负例构造失败：没找到 `AchievementIcon.STAR -> MiuixIcons.Ok` 行", broken != real)
        assertFalse("把 STAR 改成和 SUN 同图标(Alarm)应判红（两枚同图标）", distinct12(broken))
    }

    private fun distinct12(src: String): Boolean {
        val pairs = parseMappings(src)
        return pairs.size == 12 &&
            pairs.map { it.first }.toSet() == expectedEnums &&
            pairs.map { it.second }.toSet().size == 12
    }

    /** 取 `achievementIconVector` 函数体里 `AchievementIcon.X -> MiuixIcons.Y` 的配对。 */
    private fun parseMappings(src: String): List<Pair<String, String>> {
        val code = codeOnly(src)
        val start = code.indexOf("fun achievementIconVector")
        assertTrue("找不到 fun achievementIconVector（改名/搬迁会让守卫失效）", start >= 0)
        val tail = code.substring(start)
        // 截到函数体第一个闭合花括号（when 体，无嵌套花括号），避免扫到后续代码。
        val close = tail.indexOf("\n}")
        val body = if (close >= 0) tail.substring(0, close) else tail
        return Regex("""AchievementIcon\.([A-Z]+)\s*->\s*MiuixIcons\.([A-Za-z]+)""")
            .findAll(body)
            .map { it.groupValues[1] to it.groupValues[2] }
            .toList()
    }

    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    private fun cardsSource(): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(
                dir,
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/charts/StoryAchievementCards.kt",
            )
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            val direct = File(
                dir,
                "app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/charts/StoryAchievementCards.kt",
            )
            if (direct.isFile) return direct.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        throw AssertionError("找不到 StoryAchievementCards.kt —— 守卫无法验证，按失败处理")
    }
}
