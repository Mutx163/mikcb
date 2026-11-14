package com.mutx163.qingyu.architecture

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 网络层**架构守卫**（2026-11-14，用户定调「标准、好维护、架构优秀」那一批的落地）。
 *
 * ## 为什么必须有它（不是锦上添花）
 *
 * **L0 验证不了 `composeP1`**：`scripts/test-kotlin-module.ps1:256/302` 只收
 * `main/kotlin/.../pages/<模块>`，`composeP1` 从头到尾不进 L0 编译面（`:66` 注释写明
 * 「渲染层在 composeP1，纯 JVM 的 L0 解析不了 androidx.compose / miuix」）。也就是说，
 * 页面层的接线、import、构造点**只有 L1 才会发现**。这条守卫读的是源码文本，是 L0 上
 * 唯一能抓住「页面层偷偷绕开统一入口」的东西。
 *
 * ## 七条硬规矩（对应 Chief 批的口径）
 *
 * 1. `pages/` 下所有文件不许 `import okhttp3`（页面不直接碰传输层）；
 * 2. `pages/` 下所有文件不许手写 HTTP：`HttpURLConnection` / `openConnection(` / `ServerSocket`；
 * 3. `pages/` 下所有文件不许直接依赖 `platform.OkHttp*` 实现类——**唯一例外是组合根
 *    `pages/ShellWiring.kt`**，注入点就该在那一处；
 * 4. 全仓只许**一处** `OkHttpClient.Builder()`（`platform/QingyuHttp.kt`）；按请求改超时只许
 *    `client.newBuilder()`（OkHttp 契约：与父客户端共享连接池与 dispatcher）；
 * 5. 失败分类常量只许在 `infra/NetLog.kt` 定义（八档），别处只许引用；
 * 6. WebDAV 生产实现必须显式 `followRedirects = false`（凭据安全门在 `WebdavHttpTransport`
 *    里逐跳判定；开关漏了就是「每跳重发 Basic 凭据」）；
 * 7. `platform/OkHttp*.kt` 必须是**接口实现**（有 `override fun`）且走统一入口
 *    （引用 `QingyuHttp.`），不许自己发请求。
 *
 * ## 判据口径
 *
 * 一律 `stripKotlinComments(..., neutralizeStrings = true)` 后判：KDoc 里提到
 * `platform.OkHttp*` / `HttpURLConnection` 这些历史词**不算违规**（本仓大量注释在解释
 * 为什么不用它们），字符串里出现也不算。
 *
 * ## 咬合探针（改本文件或改网络层接线时必须做）
 *
 * 1. 往 `pages/about/AboutHttp.kt` 加 `import okhttp3.OkHttpClient` ⇒ 用例 1 红；
 * 2. 往任意 `pages/` 文件写一句 `HttpURLConnection` ⇒ 用例 2 红；
 * 3. 在 `platform/OkHttpHolidayHttp.kt` 里再建一个 `OkHttpClient.Builder()` ⇒ 用例 4 红；
 * 4. 在任意非 `infra/NetLog.kt` 文件里 `const val FAILURE_NETWORK` ⇒ 用例 5 红；
 * 5. 把 `platform/OkHttpWebdavHttpCaller.kt` 的 `followRedirects = false` 改成 `true` ⇒ 用例 6 红。
 */
class NetworkArchitectureGuardTest {

    /** 页面层：主源集 + 渲染层（后者 L0 不编译，所以更要靠这条守卫看）。 */
    private val pagesRoots = listOf(
        "android/app/src/main/kotlin/com/mutx163/qingyu/pages",
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages",
    )

    /** 组合根：构造实现类、注入接口的唯一允许之处。 */
    private val compositionRoot = "shellwiring.kt"

    private val allSourceRoots = listOf(
        "android/app/src/main/kotlin",
        "android/app/src/composeP1/kotlin",
        "android/app/src/main/assets",
    ).filter { File(repoRoot(), it).isDirectory }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(10) {
            if (File(dir, "android/app/src").isDirectory) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（android/app/src）——守卫无法验证，按失败处理")
    }

    private fun kotlinFilesUnder(relativeRoot: String): List<File> {
        val root = File(repoRoot(), relativeRoot)
        if (!root.isDirectory) return emptyList()
        return root.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .sortedBy { it.absolutePath }
            .toList()
    }

    private fun allKotlinFiles(): List<File> = allSourceRoots.flatMap { kotlinFilesUnder(it) }.distinct()

    private fun codeOf(file: File): String =
        stripKotlinComments(file.readText(), neutralizeStrings = true)

    private fun label(file: File): String =
        file.absolutePath.replace('\\', '/').substringAfter("android/app/src/")

    private fun isCompositionRoot(file: File): Boolean =
        file.name.lowercase() == compositionRoot

    @Test
    fun `页面层不许直接 import okhttp3`() {
        val offenders = mutableListOf<String>()
        var scanned = 0
        pagesRoots.forEach { root ->
            kotlinFilesUnder(root).forEach { file ->
                scanned++
                if (codeOf(file).contains("import okhttp3")) offenders += label(file)
            }
        }
        assertTrue("扫描面为空：页面层一个 .kt 都没找到，守卫会空转", scanned > 0)
        assertTrue(
            "页面层出现了 okhttp3 的 import——传输层只走统一入口 QingyuHttp，页面不该知道 okhttp 存在：$offenders",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `页面层不许手写 HTTP 连接`() {
        val forbidden = listOf("HttpURLConnection", "openConnection(", "ServerSocket")
        val offenders = mutableListOf<String>()
        var scanned = 0
        pagesRoots.forEach { root ->
            kotlinFilesUnder(root).forEach { file ->
                scanned++
                val code = codeOf(file)
                forbidden.firstOrNull { code.contains(it) }?.let { hit ->
                    offenders += "${label(file)} -> $hit"
                }
            }
        }
        assertTrue("扫描面为空：页面层一个 .kt 都没找到，守卫会空转", scanned > 0)
        assertTrue(
            "页面层出现了手写 HTTP（$offenders）：一律走 QingyuHttp；入站服务不在此列（本守卫只扫 pages/）",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `页面层不许直接依赖 platform 的 OkHttp 实现类`() {
        val offenders = mutableListOf<String>()
        var scanned = 0
        pagesRoots.forEach { root ->
            kotlinFilesUnder(root).forEach { file ->
                scanned++
                if (isCompositionRoot(file)) return@forEach
                if (codeOf(file).contains("platform.OkHttp")) offenders += label(file)
            }
        }
        assertTrue("扫描面为空：页面层一个 .kt 都没找到，守卫会空转", scanned > 0)
        assertTrue(
            "页面层直接依赖了 platform.OkHttp* 实现类（$offenders）：实现只能由组合根 ShellWiring 构造、" +
                "经接口注入；组合根本身是本条唯一例外",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `全仓只许一处 OkHttpClient_Builder`() {
        val owners = mutableListOf<String>()
        var scanned = 0
        allKotlinFiles().forEach { file ->
            scanned++
            if (codeOf(file).contains("OkHttpClient.Builder()")) owners += label(file)
        }
        assertTrue("扫描面为空：全仓一个 .kt 都没找到，守卫会空转", scanned > 0)
        assertTrue(
            "OkHttpClient.Builder() 必须只在 platform/QingyuHttp.kt 一处（实际：$owners）。" +
                "按请求改超时要用 client.newBuilder()——它与父客户端共享连接池与 dispatcher",
            owners == listOf("main/kotlin/com/mutx163/qingyu/platform/QingyuHttp.kt"),
        )
        assertSourceContains(
            codeOf(File(repoRoot(), "android/app/src/main/kotlin/com/mutx163/qingyu/platform/QingyuHttp.kt")),
            "client.newBuilder()",
            "QingyuHttp（派生客户端共享连接池）",
        )
    }

    @Test
    fun `失败分类常量只许在 infra_NetLog 定义`() {
        val names = listOf(
            "FAILURE_NETWORK",
            "FAILURE_TIMEOUT",
            "FAILURE_HTTP_STATUS",
            "FAILURE_NOT_JSON",
            "FAILURE_PARSE",
            "FAILURE_EMPTY",
            "FAILURE_CANCELLED",
            "FAILURE_TOO_LARGE",
        )
        val netLog = "main/kotlin/com/mutx163/qingyu/infra/NetLog.kt"
        val offenders = mutableListOf<String>()
        allKotlinFiles().forEach { file ->
            val code = codeOf(file)
            names.forEach { name ->
                if (code.contains("const val $name")) {
                    val where = label(file)
                    if (where != netLog) offenders += "$where -> $name"
                }
            }
        }
        assertTrue(
            "失败分类常量在 infra/NetLog.kt 之外也有定义（$offenders）：多一处定义就会漂出第二套分类",
            offenders.isEmpty(),
        )
        val netLogCode = codeOf(File(repoRoot(), "android/app/src/$netLog"))
        names.forEach { assertSourceContains(netLogCode, "const val $it", "NetLog（八档失败分类）") }
    }

    @Test
    fun `WebDAV 生产实现必须显式关闭重定向跟随`() {
        val caller = File(
            repoRoot(),
            "android/app/src/main/kotlin/com/mutx163/qingyu/platform/OkHttpWebdavHttpCaller.kt",
        )
        assertTrue("找不到 WebDAV 生产实现：${caller.path}", caller.isFile)
        val code = codeOf(caller)
        assertSourceContains(
            code,
            "followRedirects = false",
            "OkHttpWebdavHttpCaller（凭据安全门：跨 host / https→http 降级不许自动跟随）",
        )
        assertSourceLacks(
            code,
            "followRedirects = true",
            "OkHttpWebdavHttpCaller（跟随重定向会每跳重发 Basic 凭据）",
        )
    }

    @Test
    fun `platform 的 OkHttp 实现必须是接口实现且走统一入口`() {
        val dir = File(repoRoot(), "android/app/src/main/kotlin/com/mutx163/qingyu/platform")
        val impls = dir.listFiles { f -> f.isFile && f.name.startsWith("OkHttp") && f.extension == "kt" }
            ?.sortedBy { it.name }
            ?: emptyList()
        assertTrue("platform/ 里一个 OkHttp*.kt 都没找到，守卫会空转", impls.isNotEmpty())
        impls.forEach { file ->
            val code = codeOf(file)
            assertTrue(
                "${file.name} 不是接口实现（找不到 override fun）：实现类应当 implements 对应接缝",
                code.contains("override fun"),
            )
            assertTrue(
                "${file.name} 没有走统一入口（找不到 QingyuHttp.）：不许自己拿 client 发请求",
                code.contains("QingyuHttp."),
            )
        }
    }
}
