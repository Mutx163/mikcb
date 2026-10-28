package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 楼栋聚类逻辑测试（移植自 Dart `location_building_cluster_logic.dart`）。
 *
 * 期望值按 Dart 算法的**判据手推**（不是从实现里抄）：
 * - 字母+数字：`A1062` 的 `letterDigitPrefix` 命中 `A` + `1062`，`_splitBuildingDigits` 见
 *   「062」是 3 位教室号 → 楼栋只取首位 `1` ⇒ `A1`；`A1058 → A1`、`B201 → B2`。
 * - `A主201` 命中 `letterMainBuilding` ⇒ `A主`。
 * - `第六教学楼` 命中 `chineseTeachingBuilding`，序数「六」⇒ `六教`；显示名走 `chineseOrdinalDisplay` ⇒ `第六教学楼`。
 * - `西3-201` 命中 `cardinalGrid`（排在 numbered 之前）⇒ `西3`。
 * - `一教` ⇒ `一教`（中文序数，纯中文 → contains 模式）。
 * - `腾讯会议` 命中 `virtualPlatform` ⇒ `腾讯会议`（含「会议」→ contains 模式）。
 * - `测试教室01` 命中 `classroomLabel`，尾部教室号不并入标签 ⇒ `测试教室`。
 */
class LocationBuildingClusterModelTest {

    @Test
    fun `字母数字楼栋号只取楼栋位`() {
        assertEquals("A1", LocationBuildingClusterLogic.suggestKeywordFromLocation("A1062")?.pattern)
        assertEquals("A1", LocationBuildingClusterLogic.suggestKeywordFromLocation("A1058")?.pattern)
        assertEquals("B2", LocationBuildingClusterLogic.suggestKeywordFromLocation("B201")?.pattern)
    }

    @Test
    fun `A主与主教`() {
        assertEquals("A主", LocationBuildingClusterLogic.suggestKeywordFromLocation("A主201")?.pattern)
        assertEquals("主教", LocationBuildingClusterLogic.suggestKeywordFromLocation("主教学楼 302")?.pattern)
    }

    @Test
    fun `中文教学楼取序数`() {
        val kw = LocationBuildingClusterLogic.suggestKeywordFromLocation("第六教学楼")
        assertEquals("六教", kw?.pattern)
        // 纯中文 ⇒ contains 模式
        assertEquals(LocationKeywordMatchMode.CONTAINS, kw?.mode)
    }

    @Test
    fun `方位网格先于号栋`() {
        assertEquals("西3", LocationBuildingClusterLogic.suggestKeywordFromLocation("西3-201")?.pattern)
    }

    @Test
    fun `在线平台按会议识别为包含模式`() {
        val kw = LocationBuildingClusterLogic.suggestKeywordFromLocation("腾讯会议")
        assertEquals("腾讯会议", kw?.pattern)
        assertEquals(LocationKeywordMatchMode.CONTAINS, kw?.mode)
    }

    @Test
    fun `教室标签不并尾号`() {
        assertEquals("测试教室", LocationBuildingClusterLogic.suggestKeywordFromLocation("测试教室01")?.pattern)
    }

    @Test
    fun `空串返回null`() {
        assertNull(LocationBuildingClusterLogic.suggestKeywordFromLocation(null))
        assertNull(LocationBuildingClusterLogic.suggestKeywordFromLocation("   "))
    }

    @Test
    fun `聚类按地点数降序且样本去重排序`() {
        val clusters = LocationBuildingClusterLogic.clusterLocations(
            listOf("A1062", "A1058", "B201", "A1062"),
        )
        // A1 有 2 个样本；B2 有 1 个 → A1 在前
        assertEquals(listOf("A1", "B2"), clusters.map { it.buildingKey })
        assertEquals(listOf("A1058", "A1062"), clusters[0].sampleLocations)
        assertEquals(2, clusters[0].locationCount)
    }

    @Test
    fun `已覆盖楼栋从建议里剔除`() {
        val uncovered = LocationBuildingClusterLogic.uncoveredClusters(
            locations = listOf("A1062", "B201"),
            existingKeywords = listOf(LocationKeyword("A1", LocationKeywordMatchMode.PREFIX)),
        )
        assertEquals(listOf("B2"), uncovered.map { it.buildingKey })
    }

    @Test
    fun `显示名启发式`() {
        val clusters = LocationBuildingClusterLogic.clusterLocations(listOf("第六教学楼", "主教学楼"))
        val byKey = clusters.associateBy { it.buildingKey }
        assertEquals("第六教学楼", byKey["六教"]?.displayName)
        assertEquals("主教学楼", byKey["主教"]?.displayName)
        assertTrue(byKey.containsKey("六教"))
    }
}
