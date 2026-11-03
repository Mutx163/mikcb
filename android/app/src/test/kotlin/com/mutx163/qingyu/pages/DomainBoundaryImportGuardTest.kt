package com.mutx163.qingyu.pages

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **域边界守卫**：`pages/<域>` 的源码（main 与 test）不许 import 另一个页面域的类型。
 *
 * ## 防的是哪一类事故
 *
 * L0 轻量单测（`scripts/test-kotlin-module.ps1`）的编译范围 = 本域 main + test +
 * 共享层（`app/core/.../weather/` 等顶层目录），**不包含其它页面域**。某域的文件一旦
 * `import com.mutx163.qingyu.pages.<别的域>.*`，该域的 L0 离开 `-ExtraSources` 就编不过
 * ——「每域能独立自测」的设计就废了。2026-11-03 之前 `pages/timetable`（反向引用
 * settings / weather）与 `pages/guide`（测试引用 shell）就是这么坏的。
 *
 * ## 规则
 *
 * * 允许：本域类型、共享层（凡不带 `pages.` 前缀的 `com.mutx163.qingyu.*` 都放行
 *   ——共享层的纯度由 L0 脚本自身的 Android 依赖过滤保证，这里不重复判）；
 * * 允许：`pages/` 根的**壳装配层**（`ShellPageIndex` / `ShellWiring` /
 *   `PagesShellActivity` 等，不在任何域子目录里）——组装所有域是它的职责；
 * * 禁止：域目录（main 或 test）里出现跨域 `import com.mutx163.qingyu.pages.<其它域>.*`。
 *
 * ## 共享逻辑该往哪去
 *
 * 被 ≥2 个域用的纯数据 / 纯逻辑下沉共享层（`core/`、`weather/` 等），别复制；
 * 只有一个域用、测试顺手借了别域类型的，改测试自己构造数据。拿不准时看本守卫红不红。
 */
class DomainBoundaryImportGuardTest {

    @Test
    fun `域源码不引用其它页面域的类型`() {
        val violations = scannedFiles()
            .flatMap { (side, file, domain) -> crossDomainImports(side, file, domain) }
        assertTrue(
            "发现跨域 import（会把本域 L0 的独立编译打破）：\n" +
                violations.joinToString("\n") { "  $it" },
            violations.isEmpty(),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        val files = scannedFiles()
        val domains = files.map { it.third }.toSet()
        assertTrue("扫描到的域源码太少（${files.size} 个），路径可能不对", files.size >= 100)
        assertTrue("扫描到的域太少（${domains.size} 个）：${domains.sorted()}", domains.size >= 15)
    }

    // ------------------------------------------------------------------ 扫描

    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        repeat(8) {
            if (File(dir, "android/app/src").isDirectory) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（android/app/src），工作目录：${System.getProperty("user.dir")}")
    }

    /** (main/test, 文件, 所属域) 的全量清单；pages 根的壳装配层文件（无域）不参与判定。 */
    private fun scannedFiles(): List<Triple<String, File, String>> {
        val root = repoRoot()
        val out = mutableListOf<Triple<String, File, String>>()
        for (side in listOf("main", "test")) {
            val pagesDir = File(
                root,
                "android/app/src/$side/kotlin/com/mutx163/qingyu/pages",
            )
            if (!pagesDir.isDirectory) continue
            pagesDir.listFiles { f -> f.isDirectory }?.sortedBy { it.name }?.forEach { domainDir ->
                domainDir.walkTopDown()
                    .filter { it.isFile && it.extension == "kt" }
                    .forEach { out += Triple(side, it, domainDir.name) }
            }
        }
        return out
    }

    /** 一个文件里违反域边界的 import 行（`侧/域名/文件:行号 -> import 语句`）。 */
    private fun crossDomainImports(side: String, file: File, ownDomain: String): List<String> {
        val found = mutableListOf<String>()
        file.readLines().forEachIndexed { index, line ->
            val match = CROSS_DOMAIN_IMPORT.find(line) ?: return@forEachIndexed
            val refDomain = match.groupValues[1]
            if (refDomain != ownDomain) {
                found += "$side/$ownDomain/${file.name}:${index + 1} -> ${line.trim()}"
            }
        }
        return found
    }

    private companion object {
        /** `import com.mutx163.qingyu.pages.<域>.*`（含通配与 as 别名）。 */
        val CROSS_DOMAIN_IMPORT =
            Regex("""^\s*import\s+com\.mutx163\.qingyu\.pages\.([A-Za-z0-9_]+)\.""")
    }
}
