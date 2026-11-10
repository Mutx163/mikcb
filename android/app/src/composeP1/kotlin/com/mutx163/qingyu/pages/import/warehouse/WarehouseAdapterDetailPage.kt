package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuLoadingProgressBar
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 适配器详情页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_adapter_detail_screen.dart`：
 * 1. 适配器元数据卡片（名称、分类、维护者、学校代码）；
 * 2. 脚本使用说明与描述；
 * 3. 自定义登录入口地址覆盖编辑与恢复；
 * 4. 复制地址、脚本链接及直接拉起网页登录。
 *
 * 2026-11-04 排版重排（对照 Flutter 发布版的「分组标题 + 卡片」信息节奏）：
 * - 原本四张卡片**没有分组标题、彼此竖直贴死**、卡内标题层级不一（元数据卡无标题、
 *   其余卡自带 body1 标题），整页看不出信息分组 ⇒ 统一改成官方配方
 *   「[QingyuSectionTitle] → [QingyuCard]」一组一个 `item`，卡间统一 12dp 竖向间距；
 * - 元数据行改成「左标签 / 右取值右对齐 + 可换行」，长值（类别、适配者、学校代码）不再挤压或溢出；
 * - 卡内重复的标题（"使用说明""链接与调试"）上提为分组标题，链接分组复用 ARB 文案「更多操作」。
 */
@Composable
fun WarehouseAdapterDetailPage(
    school: WarehouseSchoolEntry,
    adapter: WarehouseAdapterEntry,
    customImportUrl: String? = null,
    onBack: () -> Unit = {},
    onSaveCustomUrl: (String) -> Unit = {},
    onClearCustomUrl: () -> Unit = {},
    onCopyLoginUrl: () -> Unit = {},
    onCopyScriptUrl: () -> Unit = {},
    onOpenWebLogin: () -> Unit = {},
    /**
     * 脚本正文的拉取状态（2026-11-05 新增槽位，宿主已填值）。
     *
     * 渲染见 [ScriptStatusBody]：`Loading` → 不确定进度条；`Loaded(length)` → 「已成功读取，
     * N 字符」；`Empty` → 「脚本为空」（错误色）；`Failed` → 「无法读取适配器脚本」（错误色，
     * 键 `warehouseScriptLoadFailed`）。
     *
     * `Failed.issue` 这一批**不上屏**：四档原因那句都靠 `attempts` 或与本屏无关的处置建议，
     * 而 `Failed` 契约里没有 attempts。就是一句话的事，不再为它动已锁的契约。
     *
     * 默认 [WarehouseScriptStatus.Loading]：还没接宿主的调用点看起来就是「正在读取」，
     * 不会误报成「脚本坏了」。
     */
    scriptStatus: WarehouseScriptStatus = WarehouseScriptStatus.Loading,
) {
    var editUrl by remember(customImportUrl) { mutableStateOf(customImportUrl ?: "") }
    val isCustomized = !customImportUrl.isNullOrBlank()

    // Dart warehouse_adapter_detail_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题，
    // 标题取适配器名（与 Flutter 发布版 `title: Text(adapter.adapterName)` 一致），
    // 避免与下方「适配器信息」分组标题重复。骨架、顶栏、返回键走共享套件（R1）；滚动走 QingyuPageList（R2）。
    QingyuPageScaffold(
        title = adapter.adapterName.ifEmpty { WarehouseStrings.adapterInfoTitle.text },
        onBack = onBack,
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MiuixTheme.colorScheme.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                Button(
                    onClick = onOpenWebLogin,
                    modifier = Modifier.fillMaxWidth(),
                    content = { Text(text = WarehouseStrings.openLoginInAppAction.text) },
                )
            }
        },
    ) {
        // 页面横向留白由每张卡片自带 12dp；配合卡内 16dp = 文字左缘 28dp，
        // 与 QingyuSectionTitle 默认 28dp 左缘对齐（样式规范 §三 标准配方）。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            // ── 分组：适配器信息（名称 / 学校 / 类别 / 适配者 / 学校代码）──
            item(key = "meta") {
                QingyuSectionTitle(WarehouseStrings.adapterInfoTitle.text)
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(bottom = QingyuSectionGap),
                    // 卡片里是普通内容（非 Preference 行），内边距必须自己给。
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = adapter.adapterName,
                            style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = school.name,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = MiuixTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        HorizontalDivider()
                        Spacer(modifier = Modifier.height(12.dp))

                        DetailMetaRow(WarehouseStrings.categoryLabel.text, adapter.category)
                        Spacer(modifier = Modifier.height(8.dp))
                        DetailMetaRow(WarehouseStrings.maintainerLabel.text, adapter.maintainer.ifEmpty { "社区成员" })
                        if (adapter.schoolCode.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(8.dp))
                            DetailMetaRow("学校代码", adapter.schoolCode)
                        }
                    }
                }
            }

            // ── 分组：脚本状态 ──
            // 发布版（`warehouse_adapter_detail_screen.dart:124-159`）把这一组紧跟「适配器信息」：
            // 用户点进详情最想先确认的就是「这个适配器的脚本到底能不能用」。
            item(key = "script_status") {
                QingyuSectionTitle(WarehouseStrings.scriptStatusTitle.text)
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(bottom = QingyuSectionGap),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    ScriptStatusBody(scriptStatus)
                }
            }

            // ── 分组：使用说明 ──
            if (adapter.description.isNotBlank()) {
                item(key = "desc") {
                    QingyuSectionTitle("使用说明")
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(bottom = QingyuSectionGap),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Text(
                            text = adapter.description,
                            style = MiuixTheme.textStyles.footnote1,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            lineHeight = 18.sp,
                        )
                    }
                }
            }

            // ── 分组：自定义登录地址 ──
            item(key = "custom_url") {
                QingyuSectionTitle(WarehouseStrings.customLoginAddressAction.text)
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(bottom = QingyuSectionGap),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = if (isCustomized) {
                                WarehouseStrings.adapterOverrideImportUrlHint.text
                            } else {
                                "可覆盖默认登录地址（如学校内网或 VPN 登录页）"
                            },
                            style = MiuixTheme.textStyles.footnote1,
                            color = if (isCustomized) {
                                MiuixTheme.colorScheme.primary
                            } else {
                                MiuixTheme.colorScheme.onSurfaceVariantSummary
                            },
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        TextField(
                            value = editUrl,
                            onValueChange = { editUrl = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = adapter.importUrl.ifEmpty { "https://..." },
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Button(
                                onClick = { onSaveCustomUrl(editUrl) },
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.saveAction.text) },
                            )
                            if (isCustomized) {
                                Button(
                                    onClick = {
                                        editUrl = ""
                                        onClearCustomUrl()
                                    },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.clearCustomLoginAddressAction.text) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.secondary,
                                        contentColor = MiuixTheme.colorScheme.error,
                                    ),
                                )
                            }
                        }
                    }
                }
            }

            // ── 分组：更多操作（复制登录地址 / 复制脚本地址）──
            item(key = "links") {
                QingyuSectionTitle(WarehouseStrings.moreActionsTooltip.text)
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(bottom = QingyuSectionGap),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Button(
                            onClick = onCopyLoginUrl,
                            modifier = Modifier.weight(1f),
                            content = { Text(text = WarehouseStrings.copyLoginAddressAction.text) },
                            colors = ButtonDefaults.buttonColors(
                                color = MiuixTheme.colorScheme.secondary,
                                contentColor = MiuixTheme.colorScheme.primary,
                            ),
                        )
                        Button(
                            onClick = onCopyScriptUrl,
                            modifier = Modifier.weight(1f),
                            content = { Text(text = WarehouseStrings.copyScriptAddressAction.text) },
                            colors = ButtonDefaults.buttonColors(
                                color = MiuixTheme.colorScheme.secondary,
                                contentColor = MiuixTheme.colorScheme.primary,
                            ),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 脚本状态卡的正文：四态各一句（对齐发布版 `warehouse_adapter_detail_screen.dart:125-159`）。
 *
 * - 读取中用**不确定进度条**而不是转圈：发布版是 3dp 的 `HyperosLinearProgress(minHeight: 3)`，
 *   同样是「还在读」，横条更贴卡片的行内排版；
 * - 「空」与「读不到」都是「这个适配器现在用不了」，发布版同样用错误色，这里一致；
 * - 只画一句人话，不把 `code` 摆上屏（那串对用户毫无意义，留给日志）。
 */
@Composable
private fun ScriptStatusBody(status: WarehouseScriptStatus) {
    when (status) {
        // 档 D（D1 统一，评审 D1-2）：不确定进度的「正在读取」走套件，条高/配色由套件钉住；
        // 这里传 null 就是官方的不确定进度动画，语义与原来的 `LinearProgressIndicator(progress = null)` 等价。
        is WarehouseScriptStatus.Loading -> QingyuLoadingProgressBar(
            progress = null,
            modifier = Modifier.fillMaxWidth(),
        )

        is WarehouseScriptStatus.Loaded -> Text(
            text = WarehouseStrings.scriptLoadedLength.filled("count", status.length.toString()),
            style = MiuixTheme.textStyles.footnote1,
        )

        is WarehouseScriptStatus.Empty -> Text(
            text = WarehouseStrings.scriptEmpty.text,
            style = MiuixTheme.textStyles.footnote1,
            color = MiuixTheme.colorScheme.error,
        )

        is WarehouseScriptStatus.Failed -> Text(
            // 「无法读取适配器脚本」：比「无法读取脚本文件」更贴这一屏（用户在看的是适配器详情）。
            // `Failed.issue` 仍不上屏——四档原因那句都在列表页那台机器上，这里只说清「脚本没读到」。
            text = WarehouseStrings.warehouseScriptLoadFailed.text,
            style = MiuixTheme.textStyles.footnote1,
            color = MiuixTheme.colorScheme.error,
        )
    }
}

/**
 * 元数据一行：左侧标签（次要色）+ 右侧取值（右对齐、可换行）。
 *
 * 取值用 `weight(1f)` 吃掉剩余宽度并右对齐，长文本（长类别名 / 长适配者名 / 学校代码）
 * 会折行而不是把标签挤走或溢出屏幕——这是原 `SpaceBetween` 写法在窄屏下的主要乱源。
 */
@Composable
private fun DetailMetaRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            modifier = Modifier.padding(end = 16.dp),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.End,
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄）：主题包 `QingyuPageTheme(isDark = …)`，
// 字号用 `textScale = …`（不用 `@Preview(fontScale = …)`），宽度 400dp 是本仓折行实测口径。
//
// 本页两个维度：脚本状态四态（读取中 / 已读取 / 空 / 读不到）与自定义地址是否已生效
// （生效后才多一颗「清除」）。四态文案各一句、颜色还不同，只测一态等于没测。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用：一所示例学校。 */
private val previewDetailSchool = WarehouseSchoolEntry(
    id = "example-university",
    name = "示例大学",
    initial = "S",
    category = "本科教务",
    code = "10001",
    province = "示例省",
)

/** 预览用：一个描述较长、字段填满的适配器，专门看长取值会不会把标签挤走。 */
private val previewDetailAdapter = WarehouseAdapterEntry(
    id = "example-university-undergrad",
    name = "本科教务系统",
    script = "// 预览用占位脚本，不执行",
    description = "登录教务处后依次点开「学生服务 → 我的课表」，脚本会把当学期课表拓成结构化数据；若学校改了登录页地址，请在下方自定义入口里改写。",
    category = "本科教务（仅限在校生）",
    maintainer = "张三",
    importUrl = "https://jw.example.edu.cn/login",
    schoolCode = "10001",
)

/** 一档预览的公共身体：脚本状态 + 自定义地址 + 外观档位。 */
@Composable
private fun PreviewWarehouseAdapterDetailPage(
    scriptStatus: WarehouseScriptStatus = WarehouseScriptStatus.Loading,
    customImportUrl: String? = null,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        WarehouseAdapterDetailPage(
            school = previewDetailSchool,
            adapter = previewDetailAdapter,
            customImportUrl = customImportUrl,
            onBack = {},
            onSaveCustomUrl = { _ -> },
            onClearCustomUrl = {},
            onCopyLoginUrl = {},
            onCopyScriptUrl = {},
            onOpenWebLogin = {},
            scriptStatus = scriptStatus,
        )
    }
}

@Suppress("unused")
@Preview(name = "1 脚本读取中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewLoading() {
    PreviewWarehouseAdapterDetailPage(scriptStatus = WarehouseScriptStatus.Loading)
}

@Suppress("unused")
@Preview(name = "2 脚本已读取", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewLoaded() {
    PreviewWarehouseAdapterDetailPage(scriptStatus = WarehouseScriptStatus.Loaded(length = 4820))
}

@Suppress("unused")
@Preview(name = "3 脚本为空", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewEmptyScript() {
    PreviewWarehouseAdapterDetailPage(scriptStatus = WarehouseScriptStatus.Empty)
}

@Suppress("unused")
@Preview(name = "4 脚本读不到", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewScriptFailed() {
    PreviewWarehouseAdapterDetailPage(
        scriptStatus = WarehouseScriptStatus.Failed(
            code = "script_fetch_failed",
            issue = WarehouseLoadIssue.INVALID_FORMAT,
        ),
    )
}

@Suppress("unused")
@Preview(name = "5 已自定义登录地址", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewCustomUrl() {
    PreviewWarehouseAdapterDetailPage(
        scriptStatus = WarehouseScriptStatus.Loaded(length = 4820),
        customImportUrl = "https://jw.example.edu.cn/login",
    )
}

@Suppress("unused")
@Preview(name = "6 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewDark() {
    PreviewWarehouseAdapterDetailPage(
        scriptStatus = WarehouseScriptStatus.Loaded(length = 4820),
        dark = true,
    )
}

@Suppress("unused")
@Preview(name = "7 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseAdapterDetailPagePreviewLargeText() {
    PreviewWarehouseAdapterDetailPage(
        scriptStatus = WarehouseScriptStatus.Loaded(length = 4820),
        textScale = 1.3f,
    )
}

// 900dp 一屏只到「使用说明」——`custom_url`（自定义登录地址）与 `links`（更多操作）两段在
// 预览里全被裁掉，改这两段时看不见效果。这一档把高度放到 1200dp 看整页：列表内容仍是同一条
// `QingyuPageList` 惰性列表，拉高只是多露出两段，不是另一套排版；状态取「已读取 + 已自定义地址」
// 这一最满的组合（同时看得到「保存 / 清除」两颗按钮与最后的分组）。900 档四个状态照旧保留。
@Suppress("unused")
@Preview(name = "8 整页 1200", showBackground = true, widthDp = 400, heightDp = 1200)
@Composable
private fun WarehouseAdapterDetailPagePreviewFullPage() {
    PreviewWarehouseAdapterDetailPage(
        scriptStatus = WarehouseScriptStatus.Loaded(length = 4820),
        customImportUrl = "https://jw.example.edu.cn/login",
    )
}
