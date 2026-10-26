package com.mutx163.qingyu.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸「最近使用」历史的纯列表运算。
 *
 * 期望值来源：[Dart抄录] test/utils/wallpaper_history_test.dart（剔除其中摸盘的
 * 存在性判定——那是 IO，不移植）与 [Dart抄录] test/models/wallpaper_history_test.dart
 * （序列化口径）。
 *
 * 与 Dart 的差异：文件存在性（availableWallpaperHistory / wallpaperHistoryEntryAvailable /
 * settingsWithWallpaperHistoryEntry）依赖磁盘，属 IO 清单，不移植；本文件只钉
 * push / remove / batch / merge / deletable 五组纯函数。
 */
class WallpaperHistoryLogicTest {

    // ---------- pushWallpaperHistory ----------

    @Test
    fun `push prepends new entry with usedAt`() { // [Dart抄录] wallpaper_history_test:19-29
        val result = pushWallpaperHistory(
            history = listOf(WallpaperHistoryEntry(key = "/old.png")),
            key = "/new.png",
            usedAt = 123L,
        )
        assertEquals(listOf("/new.png", "/old.png"), result.history.map { it.key })
        assertEquals(123L, result.history[0].usedAt)
        assertTrue(result.evictedPaths.isEmpty())
    }

    @Test
    fun `push dedups by key and updates alignment`() { // [Dart抄录] wallpaper_history_test:31-45
        val result = pushWallpaperHistory(
            history = listOf(
                WallpaperHistoryEntry(key = "/a.png"),
                WallpaperHistoryEntry(key = "/b.png"),
            ),
            key = "/b.png",
            alignX = 0.5,
            alignY = -0.5,
        )
        assertEquals(listOf("/b.png", "/a.png"), result.history.map { it.key })
        assertEquals(0.5, result.history[0].alignX, 0.0)
        assertEquals(-0.5, result.history[0].alignY, 0.0)
    }

    @Test
    fun `blank key returns history untouched`() { // [Dart抄录] wallpaper_history_test:47-53
        val history = listOf(WallpaperHistoryEntry(key = "/a.png"))
        val result = pushWallpaperHistory(history = history, key = "   ")
        assertEquals(history, result.history)
        assertTrue(result.evictedPaths.isEmpty())
    }

    @Test
    fun `push evicts oldest beyond cap`() { // [Dart抄录] wallpaper_history_test:55-67
        var history = emptyList<WallpaperHistoryEntry>()
        repeat(MAX_WALLPAPER_HISTORY_ENTRIES) { i ->
            history = pushWallpaperHistory(history = history, key = "/img/$i.png").history
        }
        val result = pushWallpaperHistory(history = history, key = "/img/new.png")
        assertEquals(MAX_WALLPAPER_HISTORY_ENTRIES, result.history.size)
        assertEquals("/img/new.png", result.history.first().key)
        assertEquals("/img/1.png", result.history.last().key)
        assertEquals(listOf("/img/0.png"), result.evictedPaths)
    }

    @Test
    fun `legacy builtin entries are not deletable`() { // [Dart抄录] wallpaper_history_test:69-87
        var history = listOf(WallpaperHistoryEntry(key = "builtin:og"))
        repeat(MAX_WALLPAPER_HISTORY_ENTRIES - 1) { i ->
            history = pushWallpaperHistory(history = history, key = "/img/$i.png").history
        }
        val result = pushWallpaperHistory(history = history, key = "/img/new.png")
        assertEquals(MAX_WALLPAPER_HISTORY_ENTRIES, result.history.size)
        assertTrue("内置壁纸条目被顶出历史", result.history.none { it.key == "builtin:og" })
        assertTrue("它们没有磁盘文件，不得进待删清单", result.evictedPaths.isEmpty())
    }

    @Test
    fun `invalid old entries are filtered on push`() { // [Dart推演] push 时 history 里 isValid 为假的条目直接不进新历史
        val result = pushWallpaperHistory(
            history = listOf(
                WallpaperHistoryEntry(key = "   "), // 空 key = 无意义条目
                WallpaperHistoryEntry(key = "/a.png"),
            ),
            key = "/new.png",
        )
        assertEquals(listOf("/new.png", "/a.png"), result.history.map { it.key })
    }

    // ---------- removeWallpaperHistoryEntry ----------

    @Test
    fun `remove keeps order of the rest`() { // [Dart抄录] wallpaper_history_test:204-215
        val next = removeWallpaperHistoryEntry(
            listOf(
                WallpaperHistoryEntry(key = "/a.png"),
                WallpaperHistoryEntry(key = "/b.png"),
                WallpaperHistoryEntry(key = "/c.png"),
            ),
            "/b.png",
        )
        assertEquals(listOf("/a.png", "/c.png"), next.map { it.key })
    }

    @Test
    fun `remove is idempotent on missing or blank key`() { // [Dart抄录] wallpaper_history_test:217-234
        val history = listOf(WallpaperHistoryEntry(key = "/a.png"))
        assertTrue(removeWallpaperHistoryEntry(history, "/missing.png") === history)
        assertTrue(removeWallpaperHistoryEntry(history, "") === history)
        assertTrue(removeWallpaperHistoryEntry(history, "   ") === history)
    }

    @Test
    fun `remove trims but never normalizes the key`() { // [Dart抄录] wallpaper_history_test:236-253 只做首尾空白裁剪
        val history = listOf(WallpaperHistoryEntry(key = "/a/b.png"))
        assertTrue(removeWallpaperHistoryEntry(history, "  /a/b.png  ").isEmpty())
        assertTrue(removeWallpaperHistoryEntry(history, "\\a\\b.png") === history)
        assertTrue(removeWallpaperHistoryEntry(history, "/A/B.png") === history)
    }

    @Test
    fun `removing the last entry yields empty list`() { // [Dart抄录] wallpaper_history_test:255-259
        assertTrue(removeWallpaperHistoryEntry(listOf(WallpaperHistoryEntry(key = "/a.png")), "/a.png").isEmpty())
    }

    // ---------- rememberWallpaperHistoryBatch ----------

    @Test
    fun `batch appends old to new with newest first`() { // [Dart抄录] wallpaper_history_test:90-102
        val result = rememberWallpaperHistoryBatch(
            history = emptyList(),
            entries = listOf(
                WallpaperHistoryEntry(key = "/old.png", alignX = 0.2),
                WallpaperHistoryEntry(key = "/new.png", alignX = -0.2),
            ),
        )
        assertEquals(listOf("/new.png", "/old.png"), result.history.map { it.key })
        assertEquals(0.2, result.history.last().alignX, 0.0)
    }

    @Test
    fun `batch preserves scale and usedAt`() { // [Dart抄录] wallpaper_history_test:104-130（scale 丢失回归）
        val result = rememberWallpaperHistoryBatch(
            history = emptyList(),
            entries = listOf(
                WallpaperHistoryEntry(
                    key = "/zoom.png",
                    alignX = 0.3,
                    alignY = -0.4,
                    scale = 1.8,
                    usedAt = 1760000000000L,
                ),
            ),
        )
        val entry = result.history.single()
        assertEquals(0.3, entry.alignX, 0.0)
        assertEquals(-0.4, entry.alignY, 0.0)
        assertEquals(1760000000000L, entry.usedAt)
        assertEquals("连缩放一起还原是 scale 字段的承诺", 1.8, entry.scale, 0.0)
    }

    @Test
    fun `batch accumulates evicted paths`() { // [Dart抄录] wallpaper_history_test:132-148
        var history = emptyList<WallpaperHistoryEntry>()
        repeat(MAX_WALLPAPER_HISTORY_ENTRIES) { i ->
            history = pushWallpaperHistory(history = history, key = "/img/$i.png").history
        }
        val result = rememberWallpaperHistoryBatch(
            history = history,
            entries = listOf(
                WallpaperHistoryEntry(key = "/img/a.png"),
                WallpaperHistoryEntry(key = "/img/b.png"),
            ),
        )
        assertEquals(MAX_WALLPAPER_HISTORY_ENTRIES, result.history.size)
        assertEquals(listOf("/img/0.png", "/img/1.png"), result.evictedPaths)
    }

    @Test
    fun `re-added entry within batch is not evictable`() { // [Dart抄录] wallpaper_history_test:150-185（会删掉正在使用的壁纸）
        var history = emptyList<WallpaperHistoryEntry>()
        repeat(MAX_WALLPAPER_HISTORY_ENTRIES) { i ->
            history = pushWallpaperHistory(history = history, key = "/img/$i.png").history
        }
        val oldest = history.last()
        assertEquals("/img/0.png", oldest.key)
        val result = rememberWallpaperHistoryBatch(
            history = history,
            entries = listOf(
                WallpaperHistoryEntry(key = "/img/previous.png"),
                WallpaperHistoryEntry(key = oldest.key),
            ),
        )
        assertTrue("它已被第二条重新加回历史", result.history.any { it.key == oldest.key })
        assertTrue(
            "仍在历史里且正被引用的文件绝不能列入待删",
            !result.evictedPaths.contains(oldest.key),
        )
        assertEquals(listOf("/img/1.png"), result.evictedPaths)
    }

    @Test
    fun `batch skips invalid entries`() { // [Dart推演] entries 里 isValid 为假的跳过
        val result = rememberWallpaperHistoryBatch(
            history = emptyList(),
            entries = listOf(
                WallpaperHistoryEntry(key = "   "),
                WallpaperHistoryEntry(key = "/real.png"),
            ),
        )
        assertEquals(listOf("/real.png"), result.history.map { it.key })
    }

    // ---------- mergeWallpaperHistories ----------

    @Test
    fun `merge dedups by key keeping newer`() { // [Dart抄录] wallpaper_history_test:369-388
        val merged = mergeWallpaperHistories(
            listOf(
                listOf(
                    WallpaperHistoryEntry(key = "/old.png", alignX = 0.1, usedAt = 10L),
                    WallpaperHistoryEntry(key = "/shared.png", alignX = 0.2, usedAt = 20L),
                ),
                listOf(
                    WallpaperHistoryEntry(key = "/shared.png", alignX = 0.8, usedAt = 30L),
                    WallpaperHistoryEntry(key = "/new.png", usedAt = 40L),
                ),
            ),
        )
        assertEquals(listOf("/new.png", "/shared.png", "/old.png"), merged.map { it.key })
        assertEquals("同 key 取较新的那次对齐", 0.8, merged[1].alignX, 0.0)
    }

    @Test
    fun `both missing usedAt keeps the later one`() { // [Dart抄录] wallpaper_history_test:390-398
        val merged = mergeWallpaperHistories(
            listOf(
                listOf(WallpaperHistoryEntry(key = "/a.png", alignX = 0.1)),
                listOf(WallpaperHistoryEntry(key = "/a.png", alignX = 0.9)),
            ),
        )
        assertEquals(1, merged.size)
        assertEquals(0.9, merged.single().alignX, 0.0)
    }

    @Test
    fun `legacy entries sort after dated ones`() { // [Dart抄录] wallpaper_history_test:400-414
        val merged = mergeWallpaperHistories(
            listOf(
                listOf(
                    WallpaperHistoryEntry(key = "/legacy-b.png"),
                    WallpaperHistoryEntry(key = "/legacy-a.png"),
                ),
                listOf(WallpaperHistoryEntry(key = "/fresh.png", usedAt = 5L)),
            ),
        )
        assertEquals(listOf("/fresh.png", "/legacy-a.png", "/legacy-b.png"), merged.map { it.key })
    }

    @Test
    fun `merged union truncates to cap`() { // [Dart抄录] wallpaper_history_test:416-430
        val merged = mergeWallpaperHistories(
            listOf(
                (0 until MAX_WALLPAPER_HISTORY_ENTRIES).map { i ->
                    WallpaperHistoryEntry(key = "/a/$i.png", usedAt = i.toLong())
                },
                (0 until MAX_WALLPAPER_HISTORY_ENTRIES).map { i ->
                    WallpaperHistoryEntry(key = "/b/$i.png", usedAt = 100L + i)
                },
            ),
        )
        assertEquals(MAX_WALLPAPER_HISTORY_ENTRIES, merged.size)
        assertEquals("/b/${MAX_WALLPAPER_HISTORY_ENTRIES - 1}.png", merged.first().key)
    }

    // ---------- deletableWallpaperPaths ----------

    @Test
    fun `deletable skips empty and builtin keys`() { // [Dart抄录] wallpaper_history_test:344-353
        assertEquals(
            listOf("/img/keep.png"),
            deletableWallpaperPaths(listOf("", "builtin:ember_teal", "/img/keep.png")),
        )
    }

    @Test
    fun `deletable skips in-use paths`() { // [Dart抄录] wallpaper_history_test:356-366（2026-09-15 全局历史回归）
        assertEquals(
            listOf("/img/evicted.png"),
            deletableWallpaperPaths(
                listOf("/img/evicted.png", "/img/other-profile.png"),
                inUsePaths = setOf("/img/other-profile.png"),
            ),
        )
    }

    // ---------- 序列化 ----------

    @Test
    fun `entry json round trip with scale`() { // [Dart抄录] wallpaper_history_test:293-309
        val json = WallpaperHistoryEntry(key = "/tmp/a.png", alignX = 0.5, scale = 2.5).toJson()
        assertEquals(2.5, (json["scale"] as Double), 0.0)
        assertEquals(2.5, WallpaperHistoryEntry.fromJson(json)!!.scale, 0.0)
        // 存量存档没有 scale：缺省 1。
        val legacy = WallpaperHistoryEntry.fromJson(
            linkedMapOf<Any?, Any?>("key" to "/tmp/a.png", "alignX" to 0.5),
        )
        assertEquals(1.0, legacy!!.scale, 0.0)
        // 坏值不许冒泡，一律回退默认。
        assertEquals(
            1.0,
            WallpaperHistoryEntry.fromJson(
                linkedMapOf<Any?, Any?>("key" to "/tmp/a.png", "scale" to "big"),
            )!!.scale,
            0.0,
        )
    }

    @Test
    fun `entry from json drops garbage and invalid keys`() { // [Dart推演] listFromJson 逐条丢弃口径
        val entries = WallpaperHistoryEntry.listFromJson(
            listOf<Any?>(
                linkedMapOf<Any?, Any?>("key" to "/a.png", "alignX" to 0.5),
                linkedMapOf<Any?, Any?>("alignX" to 0.5), // 缺 key
                linkedMapOf<Any?, Any?>("key" to 42L), // key 类型不对
                "garbage",
                linkedMapOf<Any?, Any?>("key" to "   "), // 空 key = 无意义
                linkedMapOf<Any?, Any?>("key" to "/b.png", "usedAt" to 7L),
            ),
        )
        assertEquals(listOf("/a.png", "/b.png"), entries.map { it.key })
        assertEquals(7L, entries[1].usedAt)
    }

    @Test
    fun `entry listFromJson rejects non list`() { // [Dart推演]
        assertTrue(WallpaperHistoryEntry.listFromJson(null).isEmpty())
        assertTrue(WallpaperHistoryEntry.listFromJson("not a list").isEmpty())
    }

    @Test
    fun `usedAt accepts double like num toInt`() { // [Dart推演] Dart _numOrNull(...).toInt()：num 直接截断
        val entry = WallpaperHistoryEntry.fromJson(
            linkedMapOf<Any?, Any?>("key" to "/a.png", "usedAt" to 123.0),
        )
        assertEquals(123L, entry!!.usedAt)
    }
}
