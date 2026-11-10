package com.mutx163.qingyu.testutil

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
