package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * BingWallpaperItem / BingWallpaperResolution：JSON 契约与 URL/文件名拼装。
 *
 * 期望值来源：[Dart抄录] test/models/bing_wallpaper_test.dart（含 2026-10-05
 * 实测响应形状）、[Dart抄录] test/utils/wallpaper_file_name_test.dart。
 *
 * 与 Dart 的差异口径：
 * - 不搬 WallpaperTargetSize 的「按屏幕取尺寸」运行时部分（那个依赖 Flutter
 *   PlatformDispatcher 视口，纯逻辑层拿不到）；[downloadTargetSize] 以
 *   显式屏幕参数传入，档位下限语义保持逐字一致。
 */
class BingWallpaperModelTest {

    // ---------- Resolution 档位 ----------

    @Test
    fun `three tiers are portrait with fixed keys`() { // [Dart抄录] 三档名字互不相同 + storageKey 往返
        assertEquals(listOf("standard", "tall", "high"), BingWallpaperResolution.entries.map { it.storageKey })
        for (value in BingWallpaperResolution.entries) {
            assertTrue("${value.storageKey} 不是竖屏", value.height > value.width)
        }
        for (value in BingWallpaperResolution.entries) {
            assertEquals(value, BingWallpaperResolution.fromStorageKey(value.storageKey))
        }
    }

    @Test
    fun `unknown storage key falls back to standard`() { // [Dart抄录] 未知键回退 standard（坏存档不炸读取方）
        assertEquals(BingWallpaperResolution.STANDARD, BingWallpaperResolution.fromStorageKey(null))
        assertEquals(BingWallpaperResolution.STANDARD, BingWallpaperResolution.fromStorageKey("future_tier"))
        assertEquals(BingWallpaperResolution.STANDARD, BingWallpaperResolution.fromStorageKey("native"))
    }

    @Test
    fun `standard is pregenerated and others resize`() { // [Dart抄录] 预生成档走尺寸后缀，resize 档 sizeSuffix 为 null
        assertEquals("_1080x1920.jpg", BingWallpaperResolution.STANDARD.sizeSuffix)
        assertNull(BingWallpaperResolution.TALL.sizeSuffix)
        assertNull(BingWallpaperResolution.HIGH.sizeSuffix)
    }

    @Test
    fun `size labels stay in kb`() { // [Dart抄录] 体积标签都是 KB 级
        assertEquals("322 KB", BingWallpaperResolution.STANDARD.approximateSizeLabel)
        assertEquals("492 KB", BingWallpaperResolution.TALL.approximateSizeLabel)
        assertEquals("764 KB", BingWallpaperResolution.HIGH.approximateSizeLabel)
        for (value in BingWallpaperResolution.entries) {
            assertTrue("${value.storageKey} 应该还是 KB 级", value.approximateSizeLabel.endsWith("KB"))
        }
    }

    @Test
    fun `high tier must be tall enough to avoid double upscale`() { // [Dart抄录] 顶档必须够高（≥3200）
        assertTrue(BingWallpaperResolution.HIGH.height >= 3200)
    }

    @Test
    fun `fallback walks one tier down`() { // [Dart抄录] 退档按枚举顺序退到紧邻的下一档
        assertNull(BingWallpaperResolution.STANDARD.fallbackResolution)
        assertEquals(BingWallpaperResolution.STANDARD, BingWallpaperResolution.TALL.fallbackResolution)
        assertEquals(BingWallpaperResolution.TALL, BingWallpaperResolution.HIGH.fallbackResolution)
    }

    @Test
    fun `download target size lifts tier floor above screen`() { // [Dart抄录] 实际请求尺寸 = 屏幕与档位下限取大者（2026-10-07）
        val screen = WallpaperTargetSize(1080, 2400)
        for (value in BingWallpaperResolution.entries) {
            val target = value.downloadTargetSize(screen)
            assertTrue("${value.storageKey}: 下载尺寸不得小于屏幕宽", target.width >= screen.width)
            assertTrue("${value.storageKey}: 下载尺寸不得小于屏幕高", target.height >= screen.height)
            assertTrue("${value.storageKey}: 档位下限不能丢", target.height >= value.height)
        }
        // 屏幕比档位还大 → 按屏幕比例抬到 3200 高（cover 瓶颈是高度）。
        val lifted = BingWallpaperResolution.HIGH.downloadTargetSize(WallpaperTargetSize(1080, 2400))
        assertTrue(lifted.height >= 3200)
        assertEquals(1080.0 / 2400.0, lifted.width.toDouble() / lifted.height, 0.01)
    }

    // ---------- WallpaperTargetSize（尺寸代数） ----------

    @Test
    fun `even alignment on derived sizes`() { // [Dart抄录] wallpaper_target_size_test：奇数对齐偶数
        assertEquals(1206, WallpaperTargetSize(1205, 2622).withWidth(1205).width)
        assertEquals(2622, WallpaperTargetSize(1206, 2621).withHeight(2621).height)
        assertEquals(1206, WallpaperTargetSize(1206, 2622).withWidth(1206).width)
        assertEquals(2622, WallpaperTargetSize(1206, 2622).withHeight(2622).height)
    }

    @Test
    fun `derive width from height keeps screen aspect`() { // [Dart抄录] 比例必须跟着屏幕走
        val taller = WallpaperTargetSize(1206, 2622).withHeight(3200)
        assertEquals(3200, taller.height)
        assertEquals(Math.round(3200 * 1206 / 2622.0), taller.width.toLong())
        assertEquals(1206.0 / 2622.0, taller.width.toDouble() / taller.height, 0.002)
    }

    @Test
    fun `derive height from width`() { // [Dart抄录]
        val wider = WallpaperTargetSize(1080, 1920).withWidth(1440)
        assertEquals(1440, wider.width)
        assertEquals(2560, wider.height)
    }

    @Test
    fun `atLeast keeps aspect and never below tier`() { // [Dart抄录] atLeast：档位是下限，但永远不小于屏幕
        val kept = WallpaperTargetSize(1080, 1920).atLeast(1440, 3200)
        assertTrue(kept.height >= 3200)
        assertEquals(1080.0 / 2400.0, WallpaperTargetSize(1080, 2400).atLeast(1440, 3200).let { it.width.toDouble() / it.height }, 0.01)
        val target = WallpaperTargetSize(1440, 3200)
        assertEquals(target, target.atLeast(1080, 1920))
        assertEquals(target, target.atLeast(1440, 3200))
    }

    @Test
    fun `target size equality is by value`() { // [Dart抄录] 相等判定按值 —— 台账键与文件名都靠它
        assertEquals(WallpaperTargetSize(1206, 2622), WallpaperTargetSize(1206, 2622))
        assertEquals(WallpaperTargetSize(1206, 2622).hashCode(), WallpaperTargetSize(1206, 2622).hashCode())
        assertTrue(WallpaperTargetSize(1206, 2622) != WallpaperTargetSize(1204, 2620))
    }

    // ---------- URL 拼装 ----------

    private val item = BingWallpaperItem(
        dateKey = "20261005",
        urlBase = "/th?id=OHR.AdelieTeacher_EN-US5343194378",
        title = "Taking the plunge, one lesson at a time",
        copyright = "阿德利企鹅，南极洲",
    )

    @Test
    fun `pregenerated tier uses size suffix`() { // [Dart抄录] 预生成档：绝对化基址 + 尺寸后缀
        assertEquals(
            "https://www.bing.com/th?id=OHR.AdelieTeacher_EN-US5343194378_1080x1920.jpg",
            item.fullUrl(BingWallpaperResolution.STANDARD),
        )
        assertTrue(item.fullUrl(BingWallpaperResolution.HIGH).contains("_UHD.jpg"))
    }

    @Test
    fun `resize tier carries c=4 and qlt=95`() { // [Dart抄录] resize 档走 w/h 接口且必须带 c=4
        val url = item.fullUrl(BingWallpaperResolution.TALL)
        assertTrue(url.contains("w=1080"))
        assertTrue(url.contains("h=2400"))
        assertTrue("缺 c=4 会得到白边图，不是裁切图", url.contains("c=4"))
        assertTrue("原图必须带质量参数（2026-10-14）", url.contains("qlt=95"))
        assertTrue(url.contains("id=OHR.AdelieTeacher_EN-US5343194378_UHD.jpg"))
        assertTrue(!url.contains("id=/th"))

        val high = item.fullUrl(BingWallpaperResolution.HIGH)
        assertTrue(high.contains("w=1440"))
        assertTrue(high.contains("h=3200"))
        assertTrue(high.contains("c=4"))
        assertTrue(high.contains("qlt=95"))
    }

    @Test
    fun `thumbnail keeps qlt off and portrait ratio`() { // [Dart抄录] 原图带 qlt=95、缩略图不带（480×854 竖屏）
        val thumb = item.thumbnailUrl()
        assertTrue(item.fullUrl(BingWallpaperResolution.HIGH).contains("qlt=95"))
        assertTrue("缩略图走默认压缩，8 张的流量不值得翻倍", !thumb.contains("qlt"))
        assertTrue(thumb.contains("w=480"))
        assertTrue(thumb.contains("h=854"))
        assertTrue(thumb.contains("c=4"))
        assertTrue("id 必须是纯图片 id + _UHD.jpg", thumb.contains("id=OHR.AdelieTeacher_EN-US5343194378_UHD.jpg"))
        assertTrue("urlBase 里的 /th?id= 前缀不能进查询串", !thumb.contains("id=/th"))
        assertTrue(!thumb.contains("?id=?id="))
    }

    @Test
    fun `expected size matches full url contract`() { // [Dart抄录] expectedSizeFor 与 fullUrl 的口径一致
        val target = WallpaperTargetSize(1440, 3200)
        assertEquals(target, item.expectedSizeFor(BingWallpaperResolution.HIGH, target))
        assertEquals(
            WallpaperTargetSize(1080, 1920),
            item.expectedSizeFor(BingWallpaperResolution.STANDARD, null),
        )
        assertEquals(
            WallpaperTargetSize(1080, 1920),
            item.expectedSizeFor(BingWallpaperResolution.STANDARD, WallpaperTargetSize(800, 1600)),
        )
    }

    @Test
    fun `imageId strips the th id prefix`() { // [Dart抄录] imageId 剥掉 /th?id= 前缀
        assertEquals("OHR.AdelieTeacher_EN-US5343194378", item.imageId)
        assertEquals(
            "https://www.bing.com/th?id=OHR.AdelieTeacher_EN-US5343194378",
            item.absoluteUrlBase,
        )
    }

    @Test
    fun `absolute urlbase also strips cleanly`() { // [Dart抄录] 已是绝对地址的 urlBase 也要能剥出纯 id
        val absolute = BingWallpaperItem(
            dateKey = "20261005",
            urlBase = "https://www.bing.com/th?id=OHR.X_EN-US1",
            title = "",
            copyright = "",
        )
        assertEquals(
            "https://www.bing.com/th?id=OHR.X_EN-US1_1080x1920.jpg",
            absolute.fullUrl(BingWallpaperResolution.STANDARD),
        )
        assertEquals("OHR.X_EN-US1", absolute.imageId)
        assertTrue(absolute.thumbnailUrl().contains("id=OHR.X_EN-US1_UHD.jpg"))
    }

    @Test
    fun `bigger target than pregenerated tier falls back to resize`() { // [Dart抄录] 预生成尺寸比目标小，用它就是主动降级
        val url0 = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X_EN-US1", title = "", copyright = "")
        val url = url0.fullUrl(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1206, 2622))
        assertTrue(url.contains("w=1206"))
        assertTrue(url.contains("h=2622"))
        assertTrue(url.contains("c=4"))
        assertTrue(!url.contains("_1080x1920.jpg"))
        // 目标与预生成档同大小时仍走后缀。
        assertTrue(
            url0.fullUrl(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920))
                .contains("_1080x1920.jpg"),
        )
    }

    // ---------- 文件名 ----------

    @Test
    fun `file name starts with wallpaper prefix`() { // [Dart抄录] 前缀必须是 wallpaper（删除守卫按它判归属）
        for (resolution in BingWallpaperResolution.entries) {
            val name = item.fileName(resolution, WallpaperTargetSize(1080, 1920))
            assertTrue(name.startsWith("wallpaper"))
            assertTrue(name.endsWith(".jpg"))
        }
        assertEquals(
            "wallpaper_bing_20261005_standard.jpg",
            item.fileName(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)),
        )
    }

    @Test
    fun `actual size joins file name only when it differs`() { // [Dart抄录] fileName：实际尺寸与档位默认不同时写进名字
        val entry = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X_EN-US1", title = "", copyright = "")
        assertEquals(
            "wallpaper_bing_20261005_standard.jpg",
            entry.fileName(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)),
        )
        assertEquals(
            "wallpaper_bing_20261005_standard_1206x2622.jpg",
            entry.fileName(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1206, 2622)),
        )
    }

    @Test
    fun `same day same tier lands on the same file name`() { // [Dart抄录] 同一天同一档位落在同一个文件名上（重复下载直接覆盖）
        assertEquals(
            item.fileName(BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
            item.fileName(BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
        )
        assertTrue(
            item.fileName(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)) !=
                item.fileName(BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
        )
    }

    // ---------- 文件名净化（wallpaper_file_name.dart） ----------

    @Test
    fun `real ids pass through unchanged`() { // [Dart抄录] wallpaper_file_name_test：真实数据一字不变
        for (id in listOf("94x4z1", "aBcDe123", "ml6z1q", "2xm3d4", "p5v2jk")) {
            assertEquals(id, safeWallpaperNameSegment(id, "wh"))
        }
        for (d in listOf("2026-10-08", "2026-01-01", "20251231")) {
            assertEquals(d, safeWallpaperNameSegment(d, "day"))
        }
    }

    @Test
    fun `hostile inputs are sanitized`() { // [Dart抄录] 恶意输入：分隔符必须被消掉
        assertTrue(!safeWallpaperNameSegment("/../../planted.txt").contains("/"))
        assertTrue(!safeWallpaperNameSegment("..\\..\\evil").contains("\\"))
        assertEquals("item", safeWallpaperNameSegment(".."))
        assertEquals("item", safeWallpaperNameSegment("."))
        assertEquals("item", safeWallpaperNameSegment(""))
        assertTrue(safeWallpaperNameSegment("   ", "wh").isNotEmpty())
        assertTrue(safeWallpaperNameSegment("x".repeat(500)).length <= 48)
        val hostile = listOf(
            "/../../planted.txt",
            "../../shared_prefs/wallpaper_x",
            "..\\..\\evil",
            "a/b",
            "a\\b",
            "..",
            ".",
            "",
            "   ",
            " ",
            "中文名",
            "x".repeat(500),
        )
        for (raw in hostile) {
            val got = safeWallpaperNameSegment(raw)
            assertTrue(
                "净化后仍含路径语义: $raw → $got",
                !got.contains("/") && !got.contains("\\") && got != "." && got != "..",
            )
            assertTrue("不该产出空文件名", got.isNotEmpty())
        }
    }

    @Test
    fun `segment truncates to 48 chars`() { // [Dart抄录] 超长输入被截断到安全长度
        assertEquals(48, safeWallpaperNameSegment("y".repeat(100)).length)
    }

    // ---------- JSON 契约 ----------

    @Test
    fun `item json round trip`() { // [Dart抄录] 往返无损
        val json = item.toJson()
        assertEquals(item, BingWallpaperItem.fromJson(MiniJson.parse(MiniJson.encode(json))))
    }

    @Test
    fun `bad entries are dropped one by one`() { // [Dart抄录] 缺 urlbase / startdate / 类型不对的条目逐条丢弃
        val items = BingWallpaperItem.listFromJson(
            listOf(
                linkedMapOf<Any?, Any?>("urlbase" to "/th?id=A", "startdate" to "20261005"),
                linkedMapOf<Any?, Any?>("startdate" to "20261005"),
                linkedMapOf<Any?, Any?>("urlbase" to "/th?id=B"),
                linkedMapOf<Any?, Any?>("urlbase" to 42, "startdate" to "20261005"),
                linkedMapOf<Any?, Any?>("urlbase" to "   ", "startdate" to "20261005"),
                "not-a-map",
                linkedMapOf<Any?, Any?>("urlbase" to "/th?id=C", "startdate" to "20261004"),
            ),
        )
        assertEquals(listOf("20261005", "20261004"), items.map { it.dateKey })
    }

    @Test
    fun `title and copyright degrade to empty string`() { // [Dart抄录] title/copyright 缺失或类型不对时留空串
        val parsed = BingWallpaperItem.fromJson(
            linkedMapOf<Any?, Any?>(
                "urlbase" to "/th?id=A",
                "startdate" to "20261005",
                "title" to 123L,
            ),
        )
        assertEquals("", parsed!!.title)
        assertEquals("", parsed.copyright)
    }

    @Test
    fun `non list input yields empty list`() { // [Dart抄录]
        assertEquals(emptyList<BingWallpaperItem>(), BingWallpaperItem.listFromJson(null))
        assertEquals(emptyList<BingWallpaperItem>(), BingWallpaperItem.listFromJson(emptyMap<Any?, Any?>()))
    }

    @Test
    fun `real bing response shape parses`() { // [Dart抄录] 解析 Bing 真实响应的形状（format=js 是标准 JSON）
        val payload = """
            {"images":[{"startdate":"20261005","fullstartdate":"202610050700",
            "enddate":"20261006","url":"/th?id=OHR.AdelieTeacher_EN-US5343194378_1920x1080.jpg&rf=LaDigue_1920x1080.jpg&pid=hp",
            "urlbase":"/th?id=OHR.AdelieTeacher_EN-US5343194378",
            "copyright":"阿德利企鹅，南极洲 (? Otto Plantema/Minden Pictures)",
            "copyrightlink":"https://www.bing.com/search?q=x","title":"Taking the plunge"}]}
        """.trimIndent()
        val decoded = MiniJson.parse(payload) as Map<*, *>
        val items = BingWallpaperItem.listFromJson(decoded["images"])
        assertEquals(1, items.size)
        assertEquals("20261005", items[0].dateKey)
        assertEquals("/th?id=OHR.AdelieTeacher_EN-US5343194378", items[0].urlBase)
        assertEquals("Taking the plunge", items[0].title)
    }

    @Test
    fun `json accepts both key spellings`() { // [Dart推演] 接口叫 urlbase/startdate，缓存叫 urlBase/dateKey，两套都要认
        val fromApi = BingWallpaperItem.fromJson(
            linkedMapOf<Any?, Any?>("urlbase" to "/th?id=A", "startdate" to "20261005"),
        )
        val fromCache = BingWallpaperItem.fromJson(
            linkedMapOf<Any?, Any?>("urlBase" to "/th?id=A", "dateKey" to "20261005"),
        )
        assertEquals(fromApi, fromCache)
    }
}
