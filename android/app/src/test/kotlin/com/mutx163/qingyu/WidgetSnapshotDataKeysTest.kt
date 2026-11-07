package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WidgetSnapshotDataKeys] 的行为断言（JVM 直测）。
 *
 * 钉「撤过期快照」的**收窄语义**：只清两个全局过期件，**绑定与每卡专属快照一个不碰**
 * （hy2 第五轮：原实现把用户配的绑定也清了，是语义扩权）。
 */
class WidgetSnapshotDataKeysTest {

    @Test
    fun `只清全局快照与刷新点_绑定与专属快照一个不碰`() {
        val all = setOf(
            "snapshot_json",
            "refresh_times_json",
            "widget_snapshot_5",
            "widget_binding_7",
            "other_key",
            "homeWidget.backgroundStyle",
        )
        val clear = WidgetSnapshotDataKeys.keysToClear(all)
        assertTrue(clear.contains("snapshot_json"))
        assertTrue(clear.contains("refresh_times_json"))
        assertFalse(
            "绑定是用户资产，撤过期快照绝不能清（清了用户设置页配的卡片绑定就没了）",
            clear.contains("widget_binding_7"),
        )
        assertFalse(
            "每卡专属快照属另一套，且 clearSnapshot 无 appWidgetId 上下文，不能清",
            clear.contains("widget_snapshot_5"),
        )
        assertFalse(clear.contains("other_key"))
        assertFalse(clear.contains("homeWidget.backgroundStyle"))
    }

    @Test
    fun `空集合返回空`() {
        assertTrue(WidgetSnapshotDataKeys.keysToClear(emptySet()).isEmpty())
    }
}
