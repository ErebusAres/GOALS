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

$wowheadIds = [System.Collections.Generic.HashSet[string]]::new()
$buildsText -split "`n" | ForEach-Object {
    if ($_ -match 'id\s*=\s*"([A-Z0-9_]+_WOWHEAD(?:_[A-Z0-9_]+)?)"') {
        [void]$wowheadIds.Add($matches[1])
    }
}

$currentClass = $null
$currentSpec = $null
$currentTier = $null

$out = New-Object System.Collections.Generic.List[string]

foreach ($line in $checklist) {
    $trim = $line.Trim()

    if ($trim -match '^(DEATHKNIGHT|DRUID|HUNTER|MAGE|PALADIN|PRIEST|ROGUE|SHAMAN|WARLOCK|WARRIOR)\b') {
        $currentClass = $matches[1]
        $currentSpec = $null
        $currentTier = $null
        $out.Add($line)
        continue
    }

    if ($trim -match '^-[ ]+(.+)$' -and $currentClass) {
        if ($trim -match '\|\s*export:') {
            # build line, handled below
        } else {
            $specRaw = $matches[1]
            $specName = ($specRaw -split '\(')[0].Trim()
            $specConst = To-ConstName $specName
            if ($specConst) { $currentSpec = $specConst }
            $out.Add($line)
            continue
        }
    }

    if ($trim -match '^(?<mark>✅|❌|-)\s+(?<tier>[^|]+)\|\s*export:\s*(?<export>.*)$') {
        $tierRaw = $matches['tier'].Trim()
        $exportRaw = $matches['export'].Trim()

        if (-not $exportRaw) { $out.Add($line); continue }
        if ($exportRaw -match '^PREEXISTING$') { $out.Add($line); continue }

        $label = $null
        $tierForId = $null

        if ($tierRaw -match '^\^\s*"([^"]+)"\s*$') {
            $label = $matches[1]
            if ([string]::IsNullOrWhiteSpace($currentTier)) { $out.Add($line); continue }
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

        if ([string]::IsNullOrWhiteSpace($currentClass) -or [string]::IsNullOrWhiteSpace($currentSpec) -or [string]::IsNullOrWhiteSpace($tierForId)) {
            $out.Add($line)
            continue
        }

        $labelConst = if ($label) { To-ConstName $label } else { $null }
        $id = "$currentClass`_$currentSpec`_$tierForId`_WOWHEAD"
        if ($labelConst) { $id = "$id`_$labelConst" }

        if ($wowheadIds.Contains($id)) {
            $tierOut = $tierForId
            if ($labelConst) { $tierOut = "$tierOut`_$labelConst" }
            $out.Add(('  ✅ ' + $tierOut + ' | export: ' + $exportRaw))
        } else {
            $out.Add($line)
        }
        continue
    }

    $out.Add($line)
}

Set-Content -LiteralPath $checklistPath -Value $out -Encoding UTF8
"updated"
