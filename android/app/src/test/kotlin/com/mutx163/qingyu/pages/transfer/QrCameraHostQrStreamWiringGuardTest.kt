package com.mutx163.qingyu.pages.transfer

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **二维码扫码宿主必须用帧流管线**的源码守卫（2026-11-10 修「250ms 异码闸门」）。
 *
 * ## 防的是哪一类事故
 *
 * [com.mutx163.qingyu.share.camera.ScanPipeline] 的通用默认值里有一条
 * `minIntervalBetweenScansMs = 250ms`，而二维码发送端正好 250ms 换一帧。如果宿主改回
 * `ScanPipeline(initialHasPermission = …)`，编译不会红、单测全绿，真机上却会持续丢帧，
 * 大备份传不完还表现为「超时」。所以用源码守卫把「宿主必须走 forQrFrameStream」钉住。
 *
 * 行为契约本身由 `ScanPipelineQrStreamTest` 钉；本守卫只钉生产接线没被改回去。
 */
class QrCameraHostQrStreamWiringGuardTest {

    private val source: String by lazy { stripLineComments(readHostSource()) }

    @Test
    fun `扫码宿主必须走二维码帧流管线`() {
        assertTrue(
            "QrCameraHost.kt 没有用 ScanPipeline.forQrFrameStream(——" +
                "通用 250ms 异码闸门会把 250ms 一帧的二维码流限速，大备份会超时",
            source.contains("ScanPipeline.forQrFrameStream("),
        )
    }

    @Test
    fun `扫码宿主不能回退到通用默认配置`() {
        assertFalse(
            "QrCameraHost.kt 仍在用 ScanPipeline(initialHasPermission = …) 的通用配置——" +
                "请改回 ScanPipeline.forQrFrameStream(initialHasPermission = …)",
            source.contains("ScanPipeline(initialHasPermission"),
        )
    }

    // ------------------------------------------------------------------ 定位

    private fun readHostSource(): String {
        val relative = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrCameraHost.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 QrCameraHost.kt（工作目录 ${File("").absolutePath}），试过：$relative")
    }

    /** 去掉 `//` 行注释（保留换行）：注释里写旧写法不算复发。 */
    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }
}
