package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 接线层纯逻辑单测（task-21）：进度/错误 → 页面状态、以及 §6.2 桥接消息门禁的**组合判定**。
 *
 * 这一层刻意放在 `main/.../pages/import/warehouse/`（L0 模块目录）而不是 composeP1 的页面文件里：
 * 页面文件不在 L0 的编译范围，写在那里的判定只能靠真机看。
 */
class WarehouseWebLoginWebStateTest {

    // -----------------------------------------------------------------------
    // 进度 / 错误 → 阶段
    // -----------------------------------------------------------------------

    @Test
    fun `进度映射成加载中与已加载`() {
        assertEquals(WarehouseWebLoginStage.LOADING, WarehouseWebLoginWebState.stageForProgress(0))
        assertEquals(WarehouseWebLoginStage.LOADING, WarehouseWebLoginWebState.stageForProgress(1))
        assertEquals(WarehouseWebLoginStage.LOADING, WarehouseWebLoginWebState.stageForProgress(99))
        assertEquals(WarehouseWebLoginStage.LOADED, WarehouseWebLoginWebState.stageForProgress(100))
        // 平台回调理论上不会超 100，但真给了也别判成「没加载完」
        assertEquals(WarehouseWebLoginStage.LOADED, WarehouseWebLoginWebState.stageForProgress(150))
        // 负数（异常值）当「还没加载完」处理，不抛
        assertEquals(WarehouseWebLoginStage.LOADING, WarehouseWebLoginWebState.stageForProgress(-5))
    }

    @Test
    fun `任何加载失败都进 ERROR 阶段`() {
        assertEquals(WarehouseWebLoginStage.ERROR, WarehouseWebLoginWebState.stageForError())
    }

    @Test
    fun `错误文案优先取 ARB 取不到才回退系统原文`() {
        val cleartext = WarehouseWebViewError(
            errorCode = WarehouseWebViewErrorCodes.CONNECT,
            description = "net::ERR_CLEARTEXT_NOT_PERMITTED",
            url = "http://jw.school.edu.cn/login",
        )
        // 明文拦截有现成 ARB 键（importCleartextBlockedHint）
        assertEquals("importCleartextBlockedHint", cleartext.arbKey)
        assertEquals(
            "该站点暂不支持 HTTPS 访问且未在明文白名单内，无法在此打开",
            WarehouseWebLoginWebState.errorText(cleartext) {
                if (it == "importCleartextBlockedHint") "该站点暂不支持 HTTPS 访问且未在明文白名单内，无法在此打开" else null
            },
        )
        // ARB 里没有这条键（Kotlin 侧 WarehouseStrings 尚未补）→ 回退系统原文，不能空白
        assertEquals(
            "net::ERR_CLEARTEXT_NOT_PERMITTED",
            WarehouseWebLoginWebState.errorText(cleartext) { null },
        )
        // 超时没有 ARB 键 → 直接用 description
        val timeout = WarehouseWebViewError(
            errorCode = WarehouseWebViewErrorCodes.TIMEOUT,
            description = "net::ERR_TIMED_OUT",
            url = null,
        )
        assertEquals(null, timeout.arbKey)
        assertEquals("net::ERR_TIMED_OUT", WarehouseWebLoginWebState.errorText(timeout) { "不该被用到" })
        // ARB 返回空白也算「取不到」
        assertEquals("net::ERR_TIMED_OUT", WarehouseWebLoginWebState.errorText(timeout) { "   " })
    }

    // -----------------------------------------------------------------------
    // §6.2 桥接消息门禁（本轮重点）
    // -----------------------------------------------------------------------

    @Test
    fun `UI 类桥接消息只在导入执行期放行`() {
        // 逐类型 × 逐阶段全枚举：只有 EXECUTING 放行，其余一律拦
        for (type in WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES) {
            val raw = """{"type":"$type","payload":"x"}"""
            for (stage in WarehouseWebLoginStage.entries) {
                val expected = stage == WarehouseWebLoginStage.EXECUTING
                assertEquals(
                    "UI 类消息 `$type` 在阶段 $stage 的放行判定",
                    expected,
                    WarehouseWebLoginWebState.shouldDeliverBridgeMessage(raw, stage),
                )
            }
        }
    }

    @Test
    fun `非 UI 类消息与判不出类型的一律放行`() {
        // 宿主自己注入的探活协议、数据类消息：任何阶段都照常处理（Dart 同口径）。
        // macro:event / loginAttempt 不在此列——它们各自有放行条件（见下面两测）。
        for (type in listOf("loginState", "sessionProbe", "courses")) {
            for (stage in WarehouseWebLoginStage.entries) {
                assertTrue(
                    "非 UI 类消息 `$type` 不该被门禁拦下（阶段 $stage）",
                    WarehouseWebLoginWebState.shouldDeliverBridgeMessage("""{"type":"$type"}""", stage),
                )
            }
        }
        assertTrue(WarehouseWebLoginWebState.shouldDeliverBridgeMessage(null, WarehouseWebLoginStage.IDLE))
        assertTrue(WarehouseWebLoginWebState.shouldDeliverBridgeMessage("   ", WarehouseWebLoginStage.IDLE))
    }

    @Test
    fun `macro_event 与 loginAttempt 按新门禁判定`() {
        val macroEvent = """{"type":"macro:event"}"""
        val loginAttempt = """{"type":"loginAttempt","username":"a","password":"b"}"""
        // macro:event：非录制态一律拦（页面现在还没接录制，macroState 恒 IDLE）
        for (stage in WarehouseWebLoginStage.entries) {
            assertFalse(
                "macro:event 在阶段 $stage（未录制）必须被拦",
                WarehouseWebLoginWebState.shouldDeliverBridgeMessage(macroEvent, stage),
            )
        }
        assertTrue(
            "录制态放行",
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                macroEvent,
                WarehouseWebLoginStage.LOADED,
                macroRecordingActive = true,
            ),
        )
        // loginAttempt：非执行期、当前页不在受信 host 上 ⇒ 拦（钓鱼页面）
        assertFalse(
            "钓鱼页上的伪造 loginAttempt 必须被拦",
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                loginAttempt,
                WarehouseWebLoginStage.LOADED,
                currentUrl = "https://trusted.cn.evil.com/login",
                trustedLoginUrls = listOf("https://trusted.cn/login"),
            ),
        )
        // loginAttempt：当前页在受信 host（含子域）上 ⇒ 放行（普通手动登录的主路径）
        assertTrue(
            "受信页上的 loginAttempt 应放行",
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                loginAttempt,
                WarehouseWebLoginStage.LOADED,
                currentUrl = "https://jw.trusted.cn/login",
                trustedLoginUrls = listOf("https://trusted.cn/login"),
            ),
        )
        // loginAttempt：执行期放行（与受信无关）
        assertTrue(
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                loginAttempt,
                WarehouseWebLoginStage.EXECUTING,
                currentUrl = "https://trusted.cn.evil.com/login",
                trustedLoginUrls = listOf("https://trusted.cn/login"),
            ),
        )
        // 没传受信地址 ⇒ 受信放行永不生效（只会更严），非执行期照拦
        assertFalse(
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                loginAttempt,
                WarehouseWebLoginStage.LOADED,
            ),
        )
    }

    @Test
    fun `畸形消息不会被误判成 UI 类而误拦或误放`() {
        // 不是 JSON / 顶层不是对象 / type 不是字符串 → 判不出类型 → 交回调用方（放行）
        val malformed = listOf(
            "not json at all",
            "[1,2,3]",
            """{"payload":"x"}""",
            """{"type":123}""",
            """{"type":"toast"}""", // 这一条是**合法**的 UI 类消息，单独断言
        )
        for (raw in malformed.dropLast(1)) {
            assertTrue(
                "`$raw` 判不出类型时应交回调用方",
                WarehouseWebLoginWebState.shouldDeliverBridgeMessage(raw, WarehouseWebLoginStage.IDLE),
            )
        }
        // 合法 UI 类消息在非执行期必须被拦（这条是门禁的牙齿）
        assertFalse(
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                malformed.last(),
                WarehouseWebLoginStage.LOADED,
            ),
        )
        assertTrue(
            WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                malformed.last(),
                WarehouseWebLoginStage.EXECUTING,
            ),
        )
    }

    @Test
    fun `门禁判定与 Dart 门禁函数逐项一致`() {
        // 组合判定必须与「先取类型、再判阶段」的直连写法完全等价——
        // 否则页面调的组合函数会与 Dart 门禁分叉
        val samples = listOf(
            """{"type":"toast"}""",
            """{"type":"confirm"}""",
            """{"type":"loginState"}""",
            "not json",
            "null",
        )
        for (raw in samples) {
            for (stage in WarehouseWebLoginStage.entries) {
                val direct = shouldProcessWarehouseBridgeMessage(
                    type = warehouseBridgeMessageType(raw),
                    importExecutionActive = stage == WarehouseWebLoginStage.EXECUTING,
                )
                assertEquals(
                    "`$raw` @ $stage 的组合判定必须与直连写法一致",
                    direct,
                    WarehouseWebLoginWebState.shouldDeliverBridgeMessage(raw, stage),
                )
            }
        }
    }
}
