package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.testutil.readSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云同步两页的「顶栏渐变模糊」接线守卫（2026-11-10 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户真机实报：云同步页顶部**不是**渐变模糊顶栏，和其他页不一样。
 *
 * 根因不是没走骨架，而是 **innerPadding 吃错了层**：
 * - `QingyuPageScaffold` 的模糊带采样「画到顶栏底下」的内容（`QingyuPageScaffold.kt:559-588`）；
 * - `QingyuPageList` 把 `innerPadding` 当 **contentPadding** 用（`QingyuPageList.kt:89`），
 *   列表项因此能滚进顶栏带 ⇒ 模糊采到真实像素；
 * - 这两页原来把 `innerPadding` 加在外层 `Column` 上、列表传 `PaddingValues(0.dp)`，
 *   列表视口整体落在栏下方 ⇒ 顶栏带采到一片纯背景，看起来就是「没有渐变模糊」。
 *
 * 发布版同页走 `HyperosSubpage`（`cloud_sync_screen.dart:938/950`）→ `_HyperosBlurredPage`
 * （`hyperos_page.dart:80-95`、`hyperos_blurred_header.dart` 的 backdrop blur），确实有模糊头，
 * 所以这是迁移布局偏差、不是设计差异。
 *
 * ## 判据
 *
 * 1. 两页必须走 `QingyuPageScaffold`；
 * 2. 两页的 `QingyuPageList` 必须收到 `innerPadding = innerPadding`（骨架给的那份）；
 * 3. 两页正文里**不许**再出现 `.padding(innerPadding)`（吃错层的老写法）；
 * 4. 备份列表的撤销恢复卡必须是列表首项（`item(key = "undo_restore")`），
 *    不再当列表外常驻条挡住顶栏采样。
 *
 * ## 咬合探针（2026-11-10 已做）
 *
 * 把 `CloudSyncPage.kt` 的 `innerPadding = innerPadding` 改回 `PaddingValues(0.dp)` ⇒ 判据 2 红；
 * 还原 ⇒ 绿。
 */
class SyncTopBarBlurWiringGuardTest {

    private val syncPage = readSourceNormalized(SYNC_PAGE)
    private val backupPage = readSourceNormalized(BACKUP_PAGE)

    @Test
    fun `两页都必须走共享页面骨架`() {
        assertTrue("CloudSyncPage 没走 QingyuPageScaffold（顶栏玻璃带就不会有）", syncPage.contains("QingyuPageScaffold("))
        assertTrue("CloudBackupListPage 没走 QingyuPageScaffold", backupPage.contains("QingyuPageScaffold("))
        // 空跑哨兵：读到的文件不能是空串 / 残缺。
        assertTrue("CloudSyncPage 读出来太短", syncPage.length > 5_000)
        assertTrue("CloudBackupListPage 读出来太短", backupPage.length > 5_000)
    }

    @Test
    fun `innerPadding 必须交给列表 不许吃在外层容器`() {
        for ((name, text) in listOf("CloudSyncPage.kt" to syncPage, "CloudBackupListPage.kt" to backupPage)) {
            assertTrue(
                "$name 的 QingyuPageList 没有收到 `innerPadding = innerPadding`：" +
                    "内容滚不进顶栏带，模糊只会采到纯背景（用户实报「顶部不是渐变模糊」）。",
                LIST_WITH_INNER.containsMatchIn(text),
            )
            assertFalse(
                "$name 又把 `innerPadding` 吃在外层容器上（`.padding(innerPadding)`）：" +
                    "列表视口会整体落在顶栏下方，顶栏带采不到内容。",
                INNER_PADDING_ON_CONTAINER.containsMatchIn(stripComments(text)),
            )
        }
    }

    @Test
    fun `备份列表的撤销恢复卡必须是列表首项`() {
        assertTrue(
            "CloudBackupListPage 的撤销恢复卡没做成列表首项（item(key = \"undo_restore\")）：" +
                "列表外的常驻条会挡住顶栏采样，发布版它本来就在列表流里。",
            backupPage.contains("item(key = \"undo_restore\")"),
        )
    }

    // ── 辅助 ──

    /** 剥掉 `//` 行注释与 `/* */` 块注释（字符串里的 `//` 不动，本判据不涉 URL）。 */
    private fun stripComments(text: String): String =
        Regex("(?s)/\\*.*?\\*/").replace(text, "")
            .let { withoutBlock -> Regex("(?m)//.*$").replace(withoutBlock, "") }

    private companion object {
        const val SYNC_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncPage.kt"
        const val BACKUP_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt"

        /** 列表拿骨架给的 innerPadding（允许换行与空白）。 */
        val LIST_WITH_INNER = Regex("""QingyuPageList\([\s\S]{0,200}?innerPadding\s*=\s*innerPadding""")

        /** 老写法：把 innerPadding 吃到外层容器上。 */
        val INNER_PADDING_ON_CONTAINER = Regex("""\.padding\(\s*innerPadding\s*\)""")
    }
}
