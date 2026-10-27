package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.CoupleWebdavConfig
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣课表设置页模型层测试（源：`lib/screens/couple_timetable_settings_screen.dart`
 * + `lib/domain/couple_timetable_logic.dart` 的常量）。
 *
 * 期望值按 Dart 原文手推：
 * - 周次偏移夹在 [-15, 15]，0 显示「无偏移」，正数带 `+` 号；
 * - 忙碌时按钮文案在原标签后接 `...`（Dart `'$label...'`）；
 * - 未连接只出一个「连接坚果云」按钮，已连接出「拉取 / 上传 / 断开」三个；
 * - 颜色快选 = 17 个快捷色，选中色不在里面时补到行首（Dart `_paletteIncluding`）；
 * - 「课程数量」行标签带门数，值是没有导入记录时的 `-`。
 */
class CoupleTimetableSettingsModelTest {

    private val zone: ZoneId = ZoneId.of("Asia/Shanghai")

    private fun binding(
        partnerName: String = "小屿",
        lastImportedAtIso: String? = "2026-10-26T08:15:00.000",
        weekOffset: Int = 0,
        mineColorHex: String = CoupleTimetableSettingsLogic.MINE_COLOR_DEFAULT,
        partnerColorHex: String = CoupleTimetableSettingsLogic.PARTNER_COLOR_DEFAULT,
        togetherColorHex: String = CoupleTimetableSettingsLogic.TOGETHER_COLOR_DEFAULT,
    ) = PartnerTimetableBindingModel(
        partnerName = partnerName,
        lastImportedAtIso = lastImportedAtIso,
        weekOffset = weekOffset,
        mineColorHex = mineColorHex,
        partnerColorHex = partnerColorHex,
        togetherColorHex = togetherColorHex,
    )

    private fun webdav(
        username: String = "couple@example.com",
        lastPulledAtIso: String? = null,
        mySlot: Int = 1,
    ) = CoupleWebdavConfig(username = username, mySlot = mySlot, lastPulledAtIso = lastPulledAtIso)

    // ==========================================
    // 1. 绑定状态 / 信息行
    // ==========================================

    @Test
    fun `绑定与未绑定的分区标题`() {
        assertEquals("已绑定对方课表", CoupleTimetableSettingsLogic.sectionTitle(bound = true))
        assertEquals("尚未绑定对方课表", CoupleTimetableSettingsLogic.sectionTitle(bound = false))
    }

    @Test
    fun `上次导入时间格式化没记录时是短横线`() {
        assertEquals("2026-10-26 08:15",
            CoupleTimetableSettingsLogic.formatDateTimeOrDash("2026-10-26T08:15:00.000", zone))
        assertEquals("-", CoupleTimetableSettingsLogic.formatDateTimeOrDash(null, zone))
        assertEquals("-", CoupleTimetableSettingsLogic.formatDateTimeOrDash("坏时间", zone))
    }

    @Test
    fun `课程数量标签带门数`() {
        assertEquals("课程数量：12 门", CoupleTimetableSettingsLogic.courseCountLabel(12))
        assertEquals("课程数量：0 门", CoupleTimetableSettingsLogic.courseCountLabel(0))
    }

    // ==========================================
    // 2. 周次偏移
    // ==========================================

    @Test
    fun `周次偏移文案零偏移与正负号`() {
        assertEquals("无偏移", CoupleTimetableSettingsLogic.weekOffsetLabel(0))
        assertEquals("+3 周", CoupleTimetableSettingsLogic.weekOffsetLabel(3))
        assertEquals("-2 周", CoupleTimetableSettingsLogic.weekOffsetLabel(-2))
    }

    @Test
    fun `周次偏移边界十五`() {
        assertTrue(CoupleTimetableSettingsLogic.canDecrement(-14))
        assertTrue(CoupleTimetableSettingsLogic.canDecrement(0))
        assertFalse(CoupleTimetableSettingsLogic.canDecrement(-15))
        assertTrue(CoupleTimetableSettingsLogic.canIncrement(14))
        assertFalse(CoupleTimetableSettingsLogic.canIncrement(15))
        assertEquals(-15, CoupleTimetableSettingsLogic.MIN_WEEK_OFFSET)
        assertEquals(15, CoupleTimetableSettingsLogic.MAX_WEEK_OFFSET)
    }

    @Test
    fun `周次偏移预览文案`() {
        assertEquals(
            "查看你的第 5 周时，显示对方第 6 周的课",
            CoupleTimetableSettingsLogic.weekOffsetPreview(myWeek = 5, partnerWeek = 6),
        )
    }

    // ==========================================
    // 3. 情侣 WebDAV 段
    // ==========================================

    @Test
    fun `未连接时只显示连接按钮`() {
        val state = CoupleTimetableSettingsLogic.buildViewState(
            binding = binding(),
            webdavConfig = webdav(username = ""),
            hasStoredPassword = false,
            busy = CoupleBusyState(),
            partnerCourseCount = 12,
            partnerProfileName = null,
            myWeek = 3,
            partnerWeek = 3,
            zone = zone,
        )
        assertEquals("尚未连接坚果云", state.webdavStatusText)
        assertEquals(listOf("连接坚果云"), state.webdavButtons.map { it.label })
        assertTrue(state.webdavButtons.single().enabled)
    }

    @Test
    fun `已连接时三个按钮与远程路径上次拉取`() {
        val state = CoupleTimetableSettingsLogic.buildViewState(
            binding = binding(),
            webdavConfig = webdav(lastPulledAtIso = "2026-10-27T09:30:00.000"),
            hasStoredPassword = true,
            busy = CoupleBusyState(),
            partnerCourseCount = 12,
            partnerProfileName = null,
            myWeek = 3,
            partnerWeek = 3,
            zone = zone,
        )
        assertEquals("已连接：couple@example.com", state.webdavStatusText)
        assertEquals(
            listOf("立即拉取对方课表", "上传我的课表到坚果云", "断开连接"),
            state.webdavButtons.map { it.label },
        )
        // 槽位 1 → 读对端槽位 2 的文件。
        assertEquals("远程文件路径：/Apps/qingyu-couple/couple-slot-2.mikcb", state.webdavRemotePathText)
        assertEquals("上次拉取：2026-10-27 09:30", state.webdavLastPulledText)
    }

    @Test
    fun `从未拉取过就没有上次拉取行`() {
        val state = CoupleTimetableSettingsLogic.buildViewState(
            binding = binding(),
            webdavConfig = webdav(),
            hasStoredPassword = true,
            busy = CoupleBusyState(),
            partnerCourseCount = 12,
            partnerProfileName = null,
            myWeek = 3,
            partnerWeek = 3,
            zone = zone,
        )
        assertNull(state.webdavLastPulledText)
    }

    // ==========================================
    // 4. 忙碌态按钮文案与禁点
    // ==========================================

    @Test
    fun `忙碌时标签接省略号且不可点`() {
        val state = CoupleTimetableSettingsLogic.buildViewState(
            binding = binding(),
            webdavConfig = webdav(),
            hasStoredPassword = true,
            busy = CoupleBusyState(isExporting = true, isPullingWebdav = true),
            partnerCourseCount = 12,
            partnerProfileName = null,
            myWeek = 3,
            partnerWeek = 3,
            zone = zone,
        )
        val export = state.coupleButtons.first { it.label.startsWith("导出我的课表给对方") }
        assertEquals("导出我的课表给对方...", export.label)
        assertTrue(export.loading)
        assertFalse(export.enabled)

        val pull = state.webdavButtons.first { it.label.startsWith("立即拉取对方课表") }
        assertEquals("立即拉取对方课表...", pull.label)
        assertFalse(pull.enabled)
        // 「断开连接」不受拉取忙碌影响（Dart 无 loading/onPressed 门禁）。
        assertTrue(state.webdavButtons.last().enabled)
    }

    @Test
    fun `未绑定时不出现解除绑定按钮`() {
        val state = CoupleTimetableSettingsLogic.buildViewState(
            binding = null,
            webdavConfig = webdav(username = ""),
            hasStoredPassword = false,
            busy = CoupleBusyState(),
            partnerCourseCount = 0,
            partnerProfileName = null,
            myWeek = 1,
            partnerWeek = 1,
            zone = zone,
        )
        assertEquals(
            listOf("导出我的课表给对方", "导入对方课表"),
            state.coupleButtons.map { it.label },
        )
        assertFalse(state.showWeekOffset)
        assertFalse(state.showColors)
    }

    // ==========================================
    // 5. 颜色快选
    // ==========================================

    @Test
    fun `快捷色表是十九个且首项是默认蓝`() {
        // Dart `kCourseColorQuickPickHexes`：数一遍是 19 个（默认蓝开头、棕灰收尾）。
        assertEquals(19, CoupleTimetableSettingsLogic.QUICK_PICK_HEXES.size)
        assertEquals("#2196F3", CoupleTimetableSettingsLogic.QUICK_PICK_HEXES.first())
        assertEquals("#78716C", CoupleTimetableSettingsLogic.QUICK_PICK_HEXES.last())
    }

    @Test
    fun `选中色不在快捷表时补到行首`() {
        val inList = CoupleTimetableSettingsLogic.paletteIncluding("#22C55E")
        assertEquals(CoupleTimetableSettingsLogic.QUICK_PICK_HEXES, inList)

        val custom = CoupleTimetableSettingsLogic.paletteIncluding("#123456")
        assertEquals(20, custom.size)
        assertEquals("#123456", custom.first())

        // 大小写不敏感（Dart 用 toUpperCase 比较）。
        val lower = CoupleTimetableSettingsLogic.paletteIncluding("#22c55e")
        assertEquals(CoupleTimetableSettingsLogic.QUICK_PICK_HEXES, lower)
    }

    @Test
    fun `三行颜色标签与当前值`() {
        val rows = CoupleTimetableSettingsLogic.colorRows(
            binding(
                mineColorHex = "#EF4444",
                partnerColorHex = "#EC4899",
                togetherColorHex = "#8B5CF6",
            ),
        )
        assertEquals(listOf("我的课", "TA的课", "一起上课"), rows.map { it.label })
        assertEquals(listOf("#EF4444", "#EC4899", "#8B5CF6"), rows.map { it.selectedHex })
    }

    // ==========================================
    // 6. 对方名称来源（个人档案优先）
    // ==========================================

    @Test
    fun `对方名称优先取档案名回落到绑定名`() {
        val withProfile = CoupleTimetableSettingsLogic.buildViewState(
            binding = binding(partnerName = "绑定名"),
            webdavConfig = webdav(),
            hasStoredPassword = true,
            busy = CoupleBusyState(),
            partnerCourseCount = 3,
            partnerProfileName = "档案名",
            myWeek = 2,
            partnerWeek = 2,
            zone = zone,
        )
        assertEquals("档案名", withProfile.partnerName)

        val withoutProfile = CoupleTimetableSettingsLogic.buildViewState(
            binding = binding(partnerName = "绑定名"),
            webdavConfig = webdav(),
            hasStoredPassword = true,
            busy = CoupleBusyState(),
            partnerCourseCount = 3,
            partnerProfileName = null,
            myWeek = 2,
            partnerWeek = 2,
            zone = zone,
        )
        assertEquals("绑定名", withoutProfile.partnerName)
    }

    // ==========================================
    // 7. 结果提示
    // ==========================================

    @Test
    fun `导入成功与部分损坏后缀`() {
        val ok = CoupleTimetableSettingsLogic.importToast(updated = false, droppedTotal = 0)
        assertEquals("已导入对方课表", ok.message)
        assertFalse(ok.isError)

        val updated = CoupleTimetableSettingsLogic.importToast(updated = true, droppedTotal = 3)
        assertEquals("已更新对方课表，其中 3 条格式损坏已跳过", updated.message)
        assertFalse(updated.isError)
    }

    @Test
    fun `拉取结果的四种提示`() {
        assertEquals("已从坚果云导入对方课表",
            CoupleTimetableSettingsLogic.pullToast(CoupleWebdavPullStatus.IMPORTED, null).message)
        assertEquals("已从坚果云更新对方课表",
            CoupleTimetableSettingsLogic.pullToast(CoupleWebdavPullStatus.UPDATED, null).message)
        assertEquals("对方课表无变化",
            CoupleTimetableSettingsLogic.pullToast(CoupleWebdavPullStatus.UNCHANGED, null).message)

        val failed = CoupleTimetableSettingsLogic.pullToast(
            CoupleWebdavPullStatus.FAILED,
            "couple_webdav_partner_file_missing",
        )
        assertEquals("未找到对方课表文件，请让对方先上传", failed.message)
        assertTrue(failed.isError)
    }

    @Test
    fun `拉取失败无错误码时用默认拉取失败文案`() {
        // Dart: localizeServiceMessage(l10n, result.errorCode ?? 'couple_webdav_pull_failed')
        val failed = CoupleTimetableSettingsLogic.pullToast(CoupleWebdavPullStatus.FAILED, null)
        assertEquals("拉取对方课表失败，请稍后重试", failed.message)
        assertTrue(failed.isError)
    }

    @Test
    fun `上传成功与失败`() {
        val ok = CoupleTimetableSettingsLogic.uploadToast(errorCode = null)
        assertEquals("已上传课表，对方可拉取", ok.message)
        assertFalse(ok.isError)

        val notConnected = CoupleTimetableSettingsLogic.uploadToast("couple_webdav_not_connected")
        assertEquals("请先连接坚果云", notConnected.message)
        assertTrue(notConnected.isError)

        // 未知机器码走兜底人话。
        val unknown = CoupleTimetableSettingsLogic.uploadToast("couple_webdav_something_new")
        assertEquals("发生未知错误", unknown.message)
        assertTrue(unknown.isError)
    }

    @Test
    fun `连接失败与断开失败提示`() {
        val connectFailed = CoupleTimetableSettingsLogic.webdavConnectFailedToast()
        assertEquals("连接失败，请检查账号、应用专用密码与网络", connectFailed.message)
        assertTrue(connectFailed.isError)

        val disconnectFailed = CoupleTimetableSettingsLogic.disconnectFailedToast()
        assertEquals("保存失败", disconnectFailed.message)
        assertTrue(disconnectFailed.isError)

        val unlink = CoupleTimetableSettingsLogic.unlinkSuccessToast()
        assertEquals("已解除绑定", unlink.message)
        assertFalse(unlink.isError)
    }

    // ==========================================
    // 8. 解除绑定确认弹框
    // ==========================================

    @Test
    fun `解除绑定确认弹框文案`() {
        val dialog = CoupleTimetableSettingsLogic.unlinkDialog()
        assertEquals("解除情侣课表绑定？", dialog.title)
        assertEquals("解除后将删除本地保存的对方课表，叠加视图也会关闭", dialog.message)
        assertEquals("取消", dialog.cancelLabel)
        assertEquals("解除绑定", dialog.confirmLabel)
    }
}
