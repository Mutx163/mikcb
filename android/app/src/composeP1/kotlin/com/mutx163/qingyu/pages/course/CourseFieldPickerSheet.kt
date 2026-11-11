package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.clickable
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Clear
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「已有教师 / 地点」选择弹层（发布版 `showCourseFieldPickerSheet`：
 * `widgets/course_field_picker_sheet.dart:62`，调用点 `add_course_screen.dart:917/:933`、
 * `course_followup_sheets.dart:421`）。
 *
 * ## 形态
 *
 * 标题 + 手输框（初值 = 当前值，带清空）+ 候选清单（点一下回填输入框）+ 取消 / 确认。
 * 发布版的搜索框与输入框是同一个 controller：这里同样只有一个输入框，输入即过滤候选，
 * 不另做一层「搜索态 → 再确认」。候选**只列历史值，不伪造**；没有候选时就是纯手输。
 *
 * ## 为什么是共享件
 *
 * 加课页的条目教师/地点、共享信息卡两行，以及调课弹层的地点，四处在发布版是同一个
 * 弹层；本仓也只留这一份，避免又长出第二套「手输 + 建议」画法。
 *
 * @param title 弹层标题（`selectTeacherTitle` / `selectLocationTitle`）。
 * @param label 输入框标签（`manualInputLabel`：「手动填写」）。
 * @param value 当前值；每次打开按它起手（`remember(show, value)`）。
 * @param suggestions 候选（[CourseFieldSuggestionLogic] 算好的清单；空表 = 纯手输）。
 */
@Composable
fun CourseFieldPickerSheet(
    show: Boolean,
    title: String,
    label: String,
    value: String,
    suggestions: List<String>,
    confirmLabel: String,
    cancelLabel: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var text by remember(show, value) { mutableStateOf(value) }
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    // 输入即过滤（发布版 `filterFieldSuggestions`：大小写不敏感的子串匹配）。
    val normalized = text.trim().lowercase()
    val visible = if (normalized.isEmpty()) {
        suggestions
    } else {
        suggestions.filter { it.lowercase().contains(normalized) }
    }

    // 发布版 sheet 口径：**内容滚、按钮钉底**——候选很长时也不用滚到底才能确认/取消。
    // 正文自带 LazyColumn ⇒ `contentScrolls = true`，底部让位垫在固定按钮下面。
    val listMaxHeight = rememberSheetMaxHeight(0.45f)
    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        contentScrolls = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = bottomInset),
        ) {
            TextField(
                value = text,
                onValueChange = { text = it },
                label = label,
                useLabelAsPlaceholder = true,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                trailingIcon = {
                    if (text.isNotEmpty()) {
                        IconButton(onClick = { text = "" }) {
                            Icon(
                                imageVector = MiuixIcons.Clear,
                                contentDescription = cancelLabel,
                                tint = secondaryText,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                },
            )
            if (visible.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = listMaxHeight)
                        .scrollEndHaptic()
                        .overScrollVertical(),
                ) {
                    items(visible) { suggestion ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                // 点候选即回填并关闭（发布版一步到位；不再要求再点一次确认）。
                                .clickable { onConfirm(suggestion) }
                                .padding(horizontal = 12.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = suggestion,
                                style = MiuixTheme.textStyles.body2,
                                color = primaryText,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    // 取消 = secondary 实心（已裁口径：双键同组件，仅配色分主次）。
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = cancelLabel)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(text) },
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = confirmLabel)
                }
            }
        }
    }
}
