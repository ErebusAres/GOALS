-- Goals: bossEncounters.lua
-- Boss list used for encounter detection.
-- Usage: _G.bossEncounters["Encounter Name"] = { "Boss Name", "Boss Name 2" }
-- Table of boss creatures, including multi-boss encounters
_G.bossEncounters = {
    --[[Vanilla WoW Raids]]
    --T0 Zul'Gurub Bosses
    ["High Priestess Jeklik"] = { "High Priestess Jeklik" },
    ["High Priest Venoxis"] = { "High Priest Venoxis" },
    ["High Priestess Mar'li"] = { "High Priestess Mar'li" },
    ["High Priest Thekal"] = { "High Priest Thekal" },
    ["High Priestess Arlokk"] = { "High Priestess Arlokk" },
    ["Hakkar"] = { "Hakkar" },
    --Optional Zul'Gurub Bosses
    ["Bloodlord Encounter"] = { "Bloodlord Mandokir", "Ohgan" },
    ["Edge of Madness: Gri'lek"] = { "Gri'lek" },
    ["Edge of Madness: Hazza'rah"] = { "Hazza'rah" },
    ["Edge of Madness: Renataki"] = { "Renataki" },
    ["Edge of Madness: Wushoolay"] = { "Wushoolay" },
    ["Gahz'ranka"] = { "Gahz'ranka" },
    ["Jin'do the Hexxer"] = { "Jin'do the Hexxer" },
    --T1 Molten Core Bosses
    ["Lucifron"] = { "Lucifron" },
    ["Magmadar"] = { "Magmadar" },
    ["Gehennas"] = { "Gehennas" },
    ["Garr"] = { "Garr" },
    ["Baron Geddon"] = { "Baron Geddon" },
    ["Shazzrah"] = { "Shazzrah" },
    ["Sulfuron Harbinger"] = { "Sulfuron Harbinger" },
    ["Golemagg the Incinerator"] = { "Golemagg the Incinerator" },
    ["Majordomo Executus"] = { "Majordomo Executus" },
    ["Ragnaros"] = { "Ragnaros" },
    --T0 Ruins of Ahn'Qiraj Bosses
    ["Kurinnaxx"] = { "Kurinnaxx" },
    ["General Rajaxx"] = { "General Rajaxx" },
    ["Moam"] = { "Moam" },
    ["Buru the Gorger"] = { "Buru the Gorger" },
    ["Ayamiss the Hunter"] = { "Ayamiss the Hunter" },
    ["Ossirian the Unscarred"] = { "Ossirian the Unscarred" },
    --T2 Blackwing Lair Bosses
    ["Razorgore the Untamed"] = { "Razorgore the Untamed" },
    ["Vaelastrasz the Corrupt"] = { "Vaelastrasz the Corrupt" },
    ["Broodlord Lashlayer"] = { "Broodlord Lashlayer" },
    ["Firemaw"] = { "Firemaw" },
    ["Ebonroc"] = { "Ebonroc" },
    ["Flamegor"] = { "Flamegor" },
    ["Chromaggus"] = { "Chromaggus" },
    ["Nefarian"] = { "Nefarian" },
    --T2.5 Ahn'Qiraj Bosses
    ["The Prophet Skeram"] = { "The Prophet Skeram" },
    ["Battleguard Sartura"] = { "Battleguard Sartura" },
    ["Fankriss the Unyielding"] = { "Fankriss the Unyielding" },
    ["Princess Huhuran"] = { "Princess Huhuran" },
    ["Twin Emperors"] = { "Emperor Vek'lor", "Emperor Vek'nilash" },
    ["C'Thun"] = { "C'Thun" },
    --Optional Ahn'Qiraj Bosses
    ["Bug Trio"] = { "Lord Kri", "Princess Yauj", "Vem" },
    ["Viscidus"] = { "Viscidus" },
    ["Ouro"] = { "Ouro" },
    --[[The Burning Crusade Raids]]
    --T4 Karazhan Bosses
    ["Attumen the Huntsman"] = { "Attumen the Huntsman" },
    ["Prince Tenris Mirkblood"] = { "Prince Tenris Mirkblood" },
    ["Moroes"] = { "Moroes" },
    ["Maiden of Virtue"] = { "Maiden of Virtue" },
    ["Opera Event, Romulo and Julianne"] = { "Romulo", "Julianne" },
    ["Opera Event, Wizard of Oz"] = { "The Crone" },
    ["Opera Event, Big Bad Wolf"] = { "The Big Bad Wolf" },
    ["The Curator"] = { "The Curator" },
    ["Chess Event"] = {
        "King Llane",
        "Grand Marshal Bolvar Fordragon",
        "Marshal Windsor",
        "Conjurer",
        "Cleric",
        "Footman",
        "Warchief Blackhand",
        "High Warlord",
        "Orc Wolf",
        "Summoner",
        "Necrolyte",
        "Grunt",
    },
    ["Terestian Illhoof"] = { "Terestian Illhoof" },
    ["Shade of Aran"] = { "Shade of Aran" },
    ["Netherspite"] = { "Netherspite" },
    ["Nightbane"] = { "Nightbane" },
    ["Prince Malchezaar"] = { "Prince Malchezaar" },
    --T4 Gruul's Lair Bosses
    ["High King Maulgar"] = { "High King Maulgar", "Kiggler the Crazed", "Blindeye the Seer", "Olm the Summoner", "Krosh Firehand" },
    ["Gruul the Dragonkiller"] = { "Gruul the Dragonkiller" },
    --T4 Magtheridon's Lair Bosses
    ["Magtheridon"] = { "Magtheridon" },
    --T5 Serpentshrine Cavern Bosses
    ["Hydross the Unstable"] = { "Hydross the Unstable" },
    ["The Lurker Below"] = { "The Lurker Below" },
    ["Leotheras the Blind"] = { "Leotheras the Blind" },
    ["Fathom-Lord Karathress"] = { "Fathom-Lord Karathress" },
    ["Morogrim Tidewalker"] = { "Morogrim Tidewalker" },
    ["Lady Vashj"] = { "Lady Vashj" },
    --T5 Tempest Keep Bosses
    ["Void Reaver"] = { "Void Reaver" },
    ["Al'ar"] = { "Al'ar" },
    ["High Astromancer Solarian"] = { "High Astromancer Solarian" },
    ["Kael'thas Sunstrider"] = {
        "Thaladred the Darkener",
        "Master Engineer Telonicus",
        "Grand Astromancer Capernian",
        "Lord Sanguinar",
        "Kael'thas Sunstrider",
    },
    --T6 Hyjal Summit Bosses
    ["Rage Winterchill"] = { "Rage Winterchill" },
    ["Anetheron"] = { "Anetheron" },
    ["Milleniax"] = { "Milleniax" }, -- Custom GO Boss.
    ["Kaz'rogal"] = { "Kaz'rogal" },
    ["Azgalor"] = { "Azgalor" },
    ["Archimonde"] = { "Archimonde" },
    --T6 Black Temple Bosses
    ["High Warlord Naj'entus"] = { "High Warlord Naj'entus" },
    ["Supremus"] = { "Supremus" },
    ["Shade of Akama"] = { "Shade of Akama" },
    ["Teron Gorefiend"] = { "Teron Gorefiend" },
    ["Gurtogg Bloodboil"] = { "Gurtogg Bloodboil" },
    ["Reliquary of Souls"] = { "Essence of Suffering", "Essence of Desire", "Essence of Anger" },
    ["Mother Shahraz"] = { "Mother Shahraz" },
    ["Illidari Council"] = { "Gathios the Shatterer", "High Nethermancer Zerevor", "Lady Malande", "Veras Darkshadow" },
    ["Illidan Stormrage"] = { "Illidan Stormrage" },
    --T0 Zul'Aman Bosses
    ["Nalorakk"] = { "Nalorakk" },
    ["Akil'zon"] = { "Akil'zon" },
    ["Jan'alai"] = { "Jan'alai" },
    ["Halazzi"] = { "Halazzi" },
    ["Hex Lord Malacrass"] = { "Hex Lord Malacrass" },
    --["Thurg"] = { "Thurg" }, -- Thurg is classified as a Boss, but is one of 8 possible adds in the Hex Lord Malacrass encounter. 
    ["Zul'jin"] = { "Zul'jin" },
    ["Daakara"] = { "Daakara" },
    --T6 Sunwell Plateau Bosses
    ["Kalecgos"] = { "Kalecgos", "Sathrovarr the Corruptor" },
    ["Brutallus"] = { "Brutallus" },
    ["Felmyst"] = { "Felmyst" },
    ["Eredar Twins"] = { "Lady Sacrolash", "Grand Warlock Alythess" },
    ["M'uru"] = { "M'uru", "Entropius" },
    ["Kil'jaeden"] = { "Kil'jaeden" },
    --[[Wrath of the Lich King Raids]]
    --Vault of Archavon Bosses --Vault was added in 3.4.0
    ["Archavon the Stone Watcher"] = { "Archavon the Stone Watcher" },
    ["Emalon the Storm Watcher"] = { "Emalon the Storm Watcher" },
    ["Koralon the Flame Watcher"] = { "Koralon the Flame Watcher" },
    ["Toravon the Ice Watcher"] = { "Toravon the Ice Watcher" },
    --T7 Naxxramas Bosses
    -- The Arachnid Quarter
    ["Anub'Rekhan"] = { "Anub'Rekhan" },
    ["Grand Widow Faerlina"] = { "Grand Widow Faerlina" },
    ["Maexxna"] = { "Maexxna" },
    -- The Plague Quarter
    ["Noth the Plaguebringer"] = { "Noth the Plaguebringer" },
    ["Heigan the Unclean"] = { "Heigan the Unclean" },
    ["Loatheb"] = { "Loatheb" },
    -- The Military Quarter
    ["Instructor Razuvious"] = { "Instructor Razuvious" },
    ["Gothik the Harvester"] = { "Gothik the Harvester" },
    ["The Four Horsemen"] = { "Thane Korth'azz", "Baron Rivendare", "Lady Blaumeux", "Sir Zeliek" },
    -- The Construct Quarter
    ["Patchwerk"] = { "Patchwerk" },
    ["Grobbulus"] = { "Grobbulus" },
    ["Gluth"] = { "Gluth" },
    ["Thaddius"] = { "Thaddius" },
    -- Frostwyrm Lair
    ["Sapphiron"] = { "Sapphiron" },
    ["Kel'Thuzad"] = { "Kel'Thuzad" },
    --T7 The Obsidian Sanctum Bosses
    ["Sartharion"] = { "Sartharion" },
    ["Shadron"] = { "Shadron" },
    ["Tenebron"] = { "Tenebron" },
    ["Vesperon"] = { "Vesperon" },
    --T0 The Eye of Eternity Bosses
    ["Malygos"] = { "Malygos" },
    --T8 Ulduar Bosses
    -- The Siege of Ulduar
    ["Flame Leviathan"] = { "Flame Leviathan" },
    ["Ignis the Furnace Master"] = { "Ignis the Furnace Master" },
    ["Razorscale"] = { "Razorscale" },
    ["XT-002 Deconstructor"] = { "XT-002 Deconstructor" },
    -- The Antechamber of Ulduar
    ["The Assembly of Iron"] = { "Steelbreaker", "Molgeim", "Brundir" },
    ["Kologarn"] = { "Kologarn" },
    ["Auriaya"] = { "Auriaya" },
    -- The Keepers of Ulduar
    ["Hodir"] = { "Hodir" },
    ["Thorim"] = { "Thorim" },
    ["Freya"] = { "Freya" },
    ["Mimiron"] = { "Leviathan Mk II", "VX-001", "Aerial Command Unit", "Mimiron" },
    -- The Descent into Madness
    ["General Vezax"] = { "General Vezax" },
    ["Yogg-Saron"] = { "Yogg-Saron" },
    -- Celestial Planetarium
    ["Algalon the Observer"] = { "Algalon the Observer" },
    --T0 Trial of the Cruisader Bosses
    ["Northrend Beasts P1"] = { "Gormok the Impaler" },
    ["Northrend Beasts P2"] = {"Acidmaw", "Dreadscale"},
    ["Northrend Beasts P3"] = {"Icehowl"},
    --["Northrend Beasts"] = { "Gormok the Impaler", "Acidmaw", "Dreadscale", "Icehowl" }, -- Northrend Beasts is a Multi-Part Boss Encounter that can either be classified as 3 Participations or 1.
    ["Lord Jaraxxus"] = { "Lord Jaraxxus" },
    ["Faction Champions"] = { "Faction Champions" },
    ["Twin Val'kyr"] = { "Eydis Darkbane", "Fjola Lightbane" },
    ["Anub'arak"] = { "Anub'arak" },
    --T0 Onyxia's Lair Bosses
    ["Onyxia"] = { "Onyxia" },
    --T9 Icecrown Citadel Bosses
    -- The Lower Spire
    ["Lord Marrowgar"] = { "Lord Marrowgar" },
    ["Lady Deathwhisper"] = { "Lady Deathwhisper" },
    --["Icecrown Gunship Battle"] = { "Horde Gunship" },
    --["Icecrown Gunship Battle"] = { "Alliance Gunship" },
    ["Icecrown Gunship Battle: Horde"] = { "Muradin Bronzebeard" }, --Alliance Gunship; Muradin Bronzebeard is Technically an Elite. 
    ["Icecrown Gunship Battle: Alliance"] = { "High Overlord Saurfang" }, --Horde Gunship; High Overlord Saurfang is Technically an Elite. 
    ["Deathbringer Saurfang"] = { "Deathbringer Saurfang" },
    -- The Plagueworks
    ["Festergut"] = { "Festergut" },
    ["Rotface"] = { "Rotface" },
    ["Professor Putricide"] = { "Professor Putricide" },
    -- The Crimson Hall
    ["Blood Prince Council"] = { "Prince Valanar", "Prince Keleseth", "Prince Taldaram" },
    ["Blood-Queen Lana'thel"] = { "Blood-Queen Lana'thel" },
    -- Frostwing Halls
    --["Valithria Dreamwalker"] = { "Valithria Dreamwalker" }, --Valithria is an Allied unit, so we'll need to come up with a way to track her encounter completion, if needed.
    ["Sindragosa"] = { "Sindragosa" },
    -- The Frozen Throne
    ["The Lich King"] = { "The Lich King" },
    --T0 The Ruby Sanctum Bosses
    ["Halion"] = { "Halion" },
    --[[World Bosses]] -- Are we including World Bosses??
    ["Azuregos"] = { "Azuregos" }, -- Azshara World Boss
    ["Doom Lord Kazzak"] = { "Doom Lord Kazzak" }, -- Hellfire Peninsula World Boss
    ["Doomwalker"] = { "Doomwalker" }, -- Shadowmoon Valley World Boss
    ["Lord Kazzak"] = { "Lord Kazzak" }, -- Blasted Lands World Boss
    ["Emeriss"] = { "Emeriss" }, -- Duskwood World Boss
    ["Lethon"] = { "Lethon" }, -- Feralas World Boss
    ["Ysondre"] = { "Ysondre" }, -- Hinterlands World Boss
    ["Taerar"] = { "Taerar" }, -- Ashenvale World Boss
    ["Highlord Kruul"] = { "Highlord Kruul" }, -- This Boss can be found in Searing Gorge, and many other locations.
    ["King Terokk"] = { "King Terokk" }, -- Terokkar Forest World Boss (Custom GO Boss)
    -- Add more creature names as needed
}

-- Encounter-specific rules for multi-kill or revive mechanics.
_G.encounterRules = {
    ["Opera Event, Romulo and Julianne"] = {
        type = "pair_revive",
        bosses = { "Romulo", "Julianne" },
        requiredKills = 1,
        reviveWindow = 10,
    },
    ["Mimiron"] = {
        type = "multi_death_window",
        bosses = { "Leviathan Mk II", "VX-001", "Aerial Command Unit" },
        requiredKills = 1,
        reviveWindow = 15,
    },
    ["High Priest Thekal"] = {
        type = "multi_kill",
        bosses = { "High Priest Thekal" },
        requiredKills = 2,
    },
    ["Kalecgos"] = {
        type = "pair_revive",
        bosses = { "Kalecgos", "Sathrovarr the Corruptor" },
        requiredKills = 1,
        reviveWindow = 10,
    },
    ["Al'ar"] = {
        type = "multi_kill",
        bosses = { "Al'ar" },
        requiredKills = 2,
    },
    ["Reliquary of Souls"] = {
        type = "final_boss_kill",
        finalBoss = "Essence of Anger",
    },
}

return _G.bossEncounters
