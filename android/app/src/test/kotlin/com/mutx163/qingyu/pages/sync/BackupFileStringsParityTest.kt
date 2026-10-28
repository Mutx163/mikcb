package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 备份文件读取用到的 ARB 文案逐字对照 `lib/l10n/app_zh.arb`（验收门槛 3）。
 *
 * 为什么这条单测必须存在：本批**不允许新增 ARB 键**，所以 [BackupFileStrings] 里的
 * 每一条都是「抄既有键」。抄错一个字（或哪天 ARB 那边改了措辞而这里没跟）就会
 * 让屏上出现与全 App 不一致的句子——机械对拍是唯一可靠的拦法。
 *
 * 「超大文件 / 空文件 / JSON 损坏」三条复用 [CoupleStrings] 的既有键，
 * 已由 `CoupleStringsParityTest` 覆盖，这里不重复。
 */
class BackupFileStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `五条快照错误文案与 app_zh_arb 逐字一致`() {
        val texts = BackupFileStrings.allTexts
        assertEquals("快照类文案应恰好 5 条", 5, texts.size)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertEquals("ARB 键 `${item.key}` 的屏上文案与 arb 不一致", template, item.zh)
        }
    }

    @Test
    fun `屏上实际使用的文案就是这五条`() {
        // 钉住「模型回报给页面的句子」与 ARB 原文一致：任何一处被改写，这里先红。
        assertEquals("不是可识别的 mikcb 备份文件", BackupFileStrings.serviceMsgUnrecognizedSyncSnapshot.zh)
        assertEquals("缺少云同步课表数据", BackupFileStrings.serviceMsgMissingSyncTimetableData.zh)
        assertEquals("备份文件校验失败", BackupFileStrings.serviceMsgSyncSnapshotChecksumFailed.zh)
        assertEquals("备份文件无法识别", BackupFileStrings.serviceMsgSyncSnapshotUnrecognized.zh)
        assertEquals("备份文件里没有可恢复的课表", BackupFileStrings.serviceMsgSyncSnapshotNoProfiles.zh)
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
