package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 传输预览对话框模型层测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/transfer_preview_dialog.dart`）：
 * - 单行格式 `kind: +added / ~updated / -removed`（:18-22）；
 * - 正文四段，段间空行（`join('\n\n')`，:34-35）；
 * - 有另一条通道的预览时并列 `merge:` 与 `overwrite:` 两段（:27-31）；
 * - 按钮顺序与主按钮（:42-58）。
 *
 * 这套格式是**契约**：用户会拿手机上的数字跟对方手机对比，改一个空格都会被当成
 * 「两边不一致」，所以这里逐字符断言。
 */
class TransferPreviewModelTest {

    private val identity = TransferPreviewModel.PackageIdentity(
        channel = "qr",
        scope = "current",
        packageId = "pkg-20261027-001",
    )

    // ── 1. 单行格式 ──

    @Test
    fun `一行的拼法是种类加三个计数`() {
        val summary = TransferPreviewModel.Summary(
            kind = "course",
            added = 3,
            updated = 1,
            removed = 2,
        )
        assertEquals("course: +3 / ~1 / -2", summary.line)
    }

    @Test
    fun `多个实体按传入顺序各占一行`() {
        val text = TransferPreviewModel.formatSummary(
            listOf(
                TransferPreviewModel.Summary("course", 3, 1, 2),
                TransferPreviewModel.Summary("task", 0, 5, 0),
            ),
        )
        assertEquals("course: +3 / ~1 / -2\ntask: +0 / ~5 / -0", text)
    }

    @Test
    fun `计数为零也照样写出来不省略`() {
        // Dart 是无条件插值；省略会让人以为那条实体没参与比较
        val line = TransferPreviewModel.Summary("exam", 0, 0, 0).line
        assertEquals("exam: +0 / ~0 / -0", line)
    }

    // ── 2. 正文（单段汇总） ──

    @Test
    fun `正文第一段是说明第二段是技术标识第三段是汇总`() {
        val body = TransferPreviewModel.body(
            identity = identity,
            summaries = listOf(TransferPreviewModel.Summary("course", 1, 0, 0)),
        )
        val blocks = body.split("\n\n")
        assertEquals("应有 3 段", 3, blocks.size)
        assertEquals("你可以覆盖当前课表，或者把备份导入成一个新的独立课表", blocks[0])
        assertEquals("channel=qr\nscope=current\ntransferId=pkg-20261027-001", blocks[1])
        assertEquals("course: +1 / ~0 / -0", blocks[2])
    }

    // ── 3. 正文（并列两段汇总） ──

    @Test
    fun `有另一条通道预览时并列 merge 与 overwrite`() {
        val body = TransferPreviewModel.body(
            identity = identity,
            summaries = listOf(TransferPreviewModel.Summary("course", 9, 9, 9)),
            alternateSummaries = listOf(TransferPreviewModel.Summary("course", 1, 2, 3)),
        )
        val blocks = body.split("\n\n")
        assertEquals("应有 4 段", 4, blocks.size)
        assertEquals("merge:\ncourse: +1 / ~2 / -3", blocks[2])
        assertEquals("overwrite:\ncourse: +9 / ~9 / -9", blocks[3])
    }

    // ── 4. 按钮 ──

    @Test
    fun `三个按钮顺序是取消合并覆盖`() {
        val labels = TransferPreviewModel.actions().map { it.label }
        assertEquals(listOf("取消", "合并更改", "覆盖当前课表"), labels)
    }

    @Test
    fun `取消按钮没有应用方式`() {
        val cancel = TransferPreviewModel.actions().first()
        assertNull(cancel.mode)
    }

    @Test
    fun `主按钮必须是覆盖当前课表`() {
        // 主按钮是默认焦点：误触等于把用户课表整个换掉，不能是「合并」以外的东西
        val primary = TransferPreviewModel.primaryAction()
        assertEquals("覆盖当前课表", primary.label)
        assertEquals(TransferPreviewModel.ApplyMode.OVERWRITE, primary.mode)
        assertTrue(primary.primary)
    }

    @Test
    fun `只有一个主按钮`() {
        assertEquals(1, TransferPreviewModel.actions().count { it.primary })
    }

    @Test
    fun `应用方式的 Dart 名与枚举一致`() {
        assertEquals("merge", TransferPreviewModel.ApplyMode.MERGE.dartName)
        assertEquals("overwrite", TransferPreviewModel.ApplyMode.OVERWRITE.dartName)
    }

    // ── 5. 文案 ──

    @Test
    fun `标题与说明取自 ARB`() {
        assertEquals("选择导入方式", TransferPreviewModel.title)
        assertEquals(
            "你可以覆盖当前课表，或者把备份导入成一个新的独立课表",
            TransferPreviewModel.message,
        )
    }
}
