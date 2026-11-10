package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「设备名」取值契约（用户 2026-11-10 报「为什么设备名叫 Compose 壳」）。
 *
 * 三层根因各有一条断言兜住：
 * 1. 取值顺序：用户存过的名字 > 设备型号 > 兜底「本机」；
 * 2. 旧占位名视同未设置（写盘与显示都不许再出现它）；
 * 3. 备份列表展示侧对旧占位名做等价映射（不批量改云端文件）。
 */
class DeviceLabelResolverTest {

    private val fallback = "本机"

    @Test
    fun `存过自定义名时优先用自定义名`() {
        assertEquals(
            "我的小米",
            DeviceLabelResolver.resolveDeviceLabel(
                stored = "  我的小米  ",
                deviceModel = "Xiaomi 2201122C",
                fallback = fallback,
            ),
        )
    }

    @Test
    fun `没存过时用设备型号`() {
        assertEquals(
            "Xiaomi 2201122C",
            DeviceLabelResolver.resolveDeviceLabel(
                stored = null,
                deviceModel = "  Xiaomi 2201122C ",
                fallback = fallback,
            ),
        )
        assertEquals(
            "Xiaomi 2201122C",
            DeviceLabelResolver.resolveDeviceLabel(
                stored = "   ",
                deviceModel = "Xiaomi 2201122C",
                fallback = fallback,
            ),
        )
    }

    @Test
    fun `型号也拿不到时用兜底文案`() {
        assertEquals(
            fallback,
            DeviceLabelResolver.resolveDeviceLabel(stored = null, deviceModel = "", fallback = fallback),
        )
        assertEquals(
            fallback,
            DeviceLabelResolver.resolveDeviceLabel(stored = "  ", deviceModel = null, fallback = fallback),
        )
    }

    @Test
    fun `旧占位名视同未设置 不会原样写回或显示`() {
        assertEquals(
            "设备型号",
            DeviceLabelResolver.resolveDeviceLabel(
                stored = DeviceLabelResolver.LEGACY_PLACEHOLDER,
                deviceModel = "设备型号",
                fallback = fallback,
            ),
        )
        assertEquals(
            fallback,
            DeviceLabelResolver.resolveDeviceLabel(
                stored = DeviceLabelResolver.LEGACY_PLACEHOLDER,
                deviceModel = "",
                fallback = fallback,
            ),
        )
        // 展示侧：老备份文件里存的占位名按「本机」显示，不批量改云端文件。
        assertEquals(
            SyncStrings.cloudBackupDefaultDeviceLabel.text,
            CloudBackupListLogic.resolveBackupDeviceLabel(DeviceLabelResolver.LEGACY_PLACEHOLDER),
        )
        // 正常自定义名不受影响。
        assertEquals("我的小米", CloudBackupListLogic.resolveBackupDeviceLabel("我的小米"))
    }
}
