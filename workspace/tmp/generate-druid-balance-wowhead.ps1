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
  if ($line -match '^-\s+(.+)$' -and -not ($line -like '  -*')) {
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

  $label = $null
  $jsonText = $export
  if ($jsonText -match '^"([^\"]+)"\s*(\{.*)$') {
    $label = $matches[1]
    $jsonText = $matches[2]
  }

  try {
    $data = $jsonText | ConvertFrom-Json -ErrorAction Stop
  } catch {
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

$slotMap = @{
  1='HEAD';2='NECK';3='SHOULDER';4='SHIRT';5='CHEST';6='WAIST';7='LEGS';8='FEET';9='WRIST';10='HANDS';11='RING1';12='RING2';13='TRINKET1';14='TRINKET2';15='BACK';16='MAINHAND';17='OFFHAND';18='RELIC';19='TABARD'
}
$slotOrder = @('HEAD','NECK','SHOULDER','BACK','CHEST','WRIST','HANDS','WAIST','LEGS','FEET','RING1','RING2','TRINKET1','TRINKET2','MAINHAND','OFFHAND','RELIC')

function Get-BaseTier([string]$tier) {
  if ($tier -match '^(WOTLK_[A-Z0-9]+)') { return $matches[1] }
  return $tier
}

function Label-To-Suffix([string]$label) {
  if (-not $label) { return '' }
  $label = $label.ToUpper() -replace '[^A-Z0-9]+','_'
  $label = $label.Trim('_')
  return $label
}

$balanceEntries = $entries | Where-Object { $_.Class -eq 'DRUID' -and $_.Spec -eq 'Balance' }
$out = New-Object System.Collections.Generic.List[string]

foreach ($entry in $balanceEntries) {
  $specName = $entry.Spec
  $specId = ($specName.ToUpper() -replace '[^A-Z0-9]+','_').Trim('_')
  $baseTier = Get-BaseTier $entry.Tier
  $labelSuffix = Label-To-Suffix $entry.Label
  $idSuffix = if ($labelSuffix) { '_' + $labelSuffix } else { '' }
  $id = 'DRUID_' + $specId + '_' + $baseTier + $idSuffix + '_WOWHEAD'

  $tierName = $baseTier.Replace('WOTLK_', '')
  if ($tierName -eq 'PRE') { $tierName = 'PRE' }
  $labelName = if ($entry.Label) { ' (' + $entry.Label + ')' } else { '' }
  $name = $tierName + ' Druid ' + $specName + $labelName + ' - Wowhead WotLK'

  $tags = @('bis')
  if ($baseTier -eq 'WOTLK_PRE' -and (-not ($entry.Label -match '(?i)bis'))) {
    $tags = @('progression')
  }

  $slotData = @{}
  $slots = $entry.Data.slots
  foreach ($prop in $slots.PSObject.Properties) {
    $slotKey = [int]$prop.Name
    $slotName = $slotMap[$slotKey]
    if (-not $slotName -or $slotName -eq 'SHIRT' -or $slotName -eq 'TABARD') { continue }
    $slotData[$slotName] = $prop.Value
  }

  $items = New-Object System.Collections.Generic.List[string]
  foreach ($slotName in $slotOrder) {
    if (-not $slotData.ContainsKey($slotName)) { continue }
    $slot = $slotData[$slotName]
    if (-not $slot.item) { continue }
    $enchant = if ($null -ne $slot.enchant) { [int]$slot.enchant } else { 0 }
    $gemIds = @()
    if ($slot.gems) {
      $gemKeys = $slot.gems.PSObject.Properties.Name | Sort-Object {[int]$_}
      foreach ($gk in $gemKeys) { $gemIds += [int]$slot.gems.$gk }
    }
    $gemStr = ($gemIds -join ', ')
    $items.Add('                ' + $slotName + ' = { itemId = ' + $slot.item + ', enchantId = ' + $enchant + ', gemIds = {' + $gemStr + '}, notes = "", source = "wowhead" },')
  }

  $tagsStr = ($tags | ForEach-Object { '"' + $_ + '"' }) -join ', '

  $out.Add('        {')
  $out.Add('            id = "' + $id + '",')
  $out.Add('            name = "' + $name + '",')
  $out.Add('            class = "DRUID",')
  $out.Add('            spec = "' + $specName + '",')
  $out.Add('            tier = "' + $baseTier + '",')
  $out.Add('            level = 80,')
  $out.Add('            tags = {' + $tagsStr + '},')
  $out.Add('            itemsBySlot = {')
  foreach ($item in $items) { $out.Add($item) }
  $out.Add('            },')
  $out.Add('            sources = {"wowhead"},')
  $out.Add('            notes = "Phase data ''' + $tierName.ToLower() + ''' sourced from Wowhead gear planner.",')
  $out.Add('        },')
  $out.Add('')
}

$out | Set-Content -Path workspace\tmp\druid-balance-wowhead-builds.lua
