package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * [WarehouseWebViewLogic] 的纯 JVM 单测（L0：
 * `pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"`）。
 *
 * 关键期望值不是「从实现里抄的」，而是**从参照物机械读出来的**：
 * - UA 两串：从 Dart `warehouse_adapter_web_login_screen.dart` 的常量定义里抽出来对拍；
 * - 导航白名单、UI 类桥接消息集合：从 Dart `lib/domain/warehouse_bridge_gate.dart` 里抽出来对拍；
 * - WebView 错误码数值：取自平台 `android.jar` 的 `javap -constants`（来源见
 *   「错误码常量与平台 android_jar 数值一致」那条测试的注释）。
 */
class WarehouseWebViewLogicTest {

    // -----------------------------------------------------------------------
    // 1. UA：与 Dart 逐字对拍
    // -----------------------------------------------------------------------

    @Test
    fun `UA 两串与 Dart 参照物逐字一致`() {
        val dart = readRepoFile("lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart")
        val desktop = dartConcatStringLiteral(dart, "_desktopUserAgent")
        val mobile = dartConcatStringLiteral(dart, "_mobileUserAgent")

        assertEquals("桌面版 UA 与 Dart 不一致", desktop, WarehouseWebViewUserAgents.DESKTOP)
        assertEquals("移动版 UA 与 Dart 不一致", mobile, WarehouseWebViewUserAgents.MOBILE)

        // 参照物里两串必须真的不同，否则上面两条断言等于空转
        assertTrue("Dart 里桌面/移动 UA 竟然相同，参照物已经不可信", desktop != mobile)
        assertTrue("移动版 UA 少了 Mobile 标记", mobile.contains("Mobile"))
        assertFalse("桌面版 UA 不该带 Mobile 标记", desktop.contains("Mobile"))
    }

    @Test
    fun `UA 选择按桌面模式切换`() {
        assertEquals(WarehouseWebViewUserAgents.DESKTOP, WarehouseWebViewUserAgents.forDesktopMode(true))
        assertEquals(WarehouseWebViewUserAgents.MOBILE, WarehouseWebViewUserAgents.forDesktopMode(false))
    }

    // -----------------------------------------------------------------------
    // 2. 视口改写 JS
    // -----------------------------------------------------------------------

    @Test
    fun `桌面模式视口脚本强制 1024 且不残留模板占位`() {
        val script = warehouseViewportOverrideScript(desktopMode = true)

        // 桌面/移动两条分支的**文本**在脚本里都在（三元表达式），能判定的只有被代入的那个字面量：
        // 桌面必须把 `const content =` 求值成 true。
        assertTrue("桌面脚本必须选中 width=1024 分支", script.contains("const content = true"))
        assertFalse("桌面脚本不该代入 false", script.contains("const content = false"))
        assertTrue("桌面分支必须真的写着 width=1024", script.contains("'width=1024'"))
        assertTrue("必须保留原始 meta 的暂存键", script.contains("__qingyuOriginalViewport"))
        assertFalse("模板变量没被替换掉", script.contains("desktopMode"))
        assertTrue("脚本必须是可执行的自调用函数", script.startsWith("(() => {") && script.endsWith("})();"))
    }

    @Test
    fun `移动模式视口脚本恢复原始 meta 并回退 device-width`() {
        val script = warehouseViewportOverrideScript(desktopMode = false)

        assertTrue("移动脚本必须代入 false", script.contains("const content = false"))
        assertFalse("移动脚本不该代入 true", script.contains("const content = true"))
        assertTrue(
            "移动分支必须回退到 device-width",
            script.contains("(window[KEY] || 'width=device-width, initial-scale=1')"),
        )
        assertFalse("模板变量没被替换掉", script.contains("desktopMode"))
        assertTrue("脚本必须是可执行的自调用函数", script.startsWith("(() => {") && script.endsWith("})();"))
    }

    // -----------------------------------------------------------------------
    // 3. 导航 scheme 白名单
    // -----------------------------------------------------------------------

    @Test
    fun `导航白名单与 Dart 门禁的 scheme 列表逐项一致`() {
        val dart = readRepoFile("lib/domain/warehouse_bridge_gate.dart")
        val start = dart.indexOf("bool warehouseAllowsMainFrameNavigation(")
        assertTrue("Dart 门禁里找不到 warehouseAllowsMainFrameNavigation", start >= 0)
        val end = dart.indexOf("\n}", start)
        val body = dart.substring(start, end)
        val dartAllowed = Regex("""scheme == '([^']*)'""").findAll(body).map { it.groupValues[1] }.toSet()
        assertEquals("Dart 门禁的放行 scheme 列表变了，Kotlin 侧要同步", setOf("http", "https", "about"), dartAllowed)

        val samples = listOf(
            "https://jw.school.edu.cn/login" to true,
            "http://jw.school.edu.cn/login" to true,
            "about:blank" to true,
            "HTTPS://JW.SCHOOL.EDU.CN" to true,
            "https://例.com/教务" to true,
            "javascript:alert(1)" to false,
            "data:text/html;base64,PHNjcmlwdD4=" to false,
            "file:///sdcard/secret.html" to false,
            "intent://scan/#Intent;scheme=zxing;end" to false,
            "ftp://files.org/x" to false,
            "//jw.school.edu.cn/login" to false,
            "jw.school.edu.cn" to false,
            "" to false,
        )
        for ((url, expected) in samples) {
            assertEquals("URL `$url` 的放行判定与 Dart 门禁不一致", expected, warehouseAllowsMainFrameNavigation(url))
        }
        assertFalse("null 必须拒绝", warehouseAllowsMainFrameNavigation(null))
    }

    @Test
    fun `scheme 提取按 Dart Uri 口径处理中文域名与非法形状`() {
        assertEquals("http", warehouseUrlScheme("http://x"))
        assertEquals("https", warehouseUrlScheme("  HTTPS://X  "))
        assertEquals("about", warehouseUrlScheme("about:blank"))
        assertEquals("https", warehouseUrlScheme("https://例.com/教务"))
        assertEquals("", warehouseUrlScheme("jw.school.edu.cn"))
        assertEquals("", warehouseUrlScheme("//host/path"))
        assertEquals("", warehouseUrlScheme(":no-scheme"))
        assertEquals("", warehouseUrlScheme("1http://x"))
        assertEquals("", warehouseUrlScheme("ht tp://x"))
        assertEquals("", warehouseUrlScheme(null))
        assertEquals("", warehouseUrlScheme(""))
    }

    // -----------------------------------------------------------------------
    // 4. 错误码 → 分类
    // -----------------------------------------------------------------------

    @Test
    fun `错误码常量与平台 android_jar 数值一致`() {
        // 期望值来源：javap -constants android.webkit.WebViewClient
        // （android-37.2/android.jar，2026-10-28 实测）
        val expected = mapOf(
            "ERROR_UNKNOWN" to -1,
            "ERROR_HOST_LOOKUP" to -2,
            "ERROR_UNSUPPORTED_AUTH_SCHEME" to -3,
            "ERROR_AUTHENTICATION" to -4,
            "ERROR_PROXY_AUTHENTICATION" to -5,
            "ERROR_CONNECT" to -6,
            "ERROR_IO" to -7,
            "ERROR_TIMEOUT" to -8,
            "ERROR_REDIRECT_LOOP" to -9,
            "ERROR_UNSUPPORTED_SCHEME" to -10,
            "ERROR_FAILED_SSL_HANDSHAKE" to -11,
            "ERROR_BAD_URL" to -12,
            "ERROR_FILE" to -13,
            "ERROR_FILE_NOT_FOUND" to -14,
            "ERROR_TOO_MANY_REQUESTS" to -15,
            "ERROR_UNSAFE_RESOURCE" to -16,
        )
        val actual = mapOf(
            "ERROR_UNKNOWN" to WarehouseWebViewErrorCodes.UNKNOWN,
            "ERROR_HOST_LOOKUP" to WarehouseWebViewErrorCodes.HOST_LOOKUP,
            "ERROR_UNSUPPORTED_AUTH_SCHEME" to WarehouseWebViewErrorCodes.UNSUPPORTED_AUTH_SCHEME,
            "ERROR_AUTHENTICATION" to WarehouseWebViewErrorCodes.AUTHENTICATION,
            "ERROR_PROXY_AUTHENTICATION" to WarehouseWebViewErrorCodes.PROXY_AUTHENTICATION,
            "ERROR_CONNECT" to WarehouseWebViewErrorCodes.CONNECT,
            "ERROR_IO" to WarehouseWebViewErrorCodes.IO,
            "ERROR_TIMEOUT" to WarehouseWebViewErrorCodes.TIMEOUT,
            "ERROR_REDIRECT_LOOP" to WarehouseWebViewErrorCodes.REDIRECT_LOOP,
            "ERROR_UNSUPPORTED_SCHEME" to WarehouseWebViewErrorCodes.UNSUPPORTED_SCHEME,
            "ERROR_FAILED_SSL_HANDSHAKE" to WarehouseWebViewErrorCodes.FAILED_SSL_HANDSHAKE,
            "ERROR_BAD_URL" to WarehouseWebViewErrorCodes.BAD_URL,
            "ERROR_FILE" to WarehouseWebViewErrorCodes.FILE,
            "ERROR_FILE_NOT_FOUND" to WarehouseWebViewErrorCodes.FILE_NOT_FOUND,
            "ERROR_TOO_MANY_REQUESTS" to WarehouseWebViewErrorCodes.TOO_MANY_REQUESTS,
            "ERROR_UNSAFE_RESOURCE" to WarehouseWebViewErrorCodes.UNSAFE_RESOURCE,
        )
        assertEquals("错误码镜像表被改动（应与平台 android.jar 一致）", expected, actual)
    }

    @Test
    fun `错误码分类覆盖每一类并落到正确种类`() {
        assertEquals(
            WarehouseWebViewErrorKind.HOST_UNREACHABLE,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.HOST_LOOKUP),
        )
        assertEquals(
            WarehouseWebViewErrorKind.CONNECTION_FAILED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.CONNECT),
        )
        assertEquals(
            WarehouseWebViewErrorKind.CONNECTION_FAILED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.IO),
        )
        assertEquals(
            WarehouseWebViewErrorKind.TIMEOUT,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.TIMEOUT),
        )
        assertEquals(
            WarehouseWebViewErrorKind.SSL_FAILED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.FAILED_SSL_HANDSHAKE),
        )
        assertEquals(
            WarehouseWebViewErrorKind.AUTH_REQUIRED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.UNSUPPORTED_AUTH_SCHEME),
        )
        assertEquals(
            WarehouseWebViewErrorKind.AUTH_REQUIRED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.AUTHENTICATION),
        )
        assertEquals(
            WarehouseWebViewErrorKind.AUTH_REQUIRED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.PROXY_AUTHENTICATION),
        )
        assertEquals(
            WarehouseWebViewErrorKind.BAD_URL,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.BAD_URL),
        )
        assertEquals(
            WarehouseWebViewErrorKind.UNSUPPORTED_SCHEME,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.UNSUPPORTED_SCHEME),
        )
        assertEquals(
            WarehouseWebViewErrorKind.REDIRECT_LOOP,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.REDIRECT_LOOP),
        )
        assertEquals(
            WarehouseWebViewErrorKind.TOO_MANY_REQUESTS,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.TOO_MANY_REQUESTS),
        )
        // 平台 ERROR_UNKNOWN 与将来新增的码一律归 UNKNOWN
        assertEquals(WarehouseWebViewErrorKind.UNKNOWN, classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.UNKNOWN))
        assertEquals(WarehouseWebViewErrorKind.UNKNOWN, classifyWarehouseWebViewError(-99))
    }

    @Test
    fun `明文拦截优先于错误码且判据与 Dart 同口径`() {
        // Chromium 把明文拦截报成通用连接错误码；只看码会把「不在白名单」讲成「网络连不上」
        assertEquals(
            WarehouseWebViewErrorKind.CLEARTEXT_BLOCKED,
            classifyWarehouseWebViewError(
                WarehouseWebViewErrorCodes.CONNECT,
                "net::ERR_CLEARTEXT_NOT_PERMITTED",
            ),
        )
        assertTrue(isWarehouseCleartextBlocked("net::ERR_CLEARTEXT_NOT_PERMITTED"))
        // 与 Dart 一样区分大小写：Chromium 侧恒为大写常量
        assertFalse(isWarehouseCleartextBlocked("net::err_cleartext_not_permitted"))
        assertFalse(isWarehouseCleartextBlocked(null))
        assertEquals(
            WarehouseWebViewErrorKind.CONNECTION_FAILED,
            classifyWarehouseWebViewError(WarehouseWebViewErrorCodes.CONNECT, "net::ERR_CONNECTION_REFUSED"),
        )
    }

    @Test
    fun `错误快照默认按码与描述分类并给出 ARB 键名`() {
        val blocked = WarehouseWebViewError(
            errorCode = WarehouseWebViewErrorCodes.CONNECT,
            description = "net::ERR_CLEARTEXT_NOT_PERMITTED",
            url = "http://jw.school.edu.cn/login",
        )
        assertEquals(WarehouseWebViewErrorKind.CLEARTEXT_BLOCKED, blocked.kind)
        assertEquals("importCleartextBlockedHint", blocked.arbKey)

        val timeout = WarehouseWebViewError(
            errorCode = WarehouseWebViewErrorCodes.TIMEOUT,
            description = "net::ERR_TIMED_OUT",
            url = null,
        )
        assertEquals(WarehouseWebViewErrorKind.TIMEOUT, timeout.kind)
        assertNull("没有现成 ARB 键时必须是 null，不许硬编中文", timeout.arbKey)
    }

    // -----------------------------------------------------------------------
    // 5. Cookie 拼装
    // -----------------------------------------------------------------------

    @Test
    fun `解析 Cookie 头覆盖空段 缺等号 值内含等号等形状`() {
        assertEquals(
            listOf(WarehouseCookie("a", "1"), WarehouseCookie("b", "2")),
            parseWarehouseCookieHeader("a=1; b=2"),
        )
        // 值里允许再出现 '='（base64 / JWT），只在第一个 '=' 处切
        assertEquals(
            listOf(WarehouseCookie("token", "a=b=c")),
            parseWarehouseCookieHeader("token=a=b=c"),
        )
        // 空值合法
        assertEquals(listOf(WarehouseCookie("empty", "")), parseWarehouseCookieHeader("empty="))
        // 无名字 / 无等号 / 空段一律丢弃
        assertEquals(
            listOf(WarehouseCookie("ok", "1")),
            parseWarehouseCookieHeader("; =noname; noequals; ok=1 ; "),
        )
        assertEquals(emptyList<WarehouseCookie>(), parseWarehouseCookieHeader(null))
        assertEquals(emptyList<WarehouseCookie>(), parseWarehouseCookieHeader("   "))
        assertEquals(emptyList<WarehouseCookie>(), parseWarehouseCookieHeader(";;;"))
    }

    @Test
    fun `拼装 Cookie 头保持顺序并丢掉空名项`() {
        assertEquals(
            "a=1; b=2",
            buildWarehouseCookieHeader(listOf(WarehouseCookie("a", "1"), WarehouseCookie("b", "2"))),
        )
        assertEquals("a=1", buildWarehouseCookieHeader(listOf(WarehouseCookie(" ", "x"), WarehouseCookie("a", "1"))))
        assertEquals("", buildWarehouseCookieHeader(emptyList()))
    }

    @Test
    fun `合并 Cookie 头后者覆盖同名但沿用首次出现的位置`() {
        // 同名覆盖：后一段赢；位置沿用第一次出现的位置
        assertEquals(
            "a=2; b=1",
            mergeWarehouseCookieHeaders("a=1; b=1", "a=2"),
        )
        // 多段拼接，null / 空串被容忍
        assertEquals(
            "sid=1; csrf=2",
            mergeWarehouseCookieHeaders(null, "sid=1", "", "csrf=2"),
        )
        assertEquals("", mergeWarehouseCookieHeaders(null, "", "  "))
        // 解析 + 拼装是同一口径的往返
        val raw = "sid=abc; token=x=y; empty="
        assertEquals(raw, buildWarehouseCookieHeader(parseWarehouseCookieHeader(raw)))
    }

    // -----------------------------------------------------------------------
    // 6. 桥接消息门禁
    // -----------------------------------------------------------------------

    @Test
    fun `桥接 UI 类消息集合与 Dart 门禁逐项一致`() {
        val dart = readRepoFile("lib/domain/warehouse_bridge_gate.dart")
        val start = dart.indexOf("kWarehouseImportOnlyBridgeMessageTypes")
        assertTrue("Dart 门禁里找不到 UI 类消息集合", start >= 0)
        val braceStart = dart.indexOf('{', start)
        val braceEnd = dart.indexOf('}', braceStart)
        assertTrue("Dart 门禁里的集合字面量不完整", braceStart > 0 && braceEnd > braceStart)
        val dartTypes = Regex("""'([^']*)'""")
            .findAll(dart.substring(braceStart, braceEnd))
            .map { it.groupValues[1] }
            .toSet()

        assertEquals(
            "Dart 的 UI 类桥接消息集合变了，Kotlin 侧必须同步",
            dartTypes,
            WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES,
        )
        assertEquals(
            setOf("toast", "confirm", "prompt", "singleSelection", "error"),
            WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES,
        )
    }

    @Test
    fun `桥接门禁只在导入执行期放行 UI 类消息`() {
        for (type in WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES) {
            assertFalse("UI 类消息 `$type` 在非导入期必须被丢弃", shouldProcessWarehouseBridgeMessage(type, false))
            assertTrue("UI 类消息 `$type` 在导入期应放行", shouldProcessWarehouseBridgeMessage(type, true))
        }
        // 其余非 UI 类消息照常处理（宿主自己注入的探活协议 / 数据类）
        for (type in listOf("loginState", "sessionProbe", "courses")) {
            assertTrue("非 UI 类消息 `$type` 不该被门禁拦下", shouldProcessWarehouseBridgeMessage(type, false))
        }
        // 判不出类型时交回调用方（与 Dart「非 UI 类一律照常处理」同口径）
        assertTrue(shouldProcessWarehouseBridgeMessage(null, false))
    }

    @Test
    fun `macro_event 只在录制态放行`() {
        // 非录制态没有合法生产者（录制脚本由宿主在录制态注入）——伪造的一律丢弃
        assertFalse(
            "非录制态的 macro:event 必须被丢弃",
            shouldProcessWarehouseBridgeMessage("macro:event", importExecutionActive = false),
        )
        assertFalse(
            "导入执行期也不放行 macro:event（放行条件只看录制态，与 Dart 并集口径一致）",
            shouldProcessWarehouseBridgeMessage("macro:event", importExecutionActive = true),
        )
        assertTrue(
            "录制态的 macro:event 应放行",
            shouldProcessWarehouseBridgeMessage(
                "macro:event",
                importExecutionActive = false,
                macroRecordingActive = true,
            ),
        )
    }

    @Test
    fun `loginAttempt 四类放行并集与钓鱼页拒绝`() {
        val allOff = {
            shouldProcessWarehouseBridgeMessage(
                "loginAttempt",
                importExecutionActive = false,
                macroRecordingActive = false,
                foregroundReplayActive = false,
                trustedPageOrigin = false,
            )
        }
        // 拒绝 1：钓鱼页/第三方页上的伪造登录尝试（执行期/录制态/回放/受信全不沾）
        assertFalse("四个条件全不满足时必须拒绝", allOff())
        // 拒绝 2：非录制态的杂项环境里也不因为「消息长得像数据类」而放行
        //（与 UI 类判据隔离：loginAttempt 不在 UI 集合里，但也不是无条件放行）
        assertFalse(
            "macro:event 语义同场校验：非录制态杂项消息丢弃",
            shouldProcessWarehouseBridgeMessage("macro:event", importExecutionActive = false),
        )
        // 放行 1：导入执行期（适配脚本主导的会话）
        assertTrue(
            shouldProcessWarehouseBridgeMessage(
                "loginAttempt",
                importExecutionActive = true,
            ),
        )
        // 放行 2：录制态
        assertTrue(
            shouldProcessWarehouseBridgeMessage(
                "loginAttempt",
                importExecutionActive = false,
                macroRecordingActive = true,
            ),
        )
        // 放行 3：前台回放的导航阶段（登录步骤在 executingImport 之前）
        assertTrue(
            shouldProcessWarehouseBridgeMessage(
                "loginAttempt",
                importExecutionActive = false,
                foregroundReplayActive = true,
            ),
        )
        // 放行 4：当前页在受信 host 上（普通手动登录的主路径）
        assertTrue(
            shouldProcessWarehouseBridgeMessage(
                "loginAttempt",
                importExecutionActive = false,
                trustedPageOrigin = true,
            ),
        )
    }

    @Test
    fun `受信 host 锚点精确与子域放行后缀伪装拒绝`() {
        // 受信集合按真实调用路径构造（宿主给地址、warehouseTrustedLoginHosts 做 host 化）
        val trusted = warehouseTrustedLoginHosts(
            "https://jw.trusted.cn/login",
            "https://portal.school.edu.cn:8443/",
        )
        // 登记地址本体精确命中
        assertTrue(warehouseUrlOnTrustedHosts("https://jw.trusted.cn/login", trusted))
        // 子域放行：a.trusted.cn 匹配 trusted.cn（Dart 同款要求）
        assertTrue(warehouseUrlOnTrustedHosts("https://a.trusted.cn/x", listOf("trusted.cn")))
        // 端口 / userinfo / 路径不参与判定
        assertTrue(
            warehouseUrlOnTrustedHosts(
                "https://user:pass@Portal.School.EDU.cn:8443/login?a=1",
                listOf("portal.school.edu.cn"),
            ),
        )
        // 大小写不敏感
        assertTrue(warehouseUrlOnTrustedHosts("https://JW.Trusted.CN/", listOf("jw.trusted.cn")))
        // 后缀伪装拒绝：trusted.cn.evil.com 不是 trusted.cn 的子域
        assertFalse(
            "后缀伪装必须拒绝",
            warehouseUrlOnTrustedHosts("https://trusted.cn.evil.com/login", listOf("trusted.cn")),
        )
        assertFalse(
            "前缀伪装也必须拒绝",
            warehouseUrlOnTrustedHosts("https://eviltrusted.cn/", listOf("trusted.cn")),
        )
        // 解析不出 host 的输入一律拒绝（空 / null / 相对地址 / 非 http 形态）
        assertFalse(warehouseUrlOnTrustedHosts(null, trusted))
        assertFalse(warehouseUrlOnTrustedHosts("", trusted))
        assertFalse(warehouseUrlOnTrustedHosts("   ", trusted))
        assertFalse(warehouseUrlOnTrustedHosts("/relative/path", trusted))
        assertFalse(warehouseUrlOnTrustedHosts("about:blank", trusted))
        assertFalse(warehouseUrlOnTrustedHosts("javascript:alert(1)", trusted))
        // 受信条目里的空白项跳过，不影响其余条目的判定
        assertTrue(
            warehouseUrlOnTrustedHosts("https://trusted.cn/", listOf("  ", "", "trusted.cn")),
        )
        assertFalse(warehouseUrlOnTrustedHosts("https://other.cn/", listOf("  ", "", "trusted.cn")))
        // 全是空白条目 ⇒ 没有任何受信 host ⇒ 一律拒绝
        assertFalse(warehouseUrlOnTrustedHosts("https://trusted.cn/", listOf("  ", "")))
    }

    @Test
    fun `受信 host 集合从登记与自定义地址构造`() {
        assertEquals(
            setOf("jw.trusted.cn", "portal.school.edu.cn"),
            warehouseTrustedLoginHosts(
                "https://jw.trusted.cn/login",
                "https://Portal.School.edu.cn:8443/",
                null,
                "",
                "   ",
                "/no-host-here",
            ),
        )
        // 全都解析不出 ⇒ 空集合（受信放行永不生效，门禁只会更严）
        assertTrue(warehouseTrustedLoginHosts(null, "", "about:blank").isEmpty())
    }

    @Test
    fun `从桥接原始文本里取出消息类型`() {
        assertEquals("loginState", warehouseBridgeMessageType("""{"type":"loginState","username":"a"}"""))
        assertEquals("macro:event", warehouseBridgeMessageType("""{"type":"macro:event"}"""))
        assertEquals("toast", warehouseBridgeMessageType("""  {"type" : "toast" }  """))
        assertNull("不是 JSON", warehouseBridgeMessageType("not json"))
        assertNull("顶层不是对象", warehouseBridgeMessageType("""["toast"]"""))
        assertNull("没有 type 字段", warehouseBridgeMessageType("""{"payload":"x"}"""))
        assertNull("type 不是字符串", warehouseBridgeMessageType("""{"type":123}"""))
        assertNull(warehouseBridgeMessageType(null))
        assertNull(warehouseBridgeMessageType("   "))
    }

    // -----------------------------------------------------------------------
    // 7. JS 求值结果解码
    // -----------------------------------------------------------------------

    @Test
    fun `JS 求值结果按平台 JSON 口径解码`() {
        assertNull("JS 的 null / undefined 都回字符串 null", decodeWarehouseJsResult("null"))
        assertNull(decodeWarehouseJsResult(null))
        assertNull(decodeWarehouseJsResult("   "))

        assertEquals("abc", decodeWarehouseJsResult("\"abc\""))
        assertEquals("", decodeWarehouseJsResult("\"\""))
        assertEquals("a\"b", decodeWarehouseJsResult("\"a\\\"b\""))
        assertEquals("换行\n符", decodeWarehouseJsResult("\"换行\\n符\""))
        // 非字符串：原样给 JSON 文本，不做 Double 化
        assertEquals("123", decodeWarehouseJsResult("123"))
        assertEquals("true", decodeWarehouseJsResult("true"))
        assertEquals("{\"a\":1}", decodeWarehouseJsResult("{\"a\":1}"))
        // 解不出来时宁可露出原文，也不静默吞掉
        assertEquals("not json at all", decodeWarehouseJsResult("not json at all"))
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    /** 从仓库根向上找文件（与 `WarehouseStringsParityTest` 同一套做法，不依赖 cwd）。 */
    private fun repoFile(relativePath: String): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relativePath)
            if (candidate.isFile) return candidate
            dir = dir?.parentFile
        }
        error("找不到参照物 $relativePath（当前目录 ${File("").absolutePath}）")
    }

    /** 读参照物：**显式 UTF-8**，不依赖 JVM 默认字符集。 */
    private fun readRepoFile(relativePath: String): String =
        repoFile(relativePath).readText(Charsets.UTF_8)

    /**
     * 抽出 Dart `static const String <name> = 'a' 'b';` 这种**多段拼接**的字符串常量。
     * 直接读源码是为了让「逐字对齐 Dart」这条期望值不来自 Kotlin 实现本身。
     *
     * 逐字符扫描而不是 `indexOf(';')`：UA 字面量里**自带分号**
     * （`Mozilla/5.0 (Windows NT 10.0; Win64; x64)`），按第一个分号截会把字面量截断，
     * 于是「一个都没解析出来」——这条坑 2026-10-28 实际踩过一次。
     */
    private fun dartConcatStringLiteral(source: String, variableName: String): String {
        val start = source.indexOf("$variableName =")
        assertTrue("Dart 参照物里找不到常量 $variableName", start >= 0)
        val literals = ArrayList<String>()
        var i = start
        var inQuote = false
        val current = StringBuilder()
        while (i < source.length) {
            val c = source[i]
            when {
                !inQuote && c == ';' -> break
                !inQuote && c == '\'' -> {
                    inQuote = true
                    current.setLength(0)
                }
                inQuote && c == '\\' -> {
                    i++
                    if (i < source.length) current.append(source[i])
                }
                inQuote && c == '\'' -> {
                    inQuote = false
                    literals.add(current.toString())
                }
                inQuote -> current.append(c)
            }
            i++
        }
        assertTrue(
            "Dart 参照物里 $variableName 没有解析出字符串字面量（起点 $start）",
            literals.isNotEmpty(),
        )
        return literals.joinToString("")
    }
}
