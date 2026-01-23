local addon = select(2,...)

addon.instance_abbrev = {
	["Icecrown Citadel"] = "ICC",
	--["Ulduar"] = "Uld",
	["Trial of the Champion"] = "ToC",
	["Trial of the Crusader"] = "ToC",
	["Trial of the Grand Crusader"] = "ToGC",  -- does not actually trigger, need to test heroic
	["Vault of Archavon"] = "VoA",
}

addon.boss_abbrev = {
	-- ToC
	["Northrend Beasts"] = "Animal House",
	["Lord Jaraxxus"] = "latest DIAF demon",
	["Faction Champions"] = "Alliance Clusterfuck",
	["Valkyr Twins"] = "Salt'N'Pepa",
	["Val'kyr Twins"] = "Salt'N'Pepa",
	["Anub'arak"] = "Whack-a-Spider",
	-- ICC
	["Lady Deathwhisper"] = "Lady Won't-Stop-Yammering",
	["Gunship"] = "Rocket Shirt Over the Side of the Damn Boat",
	["Gunship Battle"] = "Rocket Shirt Over the Side of the Damn Boat",
	["Professor Putricide"] = "Professor Farnsworth",
	["Valithria Dreamwalker"] = "Dreeeeaaamweaaaaaverrrr",
}

-- vim:noet
