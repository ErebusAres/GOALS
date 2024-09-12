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
    print("Resetting encounter: ["..encounter.."]")
end

-- Function to get the number of group members, with a debug message for when not in a raid or party
local function GetGroupSize()
    local inInstance, instanceType = IsInInstance()
    if instanceType == "raid" then
        if GetNumGroupMembers then
            return GetNumGroupMembers()
        else
            print("Error: GetNumGroupMembers is not available.")
            return 0
        end
    elseif instanceType == "party" then
        if GetNumPartyMembers then
            return GetNumPartyMembers() + 1
        else
            print("Error: GetNumPartyMembers is not available.")
            return 0
        end
    else
        print("You are not in a raid or party.")
        return 1
    end
end

-- Function to track and add points to raid members
local function AwardPointsToRaid()
    local numGroupMembers = GetGroupSize()

    for i = 1, numGroupMembers do
        local name = GetRaidRosterInfo(i)
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
    local _, subevent, _, _, _, _, destName, _ = ... -- Extract event arguments for WoW 3.3.5a

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if subevent == "UNIT_DIED" then
            local found = false

            for encounter, bosses in pairs(bossEncounters) do
                for i, bossName in ipairs(bosses) do
                    if destName == bossName then
                        bossesKilled[encounter] = bossesKilled[encounter] or {}
                        bossesKilled[encounter][bossName] = true
                        found = true
                        encounterActive[encounter] = true

                        -- Check if all bosses in the encounter are dead
                        local allBossesDead = true
                        for _, boss in ipairs(bosses) do
                            if not bossesKilled[encounter][boss] then
                                allBossesDead = false
                                break
                            end
                        end

                        -- If all bosses are dead, mark the encounter as completed
                        if allBossesDead and not encounterCompleted[encounter] then
                            print("Completed encounter: [" .. encounter .. "], all bosses killed.")
                            encounterCompleted[encounter] = true
                            AwardPointsToRaid()  -- Award points for a successful encounter
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
                        print ("Killed: [".. destName .."], a boss unit.")
                        found = true
                        encounterActive[encounter] = true
                        AwardPointsToRaid() -- Award points for a single boss kill
                        ResetEncounter(encounter)
                        break
                   end 
                end
            end
            -- If the boss was not found in the main list, print a debug message
            if not found then
                print("Killed: [" .. destName .. "], not on the boss list.")
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Handle the case when combat ends, reset encounters if needed
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

-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ADDON_LOADED")

-- Event handler function
f:SetScript("OnEvent", function(self, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName == "Testing" then  -- Replace with the actual addon folder name (Case sensitive)
        InitializePlayerPoints()
        self:UnregisterEvent("ADDON_LOADED")
        print("Addon: ["..addonName.."] loaded.")
    else
        OnEvent(self, event, ...)  -- Pass the vararg '...' only if it's a different event
    end
end)

