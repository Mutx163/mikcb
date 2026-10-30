package com.mutx163.qingyu.pages.statistics

import android.content.Context
import android.content.Intent

/**
 * 统计页「分享」的 Android 落地（2026-10-30 F12 新增）。
 *
 * ## 为什么单独一个文件
 *
 * `StatisticsShareText`（main 层）只算文本、零 Android 依赖，能进 JVM 单测；
 * 真正发 `ACTION_SEND` 需要 `Context`，按本仓约定这类胶水放 composeP1 的渲染侧，
 * 不污染模型层（main 对全变体编译，import android.* 会让模型层进不了 L0）。
 *
 * ## 与 Dart 的差异（同一处缺口，这里再说一遍免得被当成漏了）
 *
 * Dart `StatisticsShareService.exportAndShare` 分享的是**PNG 图片 + 正文**。
 * 图片要「离屏 Compose 渲染 → Bitmap → 缓存文件 → FileProvider 授权」，
 * 而 `FileProvider` 未在 manifest 注册（属 Lead 专属文件），所以本批只发文本。
 * 发的是真数据（不是占位），**不伪造图片**。
 *
 * 分享失败一律静默（系统里没有可分享的 App 场景极少）：不弹「假成功」，
 * 也不弹一句用户看不懂的英文异常。
 */
fun shareStatisticsText(context: Context, text: String, subject: String) {
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
