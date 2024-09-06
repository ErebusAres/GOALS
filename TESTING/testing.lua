-- Table of boss creatures, including multi-boss encounters
local bossEncounters = {
    --[[Test Encounters]]
    ["The Boars"] = { "Deranged Helboar", "Starving Helboar" },
    ["Garryowen Boar"] = { "Garryowen Boar" },
    --[[Vanilla WoW Raids]]
    --Ahn'Qiraj Bosses
    ["The Prophet Skeram"] = { "The Prophet Skeram" },
    ["Twin Emperors"] = { "Vek'lor", "Vek'nilash" },
    ["Bug Trio"] = { "Yauj", "Vem", "Kri" },
    ["The Prophet Skeram"] = { "The Prophet Skeram" },
    ["Battleguard Sartura"] = { "Battleguard Sartura" },
    ["Fankriss the Unyielding"] = { "Fankriss the Unyielding" },
    ["Viscidus"] = { "Viscidus" },
    ["Princess Huhuran"] = { "Princess Huhuran" },
    ["Ouro"] = { "Ouro" },
    ["C'Thun"] = { "C'Thun" },
    -- Add more creature names as needed
}

-- Table to track which bosses from multi-boss encounters have been killed
local bossesKilled = {}

local function OnEvent(self, event, ...)
    local _, subevent, _, _, _, _, destName, _ = ...

    -- Check if the event is UNIT_DIED
    if (subevent == "UNIT_DIED") then
        local found = false

        -- Check if the killed unit belongs to any multi-boss encounter
        for encounter, bosses in pairs(bossEncounters) do
            for i, bossName in ipairs(bosses) do
                if destName == bossName then
                    -- Mark the boss as killed
                    bossesKilled[encounter] = bossesKilled[encounter] or {}
                    bossesKilled[encounter][bossName] = true
                    found = true

                    -- Check if all bosses in the encounter are dead
                    local allDead = true
                    for _, boss in ipairs(bosses) do
                        if not bossesKilled[encounter][boss] then
                            allDead = false
                            break
                        end
                    end

                    -- Print appropriate message
                    if allDead then
                        print("Completed encounter: ["..encounter.."], all bosses killed.")
                    else
                        print("Killed: ["..destName.."], still more bosses in ["..encounter.."].")
                    end
                end
            end
        end

        -- If not part of a multi-boss encounter, check if it's a single boss
        if not found then
            for encounter, bosses in pairs(bossEncounters) do
                if #bosses == 1 and bosses[1] == destName then
                    print("Killed: ["..destName.."], a boss unit.")
                    found = true
                    break
                end
            end
        end

        -- If destName doesn't match any boss, print it was not a boss
        if not found then
            print("Killed: ["..destName.."], not on the boss list.")
        end
    end
end

-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", OnEvent)