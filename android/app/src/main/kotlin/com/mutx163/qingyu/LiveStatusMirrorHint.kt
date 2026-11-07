package com.mutx163.qingyu

/**
 * 「要不要把直播/岛状态镜像进 MIUI 焦点提示」的纯判据（从 `MainActivity.kt` 末尾搬出）。
 *
 * 为什么单独成文件（去 Flutter 化阶段 1，2026-11-07）：它原本是 `MainActivity.kt` 里的顶层函数，
 * 而 `LiveUpdateService`（非 Flutter 源）要用它。`-PwithFlutter=false` 构型会把 `MainActivity.kt`
 * 整体排除出编译，顶层函数跟着消失，编译直接报 Unresolved reference。
 * 判据本身不碰 Flutter，搬出来既保住无 Flutter 构型，也让调用点/单测无需改 import（同包）。
 *
 * 语义冻结：`sdkInt >= 36`（Android 16）且已被提权（`shouldPromote`）时不镜像，其余情况镜像。
 * 钉值见 `LiveUpdateServiceLogicTest`。
 */
internal fun liveShouldMirrorStatusIntoMiuiFocusHint(
    sdkInt: Int,
    shouldPromote: Boolean,
): Boolean {
    return !(sdkInt >= 36 && shouldPromote)
}
