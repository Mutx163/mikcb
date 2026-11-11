package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.readSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入引导面板**步骤徽标**五语言守卫（2026-11-11 审计 P0-3）。
 *
 * 用户首屏可见的问题：`ImportCommon.kt` 的 28dp 圆徽标里放的是
 * `title.replaceFirst("步骤 ", "")`——只有中文「步骤 1」裁得掉前缀，英文 `Step 1`、
 * 日文 `ステップ1`、韩文 `단계 1`、繁中「步驟 1」都裁不掉，整串塞进 28dp 圆里溢出。
 *
 * 修法：徽标只显示**模型给的序号数字**（`number.toString()`），标题才走 ARB 模板。
 * 本守卫钉住两件事：
 * 1. 徽标不许再出现「从文案裁前缀」的写法（那是本次 bug 的成因）；
 * 2. 六份 ARB 的 `stepLabel` 必须保留 `{step}` 占位符（标题侧的序号来源）。
 *
 * 徽标是 Compose 渲染层，L0 编不到（`composeP1`），所以这里读源码判（与
 * `WarehouseWebLoginHostWiringGuardTest` 同款做法）。
 */
class ImportGuideStepBadgeGuardTest {

    // 必须剥注释再判：本类说明里就写着旧写法 `replaceFirst("步骤 ", "")`，
    // 不剥注释的判据会被这句说明自己弄红（同款坑见 testutil/SourceText.kt 的 KDoc）。
    private val importCommon by lazy {
        readKotlinSourceNormalized(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/ImportCommon.kt",
        )
    }

    @Test
    fun `步骤徽标只显示序号数字 不许再从本地化标题裁前缀`() {
        assertFalse(
            "徽标不许再用 replaceFirst(\"步骤 …\") 裁前缀：非中文语言裁不掉，整串会把 28dp 圆撑破",
            importCommon.contains("replaceFirst(\"步骤"),
        )
        assertTrue(
            "引导行必须接收序号参数（ImportGuideLine(number = …)），徽标显示这个数字",
            importCommon.contains("ImportGuideLine(number ="),
        )
        assertTrue(
            "徽标文案必须是 number.toString()（纯数字，与语言无关）",
            importCommon.contains("text = number.toString(),"),
        )
    }

    @Test
    fun `六份 ARB 的 stepLabel 都必须保留 step 占位符`() {
        val files = listOf(
            "app_zh.arb",
            "app_zh_HK.arb",
            "app_zh_TW.arb",
            "app_en.arb",
            "app_ja.arb",
            "app_ko.arb",
        )
        for (name in files) {
            val text = readSourceNormalized("i18n/$name")
            val line = text.lineSequence().firstOrNull { it.contains("\"stepLabel\":") }
            assertTrue("$name 缺少 stepLabel", line != null)
            assertTrue(
                "$name 的 stepLabel 必须含 {step} 占位符（标题侧序号靠它填）",
                line!!.contains("{step}"),
            )
        }
    }
}
