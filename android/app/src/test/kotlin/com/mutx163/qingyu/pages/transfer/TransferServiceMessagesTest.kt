package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 错误码 → 屏上文案的兜底口径单测（`lib/l10n/service_message_localizer.dart` 移植）。
 *
 * 三类判据各有用例钉住：
 * 1. 未登记的 ASCII 蛇形机器码 → 兜底文案（`transfer_*` 全在这一类，Dart 也是）；
 * 2. 人话（中文 / 带空格 / 大写开头 / 空串）→ **原样透传**，不许被吃掉；
 * 3. 登记过的码 → 与 `app_zh.arb` **逐字**一致（照 `TransferStringsParityTest` 的读法）。
 */
class TransferServiceMessagesTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    // ---------- 1. 未登记机器码 ----------

    @Test
    fun `未登记的 transfer 码落到发生未知错误`() {
        // Dart 源码里 `case 'transfer_` 命中 0 次 ⇒ 这些码在 Flutter 侧同样是兜底文案。
        assertEquals(
            "发生未知错误",
            TransferServiceMessages.localize("transfer_exported_at_invalid"),
        )
        assertEquals("发生未知错误", TransferServiceMessages.localize("transfer_scope_invalid"))
        assertEquals("发生未知错误", TransferServiceMessages.localize("transfer_package_empty"))
        assertEquals("发生未知错误", TransferServiceMessages.localize("no_time_schemes"))
    }

    @Test
    fun `带冒号细节的机器码也算未登记`() {
        assertEquals(
            "发生未知错误",
            TransferServiceMessages.localize("settings_mirror_snapshot_invalid:key1"),
        )
        assertEquals(
            "发生未知错误",
            TransferServiceMessages.localize("task_course_missing:abc-123"),
        )
    }

    @Test
    fun `encodeServiceMessage 的 payload 按竖线取码`() {
        // Dart `encodeServiceMessage('transfer_x', {'a': 1})` = `transfer_x|a=1`。
        assertEquals(
            "发生未知错误",
            TransferServiceMessages.localize("transfer_x|a=1"),
        )
        assertEquals(
            "缺少设置数据",
            TransferServiceMessages.localize("missing_settings_data|detail=1"),
        )
    }

    // ---------- 2. 人话原样透传 ----------

    @Test
    fun `中文与人话原样透传`() {
        assertEquals("ImportFileTooLarge", TransferServiceMessages.localize("ImportFileTooLarge"))
        assertEquals("文件过大，无法导入", TransferServiceMessages.localize("文件过大，无法导入"))
        // Dart 异常原文形如 `Bad state: xxx`（带空格与大写），命中不了机器码正则。
        assertEquals(
            "Bad state: No element",
            TransferServiceMessages.localize("Bad state: No element"),
        )
        // 带 `!` 或空格的串不是蛇形码。
        assertEquals("file too large!", TransferServiceMessages.localize("file too large!"))
    }

    @Test
    fun `空串原样返回且 null 落到兜底文案`() {
        assertEquals("", TransferServiceMessages.localize(""))
        assertEquals("发生未知错误", TransferServiceMessages.localize(null))
    }

    // ---------- 3. 登记表逐字对拍 ARB ----------

    @Test
    fun `登记了导入与备份那一段加单套模板分享的十四个码`() {
        assertEquals(14, TransferServiceMessages.registeredCodes.size)
        assertEquals(15, TransferServiceMessages.allTexts.size) // 14 + 兜底那条
        assertEquals(
            listOf(
                "import_file_unrecognized",
                "import_rollback_incomplete",
                "import_use_overwrite_for_full_backup",
                "import_no_profiles_in_backup",
                "unrecognized_mikcb_data_file",
                "partner_import_requires_single_profile",
                "couple_webdav_not_connected",
                "couple_webdav_partner_file_missing",
                "couple_webdav_pull_failed",
                "missing_settings_data",
                "unrecognized_mikcb_full_backup",
                "missing_full_backup_data",
                "use_profile_backup_not_full",
                // T-09（2026-11-11）：单套时间模板分享时点名的那套已不在快照里。
                "transfer_send_no_selected_time_schemes",
            ),
            TransferServiceMessages.registeredCodes,
        )
    }

    @Test
    fun `每一条文案都与 app_zh_arb 逐字一致`() {
        for (item in TransferServiceMessages.allTexts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            // 这几条都没有占位符，直接整串比。
            assertEquals("键 `${item.key}` 的文案与 arb 不一致", template!!, item.zh)
        }
    }

    @Test
    fun `登记过的码返回对应 ARB 文案`() {
        assertEquals(
            "导入失败，文件内容无法识别",
            TransferServiceMessages.localize("import_file_unrecognized"),
        )
        assertEquals(
            "不是可识别的 mikcb 全量备份文件",
            TransferServiceMessages.localize("unrecognized_mikcb_full_backup"),
        )

        // T-09：单套时间模板分享的新码（宿主以 `transfer_send_<code>` 前缀查表）。
        assertEquals(
            "要分享的时间模板已不存在，请刷新后重试",
            TransferServiceMessages.localize("transfer_send_no_selected_time_schemes"),
        )
        // 带参数 payload 也必须按第一段取码（宿主偶尔会拼上 packageId 之类的细节）。
        assertEquals(
            "要分享的时间模板已不存在，请刷新后重试",
            TransferServiceMessages.localize("transfer_send_no_selected_time_schemes|packageId=pkg-1"),
        )
        assertEquals(
            "请导入单课表备份文件，不支持全量备份",
            TransferServiceMessages.localize("partner_import_requires_single_profile"),
        )
        assertEquals("请先连接坚果云", TransferServiceMessages.localize("couple_webdav_not_connected"))
        // ARB 键不是错误码：`quickImportUnknownError` 带大写字母，按判据属「人话」，
        // 因此原样透传（正是这条规则保护了 `ImportFileTooLarge` 这类串不被吃掉）。
        assertEquals(
            "quickImportUnknownError",
            TransferServiceMessages.localize("quickImportUnknownError"),
        )
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
