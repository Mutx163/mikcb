package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「后台保活」子屏文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class LiveKeepAliveStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = LiveKeepAliveStrings.allTexts
        assertTrue("文案条数不应少于 14 条，当前 ${texts.size}", texts.size >= 14)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertEquals("ARB 键 `${item.key}` 的屏上文案与 arb 不一致", template!!, item.zh)
        }
    }

    @Test
    fun `与 LiveStrings 共用的键值不得漂移`() {
        // 两张表各查各的，但同一个 ARB 键必须给同一个值：漂了说明有人在其中一处改了字。
        val shared = listOf(
            LiveKeepAliveStrings.cancelAction to LiveStrings.cancelAction,
            LiveKeepAliveStrings.saveFailed to LiveStrings.saveFailed,
        )
        for ((mine, theirs) in shared) {
            assertEquals("键 `${mine.key}` 与 LiveStrings 的同名键不一致", theirs.zh, mine.zh)
        }
    }

    @Test
    fun `权限三态的状态词与 ARB 对应`() {
        assertEquals("建议检查", LiveKeepAliveStrings.statusLabel(LivePermissionStatus.UNKNOWN))
        assertEquals("已开启", LiveKeepAliveStrings.statusLabel(LivePermissionStatus.GRANTED))
        assertEquals("未开启", LiveKeepAliveStrings.statusLabel(LivePermissionStatus.DENIED))
    }

    @Test
    fun `确认弹窗四件套齐全且与 ARB 同值`() {
        // 敏感权限弹窗：标题 / 正文 / 取消 / 确认，一个都不能缺。
        assertEquals(arbMap["keepAliveConfirmTitle"], LiveKeepAliveStrings.keepAliveConfirmTitle.zh)
        assertEquals(arbMap["keepAliveConfirmBody"], LiveKeepAliveStrings.keepAliveConfirmBody.zh)
        assertEquals(arbMap["cancelAction"], LiveKeepAliveStrings.cancelAction.zh)
        assertEquals(arbMap["keepAliveConfirmGoAction"], LiveKeepAliveStrings.keepAliveConfirmGoAction.zh)
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 i18n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
