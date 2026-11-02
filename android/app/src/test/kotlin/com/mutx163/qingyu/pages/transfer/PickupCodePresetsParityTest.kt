package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 取件码入口表与 Dart 源**逐字对照**（`lib/domain/pickup_code_presets.dart`）。
 *
 * 为什么值得单独一条：这张表的每一条链接都是「点了有没有反应」的全部内容。
 * 随手改一个百分号编码（`%2F` 写成 `%2f` 也许还能用，`%3F` 写成 `?` 就不行）
 * 在 Kotlin 侧完全看不出来，只有真机点七下才知道 —— 而真机对照归用户，
 * 所以用「读 Dart 源做子串比对」把这类走样挡在提交前。
 *
 * 比对方式：把 Dart 源里的引号与空白全部去掉（Dart 用相邻字符串字面量拼长 URI，
 * 去掉这些之后才拼得回来），再断言 Kotlin 侧每条 URI / 包名都能在里面找到。
 */
class PickupCodePresetsParityTest {

    private val dartSource: String by lazy {
        repoFile("lib/domain/pickup_code_presets.dart").readText()
    }

    /** 去掉引号与空白：Dart 的长 URI 是多段字面量拼的，这样才还原成一条。 */
    private val normalizedDart: String by lazy {
        dartSource.filter { !it.isWhitespace() && it != '\'' }
    }

    private fun repoFile(relative: String): File {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.exists()) return candidate
            dir = dir.parentFile
        }
        throw AssertionError("从工作目录找不到 $relative")
    }

    @Test
    fun `七个入口的标题键与图标与 Dart 一致`() {
        // Dart `kPickupCodePresets` 的 id 顺序就是界面顺序（身份码在前）。
        val expectedIds = listOf(
            "pickupCodePresetCainiao",
            "pickupCodePresetTaobao",
            "pickupCodePresetPinduoduo",
            "pickupCodePresetTaobaoParcels",
            "pickupCodePresetPinduoduoParcels",
            "pickupCodePresetJdParcels",
            "pickupCodePresetDouyinParcels",
        )
        assertEquals(expectedIds, PickupCodesModel.presets.map { it.titleKey })
        assertEquals(
            listOf("qrCode", "qrCode", "qrCode", "parcel", "parcel", "parcel", "parcel"),
            PickupCodesModel.presets.map { it.icon },
        )
    }

    @Test
    fun `直达链接条数与 Dart 相同`() {
        // Dart 里每一条链接都是一个 `PickupCodeLink(`（15 条）。
        val dartLinkCount = Regex("PickupCodeLink\\(").findAll(dartSource).count()
        assertEquals(15, dartLinkCount)
        assertEquals(dartLinkCount, PickupCodesModel.presets.sumOf { it.links.size })
    }

    @Test
    fun `每条直达链接的 URI 与包名都能在 Dart 源里找到`() {
        for (preset in PickupCodesModel.presets) {
            assertTrue("${preset.titleKey} 一条直达链接都没有", preset.links.isNotEmpty())
            for (link in preset.links) {
                val uri = link.uri.filter { !it.isWhitespace() }
                assertTrue(
                    "${preset.titleKey} 的链接在 Dart 源里找不到：$uri",
                    normalizedDart.contains(uri),
                )
                val packageName = link.packageName
                if (packageName != null) {
                    assertTrue(
                        "${preset.titleKey} 的包名在 Dart 源里找不到：$packageName",
                        normalizedDart.contains(packageName),
                    )
                }
            }
        }
    }

    @Test
    fun `网页兜底链接与 Dart 一致`() {
        val webUris = PickupCodesModel.presets.mapNotNull { it.webUri }
        assertEquals("七个入口都应有网页兜底", 7, webUris.size)
        for (uri in webUris) {
            assertTrue("网页兜底在 Dart 源里找不到：$uri", normalizedDart.contains(uri))
        }
    }

    @Test
    fun `官方 App 包名与 Dart 一致且去重保持首次出现顺序`() {
        val dartPackages = listOf(
            "com.cainiao.wireless",
            "com.taobao.taobao",
            "com.xunmeng.pinduoduo",
            "com.jingdong.app.mall",
            "com.ss.android.ugc.aweme",
            "com.ss.android.ugc.aweme.lite",
        )
        assertEquals(dartPackages, PickupCodesModel.allPackages())
        for (packageName in dartPackages) {
            assertTrue("Dart 源里找不到包名 $packageName", normalizedDart.contains(packageName))
        }
    }

    @Test
    fun `网页兜底与 App 包名归属到正确入口`() {
        // 只断言「所有 URL 都能在 Dart 源里找到」抓不到两条例目互换；
        // 这里把「哪个入口该有哪条兜底 / 哪组包名」逐条钉住。
        val expectedWeb = mapOf(
            "pickupCodePresetCainiao" to "authCode.html",
            "pickupCodePresetTaobao" to "end-collect-platform/identity-code?x-ssr=true",
            "pickupCodePresetPinduoduo" to "m.pinduoduo.net/mdkd/package",
            "pickupCodePresetTaobaoParcels" to "m-end-school-tab/home",
            "pickupCodePresetPinduoduoParcels" to "m.pinduoduo.net/mdkd/package",
            "pickupCodePresetJdParcels" to "order.jd.com/center/list.action",
            "pickupCodePresetDouyinParcels" to "haohuo.jinritemai.com/views/order/list",
        )
        val expectedApps = mapOf(
            "pickupCodePresetCainiao" to listOf("com.cainiao.wireless"),
            "pickupCodePresetTaobao" to listOf("com.taobao.taobao"),
            "pickupCodePresetPinduoduo" to listOf("com.xunmeng.pinduoduo"),
            "pickupCodePresetTaobaoParcels" to listOf("com.taobao.taobao"),
            "pickupCodePresetPinduoduoParcels" to listOf("com.xunmeng.pinduoduo"),
            "pickupCodePresetJdParcels" to listOf("com.jingdong.app.mall"),
            "pickupCodePresetDouyinParcels" to
                listOf("com.ss.android.ugc.aweme", "com.ss.android.ugc.aweme.lite"),
        )
        for (preset in PickupCodesModel.presets) {
            val webNeedle = expectedWeb.getValue(preset.titleKey)
            assertTrue(
                "${preset.titleKey} 的网页兜底归属不对：${preset.webUri}",
                preset.webUri.orEmpty().contains(webNeedle),
            )
            assertEquals(
                "${preset.titleKey} 的 App 兜底包名不对",
                expectedApps.getValue(preset.titleKey),
                preset.appPackages,
            )
        }
    }

    @Test
    fun `未安装判据：查不到时按已安装处理`() {
        val preset = PickupCodesModel.presets.first()
        // null = 还没查到 / 查不到 ⇒ 不许把能点的入口标成「未安装」。
        assertTrue(PickupCodesModel.isInstalled(preset, null))
        assertTrue(PickupCodesModel.isInstalled(preset, setOf("com.cainiao.wireless")))
        assertTrue(!PickupCodesModel.isInstalled(preset, emptySet()))
    }
}
