$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$checklistPath = Join-Path $root 'wowhead-wotlk-checklist.txt'
$buildsPath = Join-Path $root 'Goals\wishlistBuildData.lua'

$checklist = Get-Content -LiteralPath $checklistPath
$buildsText = Get-Content -LiteralPath $buildsPath -Raw

function To-ConstName([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $s = $raw.ToUpperInvariant()
    $s = $s -replace '[^A-Z0-9]+', '_'
    $s = $s -replace '^_+', ''
    $s = $s -replace '_+$', ''
    return $s
}

$specDisplayMap = @{
    'BEASTMASTERY' = 'Beast Mastery'
    'MARKSMANSHIP' = 'Marksmanship'
    'RESTORATION' = 'Restoration'
    'PROTECTION' = 'Protection'
    'HOLY' = 'Holy'
    'DISCIPLINE' = 'Discipline'
    'AFFLICTION' = 'Affliction'
    'DEMONOLOGY' = 'Demonology'
    'DESTRUCTION' = 'Destruction'
    'SUBTLETY' = 'Subtlety'
    'ASSASSINATION' = 'Assassination'
    'COMBAT' = 'Combat'
    'ENHANCEMENT' = 'Enhancement'
    'ELEMENTAL' = 'Elemental'
    'SHADOW' = 'Shadow'
    'ARCANE' = 'Arcane'
    'FIRE' = 'Fire'
    'FROST' = 'Frost'
    'BALANCE' = 'Balance'
    'FERAL' = 'Feral'
}

$classDisplayMap = @{
    'DEATHKNIGHT' = 'Deathknight'
    'DRUID' = 'Druid'
    'HUNTER' = 'Hunter'
    'MAGE' = 'Mage'
    'PALADIN' = 'Paladin'
    'PRIEST' = 'Priest'
    'ROGUE' = 'Rogue'
    'SHAMAN' = 'Shaman'
    'WARLOCK' = 'Warlock'
    'WARRIOR' = 'Warrior'
}

$wowheadIds = [System.Collections.Generic.HashSet[string]]::new()
$buildsText -split "`n" | ForEach-Object {
    if ($_ -match 'id\s*=\s*"([A-Z0-9_]+_WOWHEAD(?:_[A-Z0-9_]+)?)"') {
        [void]$wowheadIds.Add($matches[1])
    }
}

$newBuilds = New-Object System.Collections.Generic.List[string]
$addedIds = New-Object System.Collections.Generic.HashSet[string]

$currentClass = $null
$currentSpec = $null
$currentTier = $null

$skipped = New-Object System.Collections.Generic.List[string]

foreach ($line in $checklist) {
    $trim = $line.Trim()

    if ($trim -match '^(DEATHKNIGHT|DRUID|HUNTER|MAGE|PALADIN|PRIEST|ROGUE|SHAMAN|WARLOCK|WARRIOR)\b') {
        $currentClass = $matches[1]
        $currentSpec = $null
        $currentTier = $null
        continue
    }

    if ($trim -match '^-[ ]+(.+)$' -and $currentClass) {
        if ($trim -match '\|\s*export:') { continue }
        $specRaw = $matches[1]
        $specName = ($specRaw -split '\(')[0].Trim()
        $specConst = To-ConstName $specName
        if ($specConst) { $currentSpec = $specConst }
        continue
    }

    if ($trim -match '^(?<mark>✅|❌|-)\s+(?<tier>[^|]+)\|\s*export:\s*(?<export>.*)$') {
        $tierRaw = $matches['tier'].Trim()
        $exportRaw = $matches['export'].Trim()

        if (-not $exportRaw -or $exportRaw -notmatch '\{') { continue }
        if ($exportRaw -match '^PREEXISTING$') { continue }

        $label = $null
        $tierForId = $null

        if ($tierRaw -match '^\^\s*"([^"]+)"\s*$') {
            $label = $matches[1]
            if ([string]::IsNullOrWhiteSpace($currentTier)) { continue }
            $tierForId = $currentTier
        } else {
            if ($tierRaw -match '^(WOTLK_T\d+|WOTLK_PRE)(?:_(.+))?$') {
                $tierForId = To-ConstName $matches[1]
                $label = $matches[2]
            } elseif ($tierRaw -match '^(\S+)\s+"?([^"]+)?"?$') {
                $tierForId = To-ConstName $matches[1]
                $label = $matches[2]
            } else {
                $tierForId = To-ConstName $tierRaw
            }
            if ($label) { $label = $label.Trim('"') }
            if ($tierForId) { $currentTier = $tierForId }
        }

        if ([string]::IsNullOrWhiteSpace($currentClass) -or [string]::IsNullOrWhiteSpace($currentSpec) -or [string]::IsNullOrWhiteSpace($tierForId)) { continue }

        $labelConst = if ($label) { To-ConstName $label } else { $null }
        $id = "$currentClass`_$currentSpec`_$tierForId`_WOWHEAD"
        if ($labelConst) { $id = "$id`_$labelConst" }

        if (-not $wowheadIds.Contains($id) -and -not $addedIds.Contains($id)) {
            $classDisplay = $classDisplayMap[$currentClass]
            $specDisplay = if ($specDisplayMap.ContainsKey($currentSpec)) { $specDisplayMap[$currentSpec] } else { $currentSpec.Substring(0,1).ToUpper() + $currentSpec.Substring(1).ToLower() }
            $name = if ($labelConst) { "$classDisplay $specDisplay $label - Wowhead" } else { "$classDisplay $specDisplay - Wowhead" }

            $json = $exportRaw
            $braceIdx = $json.IndexOf('{')
            if ($braceIdx -gt 0) { $json = $json.Substring($braceIdx) }
            if (-not $json.StartsWith('{')) { $skipped.Add($trim); continue }

            try {
                $export = $json | ConvertFrom-Json
            } catch {
                $skipped.Add($trim)
                continue
            }

            $block = New-Object System.Collections.Generic.List[string]
            $block.Add('        {')
            $block.Add('            id = "' + $id + '",')
            $block.Add('            name = "' + $name + '",')
            $block.Add('            class = "' + $currentClass + '",')
            $block.Add('            spec = "' + $specDisplay + '",')
            $block.Add('            tier = "' + $tierForId + '",')
            $block.Add('            level = 80,')
            $block.Add('            tags = {"bis", "wowhead"},')
            $block.Add('            itemsBySlot = {')

            $slotMap = @{
                '1'='HEAD'; '2'='NECK'; '3'='SHOULDER'; '5'='CHEST'; '6'='WAIST'; '7'='LEGS';
                '8'='FEET'; '9'='WRIST'; '10'='HANDS'; '11'='RING1'; '12'='RING2'; '13'='TRINKET1'; '14'='TRINKET2';
                '15'='BACK'; '16'='MAINHAND'; '17'='OFFHAND'; '18'='RELIC'
            }

            foreach ($slotKey in $export.slots.PSObject.Properties.Name) {
                $slotName = $slotMap[$slotKey]
                if (-not $slotName) { continue }
                $slot = $export.slots.$slotKey
                $itemId = [int]$slot.item
                $enchantId = if ($slot.PSObject.Properties.Name -contains 'enchant') { [int]$slot.enchant } else { 0 }
                $gemIds = @()
                if ($slot.PSObject.Properties.Name -contains 'gems') {
                    foreach ($g in $slot.gems.PSObject.Properties.Name) { $gemIds += [int]$slot.gems.$g }
                }
                $gemList = if ($gemIds.Count -gt 0) { '{ ' + ($gemIds -join ', ') + ' }' } else { '{}' }
                $block.Add('                ' + $slotName + ' = { itemId = ' + $itemId + ', enchantId = ' + $enchantId + ', gemIds = ' + $gemList + ', notes = "", source = "wowhead" },')
            }

            $block.Add('            },')
            $block.Add('            sources = {"wowhead"},')
            $block.Add('            notes = "Imported directly from Wowhead WotLK gear planner export. Item, enchant, and gem IDs preserved from import string.",')
            $block.Add('        },')

            $newBuilds.Add(($block -join "`n"))
            [void]$addedIds.Add($id)
        }
    }
}

if ($newBuilds.Count -gt 0) {
    $marker = 'id = "WARLOCK_DESTRUCTION_WOTLK_PRE_LOONBIS"'
    $idx = $buildsText.IndexOf($marker)
    if ($idx -lt 0) { throw "Marker not found in builds file." }

    $insertPos = $buildsText.LastIndexOf('        {', $idx)
    if ($insertPos -lt 0) { throw "Insert position not found." }

    $prefix = $buildsText.Substring(0, $insertPos)
    $suffix = $buildsText.Substring($insertPos)

    $insertion = ($newBuilds -join "`n`n") + "`n"
    $buildsText = $prefix + $insertion + $suffix
}

Set-Content -LiteralPath $buildsPath -Value $buildsText -Encoding UTF8

"added=$($newBuilds.Count)"
"skipped=$($skipped.Count)"
if ($skipped.Count -gt 0) { $skipped | Select-Object -First 5 }
