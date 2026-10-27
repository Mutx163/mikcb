package com.mutx163.qingyu.pages.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 天气与城市选择模型层纯函数单测。
 *
 * 覆盖：
 * 1. 拼音匹配（全拼、前缀、首字母缩写）
 * 2. 中文名称与省份模糊检索及排序权重
 * 3. 空查询与无结果边缘处理
 * 4. 热门城市筛选与分组
 * 5. 定位状态变更与防重入守卫
 * 6. 格式化纯函数与模型校验规则
 */
class WeatherCityPickerModelTest {

    @Test
    fun `拼音全拼检索能精确匹配到对应城市`() {
        val results = searchCities("hangzhou")
        assertTrue("应能搜到杭州", results.any { it.name == "杭州" })
        assertEquals("第一位应为杭州", "杭州", results.first().name)

        val bjResults = searchCities("beijing")
        assertEquals("北京", bjResults.first().name)
    }

    @Test
    fun `拼音前缀检索能匹配到城市`() {
        val results = searchCities("shang")
        assertTrue("shang 前缀应匹配上海", results.any { it.name == "上海" })
        assertEquals("第一位应为上海", "上海", results.first().name)

        val cdResults = searchCities("cheng")
        assertTrue("cheng 前缀应匹配成都", cdResults.any { it.name == "成都" })
    }

    @Test
    fun `拼音首字母缩写能准确检索到对应城市`() {
        val bj = searchCities("bj")
        assertTrue("bj 应检索到北京", bj.any { it.name == "北京" })

        val hz = searchCities("hz")
        assertTrue("hz 应检索到杭州", hz.any { it.name == "杭州" })

        val gz = searchCities("gz")
        assertTrue("gz 应检索到广州", gz.any { it.name == "广州" })

        val sz = searchCities("sz")
        val names = sz.map { it.name }
        assertTrue("sz 应检索到深圳或苏州", names.contains("深圳") || names.contains("苏州"))
    }

    @Test
    fun `中文名称全词匹配与模糊包含检索`() {
        val exact = searchCities("广州")
        assertEquals(1, exact.size)
        assertEquals("广州", exact.first().name)

        val zhouResults = searchCities("州")
        val zhouNames = zhouResults.map { it.name }
        assertTrue("包含'州'的城市应包含杭州、广州、郑州、福州、苏州",
            zhouNames.containsAll(listOf("杭州", "广州", "郑州", "福州", "苏州")))
    }

    @Test
    fun `输入省份名称能检索到该省所辖城市`() {
        val zjResults = searchCities("浙江")
        assertTrue("输入浙江应检索到杭州", zjResults.any { it.name == "杭州" })

        val scResults = searchCities("四川")
        assertTrue("输入四川应检索到成都", scResults.any { it.name == "成都" })
    }

    @Test
    fun `空输入与空格输入返回空列表`() {
        assertTrue(searchCities("").isEmpty())
        assertTrue(searchCities("   ").isEmpty())
        assertTrue(searchCities("\t\n").isEmpty())
    }

    @Test
    fun `不存在的查询词返回空列表`() {
        val results = searchCities("xyz9999nonexistent")
        assertTrue(results.isEmpty())
    }

    @Test
    fun `热门城市列表筛选正确且均为热门标记`() {
        assertTrue("热门城市数量应不少于 6 个", DEFAULT_HOT_CITIES.size >= 6)
        for (city in DEFAULT_HOT_CITIES) {
            assertTrue("热门城市 isHot 必须为 true: ${city.name}", city.isHot)
        }
        val names = DEFAULT_HOT_CITIES.map { it.name }
        assertTrue("应包含主要核心大城市", names.containsAll(listOf("北京", "上海", "广州", "深圳", "杭州", "成都")))
    }

    @Test
    fun `onQueryChanged 能正确驱动状态与搜索结果刷新`() {
        val init = CityPickerState()
        assertEquals("", init.query)
        assertTrue(init.searchResults.isEmpty())

        val state1 = onQueryChanged(init, "武汉")
        assertEquals("武汉", state1.query)
        assertEquals(1, state1.searchResults.size)
        assertEquals("武汉", state1.searchResults.first().name)

        val state2 = onQueryChanged(state1, "")
        assertEquals("", state2.query)
        assertTrue(state2.searchResults.isEmpty())
    }

    @Test
    fun `选中城市纯函数能正确更新选值`() {
        val init = CityPickerState()
        val chengdu = DEFAULT_CITIES.first { it.id == "chengdu" }
        val updated = onSelectCity(init, chengdu)
        assertEquals("成都", updated.selectedCity?.name)
    }

    @Test
    fun `定位状态机流转与防重入守卫`() {
        val init = CityPickerState()
        assertFalse(init.isLocating)
        assertTrue(canStartLocating(init))

        // 1. 发起定位
        val locatingState = onStartLocating(init)
        assertTrue(locatingState.isLocating)
        assertNull(locatingState.locationError)
        assertFalse(canStartLocating(locatingState))

        // 防重入守卫：定位中再次触发应当幂等
        val retrigger = onStartLocating(locatingState)
        assertTrue(retrigger.isLocating)

        // 2. 定位失败回填
        val failedState = onLocateFailure(locatingState, "定位超时，请稍后再试")
        assertFalse(failedState.isLocating)
        assertEquals("定位超时，请稍后再试", failedState.locationError)
        assertTrue(canStartLocating(failedState))

        // 3. 定位成功回填
        val beijing = DEFAULT_CITIES.first { it.id == "beijing" }
        val successState = onLocateSuccess(locatingState, beijing)
        assertFalse(successState.isLocating)
        assertNull(successState.locationError)
        assertEquals("北京", successState.currentLocatedCity?.name)
        assertEquals("北京", successState.selectedCity?.name)
    }

    @Test
    fun `城市模型有效性守卫判定`() {
        assertFalse("null 不是有效城市", isValidCity(null))
        assertFalse("空 id 不是有效城市", isValidCity(CityItem("", "杭州", "hangzhou")))
        assertFalse("空 name 不是有效城市", isValidCity(CityItem("hangzhou", "", "hangzhou")))
        assertTrue("有效城市判定通过", isValidCity(CityItem("hangzhou", "杭州", "hangzhou")))
    }

    @Test
    fun `省份分组与热门城市过滤纯函数正常运作`() {
        val grouped = groupCitiesByProvince(DEFAULT_CITIES)
        assertTrue("应当有多个省份分组", grouped.size >= 10)
        assertTrue("应当包含浙江省", grouped.containsKey("浙江省"))
        assertTrue("浙江省下应有杭州", grouped["浙江省"]!!.any { it.name == "杭州" })

        val hot = filterHotCities(DEFAULT_CITIES)
        assertEquals(DEFAULT_HOT_CITIES.size, hot.size)
    }

    @Test
    fun `地区标签与紧凑显示名格式化纯函数`() {
        // regionLabel 对齐 Flutter WeatherLocation.regionLabel
        val region1 = WeatherStrings.formatRegionLabel("浙江省", "中国", "杭州")
        assertEquals("浙江省 · 中国", region1)

        val region2 = WeatherStrings.formatRegionLabel("北京市", "中国", "北京市")
        assertEquals("中国", region2)

        val region3 = WeatherStrings.formatRegionLabel(null, null, "杭州")
        assertEquals("", region3)

        // displayName 对齐 Flutter WeatherLocation.displayName
        val display1 = WeatherStrings.formatDisplayName("杭州市", "拱墅区")
        assertEquals("杭州市 · 拱墅区", display1)

        val display2 = WeatherStrings.formatDisplayName("杭州市", null)
        assertEquals("杭州市", display2)

        val display3 = WeatherStrings.formatDisplayName("杭州市", "杭州市")
        assertEquals("杭州市", display3)
    }

    @Test
    fun `定位错误枚举提示转换严格对应预设文案`() {
        assertEquals("请先开启系统定位服务", WeatherStrings.locationFailureMessage(WeatherLocationFailure.SERVICE_DISABLED))
        assertEquals("没有位置权限，无法获取当前位置", WeatherStrings.locationFailureMessage(WeatherLocationFailure.PERMISSION_DENIED))
        assertEquals("位置权限已被拒绝，请到系统设置里允许本应用使用位置", WeatherStrings.locationFailureMessage(WeatherLocationFailure.PERMISSION_DENIED_FOREVER))
        assertEquals("定位超时，请到窗边或室外再试，或直接搜索城市", WeatherStrings.locationFailureMessage(WeatherLocationFailure.TIMEOUT))
        assertEquals("定位失败，请改用手动搜索城市", WeatherStrings.locationFailureMessage(WeatherLocationFailure.FAILED))
        assertEquals("已定位，但解析不出地名，请改用手动搜索城市", WeatherStrings.locationFailureMessage(WeatherLocationFailure.ADDRESS_UNAVAILABLE))
    }
}
