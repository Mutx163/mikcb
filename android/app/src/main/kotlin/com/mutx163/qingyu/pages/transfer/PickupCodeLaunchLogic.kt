package com.mutx163.qingyu.pages.transfer

/**
 * 「取件码」页的**多级回退执行器**（移植自 `lib/services/pickup_code_runner.dart`，全量纯逻辑）。
 *
 * ## 为什么单独一层
 *
 * 回退顺序本身是业务规则，不是界面细节：直达链接逐条试 → 全失败逐个拉起官方 App →
 * 还不行才用网页兜底 → 全失败才报错。把它写在 Composable 里就只能靠真机点七个入口
 * 来验证；抽到这一层后，用假 [PickupCodePlatform] 记调用顺序就能把「第 1 条失败了才试
 * 第 2 条」「直达成功就不许再拉起 App」这类断言钉住（JVM 单测）。
 *
 * ## 与 Dart 的映射
 *
 * | Dart | 这里 |
 * |---|---|
 * | `PickupCodePlatform.launchUri/launchApp/installedPackages` | [PickupCodePlatform] 同签名 |
 * | `PickupCodeRunStatus` | [PickupCodeRunStatus]（枚举名保持一一对应，只是 Kotlin 用大写） |
 * | `kPickupCodeRunBudget` = 4s | [DEFAULT_BUDGET_MILLIS] |
 *
 * 总预算的意义照抄 Dart 注释：抖音那条入口有 4 条链接 + 2 个包名，单次通道调用超时 10 秒，
 * 不设上限时最坏要多轮等满 —— 用户站在柜子前看着转圈一两分钟。4 秒是「人还能忍」与
 * 「真机绝大多数成功调用在几百毫秒内」之间取的。
 */
object PickupCodeRunStatus {
    /** 直达链接被目标 App 接住（最好情况）。 */
    const val LAUNCHED = "launched"

    /** 直达全失败，只拉起官方 App（用户要自己在 App 里找页面）。 */
    const val OPENED_APP = "opened_app"

    /** App 级兜底也失败，最后用网页打开。 */
    const val OPENED_WEB = "opened_web"

    /** 全部失败。 */
    const val FAILED = "failed"

    /** 当前平台没有外部跳转能力。 */
    const val UNSUPPORTED = "unsupported"
}

/** 一次跳转的返回值（Dart `{ok: Boolean, reason: String?}` 的 Kotlin 投影）。 */
data class PickupCodeLaunchOutcome(
    val ok: Boolean,
    val reason: String? = null,
)

/** 一次点击最终走到了哪一级（`PickupCodeRunner.run` 的结果）。 */
data class PickupCodeRunResult(
    val status: String,
    /** 最后一次失败的原因码；成功时为 null。 */
    val reason: String? = null,
) {
    val ok: Boolean
        get() = status == PickupCodeRunStatus.LAUNCHED ||
            status == PickupCodeRunStatus.OPENED_APP ||
            status == PickupCodeRunStatus.OPENED_WEB
}

/**
 * 平台能力注入点（Dart `PickupCodePlatform`）。
 *
 * 生产实现是 `com.mutx163.qingyu.PickupCodeLauncher`（Android `Intent`），
 * 单测用一个记调用顺序的假实现即可。**不放进 `main` 的任何 Android 依赖**：
 * 本接口只有 String/Boolean，`pages/transfer` 因此仍可进 L0 的 JVM classpath。
 */
interface PickupCodePlatform {
    /** 当前平台有没有外部跳转能力（桌面 / 测试环境为 false）。 */
    val supported: Boolean

    fun launchUri(uri: String, packageName: String?, clearTask: Boolean): PickupCodeLaunchOutcome

    fun launchApp(packageName: String, clearTask: Boolean): PickupCodeLaunchOutcome

    /** 批量查「装了没」；返回 null = 查不到（调用方退回逐个试）。 */
    fun installedPackages(packages: List<String>): Set<String>?
}

/** 多级回退执行器。时间源可注入，预算判定因此可测。 */
class PickupCodeRunner(
    private val platform: PickupCodePlatform,
    private val budgetMillis: Long = DEFAULT_BUDGET_MILLIS,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    /**
     * 跑一条入口。
     *
     * @param alreadyInstalled 进页面时批量查到的「已安装包名」——传了就跳过没装的 App
     *   （`getLaunchIntentForPackage` 必然返回空，白等一轮，有些机型要走满通道超时）。
     */
    fun run(
        preset: PickupCodesModel.Preset,
        alreadyInstalled: Set<String>? = null,
    ): PickupCodeRunResult {
        if (!platform.supported) {
            return PickupCodeRunResult(PickupCodeRunStatus.UNSUPPORTED)
        }
        val startedAt = clock()
        fun budgetLeft(): Boolean = clock() - startedAt < budgetMillis

        var lastReason: String? = null

        for (link in preset.links) {
            if (!budgetLeft()) {
                return PickupCodeRunResult(PickupCodeRunStatus.FAILED, PickupCodesModel.REASON_TIMEOUT)
            }
            val uri = link.uri.trim()
            if (uri.isEmpty()) {
                continue
            }
            val outcome = platform.launchUri(uri, link.packageName, preset.clearTask)
            if (outcome.ok) {
                return PickupCodeRunResult(PickupCodeRunStatus.LAUNCHED)
            }
            lastReason = outcome.reason ?: lastReason
        }

        for (packageName in preset.appPackages) {
            if (alreadyInstalled != null && !alreadyInstalled.contains(packageName)) {
                lastReason = lastReason ?: PickupCodesModel.REASON_APP_NOT_FOUND
                continue
            }
            if (!budgetLeft()) {
                return PickupCodeRunResult(PickupCodeRunStatus.FAILED, PickupCodesModel.REASON_TIMEOUT)
            }
            val outcome = platform.launchApp(packageName, preset.clearTask)
            if (outcome.ok) {
                return PickupCodeRunResult(PickupCodeRunStatus.OPENED_APP)
            }
            lastReason = outcome.reason ?: lastReason
        }

        val webUri = preset.webUri?.trim()
        if (!webUri.isNullOrEmpty()) {
            if (!budgetLeft()) {
                return PickupCodeRunResult(PickupCodeRunStatus.FAILED, PickupCodesModel.REASON_TIMEOUT)
            }
            val outcome = platform.launchUri(webUri, null, preset.clearTask)
            if (outcome.ok) {
                return PickupCodeRunResult(PickupCodeRunStatus.OPENED_WEB)
            }
            lastReason = outcome.reason ?: lastReason
        }

        return PickupCodeRunResult(PickupCodeRunStatus.FAILED, lastReason)
    }

    /** 进页面时批量查「哪些 App 装了」；查不到返回 null（调用方据此退回逐个试）。 */
    fun installedPackages(packages: List<String>): Set<String>? {
        if (!platform.supported || packages.isEmpty()) {
            return null
        }
        return runCatching { platform.installedPackages(packages) }.getOrNull()
    }

    companion object {
        /** 一次点击最多花多久（Dart `kPickupCodeRunBudget`）。 */
        const val DEFAULT_BUDGET_MILLIS = 4_000L
    }
}

/**
 * 结果 → 屏上那句话（Dart `_openEntry` 的 switch，:86-113）。
 *
 * 返回 null = **什么都不弹**。这条不是省事：直达成功时目标 App 已经切到前台，
 * 此时再弹「已打开」只会挡着用户；网页兜底成功同理（浏览器已经在前面）。
 */
object PickupCodeFeedback {
    fun toastFor(preset: PickupCodesModel.Preset, result: PickupCodeRunResult): String? =
        when (result.status) {
            PickupCodeRunStatus.LAUNCHED, PickupCodeRunStatus.OPENED_WEB -> null
            PickupCodeRunStatus.OPENED_APP ->
                PickupCodesModel.openedAppToast(PickupCodesModel.entryTitle(preset))
            PickupCodeRunStatus.UNSUPPORTED -> PickupCodesModel.unsupportedMessage
            else -> PickupCodesModel.launchFailedMessage(
                PickupCodesModel.entryTitle(preset),
                result.reason ?: PickupCodesModel.REASON_UNKNOWN_FALLBACK,
            )
        }

    /** 失败时第二行建议（Dart `pickupCodeLaunchFailedHint`）；非失败返回 null。 */
    fun hintFor(result: PickupCodeRunResult): String? =
        if (result.status == PickupCodeRunStatus.FAILED) PickupCodesModel.launchFailedHint else null
}
