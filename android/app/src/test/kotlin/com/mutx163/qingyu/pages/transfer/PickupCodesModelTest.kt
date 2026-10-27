package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 取件码页模型层测试。
 *
 * 期望值从 Dart 源手推：
 * - 七个入口的顺序与分组：`lib/domain/pickup_code_presets.dart` `kPickupCodePresets`（:23-190）；
 * - 失败原因码 → 文案：`pickup_codes_screen.dart` `_reasonText`（:126-133，含 `_ =>` 兜底）；
 * - 语义标签：同文件 :352-354（未安装要在标签里念出来）。
 */
class PickupCodesModelTest {

    // ── 1. 固定表的顺序与分组 ──

    @Test
    fun `一共七个固定入口`() {
        assertEquals(7, PickupCodesModel.presets.size)
    }

    @Test
    fun `顺序按一天里最可能用到的排`() {
        // 身份码三件在前（去柜子跟前第一件事是出示码），查件四件在后。
        assertEquals(
            listOf(
                "pickupCodePresetCainiao",
                "pickupCodePresetTaobao",
                "pickupCodePresetPinduoduo",
                "pickupCodePresetTaobaoParcels",
                "pickupCodePresetPinduoduoParcels",
                "pickupCodePresetJdParcels",
                "pickupCodePresetDouyinParcels",
            ),
            PickupCodesModel.presets.map { it.titleKey },
        )
    }

    @Test
    fun `身份码组三个查件组四个`() {
        assertEquals(3, PickupCodesModel.presetsOf(PickupCodesModel.Group.IDENTITY).size)
        assertEquals(4, PickupCodesModel.presetsOf(PickupCodesModel.Group.PARCELS).size)
    }

    @Test
    fun `身份码用二维码图标查件用包裹图标`() {
        assertEquals(
            listOf("qrCode", "qrCode", "qrCode"),
            PickupCodesModel.presetsOf(PickupCodesModel.Group.IDENTITY).map { it.icon },
        )
        assertTrue(
            PickupCodesModel.presetsOf(PickupCodesModel.Group.PARCELS).all { it.icon == "parcel" },
        )
    }

    @Test
    fun `分组顺序是身份码在前`() {
        assertEquals(
            listOf(PickupCodesModel.Group.IDENTITY, PickupCodesModel.Group.PARCELS),
            PickupCodesModel.groups,
        )
    }

    @Test
    fun `每个入口的标题与说明都能取到文案`() {
        // 取不到会回落成键名（英文标识符），这里断言不是键名
        for (preset in PickupCodesModel.presets) {
            assertTrue("${preset.titleKey} 标题没取到文案", preset.title != preset.titleKey && preset.title.isNotBlank())
            assertTrue("${preset.hintKey} 说明没取到文案", preset.hint != preset.hintKey && preset.hint.isNotBlank())
        }
    }

    @Test
    fun `分组标题取自 ARB`() {
        assertEquals("出示身份码", PickupCodesModel.groupTitle(PickupCodesModel.Group.IDENTITY))
        assertEquals("查待取快递", PickupCodesModel.groupTitle(PickupCodesModel.Group.PARCELS))
    }

    // ── 2. 失败原因码 ──

    @Test
    fun `六个已知原因码各有文案`() {
        assertEquals("没有 App 响应这条链接", PickupCodesModel.reasonText("no_activity"))
        assertEquals("没有找到这个 App", PickupCodesModel.reasonText("app_not_found"))
        assertEquals("链接格式不对", PickupCodesModel.reasonText("invalid_uri"))
        assertEquals("包名格式不对", PickupCodesModel.reasonText("invalid_package"))
        assertEquals("系统没有响应（超时）", PickupCodesModel.reasonText("timeout"))
        assertEquals("当前平台不支持", PickupCodesModel.reasonText("unsupported"))
    }

    @Test
    fun `未知原因码回落未知原因不返回空串`() {
        // Dart 的 switch 有 `_ =>` 兜底；少了兜底用户会看到「打不开「京东」：」后面空着
        assertEquals("未知原因", PickupCodesModel.reasonText("some_new_code"))
        assertEquals("未知原因", PickupCodesModel.reasonText(""))
    }

    // ── 3. 跳转结果话术 ──

    @Test
    fun `拉不起 App 的 toast 带名字`() {
        val text = PickupCodesModel.openedAppToast("京东")
        assertTrue("应含应用名：$text", text.contains("京东"))
    }

    @Test
    fun `失败提示把名字与原因都拼进去`() {
        val text = PickupCodesModel.launchFailedMessage("淘宝", "invalid_uri")
        assertEquals("打不开「淘宝」：链接格式不对", text)
    }

    @Test
    fun `失败时带建议行`() {
        assertEquals("入口可能失效，试试直接打开 App", PickupCodesModel.launchFailedHint)
    }

    @Test
    fun `平台不支持时的提示`() {
        assertEquals("当前平台不支持跳到其它应用", PickupCodesModel.unsupportedMessage)
    }

    // ── 4. 语义标签 ──

    @Test
    fun `已安装时只念名字与分组`() {
        val preset = PickupCodesModel.presets.first()
        assertEquals("菜鸟，出示身份码", PickupCodesModel.semanticsLabel(preset, installed = true))
    }

    @Test
    fun `未安装时额外念出未安装`() {
        val preset = PickupCodesModel.presets.first()
        val label = PickupCodesModel.semanticsLabel(preset, installed = false)
        assertEquals("菜鸟，出示身份码，未安装对应应用", label)
    }

    @Test
    fun `标题缺失时兜底未命名入口`() {
        assertEquals("未命名入口", PickupCodesModel.entryTitle(null))
    }
}
