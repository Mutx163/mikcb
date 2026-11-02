# 仓库内便携工具链环境注入（不污染全局）。
# 用法：pwsh -NoProfile -File scripts/with-kotlinc.ps1 <command> [args...]
# 把便携 kotlinc / mingit 加入 PATH 后执行后续命令，供 test-kotlin-module.ps1 找到 kotlinc。
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CommandArgs
)
$repoRoot = Split-Path -Parent $PSScriptRoot
$tools = Join-Path (Split-Path -Parent $repoRoot) ".tools"
$kotlincBin = Join-Path $tools "kotlinc\bin"
$mingitBin = Join-Path $tools "mingit\cmd"
$env:PATH = "$kotlincBin;$mingitBin;$env:PATH"
# 便携 kotlinc 默认路径回退：test-kotlin-module.ps1 找不到 AS 内置时走 Get-Command kotlinc
$exe = $CommandArgs[0]
$rest = @()
if ($CommandArgs.Count -gt 1) { $rest = $CommandArgs[1..($CommandArgs.Count - 1)] }
& $exe @rest
exit $LASTEXITCODE
