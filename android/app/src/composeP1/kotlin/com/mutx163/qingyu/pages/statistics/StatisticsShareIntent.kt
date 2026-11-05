package com.mutx163.qingyu.pages.statistics

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.Toast
import androidx.core.content.FileProvider
import com.mutx163.qingyu.pages.statistics.charts.ChartsStrings
import java.io.File

/**
 * 统计页「分享」的 Android 落地（F12 建立 2026-10-30，F15 同日补上图片导出）。
 *
 * ## 为什么单独一个文件
 *
 * `StatisticsShareText` / `StatisticsShareImageModel` / `StatisticsShareImageDecision`（main 层）
 * 只算内容、契约与判断，零 Android 依赖，能进 JVM 单测；真正发 `ACTION_SEND` 需要 `Context`，
 * 按本仓约定这类胶水放 composeP1 的渲染侧，不污染模型层
 * （main 对全变体编译，import android.* 会让模型层进不了 L0）。
 *
 * ## 这一版的分工（对抗审核 P2 之后）
 *
 * 本文件**只搬砖**，不再自己判断「该不该发图」：
 *
 * | 环节 | 在哪 |
 * |---|---|
 * | 文件名 / 落盘路径 / MIME / 卡片排版 | [StatisticsShareImageModel]（纯逻辑，有单测） |
 * | 「该发图还是退回纯文本」 | [StatisticsShareImageDecision]（纯逻辑，有单测） |
 * | 离屏画成 PNG 字节 | [StatisticsShareImageRender] |
 * | 写盘 / `FileProvider` / `ACTION_SEND` | 本文件 |
 *
 * 这样排是因为原来五个 `return false` 全在这里、吃 `Context`、L0 跑不到，
 * 于是「发不出图就退回纯文本、绝不假装成功」这条承诺**一条用例都没有**。
 *
 * ## 与 Dart 的差异（F15 之后只剩「文档内容还不够全」这一条）
 *
 * Dart `StatisticsShareService.exportAndShare` 分享的是**PNG 图片 + 正文**；
 * 这里也是图 + 正文（`EXTRA_STREAM` + `EXTRA_TEXT` + `EXTRA_SUBJECT`，与
 * `ShareParams(files:, subject:, text:)` 同形）。差的只是文档内容本身：
 * Dart 那张图里有品牌 logo、成就、数据故事、图表、课程排行，这里只有标题 + 正文句
 * + 指标行 + 品牌条（应用名 / 一句话 / 网址 / 二维码）。补齐路径见认领文件
 * `claims/F15-statistics-share-image.md` 的「未做」——它要壳把 `SemesterStats` 交出来。
 *
 * ## 失败一律降级成纯文本，绝不假装
 *
 * 光栅化、落盘、`FileProvider` 三步任何一步失败都不抛给用户，而是退回 F12 那套纯文本分享
 * （内容仍然是真数据，只是没有 PNG 附件）。**绝不在界面上写「已导出图片」**，
 * 也绝不生成空图冒充成功（空正文在 [StatisticsShareImageModel.payload] 就被拦成 null）。
 *
 * 与 `DiagnosticsLogHost.shareLogText` 同一套「能发附件就发附件、发不了就发正文」的口径。
 */
private const val LOG_TAG = "[statistics-share]"

/**
 * 分享统计成果：**优先发 PNG 成果图**，发不出图就退回纯文本（内容同源、仍是真数据）。
 *
 * 入口名保持 `shareStatisticsText` 不改：调用点是壳 `ShellPageIndex.kt` 的 `e.statistics`
 * 分支（**不在本批写作用域**），改名会让那一行编译不过。语义已经不是「只发文本」了，
 * 所以口径写在这里，并已报 Lead 同步壳里的旧注释。
 */
fun shareStatisticsText(context: Context, text: String, subject: String) {
    if (shareStatisticsImage(context, text, subject)) return
    shareStatisticsTextOnly(context, text, subject)
}

/**
 * 尝试分享成果图。
 *
 * 判断「发图还是降级」全交给 [StatisticsShareImageDecision]；这里只把四步的真实结果
 * （载荷 / PNG / 写盘 / Uri）交给它，再照它的判决做事。
 *
 * @return 是否**真的**拉起过带 PNG 附件的分享面板；false = 调用方应降级成纯文本分享。
 */
internal fun shareStatisticsImage(context: Context, text: String, subject: String): Boolean {
    val payload = StatisticsShareImageModel.payload(
        text = text,
        subject = subject,
        epochMillis = System.currentTimeMillis(),
    )
    val png = payload?.let {
        StatisticsShareImageRender.renderPng(context, it.card, exportWidthDp(context))
    }
    val file = if (payload != null && png != null) {
        writeSharePng(context, payload.cacheRelativePath, png)
    } else {
        null
    }
    val uri = file?.let { resolveShareUri(context, it) }

    return when (
        val decision = StatisticsShareImageDecision.decide(
            payload = payload,
            png = png,
            writeSucceeded = file != null,
            uri = uri,
        )
    ) {
        is StatisticsShareImageDecision.Decision.FallbackToText -> {
            Log.w(LOG_TAG, "这次不发图，降级成纯文本分享：${decision.reason}")
            // 2026-11-05 审核修复：降级不再无声。用户点的是「分享图」，收到的却是
            // 文字面板——发布版三种失败都弹「分享失败：{detail}」
            // （statistics_share_service.dart:78-117 的 showAppToast），这里补齐同一条。
            // EMPTY_CONTENT 不提示：那不是失败，是没有内容（payload 为 null 的诚实出口）。
            if (decision.reason != StatisticsShareImageDecision.FallbackReason.EMPTY_CONTENT) {
                Toast.makeText(
                    context,
                    ChartsStrings.serviceMsgStatisticsShareFailed
                        .filled("detail", decision.reason.toDetailCode()),
                    Toast.LENGTH_SHORT,
                ).show()
            }
            false
        }

        is StatisticsShareImageDecision.Decision.ShareImage ->
            launchImageShare(context, decision.payload, decision.uri)
    }
}

// ---------------------------------------------------------------------- 搬砖

/**
 * 降级原因 → toast `{detail}` 位的机器短码。
 *
 * 对齐 Dart `statistics_share_service.dart` 的 detail 取值风格（`capture_empty` /
 * `overlay_missing` 一类小写下划线码）：这不是用户文案，是排障锚点——真因要查日志
 * （[LOG_TAG] 里有完整 reason）。与发布版同口径：detail 原样进模板，不做二次转义。
 */
private fun StatisticsShareImageDecision.FallbackReason.toDetailCode(): String = when (this) {
    StatisticsShareImageDecision.FallbackReason.EMPTY_CONTENT -> "empty_content"
    StatisticsShareImageDecision.FallbackReason.RASTERIZE_FAILED -> "rasterize_failed"
    StatisticsShareImageDecision.FallbackReason.WRITE_FAILED -> "write_failed"
    StatisticsShareImageDecision.FallbackReason.PROVIDER_UNAVAILABLE -> "provider_unavailable"
    StatisticsShareImageDecision.FallbackReason.NO_TARGET -> "no_target"
}

/** 把 PNG 写进 `cacheDir` 的**已登记**子目录；失败回 null（不抛、不吞原因）。 */
private fun writeSharePng(context: Context, relativePath: String, png: ByteArray): File? = runCatching {
    File(context.cacheDir, relativePath).apply {
        parentFile?.mkdirs()
        writeBytes(png)
    }
}.onFailure {
    Log.w(LOG_TAG, "分享图落盘失败（$relativePath）", it)
}.getOrNull()

/** 换成 `FileProvider` 的 content Uri；provider 没注册 / 白名单没覆盖时回 null。 */
private fun resolveShareUri(context: Context, file: File): String? = runCatching {
    FileProvider.getUriForFile(
        context,
        StatisticsShareImageModel.providerAuthority(context.packageName),
        file,
    ).toString()
}.onFailure {
    Log.w(LOG_TAG, "FileProvider 不可用（${file.path}）", it)
}.getOrNull()

/** 拉起系统分享面板；没有能接图的应用回 false（调用方再退回纯文本）。 */
private fun launchImageShare(
    context: Context,
    payload: StatisticsShareImageModel.Payload,
    uri: String,
): Boolean {
    val contentUri = Uri.parse(uri)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = payload.mimeType
        putExtra(Intent.EXTRA_STREAM, contentUri)
        putExtra(Intent.EXTRA_SUBJECT, payload.subject)
        putExtra(Intent.EXTRA_TEXT, payload.text)
        // ClipData 不是可选装饰：没有它，部分接收方拿不到读权限，图会显示成空白/裂图。
        clipData = ClipData.newUri(context.contentResolver, payload.clipLabel, contentUri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(intent, payload.subject).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return runCatching {
        context.startActivity(chooser)
        true
    }.getOrElse {
        // 2026-11-05 成员八复核②：这里此前无声降级——用户点的是分享图、收到的是
        // 文字面板，没有任何解释（FallbackToText 分支的提示只覆盖判决期失败，
        // NO_TARGET 发生在判决之后、永远走不到）。补齐同一条提示，
        // 文案复用 ARB 既有键 `serviceMsgStatisticsShareFailed`。
        Log.w(LOG_TAG, "没有能接收图片分享的应用，降级成纯文本分享", it)
        Toast.makeText(
            context,
            ChartsStrings.serviceMsgStatisticsShareFailed.filled(
                "detail",
                StatisticsShareImageDecision.FallbackReason.NO_TARGET.toDetailCode(),
            ),
            Toast.LENGTH_SHORT,
        ).show()
        false
    }
}

/** F12 那套纯文本分享（真数据、无附件）。图片路径失败时才会走到这里。 */
private fun shareStatisticsTextOnly(context: Context, text: String, subject: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, text)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(intent, subject).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(chooser) }
}

/**
 * 导出宽度：把当前可用宽度收进 320~420dp（Dart `mediaQuery.size.width.clamp(320, 420)` 同口径）。
 *
 * `screenWidthDp` 在非 Activity context 上可能是 0，所以退回按像素/密度算——
 * 0 会让整张图缩成 1px 宽，比拿不到精确窗口宽度糟糕得多。
 */
private fun exportWidthDp(context: Context): Float {
    val resources = context.resources
    val screenWidthDp = resources.configuration.screenWidthDp
    val availableDp = if (screenWidthDp > 0) {
        screenWidthDp.toFloat()
    } else {
        resources.displayMetrics.widthPixels / resources.displayMetrics.density
    }
    return StatisticsShareImageModel.exportWidthDp(availableDp)
}
