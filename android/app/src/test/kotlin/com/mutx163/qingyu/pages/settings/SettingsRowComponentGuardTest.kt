package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置行**组件选型守卫**：确保模型层记录的官方组件名，与渲染层真的 import 的一致。
 *
 * ## 为什么要这条（2026-10-27 的真实事故）
 *
 * 本批第一版渲染层是按 miuix **0.8.8** 的包名写的：整套设置行在
 * `top.yukonga.miuix.kmp.extra` 的 `Super*` 家族里。后来依赖升到 **0.9.4**，
 * 0.9.4 模块化发布后 `extra` 包**整个消失**，官方改成独立的 `miuix-preference`
 * 模块，类名变为 `preference.{Arrow,Switch,Slider,OverlayDropdown,RadioButton,Checkbox}Preference`。
 *
 * 结果就是：那 3,821 行代码写完 15 小时、**一次都没有编译通过**，而且没人发现——
 * 因为当时没有任何变体把 `pages/settings` 挂进编译链（`build.gradle` 的源集问题）。
 * 等挂进去、真去编了，才炸出 `Unresolved reference 'extra'`。
 *
 * 这条守卫把「模型层声称用哪个组件」与「渲染层真的 import 哪个」钉在一起：
 * 版本再升级、包名再变，这里会先红，而不是等到某个平行会话恰好去编译才发现。
 *
 * ## 它读文件，所以要做纪律上的两件事
 *
 * 1. 路径从工作目录向上找 `android/`，不写死盘符（测试可能在 CI 跑）；
 * 2. 找不到文件时**失败而不是跳过** —— 跳过等于这条守卫不存在。
 */
class SettingsRowComponentGuardTest {

    /** 从当前工作目录向上找 `android/app/src`，兼容 Gradle（在 android/ 跑）与 IDE。 */
    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private fun renderersFile(): File =
        File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )

    @Test
    fun `渲染层不再引用 miuix 0_8_8 的 extra 包`() {
        val source = renderersFile()
        assertTrue("渲染层文件不存在：${source.path}", source.isFile)
        val text = source.readText()

        // 0.9.4 起 `top.yukonga.miuix.kmp.extra` 整体不存在，任何残留 import 都是编译错误。
        val leftovers = text.lines()
            .withIndex()
            .filter { (_, line) -> line.trimStart().startsWith("import") && "miuix.kmp.extra" in line }
            .map { (i, line) -> "第 ${i + 1} 行：${line.trim()}" }

        assertTrue(
            "渲染层还在 import 0.9.4 已删除的 `miuix.kmp.extra` 包（会导致 Unresolved reference）：\n" +
                leftovers.joinToString("\n"),
            leftovers.isEmpty(),
        )
    }

    @Test
    fun `每个行组件在渲染层都真的 import 了对应的官方组件`() {
        val text = renderersFile().readText()

        // 模型层的 composeP1Component 写的是 `preference.XxxPreference` 这种短路径，
        // 这里把它和渲染层实际 import 的符号对齐：模型说用谁，渲染层就必须 import 谁。
        val expectedImports = MiuixRowComponent.entries
            .filter { it != MiuixRowComponent.COLOR_SWATCH } // 颜色行复用 ARROW 的行体
            .associateWith { it.composeP1Component }

        val missing = expectedImports.filter { (_, component) ->
            // component 形如 "preference.ArrowPreference"
            val symbol = component.substringAfterLast('.')
            val fullImport = "import top.yukonga.miuix.kmp.preference.$symbol"
            fullImport !in text
        }

        assertTrue(
            "模型层声称使用、但渲染层没有 import 的组件：\n" +
                missing.entries.joinToString("\n") { (row, comp) ->
                    "  $row → $comp（缺 import top.yukonga.miuix.kmp.preference." +
                        "${comp.substringAfterLast('.')}）"
                },
            missing.isEmpty(),
        )
    }

    @Test
    fun `模型层的组件名不再写着 0_8_8 的 Super 家族`() {
        // 防止有人「顺手」把对照表改回 0.8.8 时代的写法——那会让下一个人照它写错代码。
        val stale = MiuixRowComponent.entries
            .filter { "Super" in it.composeP1Component && "extra." in it.composeP1Component }
            .map { "${it.name} → ${it.composeP1Component}" }

        assertEquals(
            "模型层还在用 0.8.8 的 Super* 组件名（0.9.4 已删除）：\n" + stale.joinToString("\n"),
            emptyList<String>(),
            stale,
        )
    }
}
