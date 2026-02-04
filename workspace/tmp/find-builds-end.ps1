$path = 'Goals\wishlistBuildData.lua'
$text = Get-Content -Path $path -Raw
$buildsStartMatch = [regex]::Match($text, 'builds\s*=\s*\{')
$buildsStart = $buildsStartMatch.Index + $buildsStartMatch.Length
$chars = $text.ToCharArray()
$depth = 1
$end = -1
for ($i = $buildsStart; $i -lt $chars.Length; $i++) {
    $ch = $chars[$i]
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') {
        $depth--
        if ($depth -eq 0) { $end = $i; break }
    }
}
"endIndex=$end"
$start = [Math]::Max(0, $end - 100)
$len = [Math]::Min(200, $text.Length - $start)
$text.Substring($start, $len)
