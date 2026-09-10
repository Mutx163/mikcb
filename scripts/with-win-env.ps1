# 为被剥空环境的 Agent PowerShell 补齐 flutter.bat 依赖的系统变量，再执行后续命令。
# 用法:
#   pwsh -NoProfile -File scripts/with-win-env.ps1 flutter test --no-pub test/foo_test.dart
#   powershell -NoProfile -File scripts/with-win-env.ps1 flutter analyze
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

$exe = $CommandArgs[0]
$rest = @()
if ($CommandArgs.Count -gt 1) {
  $rest = $CommandArgs[1..($CommandArgs.Count - 1)]
}

& $exe @rest
exit $LASTEXITCODE
