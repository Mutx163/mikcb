package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 自定义脚本调试记录管理与验证单元测试。
 */
class WarehouseCustomDebugModelTest {

    @Test
    fun `调试记录合法性校验：名称与脚本文本必填`() {
        val blankName = WarehouseCustomDebugRecord(name = "   ", script = "console.log('hi');")
        assertEquals(WarehouseStrings.debugRecordNameRequired.key, blankName.validate())

        val blankScript = WarehouseCustomDebugRecord(name = "测试调试", script = "  ")
        assertEquals(WarehouseStrings.debugScriptRequired.key, blankScript.validate())

        val valid = WarehouseCustomDebugRecord(name = "测试调试", script = "console.log('ok');")
        assertNull(valid.validate())
        assertEquals(18, valid.scriptLength)
    }

    @Test
    fun `WarehouseCustomDebugManager 增删改查闭环测试`() {
        val manager = WarehouseCustomDebugManager()
        val rec1 = WarehouseCustomDebugRecord(id = "r1", name = "正方测试", script = "run();")
        val rec2 = WarehouseCustomDebugRecord(id = "r2", name = "青果测试", script = "fetch();")

        assertTrue(manager.addRecord(rec1))
        assertTrue(manager.addRecord(rec2))
        assertEquals(2, manager.records.size)

        // findById
        val found = manager.findById("r1")
        assertNotNull(found)
        assertEquals("正方测试", found?.name)

        // update
        val updatedRec1 = rec1.copy(name = "正方测试(已修改)")
        assertTrue(manager.updateRecord(updatedRec1))
        assertEquals("正方测试(已修改)", manager.findById("r1")?.name)

        // delete
        assertTrue(manager.deleteRecord("r1"))
        assertNull(manager.findById("r1"))
        assertEquals(1, manager.records.size)
    }
}
