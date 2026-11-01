package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.Colors
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 发布说明正文的 Markdown 渲染（对应 Dart `ReleaseNotesMarkdown`，`release_notes_markdown.dart`）。
 *
 * 只用于「更新说明」在**解析不出结构化条目时的兜底分支**：把 [buildReleaseNotesMarkdownBlocks]
 * 产出的块画成标题 / 段落 / 列表 / 分隔线，行内粗体、斜体、行内代码、链接按样式区分。
 *
 * 与 Dart 的差异（诚实）：链接只做下划线+主题色**样式**，不做点击跳转（页面已有「查看 Release」
 * 主入口；发布说明里的链接点击属低频，避免为此引入 Text 的 LinkAnnotation 兼容问题）。
 */
@Composable
fun ReleaseNotesMarkdownView(blocks: List<MdBlock>) {
    val colors = MiuixTheme.colorScheme
    val base = MiuixTheme.textStyles.footnote1

    Column(modifier = Modifier.fillMaxWidth()) {
        var first = true
        for (block in blocks) {
            if (!first) Spacer(Modifier.height(6.dp))
            first = false
            when (block.kind) {
                MdBlockKind.RULE -> HorizontalDivider(Modifier.padding(vertical = 4.dp))

                MdBlockKind.HEADING1, MdBlockKind.HEADING2, MdBlockKind.HEADING3 ->
                    BasicText(
                        text = annotated(block.spans, base, colors),
                        style = base.shiftWeight(QingyuWeightDelta.SEMIBOLD).copy(color = colors.onSurface),
                    )

                MdBlockKind.HEADING4 ->
                    BasicText(
                        text = annotated(block.spans, base, colors),
                        style = base.copy(color = colors.onSurface),
                    )

                MdBlockKind.BULLET -> BulletLine(prefix = "·", spans = block.spans, base = base, colors = colors)

                MdBlockKind.NUMBERED -> BulletLine(
                    prefix = "${block.marker ?: "•"}.",
                    spans = block.spans,
                    base = base,
                    colors = colors,
                )

                MdBlockKind.PARAGRAPH ->
                    BasicText(
                        text = annotated(block.spans, base, colors),
                        style = base.copy(color = colors.onSurface),
                    )
            }
        }
    }
}

@Composable
private fun BulletLine(
    prefix: String,
    spans: List<MdSpan>,
    base: androidx.compose.ui.text.TextStyle,
    colors: Colors,
) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(text = prefix, style = base, color = colors.onSurfaceVariantSummary)
        Spacer(Modifier.width(6.dp))
        BasicText(
            text = annotated(spans, base, colors),
            modifier = Modifier.fillMaxWidth(),
            style = base.copy(color = colors.onSurface),
        )
    }
}

private fun annotated(
    spans: List<MdSpan>,
    base: androidx.compose.ui.text.TextStyle,
    colors: Colors,
): AnnotatedString = buildAnnotatedString {
    for (span in spans) {
        val style = SpanStyle(
            fontStyle = if (span.italic) FontStyle.Italic else null,
            fontFamily = if (span.code) FontFamily.Monospace else null,
            color = if (span.linkUrl != null) colors.primary else Color.Unspecified,
            textDecoration = if (span.linkUrl != null) TextDecoration.Underline else null,
        )
        val boldStyle = if (span.bold) style.shiftWeight(QingyuWeightDelta.SEMIBOLD) else style
        withStyle(boldStyle) { append(span.text) }
    }
}
