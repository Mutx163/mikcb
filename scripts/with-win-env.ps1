# 为被剥空环境的 Agent PowerShell 补齐构建链依赖的系统变量（JDK/Gradle 与 pub 缓存），再执行后续命令。
# 用法:
#   pwsh -NoProfile -File scripts/with-win-env.ps1 ./gradlew :app:compileDevDebugKotlin
#   pwsh -NoProfile -File scripts/with-win-env.ps1 java -version
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CommandArgs
)

if (-not $CommandArgs -or $CommandArgs.Count -eq 0) {
  Write-Error 'Usage: with-win-env.ps1 <command> [args...]'
  exit 2
}

# Agent 无头会话常缺这些；缺失时 flutter.bat 展开 %ProgramFiles(x86)% 会直接失败。
if ([string]::IsNullOrEmpty($env:ProgramFiles)) {
  $env:ProgramFiles = 'C:\Program Files'
}
if ([string]::IsNullOrEmpty(${env:ProgramFiles(x86)})) {
  ${env:ProgramFiles(x86)} = 'C:\Program Files (x86)'
}
if ([string]::IsNullOrEmpty($env:ProgramW6432)) {
  $env:ProgramW6432 = 'C:\Program Files'
}
if ([string]::IsNullOrEmpty($env:SystemRoot)) {
  $env:SystemRoot = 'C:\Windows'
}
# test_core / pub 需要这四个：缺失时 `flutter test` 会在跑测试前就崩
# （`test_core/src/executable.dart` 的空断言），报错信息完全指不到这里。
# 2026-11-07 实测：本机 Agent 会话里 HOME / LOCALAPPDATA / APPDATA / PUB_CACHE
# 全为空，架构守卫因此「假红」—— 不是代码问题。
if ([string]::IsNullOrEmpty($env:USERPROFILE)) {
  $env:USERPROFILE = 'C:\Users\mutx'
}
if ([string]::IsNullOrEmpty($env:LOCALAPPDATA)) {
  $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
}
if ([string]::IsNullOrEmpty($env:APPDATA)) {
  $env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
}
if ([string]::IsNullOrEmpty($env:HOME)) {
  $env:HOME = $env:USERPROFILE
}
# pub 缓存：本仓实际用的是 D:\Cache\Pub（见 android/gradle.properties 与
# .flutter-plugins-dependencies 里的路径）。指错缓存会让它们全部重下。
if ([string]::IsNullOrEmpty($env:PUB_CACHE)) {
  $cacheCandidate = 'D:\Cache\Pub'
  if (-not (Test-Path $cacheCandidate)) {
    $cacheCandidate = Join-Path $env:LOCALAPPDATA 'Pub\Cache'
  }
  $env:PUB_CACHE = $cacheCandidate
}

$exe = $CommandArgs[0]
$rest = @()
if ($CommandArgs.Count -gt 1) {
  $rest = $CommandArgs[1..($CommandArgs.Count - 1)]
}

& $exe @rest
exit $LASTEXITCODE
