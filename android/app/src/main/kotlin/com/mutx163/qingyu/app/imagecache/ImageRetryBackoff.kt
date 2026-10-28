package com.mutx163.qingyu.app.imagecache

/**
 * 失败退避策略（纯逻辑，JVM 可测，禁 android 导入）。
 *
 * 有界指数退避：[delayMillis] 随失败次数翻倍、到 [MAX_DELAY_MILLIS] 封顶；[shouldRetry]
 * 限制总尝试次数为 [MAX_ATTEMPTS]。**不加随机抖动**——本层要可确定性单测，抖动应由调用方
 * 在需要时自行叠加（见类尾说明）。
 *
 * 「attempt」是**刚刚失败的那一次尝试**的序号，1-based（第一次尝试 = 1）。
 */
object ImageRetryBackoff {

    /** 最多尝试次数（含首次）。达到之后不再重试。 */
    const val MAX_ATTEMPTS: Int = 3

    /** 首次重试前的等待（毫秒）。 */
    const val BASE_DELAY_MILLIS: Long = 500L

    /** 单次等待上限（毫秒）。 */
    const val MAX_DELAY_MILLIS: Long = 8_000L

    /**
     * 第 [attempt] 次尝试失败后是否还应重试。
     * attempt < 1 视为非法（不重试）；attempt 有效区间 [1, MAX_ATTEMPTS)。
     */
    fun shouldRetry(attempt: Int): Boolean = attempt in 1 until MAX_ATTEMPTS

    /**
     * 第 [attempt] 次尝试失败后应等待的毫秒数。
     * = BASE * 2^(attempt-1)，封顶 [MAX_DELAY_MILLIS]；attempt < 1 返回 0。
     */
    fun delayMillis(attempt: Int): Long {
        if (attempt < 1) return 0L
        var delay = BASE_DELAY_MILLIS
        var i = 1
        while (i < attempt) {
            delay *= 2
            if (delay >= MAX_DELAY_MILLIS) return MAX_DELAY_MILLIS
            i++
        }
        return if (delay > MAX_DELAY_MILLIS) MAX_DELAY_MILLIS else delay
    }
}
