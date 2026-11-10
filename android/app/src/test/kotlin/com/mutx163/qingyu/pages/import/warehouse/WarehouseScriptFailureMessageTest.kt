package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「脚本加载失败 + 试过哪些源」文案（2026-11-10 P1）。
 *
 * 用户口径：失败后必须一眼看出**当前走的是哪个渠道、试过几条镜像**，不再是一句
 * 「脚本执行失败」。这里逐档钉住拼接口径（渠道 × 有/无镜像 × 试了几条）。
 *
 * 断言的是**屏上那句话**（`WarehouseStrings.*.text` 在未初始化语言时回落中文原文），
 * 与 ARB 中文原文逐字一致；ARB 键本身的存在性由 `WarehouseStringsParityTest` 守。
 */
class WarehouseScriptFailureMessageTest {

    private val githubOnly = WarehouseFetchOptions(preferGitCode = false, mirrorUrlPrefix = null)
    private val githubWithMirrors = WarehouseFetchOptions(preferGitCode = false, mirrorUrlPrefix = "https://mirror.example/")
    private val gitCodeWithMirrors = WarehouseFetchOptions(preferGitCode = true, mirrorUrlPrefix = "https://mirror.example/")
    private val gitCodeOnly = WarehouseFetchOptions(preferGitCode = true, mirrorUrlPrefix = null)

    @Test
    fun `GitHub 渠道 试过主地址与四个镜像`() {
        assertEquals(
            "无法读取适配器脚本：已尝试 GitHub 直连 + 4 个镜像",
            warehouseScriptLoadFailedMessage(githubWithMirrors, attempts = 5),
        )
    }

    @Test
    fun `GitHub 渠道 只试了主地址`() {
        assertEquals(
            "无法读取适配器脚本：已尝试 GitHub 直连",
            warehouseScriptLoadFailedMessage(githubWithMirrors, attempts = 1),
        )
    }

    @Test
    fun `GitCode 渠道 主地址与 raw 回退都试过`() {
        assertEquals(
            "无法读取适配器脚本：已尝试 GitCode 渠道 + GitHub 直连",
            warehouseScriptLoadFailedMessage(gitCodeWithMirrors, attempts = 2),
        )
    }

    @Test
    fun `GitCode 渠道 再加镜像`() {
        assertEquals(
            "无法读取适配器脚本：已尝试 GitCode 渠道 + GitHub 直连 + 3 个镜像",
            warehouseScriptLoadFailedMessage(gitCodeWithMirrors, attempts = 5),
        )
    }

    @Test
    fun `GitCode 渠道 只试到主地址`() {
        assertEquals(
            "无法读取适配器脚本：已尝试 GitCode 渠道",
            warehouseScriptLoadFailedMessage(gitCodeWithMirrors, attempts = 1),
        )
    }

    @Test
    fun `没开镜像时 不许说试过镜像`() {
        // `original` 渠道的候选链里根本没有镜像族；即使调用方传了更大的 attempts，
        // 也不能凭空写出「+ N 个镜像」（那是假话，用户会照着去换镜像）。
        assertEquals(
            "无法读取适配器脚本：已尝试 GitHub 直连",
            warehouseScriptLoadFailedMessage(githubOnly, attempts = 5),
        )
        assertEquals(
            "无法读取适配器脚本：已尝试 GitCode 渠道 + GitHub 直连",
            warehouseScriptLoadFailedMessage(gitCodeOnly, attempts = 9),
        )
    }

    @Test
    fun `零候选时退回原来那句`() {
        // 脚本路径都拼不出来（`script_path_missing`）时没有「源」可说，不显示「已尝试」。
        assertEquals(
            "无法读取适配器脚本",
            warehouseScriptLoadFailedMessage(githubWithMirrors, attempts = 0),
        )
        assertEquals(
            "无法读取适配器脚本",
            warehouseScriptLoadFailedMessage(gitCodeWithMirrors, attempts = 0),
        )
    }
}
