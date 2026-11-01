package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F28：登录地址链路（适配器 `import_url` → 登录页）的 JVM 单测。
 *
 * 派工大表 I2 的缺口是「壳里拿不到真实登录地址」。这里钉住三段纯逻辑：
 * 1. 没自定义地址时**必须**用仓库声明的 `import_url`；
 * 2. 用户手填的合法地址优先，且能区分来源（页面据此提示「当前使用你手动覆盖的登录地址」）；
 * 3. 两个地址都不合法时回 `null`，调用方必须显示诚实空态，不许拿占位地址凑合。
 */
class WarehouseWebLoginTargetTest {

    private val adapter = WarehouseAdapterEntry(
        id = "zhengfang-v2",
        name = "正方新版",
        script = "zhengfang.js",
        importUrl = "https://jw.example.edu.cn/login",
    )

    @Test
    fun `没有自定义地址时使用适配器的 import_url`() {
        val target = resolveWarehouseWebLoginTarget(adapter, customImportUrl = null)

        assertEquals("https://jw.example.edu.cn/login", target?.loginUrl)
        assertEquals(false, target?.customOverride)
    }

    @Test
    fun `合法的自定义地址优先 且标记为覆盖`() {
        val target = resolveWarehouseWebLoginTarget(adapter, " https://jw2.example.edu.cn/ ")

        assertEquals("https://jw2.example.edu.cn/", target?.loginUrl)
        assertEquals(true, target?.customOverride)
    }

    @Test
    fun `自定义地址格式非法时回退到仓库地址 且不算覆盖`() {
        val target = resolveWarehouseWebLoginTarget(adapter, "not-a-url")

        assertEquals("https://jw.example.edu.cn/login", target?.loginUrl)
        assertEquals(false, target?.customOverride)
    }

    @Test
    fun `两个地址都不可用时回 null 不许造占位地址`() {
        val emptyAdapter = adapter.copy(importUrl = "")

        assertNull(resolveWarehouseWebLoginTarget(emptyAdapter, null))
        assertNull(resolveWarehouseWebLoginTarget(emptyAdapter, "javascript:alert(1)"))
    }

    @Test
    fun `没有选中适配器时回 null`() {
        assertNull(resolveWarehouseWebLoginTarget(null, "https://jw.example.edu.cn/"))
    }

    @Test
    fun `会话状态携带解析出的地址 阶段从 IDLE 起步`() {
        val target = resolveWarehouseWebLoginTarget(adapter, null)!!
        val session = initialWarehouseWebLoginSession(target)

        assertEquals("https://jw.example.edu.cn/login", session.currentUrl)
        assertEquals(WarehouseWebLoginStage.IDLE, session.stage)
        assertTrue(session.errorMessage == null)
    }
}
