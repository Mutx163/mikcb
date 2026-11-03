package com.mutx163.qingyu.pages.conflict

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
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
 * - 页面骨架 / 滚动 / 卡片 / 分组标题走共享套件：`QingyuPageScaffold`（官方 TopAppBar +
 *   标准左箭头）、`QingyuPageList`（官方滚动三件套 + 右侧滚动条）、`QingyuCard`（按压反馈 +
 *   语义圆角）、`QingyuSectionTitle`（官方 SmallTitle，自带 28dp 左缘）；
 * - Text / Icon 用官方 `top.yukonga.miuix.kmp.basic.*`，不自绘；
 * - 行尾箭头用官方图标包 `miuix-icons-android:0.8.8` 的 `MiuixIcons.ChevronForward`
 *   （依赖由用户 2026-10-26 批准新增，仍只挂 composeP1）；
 * - 0.8.8 没有 preference 模块（那套在 0.9.4 且要 Kotlin 2.4），列表用 QingyuCard + Row，
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
        // 主滚动统一走共享套件：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
        // 与右侧滚动条；`innerPadding` 由套件自己吃掉，不再手写 Column + padding。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 24.dp),
        ) {
            if (view.isEmpty) {
                // Dart：Center(Text(courseConflictEmpty, style: listDetail))。
                item(key = "empty") {
                    Box(
                        modifier = Modifier.fillParentMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = view.emptyText,
                            style = MiuixTheme.textStyles.body2,
                            color = colors.onSurfaceVariantSummary,
                        )
                    }
                }
            } else {
                items(items = view.pairs, key = { it.index }) { pair ->
                    Column {
                        // 分组标题走官方 SmallTitle（自带 28dp 左缘），
                        // 与「Card 外边距 12 + 行内边距 16」的轴线对齐。
                        QingyuSectionTitle(pair.sectionLabel)
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin),
                            // 行内边距由行自己给（16/13），与 HyperosListGroup 一致。
                            insideMargin = PaddingValues(0.dp),
                        ) {
                            Column {
                                CourseConflictRowView(
                                    row = pair.rows[0],
                                    onOpenCourse = onOpenCourse,
                                )
                                if (pair.rows.size > 1) {
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
                style = MiuixTheme.textStyles.main,
                color = colors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = row.scheduleLine,
                style = MiuixTheme.textStyles.body2,
                color = colors.onSurfaceVariantSummary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
            Text(
                text = row.conflictLine,
                style = MiuixTheme.textStyles.body2,
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
