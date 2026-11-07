package com.mutx163.qingyu.platform

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * 系统分享面板「用户选了谁」的**回执接收器**（ICS 导出取消判断用）。
 *
 * ## 为什么需要它（而不是看 launcher 的 resultCode）
 *
 * 发布版用的 `share_plus` 也是这套机制：`Intent.createChooser(intent, title, sender)` 传一个
 * **广播** `PendingIntent` 的 sender，系统在用户真的选定目标时把 `EXTRA_CHOSEN_COMPONENT`
 * 投给这个广播；面板被划掉时**不会有任何投递**。它的 `ShareSuccessManager.onActivityResult`
 * 注释原文是 "Called regardless of success or dismissal" —— 也就是说 activity 的
 * `resultCode` / `data` 分不出「成功」和「取消」，只能靠这条回执。
 *
 * 只认 resultCode 的后果很具体：Android 选择器普遍恒回 `RESULT_CANCELED`，于是用户
 * **分享成功之后**也会看到「已取消分享日历」——比现在没提示还糟。所以宁可要这条回执。
 *
 * ## 必须的清单声明（属 Lead 文件，本批只提 patch）
 *
 * ```xml
 * <receiver
 *     android:name=".platform.IcsShareResultReceiver"
 *     android:exported="false" />
 * ```
 *
 * 没声明时 [isDeclared] 返回 false，适配器据此把通道标成「不可用」，
 * **宿主就保持沉默**（不谎报取消、也不谎报成功）——降级是安全的，不会给出错信息。
 *
 * 回执只是个 `ComponentName` 字符串：不跨进程共享状态、不落盘、用完即 `take()` 清空。
 */
class IcsShareResultReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val chosen = try {
            intent?.getParcelableExtra(Intent.EXTRA_CHOSEN_COMPONENT, ComponentName::class.java)
        } catch (_: Exception) {
            null
        }
        if (chosen != null) pending = chosen.flattenToString()
    }

    companion object {

        /** 上一次分享选定的目标（`ComponentName.flattenToString()`）；null = 没有回执。 */
        private var pending: String? = null

        /** 拉起分享面板之前清一次，避免把上一次的回执当成本次结果。 */
        fun begin() {
            pending = null
        }

        /** 取走回执并清空（一次性）：非空 = 用户选定目标；null = 没收到。 */
        fun take(): String? = pending.also { pending = null }

        /**
         * manifest 里是否声明了本接收器（= 回执通道能不能用）。
         *
         * 这是「降级安全性」的判据：没声明时宿主不提示取消，而不是凭 resultCode 瞎猜。
         */
        fun isDeclared(context: Context): Boolean = try {
            context.packageManager.queryBroadcastReceivers(
                Intent(context, IcsShareResultReceiver::class.java),
                0,
            ).isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }
}
