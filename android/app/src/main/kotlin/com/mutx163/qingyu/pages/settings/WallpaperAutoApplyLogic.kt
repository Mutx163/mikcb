package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.weather.BingAutoApplyDecision
import com.mutx163.qingyu.weather.BingWallpaperDaily
import com.mutx163.qingyu.weather.BingWallpaperItem
import com.mutx163.qingyu.weather.BingWallpaperLedger
import com.mutx163.qingyu.weather.DailyApplyOutcome
import com.mutx163.qingyu.weather.WallpaperEvictionPolicy
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 「每天自动更换」的**纯判据层**（Dart `settings_home_backdrop_flow.dart:501-642`）。
 *
 * ## 真源是图库台账，不是草稿
 *
 * 这颗开关写的是 `BingWallpaperStore`（设备级台账），**不走**草稿 / 宿主 `setState`：
 * 弹层正文插在根覆盖层、不在宿主页面的 widget 树下，靠 `setState` 带不动它
 * （Dart `:501-514`，2026-10-06 实报「点了一下没反应」）。Kotlin 侧对应
 * [WallpaperAutoApplySnapshot]：`enabled` 与 [BingWallpaperLedger] 由宿主从台账读出，
 * 开关的 `switchValue` 必须来自它；面板不再猜 `false`。
 *
 * ## 打开就换一次
 *
 * [togglePlan] 把 Dart `_setBingAutoApply` 的动作拆成三件事：落盘开关、
 * 先弹「正在换成今天的壁纸」（`:550-553`）、立刻执行一次自动换（**不等下次启动**）。
 *
 * ## 四种结局各一句提示（Dart `:584-617`）
 *
 * | 结局 | 用户看到的那一句 | ARB |
 * |---|---|---|
 * | 换上了今天那张 | 打开时已经弹过的「正在换成今天的壁纸」——**不重复弹** | `bingWallpaperAutoApplyApplying` |
 * | 换上的是 Bing 最新、但不是今天那张 | 「Bing 还没放出今天的图，先用 {date} 那张顶一下」 | `bingWallpaperAutoApplyStale` |
 * | 今天已经换过 | 「今天已经换过啦」 | `bingWallpaperAutoApplyAlreadyDone` |
 * | 失败（断网 / 没下下来） | 「没能取到 Bing 每日壁纸，请检查网络后重试」（警示样式） | `bingWallpaperGalleryFailed` |
 *
 * 不新增任何中文：四句全部复用 ARB 已有键（[SettingsStringsExt1]）。
 *
 * ## 自动换**不补记**「最近使用」
 *
 * 与手动选图 / 图库挑图不同：自动换每天一条，10 天后用户自己从相册存的那几张会被
 * 挤出并连带删文件（Dart `:568-571`、`:627-641`）。[settingsAfterApply] 因此只改
 * 路径与取景，**不动** `wallpaperHistory`；当前这张仍会由
 * `SettingsBackdropFlowPage.recentEntries` 补在条首。
 */
data class WallpaperAutoApplySnapshot(
    /** 台账里的开关（`BingWallpaperStore.autoApplyEnabled`，缺省 false）。 */
    val enabled: Boolean = false,
    /** 图库下载台账（`bing_wallpaper_v1`，自动换的「今天已换过」判据与下载缓存）。 */
    val ledger: BingWallpaperLedger = BingWallpaperLedger(),
) {
    /** 台账里记着的本地图路径（图库缓存，删淘汰文件时要护住）。 */
    val downloadedPaths: List<String> get() = ledger.downloadedPaths

    /** 最近一次自动换用掉的那天的 `dateKey`；没换过为 null。 */
    val lastAutoAppliedDate: String? get() = ledger.lastAutoAppliedDate
}

/**
 * 拨一次开关要做的事。
 *
 * @property persistEnabled 是否要写台账（`BingWallpaperStore.setAutoApplyEnabled`）。
 * @property showApplying 是否先弹「正在换成今天的壁纸」。
 * @property runApplyOnce 是否立刻执行一次自动换（只有**打开**时为 true）。
 */
data class WallpaperAutoApplyPlan(
    val persistEnabled: Boolean,
    val showApplying: Boolean,
    val runApplyOnce: Boolean,
)

/** 一句要上屏的提示；[warning] 对应 Dart 的 `AppToastKind.warning` + 图标。 */
data class WallpaperAutoApplyNotice(
    val text: ArbText,
    val warning: Boolean = false,
)

object WallpaperAutoApplyLogic {

    /**
     * 开关动作规划（Dart `:537-555`）。
     *
     * * 打开 → 落盘 + 提示 + **立刻换一次**；
     * * 关闭 → 只落盘（不换、不提示）；
     * * 值没变 → 什么都不做（渲染层的回调偶尔会在重组时重放）。
     */
    fun togglePlan(currentEnabled: Boolean, newValue: Boolean): WallpaperAutoApplyPlan = when {
        currentEnabled == newValue -> WallpaperAutoApplyPlan(
            persistEnabled = false,
            showApplying = false,
            runApplyOnce = false,
        )

        newValue -> WallpaperAutoApplyPlan(
            persistEnabled = true,
            showApplying = true,
            runApplyOnce = true,
        )

        else -> WallpaperAutoApplyPlan(
            persistEnabled = true,
            showApplying = false,
            runApplyOnce = false,
        )
    }

    /** 打开时那一句（Dart `:550-553`，属于「换上了今天那张」这四分之一结局的提示）。 */
    fun toggleNotice(): WallpaperAutoApplyNotice =
        WallpaperAutoApplyNotice(SettingsBackdropFlowPage.AUTO_APPLYING)

    /**
     * 「今天是否已经换过」的判据（Dart `BingWallpaperService.maybeApplyDaily` 的判据段，
     * 由 [BingWallpaperDaily.decide] 保证与 Dart 同口径）。
     *
     * 记的是**那张图自己的** dateKey，所以 Bing 之后放出今天那张时判据会自然放行。
     */
    fun decide(
        snapshot: WallpaperAutoApplySnapshot,
        newest: BingWallpaperItem,
        now: LocalDateTime? = null,
    ): BingAutoApplyDecision = BingWallpaperDaily.decide(
        lastAutoAppliedDate = snapshot.lastAutoAppliedDate,
        newest = newest,
        now = now,
    )

    /** 下载成功后的结局：清单最新那张是不是今天。 */
    fun outcomeFor(item: BingWallpaperItem, now: LocalDateTime): BingAutoApplyDecision.Outcome =
        BingWallpaperDaily.outcomeFor(item, now)

    /**
     * 结局 → 那一句提示；null = 这个结局不需要额外出声。
     *
     * | 结局 | 返回值 |
     * |---|---|
     * | [DailyApplyOutcome.AppliedToday] | null（打开时那句「正在换成今天的壁纸」已经给过） |
     * | [DailyApplyOutcome.AppliedStale] | 「…先用 {date} 那张顶一下」 |
     * | [DailyApplyOutcome.AlreadyApplied] | 「今天已经换过啦」 |
     * | [DailyApplyOutcome.Failed] | 「没能取到 Bing 每日壁纸…」（警示） |
     * | [DailyApplyOutcome.Disabled] | null（开关没开就走不到这条路） |
     *
     * @param dateLabel 非今天那张的日期文案（宿主用图库页同一套
     *   `bingWallpaperDateToday` / `_MonthDay` 生成）；为空时用 [dateKey] 现算，
     *   两者都没有就留空，不猜日期。
     * @param dateKey 那张图自己的 `dateKey`（`20261031`）；与 Dart 传 `itemId` 同一口径。
     * @param today 日期标签的「今天」，缺省取本机日期；单测注入固定值。
     */
    fun outcomeNotice(
        outcome: DailyApplyOutcome,
        dateLabel: String? = null,
        dateKey: String? = null,
        today: LocalDate = LocalDate.now(),
    ): WallpaperAutoApplyNotice? = when (outcome) {
        DailyApplyOutcome.AppliedToday -> null
        DailyApplyOutcome.Disabled -> null
        DailyApplyOutcome.AlreadyApplied ->
            WallpaperAutoApplyNotice(SettingsBackdropFlowPage.AUTO_ALREADY_DONE)

        DailyApplyOutcome.AppliedStale -> {
            val template = SettingsBackdropFlowPage.AUTO_STALE
            // Dart 的 `bingWallpaperDateLabel` 解析不出会原样退回 dateKey，绝不显示空白。
            val label = dateLabel?.takeIf { it.isNotBlank() }
                ?: dateKey?.let { SettingsBingWallpaperGalleryPage.dateLabel(it, today) }
                ?: ""
            WallpaperAutoApplyNotice(
                ArbText(template.key, template.filled("date", label)),
            )
        }

        DailyApplyOutcome.Failed -> WallpaperAutoApplyNotice(
            SettingsStringsExt1.bingWallpaperGalleryFailed,
            warning = true,
        )
    }

    /**
     * 自动换成功后要写的设置：路径 + **居中 / 不缩放**，不碰历史（理由见类注释）。
     *
     * 返回 null = 没有可写的路径（失败 / 没换上），调用方原样保留设置。
     */
    fun settingsAfterApply(
        current: TimetableSettingsModel,
        path: String?,
    ): TimetableSettingsModel? {
        if (path.isNullOrBlank()) return null
        return current.copy(
            homePageWallpaperPath = path,
            homePageWallpaperAlignX = 0.0,
            homePageWallpaperAlignY = 0.0,
            homePageWallpaperScale = 1.0,
        )
    }

    /**
     * 自动换淘汰文件的待删清单：过一遍三路并集白名单。
     *
     * 与手动路径共用 [WallpaperEvictionPolicy.evictionWhitelist] —— 自动换写下的那张
     * **不在历史里**，只按历史当白名单会把它删掉、首页当场裂图（Dart `:265-274`）。
     *
     * ⚠️ [allProfilesCurrentPaths] 与 [profilesReadable] **都必填、无默认值**：
     * 可读性必须由调用方显式交代，不能拿「路径非空」推断（所有课表都没壁纸时
     * 空列表仍是可确认的引用快照，此时该删就删；读不到才一张都不删，见 P2-18）。
     */
    fun deletableAfterApply(
        evictedPaths: List<String>,
        allProfilesCurrentPaths: Iterable<String?>?,
        profilesReadable: Boolean,
        draftPath: String? = null,
        snapshot: WallpaperAutoApplySnapshot = WallpaperAutoApplySnapshot(),
    ): List<String> = WallpaperEvictionPolicy.deletable(
        evictedPaths = evictedPaths,
        whitelist = WallpaperEvictionPolicy.evictionWhitelist(
            allProfilesCurrentPaths = allProfilesCurrentPaths,
            profilesReadable = profilesReadable,
            draftPath = draftPath,
            galleryLedgerPaths = snapshot.downloadedPaths,
        ),
    )
}
