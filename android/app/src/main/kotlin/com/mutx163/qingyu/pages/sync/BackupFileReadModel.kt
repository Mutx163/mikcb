package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_CHECKSUM_FAILED
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_CHECKSUM_INVALID
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_MISSING_TIMETABLE
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID
import com.mutx163.qingyu.sync.SNAPSHOT_PARSE_ERROR_UNRECOGNIZED
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.decodeSnapshotObject
import com.mutx163.qingyu.sync.parseSnapshotMetaFields

/**
 * 备份文件读取模型（C2「备份还原页」的模型半边：`SAF 选文件 → 内容 String → 读模型`）。
 *
 * ## 这一层负责什么
 *
 * 把用户选中的备份文件**内容**（已解码成 String）变成两种结果之一：
 *
 * - [BackupFileReadResult.Success]：可恢复的快照负载（已去掉 `contentSha256` 的 JSON 对象）
 *   + 元数据（导出时间 / 哈希 / 设备 / 版本 / 远端路径），交给页面预览与写入；
 * - [BackupFileReadResult.Failure]：一种失败 + **一句屏上文案** + **损坏值留档**
 *   （`damage`，让下一次排查一眼看出「坏在哪」）。
 *
 * 判定链复用已交付的 `main/sync/AppSyncSnapshotCodec.kt`（**只读取、不修改**）：
 * [decodeSnapshotObject] → [checkSnapshotEnvelopeAndChecksum] → [parseSnapshotMetaFields]。
 * 本层只补它**没有**的三件事：
 *
 * 1. **资源上限**（Dart `UnifiedTransferService.maxImportFileBytes` = 20 MB）：超过就先拒，
 *    绝不把整包读进解析器（Android 上 OOM 是直接杀进程，catch 不到）；
 * 2. **空文件**（Dart `data_transfer_screen.dart:419` 的 `content.isEmpty` 门）；
 * 3. **失败分类 → 屏上文案**的映射表（Dart 侧那张表在
 *    `lib/l10n/service_message_localizer.dart`；本模块见 [BackupFileStrings] 与
 *    [CoupleStrings]），以及**损坏值留档**。
 *
 * ## 与 Dart 的三处刻意差异（都写进验收，别当漏项）
 *
 * 1. **纯空白文件归为「空文件」**：Dart 只判 `content.isEmpty`，只含空格/换行的文件会
 *    落到 JSON 解析并报解析错；本层把 `isBlank()` 也归为 [BackupFileFailureKind.EMPTY_FILE]
 *    （同一句文案「无法读取所选文件」），因为「文件里什么都没有」比「JSON 语法错」更贴近事实。
 * 2. **字节数按 UTF-8 现算**（[utf8ByteLength]），不依赖调用方先量文件大小。Dart 是在读
 *    之前用 `File.length()` 量的；本层拿到的已经是 String，所以按同一口径（UTF-8 字节）
 *    重算，保证「一个汉字算 3 字节」而不是「1 个字符」。
 * 3. **多一道「一张课表都没有」的门**：`profiles: []` 能过信封门，但恢复它没有任何意义，
 *    按 Dart `sync_snapshot_no_profiles` 的味道直接拒（复用 ARB 既有键，见 [BackupFileStrings]）。
 *
 * ## 不在这一层（诚实清单）
 *
 * SAF 选文件、文件字节读入、以及把快照写回仓储（`applySnapshot*`）都不在这里：
 * 前者属 `main: platform/` 的适配器批次，后者属仓储原子入口（台账 §9.4 ③）。
 * 本层零 `android.*` 依赖，可纯 JVM 单测。
 */
object BackupFileReadLogic {

    /**
     * 备份文件字节上限（Dart `UnifiedTransferService.maxImportFileBytes` =
     * `20 * 1024 * 1024`，`lib/services/unified_transfer_service.dart:142`）。
     *
     * 存在的理由不是「判正确性」，而是拒绝一个离谱的大文件在解析前就吃满内存
     * （Dart 原文注释：一份真实课表 JSON 远小于 1~2 MB，这个数只是兜底）。
     */
    const val MAX_FILE_BYTES: Int = 20 * 1024 * 1024

    /** 损坏值留档最多记多少个字符（超出截断并标出还剩多少）。 */
    const val DAMAGE_SNIPPET_LIMIT: Int = 160

    // ------------------------------------------------------------------
    // 入口
    // ------------------------------------------------------------------

    /**
     * 读取一份备份文件内容。
     *
     * @param content 文件内容（UTF-8 解码后的文本）。
     * @param maxBytes 字节上限；默认 [MAX_FILE_BYTES]。可注入小值让单测不必造 20 MB 字符串。
     * @return 成功带快照 + 元数据；失败带分类、错误码、屏上文案、损坏值留档。
     */
    fun read(content: String, maxBytes: Int = MAX_FILE_BYTES): BackupFileReadResult {
        // ① 尺寸门（Dart 在读字节之前量大小；本层拿到的已是 String，按 UTF-8 字节重算）
        val byteLength = utf8ByteLength(content)
        if (byteLength > maxBytes) {
            return BackupFileReadResult.Failure(
                kind = BackupFileFailureKind.FILE_TOO_LARGE,
                errorCode = null,
                userMessage = CoupleStrings.importFileTooLarge.filled(
                    "size",
                    formatByteBudget(maxBytes.toLong()),
                ),
                damage = "bytes=$byteLength; limit=$maxBytes",
            )
        }
        // ② 空文件门
        if (content.isBlank()) {
            return BackupFileReadResult.Failure(
                kind = BackupFileFailureKind.EMPTY_FILE,
                errorCode = null,
                userMessage = CoupleStrings.importFileReadFailed.text,
                damage = "chars=${content.length}; bytes=$byteLength",
            )
        }
        // ③ 根对象解码：JSON 语法错 / 根不是对象都在这里被拦
        val json: Map<String, Any?> = try {
            decodeSnapshotObject(content)
        } catch (e: DartFormatException) {
            return BackupFileReadResult.Failure(
                kind = BackupFileFailureKind.MALFORMED_JSON,
                errorCode = e.message ?: SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID,
                userMessage = CoupleStrings.importFailedInvalidFile.text,
                damage = "snippet=${damageSnippet(content)}",
            )
        } catch (_: Exception) {
            return BackupFileReadResult.Failure(
                kind = BackupFileFailureKind.MALFORMED_JSON,
                errorCode = SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID,
                userMessage = CoupleStrings.importFailedInvalidFile.text,
                damage = "snippet=${damageSnippet(content)}",
            )
        }
        // ④ 信封（app / schemaVersion / backupType）+ 核心列表 + 校验和
        val envelope = checkSnapshotEnvelopeAndChecksum(json)
        if (!envelope.isValid) {
            val code = envelope.errorCode ?: SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID
            return failureForEnvelope(code, json, envelope.expectedHash, envelope.actualHash)
        }
        // ⑤ 元数据（导出时间 / 设备 / 版本）
        val meta = parseSnapshotMetaFields(json)
        if (!meta.isValid) {
            return BackupFileReadResult.Failure(
                kind = BackupFileFailureKind.META_INVALID,
                errorCode = meta.errorCode,
                userMessage = BackupFileStrings.serviceMsgSyncSnapshotUnrecognized.text,
                damage = metaDamage(json),
            )
        }
        // ⑥ 「一张课表都没有」：能过信封门，但恢复它没有意义
        val profiles = json["profiles"] as? List<*>
        val profileCount = profiles?.size ?: 0
        if (profileCount == 0) {
            val timeSchemeCount = (json["timeSchemes"] as? List<*>)?.size ?: 0
            return BackupFileReadResult.Failure(
                kind = BackupFileFailureKind.NO_PROFILES,
                errorCode = BACKUP_FILE_NO_PROFILES_CODE,
                userMessage = BackupFileStrings.serviceMsgSyncSnapshotNoProfiles.text,
                damage = "profiles=0; timeSchemes=$timeSchemeCount",
            )
        }
        // ⑦ 成功：快照负载（去掉 contentSha256 的同一份对象）+ 元数据
        return BackupFileReadResult.Success(
            snapshot = envelope.payloadWithoutHash ?: json,
            meta = BackupFileReadMeta(
                exportedAtIso = meta.exportedAtIso
                    ?: DartTime.toIso(DartTime.fromEpochMillis(0)),
                exportedAtUnparsed = DartTime.tryParseIso(json["exportedAt"] as? String) == null,
                contentSha256 = meta.contentSha256 ?: "",
                deviceId = meta.deviceId ?: "",
                appVersion = meta.appVersion,
                snapshotPath = meta.snapshotPath,
            ),
            // 文件没声明 contentSha256 时 Dart 跳过校验（AppSyncSnapshotCodec 第 5 步），
            // 这里如实回报「本次没有验证过哈希」，页面可以据此提示「缺少校验和」。
            checksumVerified = envelope.expectedHash.isNotEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 失败分类 → 文案 / 留档
    // ------------------------------------------------------------------

    /** 信封三道的错误码 → 分类 + 文案 + 留档（码与文案的对应见 Dart `service_message_localizer.dart`）。 */
    private fun failureForEnvelope(
        code: String,
        json: Map<String, Any?>,
        expectedHash: String,
        actualHash: String,
    ): BackupFileReadResult.Failure = when (code) {
        SNAPSHOT_PARSE_ERROR_UNRECOGNIZED -> BackupFileReadResult.Failure(
            kind = BackupFileFailureKind.UNSUPPORTED_VERSION,
            errorCode = code,
            userMessage = BackupFileStrings.serviceMsgUnrecognizedSyncSnapshot.text,
            damage = envelopeDamage(json),
        )

        SNAPSHOT_PARSE_ERROR_MISSING_TIMETABLE -> BackupFileReadResult.Failure(
            kind = BackupFileFailureKind.MISSING_REQUIRED_FIELDS,
            errorCode = code,
            userMessage = BackupFileStrings.serviceMsgMissingSyncTimetableData.text,
            damage = "profiles=${describeTypeOf(json, "profiles")}; " +
                "timeSchemes=${describeTypeOf(json, "timeSchemes")}",
        )

        SNAPSHOT_PARSE_ERROR_CHECKSUM_INVALID -> BackupFileReadResult.Failure(
            kind = BackupFileFailureKind.CHECKSUM_FIELD_INVALID,
            errorCode = code,
            userMessage = BackupFileStrings.serviceMsgSyncSnapshotChecksumFailed.text,
            damage = "contentSha256=${describeTypeOf(json, "contentSha256")}",
        )

        SNAPSHOT_PARSE_ERROR_CHECKSUM_FAILED -> BackupFileReadResult.Failure(
            kind = BackupFileFailureKind.CHECKSUM_MISMATCH,
            errorCode = code,
            userMessage = BackupFileStrings.serviceMsgSyncSnapshotChecksumFailed.text,
            // 留档的是「声明值 vs 重算值」这对坏值，不是整包内容：
            // 排查要的是哪个哈希对不上，整包 JSON 已经在手上了。
            damage = "expected=$expectedHash; actual=$actualHash",
        )

        // payload 相关（含根不是对象）已经在第 ③ 步拦掉，走到这里说明码是新的，
        // 按「文件本身不可用」处理，并把这个没见过的码留在 errorCode 里。
        else -> BackupFileReadResult.Failure(
            kind = BackupFileFailureKind.MALFORMED_JSON,
            errorCode = code,
            userMessage = CoupleStrings.importFailedInvalidFile.text,
            damage = "code=$code",
        )
    }

    /** 信封值留档：`app=…; schemaVersion=…; backupType=…`（缺键写 `absent`）。 */
    private fun envelopeDamage(json: Map<String, Any?>): String =
        "app=${describeValueOf(json, "app")}; " +
            "schemaVersion=${describeValueOf(json, "schemaVersion")}; " +
            "backupType=${describeValueOf(json, "backupType")}"

    /** 元数据留档：把所有「在场但类型不对」的键列出来（Dart 只报第一条，本层全列更好查）。 */
    private fun metaDamage(json: Map<String, Any?>): String =
        META_KEYS
            .filter { json[it] != null && json[it] !is String }
            .joinToString("; ") { "$it=${describeTypeOf(json, it)}" }

    // ------------------------------------------------------------------
    // 小工具（纯函数，单测直接钉）
    // ------------------------------------------------------------------

    /**
     * UTF-8 字节数（与 `text.toByteArray(Charsets.UTF_8).size` 等价，但不复制整串）。
     *
     * 口径：ASCII 1 字节；`U+0080..U+07FF` 2 字节；其余 BMP 3 字节；成对代理 4 字节；
     * **孤立代理项 1 字节**（JVM 的 UTF-8 编码器把它替换成 `?`，正是 1 字节）。
     */
    fun utf8ByteLength(text: String): Int {
        var total = 0
        var index = 0
        while (index < text.length) {
            val ch = text[index]
            when {
                ch.code < 0x80 -> total += 1
                ch.code < 0x800 -> total += 2
                Character.isHighSurrogate(ch) &&
                    index + 1 < text.length &&
                    Character.isLowSurrogate(text[index + 1]) -> {
                    total += 4
                    index++
                }

                Character.isSurrogate(ch) -> total += 1
                else -> total += 3
            }
            index++
        }
        return total
    }

    /**
     * 字节预算的可读形态：`20 MB` / `2 KB` / `512 B`（四舍五入到整数）。
     *
     * Dart `formatByteBudget`（`lib/utils/import_file_reader.dart:41-49`）原样，
     * 与 `pages/import/ImportSharedModel.kt` 的实现逐字同口径——两处都只是「同一个 Dart
     * 函数的投影」，谁也不能改口径。
     */
    fun formatByteBudget(bytes: Long): String {
        if (bytes >= 1024 * 1024) {
            return "${Math.round(bytes.toDouble() / (1024 * 1024))} MB"
        }
        if (bytes >= 1024) {
            return "${Math.round(bytes.toDouble() / 1024)} KB"
        }
        return "$bytes B"
    }

    /** 损坏值留档的片段：不超过 [limit] 字符，截断时标出还剩多少字符。 */
    fun damageSnippet(text: String, limit: Int = DAMAGE_SNIPPET_LIMIT): String =
        if (text.length <= limit) text else text.take(limit) + "…(+" + (text.length - limit) + ")"

    private val META_KEYS = listOf("exportedAt", "contentSha256", "deviceId", "appVersion", "snapshotPath")

    /** 值的 JSON 类型名；键不在场 → `absent`。 */
    private fun describeTypeOf(json: Map<String, Any?>, key: String): String {
        if (!json.containsKey(key)) return "absent"
        return describeType(json[key])
    }

    private fun describeType(value: Any?): String = when (value) {
        null -> "null"
        is String -> "string"
        is Boolean -> "boolean"
        is Map<*, *> -> "object"
        is List<*> -> "array"
        is Number -> "number"
        else -> value.javaClass.simpleName
    }

    /**
     * 标量值原样；**字符串带引号**（否则 `schemaVersion: 2` 与 `"2"` 在留档里长得一样，
     * 而这两者恰好一个合法一个非法）；容器值退回类型名；键不在场 → `absent`。
     */
    private fun describeValueOf(json: Map<String, Any?>, key: String): String {
        if (!json.containsKey(key)) return "absent"
        return when (val value = json[key]) {
            null -> "null"
            is String -> "\"" + (if (value.length <= 32) value else value.take(32) + "…") + "\""
            is Boolean -> value.toString()
            is Number -> value.toString()
            else -> describeType(value)
        }
    }
}

/**
 * 「快照里一张课表都没有」的内部码（Dart `sync_snapshot_no_profiles`）。
 *
 * 只做诊断留档，**不上屏**——屏上文案是 ARB 里的
 * `serviceMsgSyncSnapshotNoProfiles`（见 [BackupFileStrings]）。
 */
const val BACKUP_FILE_NO_PROFILES_CODE = "sync_snapshot_no_profiles"

/**
 * 备份文件读取失败的种类。每一种都对应一句**确定的**屏上文案（映射表见
 * [BackupFileReadLogic.read] 与 [BackupFileStrings] 的头注释）。
 */
enum class BackupFileFailureKind {

    /** 文件里什么都没有（含纯空白）。 */
    EMPTY_FILE,

    /** 超过字节上限（20 MB），在读进解析器之前就拒。 */
    FILE_TOO_LARGE,

    /** 不是合法 JSON，或根不是对象。 */
    MALFORMED_JSON,

    /**
     * 信封不认识：不是 mikcb 的 sync 快照，或 `schemaVersion` 不是 2。
     *
     * 两者在 ARB 里共用同一句文案（见 [BackupFileStrings] 头注释的已知缺口）。
     */
    UNSUPPORTED_VERSION,

    /** `profiles` / `timeSchemes` 不在场或不是数组。 */
    MISSING_REQUIRED_FIELDS,

    /** `contentSha256` 在场但不是字符串。 */
    CHECKSUM_FIELD_INVALID,

    /** 声明的 `contentSha256` 与按内容重算的不一致。 */
    CHECKSUM_MISMATCH,

    /** 快照合法但一张课表都没有，恢复没有意义。 */
    NO_PROFILES,

    /** 元数据字段类型非法（如 `exportedAt` 是数字）。 */
    META_INVALID,
}

/** 备份文件里读出来的元数据（Dart `AppSyncSnapshotMeta.fromJson` 的投影）。 */
data class BackupFileReadMeta(
    /** `exportedAt` 的 ISO 形态；文件里没写或写坏时回落纪元零点（与 Dart 一致）。 */
    val exportedAtIso: String,
    /**
     * `exportedAt` 是否**没写或写坏**。
     *
     * 为 true 时 [exportedAtIso] 是纪元零点兜底值，页面应当**不要**显示这个时间
     * （否则屏上会出现 1970 年），改为只显示设备/版本。
     */
    val exportedAtUnparsed: Boolean,
    /** 文件声明的哈希（没带则是空串）。 */
    val contentSha256: String,
    /** 导出设备 id（没带则是空串）。 */
    val deviceId: String,
    val appVersion: String?,
    val snapshotPath: String?,
)

/** 备份文件读取结果。 */
sealed interface BackupFileReadResult {

    /**
     * 读成功。
     *
     * @param snapshot 可恢复的快照负载（**已去掉 `contentSha256`**，与 Dart
     *   `parseSnapshotJson` 的 `payloadWithoutHash` 同口径），键序保持文件里的原序。
     * @param checksumVerified 本次是否真的验过哈希；false = 文件里没带 `contentSha256`，
     *   Dart 口径下跳过校验（不是失败，但页面可以提示「缺少校验和」）。
     */
    data class Success(
        val snapshot: Map<String, Any?>,
        val meta: BackupFileReadMeta,
        val checksumVerified: Boolean,
    ) : BackupFileReadResult

    /**
     * 读失败。
     *
     * @param kind 失败分类。
     * @param errorCode 上游错误码原文（Dart `FormatException.message`），只做诊断；
     *   空文件 / 超大文件在 Dart 侧没有码，这里是 null。
     * @param userMessage 屏上文案（逐字来自 ARB，见 [BackupFileStrings] / [CoupleStrings]）。
     * @param damage 损坏值留档：坏在哪（原始片段 / 哈希对 / 非法字段类型），便于下一次排查。
     */
    data class Failure(
        val kind: BackupFileFailureKind,
        val errorCode: String?,
        val userMessage: String,
        val damage: String,
    ) : BackupFileReadResult
}
