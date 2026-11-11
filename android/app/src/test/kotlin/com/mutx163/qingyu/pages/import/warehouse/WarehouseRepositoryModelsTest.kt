package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 仓库适配数据模型与列表计算单测。
 */
class WarehouseRepositoryModelsTest {

    @Test
    fun `WarehouseRepositorySource 宿主切换与有效属主路径测试`() {
        val source = WarehouseRepositorySource(
            owner = "Mutx163",
            repo = "qingyu_warehouse",
            gitcodeOwner = "mutx",
        )
        assertEquals("Mutx163", source.effectiveOwner)
        assertEquals("qingyu_warehouse", source.effectiveRepo)

        val gitcodeSource = source.withHost(WarehouseRepositoryHost.GITCODE)
        assertEquals(WarehouseRepositoryHost.GITCODE, gitcodeSource.host)
        assertEquals("mutx", gitcodeSource.effectiveOwner)
        assertEquals("qingyu_warehouse", gitcodeSource.effectiveRepo)
    }

    @Test
    fun `通用教务学校判定与首字母分组 Tag 规范测试`() {
        assertTrue(isGenericWarehouseSchool("正方通用教务"))
        assertTrue(isGenericWarehouseSchool("通用URP教务"))
        assertFalse(isGenericWarehouseSchool("清华大学"))
        assertFalse(isGenericWarehouseSchool("北京大学"))

        val genericSchool = WarehouseSchoolEntry(id = "zf_generic", name = "正方通用", initial = "Z")
        val normalSchool = WarehouseSchoolEntry(id = "pku", name = "北京大学", initial = "B")
        val noInitialSchool = WarehouseSchoolEntry(id = "none", name = "无首字母", initial = "")

        // 最近使用 -> ★
        assertEquals("★", warehouseSchoolTag(genericSchool, isRecent = true))
        assertEquals("★", warehouseSchoolTag(normalSchool, isRecent = true))

        // 通用 -> 通
        assertEquals("通", warehouseSchoolTag(genericSchool, isRecent = false))

        // 正常首字母大写
        assertEquals("B", warehouseSchoolTag(normalSchool, isRecent = false))
        assertEquals("#", warehouseSchoolTag(noInitialSchool, isRecent = false))
    }

    @Test
    fun `Tag 排序权重严格遵循 ★ - 通 - A-Z - #`() {
        val tags = listOf("#", "Z", "通", "A", "★", "B")
        val sorted = tags.sortedWith { left, right ->
            val rankComp = warehouseSchoolTagRank(left).compareTo(warehouseSchoolTagRank(right))
            if (rankComp != 0) rankComp else left.compareTo(right)
        }
        assertEquals(listOf("★", "通", "A", "B", "Z", "#"), sorted)
    }

    @Test
    fun `schoolsToBeans 与 schoolsToSections 保持正确顺序与分组`() {
        val s1 = WarehouseSchoolEntry(id = "s1", name = "清华大学", initial = "Q")
        val s2 = WarehouseSchoolEntry(id = "s2", name = "北京大学", initial = "B")
        val s3 = WarehouseSchoolEntry(id = "s3", name = "通用正方", initial = "T")
        val s4 = WarehouseSchoolEntry(id = "s4", name = "浙江大学", initial = "Z")

        val schools = listOf(s1, s2, s3, s4)
        val recentIds = listOf("s4")

        val beans = schoolsToBeans(schools, recentIds)
        assertEquals(4, beans.size)
        // 最近使用的 s4 在最前
        assertEquals("s4", beans[0].school.id)
        assertEquals("★", beans[0].tag)
        assertTrue(beans[0].isRecent)

        // 通用 s3 紧随其后
        assertEquals("s3", beans[1].school.id)
        assertEquals("通", beans[1].tag)

        // 其余常规学校
        assertEquals("s1", beans[2].school.id)
        assertEquals("s2", beans[3].school.id)

        val sections = schoolsToSections(beans)
        assertEquals(listOf("★", "通", "B", "Q"), sections.map { it.tag })
    }

    @Test
    fun `字母条几何尺寸计算与防溢出限制`() {
        val emptyGeom = warehouseIndexBarGeometry(0, 800.0)
        assertEquals(0.0, emptyGeom.height, 0.01)

        val geom = warehouseIndexBarGeometry(20, 500.0)
        assertTrue(geom.itemHeight >= WAREHOUSE_INDEX_BAR_MIN_ITEM_HEIGHT)
        assertTrue(geom.itemHeight <= K_INDEX_BAR_ITEM_HEIGHT)
        assertTrue(geom.height <= 500.0 * WAREHOUSE_INDEX_BAR_MAX_HEIGHT_RATIO + 0.1)
    }

    @Test
    fun `warehouseDocumentKey 统一小写并剔除 query 与 fragment`() {
        assertEquals(
            "https://jw.example.edu.cn/login",
            warehouseDocumentKey("https://jw.example.edu.cn/login?ticket=123#tab1")
        )
        assertEquals(
            "http://urp.school.cn/index.html",
            warehouseDocumentKey("HTTP://URP.school.cn/index.html")
        )
        assertEquals("not-a-valid-uri", warehouseDocumentKey("not-a-valid-uri"))
    }

    @Test
    fun `filterWarehouseSchools 关键字搜索支持学校属性与适配器关联搜索`() {
        val s1 = WarehouseSchoolEntry(id = "tsinghua", name = "清华大学", initial = "Q", province = "北京")
        val s2 = WarehouseSchoolEntry(id = "pku", name = "北京大学", initial = "B", province = "北京")
        val s3 = WarehouseSchoolEntry(id = "zju", name = "浙江大学", initial = "Z", province = "浙江")
        val all = listOf(s1, s2, s3)

        // 空搜索返回全量
        assertEquals(3, filterWarehouseSchools(all, "").size)

        // 搜名称
        assertEquals(listOf(s1), filterWarehouseSchools(all, "清华"))

        // 搜省份
        assertEquals(listOf(s1, s2), filterWarehouseSchools(all, "北京"))

        // 适配器索引匹配
        val adapterMatches = mapOf("zju" to listOf("浙大新教务"))
        val matchResult = filterWarehouseSchools(all, "新教务", adapterMatches = adapterMatches)
        assertEquals(listOf(s3), matchResult)
    }

    // P1-10（2026-11-11）：下面两条从 `infra/WarehouseInfraTest` 迁来——过滤函数真源
    // 已归本包（6 字段超集），infra 侧同名 4 字段版本删除。

    @Test
    fun `filterWarehouseSchools 命中名称 ID 首字母 资源目录 且空查询返回原表`() {
        val schools = listOf(
            WarehouseSchoolEntry("whu", "武汉大学", "W", "whu"),
            WarehouseSchoolEntry("hust", "华中科技大学", "H", "hust"),
        )
        assertEquals(listOf("whu"), filterWarehouseSchools(schools, "武汉").map { it.id })
        assertEquals(listOf("hust"), filterWarehouseSchools(schools, "HUST").map { it.id })
        assertEquals(listOf("whu"), filterWarehouseSchools(schools, "w").map { it.id })
        assertEquals(listOf("hust"), filterWarehouseSchools(schools, "hust").map { it.id })
        assertTrue(filterWarehouseSchools(schools, "不存在").isEmpty())
        assertSame("空查询必须原样返回入参表（不复制）", schools, filterWarehouseSchools(schools, "   "))
    }

    @Test
    fun `filterWarehouseSchools 学校字段不命中时可回退适配器命中`() {
        val schools = listOf(
            WarehouseSchoolEntry("whu", "武汉大学", "W", "whu"),
            WarehouseSchoolEntry("hust", "华中科技大学", "H", "hust"),
        )
        val matches = mapOf("hust" to listOf("WakeUp导入"))
        assertEquals(listOf("hust"), filterWarehouseSchools(schools, "wakeup", matches).map { it.id })
        assertTrue(filterWarehouseSchools(schools, "wakeup").isEmpty())
    }
}
