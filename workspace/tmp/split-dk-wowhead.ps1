$lines = Get-Content -Path workspace\tmp\dk-wowhead-builds.lua
$blocks = @()
$current = @()
foreach ($line in $lines) {
  if ($line.Trim().Length -eq 0) {
    if ($current.Count -gt 0) {
      $blocks += ,$current
      $current = @()
    }
    continue
  }
  $current += $line
}
if ($current.Count -gt 0) { $blocks += ,$current }

function Write-Blocks($pattern, $outPath) {
  $selected = @()
  foreach ($block in $blocks) {
    $idLine = ($block | Where-Object { $_ -match '^\s*id = ' })
    if ($idLine -and $idLine -match $pattern) {
      $selected += $block
      $selected += ''
    }
  }
  $selected | Set-Content -Path $outPath
}

Write-Blocks 'DEATHKNIGHT_BLOOD_TANK_' 'workspace\tmp\dk-wowhead-blood-tank.lua'
Write-Blocks 'DEATHKNIGHT_FROST_' 'workspace\tmp\dk-wowhead-frost.lua'
Write-Blocks 'DEATHKNIGHT_UNHOLY_' 'workspace\tmp\dk-wowhead-unholy.lua'
