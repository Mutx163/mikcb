package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.SourceSlice
import org.junit.Test

/**
 * **地点匹配卡的动作区必须是两颗实心块钮**（2026-11-10 用户报「蓝字/红字裸文字钮不合适」）。
 *
 * ## 发布版基准
 *
 * `location_time_match_screen.dart` 的 `_buildGroupCard`：`Row` 里
 * `Expanded(HyperosButton(label: editAction, variant: secondary, expand: true))`
 * + 8dp + `HyperosButton(label: deleteAction, variant: secondary)`。
 * 也就是说：编辑占满宽度、删除按内容宽、**删除不染红**（红色只在点开后的
 * `showAppConfirmDialog(destructiveConfirm: true)` 确认框里）。
 */
class LocationTimeMatchActionStyleGuardTest {

    private val page by lazy { readKotlinSourceNoStrings(PATH) }

    @Test
    fun `动作区是两颗实心 secondary 块钮`() {
        assertTrue(
            "GroupCardView 里找不到 Button( 动作钮——发布版是两颗实心块钮，不是文字链",
            page.contains("colors = ButtonDefaults.buttonColors()"),
        )
        assertTrue(
            "编辑钮必须用 weight 占满剩余宽度（发布版 expand: true）",
            page.contains("modifier = Modifier.weight(1f)"),
        )
        assertTrue("动作钮之间必须 8dp 间距（发布版 SizedBox(width: 8)）", page.contains("spacedBy(8.dp)"))
    }

    @Test
    fun `动作文字不许再写成裸 Text + clickable`() {
        assertFalse(
            "又出现 `clickable(onClick = onEdit/onDelete)` 的裸文字——热区只有文字、按压只亮字",
            page.contains("clickable(onClick = onEdit)") ||
                page.contains("clickable(onClick = onDelete)"),
        )
    }

    @Test
    fun `删除钮不染红`() {
        // 红色只允许出现在确认框（LocationTimeMatchHost）里；卡片上的删除钮是 secondary。
        val cardBody = SourceSlice.functionBody(page, "private fun GroupCardView(")
        assertFalse(
            "卡片动作区出现 error 色了——发布版删除钮是 secondary，红只在确认框",
            cardBody.contains("QingyuTheme.error"),
        )
    }

    private companion object {
        const val PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeMatchPage.kt"
    }
}
