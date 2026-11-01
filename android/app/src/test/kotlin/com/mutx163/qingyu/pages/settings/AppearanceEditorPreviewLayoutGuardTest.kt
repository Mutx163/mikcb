package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 外观编辑页**预览卡片的缩放布局**守卫。
 *
 * ## 它守的是什么（2026-11-01 真机事故）
 *
 * 预览区本该显示「整个首页按比例缩小」，真机上却只显示整页的**右下角一块**：
 * 标题行、星期栏、时间列、左边几列全被裁掉，「回本周」浮钮跑到卡片左半边。
 *
 * 根因不是算术，是 `Modifier.requiredSize(整屏)` 的语义：整屏页面比卡片大，
 * Compose 遇到「内容超出父约束」时会**把上报尺寸收缩到父约束、并把超出的内容居中**
 * （`Placeable.apparentToRealOffset`）。居中量 = (卡片 − 整屏) / 2，而卡片本身
 * 就是居中于屏幕的 —— 两者相消后页面左上角落回**屏幕**左上角，卡片这个窗口只剩
 * 页面右下角。见 `AppearanceEditorPreviewStage.fullScreenPageScaled` 的注释。
 *
 * ## 为什么读源码文本
 *
 * 修法是 `Modifier.layout { … place(0, 0) }` 这种**布局写法**，编译产物与反射都看不到；
 * 而 `composeP1` 不挂 `src/test` 的编译类路径（与 `SettingsHostIntentWiringGuardTest`
 * 同一套做法）。找不到文件**判失败而不是跳过**。
 */
class AppearanceEditorPreviewLayoutGuardTest {

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

    private fun previewStageSource(): String {
        val stage = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/AppearanceEditorPreviewStage.kt",
        )
        assertTrue("AppearanceEditorPreviewStage.kt 不存在：${stage.path}", stage.isFile)
        return stage.readText()
    }

    /**
     * 去掉注释再判：修法本身要在 KDoc 里写「不许用 `requiredSize`」，
     * 直接搜原文会把这句说明当成违规调用（本守卫自己踩过一次）。
     */
    private fun codeOf(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .replace(Regex("""//[^\n]*"""), "")

    @Test
    fun `整屏预览页不许用 requiredSize`() {
        val source = codeOf(previewStageSource())
        assertFalse(
            "预览舞台里出现 `requiredSize`：整屏页比卡片大，Compose 会把超出内容居中，" +
                "预览只剩整页右下角一块。改用 fullScreenPageScaled（layout + place(0, 0)）",
            "requiredSize(" in source,
        )
    }

    @Test
    fun `整屏预览页必须固定约束排版并钉在左上角`() {
        val source = codeOf(previewStageSource())
        assertTrue(
            "页面必须按固定整屏约束排版（不另排一套小屏布局）",
            "Constraints.fixed(" in source,
        )
        assertTrue(
            "页面必须显式钉在父容器左上角；位置一旦交给 Compose 的越界居中就会重新出现裁切",
            "place(0, 0)" in source,
        )
        assertTrue(
            "缩放必须绕左上角，否则缩小后的页面会从卡片中间开始画",
            "transformOrigin = TransformOrigin(0f, 0f)" in source,
        )
    }
}
