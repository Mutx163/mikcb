package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「Compose 壳」占位名不得回潮 + 设备名必须落盘的源级守卫（2026-11-10 用户报）。
 *
 * 两条线：
 * 1. 占位名作为**字符串字面量**只允许出现在 [DeviceLabelResolver.LEGACY_PLACEHOLDER] 一处；
 *    注释里讲历史沿革是正常文档，不算回潮（所以只匹配带引号的形态）。
 * 2. 壳层必须走 `DeviceLabelResolver`，并且把「改名」接上落盘回调
 *    （以前只改控制器草稿、从未调 `writeDeviceLabel`，所以读回来永远空 ⇒ 永远显示占位名）。
 */
class DeviceLabelLegacyPlaceholderGuardTest {

    @Test
    fun placeholder_string_literal_only_in_resolver() {
        val quoted = "\"" + DeviceLabelResolver.LEGACY_PLACEHOLDER + "\""
        val offenders = mutableListOf<String>()
        roots().forEach { root ->
            if (!root.isDirectory) return@forEach
            root.walkTopDown()
                .filter { it.isFile && it.extension == "kt" }
                .forEach { file ->
                    if (file.name.endsWith("DeviceLabelResolver.kt")) return@forEach
                    if (file.readText().contains(quoted)) {
                        offenders += file.relativeTo(androidSrc()).path
                    }
                }
        }
        assertEquals("占位名回潮：${offenders.joinToString()}", emptyList<String>(), offenders)
    }

    @Test
    fun shell_must_use_resolver_and_persist() {
        val shell = File(androidSrc(), "main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt").readText()
        assertEquals(
            "两个云同步入口都必须走 DeviceLabelResolver（防止一处漏改）",
            2,
            Regex("""DeviceLabelResolver\.resolveDeviceLabel\(""").findAll(shell).count(),
        )
        assertEquals(
            "两个入口都必须把改名接到 writeDeviceLabel",
            2,
            Regex("""persistDeviceLabel = configStore::writeDeviceLabel""").findAll(shell).count(),
        )
        assertTrue("壳层不许再出现带引号的占位名兜底", !shell.contains("\"" + DeviceLabelResolver.LEGACY_PLACEHOLDER + "\""))

        val controller = File(
            androidSrc(),
            "main/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncController.kt",
        ).readText()
        assertTrue("控制器改名时必须调落盘回调", controller.contains("persistDeviceLabel?.invoke("))
    }

    private fun roots(): List<File> = listOf(
        File(androidSrc(), "main/kotlin"),
        File(androidSrc(), "composeP1/kotlin"),
    )

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
