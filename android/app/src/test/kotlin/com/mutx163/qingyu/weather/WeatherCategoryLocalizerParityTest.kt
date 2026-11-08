package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 共享层天气现象标签逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * [WeatherCategoryLocalizer] 的中文是**照抄 ARB 的第二份副本**（第一份在
 * `pages.weather.WeatherStrings`，由 `WeatherStringsParityTest` 对拍）。共享层不能
 * 反向依赖页面域，所以副本 + 对拍是唯一防线：哪天 ARB 改了文案没同步这里，这条先红。
 */
class WeatherCategoryLocalizerParityTest {

    /** 现象分类 ↔ ARB 键的对应（与 `pages.weather.WeatherStrings` 的条目一一对应）。 */
    private val categoryToArbKey: List<Pair<WeatherCategory, String>> = listOf(
        WeatherCategory.CLEAR to "weatherClear",
        WeatherCategory.MAINLY_CLEAR to "weatherMainlyClear",
        WeatherCategory.PARTLY_CLOUDY to "weatherPartlyCloudy",
        WeatherCategory.OVERCAST to "weatherOvercast",
        WeatherCategory.FOG to "weatherFog",
        WeatherCategory.DRIZZLE to "weatherDrizzle",
        WeatherCategory.FREEZING_DRIZZLE to "weatherFreezingDrizzle",
        WeatherCategory.LIGHT_RAIN to "weatherLightRain",
        WeatherCategory.RAIN to "weatherRain",
        WeatherCategory.HEAVY_RAIN to "weatherHeavyRain",
        WeatherCategory.FREEZING_RAIN to "weatherFreezingRain",
        WeatherCategory.RAIN_SHOWERS to "weatherRainShowers",
        WeatherCategory.HEAVY_RAIN_SHOWERS to "weatherHeavyRainShowers",
        WeatherCategory.LIGHT_SNOW to "weatherLightSnow",
        WeatherCategory.SNOW to "weatherSnow",
        WeatherCategory.HEAVY_SNOW to "weatherHeavySnow",
        WeatherCategory.SNOW_GRAINS to "weatherSnowGrains",
        WeatherCategory.SNOW_SHOWERS to "weatherSnowShowers",
        WeatherCategory.THUNDERSTORM to "weatherThunderstorm",
        WeatherCategory.THUNDERSTORM_HAIL to "weatherThunderstormHail",
    )

    @Test
    fun `每个现象分类的标签都与 app_zh_arb 逐字一致`() {
        val arbMap = loadArbZh()
        assertEquals(
            "分类数与 ARB 键表数应一致（枚举加档时这里要同步）",
            WeatherCategory.entries.size,
            categoryToArbKey.size,
        )
        for ((category, key) in categoryToArbKey) {
            val template = arbMap[key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `$key`", template)
            assertEquals(
                "现象分类 $category 的标签与 ARB 键 `$key` 不一致",
                template,
                WeatherCategoryLocalizer.label(category),
            )
        }
    }

    @Test
    fun `守卫本身没有空转`() {
        val arbMap = loadArbZh()
        val covered = categoryToArbKey.count { arbMap.containsKey(it.second) }
        assertTrue("ARB 键覆盖太少（$covered），对拍可能形同虚设", covered >= 20)
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 i18n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
