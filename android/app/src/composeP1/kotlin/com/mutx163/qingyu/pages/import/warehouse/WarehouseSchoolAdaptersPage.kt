package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 学校适配器列表页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_school_adapters_screen.dart`：
 * 1. 学校概览卡片（学校名、所属省份、分类）；
 * 2. 适配器卡片流（脚本名、分类/维护者元数据、描述说明）；
 * 3. 动作按钮：网页登录导入、宏录制导入、适配器详情、一键快捷导入。
 */
@Composable
fun WarehouseSchoolAdaptersPage(
    school: WarehouseSchoolEntry,
    adapters: List<WarehouseAdapterEntry> = emptyList(),
    macroMap: Map<String, Boolean> = emptyMap(),
    onBack: () -> Unit = {},
    onRefresh: () -> Unit = {},
    onImportAdapter: (WarehouseAdapterEntry) -> Unit = {},
    onRecordAdapter: (WarehouseAdapterEntry) -> Unit = {},
    onViewAdapterDetail: (WarehouseAdapterEntry) -> Unit = {},
    onQuickImportAdapter: (WarehouseAdapterEntry) -> Unit = {},
    /**
     * 这一屏当前处于什么相位（8b 接真数据源时新增）。
     *
     * 默认 [WarehouseListPhase.Idle]：还没接数据层的调用点传空列表，行为与改动前一致
     * （空列表 = 「暂时无法读取适配器列表」）。宿主接了真仓库后必须传 Loading / Failed，
     * 否则「还在请求」和「请求失败」都会显示成同一句空态，用户不知道该不该等。
     */
    phase: WarehouseListPhase = WarehouseListPhase.Idle,
    /**
     * 最近一次失败的**具体原因**（2026-11-05 新增槽位，宿主已填值）。
     *
     * 契约见 `WarehouseLoadIssue.kt`：`code` 只留日志/排查，页面出文案**只用 `issue`**
     * （四档：网不通 / 超时 / 仓库全挂 / 格式错），不许再按 `code` 解析一遍。
     *
     * 默认 `null`：还没接到数据层的调用点行为不变（仍按 [phase] 显示通用标题 + 重试）。
     * 注意 [failure] 与「有缓存」可以同时成立：刷新失败但列表还是上次的名单时，
     * 宿主会保留列表并把原因放这里，页面适合用轻提示而不是整块失败页。
     */
    failure: WarehouseLoadFailed? = null,
    onRetry: () -> Unit = onRefresh,
) {
    // 四档原因 → 一句人话（main 层 `warehouseLoadIssueText`，可被 L0 单测钉住）。
    // `showingCachedList = adapters.isNotEmpty()`：名单还在时只说「下面显示的是上次加载的列表」，
    // 不把「已尝试 N 条线路」这类细节压给手上有名单的用户；内容格式错仍走各自那句（见函数 KDoc）。
    val failureText = failure?.let {
        warehouseLoadIssueText(it, showingCachedList = adapters.isNotEmpty())
    }

    // Dart warehouse_school_adapters_screen.dart 的 HyperosSubpage 标题是学校名 Text ⇒ 可折叠大标题。
    // 骨架 / 顶栏 / 返回键走共享套件（R1），页面级滚动走 QingyuPageList（R2）。
    QingyuPageScaffold(
        title = school.name,
        onBack = onBack,
        actions = {
            IconButton(onClick = onRefresh) {
                Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.text)
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            // 学校概览卡（旧版 Dart 没有这张卡）：页面大标题就是学校名，再画一张
            // 「头像 + 校名」卡是显式冗余（用户 2026-11-03 实报），身份由标题承担。

            // 刷新失败但**列表还在**（缓存保留，phase 已是 Idle）：顶部一条轻提示说清原因，
            // 别把整页换成失败页——用户手上的名单仍然是可用的。
            if (adapters.isNotEmpty() && failureText != null) {
                item(key = "load_issue") {
                    Text(
                        text = failureText,
                        style = MiuixTheme.textStyles.footnote1,
                        color = MiuixTheme.colorScheme.error,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 12.dp),
                    )
                }
            }

            // 适配器列表
            if (adapters.isEmpty()) {
                item(key = "empty_adapters") {
                    if (phase == WarehouseListPhase.Loading) {
                        // 请求还在路上：D1 档 A2 居中转圈（块内最小高度 120），不写「读不到」
                        // ——那会把「等一下」说成「坏了」。
                        QingyuLoadingCenter(fillPage = false)
                    } else {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 48.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                text = WarehouseStrings.warehouseAdaptersLoadFailedTitle.text,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )
                            // 真失败时把四档原因补一句：只留通用标题用户不知道该查什么。
                            // 无缓存 ⇒ `showingCachedList` 为 false，走的是「已尝试 N 条线路」/网不通/
                            // 超时/格式错那句（`attempts == 0` 的病句情形仍返回 null）。
                            if (phase == WarehouseListPhase.Failed && failureText != null) {
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = failureText,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.error,
                                    modifier = Modifier.padding(horizontal = 24.dp),
                                )
                            }
                            if (phase == WarehouseListPhase.Failed) {
                                // 真失败才给重试；Idle 是「调用方没接数据层」，给重试按钮没有意义。
                                // 配色对齐旧版（warehouse_school_adapters_screen.dart:119-123
                                // 的 HyperosButton secondary）；此前 primary 12% 浅蓝底在
                                // 页底 #F2F2F2 上对比比 ~1.05，几乎看不见是个按钮。
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(
                                    onClick = onRetry,
                                    content = { Text(text = WarehouseStrings.reloadAction.text) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.secondary,
                                        contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
                                    ),
                                )
                            }
                        }
                    }
                }
            } else {
                items(adapters, key = { it.id }) { adapter ->
                    val hasMacro = macroMap[adapter.id] ?: false
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 12.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = adapter.adapterName,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            // 元信息是标签行：footnote2（比说明小一档）弱化，说明才用 body2。
                            // 旧版同样直接显示原始分类串（warehouse_shared.dart:174），不动内容。
                            Text(
                                text = "${WarehouseStrings.categoryLabel.text}：${adapter.category} · ${WarehouseStrings.maintainerLabel.text}：${adapter.maintainer.ifEmpty { "社区" }}",
                                style = MiuixTheme.textStyles.footnote2,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )

                            if (adapter.description.isNotBlank()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                // 说明是正文字号（body2）+ 放开的行距（22sp ≈ 1.57 倍），
                                // 限 3 行：全文由「查看详情」承接（列表保持可扫读）。
                                Text(
                                    text = adapter.description,
                                    style = MiuixTheme.textStyles.body2,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                    lineHeight = 22.sp,
                                    maxLines = 3,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            // 动作按钮组：统一 2×2 等宽网格（列宽全部 weight(1f) 等分、
                            // 行内同构件等高，触摸高 ≈48dp 来自官方组件默认）。
                            // 旧版是「primary / secondary / 右对齐散排」三种摆法混用，且
                            // Compose 版此前四颗用了四种配色（surfaceVariant 白底在白卡上
                            // 对比比 1.0 完全隐形，只剩蓝字飘着）；现在只留一颗主操作
                            // 「网页登录导入」（primary 实心），其余三颗同为次级灰
                            // （secondary #E6E6E6 底 + onSecondaryVariant 墨，白卡上对比 1.25）。
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Button(
                                    onClick = { onImportAdapter(adapter) },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColorsPrimary(),
                                    content = { Text(text = WarehouseStrings.webLoginImport.text) },
                                )
                                Button(
                                    onClick = { onRecordAdapter(adapter) },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.secondary,
                                        contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
                                    ),
                                    content = { Text(text = WarehouseStrings.recordImportAction.text) },
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // 查看详情固定在右列（对齐旧版 centerRight 的位置记忆）；
                            // 没有宏时左列留空位撑住网格，不让「查看详情」变形。
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                if (hasMacro) {
                                    Button(
                                        onClick = { onQuickImportAdapter(adapter) },
                                        modifier = Modifier.weight(1f),
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.secondary,
                                            contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
                                        ),
                                        content = { Text(text = WarehouseStrings.quickImportAction.text) },
                                    )
                                } else {
                                    Spacer(modifier = Modifier.weight(1f))
                                }

                                Button(
                                    onClick = { onViewAdapterDetail(adapter) },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.secondary,
                                        contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
                                    ),
                                    content = { Text(text = WarehouseStrings.viewDetailsAction.text) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄）：主题包 `QingyuPageTheme(isDark = …)`，
// 字号用 `textScale = …`（不用 `@Preview(fontScale = …)`），宽度 400dp 是本仓折行实测口径。
//
// 本页分支最多，五档都是宿主真实会传的形态：
//   有适配器（含宏→多一颗「一键导入」）/ 空·加载中 / 空·失败（带四档原因 + 重试）/ 有名单·刷新失败（轻提示）；
// 空与失败长得一模一样又必须说不同话，所以各占一档。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用：一所示例学校。 */
private val previewAdaptersSchool = WarehouseSchoolEntry(
    id = "example-university",
    name = "示例大学",
    initial = "S",
    category = "本科教务",
    code = "10001",
    province = "示例省",
)

/** 预览用：两个适配器，一个带宏（多渲染一颗「一键导入」）、一个没有维护者（走「社区」兜底）。 */
private fun previewAdapters(): List<WarehouseAdapterEntry> = listOf(
    WarehouseAdapterEntry(
        id = "example-university-undergrad",
        name = "本科教务系统",
        script = "// 预览用占位脚本，不执行",
        description = "登录教务处后依次点开「学生服务 → 我的课表」，脚本会把当学期课表拓成结构化数据。",
        category = "本科教务",
        maintainer = "张三",
        importUrl = "https://jw.example.edu.cn/login",
        schoolCode = "10001",
    ),
    WarehouseAdapterEntry(
        id = "example-university-graduate",
        name = "研究生教务",
        script = "// 预览用占位脚本，不执行",
        description = "",
        category = "研究生教务",
        maintainer = "",
        importUrl = "https://yjs.example.edu.cn/",
    ),
)

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewWarehouseSchoolAdaptersPage(
    adapters: List<WarehouseAdapterEntry>,
    phase: WarehouseListPhase = WarehouseListPhase.Idle,
    failure: WarehouseLoadFailed? = null,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        WarehouseSchoolAdaptersPage(
            school = previewAdaptersSchool,
            adapters = adapters,
            macroMap = mapOf("example-university-undergrad" to true),
            onBack = {},
            onRefresh = {},
            onImportAdapter = { _ -> },
            onRecordAdapter = { _ -> },
            onViewAdapterDetail = { _ -> },
            onQuickImportAdapter = { _ -> },
            phase = phase,
            failure = failure,
        )
    }
}

@Suppress("unused")
@Preview(name = "1 有适配器", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseSchoolAdaptersPagePreviewList() {
    PreviewWarehouseSchoolAdaptersPage(previewAdapters())
}

@Suppress("unused")
@Preview(name = "2 空·加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseSchoolAdaptersPagePreviewLoading() {
    PreviewWarehouseSchoolAdaptersPage(emptyList(), phase = WarehouseListPhase.Loading)
}

@Suppress("unused")
@Preview(name = "3 空·失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseSchoolAdaptersPagePreviewFailed() {
    PreviewWarehouseSchoolAdaptersPage(
        adapters = emptyList(),
        phase = WarehouseListPhase.Failed,
        failure = WarehouseLoadFailed(
            code = "warehouse_fetch_failed",
            attempts = 3,
            issue = WarehouseLoadIssue.TIMEOUT,
        ),
    )
}

@Suppress("unused")
@Preview(name = "4 有名单·刷新失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseSchoolAdaptersPagePreviewCachedWithFailure() {
    PreviewWarehouseSchoolAdaptersPage(
        adapters = previewAdapters(),
        phase = WarehouseListPhase.Idle,
        // 棱镜失败的 issue 值经 main 层工厂按既有映射推出（`warehouseLoadIssueOf`），
        // 页面这里不能自己点枚举值——守卫 WarehouseLoadIssueRenderingGuardTest 会拦。
        failure = WarehouseLoad.Failed(
            code = "warehouse_fetch_failed",
            attempts = 3,
        ).toLoadFailed(),
    )
}

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseSchoolAdaptersPagePreviewDark() {
    PreviewWarehouseSchoolAdaptersPage(previewAdapters(), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseSchoolAdaptersPagePreviewLargeText() {
    PreviewWarehouseSchoolAdaptersPage(previewAdapters(), textScale = 1.3f)
}
