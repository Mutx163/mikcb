package com.mutx163.qingyu.pages.about

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.infra.MaintainerGroup
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 代码贡献者页 · Compose 渲染层（2026-10-28 新建）。
 *
 * 对照 Flutter `ContributorsScreen`（`about_screen.dart:2291-2557`）：
 * 开发人员卡 + 教务导入适配者卡（加载/失败/空/分组）+ 参与适配卡（打开适配仓 / 复制地址）。
 *
 * ## 数据从哪来
 *
 * 与 Flutter 一致：适配者名单由宿主提供（Flutter 是网络拉取 + 本地缓存）。
 * 本渲染层只按 [maintainers] / [isLoading] / [error] / [cachedAt] 四态画，不自己发网络——
 * 2026-10-29（F09）起宿主是 [ContributorsHostPage]：读 `index/root_index.yaml` +
 * 每校 `adapters.yaml`（见 `WarehouseMaintainersFeed`），缓存优先、后台刷新、失败可重试。
 *
 * ## 文案纪律
 *
 * 无中文字面量，全部取自 main 层 [ContributorsStrings]。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ContributorsPage(
    maintainers: List<MaintainerGroup>,
    isLoading: Boolean,
    error: String?,
    onBack: () -> Unit,
    onReload: () -> Unit,
    /**
     * 当前展示的名单是**缓存**时，这份缓存被写入的时刻（已格式化，见
     * `formatMaintainersCacheTime`）。null = 展示的是刚拉到的数据。
     *
     * 为什么必须有这个参数：缓存优先 + 后台刷新的页面，用户看到「有名单」并不等于
     * 「刚刚拉到」；不标时间就等于把昨天的名单当成今天的结果（F09 验收第一条）。
     */
    cachedAt: String? = null,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val groups = sortedContributorGroups(maintainers)

    QingyuPageScaffold(title = ContributorsStrings.screenTitle, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 官方配方：页面横向 0，留白由每个块自己带（卡片 12dp）——
            // 与关于/更新/捐助页同一套刻度（滚动条位置与此无关：miuix 竖条只用
            // trackPadding 的上下两个值，左右两个值不参与定位）。
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
            // 全族统一 12dp 段间距（原先这里独写 8dp，与本域其它页不是一套刻度）。
            verticalArrangement = AboutPageListSpacing,
        ) {
            // 一组 = 一个 item：标题与卡片之间不再夹一层列表间距，
            // 标题到卡片顶只剩 SmallTitle 自带的 8dp（官方 demo 的「段首贴合」）。
            // 2026-11-10 版面收口：原先标题与卡片各占一个 item，加 8dp 列表间距后
            // 标题到卡顶是 16dp，比同域的关于/更新/捐助页都松一档。

            // ── 开发人员 ──
            item(key = "developers") {
                QingyuSectionTitle(
                    text = ContributorsStrings.developersTitle,
                    // 列表已统一加 12dp，标题这里只让 16dp ⇒ 12 + 16 = 官方 28dp 轴线，
                    // 与卡内行文字的左缘落在同一条竖线上（默认 28 会变成 40，缩进一格）。
                    insideMargin = ContributorSectionTitleMargin,
                )
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    // 设置组语义圆角 24（与关于页分段卡同层同一套圆角，不再被默认压成 16）。
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    ContributorRow(
                        name = ContributorsStrings.developerName,
                        subtitle = ContributorsStrings.developerSubtitle,
                    )
                }
            }

            // ── 教务导入适配者 ──
            item(key = "maintainers") {
                QingyuSectionTitle(
                    text = ContributorsStrings.maintainersTitle,
                    insideMargin = ContributorSectionTitleMargin,
                )
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        // 卡头说明：为什么有这份名单、名单怎么来的。
                        // 与下面的名单之间**不画线**：行距由行内边距承担（发布版那条
                        // `Divider(height: 24)` 的视觉作用就是 24dp 留白；全仓
                        // `RowDividerGuardTest` 也明确禁止卡内行间横线）。
                        Column(
                            modifier = Modifier.padding(
                                start = 16.dp,
                                top = 14.dp,
                                end = 16.dp,
                                bottom = 2.dp,
                            ),
                        ) {
                            Text(
                                text = ContributorsStrings.maintainersIntro,
                                style = MiuixTheme.textStyles.footnote1,
                                lineHeight = 19.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                            // 缓存时间：只在「正在显示上次缓存」时出现，后台刷新成功后本行自动消失。
                            cachedAt?.let { time ->
                                Text(
                                    text = ContributorsStrings.cachedAtLabel(time),
                                    style = MiuixTheme.textStyles.footnote2,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                    modifier = Modifier.padding(top = 6.dp),
                                )
                            }
                        }

                        when {
                            // 「转圈」只用于**手上什么都没有**的时候。已有缓存时后台还在刷新：
                            // 继续显示旧数据，靠上面那行缓存时间说明它有多旧——本页自己的说明句
                            // 就写着「若本地已有缓存，会先显示缓存，再后台刷新」，被转圈盖住等于说话不算数。
                            // D1 档 A2（块内居中）：共享件自带 120dp 最小高度，不再手写
                            // padding(vertical = 24)（全仓原先 8/24/28/32 六档混用）。
                            isLoading && groups.isEmpty() -> QingyuLoadingCenter(fillPage = false)

                            error != null && groups.isEmpty() -> Column(
                                modifier = Modifier.padding(
                                    start = 16.dp,
                                    top = 12.dp,
                                    end = 16.dp,
                                    bottom = 8.dp,
                                ),
                                verticalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Text(
                                    text = ContributorsStrings.loadFailed(error),
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.error(dark)),
                                )
                                TextButton(
                                    text = ContributorsStrings.reloadAction,
                                    onClick = onReload,
                                )
                            }

                            groups.isEmpty() -> Text(
                                text = ContributorsStrings.maintainersEmpty,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(
                                    start = 16.dp,
                                    top = 14.dp,
                                    end = 16.dp,
                                    bottom = 16.dp,
                                ),
                            )

                            else -> {
                                // 有缓存但刷新失败：名单照常显示（比空屏有用），但要如实说明
                                // 「这次没拉到」并给重试，不许让旧数据冒充刚刷新的结果。
                                if (error != null) {
                                    Column(
                                        modifier = Modifier.padding(
                                            start = 16.dp,
                                            top = 8.dp,
                                            end = 16.dp,
                                            bottom = 0.dp,
                                        ),
                                        verticalArrangement = Arrangement.spacedBy(4.dp),
                                    ) {
                                        Text(
                                            text = ContributorsStrings.loadFailed(error),
                                            style = MiuixTheme.textStyles.footnote1,
                                            color = Color(QingyuTheme.error(dark)),
                                        )
                                        TextButton(
                                            text = ContributorsStrings.reloadAction,
                                            onClick = onReload,
                                        )
                                    }
                                }
                                // 一个适配者一行，行与行之间不画线（同上：全仓禁止卡内行间横线），
                                // 靠行自身的上下 12dp 内边距把两个人分开——一人一行里最多带三四条
                                // 适配项，名字又是加粗的起始行，不加线也读得清。
                                for (group in groups) {
                                    ContributorRow(
                                        name = group.name,
                                        subtitle = ContributorsStrings.maintainerCount(
                                            group.adapterLabels.size,
                                        ),
                                        details = group.adapterLabels,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ── 参与适配 ──
            item(key = "participate") {
                QingyuSectionTitle(
                    text = ContributorsStrings.participateTitle,
                    insideMargin = ContributorSectionTitleMargin,
                )
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 16.dp),
                    ) {
                        Text(
                            text = ContributorsStrings.participateSubtitle,
                            style = MiuixTheme.textStyles.footnote1,
                            lineHeight = 20.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(Modifier.height(12.dp))
                        // 发布版是 `Wrap(spacing: 10, runSpacing: 10)`：大字号下两个按钮放不下时
                        // 换行，而不是被挤出屏幕。Compose 侧的等价物是官方 `FlowRow`。
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Button(
                                onClick = { openUrl(context, ContributorsStrings.warehouseRepoUrl) },
                                // 发布版 HyperosButton 默认 primary：强调色实心底。
                                // 原先用了灰色的 `buttonColors()`，与右侧文字链接并列时
                                // 两个都像次要动作，主次关系反了（2026-11-10 修）。
                                colors = ButtonDefaults.buttonColorsPrimary(),
                            ) {
                                Text(ContributorsStrings.openWarehouseRepoAction)
                            }
                            // 发布版第二颗是 secondary 变体（灰底实心），不是纯文字链接。
                            Button(
                                onClick = {
                                    copyToClipboard(context, ContributorsStrings.warehouseRepoUrl)
                                    Toast.makeText(
                                        context,
                                        ContributorsStrings.copiedAddress,
                                        Toast.LENGTH_SHORT,
                                    ).show()
                                },
                                colors = ButtonDefaults.buttonColors(),
                            ) {
                                Text(ContributorsStrings.copyAddress)
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 分组标题内边距：列表已经统一给了 12dp（[QingyuPageCardMargin]），标题这里再让 16dp，
 * 合计正好落在官方 28dp 轴线上（12 页边 + 16 行内）。
 */
private val ContributorSectionTitleMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp)

/**
 * 一行贡献者：名字 + 副标题 +（可选）适配项 bullet 列表。
 *
 * 行高与留白照发布版 `_ContributorRow`（`about_screen.dart:2783-2817`）：
 * 名字与副标题之间 4dp、副标题与适配项之间 8dp、每条适配项底 4dp；
 * 行自身左右 16dp（与官方 Preference 同值）、上下 12dp。
 * 适配项用 footnote1（发布版 `listDetail` 同档），不用 footnote2——11sp 的列表项
 * 在 400dp 屏上会跟副标题混成同一种小字。
 */
@Composable
private fun ContributorRow(
    name: String,
    subtitle: String,
    details: List<String> = emptyList(),
) {
    val dark = isSystemInDarkTheme()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            text = name,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = subtitle,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        if (details.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            for (detail in details) {
                Text(
                    text = "• $detail",
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(bottom = 4.dp),
                )
            }
        }
    }
}

/** 用系统浏览器打开一个外部链接。 */
private fun openUrl(context: Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

/** 复制文本到剪贴板。 */
private fun copyToClipboard(context: Context, text: String) {
    val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    manager?.setPrimaryClip(ClipData.newPlainText("", text))
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，首批样板：给全库「批量铺」照抄用）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 5 档（渲染层会收到的全部输入组合）：有数据 / 空 / 加载中 / 失败 / 有缓存；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 暗色 —— 历史上出现过「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()）；这一档就是防它复发；
//   · 大字号 —— 行内文案 11 / 17 字的折行点，只在字被放大后才暴露；
//   · 空 / 加载 / 失败 / 缓存 —— 四条分支各有自己的文案与按钮，最容易只改了其中一条。
//
// 批量铺的固定写法（照这三条抄，别自己想）：
//   • 主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }：页面里 91 处取色
//     走 isSystemInDarkTheme()，只有它会把 LocalConfiguration 的 uiMode 一起改写，
//     预览才和真机同口径；
//   • 字号用 QingyuPageTheme(textScale = …)，不要用 @Preview(fontScale = …)：后者只改
//     基准 density，绕过了应用的 appTextScale 口径；
//   • 宽度按 400dp（本仓折行实测口径），高度给一屏多，避免列表被截断看不清。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：两个人、三条适配项，足够撑出一张多行卡片。 */
private fun previewContributorGroups(): List<MaintainerGroup> = listOf(
    MaintainerGroup(
        name = "张三",
        adapterLabels = listOf("示例大学 · 本科教务", "示例大学 · 图书馆借阅"),
    ),
    MaintainerGroup(
        name = "李四",
        adapterLabels = listOf("示例学院 · 研究生教务"),
    ),
)

/**
 * 渲染层会收到的**全部**输入组合，五档不多不少。
 *
 * 这五档就是 `ContributorsHostPage` 能传给 [ContributorsPage] 的所有形态：
 * 有数据 / 空 / 加载中 / 失败 / 展示上次缓存。改参数或任一分支的文案，
 * 先在这五档里看有没有画歪，再谈真机。
 */
private data class PreviewContributorsState(
    /** 只用来给预览命名，不参与渲染。 */
    val name: String,
    val maintainers: List<MaintainerGroup>,
    val isLoading: Boolean,
    val error: String?,
    val cachedAt: String?,
)

private val previewStates: List<PreviewContributorsState> = listOf(
    PreviewContributorsState(
        name = "有数据",
        maintainers = previewContributorGroups(),
        isLoading = false,
        error = null,
        cachedAt = null,
    ),
    PreviewContributorsState(
        name = "空态",
        maintainers = emptyList(),
        isLoading = false,
        error = null,
        cachedAt = null,
    ),
    PreviewContributorsState(
        name = "加载中",
        maintainers = emptyList(),
        isLoading = true,
        error = null,
        cachedAt = null,
    ),
    PreviewContributorsState(
        name = "失败",
        maintainers = emptyList(),
        isLoading = false,
        error = "网络连接超时",
        cachedAt = null,
    ),
    PreviewContributorsState(
        name = "有缓存",
        maintainers = previewContributorGroups(),
        isLoading = false,
        error = null,
        cachedAt = "11-08 10:24",
    ),
)

private fun previewState(name: String): PreviewContributorsState =
    previewStates.first { it.name == name }

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewContributorsPage(
    state: PreviewContributorsState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        ContributorsPage(
            maintainers = state.maintainers,
            isLoading = state.isLoading,
            error = state.error,
            onBack = {},
            onReload = {},
            cachedAt = state.cachedAt,
        )
    }
}

// ── 单档：五态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewData() {
    PreviewContributorsPage(previewState("有数据"))
}

@Suppress("unused")
@Preview(name = "2 空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewEmpty() {
    PreviewContributorsPage(previewState("空态"))
}

@Suppress("unused")
@Preview(name = "3 加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewLoading() {
    PreviewContributorsPage(previewState("加载中"))
}

@Suppress("unused")
@Preview(name = "4 失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewError() {
    PreviewContributorsPage(previewState("失败"))
}

@Suppress("unused")
@Preview(name = "5 有缓存", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewCached() {
    PreviewContributorsPage(previewState("有缓存"))
}

// ── 单档：外观两档（以「有数据」为基准，其余状态换外观直接加参数）───────────

@Suppress("unused")
@Preview(name = "6 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewDark() {
    PreviewContributorsPage(previewState("有数据"), dark = true)
}

@Suppress("unused")
@Preview(name = "7 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ContributorsPagePreviewLargeText() {
    PreviewContributorsPage(previewState("有数据"), textScale = 1.3f)
}

// ── 总览：五态并排，一屏看完 ────────────────────────────────────────────────

/**
 * 一屏总览：五种状态横向并排，用来一眼比结构差异（谁多了 / 少了哪一块）。
 *
 * 5 × 400dp + 4 × 16dp 间距 = 2064dp，所以画布给 2100dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~7 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·五态并排", showBackground = true, widthDp = 2100, heightDp = 900)
@Composable
private fun ContributorsPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (state in previewStates) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewContributorsPage(state)
            }
        }
    }
}

// ── 整页档（1200dp）────────────────────────────────────────────────────────
//
// 900dp 的一屏档只能看到前两张卡，第三张「参与适配」会被裁掉；整页档按页面
// 真实长度给 1200dp，用来检查三张卡的整页节奏（组距、卡高、末项留白）。
// 原 900 档保留，两档用途不同：900 看首屏观感，1200 看整页版式。

@Suppress("unused")
@Preview(name = "8 整页", showBackground = true, widthDp = 400, heightDp = 1200)
@Composable
private fun ContributorsPagePreviewFullPage() {
    PreviewContributorsPage(previewState("有数据"))
}
