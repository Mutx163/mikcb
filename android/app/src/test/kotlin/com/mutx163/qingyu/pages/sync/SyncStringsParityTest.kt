package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 同步 / 云备份模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class SyncStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = SyncStrings.allTexts
        assertTrue("文案条数不应少于 100 条，当前 ${texts.size}", texts.size >= 100)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `错误码本地化表与 Dart sync_error_localizer 一致`() {
        assertEquals("账号或密码错误", SyncStrings.localizeSyncError("auth_failed"))
        assertEquals("没有访问权限", SyncStrings.localizeSyncError("access_denied"))
        assertEquals("证书校验失败", SyncStrings.localizeSyncError("certificate_error"))
        assertEquals("连接超时", SyncStrings.localizeSyncError("connection_timeout"))
        assertEquals("无法连接服务器", SyncStrings.localizeSyncError("connection_failed"))
        assertEquals("网络异常", SyncStrings.localizeSyncError("network_error"))
        assertEquals("服务器响应无效", SyncStrings.localizeSyncError("invalid_response"))
        assertEquals("本地有未同步修改，已跳过自动覆盖", SyncStrings.localizeSyncError("local_changes_pending_sync"))
        assertEquals("请先配置云同步账号", SyncStrings.localizeSyncError("missing_credentials"))
        assertEquals("备份不存在", SyncStrings.localizeSyncError("backup_not_found"))
        assertEquals("备份缺失", SyncStrings.localizeSyncError("missing_backup_snapshot"))
        assertEquals("不能删除当前备份", SyncStrings.localizeSyncError("cannot_delete_current_backup"))
        assertEquals("课表尚未就绪", SyncStrings.localizeSyncError("provider_not_ready"))
        assertEquals("仅支持 HTTPS 加密连接，HTTP 明文协议已被禁用", SyncStrings.localizeSyncError("insecure_url_blocked"))
        // null / 空串 / sync_failed / 未知码 都落到「同步失败」
        assertEquals("同步失败", SyncStrings.localizeSyncError(null))
        assertEquals("同步失败", SyncStrings.localizeSyncError(""))
        assertEquals("同步失败", SyncStrings.localizeSyncError("sync_failed"))
        assertEquals("同步失败", SyncStrings.localizeSyncError("something_new"))
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals(
            "2 个课表 · 30 门课程",
            SyncStrings.cloudBackupSummary.filled("profileCount" to "2", "courseCount" to "30"),
        )
        assertEquals("已连接：me@example.com", SyncStrings.cloudSyncConnectedAs.filled("email", "me@example.com"))
        assertEquals("15 份", SyncStrings.cloudBackupMaxCountOption.filled("count", "15"))
        assertEquals("30 天", SyncStrings.cloudBackupMaxAgeOption.filled("days", "30"))
        assertEquals(
            "确定删除 2026-03-07 09:05 的云端备份吗？此操作不可撤销",
            SyncStrings.cloudBackupDeleteBody.filled("time", "2026-03-07 09:05"),
        )
        assertEquals(
            "恢复失败：备份缺失",
            SyncStrings.cloudBackupRestoreFailed.filled("message", "备份缺失"),
        )
        assertEquals(
            "同步失败：账号或密码错误",
            SyncStrings.cloudSyncResultFailed.filled("message", "账号或密码错误"),
        )
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
