package com.mutx163.qingyu.pages.timetable

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 周视图情侣叠加的**接线守卫**（B1 第二阶段，2026-11-06）。
 *
 * 这一族的 bug 高发点不是算法，而是「模型写好了、渲染层/宿主没接上」——
 * 一阶段日视图就靠类似的接线守卫兜住。这里逐环钉住，任何一环被删/被绕都立刻红：
 * 1. 宿主把 overlay 读出来并传给页面（`CoupleOverlaySource.load` + `coupleOverlay = coupleOverlay`）；
 * 2. 页面在有 overlay 时走叠加合并内核（`cardsForWeekWithCoupleOverlay`）；
 * 3. 合并内核给对方的课打 `isPartnerCourse = true`；
 * 4. 渲染层据 `model.isPartnerCourse` 画「TA的课」角标（复用日视图同一枚文案）；
 * 5. 数据源不反向依赖 `pages/sync`（否则 timetable 的 L0 会被 sync 在途改动连锁拖红）。
 */
class WeekViewCoupleOverlayWiringGuardTest {

    @Test
    fun `宿主必须读出 overlay 并传给页面`() {
        val host = read("android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt")
        assertTrue(
            "宿主必须用 CoupleOverlaySource 读叠加数据",
            host.contains("CoupleOverlaySource.load(repository)"),
        )
        assertTrue(
            "宿主必须把 overlay 传给 TimetableWeekPage",
            host.contains("coupleOverlay = coupleOverlay"),
        )
        assertTrue(
            "宿主必须带 coupleOverlayRevision 重读叠加数据",
            host.contains("coupleOverlayRevision"),
        )
    }

    @Test
    fun `页面在有 overlay 时必须走叠加合并内核`() {
        val page = read(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt",
        )
        assertTrue(
            "页面必须在 overlay 非空时调用 cardsForWeekWithCoupleOverlay",
            page.contains("cardsForWeekWithCoupleOverlay"),
        )
        assertTrue(
            "页面必须把 coupleOverlay 透传给 WeekPageContent",
            page.contains("coupleOverlay = coupleOverlay"),
        )
    }

    @Test
    fun `合并内核必须给对方的课打 TA 标记`() {
        val mapping = read(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/WeekGridCourseMapping.kt",
        )
        assertTrue(
            "合并内核必须把对方的课标 isPartnerCourse = true",
            mapping.contains("isPartnerCourse = true"),
        )
        assertTrue(
            "WeekCardModel 必须带 isPartnerCourse 字段",
            mapping.contains("val isPartnerCourse: Boolean = false"),
        )
    }

    @Test
    fun `渲染层必须据 TA 标记画角标`() {
        val card = read(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/CourseGridCard.kt",
        )
        assertTrue(
            "课卡必须读 model.isPartnerCourse",
            card.contains("model.isPartnerCourse"),
        )
        assertTrue(
            "课卡必须画「TA的课」角标（复用日视图同一枚文案）",
            card.contains("coupleTimetableLegendPartner"),
        )
    }

    @Test
    fun `叠加数据源不得反向依赖 pages-sync`() {
        val source = read(
            "android/app/src/main/kotlin/com/mutx163/qingyu/widgetdata/CoupleOverlaySource.kt",
        )
        assertFalse(
            "CoupleOverlaySource 一旦 import pages.sync，timetable 的 L0 会被 sync 在途改动连锁拖红",
            source.contains("import com.mutx163.qingyu.pages.sync"),
        )
    }

    // ---------------------------------------------------------------- 工具

    private fun read(relativePath: String): String {
        val file = File(repoRoot(), relativePath)
        check(file.isFile) { "找不到 $relativePath" }
        return file.readText(Charsets.UTF_8)
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "android/app/src/composeP1").isDirectory) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（工作目录 ${File("").absolutePath}）")
    }
}
