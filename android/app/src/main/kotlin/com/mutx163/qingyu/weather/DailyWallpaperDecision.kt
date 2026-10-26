package com.mutx163.qingyu.weather

import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

/**
 * Dart `lib/services/bing_wallpaper_service.dart` 与
 * `lib/services/daily_wallpaper_service.dart` 的移植（**纯判据**部分）。
 *
 * 覆盖：
 * - `_isToday`（dateKey 是否今天）；
 * - maybeApplyDaily 的判据段（幂等 / stale / 自愈——记的是那张图自己的 dateKey）；
 * - `loadItems` 的缓存 TTL 判定（3 小时、非空才算命中）；
 * - DailyWallpaperService 的结局归一翻译。
 *
 * 不移植（IO 清单）：HTTP 拉清单/下载、prefs 开关读写、文件清理、日志。
 */

/** 自动换这一条路上「算不算今天」的纯判据。 */
object BingWallpaperDaily {

    /**
     * [item] 是不是「今天」（按本机日期）那一涨。
     *
     * 解析不了 `dateKey` 一律按「不是今天」处理：宁可标成不是今天如实说一句，
     * 也不在脏数据上赌它是今天。
     */
    fun isToday(item: BingWallpaperItem, now: LocalDateTime): Boolean {
        val parsed = parseBingWallpaperDateKey(item.dateKey) ?: return false
        return parsed.year == now.year &&
            parsed.monthValue == now.monthValue &&
            parsed.dayOfMonth == now.dayOfMonth
    }

    /**
     * maybeApplyDaily 的**判据段**：台账里最近一次自动换的 dateKey 是否已经等于
     * 清单最新那张。相等 → 已换过（幂等，拦截在下载之前）；不等 → 继续走下载。
     *
     * 正因为记的是**那张图自己的** dateKey（可能不是今天），Bing 之后真的放出
     * 今天那张时判据会自然放行，当天再换一次——一天最多换两次，不重复也不错过的
     * 自愈机制全靠这一点。
     */
    fun decide(
        lastAutoAppliedDate: String?,
        newest: BingWallpaperItem,
        @Suppress("UNUSED_PARAMETER") now: LocalDateTime? = null,
    ): BingAutoApplyDecision = if (lastAutoAppliedDate == newest.dateKey) {
        BingAutoApplyDecision.AlreadyApplied
    } else {
        BingAutoApplyDecision.Proceed
    }

    /** 下载成功后的结局：清单最新那张是不是今天，决定 appliedToday / appliedStale。 */
    fun outcomeFor(item: BingWallpaperItem, now: LocalDateTime): BingAutoApplyDecision.Outcome =
        outcomeFor(isToday(item, now))

    /** 结局的纯映射（isToday 已算好时的便捷形态）。 */
    fun outcomeFor(isToday: Boolean): BingAutoApplyDecision.Outcome =
        if (isToday) BingAutoApplyDecision.Outcome.Today else BingAutoApplyDecision.Outcome.Stale

    /**
     * 清单缓存是否仍然新鲜：TTL 内**且**非空才算命中（空清单也算未命中——
     * 否则一次失败会被缓存 3 小时，用户当天再也看不到图库）。
     */
    fun cacheFresh(
        cachedAt: LocalDateTime?,
        now: LocalDateTime,
        itemCount: Int = 1,
    ): Boolean {
        if (cachedAt == null || itemCount <= 0) return false
        return ChronoUnit.MILLIS.between(cachedAt, now) < LIST_CACHE_TTL_MILLIS
    }

    /** 清单缓存 TTL：3 小时（防的是用户反复进出设置页时反复请求）。 */
    const val LIST_CACHE_TTL_MILLIS: Long = 3L * 60 * 60 * 1000
}

/** 「今天自动换」这一条路的判据结局。 */
sealed class BingAutoApplyDecision {
    /** 判据已拦截：今天已经换过（那张图的 dateKey 已在台账）。 */
    data object AlreadyApplied : BingAutoApplyDecision()

    /** 继续走下载（IO 段）。 */
    data object Proceed : BingAutoApplyDecision()

    /** 下载后的结局（对应 Dart BingAutoApplyOutcome）。 */
    enum class Outcome {
        /** 功能没开。 */
        Disabled,

        /** 这张图今天已经换过（判据在下载之前就拦截）。 */
        AlreadyApplied,

        /** 换上了今天那张。 */
        Today,

        /** 换上了 Bing 手上最新的那张，但它并不是今天的图。 */
        Stale,

        /** 拉不到清单，或图没下下来。 */
        Failed,
    }
}

/** 一次自动换的结果：[outcome] 说明发生了什么；path 只在真的换上时非空。 */
data class BingAutoApplyResult(
    val outcome: BingAutoApplyDecision.Outcome,
    /** 换上去那张图的本地路径。 */
    val path: String? = null,
    /** 换上去那张图自己的 `dateKey`。可能不是今天（见 Stale）。 */
    val dateKey: String? = null,
) {
    val succeeded: Boolean get() = path != null
}

/** 「每天自动换壁纸」的结局（对应 Dart DailyWallpaperApplyOutcome，独立类型）。 */
enum class DailyApplyOutcome {
    /** 功能没开。 */
    Disabled,

    /** 今天已经换过了。 */
    AlreadyApplied,

    /** 换上了今天该换的那张。 */
    AppliedToday,

    /** 换上了 Bing 手上最新的那张，但它不是「今天那张」。 */
    AppliedStale,

    /** 拉不到清单，或图没下下来。 */
    Failed,
}

/** 一次「今天自动换」尝试的结果。 */
data class DailyWallpaperApplyResult(
    val outcome: DailyApplyOutcome,
    /** 真换上去时的本地路径。 */
    val path: String? = null,
    /** 那张图的身份（Bing 是 dateKey，可能不是今天，见 AppliedStale）。 */
    val itemId: String? = null,
) {
    val succeeded: Boolean get() = path != null
}

/**
 * 调度层的结局归一翻译（Dart `_fromBing` 的 switch 逐条对应）。
 *
 * 设置页与启动路径消费的是「这一句提示」，不必知道 Bing 内部的结局枚举——
 * 保留这层薄翻译是为了让调用方的分支与 Bing 结局的演进解耦。
 */
object DailyWallpaperMapper {
    fun fromBing(
        outcome: BingAutoApplyDecision.Outcome,
        path: String?,
        dateKey: String?,
    ): DailyWallpaperApplyResult = when (outcome) {
        BingAutoApplyDecision.Outcome.Disabled ->
            DailyWallpaperApplyResult(DailyApplyOutcome.Disabled)
        BingAutoApplyDecision.Outcome.AlreadyApplied ->
            DailyWallpaperApplyResult(DailyApplyOutcome.AlreadyApplied)
        BingAutoApplyDecision.Outcome.Today ->
            DailyWallpaperApplyResult(DailyApplyOutcome.AppliedToday, path, dateKey)
        BingAutoApplyDecision.Outcome.Stale ->
            DailyWallpaperApplyResult(DailyApplyOutcome.AppliedStale, path, dateKey)
        BingAutoApplyDecision.Outcome.Failed ->
            DailyWallpaperApplyResult(DailyApplyOutcome.Failed)
    }
}
