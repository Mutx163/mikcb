package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.pages.shell.HomeBackgroundModel.InkBands
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 亮度带落盘编码（[HomeInkBandsCodec]）。
 *
 * 为什么单独测：编码坏了不会崩，只会让冷启动一直读不到带子、坞继续白字压亮壁纸——
 * 表现与「没落盘」一模一样，只有这里能把「写进去了但读不出来」钉住。
 */
class HomeInkBandsCodecTest {

    @Test
    fun `四档完整时原样往返`() {
        val bands = InkBands(top = 0.05, weekday = 0.18, body = 0.52, dock = 0.61)
        assertEquals(bands, HomeInkBandsCodec.decode(HomeInkBandsCodec.encode(bands)))
    }

    @Test
    fun `缺失项保持 null 不猜`() {
        val bands = InkBands(top = 0.05, weekday = null, body = 0.52, dock = null)
        assertEquals(bands, HomeInkBandsCodec.decode(HomeInkBandsCodec.encode(bands)))
    }

    @Test
    fun `坏数据一律当未命中`() {
        assertNull(HomeInkBandsCodec.decode(null))
        assertNull(HomeInkBandsCodec.decode(""))
        assertNull(HomeInkBandsCodec.decode("0.1,0.2"))
        assertNull(HomeInkBandsCodec.decode("a,b,c,d"))
        // 四项全空没有可用信息：宁可回「未知」，也不拿全 null 的带子去判墨。
        assertNull(HomeInkBandsCodec.decode(",,,"))
    }

    @Test
    fun `非有限值与越界值整条作废`() {
        // NaN 穿透到 DockInkRule 会让 `NaN < 0.45` 永远为 false ⇒ 永远近黑字，且磁盘不自愈。
        assertNull(HomeInkBandsCodec.decode("0.1,NaN,0.3,0.4"))
        assertNull(HomeInkBandsCodec.decode("0.1,Infinity,0.3,0.4"))
        assertNull(HomeInkBandsCodec.decode("0.1,-Infinity,0.3,0.4"))
        // 越界值同样不信任：宁可重新量，也不拿夹过的值当「已知真值」。
        assertNull(HomeInkBandsCodec.decode("0.1,-0.2,0.3,0.4"))
        assertNull(HomeInkBandsCodec.decode("0.1,0.2,0.3,1.5"))
    }

    @Test
    fun `全空编码读不回来 不该落盘`() {
        val allNull = InkBands(top = null, weekday = null, body = null, dock = null)
        val encoded = HomeInkBandsCodec.encode(allNull)
        assertEquals(",,,", encoded)
        assertNull(HomeInkBandsCodec.decode(encoded))
    }

    @Test
    fun `尾随空格与多段一律当坏数据`() {
        assertNull(HomeInkBandsCodec.decode("0.1,0.2,0.3,0.4 "))
        assertNull(HomeInkBandsCodec.decode("0.1,0.2,0.3,0.4,"))
    }
}
