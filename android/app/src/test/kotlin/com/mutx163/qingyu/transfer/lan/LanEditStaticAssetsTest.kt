package com.mutx163.qingyu.transfer.lan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 局域网编辑控制台的静态资源分发测试。
 *
 * 期望值从 Dart 手推（`lib/services/lan_edit_server_service.dart`）：
 * - 路径表：`_mapAssetPath`（:225-253）九个键；
 * - `Content-Type`：`_contentTypeFor`（:256-272）；
 * - 响应头：`_serveStatic`（:200-217）——`no-store` / CSP / `nosniff`；
 * - 缺资源与未知路径都是 404。
 *
 * 另外两条**与 Dart 源对照**的用例：映射表与 CSP 字符串改错在 Kotlin 侧完全看不出来，
 * 只有真机打开浏览器才知道（而真机对照归用户），所以用读源码做子串比对挡在提交前。
 */
class LanEditStaticAssetsTest {

    private val dartSource: String by lazy {
        repoFile("lib/services/lan_edit_server_service.dart").readText()
    }

    private val fallback = LanEditStaticAssets { null }

    private fun repoFile(relative: String): File {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.exists()) return candidate
            dir = dir.parentFile
        }
        throw AssertionError("从工作目录找不到 $relative")
    }

    // ── 1. 路径表 ──

    @Test
    fun `根路径与 index 都指向控制台首页`() {
        assertEquals("assets/lan_edit/index.html", fallback.mapAssetPath("/"))
        assertEquals("assets/lan_edit/index.html", fallback.mapAssetPath("/index.html"))
    }

    @Test
    fun `脚本与样式按 Dart 的表映射`() {
        assertEquals("assets/lan_edit/app.js", fallback.mapAssetPath("/assets/app.js"))
        assertEquals("assets/lan_edit/i18n.js", fallback.mapAssetPath("/assets/i18n.js"))
        // 两个样式路径指向同一个文件（Dart 里 style.css 是历史别名）
        assertEquals("assets/lan_edit/lan-timetable.css", fallback.mapAssetPath("/assets/style.css"))
        assertEquals(
            "assets/lan_edit/lan-timetable.css",
            fallback.mapAssetPath("/assets/lan-timetable.css"),
        )
        assertEquals(
            "assets/lan_edit/tabler-icons-subset.css",
            fallback.mapAssetPath("/assets/tabler-icons-subset.css"),
        )
    }

    @Test
    fun `图标两个路径都指向同一张 logo`() {
        assertEquals("assets/branding/launcher_icon.png", fallback.mapAssetPath("/assets/logo.png"))
        assertEquals("assets/branding/launcher_icon.png", fallback.mapAssetPath("/favicon.ico"))
    }

    @Test
    fun `表里没有的路径一律不认`() {
        assertNull(fallback.mapAssetPath("/api/v1/courses"))
        assertNull(fallback.mapAssetPath("/index.htm"))
        assertNull(fallback.mapAssetPath("/assets/"))
        assertNull(fallback.mapAssetPath("/../../etc/passwd"))
        assertNull(fallback.mapAssetPath("/assets/../../secret"))
    }

    // ── 2. 响应 ──

    @Test
    fun `读到资源时回 200 且带齐三个安全头`() {
        val payload = "%PDF-fake".toByteArray()
        val assets = LanEditStaticAssets { path ->
            if (path == "assets/lan_edit/app.js") payload else null
        }

        val response = assets.serve("/assets/app.js")

        assertEquals(200, response.status)
        assertTrue(payload.contentEquals(response.body))
        val headers = response.headers.toMap()
        assertEquals("application/javascript; charset=utf-8", headers["Content-Type"])
        assertEquals("no-store", headers["Cache-Control"])
        assertEquals("nosniff", headers["X-Content-Type-Options"])
        assertEquals(LanEditStaticAssets.CONTENT_SECURITY_POLICY, headers["Content-Security-Policy"])
    }

    @Test
    fun `资源缺失时回 404 而不是空 200`() {
        // 空 200 会让浏览器把「页面没打包」显示成一片白，用户分不清是坏了还是没做。
        val response = fallback.serve("/")
        assertEquals(404, response.status)
    }

    @Test
    fun `未知路径回 404`() {
        val response = LanEditStaticAssets { ByteArray(1) }.serve("/nope")
        assertEquals(404, response.status)
    }

    @Test
    fun `读资源抛异常也回 404 不把异常冒到连接线程`() {
        val assets = LanEditStaticAssets { throw IllegalStateException("boom") }
        assertEquals(404, assets.serve("/").status)
    }

    @Test
    fun `Content-Type 按后缀给`() {
        assertEquals("text/html; charset=utf-8", fallback.contentTypeFor("a/index.html"))
        assertEquals("application/javascript; charset=utf-8", fallback.contentTypeFor("a/app.js"))
        assertEquals("text/css; charset=utf-8", fallback.contentTypeFor("a/x.css"))
        assertEquals("image/png", fallback.contentTypeFor("a/x.png"))
        assertEquals("application/json", fallback.contentTypeFor("a/x.bin"))
    }

    // ── 3. 该不该走静态分发 ──

    @Test
    fun `只有 GET 且非 api 路径才走静态分发`() {
        assertTrue(isStaticAssetRequest("GET", "/"))
        assertTrue(isStaticAssetRequest("GET", "/assets/app.js"))
        // API 一律走路由：误判成页面会让所有接口 404
        assertFalse(isStaticAssetRequest("GET", "/api/v1/health"))
        assertFalse(isStaticAssetRequest("GET", "/api/v1/courses"))
        // 写请求走路由（POST /api/v1/courses 之类）
        assertFalse(isStaticAssetRequest("POST", "/api/v1/courses"))
        assertFalse(isStaticAssetRequest("OPTIONS", "/api/v1/courses"))
    }

    // ── 4. 与 Dart 源对照 ──

    @Test
    fun `映射表每个资源路径都在 Dart 源里出现`() {
        val assetPaths = listOf(
            "/", "/index.html", "/assets/app.js", "/assets/i18n.js", "/assets/style.css",
            "/assets/lan-timetable.css", "/assets/tabler-icons-subset.css",
            "/assets/logo.png", "/favicon.ico",
        )
        for (path in assetPaths) {
            assertTrue("Dart 侧没有这个路径：$path", dartSource.contains("'$path'"))
            assertTrue("Kotlin 侧没有这个路径：$path", fallback.mapAssetPath(path) != null)
        }
    }

    @Test
    fun `CSP 与 Dart 逐字一致`() {
        assertEquals(dartContentSecurityPolicy(), LanEditStaticAssets.CONTENT_SECURITY_POLICY)
    }

    /**
     * 把 Dart 里那条 CSP 拼回来：Dart 用相邻字符串字面量跨行拼一串，
     * 所以取声明行之后**连续**以引号开头的那些行，剥掉引号与行尾分号再连起来。
     */
    private fun dartContentSecurityPolicy(): String {
        val lines = dartSource.lines()
        val start = lines.indexOfFirst { it.contains("_lanEditContentSecurityPolicy =") }
        assertTrue("Dart 侧找不到 CSP 声明", start >= 0)
        val fragment = StringBuilder()
        for (i in start + 1 until lines.size) {
            val trimmed = lines[i].trim()
            if (!trimmed.startsWith("\"")) break
            fragment.append(trimmed.removeSuffix(";").trim('"'))
        }
        return fragment.toString()
    }

    // ── 5. 表里指的资源必须真的在仓库里 ──

    @Test
    fun `映射到的每个资源文件都真实存在`() {
        val needed = listOf(
            "/", "/assets/app.js", "/assets/i18n.js", "/assets/style.css",
            "/assets/tabler-icons-subset.css", "/assets/logo.png",
        ).mapNotNull { fallback.mapAssetPath(it) }.distinct()

        for (assetPath in needed) {
            val file = repoFile(assetPath)
            assertTrue("资源是空文件：$assetPath", file.length() > 0)
        }
    }
}