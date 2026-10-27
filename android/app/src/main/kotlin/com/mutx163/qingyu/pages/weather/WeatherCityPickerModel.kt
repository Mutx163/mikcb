package com.mutx163.qingyu.pages.weather

/**
 * 城市数据项。
 *
 * @property id 城市唯一标识，如 "beijing", "hangzhou"
 * @property name 中文城市名，如 "北京", "杭州"
 * @property pinyin 完整汉语拼音全小写，如 "beijing", "hangzhou"
 * @property province 所属省份/直辖市/自治区，如 "浙江省", "北京市"
 * @property isHot 是否推荐为热门城市（在选择页标签流置顶展示）
 * @property pinyinInitials 拼音首字母缩写，如 "bj", "hz"，便于极速检索
 * @property latitude 纬度
 * @property longitude 经度
 * @property district 区县名称（定位反查时具备，如 "西湖区"）
 */
data class CityItem(
    val id: String,
    val name: String,
    val pinyin: String,
    val province: String = "",
    val isHot: Boolean = false,
    val pinyinInitials: String = "",
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    val district: String? = null,
)

/**
 * 选城市页面的整页视图状态。
 */
data class CityPickerState(
    val query: String = "",
    val hotCities: List<CityItem> = DEFAULT_HOT_CITIES,
    val searchResults: List<CityItem> = emptyList(),
    val selectedCity: CityItem? = null,
    val isLocating: Boolean = false,
    val locationError: String? = null,
    val currentLocatedCity: CityItem? = null,
)

/** 默认支持的国内主要城市与省会库。 */
val DEFAULT_CITIES: List<CityItem> = listOf(
    CityItem("beijing", "北京", "beijing", "北京市", isHot = true, pinyinInitials = "bj", latitude = 39.9042, longitude = 116.4074),
    CityItem("shanghai", "上海", "shanghai", "上海市", isHot = true, pinyinInitials = "sh", latitude = 31.2304, longitude = 121.4737),
    CityItem("guangzhou", "广州", "guangzhou", "广东省", isHot = true, pinyinInitials = "gz", latitude = 23.1291, longitude = 113.2644),
    CityItem("shenzhen", "深圳", "shenzhen", "广东省", isHot = true, pinyinInitials = "sz", latitude = 22.5431, longitude = 114.0579),
    CityItem("hangzhou", "杭州", "hangzhou", "浙江省", isHot = true, pinyinInitials = "hz", latitude = 30.2741, longitude = 120.1551),
    CityItem("chengdu", "成都", "chengdu", "四川省", isHot = true, pinyinInitials = "cd", latitude = 30.5728, longitude = 104.0668),
    CityItem("wuhan", "武汉", "wuhan", "湖北省", isHot = true, pinyinInitials = "wh", latitude = 30.5928, longitude = 114.3055),
    CityItem("nanjing", "南京", "nanjing", "江苏省", isHot = true, pinyinInitials = "nj", latitude = 32.0603, longitude = 118.7969),
    CityItem("chongqing", "重庆", "chongqing", "重庆市", isHot = true, pinyinInitials = "cq", latitude = 29.5630, longitude = 106.5516),
    CityItem("xian", "西安", "xian", "陕西省", isHot = true, pinyinInitials = "xa", latitude = 34.3416, longitude = 108.9398),
    CityItem("changsha", "长沙", "changsha", "湖南省", isHot = true, pinyinInitials = "cs", latitude = 28.2282, longitude = 112.9388),
    CityItem("suzhou", "苏州", "suzhou", "江苏省", isHot = true, pinyinInitials = "sz", latitude = 31.2990, longitude = 120.5853),
    CityItem("tianjin", "天津", "tianjin", "天津市", isHot = false, pinyinInitials = "tj", latitude = 39.0842, longitude = 117.2009),
    CityItem("zhengzhou", "郑州", "zhengzhou", "河南省", isHot = false, pinyinInitials = "zz", latitude = 34.7466, longitude = 113.6253),
    CityItem("qingdao", "青岛", "qingdao", "山东省", isHot = false, pinyinInitials = "qd", latitude = 36.0671, longitude = 120.3826),
    CityItem("jinan", "济南", "jinan", "山东省", isHot = false, pinyinInitials = "jn", latitude = 36.6512, longitude = 117.1201),
    CityItem("fuzhou", "福州", "fuzhou", "福建省", isHot = false, pinyinInitials = "fz", latitude = 26.0745, longitude = 119.2965),
    CityItem("xiamen", "厦门", "xiamen", "福建省", isHot = false, pinyinInitials = "xm", latitude = 24.4798, longitude = 118.0894),
    CityItem("hefei", "合肥", "hefei", "安徽省", isHot = false, pinyinInitials = "hf", latitude = 31.8206, longitude = 117.2272),
    CityItem("kunming", "昆明", "kunming", "云南省", isHot = false, pinyinInitials = "km", latitude = 25.0406, longitude = 102.7129),
    CityItem("shenyang", "沈阳", "shenyang", "辽宁省", isHot = false, pinyinInitials = "sy", latitude = 41.8057, longitude = 123.4315),
    CityItem("dalian", "大连", "dalian", "辽宁省", isHot = false, pinyinInitials = "dl", latitude = 38.9140, longitude = 121.6147),
    CityItem("harbin", "哈尔滨", "harbin", "黑龙江省", isHot = false, pinyinInitials = "heb", latitude = 45.8038, longitude = 126.5350),
    CityItem("changchun", "长春", "changchun", "吉林省", isHot = false, pinyinInitials = "cc", latitude = 43.8171, longitude = 125.3235),
    CityItem("nanning", "南宁", "nanning", "广西壮族自治区", isHot = false, pinyinInitials = "nn", latitude = 22.8170, longitude = 108.3665),
    CityItem("nanchang", "南昌", "nanchang", "江西省", isHot = false, pinyinInitials = "nc", latitude = 28.6820, longitude = 115.8579),
    CityItem("guiyang", "贵阳", "guiyang", "贵州省", isHot = false, pinyinInitials = "gy", latitude = 26.6470, longitude = 106.6302),
    CityItem("taiyuan", "太原", "taiyuan", "山西省", isHot = false, pinyinInitials = "ty", latitude = 37.8706, longitude = 112.5489),
    CityItem("shijiazhuang", "石家庄", "shijiazhuang", "河北省", isHot = false, pinyinInitials = "sjz", latitude = 38.0428, longitude = 114.5149),
    CityItem("lanzhou", "兰州", "lanzhou", "甘肃省", isHot = false, pinyinInitials = "lz", latitude = 36.0611, longitude = 103.8343),
    CityItem("haikou", "海口", "haikou", "海南省", isHot = false, pinyinInitials = "hk", latitude = 20.0440, longitude = 110.1999),
    CityItem("sanya", "三亚", "sanya", "海南省", isHot = false, pinyinInitials = "sy", latitude = 18.2528, longitude = 109.5119),
    CityItem("urumqi", "乌鲁木齐", "urumqi", "新疆维吾尔自治区", isHot = false, pinyinInitials = "wlmq", latitude = 43.8256, longitude = 87.6168),
    CityItem("hohhot", "呼和浩特", "hohhot", "内蒙古自治区", isHot = false, pinyinInitials = "hhht", latitude = 40.8415, longitude = 111.7519),
    CityItem("yinchuan", "银川", "yinchuan", "宁夏回族自治区", isHot = false, pinyinInitials = "yc", latitude = 38.4872, longitude = 106.2309),
    CityItem("xining", "西宁", "xining", "青海省", isHot = false, pinyinInitials = "xn", latitude = 36.6209, longitude = 101.7782),
    CityItem("lhasa", "拉萨", "lhasa", "西藏自治区", isHot = false, pinyinInitials = "ls", latitude = 29.6525, longitude = 91.1721),
    CityItem("hongkong", "香港", "hongkong", "香港特别行政区", isHot = false, pinyinInitials = "xg", latitude = 22.3193, longitude = 114.1694),
    CityItem("macau", "澳门", "macau", "澳门特别行政区", isHot = false, pinyinInitials = "am", latitude = 22.1987, longitude = 113.5439),
    CityItem("taipei", "台北", "taipei", "台湾省", isHot = false, pinyinInitials = "tb", latitude = 25.0330, longitude = 121.5654),
)

/** 默认热门城市清单。 */
val DEFAULT_HOT_CITIES: List<CityItem> = DEFAULT_CITIES.filter { it.isHot }

// ── 纯逻辑检索与状态处理函数 ──

/**
 * 城市搜索纯函数：支持名称模糊匹配、拼音全拼或前缀、首字母缩写、省份模糊检索。
 *
 * 排序权重：
 * 1. 中文名称完全一致 (100)
 * 2. 中文名称前缀匹配 (80)
 * 3. 中文名称包含 (60)
 * 4. 拼音首字母完全一致 (55)
 * 5. 拼音全拼完全一致 (50)
 * 6. 拼音首字母前缀匹配 (45)
 * 7. 拼音全拼前缀匹配 (40)
 * 8. 拼音包含 (30)
 * 9. 省份包含 (20)
 */
fun searchCities(
    query: String,
    allCities: List<CityItem> = DEFAULT_CITIES,
): List<CityItem> {
    val q = query.trim().lowercase()
    if (q.isEmpty()) return emptyList()

    return allCities.mapNotNull { city ->
        val nameLower = city.name.lowercase()
        val pinyinLower = city.pinyin.lowercase()
        val provinceLower = city.province.lowercase()
        val initialsLower = city.pinyinInitials.lowercase()

        val score = when {
            nameLower == q -> 100
            nameLower.startsWith(q) -> 80
            nameLower.contains(q) -> 60
            initialsLower.isNotEmpty() && initialsLower == q -> 55
            pinyinLower == q -> 50
            initialsLower.isNotEmpty() && initialsLower.startsWith(q) -> 45
            pinyinLower.startsWith(q) -> 40
            pinyinLower.contains(q) -> 30
            provinceLower.contains(q) -> 20
            else -> 0
        }

        if (score > 0) Pair(city, score) else null
    }.sortedWith(
        compareByDescending<Pair<CityItem, Int>> { it.second }
            .thenBy { it.first.name.length }
            .thenBy { it.first.id }
    ).map { it.first }
}

/**
 * 查询词输入变更纯函数。
 */
fun onQueryChanged(
    state: CityPickerState,
    query: String,
    allCities: List<CityItem> = DEFAULT_CITIES,
): CityPickerState {
    val trimmed = query.trim()
    val results = if (trimmed.isEmpty()) emptyList() else searchCities(trimmed, allCities)
    return state.copy(
        query = query,
        searchResults = results,
    )
}

/**
 * 选中城市纯函数。
 */
fun onSelectCity(state: CityPickerState, city: CityItem): CityPickerState {
    return state.copy(selectedCity = city)
}

/**
 * 发起定位纯函数（带防重入守卫：定位中状态下保持幂等）。
 */
fun onStartLocating(state: CityPickerState): CityPickerState {
    if (state.isLocating) return state
    return state.copy(
        isLocating = true,
        locationError = null,
    )
}

/**
 * 定位成功回填纯函数。
 */
fun onLocateSuccess(state: CityPickerState, locatedCity: CityItem): CityPickerState {
    return state.copy(
        isLocating = false,
        locationError = null,
        currentLocatedCity = locatedCity,
        selectedCity = locatedCity,
    )
}

/**
 * 定位失败回填纯函数。
 */
fun onLocateFailure(state: CityPickerState, errorMessage: String): CityPickerState {
    return state.copy(
        isLocating = false,
        locationError = errorMessage,
    )
}

/** 守卫规则：校验城市模型是否完备有效。 */
fun isValidCity(city: CityItem?): Boolean {
    return city != null && city.id.isNotBlank() && city.name.isNotBlank()
}

/** 守卫规则：是否允许触发定位。 */
fun canStartLocating(state: CityPickerState): Boolean {
    return !state.isLocating
}

/** 辅助函数：按省份聚合城市列表。 */
fun groupCitiesByProvince(cities: List<CityItem> = DEFAULT_CITIES): Map<String, List<CityItem>> {
    return cities.groupBy { it.province.ifBlank { "其他" } }
}

/** 辅助函数：筛选热门城市。 */
fun filterHotCities(cities: List<CityItem> = DEFAULT_CITIES): List<CityItem> {
    return cities.filter { it.isHot }
}
