package com.mutx163.qingyu.pages.timetable

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣绑定键的**单一取值**守卫。
 *
 * 这个键（`partner_timetable_binding`，Dart `storage_service.dart:38`）现在有两处声明：
 * - `pages/sync/CoupleStores.kt` 的 `CouplePartnerStorage.BINDING_KEY`（生产写入方、快照桥用）；
 * - 本模块 `TimetableProfilesController` 的 `PARTNER_BINDING_KEY`（判断孤儿对方档用）。
 *
 * 为什么要重复一份而不是直接引常量：`pages/timetable` 的 L0 classpath 不含 `pages/sync`
 * （`scripts/test-kotlin-module.ps1` 的模块隔离）。所以用一条文本守卫钉住两边的值——
 * 任何一边改了字符串、另一边没跟上，这里立刻红，而不是等真机上「绑定态读不到」才发现。
 */
class CouplePartnerBindingKeyGuardTest {

    @Test
    fun `两处声明的情侣绑定键必须逐字一致`() {
        val syncKey = declaredKey(
            read("android/app/src/main/kotlin/com/mutx163/qingyu/pages/sync/CoupleStores.kt"),
            "BINDING_KEY",
        )
        val profileKey = declaredKey(
            read("android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesController.kt"),
            "PARTNER_BINDING_KEY",
        )

        assertTrue("绑定键不能是空串", syncKey.isNotEmpty())
        assertEquals(
            "两处声明必须同值，否则课表管理页判不出孤儿对方档",
            syncKey,
            profileKey,
        )
    }

    // ---------------------------------------------------------------- 工具

    private fun declaredKey(text: String, name: String): String {
        val pattern = Regex("""const val $name: String = "([^"]*)"""")
        return pattern.find(text)?.groupValues?.get(1)
            ?: error("找不到 $name 的声明（守卫本身失效了，别放宽正则混过去）")
    }

    private fun read(relativePath: String): String {
        val file = File(repoRoot(), relativePath)
        check(file.isFile) { "找不到 $relativePath" }
        return file.readText(Charsets.UTF_8)
    }

    /** 从工作目录向上找仓库根（与同目录守卫测试同一套做法）。 */
    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "android/app/src/composeP1").isDirectory) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（工作目录 ${File("").absolutePath}）")
    }
}
