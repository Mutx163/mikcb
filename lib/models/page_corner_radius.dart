/// 屏幕圆角的**兜底值**（逻辑像素）。
///
/// 用途：`AndroidAnimationScaleService` 在拿不到平台读数时（非 Android / Web /
/// 通道抛错 / 平台返回 0 之前的初值）用这个半径。
///
/// 为什么住这里：该服务属于 `services/` 层，而视觉规格住在 `ui/`
/// （`HyperosMiuixNavigation.pageCornerRadiusFallback`）。服务 import ui 是反向
/// 依赖，所以把「这个数是多少」沉到中性的 models 层，两边都能读。
///
/// **一份真源**：`ui/hyperos/hyperos_miuix_spec.dart` 里的同名值必须与它相等，
/// 口径由 `test/models/page_corner_radius_test.dart` 钉住（改一边不改另一边会红）。
///
/// 注意与「哪些机器该用兜底值」的判定无关：平台返回 0 表示这台机器没有可对齐
/// 的屏幕圆角，此时**必须归零**而不是套用本兜底值（见该服务 `refresh()` 里的
/// 2026-10-18 注释），否则转场前缘缺口会画到机身圆角外面。
const double kPageCornerRadiusFallbackDp = 28;
