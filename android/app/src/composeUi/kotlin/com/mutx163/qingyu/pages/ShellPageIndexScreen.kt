package com.mutx163.qingyu.pages

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.pages.shell.ShellPageCatalog
import com.mutx163.qingyu.pages.shell.ShellPageDataKind
import com.mutx163.qingyu.pages.shell.ShellPageEntry
import com.mutx163.qingyu.pages.shell.isOpenable
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 页面索引 —— Phase 3 开发壳的「目录页」。
 *
 * ## 它是干什么的
 *
 * L4（真机逐页对照）要求一页一页在手机上打开看。以前壳里只有课表/日程/任务三个槽位，
 * 其余 75 页**物理上进不去**（核对记录见 `docs/plans/2026-10-27-compose-phase3-l4-checklist.md`）。
 * 这一页把清单做成可点的列表：点一行进那一页，返回键回到这里。
 *
 * ## 为什么按批次分组、而不是按拼音
 *
 * 对照时要**照着 L4 清单一行行走**：清单是按批次写的，界面按同一顺序排，才不会漏页、
 * 也不会来回翻。
 *
 * ## 三档标记（判据在 [ShellPageCatalog] 里，这里只负责显示）
 *
 * - 无标记：页面自带默认值，进去就能看；
 * - `演示数据`：页面需要一份视图状态，壳里喂的是空列表/示例条目——**别当真实数据**；
 * - `暂不可用`：进不去，行下方直接写缺什么（缺渲染层 / 缺相机 / 缺二维码编码器）。
 */
@Composable
fun ShellPageIndexScreen(
    onOpenPage: (String) -> Unit,
    onBack: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val textColor = Color(QingyuTheme.primaryText(dark))
    val subTextColor = Color(QingyuTheme.secondaryText(dark))
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))

    val openableCount = ShellPageCatalog.openable.size
    val unavailableCount = ShellPageCatalog.countOf(ShellPageDataKind.UNAVAILABLE)

    Scaffold(containerColor = scaffoldBg) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = "页面索引",
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                },
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                // 底部多留一截：最后一行不能被系统手势条压住
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = innerPadding.calculateTopPadding() + 4.dp,
                    bottom = innerPadding.calculateBottomPadding() + 32.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item(key = "intro") {
                    InfoCard(
                        text = "共 ${ShellPageCatalog.totalCount} 条：可进入 $openableCount 条、" +
                            "暂不可用 $unavailableCount 条。点一行进入该页，返回键回到这里。",
                        subTextColor = subTextColor,
                    )
                }

                ShellPageCatalog.batches.forEach { batch ->
                    item(key = "batch-${batch.code}") {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "${batch.code} · ${batch.title}",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = subTextColor,
                            modifier = Modifier.padding(start = 4.dp, bottom = 2.dp),
                        )
                    }
                    items(batch.pages, key = { it.id }) { entry ->
                        PageRow(
                            entry = entry,
                            onClick = { onOpenPage(entry.id) },
                            textColor = textColor,
                            subTextColor = subTextColor,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoCard(text: String, subTextColor: Color) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = subTextColor,
        )
    }
}

@Composable
private fun PageRow(
    entry: ShellPageEntry,
    onClick: () -> Unit,
    textColor: Color,
    subTextColor: Color,
) {
    val openable = entry.isOpenable
    val badge = ShellPageCatalog.badgeOf(entry.kind)
    val badgeColor = when (entry.kind) {
        ShellPageDataKind.DEMO -> subTextColor
        ShellPageDataKind.UNAVAILABLE -> DISABLED_TEXT
        ShellPageDataKind.ALWAYS_VISIBLE -> subTextColor
        ShellPageDataKind.DIRECT -> subTextColor
    }

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = if (openable) onClick else null,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = entry.title,
                    style = MiuixTheme.textStyles.body1,
                    fontWeight = FontWeight.Medium,
                    color = if (openable) textColor else DISABLED_TEXT,
                )
                if (!entry.note.isNullOrBlank()) {
                    Text(
                        text = entry.note,
                        style = MiuixTheme.textStyles.footnote1,
                        color = if (openable) subTextColor else DISABLED_TEXT,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            if (badge != null) {
                Spacer(modifier = Modifier.size(8.dp))
                Text(
                    text = badge,
                    style = MiuixTheme.textStyles.footnote2,
                    color = badgeColor,
                )
            } else {
                Icon(
                    imageVector = MiuixIcons.ListView,
                    contentDescription = null,
                    tint = subTextColor,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}

/** 不可点击行的文字色：中性灰，明暗都读得清。 */
private val DISABLED_TEXT = Color(0xFF9AA0A6)
