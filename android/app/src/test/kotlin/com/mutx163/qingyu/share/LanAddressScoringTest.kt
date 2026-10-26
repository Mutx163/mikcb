package com.mutx163.qingyu.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 局域网地址打分端口测试。
 * dart 源：lib/services/lan_edit_network_utils.dart（score/过滤/排序）。
 * 期望值人推：环回与 169.254 丢弃；192.168 > 10/172.16-31 > 其他；同分保序；空集 null。
 */
class LanAddressScoringTest {

    @Test fun `打分口径`() {
        assertEquals(3, LanAddressScoring.scoreLanIPv4("192.168.1.5"))
        assertEquals(3, LanAddressScoring.scoreLanIPv4("192.168.0.1"))
        assertEquals(2, LanAddressScoring.scoreLanIPv4("10.0.0.8"))
        assertEquals(2, LanAddressScoring.scoreLanIPv4("172.16.0.2"))
        assertEquals(2, LanAddressScoring.scoreLanIPv4("172.31.255.1"))
        // 172.16-31 之外按普通公网处理。
        assertEquals(1, LanAddressScoring.scoreLanIPv4("172.15.0.1"))
        assertEquals(1, LanAddressScoring.scoreLanIPv4("172.32.0.1"))
        assertEquals(1, LanAddressScoring.scoreLanIPv4("8.8.8.8"))
        assertEquals(1, LanAddressScoring.scoreLanIPv4("100.64.0.1"))
    }

    @Test fun `环回与链路本地不展示`() {
        assertFalse(LanAddressScoring.isPresentable("127.0.0.1"))
        assertFalse(LanAddressScoring.isPresentable("169.254.10.20"))
        assertTrue(LanAddressScoring.isPresentable("192.168.1.5"))
        assertTrue(LanAddressScoring.isPresentable("10.0.0.8"))
    }

    @Test fun `选分最高者同分保原序`() {
        assertEquals(
            "192.168.1.5",
            LanAddressScoring.pickPreferredLanIPv4(
                listOf("10.0.0.8", "192.168.1.5", "8.8.8.8"),
            ),
        )
        // 10.* 与 172.16.* 同分：谁先出现选谁（Dart 稳定排序同口径）。
        assertEquals(
            "10.0.0.8",
            LanAddressScoring.pickPreferredLanIPv4(listOf("10.0.0.8", "172.16.0.2")),
        )
        assertEquals(
            "172.16.0.2",
            LanAddressScoring.pickPreferredLanIPv4(listOf("172.16.0.2", "10.0.0.8")),
        )
    }

    @Test fun `不可展示地址被滤掉`() {
        assertEquals(
            "192.168.1.5",
            LanAddressScoring.pickPreferredLanIPv4(
                listOf("127.0.0.1", "169.254.10.20", "192.168.1.5"),
            ),
        )
        assertNull(LanAddressScoring.pickPreferredLanIPv4(emptyList()))
        assertNull(LanAddressScoring.pickPreferredLanIPv4(listOf("127.0.0.1", "169.254.1.1")))
    }
}
