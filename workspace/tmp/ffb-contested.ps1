$json = '{"buffs":[],"classId":5,"genderId":1,"level":80,"phase":6,"raceId":11,"shapeshiftForm":0,"slots":{"1":{"item":46197,"enchant":59970,"gems":{"0":41401,"1":40113}},"2":{"item":47144,"gems":{"0":40113}},"3":{"item":46190,"enchant":59937,"gems":{"0":40113}},"5":{"item":48031,"enchant":60692,"gems":{"0":40113,"1":40134}},"6":{"item":47084,"gems":{"0":40113,"1":40113,"2":40113}},"7":{"item":46195,"enchant":55634,"gems":{"0":40113,"1":40113}},"8":{"item":47097,"enchant":55016,"gems":{"0":40113,"1":40113}},"9":{"item":47143,"enchant":57691,"gems":{"0":40113}},"10":{"item":46188,"enchant":44592,"gems":{"0":40113}},"11":{"item":47237,"gems":{"0":40151}},"12":{"item":47224,"gems":{"0":40113}},"13":{"item":40432},"14":{"item":47059},"15":{"item":47552,"enchant":63765,"gems":{"0":40113}},"16":{"item":46017,"enchant":60714},"17":{"item":47146},"18":{"item":45294,"gems":{"0":40113}}},"talentHash":"0503203130300512331313231251-20450103_001xr311pbr21pbz31rvm41rm351rms","version":1}'
$export = $json | ConvertFrom-Json
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
 Write-Output ("                $slotName = { itemId = $itemId, enchantId = $enchantId, gemIds = $gemList, notes = \"\", source = \"wowhead\" },")
}
