package com.mutx163.qingyu.pages.statistics

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * 统计页「分享」的 Android 落地（F12 建立 2026-10-30，F15 同日补上图片导出）。
 *
 * ## 为什么单独一个文件
 *
 * `StatisticsShareText` / `StatisticsShareImageModel`（main 层）只算内容与契约、零 Android 依赖，
 * 能进 JVM 单测；真正发 `ACTION_SEND` 需要 `Context`，按本仓约定这类胶水放 composeP1 的渲染侧，
 * 不污染模型层（main 对全变体编译，import android.* 会让模型层进不了 L0）。
 *
 * ## 与 Dart 的差异（F15 之后只剩一条）
 *
 * Dart `StatisticsShareService.exportAndShare` 分享的是**PNG 图片 + 正文**。F12 那一版只发文本
 * （文件里写着「图片导出没做」）；F15 把图补上：文件名 / 落盘路径 / MIME / 卡片内容由
 * [StatisticsShareImageModel] 算（纯逻辑 + 单测），像素由 [StatisticsShareImageRender] 离屏画，
 * 这里负责落盘 → `FileProvider` → `ACTION_SEND`（`image/png` + `EXTRA_STREAM` + `EXTRA_TEXT`）。
 *
 * `EXTRA_TEXT` / `EXTRA_SUBJECT` 都留着，与 Dart 的 `ShareParams(subject:, text:)` 同形：
 * 只塞图片时，某些接收方（剪贴板类、部分输入法）拿到图却没有可编辑的正文。
 *
 * 仍然存在的差距（不是本文件的事，写在这里免得被当成漏了）：Dart 的导出文档里还有
 * 品牌条（logo + 二维码）、成就网格、数据故事、日分布/性质占比图、课程排行，
 * 以及「导出模块选择」弹层。那些要模型层的图表数据，见认领文件
 * `claims/F15-statistics-share-image.md` 的「未做」。
 *
 * ## 失败一律降级成纯文本，绝不假装
 *
 * 光栅化、落盘、`FileProvider` 三步任何一步失败（磁盘满、provider 不可用、
 * `file_paths.xml` 没覆盖那个子目录）都**不抛给用户**，而是退回 F12 那套纯文本分享——
 * 内容仍然是真数据，只是没有 PNG 附件。**绝不在界面上写「已导出图片」**，
 * 也绝不生成空图冒充成功（空卡片在 [StatisticsShareImageModel.payload] 就被拦成 null）。
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
 * @return 是否**真的**拉起过带 PNG 附件的分享面板；false = 调用方应降级成纯文本分享。
 */
internal fun shareStatisticsImage(context: Context, text: String, subject: String): Boolean {
    val payload = StatisticsShareImageModel.payload(
        text = text,
        subject = subject,
        epochMillis = System.currentTimeMillis(),
    ) ?: run {
        // 没有真内容（空正文）⇒ 不生成空图。这不是错误，是「别假装导出了图」。
        Log.w(LOG_TAG, "统计分享正文为空，跳过图片导出（不生成空图）")
        return false
    }

    val png = StatisticsShareImageRender.renderPng(context, payload.card, exportWidthDp(context))
        ?: run {
            Log.w(LOG_TAG, "光栅化失败，降级成纯文本分享")
            return false
        }

    val file = runCatching {
        File(context.cacheDir, payload.cacheRelativePath).apply {
            parentFile?.mkdirs()
            writeBytes(png)
        }
    }.getOrElse {
        Log.w(LOG_TAG, "分享图落盘失败，降级成纯文本分享", it)
        return false
    }

    val uri = runCatching {
        FileProvider.getUriForFile(
            context,
            StatisticsShareImageModel.providerAuthority(context.packageName),
            file,
        )
    }.getOrElse {
        // 典型原因：manifest 没注册 provider，或 file_paths.xml 没覆盖那个子目录。
        Log.w(LOG_TAG, "FileProvider 不可用（${file.path}），降级成纯文本分享", it)
        return false
    }

    val intent = Intent(Intent.ACTION_SEND).apply {
        type = payload.mimeType
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_SUBJECT, payload.subject)
        putExtra(Intent.EXTRA_TEXT, payload.text)
        // ClipData 不是可选装饰：没有它，部分接收方拿不到读权限，图会显示成空白/裂图。
        clipData = ClipData.newUri(context.contentResolver, payload.clipLabel, uri)
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
        Log.w(LOG_TAG, "没有能接收图片分享的应用，降级成纯文本分享", it)
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
 * 0 会让整张图缩成 1px 宽，比拿不到精确窗口宽度糟得多。
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
