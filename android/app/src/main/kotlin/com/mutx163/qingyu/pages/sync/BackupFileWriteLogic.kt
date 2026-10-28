package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_CHECKSUM_FAILED
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_CHECKSUM_INVALID
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_MISSING_TIMETABLE
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_UNRECOGNIZED
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.computeContentSha256

/**
 * 备份文件写出模型（C2「备份还原页」的**另一半**：`快照负载 → 可保存的全量 JSON 字符串`）。
 *
 * ## 与 [BackupFileReadLogic] 的关系
 *
 * [BackupFileReadLogic] 把「文件内容 String → 快照 + 元数据」读进来；本对象把「快照负载 Map」
 * 写出去。两者共用 `main/sync/AppSyncSnapshotCodec.kt` 的信封与校验和口径
 * （[computeContentSha256] / [checkSnapshotEnvelopeAndChecksum]），所以
 * **[BackupFileWriteLogic.write] 的产物一定能被 [BackupFileReadLogic.read] 读回 Success**
 * ——这条「写→读」自洽不是口号，见第 ⑤ 步的自检门与 `BackupFileWriteLogicTest` 的往返用例。
 *
 * ## 对齐 Dart 的两处口径
 *
 * 1. **`contentSha256` 用重算值**（Dart `buildSnapshotJsonFromSnapshot` 的
 *    `_verifiedContentSha`，`lib/services/app_sync_snapshot_service.dart:413-473`）：
 *    快照对象经过「解码→再编码」往返或跨版本字段演化后，自带的哈希描述的已不是这份内容，
 *    透传旧值等于给接收端埋一发必然的校验失败。本对象默认写重算值；调用方若明确声明过一个
 *    非空哈希，对本对象而言这只是「期望值」，与重算不符时仍以重算为准并标记 [WriteSuccess.checksumDrift]。
 * 2. **空串哈希是「刻意不带哈希」的标记**：Dart 对空串声明原样返回、不补真哈希（有测试靠删键
 *    构造旧格式快照）。本对象把它映射成 [declaredSha256] 传空串 → 文件里写 `"contentSha256": ""`，
 *    读侧据此跳过校验（`checksumVerified == false`，不是失败）。
 *
 * ## 信封 / 空课表也是硬门（保证「写出的文件一定能读」）
 *
 * [BackupFileReadLogic.read] 会拒 `app/schemaVersion/backupType` 不认识、`profiles`/`timeSchemes`
 * 不是数组、以及 `profiles: []`。本对象在第 ⑤ 步用**同一套判据**先自检一遍：写不出一份能读回的
 * 备份就返回 [WriteFailure]，不产出「看起来像备份、恢复时才发现读不了」的文件。
 *
 * ## 不在这一层（诚实清单）
 *
 * SAF 选文件 / 建文件、Uri→字节、字节→Uri 都在 `main: platform/AndroidSafBackupAdapter.kt`；
 * 本层零 `android.*` 依赖，可纯 JVM 单测。把快照写回仓储（`applySnapshot*`）属仓储原子入口
 * （台账 §9.4 ③），也不在这里。
 */
object BackupFileWriteLogic {

    /** 缩进单位（对齐 Dart `JsonEncoder.withIndent('  ')`，两个空格）。 */
    const val INDENT: String = "  "

    /** 写出字节上限，与读取侧共用同一常量（Dart `UnifiedTransferService.maxImportFileBytes` = 20 MB）。 */
    const val MAX_FILE_BYTES: Int = BackupFileReadLogic.MAX_FILE_BYTES

    /**
     * 把一个快照负载序列化成「可被 [BackupFileReadLogic.read] 读回」的全量 JSON 文本。
     *
     * @param snapshot 快照负载对象。通常是 [BackupFileReadLogic.read] 成功返回的
     *   [BackupFileReadResult.Success.snapshot]（已去掉 contentSha256），也可以是页面从仓储
     *   新组的同一形状 Map。无论是否已带 `contentSha256`，本方法都先把它剥掉再重算，绝不会
     *   把调用方的旧哈希当成本次内容描述透传出去。
     * @param declaredSha256 调用方的哈希声明（可选，默认 null）：
     *   - `null`（默认）：写**重算值**，得到一份自校验的备份（读回时 `checksumVerified == true`）；
     *   - `""`（空串）：按 Dart 口径「刻意不带哈希」，文件里写空串，读侧跳过校验；
     *   - 非空：仅作为「期望值」参与对账——与重算一致则写它，不一致则写重算值并标 drift。
     * @param maxBytes 字节上限；默认 [MAX_FILE_BYTES]。可注入小值让单测不必造 20 MB 字符串。
     * @param indent 缩进字符串，默认两空格；传空串可得紧凑 JSON（键序不变，仍可读回）。
     * @return 成功带 JSON 文本 / 字节数 / 实际写入的哈希 / drift 标记；失败带分类与留档。
     */
    fun write(
        snapshot: Map<String, Any?>,
        declaredSha256: String? = null,
        maxBytes: Int = MAX_FILE_BYTES,
        indent: String = INDENT,
    ): BackupFileWriteResult {
        // ① 剥掉任何旧 hash，确保它不混进本次哈希输入（read 也总是先去掉再算）
        val body: LinkedHashMap<String, Any?> = LinkedHashMap(snapshot)
        body.remove("contentSha256")

        // ② 重算内容哈希（与读侧 computeContentSha256 完全同口径：排 exportedAt/deviceId/contentSha256）
        val actualSha = computeContentSha256(body)

        // ③ 决定这份文件该写哪个哈希（Dart `_verifiedContentSha` 的投影）
        val drift = !declaredSha256.isNullOrEmpty() && declaredSha256 != actualSha
        val embeddedSha: String = when {
            declaredSha256 == null -> actualSha          // 默认：自校验备份
            declaredSha256.isEmpty() -> ""               // 刻意不带哈希
            declaredSha256 == actualSha -> declaredSha256
            else -> actualSha                            // 声明失效 → 用重算值（并记 drift）
        }

        // ④ 组装带 hash 的完整对象（hash 键追加在末尾，和 Dart 对 payload 赋值的位置一致）
        val withHash = LinkedHashMap(body)
        withHash["contentSha256"] = embeddedSha

        // ⑤ 自检：产物必须能被读侧的信封/校验和/空课表三道门放行，否则不产出文件
        val envelope = checkSnapshotEnvelopeAndChecksum(withHash)
        if (!envelope.isValid) {
            val code = envelope.errorCode
            return WriteFailure(
                kind = writeKindForEnvelope(code),
                detail = "envelope=$code; expected=${envelope.expectedHash}; actual=${envelope.actualHash}",
            )
        }
        val profiles = withHash["profiles"] as? List<*>
        if ((profiles?.size ?: 0) == 0) {
            val timeSchemeCount = (withHash["timeSchemes"] as? List<*>)?.size ?: 0
            return WriteFailure(
                kind = BackupFileWriteFailureKind.NO_PROFILES,
                detail = "profiles=0; timeSchemes=$timeSchemeCount",
            )
        }

        // ⑥ 序列化 + 字节上限（读侧会按 UTF-8 字节再量一次；这里先挡住，别产出读不回的文件）
        val content = try {
            encodePretty(withHash, indent)
        } catch (e: Exception) {
            return WriteFailure(
                kind = BackupFileWriteFailureKind.SERIALIZE_FAILED,
                detail = e.message ?: e.javaClass.simpleName,
            )
        }
        val byteLength = BackupFileReadLogic.utf8ByteLength(content)
        if (byteLength > maxBytes) {
            return WriteFailure(
                kind = BackupFileWriteFailureKind.TOO_LARGE,
                detail = "bytes=$byteLength; limit=$maxBytes",
            )
        }

        return WriteSuccess(
            content = content,
            byteLength = byteLength,
            embeddedSha256 = embeddedSha,
            checksumEmbedded = embeddedSha.isNotEmpty(),
            checksumDrift = drift,
        )
    }

    private fun writeKindForEnvelope(code: String?): BackupFileWriteFailureKind = when (code) {
        SNAPSHOT_PARSE_ERROR_UNRECOGNIZED -> BackupFileWriteFailureKind.ENVELOPE_UNRECOGNIZED
        SNAPSHOT_PARSE_ERROR_MISSING_TIMETABLE -> BackupFileWriteFailureKind.MISSING_REQUIRED_FIELDS
        SNAPSHOT_PARSE_ERROR_CHECKSUM_INVALID -> BackupFileWriteFailureKind.CHECKSUM_INVALID
        SNAPSHOT_PARSE_ERROR_CHECKSUM_FAILED -> BackupFileWriteFailureKind.CHECKSUM_FAILED
        else -> BackupFileWriteFailureKind.ENVELOPE_UNRECOGNIZED
    }

    // ------------------------------------------------------------------
    // JSON 序列化（2 空格缩进；标量格式与 core.MiniJson 逐条对齐，保证读回类型不变）
    // ------------------------------------------------------------------

    /**
     * 缩进 JSON 编码（对齐 Dart `JsonEncoder.withIndent`，真正的 `"key": value` 形态）。
     *
     * **标量口径刻意与 [com.mutx163.qingyu.core.MiniJson] 的 `encode` 保持一致**：
     * `Int`/`Long` 写整数、`Double`/`Float` 整数值补 `.0`（`2.0` 而不是 `2`）、
     * 非有限值写 `null`、字符串转义规则同 `MiniJson.writeString`、非 ASCII 不转义。
     * 这样 `encodePretty(...)` → `MiniJson.parse` 的类型与值与原树一致，
     * 而 [computeContentSha256] 对 Int/Long/Double 的 canonical 形态在任何一侧都相同，
     * 往返后重算的哈希与写出前一致。
     */
    fun encodePretty(value: Any?, indent: String = INDENT): String {
        val sb = StringBuilder()
        writePretty(sb, value, 0, indent)
        return sb.toString()
    }

    private fun writePretty(sb: StringBuilder, value: Any?, depth: Int, indent: String) {
        when (value) {
            null -> sb.append("null")
            is String -> writeJsonString(sb, value)
            is Boolean -> sb.append(if (value) "true" else "false")
            is Int, is Long -> sb.append(value.toString())
            is Double -> sb.append(formatDouble(value))
            is Float -> sb.append(formatDouble(value.toDouble()))
            is Map<*, *> -> {
                if (value.isEmpty()) {
                    sb.append("{}")
                    return
                }
                val inner = indent.repeat(depth + 1)
                sb.append("{\n")
                var first = true
                for ((k, v) in value) {
                    if (!first) sb.append(",\n")
                    first = false
                    sb.append(inner)
                    writeJsonString(sb, k.toString())
                    sb.append(": ")
                    writePretty(sb, v, depth + 1, indent)
                }
                sb.append('\n').append(indent.repeat(depth)).append('}')
            }
            is Iterable<*> -> {
                val items = value.toList()
                if (items.isEmpty()) {
                    sb.append("[]")
                    return
                }
                val inner = indent.repeat(depth + 1)
                sb.append("[\n")
                items.forEachIndexed { index, item ->
                    if (index > 0) sb.append(",\n")
                    sb.append(inner)
                    writePretty(sb, item, depth + 1, indent)
                }
                sb.append('\n').append(indent.repeat(depth)).append(']')
            }
            else -> writeJsonString(sb, value.toString())
        }
    }

    private fun formatDouble(d: Double): String {
        if (d.isNaN() || d.isInfinite()) return "null"
        // 整数值（含负）补齐 .0，与 Dart jsonEncode / MiniJson 同口径。
        return if (d == Math.floor(d) && Math.abs(d) < 1e15) {
            d.toLong().toString() + ".0"
        } else {
            d.toString()
        }
    }

    private fun writeJsonString(sb: StringBuilder, value: String) {
        sb.append('"')
        for (ch in value) {
            when {
                ch == '"' -> sb.append("\\\"")
                ch == '\\' -> sb.append("\\\\")
                ch == '\b' -> sb.append("\\b")
                ch == '\u000C' -> sb.append("\\f")
                ch == '\n' -> sb.append("\\n")
                ch == '\r' -> sb.append("\\r")
                ch == '\t' -> sb.append("\\t")
                ch < ' ' -> sb.append("\\u").append(ch.code.toString(16).padStart(4, '0'))
                else -> sb.append(ch)
            }
        }
        sb.append('"')
    }
}

/** 写出失败的种类。 */
enum class BackupFileWriteFailureKind {

    /** `app` / `schemaVersion` / `backupType` 不是合法的 mikcb sync 信封。 */
    ENVELOPE_UNRECOGNIZED,

    /** `profiles` / `timeSchemes` 不在场或不是数组。 */
    MISSING_REQUIRED_FIELDS,

    /** `contentSha256` 形态非法（本对象正常路径不会产生，留作自检兜底）。 */
    CHECKSUM_INVALID,

    /** 校验和对不上（本对象重算后写，正常路径不会产生，留作自检兜底）。 */
    CHECKSUM_FAILED,

    /** 一张课表都没有——写出的备份没有恢复意义，与读侧 `NO_PROFILES` 同判据。 */
    NO_PROFILES,

    /** 序列化后超过字节上限（[BackupFileWriteLogic.MAX_FILE_BYTES]）。 */
    TOO_LARGE,

    /** 序列化本身抛错（本对象自带编码器，正常不可达，兜底用）。 */
    SERIALIZE_FAILED,
}

/** 写出结果。 */
sealed interface BackupFileWriteResult

/**
 * 写出成功。
 *
 * @param content 可直接落盘的 JSON 文本（含 `contentSha256` 键）。
 * @param byteLength content 的 UTF-8 字节数（读侧按同一口径量）。
 * @param embeddedSha256 实际写进文件的哈希；空串 = 刻意不带哈希。
 * @param checksumEmbedded 是否带了非空哈希（等价于 [embeddedSha256] 非空）。
 * @param checksumDrift 调用方声明过非空哈希但与重算不符、已改用重算值。true 说明调用方
 *   手上的快照已经「漂移」（解码→再编码过的旧对象），值得在接线层记一条诊断。
 */
data class WriteSuccess(
    val content: String,
    val byteLength: Int,
    val embeddedSha256: String,
    val checksumEmbedded: Boolean,
    val checksumDrift: Boolean,
) : BackupFileWriteResult

/**
 * 写出失败。
 *
 * @param kind 失败分类。
 * @param detail 诊断留档（命中的错误码 / expected-actual 哈希对 / 字节-上限 / 异常信息）。
 */
data class WriteFailure(
    val kind: BackupFileWriteFailureKind,
    val detail: String,
) : BackupFileWriteResult
