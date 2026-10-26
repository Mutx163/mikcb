package com.mutx163.qingyu.share

/**
 * 局域网 IPv4 展示地址选择中的纯逻辑部分（移植自
 * lib/services/lan_edit_network_utils.dart）。
 *
 * 网卡枚举（`NetworkInterface.list`）是 IO，不在本泳道；
 * 此处只移植"过滤 + 打分 + 选最优"的纯函数。
 * 按 TCP 对端取客户端 IP（`clientIpFromRequest`）同为 IO 语义，
 * 其规则是"只信 TCP 对端，不信 X-Forwarded-For"，见下方注释。
 */
object LanAddressScoring {
    /**
     * 地址打分（Dart `score` 原样）：192.168 → 3，10.* → 2，
     * 172.16~31 → 2，其余 → 1。
     */
    fun scoreLanIPv4(host: String): Int {
        if (host.startsWith("192.168.")) return 3
        if (host.startsWith("10.")) return 2
        val parts = host.split(".")
        if (parts.size == 4) {
            val second = parts[1].toIntOrNull() ?: -1
            if (parts[0] == "172" && second in 16..31) return 2
        }
        return 1
    }

    /** 环回与链路本地地址不向用户展示（Dart 过滤条件原样）。 */
    fun isPresentable(host: String): Boolean =
        host != "127.0.0.1" && !host.startsWith("169.254.")

    /**
     * 从候选地址里选最可能的一条：先过滤、再按分数稳定降序取首个。
     * Dart 用稳定排序，Kotlin `sortedWith` 同为稳定排序，同分保持原序。
     */
    fun pickPreferredLanIPv4(candidates: Iterable<String>): String? =
        candidates
            .filter(::isPresentable)
            .sortedWith(compareByDescending(::scoreLanIPv4))
            .firstOrNull()
}

/**
 * 客户端 IP 限速判据语义：只用 TCP 对端，不信任 `X-Forwarded-For`——
 * LAN Edit 绑的是直连 HttpServer、无反向代理白名单，客户端可伪造 XFF
 * 绕过按 IP 的 PIN 限速（Dart `clientIpFromRequest` 注释原意）。
 * 实际取对端地址是 IO，由调用方传入，此处只固化"未知时"的哨兵值。
 */
const val UNKNOWN_LAN_CLIENT_IP = "unknown"
