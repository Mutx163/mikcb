package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 选图落盘判据（F01 审核后补的纯函数层）。
 *
 * 起因：宿主第一版把「读完为 null」一律当**读取失败**，而
 * `ExternalImportReader.readCapped` 的唯一 null 出口是**超限** ⇒ 用户选一张超大图
 * 会看到「图片读取失败，请换一张再试」，与真实原因（太大）无关，只会让人反复重试。
 * 这条用例就是钉这个分支的。
 */
class LiveImagePickLogicTest {

    // ── classify：三态判定 ──────────────────────────────────────

    @Test
    fun `声明长度超限就不必读内容，直接超限`() {
        // 21 MB > 20 MB：连读都不该开始。
        assertEquals(
            LiveImagePickLogic.Outcome.TOO_LARGE,
            LiveImagePickLogic.classify(declaredLength = 21L * 1024 * 1024, bytes = null),
        )
    }

    @Test
    fun `长度说不清时靠限长读兜底，读成 null 就是超限而不是读失败`() {
        // 关键分支：readCapped 只在「读的过程中超过上限」时返回 null。
        assertEquals(
            LiveImagePickLogic.Outcome.TOO_LARGE,
            LiveImagePickLogic.classify(declaredLength = -1L, bytes = null),
        )
    }

    @Test
    fun `空文件是读取失败而不是超限`() {
        assertEquals(
            LiveImagePickLogic.Outcome.FAILED,
            LiveImagePickLogic.classify(declaredLength = 0L, bytes = ByteArray(0)),
        )
    }

    @Test
    fun `读到内容就能落盘`() {
        assertEquals(
            LiveImagePickLogic.Outcome.OK,
            LiveImagePickLogic.classify(declaredLength = 12L, bytes = ByteArray(12) { 1 }),
        )
    }

    @Test
    fun `恰好等于上限算通过（与 Dart 同口径，不是大于等于）`() {
        val limit = LiveImagePickLogic.MAX_BYTES
        assertEquals(
            LiveImagePickLogic.Outcome.OK,
            LiveImagePickLogic.classify(declaredLength = limit, bytes = ByteArray(4)),
        )
        assertEquals(
            LiveImagePickLogic.Outcome.TOO_LARGE,
            LiveImagePickLogic.classify(declaredLength = limit + 1, bytes = null),
        )
    }

    // ── 扩展名与文件名 ──────────────────────────────────────────

    @Test
    fun `常见图片 MIME 的扩展名`() {
        assertEquals("png", LiveImagePickLogic.extensionFor("image/png"))
        assertEquals("jpg", LiveImagePickLogic.extensionFor("image/jpeg"))
        assertEquals("jpg", LiveImagePickLogic.extensionFor("image/jpg"))
        assertEquals("webp", LiveImagePickLogic.extensionFor("image/webp"))
        assertEquals("gif", LiveImagePickLogic.extensionFor("image/gif"))
        assertEquals("bmp", LiveImagePickLogic.extensionFor("image/bmp"))
    }

    @Test
    fun `认不出或没有 MIME 一律 png 兜底`() {
        assertEquals("png", LiveImagePickLogic.extensionFor(null))
        assertEquals("png", LiveImagePickLogic.extensionFor("image/heic"))
        assertEquals("png", LiveImagePickLogic.extensionFor("text/plain"))
    }

    @Test
    fun `MIME 大小写不敏感`() {
        assertEquals("jpg", LiveImagePickLogic.extensionFor("IMAGE/JPEG"))
    }

    @Test
    fun `文件名是固定前缀加扩展名（换图靠它清旧图）`() {
        assertEquals(
            "before_class_label_logo.png",
            LiveImagePickLogic.fileNameFor("before_class_label_logo", "image/png"),
        )
        assertEquals(
            "during_end_expanded_icon.jpg",
            LiveImagePickLogic.fileNameFor("during_end_expanded_icon", "image/jpeg"),
        )
        // 同一个前缀两次调用必须同名（否则「换一张图」会变成「多一张图」）。
        assertEquals(
            LiveImagePickLogic.fileNameFor("p", "image/png"),
            LiveImagePickLogic.fileNameFor("p", "image/png"),
        )
    }

    // ── 旧图清理 ────────────────────────────────────────────────

    @Test
    fun `同前缀旧图要删，别的前缀与新品自己都不能误删`() {
        val prefix = "before_class_label_logo"
        val keep = "before_class_label_logo.png"

        // 换扩展名后留下的旧图 → 删
        assertTrue(LiveImagePickLogic.shouldDelete("before_class_label_logo.jpg", prefix, keep))
        // 即将写入的这一份 → 留
        assertFalse(LiveImagePickLogic.shouldDelete(keep, prefix, keep))
        // 另一个入口的图（课中/下课档）→ 不动
        assertFalse(
            LiveImagePickLogic.shouldDelete("during_end_label_logo.png", prefix, keep),
        )
        // 仅前缀相同但不是一个族（没有点分隔）→ 不动，避免误删别人的图标
        assertFalse(LiveImagePickLogic.shouldDelete("before_class_label_logo_backup", prefix, keep))
    }
}
