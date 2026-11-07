package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入失败/脚本状态的**渲染契约**（2026-11-05）。
 *
 * 钉两件事：
 *
 * 1. [warehouseLoadIssueOf] 的四档映射**不许有「不知道」这一档**——页面拿到 null 就只能退回通用标题；
 * 2. [warehouseScriptStatusOf] 的四态分类（尤其「全空白」必须落 `Empty`，不能出现 `Loaded(0)`）。
 *
 * 这两条是纯函数，与网络、时钟都无关，所以测试也不该有时间/机器依赖。
 */
class WarehouseLoadIssueTest {

    private fun failed(
        code: String,
        transport: WarehouseTransportFailure = WarehouseTransportFailure.UNKNOWN,
        attempts: Int = 3,
    ) = WarehouseLoad.Failed(code = code, attempts = attempts, transport = transport)

    // ── 1. 四档映射 ─────────────────────────────────────────────────────

    @Test
    fun `网不通码直接落网不通档`() {
        assertEquals(
            WarehouseLoadIssue.NETWORK_UNREACHABLE,
            warehouseLoadIssueOf(failed(WarehouseFeedCodes.NETWORK_UNREACHABLE)),
        )
    }

    @Test
    fun `索引与脚本内容不合法落格式档`() {
        val contentCodes = listOf(
            WarehouseFeedCodes.NO_SCHOOLS,
            WarehouseFeedCodes.NO_ADAPTERS,
            WarehouseFeedCodes.SCRIPT_EMPTY,
            WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED,
            WarehouseFeedCodes.SCRIPT_PATH_MISSING,
        )
        for (code in contentCodes) {
            assertEquals(
                "$code 属于内容问题，不是网络问题",
                WarehouseLoadIssue.INVALID_FORMAT,
                warehouseLoadIssueOf(failed(code)),
            )
        }
    }

    @Test
    fun `候选全失败且最后一次是超时 落超时档`() {
        for (code in listOf(WarehouseFeedCodes.FETCH_FAILED_MIRROR, WarehouseFeedCodes.FETCH_FAILED_GITHUB)) {
            assertEquals(
                "$code 的超时是慢失败（网通但服务拖），要单独一档",
                WarehouseLoadIssue.TIMEOUT,
                warehouseLoadIssueOf(failed(code, transport = WarehouseTransportFailure.TIMEOUT)),
            )
        }
    }

    @Test
    fun `非超时的传输失败落仓库全挂档`() {
        val others = listOf(
            WarehouseTransportFailure.UNKNOWN,
            WarehouseTransportFailure.DNS,
            WarehouseTransportFailure.CONNECT_REFUSED,
            WarehouseTransportFailure.TLS,
            WarehouseTransportFailure.IO,
        )
        for (transport in others) {
            assertEquals(
                "$transport 不是慢失败，别报成超时",
                WarehouseLoadIssue.MIRRORS_FAILED,
                warehouseLoadIssueOf(failed(WarehouseFeedCodes.FETCH_FAILED_MIRROR, transport = transport)),
            )
        }
    }

    @Test
    fun `没见过的码也必须有档 绝不给 unknown`() {
        // 兜底档是「仓库全挂」：它最保守（让用户重试/换渠道），也不会像 format 那样让人去找适配仓背锅。
        assertEquals(
            WarehouseLoadIssue.MIRRORS_FAILED,
            warehouseLoadIssueOf(failed("warehouse_some_future_code")),
        )
    }

    @Test
    fun `toLoadFailed 三个字段都填满且 issue 恒非空`() {
        val converted = failed(
            WarehouseFeedCodes.FETCH_FAILED_MIRROR,
            transport = WarehouseTransportFailure.TIMEOUT,
            attempts = 4,
        ).toLoadFailed()

        assertEquals(WarehouseFeedCodes.FETCH_FAILED_MIRROR, converted.code)
        assertEquals(4, converted.attempts)
        assertEquals(WarehouseLoadIssue.TIMEOUT, converted.issue)
    }

    // ── 2. 脚本状态四态 ─────────────────────────────────────────────────

    @Test
    fun `脚本有内容报长度`() {
        val status = warehouseScriptStatusOf(WarehouseLoad.Ok(value = "abcde", url = "u", attempts = 1))
        assertEquals(WarehouseScriptStatus.Loaded(5), status)
    }

    @Test
    fun `脚本全空白算空态 不许报成 Loaded(0)`() {
        val status = warehouseScriptStatusOf(WarehouseLoad.Ok(value = " \n\t ", url = "u", attempts = 1))
        assertEquals(WarehouseScriptStatus.Empty, status)
    }

    @Test
    fun `脚本拉取失败带上 issue 供页面出人话`() {
        val status = warehouseScriptStatusOf(
            failed(WarehouseFeedCodes.FETCH_FAILED_MIRROR, transport = WarehouseTransportFailure.TIMEOUT),
        )
        assertTrue("必须是 Failed 态", status is WarehouseScriptStatus.Failed)
        val failedStatus = status as WarehouseScriptStatus.Failed
        assertEquals(WarehouseFeedCodes.FETCH_FAILED_MIRROR, failedStatus.code)
        assertEquals(WarehouseLoadIssue.TIMEOUT, failedStatus.issue)
    }

    @Test
    fun `脚本校验失败是内容问题 不是网络问题`() {
        val status = warehouseScriptStatusOf(failed(WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED))
        assertEquals(
            WarehouseScriptStatus.Failed(
                code = WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED,
                issue = WarehouseLoadIssue.INVALID_FORMAT,
            ),
            status,
        )
    }

    // ── 3. 四档原因 → 屏上一句人话 ──────────────────────────────────────
    //
    // 四档各有一句 ARB 原文（2026-11-05 落地）。这里逐字钉住渲染结果：
    // 文案被改写、被换成别域的句子、或者缓存场景说错话（格式错也报「网络不太顺畅」）都会红。

    @Test
    fun `仓库全挂档把试过的线路数填进人话`() {
        val text = warehouseLoadIssueText(
            WarehouseLoadFailed(
                code = WarehouseFeedCodes.FETCH_FAILED_MIRROR,
                attempts = 4,
                issue = WarehouseLoadIssue.MIRRORS_FAILED,
            ),
        )
        assertEquals("无法连接适配仓，已尝试 4 条线路，请检查网络或切换镜像线路", text)
    }

    @Test
    fun `零候选时不显示已尝试 0 条线路`() {
        // 脚本地址拼不出来这类 0 候选情形，硬填进模板就是病句：宁可不显示这句。
        assertNull(
            warehouseLoadIssueText(
                WarehouseLoadFailed(
                    code = WarehouseFeedCodes.SCRIPT_PATH_MISSING,
                    attempts = 0,
                    issue = WarehouseLoadIssue.MIRRORS_FAILED,
                ),
            ),
        )
    }

    @Test
    fun `网不通超时内容格式 三档各有自己的一句话`() {
        listOf(
            WarehouseLoadIssue.NETWORK_UNREACHABLE to "网络不可用，请检查网络或代理后重试",
            WarehouseLoadIssue.TIMEOUT to "适配仓响应太慢，请换个网络或稍后再试",
            WarehouseLoadIssue.INVALID_FORMAT to "适配仓返回的内容无法识别，请反馈给适配仓维护者",
        ).forEach { (issue, expected) ->
            assertEquals(
                issue.toString(),
                expected,
                warehouseLoadIssueText(WarehouseLoadFailed(code = "warehouse_x", attempts = 3, issue = issue)),
            )
        }
    }

    @Test
    fun `名单还在时说下面显示的是上次加载的列表`() {
        // 用户手上有能用的名单，就不把「已尝试 N 条线路」这类细节压给他。
        assertEquals(
            "网络不太顺畅，下面显示的是上次加载的列表",
            warehouseLoadIssueText(
                WarehouseLoadFailed(
                    code = WarehouseFeedCodes.FETCH_FAILED_MIRROR,
                    attempts = 4,
                    issue = WarehouseLoadIssue.MIRRORS_FAILED,
                ),
                showingCachedList = true,
            ),
        )
    }

    @Test
    fun `内容格式错即使名单还在 也不许说网络不太顺畅`() {
        // 这不是网络的事：说「网络不太顺畅」就是假话，缓存场景一样要用格式错那句。
        assertEquals(
            "适配仓返回的内容无法识别，请反馈给适配仓维护者",
            warehouseLoadIssueText(
                WarehouseLoadFailed(
                    code = WarehouseFeedCodes.NO_ADAPTERS,
                    attempts = 1,
                    issue = WarehouseLoadIssue.INVALID_FORMAT,
                ),
                showingCachedList = true,
            ),
        )
    }

    @Test
    fun `issue 为 null 时 没有名单就不说原因 有名单才说上面是旧的`() {
        val unknown = WarehouseLoadFailed(code = "warehouse_x", attempts = 3, issue = null)
        assertNull("没有档位就别猜原因", warehouseLoadIssueText(unknown))
        assertEquals(
            "名单还在但说不清原因时，只交代「这是上次的」",
            "网络不太顺畅，下面显示的是上次加载的列表",
            warehouseLoadIssueText(unknown, showingCachedList = true),
        )
    }
}
