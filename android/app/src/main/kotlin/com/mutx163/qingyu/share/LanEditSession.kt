package com.mutx163.qingyu.share

import java.security.SecureRandom
import java.util.UUID
import kotlin.random.Random
import kotlin.random.asKotlinRandom

/**
 * 局域网编辑会话：PIN、bearer token 与空闲过期（移植自
 * lib/services/lan_edit_session.dart，全量纯逻辑；不含 HTTP 收发）。
 *
 * 时间源可注入（默认系统时钟）：Dart 侧 `touch/markClientConnected/
 * verifyPin/verifyToken` 内部读 `DateTime.now()`，此处走 [clockMillis]，
 * 行为一致且可测。
 */
class LanEditSession private constructor(
    val pin: String,
    val token: String,
    val createdAtMillis: Long,
    lastActivityAtMillis: Long,
    var boundProfileId: String?,
    private val clockMillis: () -> Long,
) {
    var lastActivityAtMillis: Long = lastActivityAtMillis
        private set

    private val pinAttempts = LinkedHashMap<String, PinAttemptState>()
    private val connectedClientSeenAt = LinkedHashMap<String, Long>()
    private var totalPinFailures = 0

    /** 会话级 PIN 失败总预算用尽后，本会话不再接受任何 PIN（含正确 PIN）。 */
    val isPinLocked: Boolean get() = totalPinFailures >= MAX_PIN_FAILURES_PER_SESSION

    /** 仅供测试断言预算计数。 */
    fun totalPinFailures(): Int = totalPinFailures

    fun touch() {
        lastActivityAtMillis = clockMillis()
    }

    val isExpired: Boolean get() = isExpiredAt(clockMillis())

    fun isExpiredAt(now: Long): Boolean {
        if (now - createdAtMillis > MAX_DURATION_MILLIS) return true
        return now - lastActivityAtMillis > IDLE_TIMEOUT_MILLIS
    }

    val connectedClientCount: Int get() = connectedClientCountAt(clockMillis())

    /**
     * 「已连接 N 台」按"多久没再请求"判离线（Dart 原文）：
     * HTTP 没有连接生命周期可依赖，只 add 不清会让计数变成历史累计；
     * 超过 [IDLE_TIMEOUT_MILLIS] 没再请求的客户端不再计入。
     */
    fun connectedClientCountAt(now: Long): Int {
        connectedClientSeenAt.entries.removeIf { (now - it.value) > IDLE_TIMEOUT_MILLIS }
        return connectedClientSeenAt.size
    }

    fun markClientConnected(clientIp: String) {
        val ip = clientIp.trim()
        if (ip.isEmpty()) return
        connectedClientSeenAt[ip] = clockMillis()
        touch()
    }

    fun isPinRateLimited(clientIp: String): Boolean {
        // 会话锁死后对所有 IP 按限速应答（服务端回 429），而不是逐次 401——
        // 后者是给攻击者的"PIN 还差几位"式 oracle（Dart 原文）。
        if (isPinLocked) return true
        val state = pinAttempts[clientIp] ?: return false
        state.prune(PIN_ATTEMPT_WINDOW_MILLIS, clockMillis())
        return state.failures.size >= MAX_PIN_ATTEMPTS_PER_IP
    }

    fun verifyPin(submittedPin: String, clientIp: String): Boolean {
        if (isPinRateLimited(clientIp)) return false
        if (constantTimeEquals(pin, submittedPin.trim())) {
            pinAttempts.remove(clientIp)
            markClientConnected(clientIp)
            return true
        }
        // 跨 IP 总预算：无论来自哪个源地址，失败都记到同一个桶里，
        // 防伪造源地址绕过单 IP 限速（Dart 原文）。
        totalPinFailures += 1
        val state = pinAttempts.getOrPut(clientIp) { PinAttemptState() }
        state.recordFailure(clockMillis())
        trimClientBookkeeping()
        return false
    }

    fun verifyToken(bearerToken: String?): Boolean {
        if (bearerToken.isNullOrEmpty()) return false
        // 局域网逐字符计时探测需数千次低抖动往返实际不可行；但此处比较的是
        // 唯一写授权凭据，与 update 校验 APK 摘要同一写法（Dart 原文）。
        if (!constantTimeEquals(token, bearerToken)) return false
        if (isExpired) return false
        touch()
        return true
    }

    fun verifyTokenForRequest(bearerToken: String?, clientIp: String): Boolean {
        if (!verifyToken(bearerToken)) return false
        markClientConnected(clientIp)
        return true
    }

    private fun trimClientBookkeeping() {
        if (pinAttempts.size <= MAX_TRACKED_CLIENTS &&
            connectedClientSeenAt.size <= MAX_TRACKED_CLIENTS
        ) {
            return
        }
        val now = clockMillis()
        pinAttempts.entries.removeIf { it.value.isIdleFor(PIN_ATTEMPT_WINDOW_MILLIS, now) }
        while (pinAttempts.size > MAX_TRACKED_CLIENTS) {
            pinAttempts.remove(pinAttempts.keys.first())
        }
        while (connectedClientSeenAt.size > MAX_TRACKED_CLIENTS) {
            connectedClientSeenAt.remove(connectedClientSeenAt.keys.first())
        }
    }

    /** 长度不等直接拒；逐字符异或累积，避免短路比较泄露命中前缀数。 */
    internal fun constantTimeEquals(expected: String, actual: String): Boolean {
        if (expected.length != actual.length) return false
        var diff = 0
        for (i in expected.indices) {
            diff = diff or (expected[i].code xor actual[i].code)
        }
        return diff == 0
    }

    val expiresAt: Long
        get() {
            val idleExpiry = lastActivityAtMillis + IDLE_TIMEOUT_MILLIS
            val hardExpiry = createdAtMillis + MAX_DURATION_MILLIS
            return minOf(idleExpiry, hardExpiry)
        }

    companion object {
        const val IDLE_TIMEOUT_MILLIS = 30 * 60 * 1000L
        const val MAX_DURATION_MILLIS = 2 * 60 * 60 * 1000L
        const val MAX_PIN_ATTEMPTS_PER_IP = 5
        const val PIN_ATTEMPT_WINDOW_MILLIS = 5 * 60 * 1000L

        /**
         * 限流表与已连接客户端集合容量上限（Dart 原文）：
         * 旧实现两张表只增不减，同网段大量不同源地址各试一次错 PIN
         * 会在 2 小时会话里攒出无界条目；上限远大于正常使用，
         * 触发时先丢过期项、再按插入序丢最旧。
         */
        const val MAX_TRACKED_CLIENTS = 128

        /**
         * 会话级 PIN 失败总预算（Dart 原文）：单 IP 限速可被伪造源地址绕过，
         * 攻击者每换一个源地址就拿到一份新的 5 次配额；真正的收敛靠这份
         * 跨 IP 总预算——PIN 是 6 位数字（90 万组合），50 次后整段会话锁死。
         */
        const val MAX_PIN_FAILURES_PER_SESSION = 50

        fun create(
            random: Random = SecureRandom().asKotlinRandom(),
            clockMillis: () -> Long = System::currentTimeMillis,
        ): LanEditSession {
            val pin = (100000 + random.nextInt(900000)).toString()
            val now = clockMillis()
            return LanEditSession(
                pin = pin,
                token = UUID.randomUUID().toString(),
                createdAtMillis = now,
                lastActivityAtMillis = now,
                boundProfileId = null,
                clockMillis = clockMillis,
            )
        }

        fun forTest(
            pin: String,
            token: String,
            createdAtMillis: Long,
            lastActivityAtMillis: Long,
            boundProfileId: String? = null,
            clockMillis: () -> Long = System::currentTimeMillis,
        ): LanEditSession = LanEditSession(
            pin = pin,
            token = token,
            createdAtMillis = createdAtMillis,
            lastActivityAtMillis = lastActivityAtMillis,
            boundProfileId = boundProfileId,
            clockMillis = clockMillis,
        )
    }
}

/** 单 IP 的失败时间点（Dart `_PinAttemptState`，时间源由调用方传入）。 */
class PinAttemptState {
    val failures = ArrayDeque<Long>()

    fun recordFailure(time: Long) {
        failures.addLast(time)
        prune(LanEditSession.PIN_ATTEMPT_WINDOW_MILLIS, time)
    }

    fun prune(windowMillis: Long, now: Long) {
        val cutoff = now - windowMillis
        while (failures.isNotEmpty() && failures.first() < cutoff) {
            failures.removeFirst()
        }
    }

    /** 窗口内已无可计数的失败记录，可整条回收。 */
    fun isIdleFor(windowMillis: Long, now: Long): Boolean {
        prune(windowMillis, now)
        return failures.isEmpty()
    }
}
