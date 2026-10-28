package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 编辑页保存校验顺序测试（照 Dart `_save` :1032-1072）。
 *
 * 手推判据：四条错误按固定优先级返回第一条——
 * 组名空 > 未绑模板 > 无关键词 > 关键词被占用。
 */
class LocationTimeGroupEditorValidationTest {

    private val groups = listOf(
        LocationTimeGroup(
            id = "g1",
            name = "主教学楼",
            timeSchemeId = "s1",
            keywords = listOf(LocationKeyword("A1", LocationKeywordMatchMode.PREFIX)),
        ),
    )

    private fun model() = LocationTimeMatchModel(groups = groups, schemeNames = mapOf("s1" to "夏季作息"))

    @Test
    fun `组名为空优先报名称必填`() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model(), name = "  ", timeSchemeId = "s1",
            keywords = listOf(LocationKeyword("B2")), editingGroupId = null,
        )
        assertEquals(LocationTimeMatchStrings.nameRequired.zh, err)
    }

    @Test
    fun `组名有但没绑模板报需要模板`() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model(), name = "东区组", timeSchemeId = "",
            keywords = listOf(LocationKeyword("B2")), editingGroupId = null,
        )
        assertEquals(LocationTimeMatchStrings.needTimeScheme.zh, err)
    }

    @Test
    fun `没关键词报关键词必填`() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model(), name = "东区组", timeSchemeId = "s1",
            keywords = emptyList(), editingGroupId = null,
        )
        assertEquals(LocationTimeMatchStrings.keywordRequired.zh, err)
    }

    @Test
    fun `关键词被别的组占用`() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model(), name = "东区组", timeSchemeId = "s1",
            keywords = listOf(LocationKeyword("A1")), editingGroupId = null,
        )
        assertEquals(LocationTimeMatchStrings.keywordUsedByGroup.filled("group", "主教学楼"), err)
    }

    @Test
    fun `编辑自己时本组关键词不算冲突`() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model(), name = "主教学楼改", timeSchemeId = "s1",
            keywords = listOf(LocationKeyword("A1")), editingGroupId = "g1",
        )
        assertNull(err)
    }

    @Test
    fun `全部合法返回null`() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model(), name = "东区组", timeSchemeId = "s1",
            keywords = listOf(LocationKeyword("B2", LocationKeywordMatchMode.PREFIX)), editingGroupId = null,
        )
        assertNull(err)
    }
}
