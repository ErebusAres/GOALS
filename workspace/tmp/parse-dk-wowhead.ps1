$path = 'wowhead-wotlk-checklist.txt'
$lines = Get-Content -Path $path
$currentClass = $null
$currentSpec = $null
$entries = @()

foreach ($line in $lines) {
  if ($line.Trim().Length -eq 0) { continue }
  if ($line.Trim() -match '^[A-Z]+$') {
    $currentClass = $line.Trim()
    $currentSpec = $null
    continue
  }
  if ($line -match '^\-\s+(.+)$' -and -not ($line -like '  -*')) {
    $currentSpec = $matches[1].Trim()
    continue
  }
  $tier = $null
  $export = $null
  if ($line -match '^\s{2}-\s+([^\s]+)\s+\|\s+URL:.*Export:\s*(.*)\s*\|\s*Status:') {
    $tier = $matches[1].Trim()
    $export = $matches[2].Trim()
  } elseif ($line -match '^\s{2}-\s+([^\s]+)\s+\|\s+Export:\s*(.*)$') {
    $tier = $matches[1].Trim()
    $export = $matches[2].Trim()
  }
  if (-not $tier -or -not $export) { continue }
  if (-not $currentClass -or -not $currentSpec) { continue }

  if (-not $export) { continue }
  $label = $null
  $jsonText = $export
  if ($jsonText -match '^"([^"]+)"\s*(\{.*)$') {
    $label = $matches[1]
    $jsonText = $matches[2]
  }

  try {
    $data = $jsonText | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Write-Host "Failed to parse JSON for $currentClass/$currentSpec/$tier"
    continue
  }

  $entries += [pscustomobject]@{
    Class = $currentClass
    Spec = $currentSpec
    Tier = $tier
    Label = $label
    Data = $data
  }
}

$entries | Where-Object { $_.Class -eq 'DEATHKNIGHT' } | ForEach-Object {
  $specId = ($_.Spec.ToUpper() -replace '[^A-Z0-9]+','_')
  $labelSuffix = if ($_.Label) { '_' + ($_.Label.ToUpper() -replace '[^A-Z0-9]+','_') } else { '' }
  $id = "DEATHKNIGHT_${specId}_${($_.Tier)}${labelSuffix}_WOWHEAD"
  Write-Host $id
}
