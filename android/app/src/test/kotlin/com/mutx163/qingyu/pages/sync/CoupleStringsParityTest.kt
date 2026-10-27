package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣课表设置页文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class CoupleStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = CoupleStrings.allTexts
        assertTrue("文案条数不应少于 40 条，当前 ${texts.size}", texts.size >= 40)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `服务层码本地化与 Dart service_message_localizer 的爱侣三码一致`() {
        assertEquals("请先连接坚果云", CoupleStrings.localizeServiceMessage("couple_webdav_not_connected"))
        assertEquals(
            "未找到对方课表文件，请让对方先上传",
            CoupleStrings.localizeServiceMessage("couple_webdav_partner_file_missing"),
        )
        assertEquals("拉取对方课表失败，请稍后重试", CoupleStrings.localizeServiceMessage("couple_webdav_pull_failed"))
        // 未登记的机器码 → 「发生未知错误」（Dart 兜底口径）
        assertEquals("发生未知错误", CoupleStrings.localizeServiceMessage("couple_webdav_new_code"))
        assertEquals("发生未知错误", CoupleStrings.localizeServiceMessage("settings_mirror_snapshot_invalid:key"))
        // 本来就是人话的字符串原样透出
        assertEquals("Bad state: 文件损坏", CoupleStrings.localizeServiceMessage("Bad state: 文件损坏"))
        assertEquals("", CoupleStrings.localizeServiceMessage(null))
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals("课程数量：12 门", CoupleStrings.courseCountBullet.filled("count", "12"))
        assertEquals("上次导入：2026-10-26 08:15",
            CoupleStrings.coupleTimetableLastImportedAt.filled("time", "2026-10-26 08:15"))
        assertEquals("远程文件路径：/Apps/qingyu-couple/couple-slot-2.mikcb",
            CoupleStrings.coupleWebdavRemotePathHint.filled("path", "/Apps/qingyu-couple/couple-slot-2.mikcb"))
        assertEquals("+3 周", CoupleStrings.coupleTimetableWeekOffsetSigned.filled("offset", "+3"))
        assertEquals(
            "查看你的第 5 周时，显示对方第 6 周的课",
            CoupleStrings.coupleTimetableWeekOffsetPreview.filled("myWeek" to "5", "partnerWeek" to "6"),
        )
        assertEquals("，其中 3 条格式损坏已跳过", CoupleStrings.importPartialSkippedSuffix.filled("count", "3"))
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "lib/l10n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 lib/l10n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
