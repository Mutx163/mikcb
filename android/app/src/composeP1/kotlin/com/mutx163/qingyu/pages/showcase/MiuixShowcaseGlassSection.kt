package com.mutx163.qingyu.pages.showcase

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.BlendMode as ComposeBlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.BlendColorEntry
import top.yukonga.miuix.kmp.blur.BlurDefaults
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.blur.textureBlur
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 深水区分组标题内边距：与主目录 / 分类详情页同一套 28dp 轴线（列表 12 + 这里 16）。 */
private val ShowcaseSectionTitleMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp)

// ─────────────────────────────────────────────
// 12b. 液态玻璃深水区（G4–G8，照抄官方 demo）
//
// 对应 docs/reference/miuix-demo/CHEATSHEET-玻璃与手感.md §4.1 缺口清单：
//   G4 前景模糊（contentBlendMode = DstIn，文字 alpha 当遮罩吃背景模糊）
//   G5 模糊配色（BlurDefaults.blurColors + ColorBlendToken 成套 token）
//   G6 玻璃描边（Highlight 六预设，按容器尺寸×主题选）
//   G7 传感器倾灯（rememberTiltLight，主光 0.15 / 副光 0.12）
//   G8 重力倾灯（rememberDeviceTilt → atan2 → 量化 3° → 旋转 dualPeak 主光）
//
// 全部走 miuix-blur 官方 API；辅助接线（ColorBlendToken / HighlightConfig /
// rememberContainerHighlight / 重力旋转）是官方 demo 代码逐字照抄，见各文件头。
// 设备不支持 RuntimeShader（API < 33）时整节不渲染——渲染坏效果不如不渲染，
// 与官方 blurSection 的门控姿势一致。
// ─────────────────────────────────────────────

/**
 * 深水区玻璃演示入口，挂在「模糊 Blur」分类下，紧跟基础 textureBlur 卡片之后。
 */
@Composable
fun ShowcaseDeepGlassSection(
    dark: Boolean,
    primaryColor: Color,
) {
    if (!isRuntimeShaderSupported()) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ShowcaseTextureBlendDemo(dark, primaryColor)
        ShowcaseForegroundBlurDemo(dark, primaryColor)
        ShowcaseGravityTiltDemo(dark, primaryColor)
    }
}

/**
 * G5 配色 × G6 描边 × G7 传感器倾灯：一张 textureBlur 面板，三个维度都接了官方
 * 演示的控件（配色下拉 / 描边档位下拉 / 倾灯开关），对照官方 BlurDemo（BlurSection.kt:222-382）。
 */
@Composable
private fun ShowcaseTextureBlendDemo(
    dark: Boolean,
    primaryColor: Color,
) {
    // 官方默认：Colored Thick（下标 5）+ Small Container + 倾灯开。
    var blendIndex by remember { mutableIntStateOf(5) }
    var containerIndex by remember { mutableIntStateOf(HighlightConfig.Container.Small.ordinal) }
    var tiltDriven by remember { mutableStateOf(true) }

    val blendConfigs = remember(dark) { buildTextureBlendConfigs(dark) }
    val blendItems = blendConfigs.map { it.first }
    val containers = HighlightConfig.Container.entries
    val containerItems = containers.map { it.displayName }

    val backdrop = rememberLayerBackdrop()
    val highlight = rememberContainerHighlight(
        container = containers[containerIndex],
        isDark = dark,
        tiltDriven = tiltDriven,
    )

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        QingyuSectionTitle(
            text = ShowcaseStrings.glassBlendCardTitle.text,
            insideMargin = ShowcaseSectionTitleMargin,
        )
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(280.dp)
                        .clip(RoundedCornerShape(16.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    // ① 被捕获层：彩带底图（纯色糊完是纯色，看不出效果）
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .layerBackdrop(backdrop),
                    ) {
                        ShowcaseGlassSampleBackground(primaryColor)
                    }
                    // ② 模糊面：采样 ① 并模糊，叠 G5 配色层 + G6 玻璃描边（G7 开时描边随传感器动）
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.8f)
                            .height(140.dp)
                            .textureBlur(
                                backdrop = backdrop,
                                shape = RoundedCornerShape(24.dp),
                                blurRadiusX = 100f,
                                blurRadiusY = 100f,
                                noiseCoefficient = BlurDefaults.NoiseCoefficient,
                                colors = BlurDefaults.blurColors(
                                    blendColors = blendConfigs[blendIndex].second,
                                ),
                                highlight = highlight,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "Texture Blur | R=100",
                                style = MiuixTheme.textStyles.headline2,
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = "${blendItems[blendIndex]} · ${containerItems[containerIndex]}",
                                style = MiuixTheme.textStyles.body2,
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                        }
                    }
                }

                OverlayDropdownPreference(
                    title = ShowcaseStrings.glassBlendLabel.text,
                    items = blendItems,
                    selectedIndex = blendIndex,
                    onSelectedIndexChange = { blendIndex = it },
                )

                OverlayDropdownPreference(
                    title = ShowcaseStrings.glassHighlightLabel.text,
                    items = containerItems,
                    selectedIndex = containerIndex,
                    onSelectedIndexChange = { containerIndex = it },
                )

                SwitchPreference(
                    title = ShowcaseStrings.glassTiltLabel.text,
                    checked = tiltDriven,
                    onCheckedChange = { tiltDriven = it },
                )
            }
        }
    }
}

/**
 * G4 前景模糊：textureBlur 直接挂在 Text 上，contentBlendMode = DstIn 让文字的
 * alpha 通道当遮罩——字里透出的是「被模糊的背景」。对照官方 ForegroundBlurDemo
 * （BlurSection.kt:385-537），默认配色是官方调的「金属 logo」配方。
 */
@Composable
private fun ShowcaseForegroundBlurDemo(
    dark: Boolean,
    primaryColor: Color,
) {
    // 官方默认：Logo Blend（下标 1）。
    var blendIndex by remember { mutableIntStateOf(1) }
    val blendConfigs = remember(dark) { buildForegroundBlendConfigs(dark) }
    val blendItems = blendConfigs.map { it.first }

    val backdrop = rememberLayerBackdrop()

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        QingyuSectionTitle(
            text = ShowcaseStrings.glassForegroundCardTitle.text,
            insideMargin = ShowcaseSectionTitleMargin,
        )
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(280.dp)
                        .clip(RoundedCornerShape(16.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .layerBackdrop(backdrop),
                    ) {
                        ShowcaseGlassSampleBackground(primaryColor)
                    }
                    Text(
                        text = "Foreground Blur",
                        style = MiuixTheme.textStyles.headline1,
                        fontWeight = FontWeight.Black,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .textureBlur(
                                backdrop = backdrop,
                                shape = RoundedCornerShape(0.dp),
                                blurRadiusX = 200f,
                                blurRadiusY = 200f,
                                noiseCoefficient = BlurDefaults.NoiseCoefficient,
                                colors = BlurDefaults.blurColors(
                                    blendColors = blendConfigs[blendIndex].second,
                                ),
                                contentBlendMode = ComposeBlendMode.DstIn,
                            ),
                    )
                }

                OverlayDropdownPreference(
                    title = ShowcaseStrings.glassBlendLabel.text,
                    items = blendItems,
                    selectedIndex = blendIndex,
                    onSelectedIndexChange = { blendIndex = it },
                )

                Text(
                    text = ShowcaseStrings.glassForegroundHint.text,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}

/**
 * G8 重力倾灯：drawBackdrop 低阶管线 + vibrancy + blur，描边高光的 dualPeak 主光
 * 被重力量化角（3° 步进）旋转。对照官方 LiquidGlassNavigationBar.kt:323 / :435 的
 * 「绘制期读 State」姿势——传感器 50Hz 写入不能进组合期。
 */
@Composable
private fun ShowcaseGravityTiltDemo(
    dark: Boolean,
    primaryColor: Color,
) {
    val backdrop = rememberLayerBackdrop()
    // 官方导航栏底壳用的偏移 -45°；在 highlight lambda 里取 .value = 绘制期读。
    val gravityHighlight = rememberGravityRotatedHighlight(
        base = showcaseIndicatorSpecular,
        extraDegrees = -45f,
    )

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        QingyuSectionTitle(
            text = ShowcaseStrings.glassGravityCardTitle.text,
            insideMargin = ShowcaseSectionTitleMargin,
        )
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp)
                        .clip(RoundedCornerShape(16.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .layerBackdrop(backdrop),
                    ) {
                        ShowcaseGlassSampleBackground(primaryColor)
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.85f)
                            .height(120.dp)
                            .drawBackdrop(
                                backdrop = backdrop,
                                shape = { RoundedCornerShape(24.dp) },
                                effects = {
                                    vibrancy()
                                    blur(4.dp.toPx())
                                },
                                highlight = { gravityHighlight.value.copy(alpha = 0.75f) },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "Gravity Tilt",
                            style = MiuixTheme.textStyles.headline2,
                            color = Color.White,
                        )
                    }
                }

                Text(
                    text = ShowcaseStrings.glassGravityHint.text,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}

// ── 配色下拉的数据源：与官方 BlurDemo（BlurSection.kt:246-262）同表 ──

private fun buildTextureBlendConfigs(isDark: Boolean): List<Pair<String, List<BlendColorEntry>>> = listOf(
    "None" to emptyList(),
    "Info Thin" to if (isDark) ColorBlendToken.Info_Thin_Dark else ColorBlendToken.Info_Thin_Light,
    "Info Regular" to if (isDark) ColorBlendToken.Info_Regular_Dark else ColorBlendToken.Info_Regular_Light,
    "Colored Thin" to if (isDark) ColorBlendToken.Colored_Thin_Dark else ColorBlendToken.Colored_Thin_Light,
    "Colored Regular" to if (isDark) ColorBlendToken.Colored_Regular_Dark else ColorBlendToken.Colored_Regular_Light,
    "Colored Thick" to if (isDark) ColorBlendToken.Colored_Thick_Dark else ColorBlendToken.Colored_Thick_Light,
    "Pured Regular" to if (isDark) ColorBlendToken.Pured_Regular_Dark else ColorBlendToken.Pured_Regular_Light,
    "Pured Thick" to if (isDark) ColorBlendToken.Pured_Thick_Dark else ColorBlendToken.Pured_Thick_Light,
    "Overlay Thin" to if (isDark) ColorBlendToken.Overlay_Thin_Light else ColorBlendToken.Overlay_Thin_Light,
    "Overlay Thick" to if (isDark) ColorBlendToken.Overlay_Thick_Dark else ColorBlendToken.Overlay_Thick_Light,
)

/**
 * G4 前景模糊的配色表：与官方 ForegroundBlurDemo（BlurSection.kt:413-424）同表，
 * 下标 1 = 官方调好的「金属 logo」配方，是该演示的默认档。
 */
private fun buildForegroundBlendConfigs(isDark: Boolean): List<Pair<String, List<BlendColorEntry>>> = listOf(
    "None" to emptyList(),
    "Logo Blend" to if (isDark) {
        ColorBlendToken.ForegroundLogoBlend_Dark
    } else {
        ColorBlendToken.ForegroundLogoBlend_Light
    },
    "Colored Thin" to if (isDark) ColorBlendToken.Colored_Thin_Dark else ColorBlendToken.Colored_Thin_Light,
    "Colored Regular" to if (isDark) ColorBlendToken.Colored_Regular_Dark else ColorBlendToken.Colored_Regular_Light,
    "Colored Thick" to if (isDark) ColorBlendToken.Colored_Thick_Dark else ColorBlendToken.Colored_Thick_Light,
    "Pured Regular" to if (isDark) ColorBlendToken.Pured_Regular_Dark else ColorBlendToken.Pured_Regular_Light,
    "Overlay Thin" to if (isDark) ColorBlendToken.Overlay_Thin_Light else ColorBlendToken.Overlay_Thin_Light,
    "Info Colored" to ColorBlendToken.Info_Colored_Regular,
)

/**
 * 演示用采样底图：斜向彩带 + 白色圆点。
 * 颜色取应用层彩豆 token（与既有 ShowcaseBlurSampleBackground 同源），不写字面量（R5）。
 */
@Composable
private fun ShowcaseGlassSampleBackground(primaryColor: Color) {
    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(primaryColor),
        )
        Row(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .background(Color(QingyuIconColors.CYAN)),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .background(Color(QingyuIconColors.RED)),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .background(Color(QingyuIconColors.YELLOW)),
            )
        }
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            repeat(4) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.9f)),
                )
            }
        }
    }
}
