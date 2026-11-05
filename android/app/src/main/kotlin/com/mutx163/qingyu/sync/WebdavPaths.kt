package com.mutx163.qingyu.sync

/**
 * 远端路径 / ETag 比对 / 字节比对纯逻辑。
 *
 * 源：
 * - lib/services/webdav_client_service.dart（`isSecureUrl`、默认 30s 超时）；
 * - lib/services/webdav_sync_service.dart（`_versionedSnapshotRemotePath`、
 *   `_resolveRemoteSnapshotPath`、`_remoteMetaChanged`、`_bytesEqual`）；
 * - lib/services/couple_webdav_service.dart（pull 的 unchanged 短路）。
 *
 * 不做网络收发：只做传给客户端之前的字符串/字节判定。
 */

/**
 * 读/写单次操作的**读超时**预算（Dart `webdav_client_service.dart` 默认 30s 同值）。
 *
 * 2026-11-05 审核修复：原先这一个值同时当 connect 与 read 超时（弱网下死主机要等满
 * 30s 才报错）。现在拆开——连接建立走 [DEFAULT_CONNECT_TIMEOUT_MILLIS]，
 * 本值只管「连上之后」的读写。
 */
const val DEFAULT_OPERATION_TIMEOUT_MILLIS = 30_000L

/**
 * 连接建立（TCP + TLS 握手）预算：**2026-11-05 审核修复，从 30s 拆出 10s**。
 *
 * 依据：握手只含一个 RTT 级别的往返 + TLS 握手，正常服务 10s 绰绰有余；
 * 连不上的主机（DNS 污染 / 端口被封 / 服务下线）不值得等满整个 30s 操作预算——
 * 10s 见分晓，配合读操作的一次重试，最坏路径（10s + 0.8s 退避 + 10s）也比
 * 旧版单次 30s 更快给出结论。读超时（快照体在弱网下慢速到达）保持 30s 不动。
 */
const val DEFAULT_CONNECT_TIMEOUT_MILLIS = 10_000L

/**
 * 是否 HTTPS（Dart `WebdavConnectionParams.isSecureUrl` 原样）。
 * 仅作提示用，http 是否放行由 scheme 门禁决定。
 */
fun isSecureUrl(url: String): Boolean =
    url.trim().lowercase().startsWith("https://")

/**
 * 版本化快照远端路径（Dart `_versionedSnapshotRemotePath` 原样）。
 * deviceId 只留 `[A-Za-z0-9_.-]`，其余填 `_`；全空回落 `device`。
 */
fun versionedSnapshotRemotePath(
    normalizedRemoteFolder: String,
    contentSha256: String,
    exportedAtUtcMicros: Long,
    deviceId: String,
): String {
    val safeDeviceId = deviceId.replace(Regex("[^A-Za-z0-9_.-]"), "_")
    val devicePart = if (safeDeviceId.isEmpty()) "device" else safeDeviceId
    return "${normalizedRemoteFolder}snapshot-${contentSha256}-" +
        "${exportedAtUtcMicros}-$devicePart.mikcb"
}

/**
 * 远端快照指针解析（Dart `_resolveRemoteSnapshotPath` 原样）。
 * @param snapshotRemotePath legacy 单文件路径（空 rawPath 时的回落）。
 * @return 合法单段路径；穿越/反斜杠/子目录/跨目录一律 null（调用方按失败处理）。
 */
fun resolveRemoteSnapshotPath(
    normalizedRemoteFolder: String,
    snapshotRemotePath: String,
    rawPath: String?,
): String? {
    val candidateRaw = rawPath?.trim()
    if (candidateRaw.isNullOrEmpty()) {
        return snapshotRemotePath
    }
    val candidate = if (candidateRaw.startsWith("/")) {
        candidateRaw
    } else {
        "$normalizedRemoteFolder$candidateRaw"
    }
    if (!candidate.startsWith(normalizedRemoteFolder)) return null
    if (candidate.contains("..") || candidate.contains("\\")) return null
    val relative = candidate.substring(normalizedRemoteFolder.length)
    if (relative.isEmpty() || relative.contains("/")) return null
    return candidate
}

/** `_remoteMetaChanged` 的无客户端投影（Dart 字段逐一比对）。 */
data class RemoteMetaState(
    val isNotFound: Boolean,
    /** false 表 meta 为 null（Dart beforeMeta/afterMeta null 分支）。 */
    val metaPresent: Boolean = !isNotFound,
    val contentSha256: String? = null,
    val deviceId: String? = null,
    val exportedAtMillis: Long? = null,
    val snapshotPath: String? = null,
    val etag: String? = null,
)

/** 远端 meta 是否漂移（Dart `_remoteMetaChanged` 原样）。 */
fun remoteMetaChanged(before: RemoteMetaState, after: RemoteMetaState): Boolean {
    if (before.isNotFound || after.isNotFound) {
        return before.isNotFound != after.isNotFound
    }
    if (!before.metaPresent || !after.metaPresent) {
        return before.metaPresent != after.metaPresent
    }
    val beforeEtag = before.etag
    val afterEtag = after.etag
    if (!beforeEtag.isNullOrEmpty() && !afterEtag.isNullOrEmpty() && beforeEtag != afterEtag) {
        return true
    }
    return before.contentSha256 != after.contentSha256 ||
        before.deviceId != after.deviceId ||
        before.exportedAtMillis != after.exportedAtMillis ||
        before.snapshotPath != after.snapshotPath
}

/** 字节逐位比对（Dart `_bytesEqual` 原样）。 */
fun bytesEqual(left: ByteArray, right: ByteArray): Boolean {
    if (left.size != right.size) return false
    for (i in left.indices) {
        if (left[i] != right[i]) return false
    }
    return true
}

/**
 * 情侣拉取 unchanged 短路（Dart pullPartnerTimetable:195-241 原样）。
 * `!force && lastHash == contentHash && hasBinding` 时免导入。
 */
fun shouldSkipCouplePullAsUnchanged(
    lastRemoteContentHash: String?,
    contentHash: String,
    force: Boolean,
    hasPartnerBinding: Boolean,
): Boolean = !force &&
    lastRemoteContentHash == contentHash &&
    hasPartnerBinding
