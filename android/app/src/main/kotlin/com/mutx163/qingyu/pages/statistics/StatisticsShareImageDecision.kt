package com.mutx163.qingyu.pages.statistics

/**
 * 「这一次该发图，还是退回纯文本」的**决策**（2026-10-30 F15 补，来自对抗审核 P2）。
 *
 * ## 为什么要把这段抽出来
 *
 * 原来这条判断散在 `StatisticsShareIntent.shareStatisticsImage` 的五个 `return false` 里。
 * 那个函数吃 `Context`、又要 `FileProvider`，**进不了 L0 的 JVM 单测 classpath**，
 * 于是「发不出图就退回纯文本、绝不假装成功」这条承诺**一条用例都没有**——
 * 把任一 `return false` 改成 `return true`，测试会全绿。这正是本仓最怕的那种
 * 「守着的规矩没人真的守着」。
 *
 * 现在：判断的**输入输出全是纯值**（可能为 null 的载荷 / PNG / 写盘结果 / Uri），
 * 决策本身零 `android.*`，[StatisticsShareImageDecisionTest] 直接钉四个结局；
 * Intent 侧只剩搬砖（真的画、真的写、真的发）。
 *
 * ## 顺序是契约的一部分
 *
 * 检查顺序 = 真实链路的顺序：空正文 → 光栅化 → 写盘 → provider。
 * 顺序反过来会让「空正文 + 图也画失败」报成 `RASTERIZE_FAILED`，
 * 排障时指错方向（真正原因是没有内容，不是画不出来）。
 *
 * ## `NO_TARGET` 为什么不在 [decide] 里
 *
 * 它只能由 `startActivity` 抛异常才知道，发生在决策之后。
 * 调用方拿到 false 后仍然退回纯文本——与这里的其它几个结局同一条出口。
 */
object StatisticsShareImageDecision {

    /** 降级成纯文本的原因（留档 / 排障 / 日志用，不是用户文案）。 */
    enum class FallbackReason {
        /** 正文为空：没有真内容，**不生成空图**。 */
        EMPTY_CONTENT,

        /** 光栅化失败（OOM、字体度量异常等）。 */
        RASTERIZE_FAILED,

        /** PNG 写不进 cacheDir（磁盘满、目录被删、SecurityException）。 */
        WRITE_FAILED,

        /** `FileProvider.getUriForFile` 不可用（manifest 没注册 / 白名单没覆盖该子目录）。 */
        PROVIDER_UNAVAILABLE,

        /** 没有能接收图片分享的应用（`ActivityNotFoundException` 等）。 */
        NO_TARGET,
    }

    /** 二选一：发图，或退回纯文本。 */
    sealed class Decision {

        class ShareImage(
            val payload: StatisticsShareImageModel.Payload,
            val png: ByteArray,
            val uri: String,
        ) : Decision()

        class FallbackToText(val reason: FallbackReason) : Decision()
    }

    /**
     * @param payload 由 [StatisticsShareImageModel.payload] 算出；null = 正文为空
     * @param png 光栅化结果；null / 空数组 = 画不出来
     * @param writeSucceeded PNG 是否真的落盘了
     * @param uri `FileProvider` 换来的 content Uri；null / 空白 = provider 不可用
     */
    fun decide(
        payload: StatisticsShareImageModel.Payload?,
        png: ByteArray?,
        writeSucceeded: Boolean,
        uri: String?,
    ): Decision {
        if (payload == null) return Decision.FallbackToText(FallbackReason.EMPTY_CONTENT)
        // 空字节数组与 null 同罪：写进去的会是一张 0 字节的「图」，接收方打不开。
        if (png == null || png.isEmpty()) return Decision.FallbackToText(FallbackReason.RASTERIZE_FAILED)
        if (!writeSucceeded) return Decision.FallbackToText(FallbackReason.WRITE_FAILED)
        if (uri.isNullOrBlank()) return Decision.FallbackToText(FallbackReason.PROVIDER_UNAVAILABLE)
        return Decision.ShareImage(payload = payload, png = png, uri = uri)
    }
}
