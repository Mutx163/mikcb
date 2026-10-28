package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.canonicalJson
import com.mutx163.qingyu.sync.canonicalize
import com.mutx163.qingyu.sync.computeContentSha256
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 备份文件读取模型测试（C2「备份还原页」的模型半边）。
 *
 * 期望值全部**人推**，不从实现里抄：
 *
 * - 文件内容、canonical 哈希输入、每一条屏上文案都是手写字面量；
 * - 哈希由测试**自己**用 [MessageDigest] 对**手写的 canonical 字符串**算，
 *   与生产代码走不同的路径（生产走 `canonicalize` + `canonicalJson`），
 *   两边对上才算「校验和这条链没走歪」；
 * - 字节数按 UTF-8 手算：ASCII 1、汉字 3、emoji（代理对）4；
 * - 尺寸文案按 Dart `formatByteBudget` 的四舍五入口径手推（`1536 B → 2 KB`）。
 *
 * 与 Dart 的三处刻意差异（纯空白算空文件、字节按 UTF-8 现算、`profiles: []` 单独拒）
 * 都在下面各有独立用例钉住，见 [BackupFileReadLogic] 头注释。
 */
class BackupFileReadModelTest {

    // ==========================================================
    // 手写的 canonical 哈希输入（口径：键升序、紧凑分隔符、非 ASCII 不转义；
    // exportedAt / deviceId / contentSha256 三个键**不进哈希**）
    // ==========================================================
    private val canonicalHashInput: String =
        """{"app":"mikcb","backupType":"sync","profiles":[{"id":"p1","name":"默认"}],""" +
            """"schemaVersion":2,"timeSchemes":[{"id":"t1","name":"默认作息"}]}"""

    /** 测试侧独立算的「正确校验和」（生产侧走 canonicalize + canonicalJson，两条路径）。 */
    private val honestHash: String by lazy { sha256Hex(canonicalHashInput) }

    /** 一份合法备份文件：信封 + 元数据 + 一张课表 + 一张作息 + 正确的校验和。 */
    private val validContent: String by lazy {
        """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"exportedAt":"2026-03-07T09:05:30.000","deviceId":"device-1",""" +
            """"profiles":[{"id":"p1","name":"默认"}],""" +
            """"timeSchemes":[{"id":"t1","name":"默认作息"}],""" +
            """"contentSha256":"$honestHash"}"""
    }

    // ==========================================================
    // 1. 正常备份往返
    // ==========================================================

    @Test
    fun `合法备份文件读出快照负载与元数据`() {
        val snapshot = success(BackupFileReadLogic.read(validContent))

        // 元数据：导出时间原样往返（毫秒位补零）、设备、无 appVersion / snapshotPath
        assertEquals("2026-03-07T09:05:30.000", snapshot.meta.exportedAtIso)
        assertFalse(snapshot.meta.exportedAtUnparsed)
        assertEquals(honestHash, snapshot.meta.contentSha256)
        assertEquals("device-1", snapshot.meta.deviceId)
        assertNull(snapshot.meta.appVersion)
        assertNull(snapshot.meta.snapshotPath)

        // 校验和：文件带了正确哈希 → 真的验过
        assertTrue(snapshot.checksumVerified)

        // 快照负载：去掉 contentSha256，其余键原样；课表/作息都在
        assertFalse("快照负载里不该留着 contentSha256", snapshot.snapshot.containsKey("contentSha256"))
        assertEquals("mikcb", snapshot.snapshot["app"])
        assertEquals("sync", snapshot.snapshot["backupType"])
        assertEquals(2L, snapshot.snapshot["schemaVersion"])
        assertEquals(1, (snapshot.snapshot["profiles"] as List<*>).size)
        assertEquals(1, (snapshot.snapshot["timeSchemes"] as List<*>).size)
    }

    /**
     * 校验和这条链的**独立锚点**：手写 canonical 字符串必须与生产侧的
     * canonicalize + canonicalJson 逐字一致，且哈希对得上。
     *
     * 这条用例的价值在于「canonical 口径是人推的」：键升序、紧凑分隔符、
     * 三个元数据键不进哈希——三条口径任一条被改动，这里立刻红。
     */
    @Test
    fun `校验和口径与手写 canonical 字符串一致`() {
        val parsed = MiniJson.parse(validContent) as Map<String, Any?>

        // 进哈希的负载：去掉 exportedAt / deviceId / contentSha256（Dart _canonicalize 前先 filter）
        val payload = parsed.filterKeys { it != "exportedAt" && it != "deviceId" && it != "contentSha256" }
        assertEquals(canonicalHashInput, canonicalJson(canonicalize(payload)))
        assertEquals(honestHash, computeContentSha256(parsed))

        // 反过来：把 exportedAt 改掉，哈希必须不变（它不进哈希）；把 id 改掉，哈希必须变。
        val movedTime = validContent.replace("2026-03-07T09:05:30.000", "2027-01-01T00:00:00.000")
        assertEquals(honestHash, computeContentSha256(MiniJson.parse(movedTime) as Map<String, Any?>))
        val renamed = validContent.replace("\"p1\"", "\"p2\"")
        assertFalse(honestHash == computeContentSha256(MiniJson.parse(renamed) as Map<String, Any?>))
    }

    @Test
    fun `没带校验和的文件仍可读但标记未验证`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"deviceId":"device-1","profiles":[{"id":"p1"}],"timeSchemes":[{"id":"t1"}]}"""
        val snapshot = success(BackupFileReadLogic.read(content))

        // Dart 口径（AppSyncSnapshotCodec 第 5 步）：声明空/缺失 → 跳过校验，不是失败。
        assertFalse(snapshot.checksumVerified)
        assertEquals("", snapshot.meta.contentSha256)
        // 没写 exportedAt → 回落纪元零点，并标「时间不可用」，页面据此隐藏时间行。
        assertTrue(snapshot.meta.exportedAtUnparsed)
    }

    @Test
    fun `带了 appVersion 与 snapshotPath 时原样透出`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"exportedAt":"2026-03-07T09:05:30","deviceId":"d",""" +
            """"appVersion":"4.1.2","snapshotPath":"qingyu/snapshots/a.json",""" +
            """"profiles":[{"id":"p1"}],"timeSchemes":[]}"""
        val meta = success(BackupFileReadLogic.read(content)).meta

        // 无毫秒的 ISO 也解析得动，并补齐到 .000（Dart toIso8601String 恒定三位毫秒）
        assertEquals("2026-03-07T09:05:30.000", meta.exportedAtIso)
        assertEquals("4.1.2", meta.appVersion)
        assertEquals("qingyu/snapshots/a.json", meta.snapshotPath)
    }

    // ==========================================================
    // 2. JSON 损坏
    // ==========================================================

    @Test
    fun `JSON 截断报文件无效并留档原始片段`() {
        val broken = """{"app":"mikcb","""
        val failure = failure(BackupFileReadLogic.read(broken))

        assertEquals(BackupFileFailureKind.MALFORMED_JSON, failure.kind)
        assertEquals("导入失败，请确认文件有效", failure.userMessage)
        assertEquals("snippet=$broken", failure.damage)
        // 上游是 MiniJson 的解析器原文（Dart 侧 FormatException.message 同口径），只做诊断
        assertTrue("解析器错误信息不该为空", !failure.errorCode.isNullOrEmpty())
    }

    @Test
    fun `根不是对象也归为 JSON 损坏`() {
        val failure = failure(BackupFileReadLogic.read("[1,2,3]"))

        assertEquals(BackupFileFailureKind.MALFORMED_JSON, failure.kind)
        // 根不是对象由 decodeSnapshotObject 抛固定码（Dart :689 原样）
        assertEquals("invalid_sync_snapshot_payload", failure.errorCode)
        assertEquals("导入失败，请确认文件有效", failure.userMessage)
        assertEquals("snippet=[1,2,3]", failure.damage)
    }

    @Test
    fun `超长坏文件的留档片段被截断并标明剩余字符数`() {
        // 300 个 'x'：不是 JSON，damage 只留前 160 字符
        val failure = failure(BackupFileReadLogic.read("x".repeat(300)))

        assertEquals(BackupFileFailureKind.MALFORMED_JSON, failure.kind)
        assertEquals("snippet=" + "x".repeat(160) + "…(+140)", failure.damage)
    }

    // ==========================================================
    // 3. 校验和不符
    // ==========================================================

    @Test
    fun `校验和不符报校验失败并留档声明值与重算值`() {
        val tampered = validContent.replace(honestHash, "deadbeef")
        val failure = failure(BackupFileReadLogic.read(tampered))

        assertEquals(BackupFileFailureKind.CHECKSUM_MISMATCH, failure.kind)
        assertEquals("sync_snapshot_checksum_failed", failure.errorCode)
        assertEquals("备份文件校验失败", failure.userMessage)
        assertEquals("expected=deadbeef; actual=$honestHash", failure.damage)
    }

    @Test
    fun `内容被改过导致哈希对不上也报校验失败`() {
        // 哈希还是原来那份内容的，但课程名被改了 → 重算值变 → 不一致
        val tampered = validContent.replace("默认作息", "改过的作息")
        val failure = failure(BackupFileReadLogic.read(tampered))

        assertEquals(BackupFileFailureKind.CHECKSUM_MISMATCH, failure.kind)
        assertEquals("备份文件校验失败", failure.userMessage)
        assertTrue(
            "留档里应能看出两个哈希不同：${failure.damage}",
            failure.damage.startsWith("expected=$honestHash; actual=") && !failure.damage.endsWith(honestHash),
        )
    }

    @Test
    fun `校验和字段类型非法报校验失败并留档字段类型`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"profiles":[{"id":"p1"}],"timeSchemes":[],"contentSha256":123}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.CHECKSUM_FIELD_INVALID, failure.kind)
        assertEquals("invalid_sync_snapshot_checksum", failure.errorCode)
        assertEquals("备份文件校验失败", failure.userMessage)
        assertEquals("contentSha256=number", failure.damage)
    }

    // ==========================================================
    // 4. 缺必需字段
    // ==========================================================

    @Test
    fun `缺 profiles 与 timeSchemes 报缺少课表数据`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.MISSING_REQUIRED_FIELDS, failure.kind)
        assertEquals("missing_sync_timetable_data", failure.errorCode)
        assertEquals("缺少云同步课表数据", failure.userMessage)
        assertEquals("profiles=absent; timeSchemes=absent", failure.damage)
    }

    @Test
    fun `profiles 是对象而不是数组时留档类型`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"profiles":{"id":"p1"},"timeSchemes":[]}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.MISSING_REQUIRED_FIELDS, failure.kind)
        assertEquals("缺少云同步课表数据", failure.userMessage)
        assertEquals("profiles=object; timeSchemes=array", failure.damage)
    }

    // ==========================================================
    // 5. 空文件
    // ==========================================================

    @Test
    fun `空文件报无法读取并留档字节数`() {
        val failure = failure(BackupFileReadLogic.read(""))

        assertEquals(BackupFileFailureKind.EMPTY_FILE, failure.kind)
        assertEquals("无法读取所选文件", failure.userMessage)
        assertEquals("chars=0; bytes=0", failure.damage)
        assertNull(failure.errorCode)
    }

    @Test
    fun `纯空白文件也归为空文件`() {
        // 刻意差异：Dart 只判 isEmpty，纯空白会掉进 JSON 解析并报语法错；
        // 本层认为「文件里什么都没有」更贴近事实，文案与 Dart 空文件分支同一句。
        val failure = failure(BackupFileReadLogic.read("  \n\t"))

        assertEquals(BackupFileFailureKind.EMPTY_FILE, failure.kind)
        assertEquals("无法读取所选文件", failure.userMessage)
        assertEquals("chars=4; bytes=4", failure.damage)
    }

    // ==========================================================
    // 6. 超大文件
    // ==========================================================

    @Test
    fun `默认上限就是 Dart 的 20 MB`() {
        // 20 * 1024 * 1024 = 20971520；formatByteBudget 四舍五入到整数 MB → 20 MB
        assertEquals(20971520, BackupFileReadLogic.MAX_FILE_BYTES)
        assertEquals("20 MB", BackupFileReadLogic.formatByteBudget(20971520L))
    }

    @Test
    fun `超过字节上限报文件过大且文案带尺寸`() {
        // 注入 64 字节上限（不造 20 MB 字符串）：22 个汉字 = 66 字节 > 64
        val failure = failure(BackupFileReadLogic.read("课".repeat(22), maxBytes = 64))

        assertEquals(BackupFileFailureKind.FILE_TOO_LARGE, failure.kind)
        assertEquals("文件超出大小上限 64 B，请选择较小的文件", failure.userMessage)
        assertEquals("bytes=66; limit=64", failure.damage)
        assertNull(failure.errorCode)
    }

    @Test
    fun `尺寸按 UTF-8 字节算而不是字符数`() {
        // 25 个汉字 = 75 字节 > 64，但字符数 25 < 64：按字符算就会漏判。
        val failure = failure(BackupFileReadLogic.read("课".repeat(25), maxBytes = 64))
        assertEquals(BackupFileFailureKind.FILE_TOO_LARGE, failure.kind)
        assertEquals("bytes=75; limit=64", failure.damage)
    }

    @Test
    fun `尺寸门先于内容判定`() {
        // 内容本身是合法快照，但上限设成 8 字节：必须先报「过大」，不能读成成功。
        val failure = failure(BackupFileReadLogic.read(validContent, maxBytes = 8))

        assertEquals(BackupFileFailureKind.FILE_TOO_LARGE, failure.kind)
        assertEquals("文件超出大小上限 8 B，请选择较小的文件", failure.userMessage)
    }

    // ==========================================================
    // 7. 版本不支持
    // ==========================================================

    @Test
    fun `schemaVersion 不是 2 报不是可识别的备份文件`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":3,""" +
            """"profiles":[{"id":"p1"}],"timeSchemes":[]}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.UNSUPPORTED_VERSION, failure.kind)
        assertEquals("unrecognized_sync_snapshot", failure.errorCode)
        assertEquals("不是可识别的 mikcb 备份文件", failure.userMessage)
        assertEquals("app=\"mikcb\"; schemaVersion=3; backupType=\"sync\"", failure.damage)
    }

    @Test
    fun `schemaVersion 是字符串时同样不认`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":"2",""" +
            """"profiles":[{"id":"p1"}],"timeSchemes":[]}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.UNSUPPORTED_VERSION, failure.kind)
        // 字符串带引号，留档能区分 schemaVersion=2 与 schemaVersion="2"
        assertEquals("app=\"mikcb\"; schemaVersion=\"2\"; backupType=\"sync\"", failure.damage)
    }

    @Test
    fun `别的 App 的文件与错的 backupType 都不认`() {
        val otherApp = failure(
            BackupFileReadLogic.read("""{"app":"other","backupType":"sync","schemaVersion":2}"""),
        )
        assertEquals(BackupFileFailureKind.UNSUPPORTED_VERSION, otherApp.kind)
        assertEquals("不是可识别的 mikcb 备份文件", otherApp.userMessage)

        val wrongType = failure(
            BackupFileReadLogic.read("""{"app":"mikcb","backupType":"full","schemaVersion":2}"""),
        )
        assertEquals(BackupFileFailureKind.UNSUPPORTED_VERSION, wrongType.kind)
        assertEquals("app=\"mikcb\"; schemaVersion=2; backupType=\"full\"", wrongType.damage)
    }

    // ==========================================================
    // 8. 元数据非法
    // ==========================================================

    @Test
    fun `元数据字段类型非法报无法识别并列出坏字段`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"exportedAt":1730000000,"profiles":[{"id":"p1"}],"timeSchemes":[]}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.META_INVALID, failure.kind)
        assertEquals("invalid_sync_snapshot_meta", failure.errorCode)
        assertEquals("备份文件无法识别", failure.userMessage)
        assertEquals("exportedAt=number", failure.damage)
    }

    @Test
    fun `多个坏元数据字段全部列出且按固定键序`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"exportedAt":1,"snapshotPath":{"a":1},"deviceId":"ok",""" +
            """"profiles":[{"id":"p1"}],"timeSchemes":[]}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.META_INVALID, failure.kind)
        assertEquals("exportedAt=number; snapshotPath=object", failure.damage)
    }

    // ==========================================================
    // 9. 没有可恢复的课表
    // ==========================================================

    @Test
    fun `课表列表为空时报没有可恢复的课表`() {
        val content = """{"app":"mikcb","backupType":"sync","schemaVersion":2,""" +
            """"profiles":[],"timeSchemes":[{"id":"t1"},{"id":"t2"}]}"""
        val failure = failure(BackupFileReadLogic.read(content))

        assertEquals(BackupFileFailureKind.NO_PROFILES, failure.kind)
        assertEquals("sync_snapshot_no_profiles", failure.errorCode)
        assertEquals("备份文件里没有可恢复的课表", failure.userMessage)
        assertEquals("profiles=0; timeSchemes=2", failure.damage)
    }

    // ==========================================================
    // 10. 纯函数
    // ==========================================================

    @Test
    fun `UTF-8 字节数与 JVM 编码结果一致`() {
        val samples = listOf(
            "" to 0,
            "abc" to 3,
            "课表" to 6,
            "a课" to 4,
            "😀" to 4,          // U+1F600：代理对 → 4 字节
            "a😀课" to 8,        // 1 + 4 + 3
            "\u007F" to 1,       // ASCII 边界
            "\u0080" to 2,       // 2 字节段下界
            "\u07FF" to 2,       // 2 字节段上界
            "\u0800" to 3,       // 3 字节段下界
            "\uD83D" to 1,       // 孤立高代理：JVM 编码成 '?' → 1 字节
        )
        for ((text, expected) in samples) {
            assertEquals("UTF-8 字节数：${text.map { it.code }}", expected, BackupFileReadLogic.utf8ByteLength(text))
            assertEquals(
                "与 toByteArray 不一致：${text.map { it.code }}",
                text.toByteArray(Charsets.UTF_8).size,
                BackupFileReadLogic.utf8ByteLength(text),
            )
        }
    }

    @Test
    fun `字节预算格式化边界值`() {
        // Dart formatByteBudget 的三段口径：<1KB 原样 B；<1MB 四舍五入 KB；否则四舍五入 MB
        assertEquals("512 B", BackupFileReadLogic.formatByteBudget(512))
        assertEquals("1023 B", BackupFileReadLogic.formatByteBudget(1023))
        assertEquals("1 KB", BackupFileReadLogic.formatByteBudget(1024))
        assertEquals("2 KB", BackupFileReadLogic.formatByteBudget(1536))
        assertEquals("1 MB", BackupFileReadLogic.formatByteBudget(1024L * 1024))
        assertEquals("2 MB", BackupFileReadLogic.formatByteBudget(1024L * 1024 * 3 / 2))
    }

    @Test
    fun `损坏值片段超长才截断`() {
        assertEquals("short", BackupFileReadLogic.damageSnippet("short"))
        assertEquals("x".repeat(160), BackupFileReadLogic.damageSnippet("x".repeat(160)))
        assertEquals("x".repeat(160) + "…(+1)", BackupFileReadLogic.damageSnippet("x".repeat(161)))
    }

    // ==========================================================
    // 工具
    // ==========================================================

    private fun success(result: BackupFileReadResult): BackupFileReadResult.Success {
        assertTrue("期望读成功，实际：$result", result is BackupFileReadResult.Success)
        return result as BackupFileReadResult.Success
    }

    private fun failure(result: BackupFileReadResult): BackupFileReadResult.Failure {
        assertTrue("期望读失败，实际：$result", result is BackupFileReadResult.Failure)
        return result as BackupFileReadResult.Failure
    }

    /** 测试侧独立实现的 SHA-256（十六进制小写），不复用生产代码。 */
    private fun sha256Hex(text: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}
