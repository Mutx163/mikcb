-dontwarn com.umeng.**
-keep class com.umeng.** { *; }
-keepclassmembers class * {
    public <init>(org.json.JSONObject);
}

# Room 生成的 *_Impl 由 Room 反射调用无参构造创建。
#
# Room 2.6.1 自带的 consumer rule 只有
#   -keep class * extends androidx.room.RoomDatabase
# 在 AGP 9.4.1 / R8 下它只保住了类名，没保住 <init>()：
# build/app/outputs/mapping/<变体>/usage.txt 里能看到
#   androidx.work.impl.WorkDatabase_Impl:
#       public void <init>()
# 被 removed（2026-11-02 实测，perfBench 2.1.4-1-profile-bench）。
#
# 后果不是「某个功能不可用」，而是**进程启动即崩**：
# androidx.startup.InitializationProvider 在 Application.onCreate 之前初始化
# WorkManager，反射 new WorkDatabase_Impl() 抛
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# 所有走 R8 的包（release / bench）都会中，debug 不跑 R8 所以看不出来。
#
# -keep 带上成员块才会保构造函数；只写类名不够。
-keep class * extends androidx.room.RoomDatabase { <init>(); }
