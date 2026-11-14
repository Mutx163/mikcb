package com.mutx163.qingyu.platform

import com.mutx163.qingyu.calendar.HolidayHttp
import com.mutx163.qingyu.calendar.HolidayHttpResponse
import com.mutx163.qingyu.calendar.HolidayService

/**
 * 节假日远程取数的 OkHttp 实现（2026-11-14 用户决定「所有网络请求改走 OkHttp」）。
 *
 * ## 为什么实现放在 `platform/`，不在 `calendar/`
 *
 * `calendar` 是 `scripts/test-kotlin-module.ps1` 的 L0 **共享面**（`$sharedModelDirs` 含
 * `calendar`），而 L0 的 classpath 只有 junit / hamcrest / kotlin-stdlib，**没有 okhttp jar**。
 * 把 `QingyuHttp`（import 了 `okhttp3.*`）引进 `calendar/`，24 个模块的 L0 会一起
 * `Unresolved reference`。所以：**接口留在 `calendar/HolidayService.kt`（纯 Kotlin，可测）**，
 * 实现在这里——与 `platform/OkHttpWeatherHttp.kt` 同一套切法。
 *
 * ## 与 Dart 原件逐条对齐（别顺手「优化」掉）
 *
 * - 超时 8 秒（Dart `holiday_service.dart:279`，`HolidayService.TIMEOUT_MILLIS`）；
 * - 请求头 `Accept: application/json` + `User-Agent: mikcb-holiday-sync`（`:274-277`）；
 * - **传输失败返回 null、不抛**：节假日是装饰性信息，不该把一个页面拖崩；
 * - **非 200 只回状态码**：调用方 `HolidayService` 对非 200 只记
 *   `holiday_log_*_status`（正文不解析），所以这里不费劲读 errorStream。
 *
 * 每次请求由 [QingyuHttp] 自动写一条 `category=network` 日志：只记 host + path，
 * query（年份）不落盘；失败分类走 `NetLog` 七档。
 */
class OkHttpHolidayHttp : HolidayHttp {

    override fun get(url: String): HolidayHttpResponse? {
        val result = QingyuHttp.getText(
            QingyuHttp.HttpCallSpec(
                url = url,
                headers = mapOf(
                    "Accept" to "application/json",
                    "User-Agent" to USER_AGENT,
                ),
                connectTimeoutMs = HolidayService.TIMEOUT_MILLIS.toLong(),
                readTimeoutMs = HolidayService.TIMEOUT_MILLIS.toLong(),
            ),
        )
        // 连不上 / 超时：QingyuHttp 已经记了网络日志，这里按接口契约返回 null。
        val status = result.status ?: return null
        return HolidayHttpResponse(statusCode = status, body = result.body.orEmpty())
    }

    private companion object {
        /** 与 Dart `:274-277` 逐字一致；节假日接口对无 UA 的请求不保证行为。 */
        const val USER_AGENT: String = "mikcb-holiday-sync"
    }
}
