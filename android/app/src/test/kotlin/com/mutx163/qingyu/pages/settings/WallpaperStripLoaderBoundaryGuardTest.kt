package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Test

/**
 * 「壁纸条**不**接图片加载器」的源码守卫（2026-11-15，第 3 段「图片加载换 Coil」）。
 *
 * ## 为什么需要这条守卫
 *
 * 第 3 段原来的验收句写的是「Bing 缩略图与壁纸条两个消费点接线完成」。核实下来这句话不成立：
 * 壁纸条的条目键是**本地绝对路径**（最近使用的壁纸文件），而 `platform/AndroidImageLoader`
 * 只吃 http(s) URL。所以壁纸条按设计就该走本地解码，接线反而是错的。
 *
 * 验收句已订正成「经核实不接线，须有注释说明且**不得回退**到 loader」。后半个要求如果只
 * 存在注释里，下一个人看到 `load(url, w, h) { … }` 这个封装很顺手就会接上去——接上之后的
 * 症状是**把本地路径当 URL 去请求**，整条壁纸条退成占位图，而且只有真机才看得见（JVM 单测
 * 抓不到）。所以把「不许接线」写成判据。
 *
 * ## 档位：中性化档（选错会误红）
 *
 * 判据是「这个文件里不许出现对 loader 的**引用**」，属于接线类，所以用
 * [readKotlinSourceNoStrings]（剥注释 + 抹掉字符串内容）。
 *
 * 用默认档会**误红**：`RecentWallpaperStrip.kt:468` 与 `:472` 的注释正在解释「为什么本地缩略图
 * 不走它」，那两处 `AndroidImageLoader` 是说明文字，不是引用；默认档把它们当命中，等于逼人
 * 删掉最有价值的说明。字符串内容一并抹掉，是因为日志 / 提示语里出现这个名字也不算接线。
 *
 * ## 否定式断言
 *
 * 走 [assertSourceLacks]：它**先判非空再判缺席**，读不到源码时直接红。手写
 * `assertFalse(source.contains(...))` 一旦路径变了就是空串恒真——本仓 2026-11-12 审计里
 * 踩过这个坑（见 `testutil/SourceAssertions.kt` 的 KDoc）。
 */
class WallpaperStripLoaderBoundaryGuardTest {

    /** 中性化档：注释与字符串内容都被抹掉，只剩代码骨架。 */
    private val source = readKotlinSourceNoStrings(STRIP_PATH)

    @Test
    fun `壁纸条读得到 且仍然走本地文件解码`() {
        // 正向锚点：先证明读到的确实是那份实现，下面那条否定式断言才不会在空读上恒真。
        assertSourceContains(source, "fun rememberWallpaperThumb", STRIP_PATH)
        assertSourceContains(source, "fun decodeLocalThumbnail", STRIP_PATH)
        assertSourceContains(source, "BitmapFactory.decodeFile", STRIP_PATH)
        assertSourceContains(source, "ImageSizeSelector.inSampleSize", STRIP_PATH)
    }

    @Test
    fun `壁纸条不得引用 AndroidImageLoader`() {
        assertSourceLacks(source, "AndroidImageLoader", STRIP_PATH)
    }

    private companion object {
        /**
         * 壁纸条的实现文件（`pages/settings` 的页面代码在 composeP1 源集里）。
         *
         * 路径写死而不是搜索：守卫要钉的**就是这一份**文件；搜索式定位一旦有人新增同名文件，
         * 判据会悄悄换对象。
         */
        const val STRIP_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/RecentWallpaperStrip.kt"
    }
}
