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

-- Define PrintPointsSummary at the top of the file before it's used elsewhere
local function PrintPointsSummary()
    if not GoalsFrame then
        print("Error: GoalsFrame does not exist. Creating it now.")
        GoalsFrame = 
    print("Debug: CreateGoalsFrame function called")
    CreateGoalsFrame()
    
    end

    -- Access the text objects directly from the frame object
    --local playerText = GoalsFrame.playerText
    --local pointsText = GoalsFrame.pointsText

    --if not playerText or not pointsText then
        --print("Error: FontStrings [playerText/pointsText] are not available in GoalsFrame. Cannot update text.")
        --return
    --end

    -- Clear previous text
    --playerText:SetText("")
    --pointsText:SetText("")

    -- Sort the players by points
    local sortedPlayers = {}
    for name, points in pairs(playerPoints) do
        table.insert(sortedPlayers, { name = name, points = points })
    end
    table.sort(sortedPlayers, function(a, b)
        if a.points == b.points then
            return a.name < b.name  -- Alphabetical if points are equal
        else
            return a.points > b.points  -- Higher points first
        end
    end)

    -- Initialize empty strings for playerText and pointsText
    local playersTextValue = ""
    local pointsTextValue = ""

    -- Update the sorted list of players and points
    for _, entry in ipairs(sortedPlayers) do
        local playerName = entry.name or "Unknown"
        local playerPointsValue = entry.points or 0

        -- Append to playerText and pointsText strings
        playersTextValue = playersTextValue .. playerName .. "\n"
        pointsTextValue = pointsTextValue .. tostring(playerPointsValue) .. "\n"
    end

    -- Update the frame text with the concatenated strings
    --playerText:SetText(playersTextValue)
    --pointsText:SetText(pointsTextValue)
    --addRow("ManualAdd", "3", "priest")


end

-- Updated AwardPointsToGroup() function
    local function AwardPointsToGroup()
        print("Awarding points to group...")
    
        local numGroupMembers = GetGroupSize()
        for i = 1, numGroupMembers do
            local name = GetGroupMemberName(i)
            
            if name and name ~= "" then
                if not playerPoints[name] then
                    playerPoints[name] = 0
                end
                playerPoints[name] = playerPoints[name] + 1
                print("Awarded 1 point to: " .. name .. ". Total points: " .. playerPoints[name])
            end
        end
    
        -- Always update the frame, regardless of its visibility
        PrintPointsSummary()
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
                            PrintPointsSummary()  -- Update the frame with the new points
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
                        PrintPointsSummary()  -- Update the frame with the new points
                        ResetEncounter(encounter)
                        break
                    end
                end
            end
            if not found then
                print("Killed: [" .. destName .. "], not on the boss list.")
            end
            PrintPointsSummary()  -- Award points to all raid/party members
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
    PrintPointsSummary()  -- Update the frame with the new points
end

-- Command to display player points
SLASH_SHOWPOINTS1 = '/showpoints'
SlashCmdList["SHOWPOINTS"] = PrintPoints

-- Updated ToggleGoalsFrame() function
    local function ToggleGoalsFrame()
        print("ToggleGoalsFrame called")
    
        if not GoalsFrame then
            print("Debug: CreateGoalsFrame function called")
            CreateGoalsFrame()
        end
    
        if GoalsFrame:IsShown() then
            print("Debug: GoalsFrame is being hidden")
            GoalsFrame:Hide()
        else
            print("Debug: GoalsFrame is being shown")
            GoalsFrame:Show()
            
            -- Call PrintPointsSummary() to update the frame data
            PrintPointsSummary()
        end
    end    
    
    -- Create the GoalsFrame if it doesn't exist
    if not GoalsFrame then
        print("Error 007: GoalsFrame does not exist, creating now.")
        
    print("Debug: CreateGoalsFrame function called")
    CreateGoalsFrame()
      -- Assuming CreateGoalsFrame is the function that initializes the frame.
    end

    if GoalsFrame:IsShown() then
    
        
    print("Debug: GoalsFrame is being hidden")
    GoalsFrame:Hide()
    
    else
        
    print("Debug: GoalsFrame is being shown")
    
    GoalsFrame:Show()
    print("Debug: Triggering data update")
    -- Fetch and populate data dynamically when frame is shown
    local numGroupMembers = UnitInRaid("player") and GetNumRaidMembers() or GetNumPartyMembers()
    print("Debug: Number of group members:", numGroupMembers)

    for i = 1, numGroupMembers do
        local name, class
        if UnitInRaid("player") then
            name, _, _, _, class, _, _, _ = GetRaidRosterInfo(i)
        else
            name = UnitName("party" .. i)
            class = UnitClass("party" .. i)
        end

        if name and name ~= "" then
            local playerPointsValue = playerPoints[name] or 0
            print("Debug: Adding row for", name, "with points", playerPointsValue, "and class", class)
            addRow(name, tostring(playerPointsValue), class)
        end
    end

    -- Handle the solo case (if the player is not in a party/raid)
    if numGroupMembers == 0 then
        local playerName = UnitName("player")
        local playerClass = UnitClass("player")
        local playerPointsValue = playerPoints[playerName] or 0
        print("Debug: Adding row for solo player", playerName, "with points", playerPointsValue, "and class", playerClass)
        addRow(playerName, tostring(playerPointsValue), playerClass)
    end
    
    
        PrintPointsSummary()  -- Update points when showing the frame
    end


SLASH_TOGGLEGOALS1 = '/togglegoals'
SlashCmdList["TOGGLEGOALS"] = ToggleGoalsFrame



-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ADDON_LOADED")

-- Use SetScript to directly bind OnEvent
f:SetScript("OnEvent", OnEvent)

-- Updated /togglegoals command with debug statements
