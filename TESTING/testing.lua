-- Declare a table to track which bosses from multi-boss encounters have been killed
local bossesKilled = {}

-- Function to reset the encounter (clear all killed bosses for a given encounter)
local function ResetEncounter(encounterName)
    if bossesKilled[encounterName] then
        bossesKilled[encounterName] = nil
        print("Encounter reset: ["..encounterName.."]")
    end
end

-- Function to check if the entire raid or party has wiped
local function CheckForWipe()
    -- Check if all raid or party members are dead or ghost
    local isWiped = true
    for i = 1, GetNumGroupMembers() do
        local unit = "raid"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            isWiped = false -- If at least one member is alive, the wipe didn't happen
            break
        end
    end
    return isWiped
end

-- Main event handler function
local function OnEvent(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, _ = CombatLogGetCurrentEventInfo()

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

                        -- Print appropriate message and reset encounter if all bosses are dead
                        if allDead then
                            print("Completed encounter: ["..encounter.."], all bosses killed.")
                            ResetEncounter(encounter)
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

    elseif event == "ENCOUNTER_END" then
        -- ENCOUNTER_END event gives us encounterID, encounterName, difficultyID, groupSize, and success (true or false)
        local encounterID, encounterName, difficultyID, groupSize, success = ...

        if success then
            -- If the encounter was successfully completed (bosses defeated), reset it
            print("Encounter successfully completed: ["..encounterName.."].")
        else
            -- If the encounter was unsuccessful (e.g., a wipe), reset the encounter
            print("Encounter failed: ["..encounterName.."], resetting.")
        end

        ResetEncounter(encounterName)

    elseif event == "PLAYER_DEAD" or event == "UNIT_HEALTH" then
        -- Check for a wipe if a player dies or their health changes
        if CheckForWipe() then
            print("Party wiped! Resetting all active encounters.")
            for encounter in pairs(bossEncounters) do
                ResetEncounter(encounter)
            end
        end
    end
end

-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") -- Detect boss deaths
f:RegisterEvent("ENCOUNTER_END") -- Detect encounter end (for resets)
f:RegisterEvent("PLAYER_DEAD") -- Detect player death to check for wipes
f:RegisterEvent("UNIT_HEALTH") -- Monitor health to detect a wipe
f:SetScript("OnEvent", OnEvent)
