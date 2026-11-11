package com.mutx163.qingyu.testutil

/**
 * 源码**作用域切片**（2026-11-11 评审 T-04）。
 *
 * ## 为什么需要它
 *
 * 守卫里最常见的假绿是「在整份文件里 `contains`」：断言「宿主必须传 `onRequestQrSend`」，
 * 结果宿主文件**别的页面**也提到了这个符号，判据照样绿；反过来「某函数里不许出现 X」，
 * 文件里别处有 X 就假红。评审三在 T-04 里给的统一建议就是**先切出判据所在的作用域**
 * （函数 / 分支 / 弹层主体），再在切片里断言。
 *
 * 与 `SourceText.kt` 的分工：那边负责「读 + 剥注释 / 中性化字符串」，这边只做**纯文本切片**，
 * 不读文件、不碰注释——所以可以先剥后切，也可以先切后剥，两边互不依赖。
 */
object SourceSlice {

    /**
     * 取 [source] 里 [startMarker] 到其后第一个 [endMarker] 之间的内容（**含 startMarker、
     * 不含 endMarker**）。
     *
     * @param endMarker 为 null 时取到文件末尾
     * @throws IllegalStateException 找不到标记（守卫不许静默跳过：锚点失效必须红）
     */
    fun between(source: String, startMarker: String, endMarker: String? = null): String {
        val start = source.indexOf(startMarker)
        check(start >= 0) { "源码里找不到切片起点 `$startMarker`（锚点失效，请同步守卫）" }
        if (endMarker == null) return source.substring(start)
        val end = source.indexOf(endMarker, start + startMarker.length)
        check(end >= 0) { "源码里找不到切片终点 `$endMarker`（锚点失效，请同步守卫）" }
        return source.substring(start, end)
    }

    /**
     * 取以 [signatureMarker] 开头的那个函数的**函数体**（从签名后的第一个 `{` 到配对的 `}`，
     * 花括号按深度配平，字符串里的花括号不特殊处理——源码切片的对象是已剥注释的代码）。
     *
     * @throws IllegalStateException 找不到签名或括号不闭合
     */
    fun functionBody(source: String, signatureMarker: String): String {
        val start = source.indexOf(signatureMarker)
        check(start >= 0) { "源码里找不到函数签名 `$signatureMarker`（锚点失效，请同步守卫）" }
        val open = source.indexOf('{', start + signatureMarker.length)
        check(open >= 0) { "`$signatureMarker` 之后没有 `{`" }
        var depth = 0
        var index = open
        while (index < source.length) {
            when (source[index]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(open, index + 1)
                }
            }
            index++
        }
        error("`$signatureMarker` 的括号没有闭合")
    }
}
