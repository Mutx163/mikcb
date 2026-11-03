package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.ClassReminderEntry
import com.mutx163.qingyu.core.ClassReminderLogic
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「已设提醒」块接线的**双半边契约**（2026-11-03）：
 *
 * 1. **接线半边**：壳 `ShellWiring` 必须把 `existingReminderMinuteOfDay` 读侧与
 *    `onRemoveReminder` 写侧真接进子弹层——两个参数任一缺接，`ClassAlarmSheet`
 *    按约定整块不渲染，用户永远看不到「已设提醒：HH:mm / 取消」。接线发生在
 *    Compose 函数体里，反射与编译产物都不保留，所以读源码文本（与同目录
 *    `DayViewWiringGuardTest` 同一套做法）。
 * 2. **行为半边**：走壳同一条 store + 逻辑链路（`ClassReminderLogic.remove` →
 *    `saveSettings`，即 `saveSettingsPatch` 合并写）真删一遍，断言**设置里那条
 *    真消失**、同课表里别的条目不动、盘上 Dart 侧的其它键不被洗掉——不是
 *    「调用了某个方法」级别，是落盘重读后的状态断言。
 */
class ClassAlarmReminderWiringContractTest {

    // ── 接线半边 ─────────────────────────────────────────────────────────

    @Test
    fun `宿主必须把已设提醒读侧与移除回调接进子弹层`() {
        val wiring = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        )
        assertTrue(
            "`ShellWiring` 没有把 `existingReminderMinuteOfDay` 传进 `CourseActionSheet`——" +
                "null 会让子弹层整块不画「已设提醒」，用户看不到已设过什么。",
            "existingReminderMinuteOfDay = existingReminderMinuteOfDay" in wiring,
        )
        assertTrue(
            "`ShellWiring` 没有把 `onRemoveReminder` 接到 `removeTargetClassReminder()`——" +
                "「取消」按钮点了没反应。",
            "onRemoveReminder = { removeTargetClassReminder() }" in wiring,
        )
        assertTrue(
            "读侧没有用 `ClassReminderEntry.formatDate(date)` 归一日期——日期格式与" +
                "落盘条目（yyyy-MM-dd）对不上就永远查不到已设条目。",
            "ClassReminderEntry.formatDate(date)" in wiring,
        )
    }

    @Test
    fun `移除链路必须走共享逻辑与合并写且成功才收弹层`() {
        val wiring = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        )
        val start = wiring.indexOf("fun removeTargetClassReminder")
        assertTrue("找不到 `removeTargetClassReminder`——移除回调没有实现。", start >= 0)
        // 函数体到下一个锚点（弹层挂载处）为止：同目录守卫的分支截取同款做法。
        val end = wiring.indexOf("val course = actionTarget", start)
        assertTrue("函数体定位失败：锚点 `val course = actionTarget` 不在函数之后。", end > start)
        val body = wiring.substring(start, end)
        assertTrue(
            "删表没有走共享的 `ClassReminderLogic.remove`——另写一套会与统计「设过提醒」、" +
                "课卡铃铛的判据漂移。",
            "ClassReminderLogic.remove(current.classReminders, target.id, dateText)" in body,
        )
        assertTrue(
            "没有经仓储 `updateSettings` 落盘——它内部才是 saveSettings → saveSettingsPatch " +
                "合并写 + 通知；直写 store 会让课卡铃铛 / 统计停在旧值。",
            "repository.updateSettings(current.copy(classReminders = updated))" in body,
        )
        assertTrue(
            "成功提示没有用既有 `classAlarmRemovedToast`（自拟文案会同时红 CJK 门禁与 ARB 对拍）。",
            "classAlarmRemovedToast" in body,
        )
        // 顺序契约：收弹层（actionTarget = null）必须在成功提示**之后**——
        // 失败路径只 toast、弹层留着，不许静默关掉。
        val toastIdx = body.indexOf("classAlarmRemovedToast")
        val closeIdx = body.indexOf("actionTarget = null")
        assertTrue("弹层收起出现在成功提示之前——失败路径也会把弹层关掉（静默失败）。", closeIdx > toastIdx)
        assertTrue(
            "失败路径没有 toast（找不到 `saveFailed`）——写盘失败会变成点了没反应。",
            "TimetableStrings.saveFailed.zh" in body,
        )
    }

    // ── 行为半边：移除后设置里那条真消失 ─────────────────────────────────

    @Test
    fun `移除后设置里那条真消失且同表其它条目不动`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        // 先放一个 Dart 侧风格的「本层不认识的键」，验证合并写不把它洗掉。
        store.saveSettingsPatch(mapOf("dartFutureKey" to "keep-me"))
        val gone = ClassReminderEntry(courseId = "c1", date = "2026-11-04", minuteOfDay = 470)
        val kept = ClassReminderEntry(courseId = "c2", date = "2026-11-04", minuteOfDay = 500)
        store.saveSettings(TimetableSettings(classReminders = listOf(gone, kept)))

        // 壳的同一条链路：读 → ClassReminderLogic.remove → saveSettings
        //（= saveSettingsPatch 合并写；壳侧经 repository.updateSettings 走到这里）。
        val current = store.loadSettings()
        val updated = ClassReminderLogic.remove(current.classReminders, "c1", "2026-11-04")
        store.saveSettings(current.copy(classReminders = updated))

        val reloaded = store.loadSettings()
        assertEquals("被移除的条目还在设置里（真消失断言失败）。", emptyList<String>(), reloaded.classReminders.filter { it.key == gone.key }.map { it.key })
        assertEquals("同表的其它条目被误删了。", listOf(kept.key), reloaded.classReminders.map { it.key })
        // 合并写语义：别的课在这天的条目保留，盘上外来键也原样。
        assertEquals("keep-me", store.loadSettingsJson()["dartFutureKey"])
    }

    @Test
    fun `守卫本身没有空转`() {
        val wiring = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        )
        assertTrue("ShellWiring.kt 读出来太短（${wiring.length} 字符），定位可能坏了", wiring.length > 1000)
        assertTrue("源文件里应当有 CourseActionSheet( 挂载", "CourseActionSheet(" in wiring)
    }

    /** 与同目录守卫同一口径：从工作目录向上找仓库根，找不到仍判失败。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
