package androidx.compose.animation.core

/**
 * **JVM 单测桩（不是生产代码）**：只给 `scripts/test-kotlin-module.ps1` 的纯 JVM classpath 用。
 *
 * ## 为什么需要它
 *
 * 页面里有些文件是「数学 + 常量」，只是**顺手实现一下 Compose 的缓动接口**好交给渲染层用
 * （活例：`android/app/src/main/kotlin/.../pages/timetable/HomeViewExpandMotion.kt` 的
 * `ThreePointCubicEasing : Easing`，其它内容全是三次贝塞尔求值，可在 JVM 上直接断言）。
 *
 * L0 的 classpath 只有 junit / hamcrest / stdlib（**故意**不挂 androidx：挂了就等于把
 * Compose 运行时拖进 JVM 单测），于是这一行 `import androidx.compose.animation.core.Easing`
 * 就让整个模块编不过——同模块其他人连带失去「交活前自测」的通道。
 *
 * ## 边界（别把它当万能补丁）
 *
 * - 只声明 `Easing` 这一个**纯函数接口**（Compose 里它就是
 *   `fun interface Easing { fun transform(fraction: Float): Float }`，无状态、无 Android 依赖）。
 * - 页面若真用到 `Modifier` / `Color` / 组合函数之类的 Compose API，仍然会在 L0 里**照样报红**——
 *   这是对的：那种文件本来就该待在自己的渲染层，不该靠桩糊过去。
 * - 脚本**只在本次收集到的源码真的 import 了它**时才加这个文件（见脚本里的
 *   `ComposeAnimationEasingStub` 分支），所以其它模块的编译面一字不变。
 */
fun interface Easing {
    fun transform(fraction: Float): Float
}
