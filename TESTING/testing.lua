local bossesKilled = {}
local playerPoints = {} -- Will hold the in-game session data for player points

-- Function to initialize or load the database
local function InitializeDatabase()
    -- Check if PlayerPointsDB exists, if not, initialize it
    if not PlayerPointsDB then
        PlayerPointsDB = {}
    end

    -- Copy the saved points into the local playerPoints table
    playerPoints = PlayerPointsDB
end

-- Function to save points to the SavedVariables
local function SavePointsToDatabase()
    -- Save the local playerPoints table to the SavedVariables
    PlayerPointsDB = playerPoints
end

-- Function to get the list of all players in the raid group
local function GetRaidMembers()
    local members = {}
    local numRaidMembers = GetNumGroupMembers()

    for i = 1, numRaidMembers do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(members, name)
        end
    end

    return members
end

-- Function to add points to players present in the raid
local function AwardPointsToRaid()
    local raidMembers = GetRaidMembers()

    for _, playerName in ipairs(raidMembers) do
        -- Initialize player points if not already done
        if not playerPoints[playerName] then
            playerPoints[playerName] = 0
        end

        -- Add a point to the player's total
        playerPoints[playerName] = playerPoints[playerName] + 1
    end

    -- Save updated points to the database
    SavePointsToDatabase()
end

-- Function to print players and their current points
local function PrintPlayerPoints()
    print("Raid members and their points:")

    for playerName, points in pairs(playerPoints) do
        print(playerName .. ": " .. points .. " points")
    end
end

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

                    -- If all bosses in the encounter are dead, award points
                    if allDead then
                        print("Completed encounter: ["..encounter.."], all bosses killed.")
                        AwardPointsToRaid() -- Award points to the raid group
                        PrintPlayerPoints() -- Print player points to the chat
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
                    AwardPointsToRaid() -- Award points to the raid group
                    PrintPlayerPoints() -- Print player points to the chat
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
f:RegisterEvent("ADDON_LOADED") -- Event for when the addon is loaded
f:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == "MyAddon" then
        InitializeDatabase() -- Load player points when addon is loaded
    else
        OnEvent(self, event, ...)
    end
end)
