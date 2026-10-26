package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * BingWallpaperLedger：下载台账的纯记账部分（键、去重、封顶、溢出、反序列化）。
 *
 * 期望值来源：[Dart抄录] test/services/bing_wallpaper_store_test.dart（剔除其中
 * prefs / 文件存在性的部分——那是 IO，不移植）。
 *
 * 移植取舍：Dart 的 BingWallpaperStore 是「SharedPreferences + 单例 + 记账」的
 * 混合体，Kotlin 侧只把**纯记账**抽成 [BingWallpaperLedger]（recordApplied 的
 * 键构造 / 去重置顶 / 封顶 / 溢出清单，以及 _DownloadedEntry 的 JSON 契约），
 * prefs 读写与文件存在性检查留给宿主层接线。
 */
class BingWallpaperLedgerTest {

    // ---------- 键构造 ----------

    @Test
    fun `ledger key includes date tier and size`() { // [Dart推演] makeKey: dateKey@storageKey@wxh
        assertEquals(
            "20261005@standard@1080x1920",
            BingWallpaperLedgerEntry.makeKey(
                dateKey = "20261005",
                resolution = BingWallpaperResolution.STANDARD,
                size = WallpaperTargetSize(1080, 1920),
            ),
        )
        assertEquals(
            "20261005@high@1440x3200",
            BingWallpaperLedgerEntry.makeKey(
                dateKey = "20261005",
                resolution = BingWallpaperResolution.HIGH,
                size = WallpaperTargetSize(1440, 3200),
            ),
        )
    }

    // ---------- 记账 / 复用 / 封顶 ----------

    @Test
    fun `record keeps newest first and dedups by key`() { // [Dart抄录] bing_wallpaper_store_test:291-304
        var ledger = BingWallpaperLedger()
        for (key in listOf("20261001", "20261002", "20261003")) {
            ledger = ledger.recordApplied(
                dateKey = key,
                resolution = BingWallpaperResolution.STANDARD,
                path = "/tmp/$key.jpg",
            ).ledger
        }
        assertEquals(
            listOf("/tmp/20261003.jpg", "/tmp/20261002.jpg", "/tmp/20261001.jpg"),
            ledger.downloadedPaths,
        )
    }

    @Test
    fun `same key recorded twice occupies one slot`() { // [Dart抄录] bing_wallpaper_store_test:175-187
        val ledger = BingWallpaperLedger()
        var current = ledger
        repeat(6) {
            val result = current.recordApplied(
                dateKey = "20261005",
                resolution = BingWallpaperResolution.STANDARD,
                path = "/tmp/wallpaper_bing_20261005_standard.jpg",
            )
            current = result.ledger
        }
        assertEquals(1, current.downloadedPaths.size) // 同键去重置顶（recordApplied 语义）
    }

    @Test
    fun `evicts only beyond cap and oldest first`() { // [Dart抄录] bing_wallpaper_store_test:157-173, 265-289
        val ledger = BingWallpaperLedger()
        var current = ledger
        val evicted = mutableListOf<String>()
        val total = MAX_DOWNLOADED_ENTRIES + 3
        for (i in 1..total) {
            val key = "2026" + i.toString().padStart(4, '0')
            val result = current.recordApplied(
                dateKey = key,
                resolution = BingWallpaperResolution.STANDARD,
                path = "/tmp/$key.jpg",
            )
            current = result.ledger
            evicted.addAll(result.evictedPaths)
        }
        assertEquals(3, evicted.size)
        assertEquals(MAX_DOWNLOADED_ENTRIES, current.downloadedPaths.size)
        // 淘汰最旧的：先记的 20260001..0003 三条被挤出
        assertEquals("/tmp/20260001.jpg", evicted.first())
    }

    @Test
    fun `eight days fit the cache without eviction`() { // [Dart抄录] bing_wallpaper_store_test:242-263（用户 2026-10-06 看过的图要能直接再打开）
        var current = BingWallpaperLedger()
        var anyEvicted: List<String>? = null
        for (day in 1..8) {
            val key = "2026100$day"
            val result = current.recordApplied(
                dateKey = key,
                resolution = BingWallpaperResolution.STANDARD,
                path = "/tmp/wallpaper_bing_${key}_standard.jpg",
            )
            current = result.ledger
            anyEvicted = result.evictedPaths
        }
        assertTrue("整个图库范围内的图都该留在缓存里", anyEvicted!!.isEmpty())
        assertEquals(8, current.downloadedPaths.size)
    }

    @Test
    fun `cap covers the visible gallery window`() { // [Dart抄录] bing_wallpaper_store_test:234-240
        assertTrue(MAX_DOWNLOADED_ENTRIES >= 8)
    }

    @Test
    fun `tier change is a different image`() { // [Dart抄录] bing_wallpaper_store_test:133-154 换档位就是换一张
        val ledger = BingWallpaperLedger().recordApplied(
            dateKey = "20261005",
            resolution = BingWallpaperResolution.STANDARD,
            path = "/tmp/standard.jpg",
        ).ledger
        assertEquals(
            "/tmp/standard.jpg",
            ledger.findExistingPath("20261005", BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)),
        )
        assertNull(
            "换档位就是换一张图，不能拿旧的顶替",
            ledger.findExistingPath("20261005", BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
        )
    }

    @Test
    fun `size mismatch forces a redownload`() { // [Dart推演] 2026-10-07 起尺寸进键：对不上就该重下
        val ledger = BingWallpaperLedger().recordApplied(
            dateKey = "20261005",
            resolution = BingWallpaperResolution.STANDARD,
            path = "/tmp/a.jpg",
            targetSize = WallpaperTargetSize(1080, 1920),
        ).ledger
        assertNull(
            ledger.findExistingPath("20261005", BingWallpaperResolution.STANDARD, WallpaperTargetSize(1206, 2622)),
        )
        assertEquals(
            "/tmp/a.jpg",
            ledger.findExistingPath("20261005", BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)),
        )
    }

    @Test
    fun `lastAutoAppliedDate only counts auto applies`() { // [Dart抄录] bing_wallpaper_store_test:46-68
        var ledger = BingWallpaperLedger().recordApplied(
            dateKey = "20261005",
            resolution = BingWallpaperResolution.STANDARD,
            path = "/tmp/wallpaper_bing_20261005_standard.jpg",
            autoApplied = false,
        ).ledger
        assertNull("手动挑的那张不算「自动换已完成」", ledger.lastAutoAppliedDate)
        ledger = ledger.recordApplied(
            dateKey = "20261004",
            resolution = BingWallpaperResolution.STANDARD,
            path = "/tmp/wallpaper_bing_20261004_standard.jpg",
        ).ledger
        assertEquals("20261004", ledger.lastAutoAppliedDate)
    }

    @Test
    fun `lastAutoAppliedDate returns the newest auto entry`() { // [Dart推演] 最新在前，第一个 autoApplied 命中
        val ledger = BingWallpaperLedger()
            .recordApplied(dateKey = "20261003", resolution = BingWallpaperResolution.STANDARD, path = "/tmp/a.jpg")
            .ledger
            .recordApplied(dateKey = "20261002", resolution = BingWallpaperResolution.STANDARD, path = "/tmp/b.jpg", autoApplied = false)
            .ledger
        assertEquals("20261003", ledger.lastAutoAppliedDate)
    }

    // ---------- JSON 契约 ----------

    @Test
    fun `entry json keys match dart`() { // [Dart推演] toJson 的键逐字一致
        val json = BingWallpaperLedgerEntry(
            dateKey = "20261005",
            resolution = BingWallpaperResolution.STANDARD,
            targetSize = WallpaperTargetSize(1080, 1920),
            path = "/tmp/a.jpg",
            autoApplied = true,
        ).toJson()
        assertEquals(
            listOf("dateKey", "resolution", "targetWidth", "targetHeight", "path", "autoApplied"),
            json.keys.toList(),
        )
        assertEquals("standard", json["resolution"])
        assertEquals(1080L, json["targetWidth"])
        assertEquals(1920L, json["targetHeight"])
    }

    @Test
    fun `entry json round trip`() { // [Dart推演]
        val entry = BingWallpaperLedgerEntry(
            dateKey = "20261005",
            resolution = BingWallpaperResolution.HIGH,
            targetSize = WallpaperTargetSize(1206, 2622),
            path = "/tmp/a.jpg",
            autoApplied = false,
        )
        val restored = BingWallpaperLedgerEntry.fromJson(MiniJson.parse(MiniJson.encode(entry.toJson())))
        assertEquals(entry, restored)
    }

    @Test
    fun `legacy entry without size falls back to tier default`() { // [Dart抄录] 旧存档没有尺寸字段 → 回退该档默认尺寸
        val restored = BingWallpaperLedgerEntry.fromJson(
            MiniJson.parse("""{"dateKey":"20261005","path":"/b","resolution":"standard","autoApplied":true}"""),
        )
        assertEquals(WallpaperTargetSize(1080, 1920), restored!!.targetSize)
        assertEquals("20261005", restored.dateKey)
        assertEquals("/b", restored.path)
        assertTrue(restored.autoApplied)
    }

    @Test
    fun `unknown tier string reads as standard`() { // [Dart抄录] bing_wallpaper_store_test:214-230
        val restored = BingWallpaperLedgerEntry.fromJson(
            MiniJson.parse("""{"dateKey":"20261005","path":"/x","resolution":"future_tier"}"""),
        )
        assertEquals(BingWallpaperResolution.STANDARD, restored!!.resolution)
        assertTrue("陌生档位的 autoApplied 缺省为 true", restored.autoApplied)
        assertEquals("20261005", ledgerOf(restored).lastAutoAppliedDate)
    }

    @Test
    fun `garbage entries are dropped one by one`() { // [Dart抄录] bing_wallpaper_store_test:201-212
        val ledger = BingWallpaperLedger.fromJsonList(
            MiniJson.parse(
                """[{"dateKey":123,"path":"/a"},""" +
                    """{"dateKey":"20261005","path":"/b","resolution":"standard","autoApplied":true},""" +
                    """"garbage"]""",
            ),
        )
        assertEquals("20261005", ledger.lastAutoAppliedDate)
        assertEquals(listOf("/b"), ledger.downloadedPaths)
    }

    @Test
    fun `whole corrupt payload reads as empty ledger`() { // [Dart抄录] bing_wallpaper_store_test:191-199
        val ledger = BingWallpaperLedger.fromJsonList(null)
        assertNull(ledger.lastAutoAppliedDate)
        assertTrue(ledger.downloadedPaths.isEmpty())
        val garbage = BingWallpaperLedger.fromJsonList(MiniJson.tryParse("{不是 json"))
        assertNull(garbage.lastAutoAppliedDate)
    }

    @Test
    fun `blank date or path is a bad entry`() { // [Dart推演] trim 后为空 = 脏条目
        assertNull(
            BingWallpaperLedgerEntry.fromJson(
                MiniJson.parse("""{"dateKey":"   ","path":"/a"}"""),
            ),
        )
        assertNull(
            BingWallpaperLedgerEntry.fromJson(
                MiniJson.parse("""{"dateKey":"20261005","path":"  "}"""),
            ),
        )
    }

    @Test
    fun `autoApplied non-bool defaults true`() { // [Dart推演] raw['autoApplied'] is bool ? : true
        val restored = BingWallpaperLedgerEntry.fromJson(
            MiniJson.parse("""{"dateKey":"20261005","path":"/a","autoApplied":"yes"}"""),
        )
        assertTrue(restored!!.autoApplied)
    }

    @Test
    fun `recordApplied keeps target size from explicit param`() { // [Dart推演] targetSize 缺省取该档默认尺寸
        val ledger = BingWallpaperLedger()
            .recordApplied(dateKey = "20261005", resolution = BingWallpaperResolution.TALL, path = "/tmp/a.jpg")
            .ledger
        assertEquals(
            WallpaperTargetSize(1080, 2400),
            ledger.entries[0].targetSize,
        )
    }

    private fun ledgerOf(entry: BingWallpaperLedgerEntry): BingWallpaperLedger =
        BingWallpaperLedger(listOf(entry))
}
