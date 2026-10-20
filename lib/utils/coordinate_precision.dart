/// 经纬度的统一精度：小数点后 2 位（赤道附近约 1.1 公里）。
///
/// ## 为什么住 utils 而不是 weather_service
///
/// 同一个取整口径要在三层共用：
/// - **services**：三个解析汇聚点（正向搜索 / 反查 / IP 估算）与预报请求出口；
/// - **providers**：内存里的位置、以及与缓存预报的「是不是同一个城市」比对；
/// - **models**：[WeatherLocation.coarsened]。
///
/// `utils/` 是横切层（谁都能依赖），`services/` 不是——models 若去 import
/// `weather_service.dart` 就是反向依赖，`dependency_guards_test` 会红。
/// 所以把定义放这里，`WeatherService.coarsenCoordinate` 保留为一行转发的
/// 公开别名（既有测试与调用点无感）。
///
/// 反面教材见仓库历史：周次换算的两份手写副本、端口重复声明 89 条——
/// 同一规则两处维护，改一处必漂。
double coarsenCoordinate(double value) => (value * 100).roundToDouble() / 100;
