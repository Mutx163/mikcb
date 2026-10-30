package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 图库清单数据源（`BingGalleryDataSource`）。
 *
 * 期望值来源：Dart `lib/services/bing_wallpaper_service.dart:159` / `:193-202`（`n=8`、
 * `mkt=zh-CN`）+ 接口真实响应形状（见 `weather/BingWallpaperModelTest` 里那份样本）。
 *
 * 这一层今天补的是「屏幕上永远转圈」的根因：壳传的是 `BingGalleryState()` 默认构造，
 * 没有任何东西把接口字节喂进 `items`。所以这里的断言钉的是**喂进去的那一步**。
 */
class BingGallerySourceTest {

    private class FakeHttp(private val body: String?) : BingGalleryHttp {
        var lastUrl: String? = null
        override fun get(url: String): String? {
            lastUrl = url
            return body
        }
    }

    private val twoDays = """
        {"images":[
          {"startdate":"20261005","fullstartdate":"202610050700",
           "urlbase":"/th?id=OHR.AdelieTeacher_ZH-CN5343194378",
           "title":"阿德利企鹅","copyright":"阿德利企鹅，南极洲 (© Martin Bailey)"},
          {"startdate":"20261004","fullstartdate":"202610040700",
           "urlbase":"/th?id=OHR.SaltFlats_ZH-CN1234567890",
           "title":"盐沼","copyright":"乌尤尼盐沼，玻利维亚"}
        ]}
    """.trimIndent()

    @Test
    fun `正常响应解析出条目`() {
        val items = BingGalleryDataSource.parse(twoDays)
        assertEquals(2, items.size)
        assertEquals("20261005", items[0].dateKey)
        assertEquals("/th?id=OHR.AdelieTeacher_ZH-CN5343194378", items[0].urlBase)
        assertEquals("阿德利企鹅", items[0].title)
        assertEquals("乌尤尼盐沼，玻利维亚", items[1].copyright)
    }

    @Test
    fun `body 为 null 返回空表而不是抛异常`() {
        assertEquals(emptyList<Any>(), BingGalleryDataSource.parse(null))
    }

    @Test
    fun `不是 JSON 返回空表`() {
        assertEquals(emptyList<Any>(), BingGalleryDataSource.parse("<html>403</html>"))
    }

    @Test
    fun `没有 images 字段返回空表`() {
        assertEquals(emptyList<Any>(), BingGalleryDataSource.parse("""{"tooltips":{}}"""))
    }

    @Test
    fun `缺 startdate 或 urlbase 的条目被丢弃`() {
        val body = """
            {"images":[
              {"startdate":"20261005","urlbase":"/th?id=OHR.A_ZH-CN1"},
              {"urlbase":"/th?id=OHR.B_ZH-CN2"},
              {"startdate":"20261003"},
              {"startdate":"20261002","urlbase":""}
            ]}
        """.trimIndent()
        val items = BingGalleryDataSource.parse(body)
        assertEquals(1, items.size)
        assertEquals("20261005", items[0].dateKey)
    }

    @Test
    fun `重复 dateKey 只留第一条`() {
        val body = """
            {"images":[
              {"startdate":"20261005","urlbase":"/th?id=OHR.A_ZH-CN1","copyright":"甲"},
              {"startdate":"20261005","urlbase":"/th?id=OHR.A_ZH-CN1","copyright":"乙"}
            ]}
        """.trimIndent()
        val items = BingGalleryDataSource.parse(body)
        assertEquals(1, items.size)
        assertEquals("甲", items[0].copyright)
    }

    @Test
    fun `超过 8 天只取前 8 条`() {
        val entries = (1..11).joinToString(",") { day ->
            val key = "2026100${day.toString().padStart(1, '0')}"
            """{"startdate":"${key}","urlbase":"/th?id=OHR.D${day}_ZH-CN$day"}"""
        }
        val items = BingGalleryDataSource.parse("""{"images":[$entries]}""")
        assertEquals(BING_GALLERY_DAYS, items.size)
        assertEquals(8, items.size)
    }

    @Test
    fun `fetch 打的是 8 天中文市场那一个接口`() {
        val http = FakeHttp(twoDays)
        val items = BingGalleryDataSource(http).fetch()
        assertEquals(2, items.size)
        val url = http.lastUrl.orEmpty()
        assertTrue("URL 应带 n=8：$url", url.contains("n=8"))
        assertTrue("URL 应带 mkt=zh-CN：$url", url.contains("mkt=zh-CN"))
        assertTrue("URL 应指向 HPImageArchive：$url", url.contains("HPImageArchive.aspx"))
    }

    @Test
    fun `http 拿不到正文时是空表（等于失败）`() {
        assertEquals(emptyList<Any>(), BingGalleryDataSource(FakeHttp(null)).fetch())
    }
}
