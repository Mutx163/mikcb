package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.core.LenientJson
import com.mutx163.qingyu.core.MiniJson

/**
 * 冷启动期的**单键**设置读取（A1 · 2026-11-03）。
 *
 * ## 它解决什么
 *
 * `PagesShellActivity.attachBaseContext` 早于一切 UI，只为读语言覆写标记
 * （`appLocaleTag`）。此前它走 `TimetableSettingsModelStore(...).load()`，把 45+ 个
 * 显示设置键（含两张嵌套主题快照）全量反序列化成模型，只为拿一个字符串。现在只把
 * 盘上 `timetable_settings` 原始 JSON 解成通用 map、捞出语言键，**不建模型**；
 * 全量解析只剩 `ShellWiring` 构造时那一次（首帧前 4 遍 → 1 遍全量 + 1 次单键）。
 *
 * ## 读口径与全量模型逐字一致
 *
 * `appLocaleTag` 缺键回落旧键 `appLocaleMode`，再过 `normalizeAppLocaleTag`
 * （空 / `system` 归空、`-`→`_`、`en_us`→`en`、`zh_cn`→`zh`）——两条都取自
 * [TimetableSettingsModel.fromJson] 的同一段读侧；等价性由
 * `ShellColdStartSettingsTest` 的对拍矩阵钉住（同一批原始 JSON，本函数与全量模型
 * 读出的 tag 必须相等）。
 *
 * ## 与全量路径的一处**有意**差异（如实说明）
 *
 * 盘上不是合法 JSON 对象（损坏）时，本函数只返回空串（跟随系统），**不做损坏留档**
 * ——留档+删键仍由冷启动必经的 `ShellWiring`（`settingsModel.load()` →
 * `TimetableStore.loadSettingsJson`）在同一次启动里完成。两边只是先后不同，
 * 最终盘面状态与语言回落行为一致。
 */
fun localeTagFromRawSettingsJson(raw: String?): String {
    if (raw.isNullOrEmpty()) return ""
    val decoded = MiniJson.tryParse(raw)
    if (decoded !is Map<*, *>) return ""
    val tag = LenientJson.string(decoded["appLocaleTag"])
        ?: LenientJson.string(decoded["appLocaleMode"])
    return TimetableSettingsModel.normalizeAppLocaleTag(tag)
}
