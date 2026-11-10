package com.mutx163.qingyu.pages.import.warehouse

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 选校页「搜索 / 最近使用 / 返回滚动位置」接线守卫（2026-11-10 修复批）。
 *
 * 这一批修的都是**穿过文件边界**的接线，JVM 单测驱动不了 Compose，只能把
 * 「宿主必须把哪个值传给页面」钉在源码上：
 *
 * 1. **适配器名搜索**：`adapterMatches` 必须是搜索索引按当前关键词算出来的结果，
 *    不许再写死 `emptyMap()`（写死 = 按脚本名永远搜不到，2026-11-10 审核差异）；
 * 2. **最近使用**：点学校只写本条目的 `WarehouseShellState`，不许在这里记「最近使用」
 *    （发布版是导入落库成功后写，`warehouse_adapter_web_login_screen.dart:2504`）；
 * 3. **滚动位置**：列表的 `LazyListState` 必须由宿主持有并传给页面，页面再交给
 *    `QingyuPageList`——点学校是本条目内换页，页面内的 `rememberLazyListState` 会清零。
 *
 * 判据全是「源码里必须有 / 不许有」，所以断言串都带足够的上下文，别宽到
 * 注释里出现一次就误判。
 */
class WarehouseSchoolSearchWiringGuardTest {

    private val hostSource: String by lazy {
        relativeSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/" +
                "WarehouseImportHosts.kt",
        ).readText(Charsets.UTF_8)
    }

    private val pageSource: String by lazy {
        relativeSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/" +
                "WarehouseCourseImportPage.kt",
        ).readText(Charsets.UTF_8)
    }

    @Test
    fun `适配器名搜索必须接真索引 不许再写死空表`() {
        assertTrue(
            "选校页没有拉取搜索索引：按适配器（脚本）名仍然搜不到。",
            hostSource.contains("loadWarehouseSearchIndex(fetch, fetchOptions)"),
        )
        assertTrue(
            "搜索索引命中的适配器名必须经 adapterMatches 交给页面。",
            hostSource.contains("adapterMatches = adapterMatches"),
        )
        assertFalse(
            "adapterMatches 不许再写死 emptyMap()（那会让适配器名搜索恒为空）。",
            hostSource.contains("adapterMatches = emptyMap()"),
        )
        assertTrue(
            "页面必须消费 adapterMatches（过滤 + 副标题回显），否则宿主算了也白算。",
            pageSource.contains("adapterMatches[bean.school.id]"),
        )
    }

    @Test
    fun `点学校不许再写最近使用 写入点在导入成功之后`() {
        val start = hostSource.indexOf("onSelectSchool = {")
        assertTrue("选校页里找不到 onSelectSchool（守卫自身失效）", start >= 0)
        val end = hostSource.indexOf("onQuickImportClick", start)
        assertTrue("找不到 onSelectSchool 的结尾边界（守卫自身失效）", end > start)
        val block = hostSource.substring(start, end)

        assertTrue(
            "点学校必须把学校写进本条目的 state（本条目内换成适配器列表靠它）。",
            block.contains("state.school = school"),
        )
        assertFalse(
            "不许在点学校时写「最近使用」：发布版是导入落库成功后 addRecentSchool，\n" +
                "点一下（哪怕没导入就返回）都记会让 ★ 组的含义从「最近导入」变成「最近点过」。",
            block.contains("recordRecentSchool"),
        )
    }

    @Test
    fun `返回列表要保留滚动位置 宿主与页面必须共用同一个 LazyListState`() {
        assertTrue(
            "宿主必须持有选校列表的 LazyListState（页面内的 remember 活不过内联换页）。",
            hostSource.contains("val schoolListState = rememberLazyListState()"),
        )
        assertTrue(
            "宿主要把 LazyListState 传给页面。",
            hostSource.contains("listState = schoolListState"),
        )
        assertTrue(
            "页面必须接收 listState 参数（默认值只给预览用）。",
            pageSource.contains("listState: LazyListState"),
        )
        assertTrue(
            "页面的 QingyuPageList 必须吃宿主给的 state，否则滚动位置仍然丢。",
            pageSource.contains("state = listState"),
        )
    }

    private fun relativeSource(relative: String): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate
            dir = dir?.parentFile
        }
        throw AssertionError("找不到源文件：$relative（工作目录=${File("").absolutePath}）")
    }
}
