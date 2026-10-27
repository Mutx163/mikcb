package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 网页登录流程状态机与地址解析单元测试。
 */
class WarehouseWebLoginFlowStateTest {

    @Test
    fun `resolveWarehouseImportUrl 正确支持覆盖地址与缺省地址回退`() {
        val defaultUrl = "https://jw.school.edu.cn/login"
        val customUrl = "https://vpn.school.edu.cn/jw/login"

        // 有效自定义覆盖地址优先
        assertEquals(customUrl, resolveWarehouseImportUrl(customUrl, defaultUrl))

        // 自定义地址为空时回退默认地址
        assertEquals(defaultUrl, resolveWarehouseImportUrl(null, defaultUrl))
        assertEquals(defaultUrl, resolveWarehouseImportUrl("   ", defaultUrl))

        // 自定义地址协议非法（非 http/https）回退默认地址
        assertEquals(defaultUrl, resolveWarehouseImportUrl("ftp://files.org", defaultUrl))

        // 两者均无效时返回 null
        assertNull(resolveWarehouseImportUrl("not-valid-url", "also-not-valid"))
        assertNull(resolveWarehouseImportUrl("", ""))
    }

    @Test
    fun `WarehouseWebLoginSessionState 状态流转与弹窗条件自动计算`() {
        val initial = WarehouseWebLoginSessionState(
            currentUrl = "https://jw.school.edu.cn",
            stage = WarehouseWebLoginStage.LOADING,
        )

        // 推进到 LOADED
        val loaded = initial.withStage(WarehouseWebLoginStage.LOADED)
        assertEquals(WarehouseWebLoginStage.LOADED, loaded.stage)

        // 录制步骤自增
        val recorded = loaded.withStepRecorded().withStepRecorded()
        assertEquals(2, recorded.recordedStepsCount)
        assertEquals(WarehouseMacroActionState.RECORDING, recorded.macroState)

        // 凭据自动填充联动：有密码记录且候选为空时触发
        val withCreds = recorded.copy(
            rememberedAccount = WarehouseRememberedLogin("stu100", "p@ssword"),
            candidateAccount = WarehouseRememberedLogin("stu100", ""),
        )
        assertTrue(withCreds.shouldPromptAutofill)

        // 登录完成后候选密码不为空且未保存时触发保存
        val afterLogin = recorded.copy(
            rememberedAccount = null,
            candidateAccount = WarehouseRememberedLogin("stu100", "p@ssword"),
        )
        assertTrue(afterLogin.shouldPromptSave)
    }
}
