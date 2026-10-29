package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 节假日持久化（移植 `lib/services/holiday_service.dart:36-41`、`:225-253`、`:603-722`
 * 里碰 `SharedPreferences` 的那部分）。
 *
 * ## 两个键（与 Dart 逐字一致，物理前缀 `flutter.` 由 [KeyValueStore] 实现统一加）
 *
 * - `holiday_data_<year>`：该年的 [HolidayData]（`toJsonString()` 的 JSON）；
 * - `custom_holidays`：用户自定义假期列表（`[{date,name,type,groupId},…]`）。
 *
 * 原生侧（`TodayWidgetSupport.kt:154-155`）读的是同一个物理键
 * （`flutter.holiday_data_<year>` / `flutter.custom_holidays`），所以这里的 encode/decode
 * 形状必须与 Flutter 侧完全一致——复用 [HolidayData.toJsonString] /
 * [CustomHolidayListOps.encodePersistedList] 就是为了不出现第二份序列化规则。
 *
 * ## 三条不能含糊的语义（Issue #52 审核钉住，逐条对应 Dart 注释）
 *
 * 1. **年度缓存读失败 → null**（不是空数据）。Dart `_loadFromLocalCache` 整段 try/catch
 *    返回 null，然后走上「无缓存」分支重新取网。
 * 2. **自定义假期整体解析失败 → null**（损坏态），调用方必须与「合法的空列表」区分开；
 *    把 null 当空列表回写会把真实数据覆盖清零（Dart `:606-640`）。
 * 3. **自定义假期写入失败 → 抛 [HolidayCustomSaveException]**，不许静默吞掉：
 *    用户会「看着保存成功、重启即丢」（Dart `:642-678`）。
 *    ⚠️ 与 Dart 的差异：Dart 还要检查 `prefs.setString` 的**返回值**（Android 磁盘满时
 *    `commit()` 返回 false 而不抛），[KeyValueStore.putString] 返回 Unit、没有这个信号，
 *    所以这条防线在 Kotlin 侧落到实现层（实现抛异常才算失败）。
 *
 * 另注：Dart `saveCustomHolidays` 成功后调 `notifyUserDataChangedForSync()` 通知云同步；
 * 本层**不碰**同步链路（那是 Phase 3.5 接线层的职责，硬接会让本目录进不了 JVM 单测）。
 */
class HolidayPreferences(private val store: KeyValueStore) {

    companion object {
        const val DATA_KEY_PREFIX = "holiday_data_"
        const val CUSTOM_HOLIDAYS_KEY = "custom_holidays"

        fun dataKey(year: Int): String = "$DATA_KEY_PREFIX$year"
    }

    // ---------- 年度缓存 ----------

    /**
     * 读 [year] 的本地缓存；键不存在或 JSON 坏了都返回 null。
     *
     * Dart 侧读坏数据只是「当作没缓存」，并不删原值——所以这里也不清理，
     * 下一次成功取网会直接覆盖它。
     */
    fun loadYear(year: Int): HolidayData? {
        val raw: String? = try {
            store.getString(dataKey(year))
        } catch (_: Exception) {
            null
        }
        if (raw == null) return null
        return try {
            HolidayData.fromJsonString(raw)
        } catch (_: Exception) {
            null
        }
    }

    /** 写 [year] 的缓存。写失败**不抛**（Dart `:236-243` 同口径：缓存只是加速，不该让取网失败）。 */
    fun saveYear(year: Int, data: HolidayData) {
        try {
            store.putString(dataKey(year), data.toJsonString())
        } catch (_: Exception) {
            // 忽略：内存缓存本次仍然有效，下次启动走「无缓存 → 取网」。
        }
    }

    /** 清掉 [year] 的缓存（Dart `clearCache`，`:581-601`）。失败同样不抛，只影响下次是否读旧值。 */
    fun clearYear(year: Int) {
        try {
            store.remove(dataKey(year))
        } catch (_: Exception) {
            // 忽略：Dart 这里落 AppLogService.warn，本层无日志通道，交给调用方按需补。
        }
    }

    // ---------- 自定义假期 ----------

    /**
     * 读自定义假期。
     *
     * - `null` = **持久化数据损坏**（整体 JSON 解析失败）——调用方必须当损坏处理，
     *   不许当空列表继续 add/save；
     * - 空列表 = 合法的「还没加过」（键不存在）；
     * - 单条坏条目按容错粒度跳过，不影响其余条目（[CustomHolidayListOps.parsePersistedList]）。
     */
    fun loadCustomHolidays(): List<HolidayEntry>? {
        val raw = try {
            store.getString(CUSTOM_HOLIDAYS_KEY)
        } catch (_: Exception) {
            // 读不出来与「解析失败」同属损坏态：都不能被当成空列表。
            return null
        }
        return CustomHolidayListOps.parsePersistedList(raw)
    }

    /**
     * 整表覆盖写自定义假期。
     *
     * @throws HolidayCustomSaveException 序列化或写盘失败（调用方必须让用户知道没存上）。
     */
    fun saveCustomHolidays(entries: List<HolidayEntry>) {
        try {
            store.putString(CUSTOM_HOLIDAYS_KEY, CustomHolidayListOps.encodePersistedList(entries))
        } catch (e: Exception) {
            throw HolidayCustomSaveException("custom holiday persist failed", e)
        }
    }
}
