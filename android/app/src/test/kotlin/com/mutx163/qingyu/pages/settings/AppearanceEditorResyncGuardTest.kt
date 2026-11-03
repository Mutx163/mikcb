package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 外观编辑页「回到页顶对齐盘上真值」的判据与接线守卫（2026-11-03 用户实报
 * 「Bing 壁纸点应用，预览要点完成才变」）。
 *
 * ## 根因（守卫钉的是什么）
 *
 * Bing 图库 / 调整位置这类被外观编辑页推开的整页，应用结果直接 `store.save()` 落盘、
 * 不经过编辑页草稿；而编辑页被覆盖期间仍组合着（miuix `NavDisplay` 可见窗口
 * `opaqueDepth = 1`，depth=1 的被覆盖页不销毁），返回后草稿还是旧内存值——
 * 预览（读草稿）停在旧壁纸，直到「完成」退出、首页按 `settingsRevision` 重读盘。
 *
 * 修法：宿主监听 NavDisplay 条目自己的 `LocalLifecycleOwner` 的 `ON_RESUME`
 * （重新成为页顶），按 [appearanceEditorResyncOnResume] 对齐草稿。守卫钉住这条
 * 接线不许被拆（判据先剥注释）；找不到文件判失败而不是跳过。
 */
class AppearanceEditorResyncGuardTest {

    // ── 纯判据（appearanceEditorResyncOnResume）─────────────────────────

    @Test
    fun `盘上与草稿不同时返回盘上真值`() {
        val draft = TimetableSettingsModel()
        val disk = draft.copy(homePageWallpaperPath = "/data/wallpapers/bing_new.jpg")
        assertEquals(disk, appearanceEditorResyncOnResume(disk = disk, draft = draft, exiting = false))
    }

    @Test
    fun `盘上与草稿相同不折腾`() {
        val same = TimetableSettingsModel()
        assertNull(appearanceEditorResyncOnResume(disk = same, draft = same, exiting = false))
    }

    @Test
    fun `退场中不对齐`() {
        val draft = TimetableSettingsModel()
        val disk = draft.copy(homePageWallpaperPath = "/data/wallpapers/bing_new.jpg")
        assertNull(appearanceEditorResyncOnResume(disk = disk, draft = draft, exiting = true))
    }

    // ── 接线守卫（读源码文本，判据先剥注释）────────────────────────────

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

    /** 去掉块注释与行注释再判（KDoc 里的说明不能算接线）。 */
    private fun codeOf(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .replace(Regex("""//[^\n]*"""), "")

    @Test
    fun `宿主必须订阅条目生命周期并在页顶恢复时对齐草稿`() {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt",
        )
        assertTrue("AppearanceEditorHost.kt 不存在：${file.path}", file.isFile)
        val code = codeOf(file.readText())
        assertTrue(
            "宿主没有读 NavDisplay 条目的 LocalLifecycleOwner：被 Bing 图库/调整位置" +
                "覆盖返回后草稿不会重读盘，预览要点完成才变（2026-11-03 用户实报）",
            "LocalLifecycleOwner.current" in code,
        )
        assertTrue(
            "宿主没有监听 ON_RESUME：回到页顶时不会对齐盘上真值，" +
                "「应用」后的壁纸/位置改动预览看不到",
            "Lifecycle.Event.ON_RESUME" in code,
        )
        assertTrue(
            "宿主没有注册/注销生命周期观察者（addObserver 与 removeObserver 要成对）",
            "addObserver(" in code && "removeObserver(" in code,
        )
        assertTrue(
            "对齐判据必须走 appearanceEditorResyncOnResume（不许在宿主里另写一套）",
            "appearanceEditorResyncOnResume(" in code,
        )
        assertEquals(
            "判据在代码区只应出现一次（声明在 main，宿主只调用）",
            1,
            Regex("appearanceEditorResyncOnResume\\(").findAll(code).count(),
        )
    }
}
