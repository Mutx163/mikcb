package com.mutx163.qingyu.testutil

// 接管（美化十二 SCNet 停机，Chief 授权 11-11）：本文件由美化十三补到可编译；
// 实现与 API 不改，只修一处「KDoc 里写了裸的块注释起始符 ⇒ Kotlin 当成嵌套注释、
// 整份文件收不了尾」的语法错。P6-G2 的任务所有权仍归美化十二。
//
// 2026-11-11（美化十二，P6-G2）：补上 neutralizeStrings 的实现。此前该参数被接收却
// 从未参与判断，导致 readKotlinSourceNoStrings(...) 与 readKotlinSourceNormalized(...)
// 行为完全一样（字符串内容没被抹掉）——与下方 KDoc 承诺的「接线类判据用中性化档」不符。
// 现在字符串 / 原始字符串 / 字符字面量的**内容**换成空格，定界符与换行保留；
// 默认档（neutralizeStrings = false）输出逐字节不变。

import java.io.File

/**
 * 读仓库内源码并**归一行尾**（`\r\n` → `\n`）。
 *
 * ## 为什么需要它
 *
 * 本仓 `core.autocrlf=true` + `.gitattributes * text=auto`：索引里是 LF、工作区检出是 CRLF
 * （`git ls-files --eol` 显示 `i/lf w/crlf` 属**正常态**，不许手工把整文件改回 LF）。
 * 守卫若直接 `readText()` 再拿含换行的字面量（跨行锚点、找 `"\n\n"` 空行切函数体），
 * 就会在工作区假红、在干净检出又变绿——最典型的「以后随机红」雷。
 *
 * ## 用法
 *
 * **新守卫一律用它**；138 个已免疫的老守卫不改（判据长到哪改到哪，不搞全仓大迁移）。
 *
 * @param repoRelativePath 相对仓库根的路径，例如
 *   `android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt`
 * @throws IllegalStateException 找不到文件（守卫不许静默跳过）
 */
fun readSourceNormalized(repoRelativePath: String): String {
    var dir: File? = File("").absoluteFile
    repeat(10) {
        dir?.let { current ->
            val candidate = File(current, repoRelativePath)
            if (candidate.isFile) {
                return candidate.readText(Charsets.UTF_8).replace("\r\n", "\n")
            }
        }
        dir = dir?.parentFile
    }
    error("找不到 $repoRelativePath（工作目录 ${File("").absolutePath}）")
}

/**
 * 读一个 `.kt` 源码并按 [stripKotlinComments] 剥掉注释（**保留字符串内容**）。
 *
 * 适用：形态/常量类判据——比如「某个字符串字面量不许再出现」「某个常量是 16」。
 * 字符串必须留着，否则判据会把要抓的字面量自己擦掉。
 *
 * **读源码做 `contains(...)` 判据的守卫一律用它**（或自己 `readText` 后显式过
 * [stripKotlinComments]）——不剥注释的判据会被「把目标行注释掉」静默骗绿：
 * 2026-11-10 仓库域实弹发生过已提交接线被注释掉、判据照样通过的事故（J4 守卫抓到），
 * 所以这条现在是硬性口径：**注释掉的接线不算接线**。
 */
fun readKotlinSourceNormalized(repoRelativePath: String): String =
    stripKotlinComments(readSourceNormalized(repoRelativePath))

/**
 * 读一个 `.kt` 源码，先把注释剥掉，**再把字符串 / 字符字面量的内容中性化**（换成空格）。
 *
 * 适用：**接线 / 挂载类判据**——判断「这里必须调用 / 必须挂载 / 不许出现某调用」。
 * 这类判据要的是**代码结构**，不是文案：生产代码里只要有一句含同样片段的字符串
 * （日志、提示语、KDoc 里的示例），`contains` 就会被它满足而假绿。中性化后只剩真实代码骨架。
 *
 * 不用它的时候：判据本身就是「某字面量许不许出现」时，必须走 [readKotlinSourceNormalized]。
 */
fun readKotlinSourceNoStrings(repoRelativePath: String): String =
    stripKotlinComments(readSourceNormalized(repoRelativePath), neutralizeStrings = true)

/**
 * 剥掉 Kotlin 源码里的注释；[neutralizeStrings] 为 true 时**连字符串内容一起换成空格**。
 *
 * ## 两档模式（怎么选）
 *
 * | 模式 | 注释 | 字符串内容 | 用在 |
 * |---|---|---|---|
 * | 默认 | 剥 | **保留** | 形态 / 常量 /「某字面量许不许出现」类判据 |
 * | `neutralizeStrings = true` | 剥 | **抹成空格** | 接线 / 挂载 /「必须调用某函数」类判据 |
 *
 * ## 判据（2026-11-10 守卫加固批 P6-G2）
 *
 * - **行注释** `// …` 到行尾（换行保留，便于按行断言）；
 * - **块注释** `/* … */`，**支持 Kotlin 的嵌套块注释**（深度计数，`/* /* */ */` 整体剥掉）；
 * - **字符串字面量** `"…"`：转义 `\"` / `\\` 正确跳过，**字符串里的 `//`、块注释起始符
 *   不许当注释**（这里刻意不写出那两个字面字符：Kotlin 的 KDoc 是块注释，写了裸的
 *   起始符会被当成嵌套注释，整份文件收不了尾——本文件 11-11 就是这么断的）；
 * - **原始字符串** `"""…"""`：整体识别，里面出现 `//` 或 `"` 也不切换状态（旧实现会在
 *   第一个 `"` 处误判退出，导致后续真实代码被当成字符串、注释漏剥）；
 * - **字符字面量** `'x'`：与字符串同档处理（`'\''` 这类转义不误判）。
 *
 * 剥离只把注释/字符串内容换成空格（换行保留），**行数与列位置不变**——守卫报错时行号还能用。
 *
 * ## 已知不覆盖（**故意的边界，别当 bug 修**，有自测钉着）
 *
 * - **`${…}` 插值里再嵌引号**：如 `"${map["k"]}"`。状态机按「第一个未转义引号收尾」处理，
 *   嵌在插值里的引号会让它提前退出一个字符串状态。Kotlin 里这种写法本身要靠转义或
 *   `'` 才能编译，实际源码极少；真要支持得写完整的插值解析，收益远小于复杂度。
 * - **原始字符串以多于三个引号收尾**：如 `"""a""""`（内容含一个引号）。状态机在第一个
 *   `"""` 处收尾，后面那个引号会被当成新字符串开头。同上，属于可读性可接受的边界。
 *
 * 这两种情形一旦影响判据，宁可**在守卫里换一种锚点**（锚到结构而不是那句话），
 * 不要为此把状态机改复杂。
 *
 * ## 为什么放 testutil 而不是各守卫自带一份
 *
 * 每份守卫自带一份剥离器时，实现强弱不一（本仓最全那份是
 * `WarehouseWebLoginHostWiringGuardTest` 的私有函数），新守卫抄旧守卫就会抄到弱版本。
 * 现在统一到这里 + 元检查守卫（`pages/sheetguard/GuardSourceStrippingPolicyTest`）盯着
 * 「读 .kt 做 contains 却没剥注释」的新守卫。
 */
fun stripKotlinComments(source: String, neutralizeStrings: Boolean = false): String {
    val sb = StringBuilder(source.length)
    var i = 0
    var inLineComment = false
    var inBlockComment = false
    var blockDepth = 0
    var stringQuote: Char? = null
    var inRawString = false
    while (i < source.length) {
        val ch = source[i]
        val next = if (i + 1 < source.length) source[i + 1] else ' '
        val third = if (i + 2 < source.length) source[i + 2] else ' '
        when {
            inLineComment -> {
                if (ch == '\n') {
                    inLineComment = false
                    sb.append(ch)
                }
                i++
            }
            inBlockComment -> {
                if (ch == '/' && next == '*') {
                    blockDepth++
                    i += 2
                } else if (ch == '*' && next == '/') {
                    blockDepth--
                    i += 2
                    if (blockDepth == 0) inBlockComment = false
                } else {
                    if (ch == '\n') sb.append(ch)
                    i++
                }
            }
            inRawString -> {
                if (ch == '"' && next == '"' && third == '"') {
                    sb.append("\"\"\"")
                    inRawString = false
                    i += 3
                } else {
                    when {
                        !neutralizeStrings -> sb.append(ch)
                        ch == '\n' -> sb.append(ch)
                        else -> sb.append(' ')
                    }
                    i++
                }
            }
            stringQuote != null -> {
                if (ch == '\\' && i + 1 < source.length) {
                    // 转义序列整体消费；中性化时连它一起换成空格（行续接的换行要留着）。
                    val escaped = source[i + 1]
                    if (neutralizeStrings) {
                        sb.append(' ')
                        sb.append(if (escaped == '\n') '\n' else ' ')
                    } else {
                        sb.append(ch)
                        sb.append(escaped)
                    }
                    i += 2
                } else {
                    val closing = ch == stringQuote
                    when {
                        !neutralizeStrings -> sb.append(ch)
                        // 引号定界符保留（结构还能看出来），内容换空格；换行保留以维持行号。
                        closing -> sb.append(ch)
                        ch == '\n' -> sb.append(ch)
                        else -> sb.append(' ')
                    }
                    if (closing) stringQuote = null
                    i++
                }
            }
            ch == '/' && next == '/' -> {
                inLineComment = true
                sb.append(' ')
                i += 2
            }
            ch == '/' && next == '*' -> {
                inBlockComment = true
                blockDepth = 1
                sb.append(' ')
                i += 2
            }
            ch == '"' && next == '"' && third == '"' -> {
                inRawString = true
                sb.append("\"\"\"")
                i += 3
            }
            ch == '"' || ch == '\'' -> {
                stringQuote = ch
                sb.append(ch)
                i++
            }
            else -> {
                sb.append(ch)
                i++
            }
        }
    }
    return sb.toString()
}
