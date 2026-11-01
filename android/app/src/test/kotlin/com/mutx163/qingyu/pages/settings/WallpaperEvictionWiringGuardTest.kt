package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 壁纸删除白名单的**接线守卫**。
 *
 * 纯逻辑在 [WallpaperEvictionSources]（由 `WallpaperEvictionSourcesTest` 钉），
 * 但宿主一旦不再把「所有档案的原始 JSON」传进去，逻辑再对也白搭——上一批正是
 * 「函数支持多档案、调用点只传当前课表」才漏掉的。宿主在 `composeP1` 源集，
 * `src/test` 编不进来，所以按 `SettingsRouteWiringGuardTest` 的同一套办法读源码文本；
 * 找不到文件**判失败而不是跳过**。
 */
class WallpaperEvictionWiringGuardTest {

    private fun hostSource(): String {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(
                dir,
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt",
            )
            if (candidate.isFile) return candidate.readText()
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 AppearanceEditorHost.kt —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }

    @Test
    fun `删除入口必须从档案原始 JSON 取所有档案的壁纸`() {
        val source = hostSource()
        assertTrue(
            "删除入口必须走 WallpaperEvictionSources.planEviction（多档案白名单的唯一组装处）",
            source.contains("WallpaperEvictionSources.planEviction("),
        )
        assertTrue(
            "必须把档案原始 JSON 传进判定，否则白名单又只剩当前课表",
            source.contains("profilesJson = profilesJson"),
        )
        assertTrue(
            "必须读 timetable_profiles 原始 JSON（TimetableProfile.settings 没有壁纸键）",
            source.contains("WallpaperEvictionSources.PROFILES_KEY"),
        )
        assertFalse(
            "旧的「只传当前课表」写法不许回来",
            source.contains("allProfilesCurrentPaths = listOfNotNull(model.homePageWallpaperPath)"),
        )
    }

    @Test
    fun `自动换与手动删除共用同一条删除入口`() {
        val source = hostSource()
        assertTrue(
            "自动换淘汰的文件必须交给 deleteWallpaperFiles 统一过白名单",
            source.contains("deleteWallpaperFiles(evicted)"),
        )
    }
}
