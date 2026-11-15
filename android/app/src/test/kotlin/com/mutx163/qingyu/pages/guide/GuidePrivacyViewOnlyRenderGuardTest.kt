package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Test

/**
 * 「用户指南复看页那两句说明必须有生产渲染点」的源码守卫（2026-11-15）。
 *
 * ## 背景
 *
 * `guidePrivacyViewOnly` / `guidePrivacyHelperViewOnly` 两条 ARB 六语早就备好了，但在
 * `6a2353edf` 之前**全仓零渲染**——只在字符串表里躺着。从设置进指南页是「复看」模式，
 * 用户容易以为又要重新勾一次同意；这两句正是回答那个疑问的（「本页只做查看，不会再采集
 * 同意」）。文案存在但没人渲染，等于这句解释不存在。
 *
 * ## 判据
 *
 * 1. 两句都**真的渲染**：`.text` 分别传进 `GuideGroupTitle` / `GuideParagraph`；
 * 2. 渲染点在**复看模式分支**里（`if (!requireConsent)` 之后、`item(key = "viewOnlyNote")`
 *    这个卡片里）——放进别处等于首启也显示，文案就变成误导。
 *
 * 档位：中性化档。判的是「有没有这处调用」，注释里解释历史不算数，字符串内容也无关；
 * 用默认档反而会被这两条的 ARB 文案本身满足（`.text` 里的字面量），变成假绿。
 */
class GuidePrivacyViewOnlyRenderGuardTest {

    private val page = readKotlinSourceNoStrings(USER_GUIDE_PAGE)

    /** 判字符串字面量（卡片 key）用默认档：中性化档会把引号里的内容抹成空格。 */
    private val pageWithStrings = readKotlinSourceNormalized(USER_GUIDE_PAGE)

    @Test
    fun `复看两句都有生产渲染点`() {
        assertSourceContains(page, "GuideGroupTitle(GuideStrings.guidePrivacyViewOnly.text", USER_GUIDE_PAGE)
        assertSourceContains(
            page,
            "GuideParagraph(GuideStrings.guidePrivacyHelperViewOnly.text",
            USER_GUIDE_PAGE,
        )
    }

    @Test
    fun `复看两句渲染在不需要再次同意的分支里`() {
        // 结构锚：卡片 key 一旦改名，这条会红，提醒重新确认位置。
        assertSourceContains(pageWithStrings, "item(key = \"viewOnlyNote\")", USER_GUIDE_PAGE)
        val index = page.indexOf("GuideGroupTitle(GuideStrings.guidePrivacyViewOnly.text")
        check(index >= 0) { "找不到渲染点：$USER_GUIDE_PAGE" }
        // 往前 1200 字符内必须能看到「不需要同意」的判断，否则可能被挪去了首启分支。
        val before = page.substring(maxOf(0, index - 1200), index)
        assertSourceContains(before, "if (!requireConsent)", "$USER_GUIDE_PAGE 的 viewOnlyNote 之前 1200 字符")
    }

    private companion object {
        const val USER_GUIDE_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt"
    }
}
