package com.mutx163.qingyu.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `.mikcb` 传输包分享/选文件契约的**纯 Kotlin 单测**（L0，无需 Gradle、无需设备）。
 *
 * 期望值全部人推，不是从实现里抄的：
 * - authority 由「applicationId + `.fileprovider`」手工拼出来对照本仓四个变体的真实包名；
 * - 字节上限的边界值按 Dart `readImportFileBytes` 的 `length > maxBytes` 口径推
 *   （等于上限**能**导，多 1 字节就拒）；
 * - MIME 顺序按「JSON 在前」的既有约定（同 `BackupSafContract.OPEN_MIME_TYPES`）；
 * - 文案键直接写 ARB 里的键名字面量（`i18n/app_zh.arb` 里逐字可查）。
 *
 * 这些值一旦被谁改坏（例如把 `>` 写成 `>=`、把 authority 后缀拼错、把 MIME 顺序颠倒），
 * 本文件会红——Android 侧的两个胶水适配器进不了单测，它们是这份契约的**唯一**自动化证据。
 */
class TransferShareContractTest {

    // ------------------------------------------------------------------
    // 常量：必须与 manifest / file_paths.xml / Dart 侧逐字对得上
    // ------------------------------------------------------------------

    @Test fun `常量与manifest及Dart侧一致`() {
        // manifest 里写的是 ${applicationId}.fileprovider
        assertEquals(".fileprovider", TransferShareContract.PROVIDER_AUTHORITY_SUFFIX)
        // file_paths.xml 的 <cache-path name="transfer_share" path="transfer-share/"/>
        assertEquals("transfer_share", TransferShareContract.PROVIDER_PATH_NAME)
        assertEquals("transfer-share", TransferShareContract.CACHE_DIR_NAME)
        // 标准 MIME
        assertEquals("application/json", TransferShareContract.MIME_JSON)
        assertEquals("application/octet-stream", TransferShareContract.MIME_BINARY)
        // Dart UnifiedTransferService.maxImportFileBytes = 20 * 1024 * 1024
        assertEquals(20971520, TransferShareContract.MAX_IMPORT_BYTES)
        // Dart DataTransferService.fileExtension = 'mikcb'（带点写出来是 .mikcb）
        assertEquals("mikcb", TransferShareContract.EXTENSION)
    }

    @Test fun `路径名与目录名是两回事`() {
        // name 是 content Uri 里的第一段（下划线），path 是真实目录名（连字符）。
        // 这俩被谁「统一」成同一个值，FileProvider 就会找不到目录。
        assertNotEquals(
            TransferShareContract.PROVIDER_PATH_NAME,
            TransferShareContract.CACHE_DIR_NAME,
        )
        // 但语义上必须成对：写进 CACHE_DIR_NAME 的文件才在 PROVIDER_PATH_NAME 那个根下面。
        assertTrue(
            TransferShareContract.providerCacheRelativePath("a.mikcb")
                .startsWith(TransferShareContract.CACHE_DIR_NAME + "/"),
        )
    }

    // ------------------------------------------------------------------
    // authority：手工拼接对照四个变体的真实 applicationId
    // ------------------------------------------------------------------

    @Test fun `authority由applicationId派生`() {
        // 正式包
        assertEquals(
            "com.mutx163.qingyu.fileprovider",
            TransferShareContract.providerAuthority("com.mutx163.qingyu"),
        )
        // dev / perf / itest 三个变体（applicationIdSuffix 见 android/app/build.gradle）
        assertEquals(
            "com.mutx163.qingyu.debug.fileprovider",
            TransferShareContract.providerAuthority("com.mutx163.qingyu.debug"),
        )
        assertEquals(
            "com.mutx163.qingyu.profile.fileprovider",
            TransferShareContract.providerAuthority("com.mutx163.qingyu.profile"),
        )
        assertEquals(
            "com.mutx163.qingyu.itest.fileprovider",
            TransferShareContract.providerAuthority("com.mutx163.qingyu.itest"),
        )
        // bench 变体不带后缀，与正式包同名
        assertEquals(
            "com.mutx163.qingyu.fileprovider",
            TransferShareContract.providerAuthority("com.mutx163.qingyu"),
        )
    }

    @Test fun `authority去掉两端空白`() {
        assertEquals(
            "com.mutx163.qingyu.fileprovider",
            TransferShareContract.providerAuthority("  com.mutx163.qingyu\n"),
        )
    }

    @Test fun `authority拒绝空applicationId`() {
        // 空串会拼出 ".fileprovider"，那种 authority 永远匹配不上 manifest，
        // 表现为「点了分享没反应」，所以必须在契约层就炸。
        assertThrows(IllegalArgumentException::class.java) {
            TransferShareContract.providerAuthority("")
        }
        assertThrows(IllegalArgumentException::class.java) {
            TransferShareContract.providerAuthority("   ")
        }
    }

    // ------------------------------------------------------------------
    // 缓存相对路径
    // ------------------------------------------------------------------

    @Test fun `缓存相对路径落在transfer-share目录`() {
        assertEquals(
            "transfer-share/mikcb-full-backup.mikcb",
            TransferShareContract.providerCacheRelativePath("mikcb-full-backup.mikcb"),
        )
        // 拼的是相对路径，不能带前导斜杠（File(context.cacheDir, "/x") 会跑到根目录）
        assertFalse(
            TransferShareContract.providerCacheRelativePath("a.mikcb").startsWith("/"),
        )
        // 只拼一层：不替调用方清洗文件名（清洗是适配器 share() 的责任）
        assertEquals(
            "transfer-share/a/b.mikcb",
            TransferShareContract.providerCacheRelativePath("a/b.mikcb"),
        )
    }

    // ------------------------------------------------------------------
    // 选文件 MIME 候选
    // ------------------------------------------------------------------

    @Test fun `选文件MIME候选顺序固定`() {
        // 顺序是契约：JSON 在前（与 BackupSafContract 同口径，首项常被 Rom 当默认过滤档）
        assertEquals(
            listOf("application/json", "application/octet-stream"),
            TransferShareContract.OPEN_MIME_TYPES,
        )
        // .mikcb 在系统里多半映射不出 MIME，所以必须有 octet-stream 兜底才能被选中
        assertTrue(TransferShareContract.OPEN_MIME_TYPES.contains(TransferShareContract.MIME_BINARY))
        assertEquals(2, TransferShareContract.OPEN_MIME_TYPES.size)
    }

    // ------------------------------------------------------------------
    // 限长：边界值人推（Dart: length > maxBytes 才拒）
    // ------------------------------------------------------------------

    @Test fun `超限判断默认上限20MB边界`() {
        val limit = 20L * 1024 * 1024
        // 恰好等于上限：**不**算超（Dart 侧同样能导）
        assertFalse(TransferShareContract.exceedsLimit(limit))
        // 多 1 字节就拒
        assertTrue(TransferShareContract.exceedsLimit(limit + 1))
        // 少 1 字节当然能导
        assertFalse(TransferShareContract.exceedsLimit(limit - 1))
        // 0 字节（空文件）不超限——内容是否合法不归这一层判
        assertFalse(TransferShareContract.exceedsLimit(0))
    }

    @Test fun `超限判断自定义上限`() {
        assertFalse(TransferShareContract.exceedsLimit(1024, 1024))
        assertTrue(TransferShareContract.exceedsLimit(1025, 1024))
        assertFalse(TransferShareContract.exceedsLimit(0, 0))
        assertTrue(TransferShareContract.exceedsLimit(1, 0))
    }

    @Test fun `超限判断用Long不溢出`() {
        // OpenableColumns.SIZE / File.length() 都是 Long：按 Int 比会先溢出。
        // Int.MAX_VALUE 的两倍多，用 Long 比能正确判成「超」。
        assertTrue(TransferShareContract.exceedsLimit(Int.MAX_VALUE.toLong() * 2))
        // 负值（某些 provider 上报 -1）不当作超限：交给限长读兜底，而不是乱报「太大」
        assertFalse(TransferShareContract.exceedsLimit(-1))
    }

    // ------------------------------------------------------------------
    // 失败分类 → ARB 文案键
    // ------------------------------------------------------------------

    @Test fun `导入侧文案键与ARB一致`() {
        // 这两个键在 i18n/app_zh.arb 里逐字存在
        assertEquals(
            "importFileTooLarge",
            TransferShareContract.failureMessageKey(TransferShareContract.Failure.FILE_TOO_LARGE),
        )
        assertEquals(
            "importFileReadFailed",
            TransferShareContract.failureMessageKey(TransferShareContract.Failure.READ_FAILED),
        )
    }

    @Test fun `导出侧三类失败的文案键现在都落到saveFailed`() {
        // 现有 ARB 里没有 export/share 专属失败键，统一落到通用「保存失败」。
        // 谁补了专属键，改契约的同时必须改这三条断言——这条测试就是那次改动的提醒。
        assertEquals(
            "saveFailed",
            TransferShareContract.failureMessageKey(TransferShareContract.Failure.WRITE_FAILED),
        )
        assertEquals(
            "saveFailed",
            TransferShareContract.failureMessageKey(TransferShareContract.Failure.PROVIDER_UNAVAILABLE),
        )
        assertEquals(
            "saveFailed",
            TransferShareContract.failureMessageKey(TransferShareContract.Failure.NO_TARGET),
        )
        assertEquals(
            "saveFailed",
            TransferShareContract.failureMessageKey(TransferShareContract.Failure.LAUNCH_FAILED),
        )
    }

    @Test fun `每个失败分类都有非空文案键`() {
        // 穷举全部枚举项：新增分类却忘了配键时（when 不穷举编译不过，这条兜运行期空串）
        for (failure in TransferShareContract.Failure.entries) {
            val key = TransferShareContract.failureMessageKey(failure)
            assertTrue("$failure 没有文案键", key.isNotBlank())
            // 返回的是 ARB 键名，不是中文句子
            assertTrue("$failure 的键名看起来像中文文案：$key", key.all { it.isLetterOrDigit() })
        }
        assertEquals(6, TransferShareContract.Failure.entries.size)
    }
}
