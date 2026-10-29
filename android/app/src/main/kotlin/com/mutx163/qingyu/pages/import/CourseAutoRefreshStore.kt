package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 「课表自动更新」的**配置与台账落盘 store**（纯 Kotlin，无 Android / Compose 依赖）。
 *
 * 移植 `lib/services/course_auto_refresh_store.dart` 的读写部分；**判据一条都不复制**：
 * 「下次什么时候跑」「现在该不该跑」全部转手给 [CourseAutoRefreshModel]，
 * 免得出现第二份真源（两份判据一旦走偏，界面显示和实际执行会对不上）。
 *
 * ## 冻结的键（与 Dart `course_auto_refresh_store.dart:35-41` 逐字对齐）
 *
 * | 契约 key | 盘上类型 | 内容 |
 * |---|---|---|
 * | [KEY_SCHEDULE] | String(JSON) | `enabled` / `mode` / `intervalHours` / `dailyMinuteOfDay` |
 * | [KEY_LAST_SUCCESS] | **64 位整数 epoch 毫秒** | 上次成功抓到课表的时刻 |
 * | [KEY_LAST_ATTEMPT] | **64 位整数 epoch 毫秒** | 上次尝试的时刻（无论成败，只喂失败冷却） |
 *
 * `flutter.` 前缀由 [KeyValueStore] 的实现负责，本层只说契约 key。
 * 时间戳必须是毫秒：秒级精度会让「30 分钟冷却」在边界上来回抖，`Int` 更是 2038 年就溢出，
 * 所以键值层专门加了 `getLong` / `putLong`。
 *
 * ## 为什么 `saveSchedule` 要回读
 *
 * Dart 的 `prefs.setString` 直接返回「插件是否认账」。本层 `putString` 是 `Unit`，
 * 于是用**写下去再读回来**当同一份证据：读到的配置与「规范化后的期望值」不一致就返回 false，
 * 让界面能提示「保存失败」而不是假装成功。
 *
 * 比较用**规范化后的期望值**（过一遍 [CourseAutoRefreshSchedule.fromJson]）而不是入参原样：
 * 越界的 `intervalHours` / `dailyMinuteOfDay` 落盘后读回来本来就会被夹进合法区间，
 * 拿原样比会把「夹值」误报成「写失败」。
 */
class CourseAutoRefreshStore(private val store: KeyValueStore) {

    /**
     * 读配置。键缺失 / 空串 / JSON 坏 / 结构不对 ⇒ 一律退回默认值（关、每次打开、24h、07:30），
     * 绝不让一条脏存档打断启动路径（Dart `:54-70` 同口径）。
     */
    fun load(): CourseAutoRefreshSchedule {
        val raw = store.getString(KEY_SCHEDULE)
        if (raw.isNullOrEmpty()) {
            return CourseAutoRefreshSchedule()
        }
        // tryParse 对坏串给 null，fromJson 再退默认——「不崩」这件事只在一处决定。
        return CourseAutoRefreshSchedule.fromJsonString(raw)
    }

    /**
     * 落盘配置，返回**回读验证**是否成功。
     *
     * 写的是入参原样（与 Dart `jsonEncode(next.toJson())` 逐字节同形），
     * 验证时按规范化后的值比（见类注释）。写失败时**不改**任何内存态——
     * 本类是无状态 store，判定路径每次都会重新读盘。
     */
    fun saveSchedule(next: CourseAutoRefreshSchedule): Boolean {
        store.putString(KEY_SCHEDULE, MiniJson.encode(next.toJson()))
        val readBack = store.getString(KEY_SCHEDULE) ?: return false
        return CourseAutoRefreshSchedule.fromJsonString(readBack) == normalize(next)
    }

    /** 上次**成功**的时刻；无键 / 坏值（≤ 0）⇒ null。 */
    fun lastSuccessAt(): LocalDateTime? = readTime(KEY_LAST_SUCCESS)

    /** 上次**尝试**的时刻；无键 / 坏值（≤ 0）⇒ null。 */
    fun lastAttemptAt(): LocalDateTime? = readTime(KEY_LAST_ATTEMPT)

    /**
     * 记一次「尝试开始」。
     *
     * 必须在**真正发起抓取之前**写：会话中途被杀时没有这条记录，下次打开会立刻重来一次
     *（Dart `:84-88` 的理由）。
     */
    fun recordAttempt(at: LocalDateTime) {
        store.putLong(KEY_LAST_ATTEMPT, epochMillis(at))
    }

    /**
     * 记一次「成功」，**同时**把尝试时间推到 [at]。
     *
     * 成功之后再判失败冷却没有意义；留着旧的尝试时间会造出「刚成功、马上又在冷却」
     * 这种自相矛盾的状态（Dart `:94-100` 同口径）。
     */
    fun recordSuccess(at: LocalDateTime) {
        val millis = epochMillis(at)
        store.putLong(KEY_LAST_SUCCESS, millis)
        store.putLong(KEY_LAST_ATTEMPT, millis)
    }

    /** 下次预计运行的时刻；功能关着 ⇒ null。判据全在 [CourseAutoRefreshModel.nextRunAt]。 */
    fun nextRunAt(now: LocalDateTime): LocalDateTime? =
        CourseAutoRefreshModel.nextRunAt(load(), lastSuccessAt(), now)

    /** 现在该不该跑。判据全在 [CourseAutoRefreshModel.decideCourseAutoRefresh]。 */
    fun isDue(now: LocalDateTime): Boolean =
        CourseAutoRefreshModel.decideCourseAutoRefresh(
            schedule = load(),
            now = now,
            lastSuccess = lastSuccessAt(),
            lastAttempt = lastAttemptAt(),
        ) == CourseAutoRefreshDecision.RUN

    // ------------------------------------------------------------------
    // 内部
    // ------------------------------------------------------------------

    /**
     * 入参过一遍「落盘再读回」的同一套容错，得到 `load()` 应当给回的值。
     *
     * **必须走 JSON 文本**：`CourseAutoRefreshSchedule.fromJson` 只认 `Long`
     *（`MiniJson` 解码出来的整数类型），直接喂 `toJson()` 的内存 `Int` 会被当成缺字段、
     * 悄悄退回默认值——那样写成功也会被误判成失败。
     */
    private fun normalize(schedule: CourseAutoRefreshSchedule): CourseAutoRefreshSchedule =
        CourseAutoRefreshSchedule.fromJsonString(MiniJson.encode(schedule.toJson()))

    private fun readTime(key: String): LocalDateTime? {
        // Dart `_readTime`：null 或 ≤ 0 都算「没有」（0 是「从没记过」的哨兵值）。
        val millis = store.getLong(key, 0L)
        return if (millis <= 0L) null else fromEpochMillis(millis)
    }

    /**
     * `LocalDateTime` ↔ epoch 毫秒**必须走同一个时区**。
     *
     * 这里用 [ZoneId.systemDefault]（Dart `DateTime.fromMillisecondsSinceEpoch` 也是本地时区），
     * 所以调用方拿到的 `LocalDateTime` 与它自己写进去的是「同一面墙上的同一时刻」。
     * 测试断言同样要按这个时区换算，否则跨时区机器上会假红。
     */
    private fun epochMillis(at: LocalDateTime): Long =
        at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

    private fun fromEpochMillis(millis: Long): LocalDateTime =
        LocalDateTime.ofInstant(Instant.ofEpochMilli(millis), ZoneId.systemDefault())

    companion object {
        /** 配置存档键（Dart `preferenceKey`）。 */
        const val KEY_SCHEDULE = "course_auto_refresh_v1"

        /** 上次成功的 epoch 毫秒。 */
        const val KEY_LAST_SUCCESS = "course_auto_refresh_last_success_v1"

        /** 上次尝试的 epoch 毫秒（无论成败）。 */
        const val KEY_LAST_ATTEMPT = "course_auto_refresh_last_attempt_v1"
    }
}

/**
 * 「课表自动更新」设置区**行级编辑**的纯逻辑（照 `lib/widgets/course_auto_refresh_settings.dart:107-158`）。
 *
 * 为什么单独抽出来：设置行是「用户点一下 → 新配置」的映射，写在 Compose 页面里就只能
 * 靠真机点一遍验证；抽成纯函数后，每一行的口径都能在 JVM 上钉住。
 *
 * 行 id 由设置页给（不放进 `settings` 包，是因为这组行只服务本功能）：
 * - [ROW_SWITCH]：开关行。`target` 为 null（开关行不传值），一律**取反**。
 * - [ROW_MODE]：档位行。`target` 是 [CourseAutoRefreshMode.serialName]。
 * - [ROW_INTERVAL]：间隔滑杆。`target` 是滑杆回传的数字字符串（可能是 `"24.0"`）。
 * - [ROW_DAILY_TIME] / [ROW_TRY_NOW]：由时间弹层与执行器处理，**不归本逻辑管**。
 */
object CourseAutoRefreshSettingsLogic {

    const val ROW_SWITCH = "general.autoRefresh.switch"
    const val ROW_MODE = "general.autoRefresh.mode"
    const val ROW_INTERVAL = "general.autoRefresh.interval"
    const val ROW_DAILY_TIME = "general.autoRefresh.dailyTime"
    const val ROW_TRY_NOW = "general.autoRefresh.tryNow"

    /**
     * 行改动 → 新配置。
     *
     * 返回 null 表示**这一行不归本逻辑管**，或回传值不合法——两种情况都「宁可不动」：
     * 把非法值猜成一个合法值会让用户在界面上看到自己没选过的档位。
     */
    fun applyEdit(
        rowId: String,
        target: String?,
        current: CourseAutoRefreshSchedule,
    ): CourseAutoRefreshSchedule? = when (rowId) {
        ROW_SWITCH -> {
            // 开关行不携带值：收到任何 target 都说明调用方搞错了行，不动。
            if (target == null) current.copy(enabled = !current.enabled) else null
        }

        ROW_MODE -> {
            val mode = CourseAutoRefreshMode.entries.firstOrNull { it.serialName == target }
            mode?.let { current.copy(mode = it) }
        }

        ROW_INTERVAL -> {
            val raw = target?.toDoubleOrNull()
            // 滑杆不会给 NaN/Infinity；给了就是坏值，别让它悄悄变成「1 小时」。
            if (raw == null || !raw.isFinite()) {
                null
            } else {
                current.copy(
                    intervalHours = CourseAutoRefreshModel.clampIntervalHours(roundLikeDart(raw)),
                )
            }
        }

        else -> null
    }

    /**
     * 与 Dart `double.round()` 同口径：**.5 一律远离零**。
     *
     * 不能用 Kotlin 的 `kotlin.math.round()`——它「.5 取偶」（`12.5 → 12`），
     * Dart 给 13（`course_auto_refresh_settings.dart:144` 就是 `value.round()`）。
     * `Math.round` = `floor(x + 0.5)`，对滑杆的取值域（≥ 1）与 Dart 逐值一致；
     * 负数负半边（`-12.5`：Dart -13、这里 -12）也走不出夹区间结果（都会夹到下限 1）。
     */
    private fun roundLikeDart(value: Double): Int = Math.round(value).toInt()
}
