package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * LocationTimeGroup + LocationTimeMatchLogic 移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/models/location_time_group_test.dart；
 * - [Dart推演]：对照 lib/domain/location_time_match_logic.dart 实现逐行推演；
 * - [人推]：全角/空白/括号归一边界。
 */
class LocationTimeGroupTest {

    // ---------- LocationKeywordMatchMode [Dart抄录] ----------

    @Test
    fun matchMode_roundTripsAndDefaultsToPrefix() { // [Dart抄录]
        for (mode in LocationKeywordMatchMode.entries) {
            assertEquals(mode, LocationKeywordMatchMode.fromValue(mode.value))
            assertEquals(mode.name.lowercase(), mode.value)
        }
        assertEquals(LocationKeywordMatchMode.PREFIX, LocationKeywordMatchMode.fromValue("garbage"))
        assertEquals(LocationKeywordMatchMode.PREFIX, LocationKeywordMatchMode.fromValue(null))
    }

    // ---------- LocationKeyword [Dart抄录] ----------

    @Test
    fun keyword_roundTripsAndTrimsPattern() { // [Dart抄录]
        val keyword = LocationKeyword.fromJson(
            linkedMapOf("pattern" to "  A主  ", "mode" to "contains"),
        )
        assertEquals("A主", keyword.pattern)
        assertEquals(LocationKeywordMatchMode.CONTAINS, keyword.mode)

        val restored = LocationKeyword.fromJson(keyword.toJson())
        assertEquals(keyword, restored)
    }

    @Test
    fun keyword_copyAndEquality() { // [Dart抄录]
        val original = LocationKeyword("A1")
        val updated = original.copy(pattern = "A6", mode = LocationKeywordMatchMode.EXACT)
        assertEquals("A6", updated.pattern)
        assertEquals(LocationKeywordMatchMode.EXACT, updated.mode)
        assertEquals(LocationKeyword("A1"), original)
        assertFalse(original == updated)
    }

    // ---------- LocationTimeGroup [Dart抄录] ----------

    @Test
    fun group_roundTripsAndDropsEmptyKeywordPatterns() { // [Dart抄录]
        val original = LocationTimeGroup(
            id = "group-1",
            name = "  主教学楼  ",
            timeSchemeId = "scheme-main",
            enabled = false,
            priority = 3,
            keywords = listOf(
                LocationKeyword("A主"),
                LocationKeyword("主教", LocationKeywordMatchMode.CONTAINS),
            ),
        )
        val json = original.toJsonMap()
        @Suppress("UNCHECKED_CAST")
        val dirty = json.toMutableMap()
        dirty["keywords"] = (json["keywords"] as List<Any?>) +
            linkedMapOf<String, Any?>("pattern" to "   ", "mode" to "exact")

        val restored = LocationTimeGroup.fromJson(dirty)
        assertEquals("group-1", restored.id)
        assertEquals("主教学楼", restored.name)
        assertEquals("scheme-main", restored.timeSchemeId)
        assertFalse(restored.enabled)
        assertEquals(3, restored.priority)
        assertEquals(2, restored.keywords.size)
        assertEquals("A主", restored.keywords.first().pattern)
        assertEquals("A主, 主教", restored.keywordSummary)
    }

    @Test
    fun group_fromJsonDefaults() { // [Dart抄录]
        val restored = LocationTimeGroup.fromJson(
            linkedMapOf("id" to null, "name" to null, "timeSchemeId" to null),
        )
        assertEquals("", restored.id)
        assertEquals("", restored.name)
        assertEquals("", restored.timeSchemeId)
        assertTrue(restored.enabled)
        assertEquals(0, restored.priority)
        assertTrue(restored.keywords.isEmpty())
        assertEquals("", restored.keywordSummary)
    }

    @Test
    fun group_sourceSchoolId_toStringAndBlankToNull() { // [Dart抄录 location_time_group.dart:123-127]
        // 数字型来源校 ID toString 收下
        assertEquals(
            "42",
            LocationTimeGroup.fromJson(linkedMapOf("id" to "g", "sourceSchoolId" to 42)).sourceSchoolId,
        )
        // 空白 → null
        assertNull(
            LocationTimeGroup.fromJson(linkedMapOf("id" to "g", "sourceSchoolId" to "  ")).sourceSchoolId,
        )
        assertNull(
            LocationTimeGroup.fromJson(linkedMapOf("id" to "g", "sourceSchoolId" to null)).sourceSchoolId,
        )
        assertEquals(
            "sch-1",
            LocationTimeGroup.fromJson(linkedMapOf("id" to "g", "sourceSchoolId" to "sch-1")).sourceSchoolId,
        )
    }

    @Test
    fun group_jsonStringHelpersAndCopy() { // [Dart抄录]
        val original = LocationTimeGroup(
            id = "group-2",
            name = "实验楼",
            timeSchemeId = "scheme-lab",
            keywords = listOf(LocationKeyword("B1", LocationKeywordMatchMode.EXACT)),
        )
        val restored = LocationTimeGroup.fromJsonString(original.toJsonString())
        assertEquals(original.id, restored.id)
        assertEquals(LocationKeywordMatchMode.EXACT, restored.keywords.single().mode)

        val updated = original.copy(name = "新实验楼", priority = 9, enabled = false)
        assertEquals("新实验楼", updated.name)
        assertEquals(9, updated.priority)
        assertFalse(updated.enabled)
        assertEquals(original.timeSchemeId, updated.timeSchemeId)
    }

    // ---------- 归一化 [Dart推演 location_time_match_logic.dart:45-85] ----------

    @Test
    fun normalize_fullWidthToHalfWidth() {
        // 全角 A 与数字 → 半角
        assertEquals("a1062", LocationTimeMatchLogic.normalizeLocation("Ａ１０６２"))
        // 全角空格剔除、半角空格剔除
        assertEquals("测试教室01", LocationTimeMatchLogic.normalizeLocation("测试教室　01"))
        assertEquals("测试教室01", LocationTimeMatchLogic.normalizeLocation("测试教室 01"))
        // 破折号族 → '-'
        assertEquals("a-101", LocationTimeMatchLogic.normalizeLocation("A—101"))
        assertEquals("a-101", LocationTimeMatchLogic.normalizeLocation("A–101"))
        assertEquals("a-101", LocationTimeMatchLogic.normalizeLocation("A－101"))
        // 全角斜杠 → '/'
        assertEquals("a/b", LocationTimeMatchLogic.normalizeLocation("A／B"))
        // 中点剔除
        assertEquals("ab", LocationTimeMatchLogic.normalizeLocation("A·B"))
        assertEquals("ab", LocationTimeMatchLogic.normalizeLocation("A・B"))
        // 括号内容保留、括号本身剔除（≤12 字）：Dart replace 返回 match.group(1)
        assertEquals("东楼附201", LocationTimeMatchLogic.normalizeLocation("东楼（附）201"))
        assertEquals("东楼附201", LocationTimeMatchLogic.normalizeLocation("东楼(附)201"))
        // 大小写折叠
        assertEquals("a101", LocationTimeMatchLogic.normalizeLocation(" a101 "))
        // 空/空串
        assertEquals("", LocationTimeMatchLogic.normalizeLocation(null))
        assertEquals("", LocationTimeMatchLogic.normalizeLocation("   "))
    }

    // ---------- match [Dart抄录 providers/time_scheme_logic_test.dart + 推演] ----------

    @Test
    fun match_longerKeywordWins() { // [Dart推演 :117-136]
        val short = LocationTimeGroup(id = "g1", name = "G1", timeSchemeId = "s1", keywords = listOf(LocationKeyword("A")))
        val long = LocationTimeGroup(id = "g2", name = "G2", timeSchemeId = "s2", keywords = listOf(LocationKeyword("A10")))
        val result = LocationTimeMatchLogic.match("A1062", listOf(short, long))
        assertEquals("s2", result?.timeSchemeId)
        assertEquals("A10", result?.matchedKeyword?.pattern)
    }

    @Test
    fun match_equalLengthHigherPriorityWins() { // [Dart推演]
        val low = LocationTimeGroup(id = "g1", name = "G1", timeSchemeId = "s1", priority = 0, keywords = listOf(LocationKeyword("A1")))
        val high = LocationTimeGroup(id = "g2", name = "G2", timeSchemeId = "s2", priority = 5, keywords = listOf(LocationKeyword("A1")))
        assertEquals("s2", LocationTimeMatchLogic.match("A102", listOf(low, high))?.timeSchemeId)
    }

    @Test
    fun match_modes() { // [Dart推演 :157-170]
        val exact = LocationTimeGroup(id = "g", name = "g", timeSchemeId = "s", keywords = listOf(LocationKeyword("A101", LocationKeywordMatchMode.EXACT)))
        assertEquals("s", LocationTimeMatchLogic.match("A101", listOf(exact))?.timeSchemeId)
        assertNull(LocationTimeMatchLogic.match("A1012", listOf(exact)))
        val contains = LocationTimeGroup(id = "g", name = "g", timeSchemeId = "s", keywords = listOf(LocationKeyword("10", LocationKeywordMatchMode.CONTAINS)))
        assertEquals("s", LocationTimeMatchLogic.match("A1012", listOf(contains))?.timeSchemeId)
        val prefix = LocationTimeGroup(id = "g", name = "g", timeSchemeId = "s", keywords = listOf(LocationKeyword("A1")))
        assertEquals("s", LocationTimeMatchLogic.match("A1062", listOf(prefix))?.timeSchemeId)
        assertNull(LocationTimeMatchLogic.match("B1062", listOf(prefix)))
    }

    @Test
    fun match_disabledGroupsAndEmptySchemeIdSkipped() { // [Dart推演 :100-103]
        val disabled = LocationTimeGroup(id = "g1", name = "g1", timeSchemeId = "s1", enabled = false, keywords = listOf(LocationKeyword("A")))
        val emptyScheme = LocationTimeGroup(id = "g2", name = "g2", timeSchemeId = "", keywords = listOf(LocationKeyword("A")))
        assertNull(LocationTimeMatchLogic.match("A101", listOf(disabled, emptyScheme)))
    }

    @Test
    fun match_nullOrEmptyLocationReturnsNull() { // [Dart推演 :94-97]
        assertNull(LocationTimeMatchLogic.match(null, listOf(LocationTimeGroup(id = "g", name = "g", timeSchemeId = "s", keywords = listOf(LocationKeyword("A"))))))
        assertNull(LocationTimeMatchLogic.match("", emptyList()))
    }

    @Test
    fun match_normalizedLocationVsNormalizedPattern() { // [Dart推演] 全角位置能被半角关键词命中
        val group = LocationTimeGroup(id = "g", name = "g", timeSchemeId = "s", keywords = listOf(LocationKeyword("a1")))
        assertEquals("s", LocationTimeMatchLogic.match("Ａ１０６２", listOf(group))?.timeSchemeId)
    }

    // ---------- scheme 绑定判定 [Dart抄录 :173-188] ----------

    @Test
    fun schemeBinding_enabledVsAny() {
        val enabled = LocationTimeGroup(id = "g1", name = "g1", timeSchemeId = "s1", enabled = true)
        val disabled = LocationTimeGroup(id = "g2", name = "g2", timeSchemeId = "s1", enabled = false)
        val other = LocationTimeGroup(id = "g3", name = "g3", timeSchemeId = "s2", enabled = true)
        // 绑定（只算启用）
        assertTrue(LocationTimeMatchLogic.isSchemeBoundByGroups(listOf(enabled), "s1"))
        assertFalse(LocationTimeMatchLogic.isSchemeBoundByGroups(listOf(disabled), "s1"))
        // 引用（停用也算）
        assertTrue(LocationTimeMatchLogic.isSchemeReferencedByGroups(listOf(disabled), "s1"))
        assertFalse(LocationTimeMatchLogic.isSchemeReferencedByGroups(listOf(other), "s1"))
    }

    // ---------- pattern 归属 [Dart推演 :191-231] ----------

    @Test
    fun patternsOwnedByOtherGroups_excludesSelf() {
        val a = LocationTimeGroup(id = "a", name = "A", timeSchemeId = "s", keywords = listOf(LocationKeyword("A1")))
        val b = LocationTimeGroup(id = "b", name = "B", timeSchemeId = "s", keywords = listOf(LocationKeyword("B2"), LocationKeyword("  ")))
        val owned = LocationTimeMatchLogic.patternsOwnedByOtherGroups(listOf(a, b), excludingGroupId = "a")
        assertEquals(setOf("b2"), owned)
    }

    @Test
    fun groupNameOwningPattern_normalizesBeforeCompare() {
        val a = LocationTimeGroup(id = "a", name = "A", timeSchemeId = "s", keywords = listOf(LocationKeyword("A1")))
        assertEquals("A", LocationTimeMatchLogic.groupNameOwningPattern(listOf(a), "a1"))
        assertNull(LocationTimeMatchLogic.groupNameOwningPattern(listOf(a), "zzz"))
        assertNull(LocationTimeMatchLogic.groupNameOwningPattern(listOf(a), "  ")) // 空归一 → null
        assertEquals("A", LocationTimeMatchLogic.groupNameOwningPattern(listOf(a), "a1", excludingGroupId = "x"))
        assertNull(LocationTimeMatchLogic.groupNameOwningPattern(listOf(a), "a1", excludingGroupId = "a"))
    }

    @Test
    fun isLocationClaimedByOtherGroups_excludesSelf() { // [Dart推演 :237-247]
        val a = LocationTimeGroup(id = "a", name = "A", timeSchemeId = "s", keywords = listOf(LocationKeyword("A1")))
        val b = LocationTimeGroup(id = "b", name = "B", timeSchemeId = "s", keywords = listOf(LocationKeyword("B2")))
        assertTrue(LocationTimeMatchLogic.isLocationClaimedByOtherGroups("A101", listOf(a, b)))
        assertFalse(LocationTimeMatchLogic.isLocationClaimedByOtherGroups("A101", listOf(a, b), excludingGroupId = "a"))
        assertFalse(LocationTimeMatchLogic.isLocationClaimedByOtherGroups("C101", listOf(a, b)))
    }
}
