// 去 Flutter 化阶段 1（2026-11-07）：`-PwithFlutter=false` 时顶替真实 flutter_tools 插件的**空实现**。
//
// 为什么必须有它：Gradle 的 settings `plugins {}` 只允许 `id(..)` 调用，不能写 `if`；
// 而 `plugins{}` 里的插件请求又必须先解析成功（`apply false` 也一样）。
// 所以「无 Flutter 构型不加载 flutter_tools」只能靠**换掉 includeBuild 指向**：
//   默认 withFlutter=true → 指向 $flutterSdkPath/packages/flutter_tools/gradle（原行为，零变化）
//   withFlutter=false     → 指向本目录，id / 版本一致但 apply 什么都不做
// 本 build 只在无 Flutter 构型下参与配置，不产出 APK 内容、不进任何 variant 的 classpath。

plugins {
    `java-gradle-plugin`
}

group = "dev.flutter.plugin"
version = "1.0.0"

gradlePlugin {
    plugins {
        create("noopFlutterPluginLoader") {
            // 与 Flutter SDK 内 `dev.flutter.flutter-plugin-loader` 同 id、同版本。
            id = "dev.flutter.flutter-plugin-loader"
            implementationClass = "com.mutx163.qingyu.noflutter.NoopFlutterPluginLoader"
        }
    }
}
