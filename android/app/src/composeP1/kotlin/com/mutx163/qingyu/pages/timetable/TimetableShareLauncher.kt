package com.mutx163.qingyu.pages.timetable

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 「干净课表图」的 Android 落地（2026-11-03 新增）。
 *
 * ## 分工（与统计域 `StatisticsShareIntent` 同一张表）
 *
 * | 环节 | 在哪 |
 * |---|---|
 * | 文件名 / 落盘路径 / MIME / 宽度 / 几何 | [TimetableShareImageModel]（纯逻辑，JVM 单测） |
 * | 离屏画成 PNG 字节 | [TimetableShareImageRender]（composeP1，Canvas） |
 * | 写盘 / 清旧图 / `FileProvider` / `ACTION_SEND` | 本文件 |
 *
 * ## 为什么导出在后台线程
 *
 * 周网格 + 二维码 + PNG 压缩在低端机上是几百毫秒级的主线程卡顿；统计域同步做是因为
 * 它只有几行字。这里 `Dispatchers.Default` 画图、回主线程只做 `startActivity`
 * （Intent 必须在主线程发）。协程用独立 scope——分享动作的生命周期比任何组合都长，
 * 不挂在调用方的 composition 上。
 *
 * ## 失败一律降级成纯文本，绝不假装
 *
 * 渲染 / 落盘 / `FileProvider` 三步任何一步失败都退回纯文本分享（内容仍是真数据：
 * [TimetableShareImageModel.Document.shareText]）。**绝不在界面上写「已导出图片」**，
 * 也绝不生成空图冒充成功。
 */
private const val LOG_TAG = "[timetable-share]"

/**
 * 导出并分享「干净课表图」。
 *
 * @param context 任意 Context（Application Context 即可，分享面板挂 `NEW_TASK`）。
 * @param doc 已组装好的导出文档（周图 / 日图由调用方定，模型层组装）。
 * @param exportWidthDp 导出宽度（调用方用 `TimetableShareImageModel.exportWidthDp(屏宽)` 收口）。
 */
fun shareTimetableImage(context: Context, doc: TimetableShareImageModel.Document, exportWidthDp: Float) {
    val appContext = context.applicationContext
    CoroutineScope(Dispatchers.Default).launch {
        val uri = exportToCacheUri(appContext, doc, exportWidthDp)
        val launched = uri?.let { launchImageShare(appContext, doc, it) } ?: false
        if (!launched) {
            // 图片链路任何一步失败 → 退回纯文本（真数据，不装成功）。
            shareTextOnly(appContext, doc.shareText)
        }
    }
}

/**
 * 渲染 → 落盘 → 换 content Uri；任何一步失败回 null（调用方降级）。
 *
 * 落盘进 `cacheDir/timetable-share/`（FileProvider 白名单目录，
 * `file_paths.xml` 的 `timetable_share` 条目）；写之前先清掉上一张，
 * 目录里只保留最新一份。
 */
private suspend fun exportToCacheUri(
    context: Context,
    doc: TimetableShareImageModel.Document,
    exportWidthDp: Float,
): Uri? = withContext(Dispatchers.Default) {
    val png = TimetableShareImageRender.renderPng(context, doc, exportWidthDp)
    if (png == null) {
        Log.w(LOG_TAG, "课表图渲染失败，降级纯文本分享")
        return@withContext null
    }
    val dir = File(context.cacheDir, TimetableShareImageModel.CACHE_DIR_NAME)
    val removed = TimetableShareImageModel.cleanStaleExports(dir)
    if (removed > 0) Log.i(LOG_TAG, "清理旧分享图 $removed 张")
    val file = runCatching {
        dir.mkdirs()
        File(dir, TimetableShareImageModel.fileName(System.currentTimeMillis())).apply {
            writeBytes(png)
        }
    }.onFailure {
        Log.w(LOG_TAG, "课表图落盘失败（${dir.path}）", it)
    }.getOrNull() ?: return@withContext null

    runCatching {
        FileProvider.getUriForFile(
            context,
            TimetableShareImageModel.providerAuthority(context.packageName),
            file,
        )
    }.onFailure {
        Log.w(LOG_TAG, "FileProvider 不可用（${file.path}）", it)
    }.getOrNull()
}

/**
 * 拉起系统分享面板：`ACTION_SEND` + `image/png` + `EXTRA_STREAM` + `EXTRA_TEXT`。
 *
 * 与 Dart `SharePlus.instance.share(ShareParams(files:, text:))` 同形。
 * `ClipData` 不是可选装饰：没有它，部分接收方拿不到读权限，图会显示成空白/裂图
 * （统计域踩过的坑原样避让）。
 */
private fun launchImageShare(
    context: Context,
    doc: TimetableShareImageModel.Document,
    uri: Uri,
): Boolean {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = TimetableShareImageModel.MIME_PNG
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_TEXT, doc.shareText)
        clipData = ClipData.newUri(context.contentResolver, TimetableShareImageModel.CLIP_LABEL, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(intent, null).apply {
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

/** 纯文本兜底分享（真数据、无附件）。图片链路失败时才会走到这里。 */
private fun shareTextOnly(context: Context, text: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(intent, null).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(chooser) }
}
