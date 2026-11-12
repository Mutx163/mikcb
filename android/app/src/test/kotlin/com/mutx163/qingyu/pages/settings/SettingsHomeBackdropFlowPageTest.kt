package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页壁纸流程（`lib/screens/settings/settings_home_backdrop_flow.dart`）与
 * 「最近使用」缩略图条（`settings_recent_wallpaper.dart`）的结构测试。
 *
 * 这两份 Dart 源不产生「一整页 spec」：
 * - `settings_home_backdrop_flow.dart` 是 **mixin**（:57 `HomeBackdropFlow`），提供
 *   若干块被两个宿主（课表页面设置 / 外观编辑的壁纸弹窗）复用的 UI 片段；
 * - `settings_recent_wallpaper.dart` 是其中的「最近使用」整段。
 *
 * 所以本批把它们落成若干**可组装的块**（[SettingsBackdropFlowPage] 的各个 builder），
 * 由宿主决定嵌在哪一页里——与 Flutter 侧「同一套 builder、两个宿主」同构。
 *
 * 期望值来源：Dart 源 + ARB。
 */
class SettingsHomeBackdropFlowPageTest {

    private fun selectionPage(backdrop: BackdropFlowState = BackdropFlowState()) =
        SettingsBackdropFlowPage.selectionPage(backdrop)

    private fun settingsPage(backdrop: BackdropFlowState = BackdropFlowState()) =
        SettingsBackdropFlowPage.settingsPage(backdrop)

    // ------------------------------------------------------------ 宿主差异

    @Test
    fun `两个宿主的左右内缩与行底色不同`() {
        // :79-103：课表页面那侧在 HyperosListGroup 卡片里（16 + 有行底），
        // 外观编辑的壁纸弹窗那侧无容器（0 + 关掉行底色）
        assertEquals(16.0, SettingsBackdropFlowPage.HOST_SETTINGS_ROW_INSET, 0.0)
        assertEquals(0.0, SettingsBackdropFlowPage.HOST_SHEET_ROW_INSET, 0.0)
        assertTrue(SettingsBackdropFlowPage.HOST_SETTINGS_ROWS_HAVE_CARD_BACKGROUND)
        assertFalse(SettingsBackdropFlowPage.HOST_SHEET_ROWS_HAVE_CARD_BACKGROUND)
    }

    // ------------------------------------------------------ 第一页「壁纸」

    @Test
    fun `选图块的标题、未选文案与「选择图片」按钮`() {
        // :857-940。没选图时只有标题 + 「未选择」+ 选择图片这一颗；
        // 「调整位置」「清除图片」只在已有壁纸时出现（:910 `if (hasWallpaper)`）
        val spec = selectionPage()
        val row = spec.row("backdrop.image")
        assertEquals("背景图片", row.title)
        // 没选图时显示「未选择」（:866-867）
        assertEquals("未选择", row.subtitle)
        assertEquals("homePageImageNotSelected", row.subtitleKey)
        assertEquals("选择图片", spec.row("backdrop.image.pick").title)
        assertFalse(spec.flattenedIds().contains("backdrop.image.adjust"))
        assertFalse(spec.flattenedIds().contains("backdrop.image.clear"))
    }

    @Test
    fun `已有壁纸时才有调整位置与清除图片两颗`() {
        // :910-935
        val spec = selectionPage(BackdropFlowState(imagePath = "/w/qingyu_1.jpg"))
        assertEquals("调整位置", spec.row("backdrop.image.adjust").title)
        assertEquals("清除图片", spec.row("backdrop.image.clear").title)
        // 清除写设置，调整位置推页
        assertEquals(SettingsAction.WRITE_SETTING, spec.row("backdrop.image.clear").action)
        assertEquals(SettingsAction.NAVIGATE, spec.row("backdrop.image.adjust").action)
    }

    @Test
    fun `已有壁纸时显示文件名并给出调整位置与清除`() {
        // :866-871：两种分隔符都切，不按当前系统的 pathSeparator
        val windowsPath = BackdropFlowState(imagePath = "C:\\Users\\x\\wallpapers\\qingyu_1.jpg")
        assertEquals("qingyu_1.jpg", selectionPage(windowsPath).row("backdrop.image").subtitle)
        val posixPath = BackdropFlowState(imagePath = "/storage/emulated/0/wallpapers/qingyu_2.jpg")
        assertEquals("qingyu_2.jpg", selectionPage(posixPath).row("backdrop.image").subtitle)
        // 只有文件名，不带目录
        assertFalse(selectionPage(posixPath).row("backdrop.image").subtitle!!.contains("/"))
    }

    @Test
    fun `没有壁纸时不出现调整位置与清除两行`() {
        // :910 `if (hasWallpaper)`
        val ids = selectionPage(BackdropFlowState(imagePath = null)).flattenedIds()
        assertTrue(ids.contains("backdrop.image.pick"))
        assertFalse(ids.contains("backdrop.image.adjust"))
        assertFalse(ids.contains("backdrop.image.clear"))
        val withImage = selectionPage(BackdropFlowState(imagePath = "/w/qingyu_1.jpg")).flattenedIds()
        assertTrue(withImage.contains("backdrop.image.adjust"))
        assertTrue(withImage.contains("backdrop.image.clear"))
    }

    @Test
    fun `文件已丢失时出现可点的警示条`() {
        // :873-895 + :942-996
        val missing = SelectionPageState(
            backdrop = BackdropFlowState(imagePath = "/w/gone.jpg"),
            fileMissing = true,
        )
        val spec = SettingsBackdropFlowPage.selectionPage(missing.backdrop, missing)
        val notice = spec.row("backdrop.image.missing")
        assertEquals("图片文件已丢失", notice.title)
        assertEquals("已回退为纯色背景，点下方换壁纸重选", notice.subtitle)
        // 警示条本身就是一个动作（点了回到选图），不是纯文字。
        // ⚠ 因此这条 subtitle 里的「点下方换壁纸」在这条**可点**的警示条上是错的说法：
        // 同一个 ARB 键还被选图页的不可点空态复用（WallpaperPositionPickerPage.PickerEmptyState）。
        // 要修必须拆键，属于产品文案决定，见 .botharness/copy-audit 的对照表。
        assertEquals(SettingsAction.NAVIGATE, notice.action)
        assertEquals("backdrop.image.missing", notice.actionTarget)

        // 文件在的时候不该出现
        val ok = SettingsBackdropFlowPage.selectionPage(BackdropFlowState(imagePath = "/w/qingyu_1.jpg"))
        assertFalse(ok.flattenedIds().contains("backdrop.image.missing"))
    }

    @Test
    fun `最近使用整段的标题与说明`() {
        // settings_recent_wallpaper.dart:110-119
        val spec = selectionPage(BackdropFlowState(history = listOf("a.jpg", "b.jpg")))
        val recent = spec.flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "backdrop.recent" }
        assertEquals(InlineKind.CONTROL_CARD, recent.kind)
        assertEquals("最近使用", recent.label)
        assertEquals("点按切回，点角标移除，最多 10 张", recent.value)
        assertEquals(listOf("a.jpg", "b.jpg"), recent.colors)
    }

    @Test
    fun `最近使用为空时整段不渲染`() {
        // :816-818 `if (entries.isEmpty) return SizedBox.shrink()`
        val spec = selectionPage(BackdropFlowState(history = emptyList(), imagePath = null))
        assertFalse(spec.flattenedIds().contains("backdrop.recent"))
        // 有当前图但历史为空时，当前那张要补在最前（:805-813）
        val withCurrent = selectionPage(BackdropFlowState(history = emptyList(), imagePath = "/w/qingyu_9.jpg"))
        val recent = withCurrent.flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "backdrop.recent" }
        assertEquals(listOf("/w/qingyu_9.jpg"), recent.colors)
    }

    @Test
    fun `确认删除那一条的文案与两颗按钮`() {
        // settings_recent_wallpaper.dart:169-203
        val armed = SelectionPageState(
            backdrop = BackdropFlowState(history = listOf("a.jpg")),
            armedKey = "a.jpg",
        )
        val spec = SettingsBackdropFlowPage.selectionPage(armed.backdrop, armed)
        val hint = spec.flatten().filterIsInstance<SettingsDescription>()
            .single { it.textKey == "wallpaperHistoryRemoveConfirmHint" }
        assertEquals("将从最近使用中移除，图片文件也会一起删除", hint.text)
        assertEquals("删除", spec.row("backdrop.recent.confirmDelete").title)
        assertEquals("取消", spec.row("backdrop.recent.cancelDelete").title)
        // 删除是危险操作
        assertTrue(spec.row("backdrop.recent.confirmDelete").destructive)
    }

    @Test
    fun `没有发起移除时不出现确认条`() {
        val spec = selectionPage(BackdropFlowState(history = listOf("a.jpg")))
        assertFalse(spec.flattenedIds().contains("backdrop.recent.confirmDelete"))
    }

    @Test
    fun `角标与不移除的解释文案`() {
        // settings_recent_wallpaper.dart:349 / :846-855
        assertEquals("从最近使用中移除", SettingsBackdropFlowPage.REMOVE_BADGE_TOOLTIP.zh)
        assertEquals("正在使用这张壁纸，请先换成别的再删除", SettingsBackdropFlowPage.REMOVE_IN_USE_TOAST.zh)
    }

    @Test
    fun `每日壁纸入口与自动换开关`() {
        // :482-529
        val spec = selectionPage()
        assertEquals("Bing 每日壁纸", spec.row("backdrop.bing.entry").title)
        val auto = spec.row("backdrop.bing.autoApply")
        assertEquals("每天自动更换", auto.title)
        assertEquals("所有课表共用，只换当前这份", auto.subtitle)
        assertEquals(false, auto.switchValue)
        assertEquals(
            true,
            selectionPage(BackdropFlowState(bingAutoApplyEnabled = true))
                .row("backdrop.bing.autoApply")
                .switchValue,
        )
    }

    // ------------------------------------------------------ 第二页「设置」

    @Test
    fun `第二页只有两根控件：随周次滑动与壁纸模糊`() {
        // :725-737
        val spec = settingsPage()
        assertEquals(
            listOf("backdrop.followsWeekPager", "backdrop.blur"),
            spec.group("backdrop.settings").childRowIds(),
        )
        val follows = spec.row("backdrop.followsWeekPager")
        assertEquals("背景随周次滑动", follows.title)
        assertEquals("切周时背景与课表一起移动", follows.subtitle)
        // 默认关（:939 `homePageBackdropFollowsWeekPager = false`）
        assertEquals(false, follows.switchValue)
        assertEquals(
            true,
            settingsPage(BackdropFlowState(followsWeekPager = true))
                .row("backdrop.followsWeekPager")
                .switchValue,
        )
    }

    @Test
    fun `壁纸模糊滑杆是零到二十四`() {
        // widgets/wallpaper_blur_tile.dart:56-84
        val blur = settingsPage().row("backdrop.blur")
        assertEquals("壁纸模糊", blur.title)
        assertEquals(0.0, blur.slider!!.min, 0.0)
        assertEquals(24.0, blur.slider!!.max, 0.0)
        // 每格 1：档数跟着上限走
        assertEquals(24, blur.slider!!.divisions)
        // 0 档显示「关闭」而不是「0」（:38-41 / :76-78）
        assertEquals("关闭", blur.value)
        assertEquals("homePageWallpaperBlurOff", blur.valueKey)
        assertEquals(
            "12",
            settingsPage(BackdropFlowState(blurSigma = 12.0)).row("backdrop.blur").value,
        )
        // 存量越界值夹到收口带，拇指与数字同口径
        assertEquals(
            "24",
            settingsPage(BackdropFlowState(blurSigma = 40.0)).row("backdrop.blur").value,
        )
    }

    // -------------------------------------------------------------- 提示文案

    @Test
    fun `自动换的三句提示都在`() {
        // :584-617
        assertEquals("正在换成今天的壁纸", SettingsBackdropFlowPage.AUTO_APPLYING.zh)
        assertEquals("今天已经换过啦", SettingsBackdropFlowPage.AUTO_ALREADY_DONE.zh)
        assertEquals(
            "Bing 还没放出今天的图，先用 10 月 5 日 那张顶一下",
            SettingsBackdropFlowPage.AUTO_STALE.filled("date", "10 月 5 日"),
        )
    }

    @Test
    fun `文件丢失的提示与删除撤销的文案`() {
        // :1158-1163 / :348-353
        assertEquals(
            "壁纸文件已丢失，已恢复为纯色背景，请重新选择一张",
            SettingsBackdropFlowPage.FILE_MISSING_TOAST.zh,
        )
        assertEquals("已从最近使用中删除", SettingsBackdropFlowPage.REMOVED_TOAST.zh)
        assertEquals("撤销", SettingsBackdropFlowPage.REMOVE_UNDO.zh)
    }

    // ---------------------------------------------------------- 纯逻辑搬运

    @Test
    fun `文件名从任一分隔符里取最后一段`() {
        // :866-871：刻意不按 Platform.pathSeparator 切 —— 设置能跨设备同步
        assertEquals("a.jpg", SettingsBackdropFlowPage.fileNameOf("/sdcard/wallpapers/a.jpg"))
        assertEquals("a.jpg", SettingsBackdropFlowPage.fileNameOf("C:\\Users\\x\\a.jpg"))
        assertEquals("a.jpg", SettingsBackdropFlowPage.fileNameOf("a.jpg"))
        assertEquals("", SettingsBackdropFlowPage.fileNameOf(""))
        assertEquals("", SettingsBackdropFlowPage.fileNameOf(null))
    }

    @Test
    fun `最近使用列表要把当前那张补在最前`() {
        // :800-818 buildRecentWallpaperTile
        assertEquals(
            listOf("/w/now.jpg", "old1.jpg", "old2.jpg"),
            SettingsBackdropFlowPage.recentEntries(
                history = listOf("old1.jpg", "old2.jpg"),
                currentKey = "/w/now.jpg",
            ),
        )
        // 历史里已经有当前这张时**不重复**补
        assertEquals(
            listOf("/w/now.jpg", "old1.jpg"),
            SettingsBackdropFlowPage.recentEntries(
                history = listOf("/w/now.jpg", "old1.jpg"),
                currentKey = "/w/now.jpg",
            ),
        )
        // 没有当前图时原样返回
        assertEquals(
            listOf("old1.jpg"),
            SettingsBackdropFlowPage.recentEntries(history = listOf("old1.jpg"), currentKey = null),
        )
    }

    @Test
    fun `当前那张不给移除`() {
        // :825-828 + settings_recent_wallpaper.dart:128-137
        assertEquals(
            false,
            SettingsBackdropFlowPage.isRemovable("a.jpg", selectedKey = "a.jpg"),
        )
        assertEquals(
            true,
            SettingsBackdropFlowPage.isRemovable("b.jpg", selectedKey = "a.jpg"),
        )
        // 没有选中项时都不可移除（不猜）
        assertEquals(
            false,
            SettingsBackdropFlowPage.isRemovable("b.jpg", selectedKey = null),
        )
    }

    @Test
    fun `最近使用上限是十张`() {
        // ARB 文案写死了「最多保留 10 张」，常量必须与它同值
        assertEquals(10, SettingsBackdropFlowPage.MAX_HISTORY_ENTRIES)
        assertTrue(
            SettingsStringsExt1.homePageWallpaperRecentSubtitle.zh
                .contains(SettingsBackdropFlowPage.MAX_HISTORY_ENTRIES.toString()),
        )
    }

    @Test
    fun `自动换开关写的是台账不走草稿`() {
        // :501-525：这个开关必须自己订阅台账通知，不能靠宿主 setState
        // 模型层只记「它不属于草稿」，接线层据此接台账
        assertFalse(SettingsBackdropFlowPage.AUTO_APPLY_GOES_THROUGH_DRAFT)
        // 其余两根都写草稿
        assertTrue(SettingsBackdropFlowPage.FOLLOWS_WEEK_PAGER_GOES_THROUGH_DRAFT)
        assertTrue(SettingsBackdropFlowPage.BLUR_GOES_THROUGH_DRAFT)
    }

    @Test
    fun `壁纸流程不产生独立的整页 spec`() {
        // 它是 mixin（:57），两个宿主各自嵌进去；本批只落块
        assertNull(SettingsBackdropFlowPage.PAGE_ID)
    }
}
