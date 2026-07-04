$f='lib\screens\timetable_settings_screen.dart'
$items = @(
 'Scaffold','Card','Switch','IconButton','ExpansionTile','ListTile','InkWell',
 'TextField','PopupMenuButton','Slider','AlertDialog','DropdownButtonFormField','SegmentedButton'
)
foreach($w in $items) {
  $p = "(?<![A-Za-z])$w" + '\('
  $m = Select-String -Path $f -Pattern $p -AllMatches
  $lines = ($m | ForEach-Object { $_.LineNumber }) -join ','
  "$w ($($m.Count)): $lines"
}
"--- showDialog ---"
$m = Select-String -Path $f -Pattern 'showDialog' -AllMatches
($m | ForEach-Object { $_.LineNumber }) -join ','
"--- showModalBottomSheet ---"
$m = Select-String -Path $f -Pattern 'showModalBottomSheet' -AllMatches
($m | ForEach-Object { $_.LineNumber }) -join ','
"--- other Scaffold (confirm remaining) ---"
