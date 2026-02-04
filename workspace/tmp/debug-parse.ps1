$path = 'Goals\wishlistBuildData.lua'
$text = Get-Content -Path $path -Raw
$buildsStartMatch = [regex]::Match($text, 'builds\s*=\s*\{')
$buildsStart = $buildsStartMatch.Index + $buildsStartMatch.Length
$chars = $text.ToCharArray()
$depth = 1
$blocks = @()
$blockStart = -1
for ($i = $buildsStart; $i -lt $chars.Length; $i++) {
    $ch = $chars[$i]
    if ($ch -eq '{') {
        if ($depth -eq 1) { $blockStart = $i }
        $depth++
    } elseif ($ch -eq '}') {
        $depth--
        if ($depth -eq 1 -and $blockStart -ge 0) {
            $blockEnd = $i
            $j = $i + 1
            while ($j -lt $chars.Length -and ($chars[$j] -match '[\s,]')) { $j++ }
            $blocks += $text.Substring($blockStart, $j - $blockStart)
            $blockStart = -1
            $i = $j - 1
        } elseif ($depth -eq 0) { break }
    }
}
"blocks=$($blocks.Count)"
$idx = 500
$block = $blocks[$idx]
$block.Substring(0,300)
$cm = [regex]::Match($block, 'class\s*=\s*"([A-Z]+)"')
$sm = [regex]::Match($block, 'spec\s*=\s*"([^"]+)"')
"classMatch=$($cm.Success) value=$($cm.Groups[1].Value)"
"specMatch=$($sm.Success) value=$($sm.Groups[1].Value)"
