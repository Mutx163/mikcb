$ErrorActionPreference='Stop'
$f='lib/screens/timetable_settings_screen.dart'
$text=[IO.File]::ReadAllText($f)
$lines=$text -split "`n"
$out=New-Object System.Collections.Generic.List[string]
$mode=$null
$modeIndent=0
$variantPending=$false
$rTonalIcon=[regex]'\.tonalIcon\(\s*$'
$rTonal=[regex]'\.tonal\(\s*$'
$rBase=[regex]'FilledButton\(\s*$'
for($i=0;$i -lt $lines.Count;$i++){
  $line=$lines[$i]
  $trim=$line.Trim()
  $ls=$line.Length-$line.TrimStart(' ').Length
  if($variantPending){
    $v=switch($mode){ 'tonalIcon'{'secondary'} 'tonal'{'secondary'} 'base'{'primary'} }
    $out.Add((' '*$ls)+"variant: FButtonVariant.$v,")
    $variantPending=$false
  }
  if($null -ne $mode -and ($trim -eq '),' -or $trim -eq ')') -and $ls -eq $modeIndent){
    $out.Add($line)
    $mode=$null
    $modeIndent=0
    continue
  }
  if($rTonalIcon.IsMatch($line)){ $out.Add($line.Substring(0,$ls)+'FButton('); $mode='tonalIcon'; $modeIndent=$ls; $variantPending=$true; continue }
  if($rTonal.IsMatch($line)){ $out.Add($line.Substring(0,$ls)+'FButton('); $mode='tonal'; $modeIndent=$ls; $variantPending=$true; continue }
  if($rBase.IsMatch($line)){ $out.Add($line.Substring(0,$ls)+'FButton('); $mode='base'; $modeIndent=$ls; $variantPending=$true; continue }
  if($null -ne $mode){
    $ln=$line
    if($mode -eq 'tonalIcon'){
      $ln=[regex]::Replace($ln,'^(\s*)icon:','${1}prefix:')
      $ln=[regex]::Replace($ln,'^(\s*)label: Text\(','${1}child: Text(')
    }
    $ln=[regex]::Replace($ln,'^(\s*)onPressed:','${1}onPress:')
    $out.Add($ln)
    continue
  }
  $out.Add($line)
}
$res=($out -join "`n")
if(-not $res.EndsWith("`n")){ $res+="`n" }
[IO.File]::WriteAllText($f,$res)
Write-Output ("FilledButton: "+(Select-String -Path $f -Pattern 'FilledButton' -AllMatches).Count)
Write-Output ("FButton(: "+(Select-String -Path $f -Pattern '\bFButton\(' -AllMatches).Count)
Write-Output ("onPressed: "+(Select-String -Path $f -Pattern 'onPressed:' -AllMatches).Count)
Write-Output ("variant: "+(Select-String -Path $f -Pattern 'variant: FButtonVariant' -AllMatches).Count)
Write-Output ("prefix: "+(Select-String -Path $f -Pattern 'prefix: ' -AllMatches).Count)
