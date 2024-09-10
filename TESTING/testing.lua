-- Desc: Testing AddOn for multi-boss encounter tracking.
-- This AddOn is intended to be used for testing purposes only.
local bossesKilled = {}
local encounterActive = {}
local encounterCompleted = {}

local function ResetEncounter(encounter)
    bossesKilled[encounter] = nil
    encounterActive[encounter] = nil
    encounterCompleted[encounter] = nil
    print("Resetting encounter: ["..encounter.."]")
end

local function OnEvent(self, event, ...)
    local _, subevent, _, _, _, _, destName, _ = ...

    -- Debugging output for specific cases
    if subevent == "UNIT_DIED" then
        print("UNIT_DIED Event:", destName)
    elseif event == "PLAYER_REGEN_ENABLED" then
        print("PLAYER_REGEN_ENABLED Event")
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Check if the subevent is UNIT_DIED
        if (subevent == "UNIT_DIED") then
            local found = false

            -- Check if the killed unit belongs to any multi-boss encounter
            for encounter, bosses in pairs(bossEncounters) do
                if not bosses then
                    print("Warning: No bosses defined for encounter ["..encounter.."]")
                    break
                end

                for i, bossName in ipairs(bosses) do
                    if destName == bossName then
                        -- Mark the boss as killed
                        bossesKilled[encounter] = bossesKilled[encounter] or {}
                        bossesKilled[encounter][bossName] = true
                        found = true
                        encounterActive[encounter] = true  -- Mark encounter as active

                        -- Check if all bosses in the encounter are dead
                        local allBossesDead = true
                        for _, boss in ipairs(bosses) do
                            if not bossesKilled[encounter][boss] then
                                allBossesDead = false
                                break
                            end
                        end

                        -- Print appropriate message and reset encounter if completed
                        if allBossesDead and not encounterCompleted[encounter] then
                            print("Completed encounter: ["..encounter.."], all bosses killed.")
                            encounterCompleted[encounter] = true  -- Mark encounter as completed
                            ResetEncounter(encounter)  -- Reset after completion
                        elseif not allBossesDead then
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
                        encounterActive[encounter] = true
                        ResetEncounter(encounter)  -- Reset after single boss kill
                        break
                    end
                end
            end

            -- If destName doesn't match any boss, print it was not a boss
            if not found then
                print("Killed: ["..destName.."], not on the boss list.")
            end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat has ended, check if the encounter was a success or failure and reset
        for encounter, bosses in pairs(bossEncounters) do
            if encounterActive[encounter] and not encounterCompleted[encounter] then
                local allBossesDead = true
                for _, bossName in ipairs(bosses) do
                    if not bossesKilled[encounter] or not bossesKilled[encounter][bossName] then
                        allBossesDead = false
                        break
                    end
                end

                if not allBossesDead then
                    print("Encounter failed: ["..encounter.."]. Resetting.")
                end
                ResetEncounter(encounter)
            end
        end
    end
end

-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Fires when combat ends
f:SetScript("OnEvent", OnEvent)
