-- Quick Reloading and Debugging Commands
SLASH_RELOADUI1 = "/rl" -- For quicker reloading of ui
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = "/fs" -- for quicker access to frame stack
SlashCmdList.FRAMESTK = function ()
    LoadAddon('Blizzard_DebugTools')
    FrameStackTooltip_Toggle()
end
--[[Above is the code to reload the UI and access the frame stack quickly.]]
--[[Below is the code to handle boss kill event and combat log event.]]

-- Define a table with the creature names
local bossCreatures = {
    --[[Test "Bosses"]]
    -- Test "Bosses"
    ["Garryowen Boar"] = true,
    ["Deranged Helboar"] = true,
    ["Starving Helboar"] = true,
    --[[Wrath of the Lich King Raids]]
    -- Naxxramas Bosses
    ["Anub'Rekhan"] = true,
    ["Grand Widow Faerlina"] = true,
    ["Maexxna"] = true,
    ["Noth the Plaguebringer"] = true,
    ["Heigan the Unclean"] = true,
    ["Loatheb"] = true,
    ["Instructor Razuvious"] = true,
    ["Gothik the Harvester"] = true,
    ["The Four Horsemen"] = true,
    ["Patchwerk"] = true,
    ["Grobbulus"] = true,
    ["Gluth"] = true,
    ["Thaddius"] = true,
    ["Sapphiron"] = true,
    ["Kel'Thuzad"] = true,
    -- The Eye of Eternity Bosses
    ["Malygos"] = true,
    -- Vault of Archavon Bosses
    ["Archavon the Stone Watcher"] = true,
    ["Emalon the Storm Watcher"] = true,
    ["Koralon the Flame Watcher"] = true,
    ["Toravon the Ice Watcher"] = true,
    -- Obsidian Sanctum Bosses
    ["Sartharion"] = true,
    ["Shadron"] = true,
    ["Tenebron"] = true,
    ["Vesperon"] = true,
    -- Ulduar Bosses
    ["Flame Leviathan"] = true,
    ["Ignis the Furnace Master"] = true,
    ["Razorscale"] = true,
    ["XT-002 Deconstructor"] = true,
    ["The Assembly of Iron"] = true,
    ["Kologarn"] = true,
    ["Auriaya"] = true,
    ["Hodir"] = true,
    ["Thorim"] = true,
    ["Freya"] = true,
    ["Mimiron"] = true,
    ["General Vezax"] = true,
    ["Yogg-Saron"] = true,
    ["Algalon the Observer"] = true,
    -- Trial of the Crusader Bosses
    ["Northrend Beasts"] = true,
    ["Lord Jaraxxus"] = true,
    ["Faction Champions"] = true,
    ["Twin Val'kyr"] = true,
    ["Anub'arak"] = true,
    -- Onyxia's Lair Bosses
    ["Onyxia"] = true,
    -- Icecrown Citadel Bosses
    ["Lord Marrowgar"] = true,
    ["Lady Deathwhisper"] = true,
    ["Gunship Battle"] = true,
    ["Deathbringer Saurfang"] = true,
    ["Festergut"] = true,
    ["Rotface"] = true,
    ["Professor Putricide"] = true,
    ["Blood Prince Council"] = true,
    ["Blood-Queen Lana'thel"] = true,
    ["Valithria Dreamwalker"] = true,
    ["Sindragosa"] = true,
    ["The Lich King"] = true,
    -- Ruby Sanctum Bosses
    ["Halion"] = true,
    -- [[The Burning Crusade Raids]]
    -- Karazhan Bosses
    ["Attumen the Huntsman"] = true,
    ["Moroes"] = true,
    ["Maiden of Virtue"] = true,
    ["Opera Event"] = true,
    ["The Curator"] = true,
    ["Terestian Illhoof"] = true,
    ["Shade of Aran"] = true,
    ["Netherspite"] = true,
    ["Chess Event"] = true,
    ["Prince Malchezaar"] = true,
    ["Nightbane"] = true,
    -- Gruul's Lair Bosses
    ["High King Maulgar"] = true,
    ["Gruul the Dragonkiller"] = true,
    -- Magtheridon's Lair Bosses
    ["Magtheridon"] = true,
    -- Serpentshrine Cavern Bosses
    ["Hydross the Unstable"] = true,
    ["The Lurker Below"] = true,
    ["Leotheras the Blind"] = true,
    ["Fathom-Lord Karathress"] = true,
    ["Morogrim Tidewalker"] = true,
    ["Lady Vashj"] = true,
    -- Tempest Keep Bosses
    ["Al'ar"] = true,
    ["Void Reaver"] = true,
    ["High Astromancer Solarian"] = true,
    ["Kael'thas Sunstrider"] = true,
    -- Black Temple Bosses
    ["High Warlord Naj'entus"] = true,
    ["Supremus"] = true,
    ["Shade of Akama"] = true,
    ["Teron Gorefiend"] = true,
    ["Gurtogg Bloodboil"] = true,
    ["Reliquary of Souls"] = true,
    ["Mother Shahraz"] = true,
    ["Illidari Council"] = true,
    ["Illidan Stormrage"] = true,
    -- Sunwell Plateau Bosses
    ["Kalecgos"] = true,
    ["Brutallus"] = true,
    ["Felmyst"] = true,
    ["Eredar Twins"] = true,
    ["M'uru"] = true,
    ["Kil'jaeden"] = true,
    -- [[Vanilla Raids]]
    -- Molten Core Bosses
    ["Lucifron"] = true,
    ["Magmadar"] = true,
    ["Gehennas"] = true,
    ["Garr"] = true,
    ["Baron Geddon"] = true,
    ["Shazzrah"] = true,
    ["Sulfuron Harbinger"] = true,
    ["Golemagg the Incinerator"] = true,
    ["Majordomo Executus"] = true,
    ["Ragnaros"] = true,
    -- Blackwing Lair Bosses
    ["Razorgore the Untamed"] = true,
    ["Vaelastrasz the Corrupt"] = true,
    ["Broodlord Lashlayer"] = true,
    ["Firemaw"] = true,
    ["Ebonroc"] = true,
    ["Flamegor"] = true,
    ["Chromaggus"] = true,
    ["Nefarian"] = true,
    -- Ruins of Ahn'Qiraj Bosses
    ["Kurinnaxx"] = true,
    ["General Rajaxx"] = true,
    ["Moam"] = true,
    ["Buru the Gorger"] = true,
    ["Ayamiss the Hunter"] = true,
    ["Ossirian the Unscarred"] = true,
    -- Temple of Ahn'Qiraj Bosses
    ["The Prophet Skeram"] = true,
    ["Bug Trio"] = true,
    ["Battleguard Sartura"] = true,
    ["Fankriss the Unyielding"] = true,
    ["Viscidus"] = true,
    ["Princess Huhuran"] = true,
    ["Twin Emperors"] = true,
    ["Ouro"] = true,
    ["C'Thun"] = true,
    -- Zul'Gurub Bosses
    ["High Priest Venoxis"] = true,
    ["High Priestess Jeklik"] = true,
    ["High Priestess Mar'li"] = true,
    ["High Priest Thekal"] = true,
    ["High Priestess Arlokk"] = true,
    ["Hakkar"] = true,
    -- Onyxia's Lair Bosses
    ["Onyxia"] = true,
    -- Add more creature names as needed
}

-- Define multi-boss encounters
local multiBossEncounters = {
    ["Twin Emperors"] = {"Vek'lor", "Vek'nilash"},
    ["The Boars"] = {"Deranged Helboar", "Starving Helboar"},
    ["Bug Trio"] = {"Yauj", "Vem", "Kri"},
}

-- Track killed bosses
local bossKillTracker = {}

-- Function to check if all bosses in a multi-boss encounter are killed
local function checkMultiBossEncounterCompletion(encounterName)
    local bosses = multiBossEncounters[encounterName]
    for _, boss in ipairs(bosses) do
        if not bossKillTracker[boss] then
            return false
        end
    end
    print(encounterName .. " encounter completed!")
    return true
end

-- Event handler for combat log events
local function onCombatLogEvent(self, event, ...)
    local _, subEvent, _, _, _, _, _, destName = ...
    if subEvent == "UNIT_DIED" and bossCreatures[destName] then
        bossKillTracker[destName] = true
        for encounterName, bosses in pairs(multiBossEncounters) do
            checkMultiBossEncounterCompletion(encounterName)
        end
    end
end

-- Register event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", onCombatLogEvent)