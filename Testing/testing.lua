-- Declare tables for boss kills, encounters, and raid points
local bossesKilled = {}
local encounterActive = {}
local encounterCompleted = {}
local playerPoints = {}  -- Local table to temporarily hold player points

-- Function to initialize the playerPoints table from saved data
local function InitializePlayerPoints()
    -- If PlayerPointsDB doesn't exist, initialize it as an empty table
    if not PlayerPointsDB then
        PlayerPointsDB = {}
    end

    -- Map the local playerPoints table to the saved PlayerPointsDB
    playerPoints = PlayerPointsDB
end

-- Function to reset an encounter after completion
local function ResetEncounter(encounter)
    bossesKilled[encounter] = nil
    encounterActive[encounter] = nil
    encounterCompleted[encounter] = nil
    print("Resetting encounter: [" .. encounter .. "]")
end

-- Function to get the number of group members
local function GetGroupSize()
    if UnitInRaid("player") then
        return GetNumRaidMembers()  -- Correct function for raids in 3.3.5a
    elseif GetNumPartyMembers() > 0 then
        return GetNumPartyMembers() + 1  -- +1 includes the player
    else
        print("You are not in a raid or party.")
        return 1
    end
end

-- Function to get the name of a group member based on index
local function GetGroupMemberName(index)
    if UnitInRaid("player") then
        local name, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(index)
        return name
    elseif index == 1 then
        return UnitName("player")  -- For the player themselves
    else
        return UnitName("party" .. (index - 1))  -- For party members (party1, party2, etc.)
    end
end

-- Function to track and add points to raid/party members
local function AwardPointsToGroup()
    print("Awarding points to group...")  -- Debugging line

    local numGroupMembers = GetGroupSize()
    print("Number of group members: " .. numGroupMembers)  -- Debugging line

    for i = 1, numGroupMembers do
        local name = GetGroupMemberName(i)
        print("Processing group member: " .. (name or "nil"))  -- Debugging line

        if name and name ~= "" then
            if not playerPoints[name] then
                playerPoints[name] = 0
            end
            playerPoints[name] = playerPoints[name] + 1
            print("Awarded 1 point to: " .. name .. ". Total points: " .. playerPoints[name])
        else
            print("Error retrieving info for index " .. i)
        end
    end
end

-- Function to handle events
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Testing" then  -- Replace with the actual addon folder name (Case sensitive)
            InitializePlayerPoints()
            self:UnregisterEvent("ADDON_LOADED")
            print("Addon: [" .. addonName .. "] loaded.")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, _ = ...
        if (subevent == "UNIT_DIED") then
            local found = false
            for encounter, bosses in pairs(bossEncounters) do
                for i, bossName in ipairs(bosses) do
                    if destName == bossName then
                        print("Boss found: " .. bossName)  -- Debugging line
                        bossesKilled[encounter] = bossesKilled[encounter] or {}
                        bossesKilled[encounter][bossName] = true
                        found = true
                        encounterActive[encounter] = true
                        local allBossesDead = true
                        for _, boss in ipairs(bosses) do
                            if not bossesKilled[encounter][boss] then
                                allBossesDead = false
                                break
                            end
                        end
                        if allBossesDead and not encounterCompleted[encounter] then
                            print("Completed encounter: [" .. encounter .. "], all bosses killed.")
                            encounterCompleted[encounter] = true
                            AwardPointsToGroup()  -- Award points to all raid/party members
                            ResetEncounter(encounter)
                        elseif not allBossesDead then
                            print("Killed: [" .. destName .. "], still more bosses in [" .. encounter .. "].")
                        end
                    end
                end
            end
            if not found then
                for encounter, bosses in pairs(bossEncounters) do
                    if #bosses == 1 and bosses[1] == destName then
                        print("Killed: [" .. destName .. "], a boss unit.")
                        found = true
                        encounterActive[encounter] = true
                        AwardPointsToGroup()  -- Award points for single boss encounter
                        ResetEncounter(encounter)
                        break
                    end
                end
            end
            if not found then
                print("Killed: [" .. destName .. "], not on the boss list.")
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
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
                    print("Encounter failed: [" .. encounter .. "]. Resetting.")
                end
                ResetEncounter(encounter)
            end
        end
    end
end

-- Function to print the list of raid members and their points
local function PrintPoints()
    print("Raid Points Summary:")
    for name, points in pairs(playerPoints) do
        print(name .. ": " .. points .. " points")
    end
end

-- Function to set points for a specific player (used for testing/debugging)
local function SetPlayerPoints(name, points)
    if not name or name == "" then
        print("Invalid player name.")
        return
    end
    
    points = tonumber(points)
    if not points then
        print("Invalid points value. It must be a number.")
        return
    end
    
    if not playerPoints[name] then
        playerPoints[name] = 0
    end
    
    playerPoints[name] = points
    print("Set " .. name .. "'s points to: " .. points)
end

-- Slash command handler for /goalset
SLASH_GOALSET1 = '/goalset'
SlashCmdList["GOALSET"] = function(msg)
    local name, points = strsplit(" ", msg, 2)
    SetPlayerPoints(name, points)
end

-- Command to display player points
SLASH_SHOWPOINTS1 = '/showpoints'
SlashCmdList["SHOWPOINTS"] = PrintPoints

-- Add this at the beginning or after declaring variables in the original code
local function ToggleGoalsFrame()
    if not GoalsFrame then
        CreateGoalsFrame()  -- Call the frame creation function from FrameCode.lua
    end
    
    if GoalsFrame:IsShown() then
        GoalsFrame:Hide()
    else
        GoalsFrame:Show()
    end
end

-- Slash command to toggle GoalsFrame
SLASH_TOGGLEGOALS1 = '/togglegoals'
SlashCmdList["TOGGLEGOALS"] = ToggleGoalsFrame

-- Now you can toggle the GoalsFrame using the /togglegoals command in-game


-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ADDON_LOADED")

-- Use SetScript to directly bind OnEvent
f:SetScript("OnEvent", OnEvent)