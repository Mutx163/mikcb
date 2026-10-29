package com.mutx163.qingyu.pages.feedback

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 问题反馈页模型层测试。
 *
 * 期望值来源（独立于实现）：
 * - 渠道清单/顺序/文案/URL：逐条对照 `lib/screens/feedback_screen.dart:36-59,72-157`；
 * - 打开语义：对照 `_openChannel`（`:195-250`）、`_openWechatOfficialAccount`（`:169-186`）——
 *   逐个候选 URL 尝试、空串跳过、全部失败才回落复制 + 黄色提示；
 * - QQ 深链：`Uri.encodeComponent`（Dart 保留 `A-Za-z0-9-_.!~*'()`）拼接，
 *   期望值按 Dart 文档口径手推，不抄实现；
 * - 文案：直读 `lib/l10n/app_zh.arb` 逐字对拍。
 */
class FeedbackModelTest {

    // ---------- 渠道清单 ----------

    @Test
    fun `五个渠道按Dart顺序排列`() {
        val view = buildFeedbackPageView()
        assertEquals("问题反馈", view.title)
        assertEquals(
            listOf("github", "xiaohongshu", "coolapk", "qq", "wechat"),
            view.channels.map { it.id },
        )
    }

    @Test
    fun `GitHub渠道`() {
        val channel = buildFeedbackPageView().channels.first { it.id == "github" }
        assertEquals("GitHub Issue", channel.title)
        assertEquals("提交问题、建议，查看已有反馈", channel.subtitle)
        assertEquals("https://github.com/Mutx163/mikcb/issues", channel.copyValue)
        assertEquals("已复制 Issue 地址", channel.copyToast)
        assertEquals(listOf("https://github.com/Mutx163/mikcb/issues"), channel.urls)
        assertEquals("https://github.com/Mutx163/mikcb/issues", channel.fallbackCopyValue)
        assertNull(channel.preCopy)
    }

    @Test
    fun `小红书渠道两个候选URL且复制的是号`() {
        val channel = buildFeedbackPageView().channels.first { it.id == "xiaohongshu" }
        assertEquals("小红书", channel.title)
        assertEquals("小红书号：4976443029", channel.subtitle)
        assertEquals("4976443029", channel.copyValue)
        assertEquals("已复制小红书号", channel.copyToast)
        assertEquals(
            listOf(
                "https://xhslink.com/m/ALcscDMw39N",
                "https://www.xiaohongshu.com/user/profile/4976443029",
            ),
            channel.urls,
        )
        assertEquals("4976443029", channel.fallbackCopyValue)
    }

    @Test
    fun `酷安渠道应用内深链排在外链之前`() {
        val channel = buildFeedbackPageView().channels.first { it.id == "coolapk" }
        assertEquals("酷安", channel.title)
        assertEquals("酷安号：Mutx666", channel.subtitle)
        assertEquals("Mutx666", channel.copyValue)
        assertEquals("已复制酷安号", channel.copyToast)
        // Dart 顺序：先 coolapk.com，再 coolmarket://（失败会继续试下一个）。
        assertEquals(
            listOf(
                "https://www.coolapk.com/u/739248",
                "coolmarket://www.coolapk.com/u/739248",
            ),
            channel.urls,
        )
    }

    @Test
    fun `QQ群渠道`() {
        val channel = buildFeedbackPageView().channels.first { it.id == "qq" }
        assertEquals("QQ 群", channel.title)
        assertEquals("群号：1077077989", channel.subtitle)
        assertEquals("1077077989", channel.copyValue)
        assertEquals("已复制 QQ 群号", channel.copyToast)
        assertEquals("1077077989", channel.fallbackCopyValue)
        assertEquals(2, channel.urls.size)
    }

    @Test
    fun `微信公众号先复制名称再尝试打开微信`() {
        val channel = buildFeedbackPageView().channels.first { it.id == "wechat" }
        assertEquals("微信公众号", channel.title)
        assertEquals("轻屿课表", channel.subtitle)
        assertEquals("轻屿课表", channel.copyValue)
        assertEquals("已复制公众号名称", channel.copyToast)
        assertEquals("轻屿课表", channel.preCopy)
        assertEquals(listOf("weixin://"), channel.urls)
        assertEquals("轻屿课表", channel.fallbackCopyValue)
        // Dart：打开前提示改成「已复制公众号名称，请到微信中粘贴搜索」。
        assertEquals("已复制公众号名称，请到微信中粘贴搜索", channel.openingToast)
    }

    @Test
    fun `普通渠道打开提示是正在打开`() {
        for (id in listOf("github", "xiaohongshu", "coolapk", "qq")) {
            val channel = buildFeedbackPageView().channels.first { it.id == id }
            assertEquals("正在打开……", channel.openingToast)
        }
    }

    // ---------- QQ 深链编码 ----------

    @Test
    fun `Dart的encodeComponent保留未保留字符之外的百分号编码`() {
        // Dart Uri.encodeComponent：仅 A-Za-z0-9-_.!~*'() 不转义。
        assertEquals("a-b_c.d!e~f*g'h(i)", dartEncodeComponent("a-b_c.d!e~f*g'h(i)"))
        assertEquals("a%20b%2Bc%2Fd%3Fe%3Df%26g", dartEncodeComponent("a b+c/d?e=f&g"))
        assertEquals("%E8%BD%BB%E5%B1%BF", dartEncodeComponent("轻屿"))
    }

    @Test
    fun `QQ群深链由编码后的网页入群链接拼成`() {
        val web =
            "https://qm.qq.com/cgi-bin/qm/qr?from=app&p=android&jump_from=webapi&k=TMCg23sigjbqS5nYrBx0kxc7JcuwHN8Q"
        val encoded =
            "https%3A%2F%2Fqm.qq.com%2Fcgi-bin%2Fqm%2Fqr%3Ffrom%3Dapp%26p%3Dandroid%26jump_from%3Dwebapi%26k%3DTMCg23sigjbqS5nYrBx0kxc7JcuwHN8Q"
        assertEquals(
            "mqqopensdkapi://bizAgent/qm/qr?url=$encoded",
            FeedbackContact.qqGroupJoinAppUrl,
        )
        assertEquals(web, FeedbackContact.qqGroupJoinWebUrl)
    }

    // ---------- 打开语义（纯函数，launch 注入） ----------

    @Test
    fun `第一个URL能打开就不回落复制`() {
        val launched = mutableListOf<String>()
        val outcome = runFeedbackOpenPlan(
            plan = feedbackOpenPlanFor(buildFeedbackPageView().channels.first { it.id == "xiaohongshu" }),
            launch = { url ->
                launched += url
                true
            },
        )
        assertEquals(FeedbackOpenOutcome.Opened("https://xhslink.com/m/ALcscDMw39N"), outcome)
        assertEquals(listOf("https://xhslink.com/m/ALcscDMw39N"), launched)
    }

    @Test
    fun `第一个失败会继续试第二个`() {
        val launched = mutableListOf<String>()
        val outcome = runFeedbackOpenPlan(
            plan = feedbackOpenPlanFor(buildFeedbackPageView().channels.first { it.id == "coolapk" }),
            launch = { url ->
                launched += url
                !url.startsWith("https://")
            },
        )
        assertEquals(
            FeedbackOpenOutcome.Opened("coolmarket://www.coolapk.com/u/739248"),
            outcome,
        )
        assertEquals(2, launched.size)
    }

    @Test
    fun `全部失败才复制回落值并给黄色提示`() {
        val copied = mutableListOf<String>()
        val outcome = runFeedbackOpenPlan(
            plan = feedbackOpenPlanFor(buildFeedbackPageView().channels.first { it.id == "github" }),
            launch = { false },
            copy = { copied += it },
        )
        assertEquals(
            FeedbackOpenOutcome.CopiedFallback(
                value = "https://github.com/Mutx163/mikcb/issues",
                toast = "无法打开，已复制相关信息",
            ),
            outcome,
        )
        assertEquals(listOf("https://github.com/Mutx163/mikcb/issues"), copied)
    }

    @Test
    fun `空URL被跳过且不会调用launch`() {
        val launched = mutableListOf<String>()
        val outcome = runFeedbackOpenPlan(
            plan = FeedbackOpenPlan(
                openingToast = "正在打开……",
                preCopy = null,
                urls = listOf("", "https://example.com/x", ""),
                fallbackCopyValue = "fallback",
            ),
            launch = { url ->
                launched += url
                true
            },
        )
        assertEquals(FeedbackOpenOutcome.Opened("https://example.com/x"), outcome)
        assertEquals(listOf("https://example.com/x"), launched)
    }

    @Test
    fun `微信渠道先复制名称再尝试打开`() {
        val events = mutableListOf<String>()
        val outcome = runFeedbackOpenPlan(
            plan = feedbackOpenPlanFor(buildFeedbackPageView().channels.first { it.id == "wechat" }),
            launch = { url ->
                events += "launch:$url"
                false
            },
            copy = { value -> events += "copy:$value" },
        )
        // 先复制名称一次；打开失败后回落再复制一次（Dart 的 _openChannel 回落语义）。
        assertEquals(
            listOf("copy:轻屿课表", "launch:weixin://", "copy:轻屿课表"),
            events,
        )
        assertEquals(
            FeedbackOpenOutcome.CopiedFallback(
                value = "轻屿课表",
                toast = "无法打开，已复制相关信息",
            ),
            outcome,
        )
    }

    // ---------- 提示语时机（Dart 的顺序：先说「正在打开」，再说结果） ----------

    @Test
    fun `微信渠道顺序是复制名称再提示再拉起`() {
        val events = mutableListOf<String>()
        val outcome = runFeedbackOpenPlan(
            plan = feedbackOpenPlanFor(buildFeedbackPageView().channels.first { it.id == "wechat" }),
            launch = { url ->
                events += "launch:$url"
                true
            },
            copy = { value -> events += "copy:$value" },
            notify = { message -> events += "notify:$message" },
        )
        // 拉起成功的口径：先复制名称（微信里要粘贴），再提示（此时本 App 还在前台），
        // 最后才把微信拉起来；成功**不再**复制回落值。
        assertEquals(
            listOf(
                "copy:轻屿课表",
                "notify:已复制公众号名称，请到微信中粘贴搜索",
                "launch:weixin://",
            ),
            events,
        )
        assertEquals(FeedbackOpenOutcome.Opened("weixin://"), outcome)
    }

    @Test
    fun `全部失败时先提示正在打开再提示已复制`() {
        val events = mutableListOf<String>()
        runFeedbackOpenPlan(
            plan = feedbackOpenPlanFor(buildFeedbackPageView().channels.first { it.id == "qq" }),
            launch = { false },
            copy = { value -> events += "copy:$value" },
            notify = { message -> events += "notify:$message" },
        )
        assertEquals(
            listOf(
                "notify:正在打开……",
                "copy:1077077989",
                "notify:无法打开，已复制相关信息",
            ),
            events,
        )
    }

    // ---------- scheme 白名单（与 MainActivity 的 launch_url 同口径） ----------

    @Test
    fun `反馈渠道用到的URL都在白名单内`() {
        for (channel in buildFeedbackPageView().channels) {
            for (url in channel.urls) {
                assertTrue("渠道 ${channel.id} 的 URL 不在白名单：$url", FeedbackLaunchRules.isAllowed(url))
            }
        }
    }

    @Test
    fun `危险scheme一律拒绝`() {
        val blocked = listOf(
            "javascript:alert(1)",
            "file:///sdcard/x.txt",
            "content://com.other/secret",
            "data:text/html,<b>x</b>",
            "intent://scan/#Intent;end",
            "",
            "根本就没有冒号",
            "weixin", // 没有 ://，不是可拉起地址
        )
        for (url in blocked) {
            assertTrue("本该拒绝：$url", !FeedbackLaunchRules.isAllowed(url))
        }
        assertEquals("weixin", FeedbackLaunchRules.schemeOf("weixin://"))
        assertEquals("https", FeedbackLaunchRules.schemeOf("HTTPS://github.com/a"))
    }

    /**
     * 与 `MainActivity` 的 `ALLOWED_LAUNCH_SCHEMES` 逐字对拍。
     *
     * 两条通道（Flutter 的 `launch_url` 与 Compose 宿主的直连 Intent）必须同口径：
     * 一边放宽/收紧而另一边没跟上，用户看到的就是「点了没反应」或「白名单形同虚设」。
     * 这条守卫读源码文本（反射拿不到 private const 的值语义上的同源关系）。
     */
    @Test
    fun `白名单与MainActivity逐字一致`() {
        val candidates = listOf(
            File("android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt"),
            File("app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt"),
            File("../android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt"),
            File("../../android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 MainActivity.kt，工作目录=${File(".").absolutePath}")
        val text = file.readText(Charsets.UTF_8)
        val block = Regex(
            """ALLOWED_LAUNCH_SCHEMES\s*=\s*setOf\(([^)]*)\)""",
        ).find(text)?.groupValues?.get(1)
            ?: error("MainActivity.kt 里没找到 ALLOWED_LAUNCH_SCHEMES（守卫不许静默跳过）")
        val declared = Regex(""""([a-z]+)"""").findAll(block).map { it.groupValues[1] }.toSet()
        assertTrue("MainActivity 的白名单解析为空，正则可能失效", declared.size >= 5)
        assertEquals(
            "MainActivity 的 ALLOWED_LAUNCH_SCHEMES 与 FeedbackLaunchRules.allowedSchemes 不一致",
            declared,
            FeedbackLaunchRules.allowedSchemes,
        )
    }

    // ---------- ARB 逐字对拍 ----------

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../lib/l10n/app_zh.arb"),
            File("../lib/l10n/app_zh.arb"),
            File("lib/l10n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 lib/l10n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    @Test
    fun `普通文案与ARB逐字一致`() {
        val pairs = listOf(
            "feedbackTitle" to FeedbackStrings.title,
            "githubIssueTitle" to FeedbackStrings.githubIssueTitle,
            "githubIssueSubtitle" to FeedbackStrings.githubIssueSubtitle,
            "copiedIssueAddress" to FeedbackStrings.copiedIssueAddress,
            "copiedXiaohongshuId" to FeedbackStrings.copiedXiaohongshuId,
            "copiedCoolapkId" to FeedbackStrings.copiedCoolapkId,
            "copiedQqGroupId" to FeedbackStrings.copiedQqGroupId,
            "copiedWechatOaName" to FeedbackStrings.copiedWechatOaName,
            "feedbackWechatOaOpenHint" to FeedbackStrings.wechatOaOpenHint,
            "feedbackOpeningChannel" to FeedbackStrings.openingChannel,
            "feedbackOpenChannelFailed" to FeedbackStrings.openChannelFailed,
            "feedbackXiaohongshuTitle" to FeedbackStrings.xiaohongshuTitle,
            "feedbackCoolapkTitle" to FeedbackStrings.coolapkTitle,
            "feedbackQqGroupTitle" to FeedbackStrings.qqGroupTitle,
            "feedbackWechatOaTitle" to FeedbackStrings.wechatOaTitle,
        )
        for ((key, value) in pairs) {
            assertEquals("ARB 键 $key 与模型不一致", arbString(key), value)
        }
    }

    @Test
    fun `带参文案与ARB占位符一致`() {
        assertEquals(
            arbString("feedbackXiaohongshuSubtitle").replace("{id}", FeedbackContact.xiaohongshuId),
            FeedbackStrings.xiaohongshuSubtitle(FeedbackContact.xiaohongshuId),
        )
        assertEquals(
            arbString("feedbackCoolapkSubtitle").replace("{id}", FeedbackContact.coolapkId),
            FeedbackStrings.coolapkSubtitle(FeedbackContact.coolapkId),
        )
        assertEquals(
            arbString("feedbackQqGroupSubtitle").replace("{id}", FeedbackContact.qqGroupId),
            FeedbackStrings.qqGroupSubtitle(FeedbackContact.qqGroupId),
        )
        assertEquals(
            arbString("feedbackWechatOaSubtitle").replace("{name}", FeedbackContact.wechatOaName),
            FeedbackStrings.wechatOaSubtitle(FeedbackContact.wechatOaName),
        )
    }

    @Test
    fun `品牌图标资产路径记录齐备留Phase4对齐`() {
        // 原 Flutter 资产路径必须被记下来，否则 Phase 4 换真图标时对不上账。
        val channels = buildFeedbackPageView().channels
        assertEquals(
            "assets/branding/github.svg",
            channels.first { it.id == "github" }.badge.assetPath,
        )
        assertEquals(
            "assets/branding/xiaohongshu.svg",
            channels.first { it.id == "xiaohongshu" }.badge.assetPath,
        )
        assertEquals(
            "assets/branding/coolapk.png",
            channels.first { it.id == "coolapk" }.badge.assetPath,
        )
        assertEquals(
            "assets/branding/qq.svg",
            channels.first { it.id == "qq" }.badge.assetPath,
        )
        assertTrue(channels.first { it.id == "wechat" }.badge.assetPath.isNotEmpty())
    }
}
