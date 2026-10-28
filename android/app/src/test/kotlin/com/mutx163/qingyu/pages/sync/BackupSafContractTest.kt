package com.mutx163.qingyu.pages.sync

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SAF 契约（[BackupSafContract]）测试。
 *
 * 这里的期望值全是**手写字面量**：action / extra 键的字符串要跟 Android 框架常量逐字相等
 * （`Intent.ACTION_OPEN_DOCUMENT` 等），文件名格式要跟 Dart `mikcb-backup-yyyyMMdd-HHmm`
 * 的形态对得上。适配器本身进不了 JVM 单测，这些契约值由本测试钉住——写错一个字符就会在
 * 真机上表现为「系统选择器不认这个文件」。
 */
class BackupSafContractTest {

    @Test
    fun `默认文件名按 yyyyMMdd-HHmm 生成并用 json 扩展名`() {
        val name = BackupSafContract.defaultFileName(LocalDateTime.of(2026, 10, 28, 16, 6))
        assertEquals("mikcb-backup-20261028-1606.json", name)
    }

    @Test
    fun `月日时分补零`() {
        val name = BackupSafContract.defaultFileName(LocalDateTime.of(2026, 1, 2, 3, 4))
        assertEquals("mikcb-backup-20260102-0304.json", name)
    }

    @Test
    fun `MIME 常量与 JSON 语义一致`() {
        assertEquals("application/json", BackupSafContract.MIME_JSON)
        assertEquals("application/octet-stream", BackupSafContract.MIME_OCTET_STREAM)
        assertEquals(listOf("application/json", "application/octet-stream"),
            BackupSafContract.OPEN_MIME_TYPES.toList())
    }

    @Test
    fun `action 与 extra 键与 Android 框架常量逐字一致`() {
        // 这些是 android.content.Intent 上常量的字面值（本层不 import android.* ，改写字面量）
        assertEquals("android.intent.action.OPEN_DOCUMENT", BackupSafContract.ACTION_OPEN_DOCUMENT)
        assertEquals("android.intent.action.CREATE_DOCUMENT", BackupSafContract.ACTION_CREATE_DOCUMENT)
        assertEquals("android.intent.extra.TITLE", BackupSafContract.EXTRA_TITLE)
        assertEquals("android.intent.extra.MIME_TYPES", BackupSafContract.EXTRA_MIME_TYPES)
        assertEquals("android.intent.category.OPENABLE", BackupSafContract.CATEGORY_OPENABLE)
    }

    @Test
    fun `导出文件名前缀与扩展名`() {
        assertEquals("mikcb-backup", BackupSafContract.FILE_NAME_PREFIX)
        assertEquals("json", BackupSafContract.FILE_EXTENSION)
    }

    @Test
    fun `导入候选扩展名接受 json 与 mikcb`() {
        assertEquals(setOf("json", "mikcb"), BackupSafContract.ACCEPTED_EXTENSIONS)
        assertTrue(BackupSafContract.isBackupFileCandidate("mikcb-backup-20261028-1606.json"))
        assertTrue(BackupSafContract.isBackupFileCandidate("a.mikcb"))
        assertTrue("大小写不敏感", BackupSafContract.isBackupFileCandidate("A.MIKCB"))
        assertTrue(BackupSafContract.isBackupFileCandidate("x.Json"))
    }

    @Test
    fun `非备份文件名一律拒绝`() {
        assertFalse(BackupSafContract.isBackupFileCandidate("a.txt"))
        assertFalse(BackupSafContract.isBackupFileCandidate("noext"))
        assertFalse(BackupSafContract.isBackupFileCandidate("trailing."))
        assertFalse(BackupSafContract.isBackupFileCandidate(""))
        assertFalse(BackupSafContract.isBackupFileCandidate("   "))
        assertFalse(BackupSafContract.isBackupFileCandidate(null))
    }
}
