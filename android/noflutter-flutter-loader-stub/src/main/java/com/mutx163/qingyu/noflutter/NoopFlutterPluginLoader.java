package com.mutx163.qingyu.noflutter;

import org.gradle.api.Plugin;
import org.gradle.api.initialization.Settings;

/**
 * 无 Flutter 构型下的空插件（去 Flutter 化阶段 1，2026-11-07）。
 *
 * <p>真实实现 {@code com.flutter.gradle.FlutterAppPluginLoaderPlugin} 做两件事：读
 * {@code local.properties} 里的 flutter.sdk、把 {@code .flutter-plugins-dependencies} 里的插件工程
 * {@code include} 进来。无 Flutter 构型下这两件事都不该发生（也没有 SDK 可读），所以这里**故意为空**。
 *
 * <p>它只用于让 settings 的 {@code plugins { id "dev.flutter.flutter-plugin-loader" }} 请求
 * 能够解析：一旦解析失败，Gradle 在配置期就报 "Plugin with id ... not found"，
 * 连 {@code -PwithFlutter=false} 的编译都跑不起来。
 */
public final class NoopFlutterPluginLoader implements Plugin<Settings> {

    @Override
    public void apply(Settings settings) {
        // 故意不做事：不读 local.properties，不 include 任何插件工程。
    }
}
