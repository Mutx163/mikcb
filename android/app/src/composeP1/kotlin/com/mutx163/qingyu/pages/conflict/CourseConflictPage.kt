package com.mutx163.qingyu.pages.conflict

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageScaffold
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 冲突详情页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/course_conflict_screen.dart`：分组小标题（冲突组合 N）
 * + 每对两行课程（课名 / 周几第几节·周次 / 与谁冲突红字）+ 空态一行提示。
 *
 * ## 分层
 *
 * 本文件在 **composeP1** 源集（只有该变体 classpath 有官方 Miuix）；结构、配对、
 * 排序与文案在 main 源集的 `CourseConflictModel.kt`（零 Compose 依赖，可跑常规 JVM 单测）。
 *
 * ## 组件选择（对照 S2-5 组件表）
 *
 * - Scaffold / Card / Text / Icon / IconButton / HorizontalDivider 全部官方
 *   `top.yukonga.miuix.kmp.basic.*`，不自绘；
 * - 返回与行尾箭头用官方图标包 `miuix-icons-android:0.8.8` 的
 *   `MiuixIcons.Back` / `MiuixIcons.ChevronForward`（依赖由用户 2026-10-26 批准新增，
 *   仍只挂 composeP1）；
 * - 0.8.8 没有 preference 模块（那套在 0.9.4 且要 Kotlin 2.4），列表用 Card + Row，
 *   与已合入的开源许可页同口径。
 *
 * ## 尚未接线（诚实标注）
 *
 * - `onOpenCourse` 只回调课程 id；Dart 侧「找到课程所在分组再打开编辑页」属于仓库/导航层，
 *   本批不接（页面也还没有 App 入口）。
 * - 真机同屏截图对照待接壳后进行；本批只做本地测试 + 编译验证。
 */
@Composable
fun CourseConflictPage(
    view: CourseConflictView,
    onBack: () -> Unit,
    onOpenCourse: (courseId: String) -> Unit = {},
) {
    val colors = MiuixTheme.colorScheme

    QingyuPageScaffold(title = view.title, onBack = onBack, smallTopBar = true) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 顶栏改由共享骨架提供（官方 TopAppBar + 标准左箭头），
                // 内容只吃顶栏高度 + 底部手势条。
                .padding(innerPadding),
        ) {

            if (view.isEmpty) {
                // Dart：Center(Text(courseConflictEmpty, style: listDetail))。
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = view.emptyText,
                        fontSize = 14.sp,
                        color = colors.onSurfaceVariantSummary,
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 24.dp),
                ) {
                    items(items = view.pairs, key = { it.index }) { pair ->
                        Column {
                            // HyperosSectionLabel：13sp、actionIcon 色、左缩进 16、与列表间距 8。
                            Text(
                                text = pair.sectionLabel,
                                fontSize = 13.sp,
                                color = colors.onSurfaceVariantActions,
                                modifier = Modifier.padding(
                                    start = 16.dp,
                                    top = 12.dp,
                                    bottom = 8.dp,
                                ),
                            )
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp),
                                // 行内边距由行自己给（16/13），与 HyperosListGroup 一致。
                                insideMargin = PaddingValues(0.dp),
                            ) {
                                Column {
                                    CourseConflictRowView(
                                        row = pair.rows[0],
                                        onOpenCourse = onOpenCourse,
                                    )
                                    if (pair.rows.size > 1) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(start = 16.dp),
                                            thickness = 0.75.dp,
                                            color = colors.dividerLine,
                                        )
                                        CourseConflictRowView(
                                            row = pair.rows[1],
                                            onOpenCourse = onOpenCourse,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 一行冲突课程：课名 / 周几第几节·周次 / 与谁冲突（红字）+ 右箭头。
 *
 * 三行都单行省略（Dart `maxLines: 1` + `TextOverflow.ellipsis`）。
 */
@Composable
private fun CourseConflictRowView(
    row: CourseConflictRow,
    onOpenCourse: (String) -> Unit,
) {
    val colors = MiuixTheme.colorScheme

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpenCourse(row.courseId) }
            .padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.title,
                fontSize = 17.sp,
                color = colors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = row.scheduleLine,
                fontSize = 14.sp,
                color = colors.onSurfaceVariantSummary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
            Text(
                text = row.conflictLine,
                fontSize = 14.sp,
                color = colors.error,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        androidx.compose.foundation.layout.Spacer(modifier = Modifier.size(12.dp))
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = colors.onSurfaceVariantActions,
            modifier = Modifier.size(18.dp),
        )
    }
}
