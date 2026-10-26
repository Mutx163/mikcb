package com.mutx163.qingyu.weather

import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.abs

/**
 * coarsenCoordinate（经纬度统一取整到 2 位小数，约 1.1 km）。
 *
 * 期望值来源：[Dart抄录] test/services/weather_service_test.dart 的
 * 「坐标出网/落盘取整」组 —— 那组期望值由「选城市的结果会被直接落盘 +
 * 隐私说明（坐标仅以约 1 公里精度保存）」推出，不是从实现抄的。
 */
class CoordinatePrecisionTest {

    @Test
    fun `coarsen rounds to two decimals like dart`() { // [Dart抄录] weather_service_test:626-629
        assertEquals(30.29, coarsenCoordinate(30.29365), 1e-12)
        assertEquals(120.16, coarsenCoordinate(120.16142), 1e-12)
        assertEquals(-100.0, coarsenCoordinate(-99.999), 1e-12)
        assertEquals(0.0, coarsenCoordinate(0.0), 1e-12)
    }

    @Test
    fun `geocoding results carry the coarsened precision`() { // [Dart抄录] weather_service_test:291-294
        assertEquals(30.07, coarsenCoordinate(30.06517), 1e-12)
        assertEquals(102.2, coarsenCoordinate(102.19527), 1e-12)
    }

    @Test
    fun `reverse geocode and ip geocode both coarsen`() { // [Dart抄录] weather_service_test:654-655, 675-676
        assertEquals(30.29, coarsenCoordinate(30.29365432), 1e-12)
        assertEquals(120.16, coarsenCoordinate(120.16123456), 1e-12)
        assertEquals(30.57, coarsenCoordinate(30.572815), 1e-12)
        assertEquals(104.07, coarsenCoordinate(104.066803), 1e-12)
    }

    @Test
    fun `forecast request coarsens defensively`() { // [Dart抄录] weather_service_test:700-701
        assertEquals(30.12, coarsenCoordinate(30.123456), 1e-12)
        assertEquals(120.99, coarsenCoordinate(120.987654), 1e-12)
    }

    @Test
    fun `half away from zero like dart roundToDouble`() { // [Dart推演] Dart roundToDouble 是半远离零
        // 2.5 * 100 = 250 精确可表示 → 2.5；0.005 边界受二进制表示影响不在此钉。
        assertEquals(2.5, coarsenCoordinate(2.5), 1e-12)
        assertEquals(-2.5, coarsenCoordinate(-2.5), 1e-12)
    }

    @Test
    fun `coarsening is idempotent`() { // [人推] 取整后再取整不变 —— 比对口径依赖这一点
        for (value in listOf(30.29365, 120.16142, -99.999, 0.0, 104.066803)) {
            val once = coarsenCoordinate(value)
            val twice = coarsenCoordinate(once)
            assertEquals(0.0, abs(once - twice), 0.0)
        }
    }
}
