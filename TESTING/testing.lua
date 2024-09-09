local bossEncounters = require("TESTING/bossEncounters")
-- Table to track which bosses from multi-boss encounters have been killed
local bossesKilled = {}

local function OnEvent(self, event, ...)
    local _, subevent, _, _, _, _, destName, _ = ...

    -- Debug print to check if bossEncounters is loaded
    if not bossEncounters then
        print("Error: bossEncounters table is nil")
        return
    end

    -- Check if the event is UNIT_DIED
    if (subevent == "UNIT_DIED") then
        local found = false

        -- Debug print to check the content of bossEncounters
        print("bossEncounters content:")
        for encounter, bosses in pairs(bossEncounters) do
            print("Encounter:", encounter)
            for i, bossName in ipairs(bosses) do
                print("  Boss:", bossName)
            end
        end

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
    end
end

-- Register the event
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", OnEvent)