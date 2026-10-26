package com.mutx163.qingyu.weather

/**
 * Dart `lib/services/bing_wallpaper_service.dart` 下载链路的**纯判定**部分。
 *
 * 覆盖：`_isMissingTier`（哪些失败值得退档重试）。download 的 HTTP/落盘/验尺寸
 * 全部是 IO，不移植；退档决策本身是纯逻辑，按失败原因给出「换一档再试」还是
 * 「如实失败」。
 */

/** 一次下载尝试的失败原因（对应 Dart ManagedImageDownloadFailure 的语义子集）。 */
enum class DownloadFailure {
    /** 网络层异常 / 超时 / 断网。 */
    Network,

    /** HTTP 状态码非 2xx（含 404 =「Bing 没这张」）。 */
    Status,

    /** 拿到的不是图片（Bing 对未知尺寸回 HTML 错误页，状态码偶尔仍是 200）。 */
    NotImage,

    /** 响应体为空。 */
    EmptyBody,

    /** 写盘失败。 */
    Write,
}

/**
 * [failure] 是不是「这个尺寸 Bing 根本没给」那一类。
 *
 * 只有 [DownloadFailure.Status]（多为 404）与 [DownloadFailure.NotImage]（HTML
 * 错误页，状态码偶尔仍是 200）才值得退档。`Network` / `EmptyBody` / `Write`
 * 与尺寸无关——换个尺寸重下同一张图照样失败，重试只是把一次失败拖成两次超时
 * （2026-10-06 review 定的口径）。
 */
fun isMissingTierFailure(failure: DownloadFailure?): Boolean =
    failure == DownloadFailure.Status || failure == DownloadFailure.NotImage
