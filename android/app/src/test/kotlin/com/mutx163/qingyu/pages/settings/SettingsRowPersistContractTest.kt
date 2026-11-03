package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置行「值变化 → 落盘一次」的**写盘节奏契约**（2026-11-03 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 滑杆的 `onValueChange` 每个拖动 tick 都会回调；选色器的 `onColorChanged` 拖动中也是
 * 连续回调。渲染层照官方组件的节奏原样转发（这是对的），「落盘几次」的判据就全压在
 * 宿主的写路径上：
 *
 * - **滑杆**：内存草稿立刻更新（预览跟手），落盘走 `DebouncedSettingsWriter` 的
 *   250ms 防抖——一个静默窗口只留最后一次，离页 flush 兜底不丢最后一档。
 *   `PrefsKeyValueStore.putString` 是同步 `commit()`，不做防抖就是主线程上每帧一次
 *   「读-合并-序列化-写盘」。2026-11-03 之前 `TimetablePageSettingsHost`（课表页面设置：
 *   行高 / 课卡间距 / 回到本周不透明度 / 壁纸模糊四根滑杆）就漏了这一层。
 * - **非滑杆行**（开关 / 下拉 / 单选）：一次动作就是一次落盘，且写之前先 flush 防抖里
 *   欠着的那一档，避免旧值后落地把新值盖回去。
 * - **选色弹窗**：拖动只改弹窗本地色，**确认才写一次**（Dart `_showColorPicker` 同口径）。
 *
 * ## 为什么读源码文本
 *
 * 写盘节奏发生在 `composeP1` 的宿主函数体里；`src/test` 只挂 `main` 源集，
 * `SettingsHost` 编不进来（与 `SettingsHostIntentWiringGuardTest` 同一套做法）。
 * 模型层的部分（本页到底哪几行是滑杆）用真 spec 运行时断言。找不到文件**判失败
 * 而不是跳过**。
 */
class SettingsRowPersistContractTest {

    // ------------------------------------------------------------------ 模型层

    @Test
    fun `课表页面设置的滑杆行就是那四根`() {
        val sliderIds = SettingsTimetablePageSettingsPage
            .spec(TimetablePageSettingsState(screenshotShareSupported = true))
            .rows()
            .filter { it.component == MiuixRowComponent.SLIDER }
            .map { it.id }
            .sorted()
        assertEquals(
            listOf(
                "timetablePage.backToWeek.opacity",
                "timetablePage.background.blur",
                "timetablePage.courseCardGap",
                "timetablePage.sectionHeight",
            ),
            sliderIds,
        )
    }

    @Test
    fun `选色弹窗标题绑定与 ARB 逐字一致`() {
        assertTrue(
            "键 textColorSelectColor 必须在 app_zh.arb 里",
            ArbZh.strings.containsKey("textColorSelectColor"),
        )
        assertEquals(
            ArbZh.value("textColorSelectColor"),
            SettingsStrings.textColorSelectColor.zh,
        )
    }

    // ------------------------------------------------------------------ 宿主源码

    @Test
    fun `两个宿主都接了防抖写盘器与离页补写`() {
        val source = settingsHostSource()
        val writerCount = Regex("""DebouncedSettingsWriter\(store, scope\)""").findAll(source).count()
        assertEquals(
            "DebouncedSettingsWriter 只挂在一处：另一个宿主的滑杆还在每帧同步落盘（主宿主 + 课表页面设置宿主各一处）",
            2,
            writerCount,
        )
        val flushOnDispose = Regex("""onDispose \{ writer\.flush\(\) \}""").findAll(source).count()
        assertEquals(
            "离页 flush 只有一处：另一个宿主离开页面时防抖里欠着的那一档会丢",
            2,
            flushOnDispose,
        )
    }

    @Test
    fun `课表页面设置宿主的滑杆走防抖非滑杆先补写再落盘`() {
        val source = settingsHostSource()
        // TimetablePageSettingsHost 的 commitWrite：滑杆分支只改内存 + schedule，
        // 非滑杆分支先 flush 再 commitModel（顺序反了 = 防抖欠档会被旧值盖回去）。
        val sliderBranch = Regex(
            """if \(actual in sliderRowIds\) \{\s*\n\s*// [^\n]*\n\s*model = result\.model\s*\n\s*writer\.schedule\(result\.model\)""",
        )
        assertTrue(
            "课表页面设置宿主的滑杆分支不再走 writer.schedule：拖动中每帧同步落盘",
            sliderBranch.containsMatchIn(source),
        )
        val immediateBranch = Regex("""writer\.flush\(\)\s*\n\s*commitModel\(result\.model\)""")
            .findAll(source).count()
        assertTrue(
            "「先 flush 再 commitModel」的立即可写分支应至少 2 处（主宿主 + 课表页面设置宿主），实际 $immediateBranch",
            immediateBranch >= 2,
        )
    }

    @Test
    fun `防抖器一个静默窗口只留最后一次且窗口为250毫秒`() {
        val source = settingsHostSource()
        // schedule 的三件套：记 pending、取消上一个 job、再 launch——顺序反了或漏了
        // cancel，一个窗口内就会排队多次落盘。
        val scheduleBody = Regex(
            """fun schedule\(next: TimetableSettingsModel\) \{\s*\n\s*pending = next\s*\n\s*job\?\.cancel\(\)\s*\n\s*job = scope\.launch \{""",
        )
        assertTrue(
            "DebouncedSettingsWriter.schedule 不再是「记档 → 取消旧 job → 重排」的形态：一个拖动窗口会落盘多次",
            scheduleBody.containsMatchIn(source),
        )
        assertTrue(
            "防抖窗口不再是 250ms（Dart settings_general.dart:116 的同一个数）",
            "const val DEBOUNCE_MILLIS: Long = 250L" in source,
        )
        // flush 消费掉 pending：不置空就会在下一次 flush 时重复落盘同一档。
        assertTrue(
            "flush 必须取走并清空 pending（否则同一档会被写两次）",
            Regex("""val next = pending \?: return\s*\n\s*pending = null""").containsMatchIn(source),
        )
    }

    @Test
    fun `选色弹窗用官方ColorPicker且确认才写`() {
        val source = settingsHostSource()
        assertTrue(
            "选色弹窗不再 import 官方 basic.ColorPicker：别改回手拼 RGB 滑杆",
            "import top.yukonga.miuix.kmp.basic.ColorPicker" in source,
        )
        assertFalse(
            "手拼的 RGB 三通道行（ColorChannel）应已删除",
            "ColorChannel(" in source,
        )
        assertTrue(
            "确认按钮不再从本地色取值落盘：选色弹窗的「确认才写一次」断了",
            "onConfirm(pickerColor.toHexRgb())" in source,
        )
        // 两个宿主（主宿主 + 课表页面设置宿主）的选色意图都落在同一颗弹窗上，
        // 确认回调各自接 commitWrite——少一处，那页的选色确认就静默不写。
        val confirmCallbacks = Regex("""onConfirm = \{ hex ->""").findAll(source).count()
        val confirmWrites = Regex("""commitWrite\(hex, it\.rowId\)""").findAll(source).count()
        assertEquals(
            "选色弹窗的确认回调应恰好 2 处（两个宿主各一）",
            2,
            confirmCallbacks,
        )
        assertEquals(
            "选色确认 → commitWrite 的接线应恰好 2 处（两个宿主各一）",
            2,
            confirmWrites,
        )
    }

    // ------------------------------------------------------------------ 解析

    private fun settingsHostSource(): String {
        val host = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt",
        )
        assertTrue("SettingsHost.kt 不存在：${host.path}", host.isFile)
        return host.readText()
    }

    /** 从当前工作目录向上找 `android/app/src`（兼容 L0 脚本与 Gradle 两种工作目录）。 */
    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }
}
