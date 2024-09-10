-- Table to keep track of bosses killed in multi-boss encounters
local bossesKilled = {}

-- Table to store player data with their points
local playerData = {}

-- Function to save player data to a file
local function SavePlayerData()
    local file = io.open("player_data.txt", "w")  -- Open a file in write mode
    for playerName, points in pairs(playerData) do  -- Iterate through player data
        file:write(playerName .. ":" .. points .. "\n")  -- Write player name and points to the file
    end
    file:close()  -- Close the file
end

-- Function to edit player data by adding points
local function EditPlayerData(playerName, points)
    playerData[playerName] = (playerData[playerName] or 0) + points  -- Add points to the player's current points
    SavePlayerData()  -- Save the updated player data
end

-- Function to get the list of raid members
local function GetRaidMembers()
    local raidMembers = {}  -- Table to store raid members
    for i = 1, GetNumRaidMembers() do  -- Loop through all raid members
        local name = GetRaidRosterInfo(i)  -- Get the name of the raid member
        if name then
            table.insert(raidMembers, name)  -- Add the name to the raid members table
        end
    end
    return raidMembers  -- Return the list of raid members
end

-- Function to handle events
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

                    -- If all bosses are dead, print a message and save player data
                    if allDead then
                        print("Completed encounter: ["..encounter.."], all bosses killed.")
                        local raidMembers = GetRaidMembers()  -- Get the list of raid members
                        for _, playerName in ipairs(raidMembers) do
                            EditPlayerData(playerName, 1)  -- Add 1 point to each player's data
                        end
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
