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
 * 期望值钉 Kotlin 常量表（`LanEditStaticAssets`）本身：
 * - 路径表：九个键；
 * - `Content-Type`：按后缀；
 * - 响应头：`no-store` / CSP / `nosniff`；
 * - 缺资源与未知路径都是 404。
 *
 * 去 Flutter 化（P4-C，2026-11-08）：原先§4 还与 Dart 源逐字对拍
 * （`lib/services/lan_edit_server_service.dart` 的 `_mapAssetPath` / `_contentTypeFor` /
 * `_serveStatic` / `_lanEditContentSecurityPolicy`），Dart 层删除后参照物不存在，
 * 那两条已删——Kotlin 侧常量表仍由 §1-§3 的断言钉住，没有失去覆盖。
 *
 * **前缀口径（2026-11-03）**：Dart 的资源路径带 `assets/` 前缀（rootBundle 以 flutter
 * 资产目录为根）；Kotlin 侧 `AssetManager` 本就相对 APK assets 根，映射表**不带**
 * `assets/` 前缀——照抄会找成 `assets/assets/…`，整表 FileNotFound、控制台整个 404。
 *
 * 另外一条**与网页端 JS 对照**的用例（§6）：映射表与 CSP 字符串改错在 Kotlin 侧完全看不出来，
 * 只有真机打开浏览器才知道（而真机对照归用户），所以用读源码做子串比对挡在提交前。
 */
class LanEditStaticAssetsTest {

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

    /**
     * 主 assets 落点（打进 APK 的就是这份）。根锚点用仓库根的 `android/app/build.gradle`——
     * 或是 `i18n/app_zh.arb` 都行，但传到根要三层 parent：
     * `i18n/app_zh.arb` 的 parent 是 `i18n/`，不是仓库根，少一层就会解析出
     * `i18n/android/app/...` 这种不存在的路径（2026-11-08 踩过）。
     */
    private fun mainAssetFile(relative: String): File =
        repoFile("i18n/app_zh.arb").parentFile.parentFile
            .resolve("android/app/src/main/assets/$relative")

    // ── 1. 路径表 ──

    @Test
    fun `根路径与 index 都指向控制台首页`() {
        assertEquals("lan_edit/index.html", fallback.mapAssetPath("/"))
        assertEquals("lan_edit/index.html", fallback.mapAssetPath("/index.html"))
    }

    @Test
    fun `脚本与样式按 Dart 的表映射`() {
        assertEquals("lan_edit/app.js", fallback.mapAssetPath("/assets/app.js"))
        assertEquals("lan_edit/i18n.js", fallback.mapAssetPath("/assets/i18n.js"))
        // 两个样式路径指向同一个文件（Dart 里 style.css 是历史别名）
        assertEquals("lan_edit/lan-timetable.css", fallback.mapAssetPath("/assets/style.css"))
        assertEquals(
            "lan_edit/lan-timetable.css",
            fallback.mapAssetPath("/assets/lan-timetable.css"),
        )
        assertEquals(
            "lan_edit/tabler-icons-subset.css",
            fallback.mapAssetPath("/assets/tabler-icons-subset.css"),
        )
    }

    @Test
    fun `图标两个路径都指向同一张 logo`() {
        assertEquals("branding/launcher_icon.png", fallback.mapAssetPath("/assets/logo.png"))
        assertEquals("branding/launcher_icon.png", fallback.mapAssetPath("/favicon.ico"))
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
            if (path == "lan_edit/app.js") payload else null
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

    // ── 4. （原与 Dart 源对照的两条：P4-C 后 Dart 层删除，参照物不存在——Kotlin 常量表已由
    //         §1-§3 的断言钉住，故整段删除，CSP 改用下列逐字钉死，见类 KDoc。）

    @Test
    fun `CSP 逐字为既定策略`() {
        // Dart 时代该值用相邻字符串字面量跨行拼、Kotlin 侧是常量化——平铺写法改错在 Kotlin 侧
        // 完全看不出来，只有真机打开浏览器才知道（真机归用户）。逐字钉死，值一变就红。
        assertEquals(
            "default-src 'self'; script-src 'self'; " +
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; " +
                "font-src 'self' https://cdn.jsdelivr.net; " +
                "img-src 'self' data:; connect-src 'self'; " +
                "object-src 'none'; base-uri 'none'; " +
                "frame-ancestors 'none'; form-action 'self'",
            LanEditStaticAssets.CONTENT_SECURITY_POLICY,
        )
    }

    // ── 5. 表里指的资源必须真的在仓库里 ──

    @Test
    fun `映射到的每个资源文件都真实存在`() {
        val needed = listOf(
            "/", "/assets/app.js", "/assets/i18n.js", "/assets/style.css",
            "/assets/tabler-icons-subset.css", "/assets/logo.png",
        ).mapNotNull { fallback.mapAssetPath(it) }.distinct()

        for (assetPath in needed) {
            // 对拍主 assets（打进 APK 的那份），不拿仓库根的 Dart 原件凑数。
            val file = mainAssetFile(assetPath)
            assertTrue("主 assets 缺资源：$assetPath", file.isFile)
            assertTrue("资源是空文件：$assetPath", file.length() > 0)
        }
    }

    // ── 6. 网页端行为没有自动化：靠源码守卫钉「字段真被消费」 ──

    @Test
    fun `网页端撤销结果必须消费 skippedCount 并配好中英文案`() {
        // `assets/lan_edit/` 下没有 JS 测试基建（无 node 测试入口），网页端行为本身
        // 只能真机验。这里守的是最容易被无声破坏的一步：响应里有 `skippedCount`、
        // 网页端却不读——用户就会看到「撤销成功」而少撤了 N 套模板（hy3 判不能放行的那处）。
        //
        // 两份拷贝都查：仓库根 `assets/lan_edit/` 是 Dart 时代原件（现在不打包），
        // 主 assets 才是打进 APK 的那份；漏掉任何一份都会在「下次从根拷贝覆盖」时复发。
        for (copy in listOf("assets/lan_edit", "android/app/src/main/assets/lan_edit")) {
            val appJs = repoFile("$copy/app.js").readText()
            assertTrue(
                "$copy/app.js 必须把 result.skippedCount 真的读进数值（注释里提一句不算）",
                Regex("""Number\(\s*result\.skippedCount\s*\)""").containsMatchIn(appJs),
            )
            assertTrue(
                "$copy/app.js 有未撤条目时不许只说「撤销成功」：必须真的调 transferUndoPartial",
                appJs.contains("t('transferUndoPartial'"),
            )
            val i18n = repoFile("$copy/i18n.js").readText()
            val keyCount = Regex("""transferUndoPartial\s*:""").findAll(i18n).count()
            assertTrue(
                "$copy/i18n.js 的 transferUndoPartial 至少要中英两份（现在 $keyCount 份）",
                keyCount >= 2,
            )
            assertTrue(
                "$copy/i18n.js 的中文案必须带 {0} 占位（条数要真的显示出来）",
                i18n.contains("transferUndoPartial: '撤销完成，其中 {0} 套时间模板未撤销"),
            )
        }
    }
}