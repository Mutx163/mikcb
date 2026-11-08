package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 取件码入口表的**自包含黄金对拍**（2026-11-08）。
 *
 * ## 为什么不再读 Dart
 *
 * 原用例读 `lib/domain/pickup_code_presets.dart` 做子串比对；去 Flutter 化 P4-C
 * 删除 Dart 层后该文件不存在，5 条用例变成必然红（`从工作目录找不到 …`）。
 * 现在把「点了有没有反应」所依赖的 URI / 包名 / 网页兜底固化成字面量：
 * 改一个百分号编码（`%2F`↔`%2f`、`%3F`↔`?`）、换一个包名、删一条兜底，这里都会红。
 *
 * 黄金值是**行为契约**，不是「从 Kotlin 再抄一遍」：改之前先确认为什么要改。
 */
class PickupCodePresetsGoldenTest {

    private data class LinkGolden(val uri: String, val packageName: String?)

    /** 七个入口、15 条直达链接、按界面顺序。 */
    private val expectedLinks: Map<String, List<LinkGolden>> = linkedMapOf(
        "pickupCodePresetCainiao" to listOf(
            LinkGolden("cainiao://desktop/station_code", "com.cainiao.wireless"),
            LinkGolden("cainiao://client.main", "com.cainiao.wireless"),
        ),
        "pickupCodePresetTaobao" to listOf(
            LinkGolden(
                "taobao://m.taobao.com/tbopen/index.html?h5Url=" +
                    "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                    "1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code" +
                    "%3Fx-ssr%3Dtrue",
                "com.taobao.taobao",
            ),
            LinkGolden(
                "tbopen://m.taobao.com/tbopen/index.html?h5Url=" +
                    "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                    "1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code" +
                    "%3Fx-ssr%3Dtrue",
                "com.taobao.taobao",
            ),
        ),
        "pickupCodePresetPinduoduo" to listOf(
            LinkGolden(
                "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE" +
                    "&entry_source=11&refer_page_name=login&refer_page_sn=10169",
                "com.xunmeng.pinduoduo",
            ),
            LinkGolden(
                "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE" +
                    "&entry_source=11",
                "com.xunmeng.pinduoduo",
            ),
            LinkGolden(
                "pinduoduo://com.xunmeng.pinduoduo/mdkd/package",
                "com.xunmeng.pinduoduo",
            ),
        ),
        "pickupCodePresetTaobaoParcels" to listOf(
            LinkGolden(
                "taobao://m.taobao.com/tbopen/index.html?h5Url=" +
                    "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                    "1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome",
                "com.taobao.taobao",
            ),
            LinkGolden(
                "tbopen://m.taobao.com/tbopen/index.html?h5Url=" +
                    "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                    "1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome",
                "com.taobao.taobao",
            ),
        ),
        "pickupCodePresetPinduoduoParcels" to listOf(
            LinkGolden(
                "pinduoduo://com.xunmeng.pinduoduo/mdkd/package",
                "com.xunmeng.pinduoduo",
            ),
        ),
        "pickupCodePresetJdParcels" to listOf(
            LinkGolden(
                "openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C" +
                    "%22des%22%3A%22orderlist%22%7D",
                "com.jingdong.app.mall",
            ),
        ),
        "pickupCodePresetDouyinParcels" to listOf(
            LinkGolden("snssdk1128://ecom_order_list", "com.ss.android.ugc.aweme"),
            LinkGolden("snssdk1128://wallet", "com.ss.android.ugc.aweme"),
            LinkGolden("snssdk2329://ecom_order_list", "com.ss.android.ugc.aweme.lite"),
            LinkGolden("snssdk2329://wallet", "com.ss.android.ugc.aweme.lite"),
        ),
    )

    @Test
    fun `七个入口的顺序_图标与分组固定`() {
        assertEquals(
            "入口 id 顺序就是界面顺序（身份码在前）",
            expectedLinks.keys.toList(),
            PickupCodesModel.presets.map { it.titleKey },
        )
        assertEquals(
            listOf("qrCode", "qrCode", "qrCode", "parcel", "parcel", "parcel", "parcel"),
            PickupCodesModel.presets.map { it.icon },
        )
        assertEquals(
            listOf(
                "IDENTITY", "IDENTITY", "IDENTITY",
                "PARCELS", "PARCELS", "PARCELS", "PARCELS",
            ),
            PickupCodesModel.presets.map { it.group.name },
        )
    }

    @Test
    fun `七条入口一共 15 条直达链接`() {
        assertEquals(15, expectedLinks.values.sumOf { it.size })
        assertEquals(
            "链接条数必须与黄金值一致（少一条 = 某个入口点不开）",
            expectedLinks.values.sumOf { it.size },
            PickupCodesModel.presets.sumOf { it.links.size },
        )
    }

    @Test
    fun `每条直达链接的 URI_顺序与包名逐字固定`() {
        val actual = PickupCodesModel.presets.associate { preset ->
            preset.titleKey to preset.links.map { LinkGolden(it.uri, it.packageName) }
        }
        assertEquals(
            "URI 的百分号编码、参数顺序、包名与链接顺序都必须与黄金值一致",
            expectedLinks,
            actual,
        )
    }

    @Test
    fun `网页兜底逐字固定`() {
        val expectedWeb = mapOf(
            "pickupCodePresetCainiao" to
                "https://market.m.taobao.com/app/cn-yz/multi-activity/authCode.html" +
                "?bizEntry=ALIPAY_GUOGUO",
            "pickupCodePresetTaobao" to
                "https://pages-fast.m.taobao.com/wow/z/uniapp/1011717/last-mile-fe/" +
                "end-collect-platform/identity-code?x-ssr=true",
            "pickupCodePresetPinduoduo" to
                "https://m.pinduoduo.net/mdkd/package?entry_source=18" +
                "&extra_params=from_wx_jump%3D1&p_channel=0",
            "pickupCodePresetTaobaoParcels" to
                "https://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/" +
                "m-end-school-tab/home",
            "pickupCodePresetPinduoduoParcels" to
                "https://m.pinduoduo.net/mdkd/package?entry_source=18" +
                "&extra_params=from_wx_jump%3D1&p_channel=0",
            "pickupCodePresetJdParcels" to "https://order.jd.com/center/list.action",
            "pickupCodePresetDouyinParcels" to
                "https://haohuo.jinritemai.com/views/order/list",
        )
        assertEquals(
            expectedWeb.keys.toList(),
            PickupCodesModel.presets.map { it.titleKey },
        )
        assertEquals(
            "网页兜底是「没装 App 也能用」的唯一退路，必须逐字一致",
            expectedWeb,
            PickupCodesModel.presets.associate { it.titleKey to it.webUri },
        )
    }

    @Test
    fun `网页兜底与 App 包名归属到正确入口`() {
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
        assertEquals(
            "包名归属错了会让「已安装/未安装」判到别的入口上",
            expectedApps,
            PickupCodesModel.presets.associate { it.titleKey to it.appPackages },
        )
    }

    @Test
    fun `官方 App 包名去重且保持首次出现顺序`() {
        assertEquals(
            listOf(
                "com.cainiao.wireless",
                "com.taobao.taobao",
                "com.xunmeng.pinduoduo",
                "com.jingdong.app.mall",
                "com.ss.android.ugc.aweme",
                "com.ss.android.ugc.aweme.lite",
            ),
            PickupCodesModel.allPackages(),
        )
    }

    @Test
    fun `未安装判据：查不到时按已安装处理`() {
        val preset = PickupCodesModel.presets.first()
        // null = 还没查到 / 查不到 ⇒ 不许把能点的入口标成「未安装」。
        assertTrue(PickupCodesModel.isInstalled(preset, null))
        assertTrue(PickupCodesModel.isInstalled(preset, setOf("com.cainiao.wireless")))
        assertFalse(PickupCodesModel.isInstalled(preset, emptySet()))
    }
}
