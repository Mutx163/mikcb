package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 成就徽章详情弹层。
 *
 * 对应 Dart `lib/widgets/statistics/achievement_badge.dart` 的 `showAchievementDetailSheet`：
 * - 勋章大图：84×84 dp，圆角 24 dp；未解锁时显示小锁圆点
 * - 状态标签：已达成（主色背景） / 未达成
 * - 进度：带进度条与已完成/目标值文本
 * - 一句话简述 + 详细达成说明（对齐 ARB 文案）
 * - 「知道了」确认关闭按钮
 */
@Composable
fun AchievementDetailSheet(
    achievement: AchievementView?,
    dark: Boolean,
    onDismiss: () -> Unit,
) {
    if (achievement == null) return

    val unlocked = achievement.isUnlocked
    val accent = Color(QingyuTheme.primary(dark = dark))
    val fill = if (unlocked) {
        accent
    } else {
        Color(QingyuTheme.surfaceContainerHighest(dark))
    }
    val iconTint = if (unlocked) {
        Color(QingyuTheme.onAccent(dark))
    } else {
        Color(QingyuTheme.secondaryText(dark))
    }

    QingyuSheet(
        show = true,
        title = achievement.name,
        onDismissRequest = onDismiss,
        // 正文自带 16dp ⇒ 套件侧边距归零，避免叠成 32。
        contentPadsHorizontally = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // ── 勋章大图标（84×84，圆角 24） ──
            Box(
                modifier = Modifier
                    .size(84.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(fill)
                    .then(
                        if (unlocked) {
                            Modifier
                        } else {
                            Modifier.border(
                                width = 0.5.dp,
                                color = Color(QingyuTheme.dividerLine(dark)),
                                shape = RoundedCornerShape(24.dp),
                            )
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = MiuixIcons.Favorites,
                    contentDescription = null,
                    tint = iconTint,
                    modifier = Modifier.size(40.dp),
                )
                if (!unlocked) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .offset(x = 2.dp, y = 2.dp)
                            .size(20.dp)
                            .clip(CircleShape)
                            .background(Color(QingyuTheme.card(dark)))
                            .border(1.dp, Color(QingyuTheme.dividerLine(dark)), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(QingyuTheme.secondaryText(dark))),
                        )
                    }
                }
            }

            Spacer(Modifier.height(14.dp))

            // ── 状态 Tag + 进度文字 ──
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(
                            if (unlocked) {
                                accent.copy(alpha = 0.14f)
                            } else {
                                Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.1f)
                            },
                        )
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                ) {
                    Text(
                        text = achievement.statusLabel,
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = if (unlocked) accent else Color(QingyuTheme.secondaryText(dark)),
                    )
                }

                if (achievement.hasProgress && achievement.progressLabel != null) {
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = achievement.progressLabel,
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
            }

            // ── 进度条 ──
            if (achievement.hasProgress) {
                Spacer(Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(Color(QingyuTheme.surfaceContainerHighest(dark))),
                ) {
                    val ratio = if (unlocked) 1f else achievement.progressRatio.coerceIn(0f, 1f)
                    if (ratio > 0f) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(ratio)
                                .height(6.dp)
                                .clip(RoundedCornerShape(3.dp))
                                .background(accent),
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            // ── 一句话描述（走字阶 body1，不再写死 15sp） ──
            //
            // 原先写 `style = title4` + `fontSize = 15.sp`：15 既不在官方字阶上（16 / 14 之间），
            // 也绕过了 `MiuixTheme` 注入的字阶（用户字重与系统粗体当场失效，规则 R4）。
            // 这里按「正文角色」取最近的一档 body1（16sp）。
            //
            // ⚠️ 与 Dart 的差异（记在这里，不静默改版式）：Dart
            // `lib/widgets/statistics/achievement_badge.dart:294-300` 用的是
            // `listTitle.copyWith(fontSize: footnote2 + 2)` = 13sp。迁移时写成了 15sp，
            // 本次只做「回到字阶」，没有顺手改字号（那是版式变更，需要用户过目）。
            Text(
                text = achievement.description,
                style = MiuixTheme.textStyles.body1,
                lineHeight = 22.sp,
                textAlign = TextAlign.Center,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.fillMaxWidth(),
            )

            // ── 详细达成说明（次要字色 13sp） ──
            if (achievement.detail.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = achievement.detail,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = 20.sp,
                    textAlign = TextAlign.Center,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(Modifier.height(20.dp))

            // ── 确认按钮（知道了） ──
            // Dart `achievement_badge.dart:312-316` 是 `HyperosButton(expand: true)`（不传 variant
            // ⇒ primary）；miuix `Button` 不传 colors 是 secondaryVariant 灰底。
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(achievement.confirmLabel)
            }
        }
    }
}
