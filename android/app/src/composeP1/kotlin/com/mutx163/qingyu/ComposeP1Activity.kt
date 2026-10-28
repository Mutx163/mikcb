package com.mutx163.qingyu

import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * Compose 迁移 Phase 1 验证壳（composeP1 flavor 专属，验证完即删）。
 *
 * 目的（对应迁移计划 Phase 1 验收单）：
 * 1. 同包名覆盖安装后**读得出真实课表**——数据经 [TodayWidgetSupport.buildSnapshotFromFlutterState]
 *    直读 FlutterSharedPreferences（flutter.timetable_profiles / settings / 自定义节假日），
 *    与桌面小组件同一条解析口径，不另写解析器、不猜 JSON 结构；
 * 2. 能**写回一个 key** 并被 Dart 侧读回（写 flutter.compose_p1_probe_v1）；
 * 3. 官方 Miuix 组件先行接入验证（本页 Scaffold / Card / Text / MiuixTheme 全是
 *    top.yukonga.miuix.kmp 的，不引 material3——API 签名已对 miuix 0.8.8 AAR
 *    javap 核实：Card.insideMargin 是 PaddingValues，Text/color 是 value class）；
 * 4. manifest 其余组件（小组件/保活/通知渠道）全部继承，真机逐项核对无恙。
 *
 * UI 只求结构清晰，不做像素级对齐——那是 Phase 3 的事。
 */
class ComposeP1Activity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 与 PagesShellActivity 同一处修复（2026-10-27）：edge-to-edge 必须真调用，
        // 只 import 没有效果。LaunchTheme 的平台默认 system bar 是黑色，不启用
        // edge-to-edge 时状态栏与手势条就是两条黑边，与浅色界面割裂。
        // 图标明暗跟随系统深浅，避免深色下图标与背景同色看不见。
        applyShellSystemBars(isDark = isNightMode())

        setContent {
            val dark = isSystemInDarkTheme()
            SideEffect { applyShellSystemBars(isDark = dark) }
            // 无参 MiuixTheme{ } 的配色恒取官方默认亮色板，深色下白字白底。
            // 改走主题桥后跟随系统深浅。
            QingyuPageTheme {
                ComposeP1Screen(activity = this@ComposeP1Activity)
            }
        }
    }

    /** 当前资源配置是否为深色。仅作首帧兜底，组合内以 isSystemInDarkTheme() 为准。 */
    private fun isNightMode(): Boolean =
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    /** 系统栏全透明，图标明暗跟随壳的明暗。 */
    private fun applyShellSystemBars(isDark: Boolean) {
        val transparent = android.graphics.Color.TRANSPARENT
        enableEdgeToEdge(
            statusBarStyle = if (isDark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
            navigationBarStyle = if (isDark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
        )
    }
}

@Composable
private fun ComposeP1Screen(activity: ComponentActivity) {
    // 后台线程读 prefs + 解析，完成后触发重组；produceState 自带取消语义。
    val snapshotState = produceState<TodayWidgetSnapshotInfo?>(initialValue = null) {
        value = runCatching {
            TodayWidgetSupport.buildSnapshotFromFlutterState(activity.applicationContext)
        }.getOrNull()
    }
    val writeState = produceState<String>(initialValue = "…") {
        value = runCatching {
            // Phase 1 写回探针：写一个 Dart 侧能按普通 String 读的 key。
            // 前缀 flutter. 必须显式写（Kotlin 侧不经插件，没有自动加前缀这回事）。
            val prefs = activity.applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
            val ok = prefs.edit()
                .putString(
                    "flutter.compose_p1_probe_v1",
                    "written-by-compose-" + System.currentTimeMillis(),
                )
                .commit()
            if (ok) "写回成功（compose_p1_probe_v1）" else "写回失败"
        }.getOrElse { "写回异常：${it.message}" }
    }

    val colors = MiuixTheme.colorScheme
    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
                // 默认 systemBars.union(displayCutout)，本页无 topBar 槽位，
                // innerPadding.top 已含状态栏高度，再写一次会算两遍。
                .verticalScroll(rememberScrollState())
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = "轻屿课表 · Compose P1",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = colors.onSurface,
                modifier = Modifier.padding(top = 12.dp),
            )
            Text(
                text = "同包名覆盖安装验证壳 — 数据直读 Flutter 落盘",
                fontSize = 13.sp,
                color = colors.onSurfaceVariantSummary,
            )

            // ── 写回探针结果 ──
            MiuixProbeCard(title = "写回探针", body = writeState.value)

            // ── 课表数据 ──
            val snapshot = snapshotState.value
            if (snapshot == null) {
                MiuixProbeCard(
                    title = "未读到课表",
                    body = "flutter.timetable_profiles 为空或解析失败。" +
                        "若这是刚覆盖安装的机器，请核对活跃档案是否存在。",
                )
            } else {
                MiuixProbeCard(
                    title = snapshot.profileName.ifBlank { "（未命名课表）" },
                    body = "第 ${snapshot.currentWeek} 周 · 今天 ${snapshot.totalTodayCourseCount} 节课",
                )
                snapshot.todayCourses.forEach { course ->
                    CourseRow(course = course)
                }
                snapshot.nextCourse?.let {
                    MiuixProbeCard(
                        title = "下一节：${it.name}",
                        body = "${it.startTime} · ${it.location}",
                    )
                }
                snapshot.holidayName?.let {
                    MiuixProbeCard(title = "假期标记", body = it)
                }
            }
        }
    }
}

/** 今日课程一行：色条 + 课名 + 时间地点（Phase 1 只求信息对，不求样式对）。 */
@Composable
private fun CourseRow(course: TodayWidgetCourseInfo) {
    val accent = runCatching {
        Color(android.graphics.Color.parseColor(course.colorHex))
    }.getOrDefault(Color(0xFF3482FF))
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(colors.surfaceContainer)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(2.dp))
                .background(accent)
                .width(4.dp)
                .height(36.dp),
        )
        Column {
            Text(
                text = course.name,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = colors.onSurface,
            )
            Text(
                text = "${course.startTime} – ${course.endTime} · ${course.location}",
                fontSize = 12.sp,
                color = colors.onSurfaceVariantSummary,
            )
        }
    }
}

/** 本壳内复用的最小卡片（官方 Miuix Card 的薄封装，insideMargin 按 0.8.8 签名传 PaddingValues）。 */
@Composable
private fun MiuixProbeCard(title: String, body: String) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(14.dp),
    ) {
        Column {
            Text(
                text = title,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.onSurface,
            )
            Text(
                text = body,
                fontSize = 13.sp,
                color = colors.onSurfaceVariantSummary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}
