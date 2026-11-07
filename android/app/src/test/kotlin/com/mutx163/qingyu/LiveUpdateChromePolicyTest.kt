package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [LiveUpdateChromePolicy] 的**行为断言**（JVM 直测，测真实布尔值，不查源码字符串）。
 *
 * 第四轮返工后策略只剩一件事：**上岛 ⇒ 藏 `when` 区**（岛上不显示 when；标准通知显示）。
 * chronometer 字段已撤（走字方案撤回，理由见 `LiveUpdateChromePolicy` KDoc）。
 */
class LiveUpdateChromePolicyTest {

    @Test
    fun `上岛时 when 区必须隐藏`() {
        assertFalse(LiveUpdateChromePolicy.chromeFor(promotedFormActive = true).showWhen)
    }

    @Test
    fun `不上岛时 when 区必须显示`() {
        assertTrue(LiveUpdateChromePolicy.chromeFor(promotedFormActive = false).showWhen)
    }
}
