-- Utility function to capitalize the first character of a name
local function CapitalizeFirstLetter(str)
    return str:gsub("^%l", string.upper)
end


-- Class colors configuration
local classColors = { 
    deathknight = {r = 0.77, g = 0.12, b = 0.23},
    druid       = {r = 1.0, g = 0.49, b = 0.04},
    hunter      = {r = 0.67, g = 0.83, b = 0.45},
    mage        = {r = 0.25, g = 0.78, b = 0.92},
    paladin     = {r = 0.96, g = 0.55, b = 0.73},
    priest      = {r = 1.0, g = 1.0, b = 1.0},
    rogue       = {r = 1.0, g = 0.96, b = 0.41},
    shaman      = {r = 0.0, g = 0.44, b = 0.87},
    warlock     = {r = 0.53, g = 0.53, b = 0.93},
    warrior     = {r = 0.78, g = 0.63, b = 0.43},
    unknown     = {r = 0.5, g = 0.5, b = 0.5}  -- Default class color for unknown
}

local playerPoints = {}  -- Table to store player points and class information
local bossEncounters = {}  -- Table to store boss encounter information
local encounterActive = {}
local bossesKilled = {}  -- Track killed bosses in an encounter
local encounterCompleted = {}  -- Track completed encounters
local recentlyAwarded = {}
local disenchanters = {}  -- Table to store disenchanter status for players

-- Custom delay function to avoid C_Timer issues
local function Delay(seconds, func)
    local delayFrame = CreateFrame("Frame")
    local elapsed = 0
    delayFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= seconds then
            self:SetScript("OnUpdate", nil)
            func()
            delayFrame = nil
        end
    end)
end

-- Function to ensure playerPoints entry is always properly initialized
local function EnsurePlayerPointsEntry(playerName, playerClass)
    if type(playerPoints[playerName]) ~= "table" then
        playerPoints[playerName] = {points = 0, class = playerClass or "unknown"}
    else
        -- Ensure class and points are always set to avoid invalid formats
        playerPoints[playerName].class = playerPoints[playerName].class or "unknown"
        playerPoints[playerName].points = playerPoints[playerName].points or 0
    end
end

local function SetDisenchanter(playerName, isDisenchanter)
    local properCasedName = CapitalizeFirstLetter(playerName)

    -- Ensure player points entry is initialized before setting disenchanter status
    EnsurePlayerPointsEntry(properCasedName)

    if isDisenchanter then
        disenchanters[properCasedName] = true
        SendToGoalsChat(properCasedName .. " is now marked as a disenchanter.")
    else
        disenchanters[properCasedName] = nil
        SendToGoalsChat(properCasedName .. " is no longer marked as a disenchanter.")
    end
end


-- Function to get all group members, whether raid or party
local function GetAllGroupMembers()
    local members = {}

    -- Add player themselves
    local playerName, playerClass = UnitName("player"), UnitClass("player")
    if playerName and playerClass then
        table.insert(members, {name = playerName, class = playerClass})
    end

    -- Add raid members if in a raid
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name, _, _, _, class = GetRaidRosterInfo(i)
            if name and class then
                table.insert(members, {name = name, class = class})
            end
        end
    -- Add party members if not in a raid but in a party
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local name, class = UnitName("party" .. i), UnitClass("party" .. i)
            if name and class then
                table.insert(members, {name = name, class = class})
            end
        end
    end

    return members
end

local function SendToGoalsChat(msg)
    if msg then
        local chatTabIndex = nil

        -- Find existing "GOALS" tab
        for i = 1, NUM_CHAT_WINDOWS do
            local name = GetChatWindowInfo(i)
            if name == "GOALS" then
                chatTabIndex = i
                break
            end
        end

        -- Create "GOALS" tab if it does not exist
        if not chatTabIndex then
            local chatFrame = FCF_OpenNewWindow("GOALS")
            chatTabIndex = chatFrame:GetID()

            -- Assign default settings to avoid errors
            FCF_SetWindowColor(chatFrame, 0, 0, 0)  -- Black background color
            FCF_SetWindowAlpha(chatFrame, 0.5)      -- 50% transparency
            FCF_DockFrame(chatFrame)                -- Dock the frame to the chat
            FCF_SetLocked(chatFrame, true)          -- Lock the frame

            -- Send confirmation message
            chatFrame:AddMessage("|cffFFD700[GOALS]:|r GOALS tab created.")
        end

        -- Send the message to the "GOALS" chat tab if it exists
        if chatTabIndex and _G["ChatFrame" .. chatTabIndex] then
            local color = "|cffFFD700"  -- Gold color code for the prefix
            _G["ChatFrame" .. chatTabIndex]:AddMessage(color .. "[GOALS]:|r " .. msg)
        else
            print("[ERROR]: Unable to send message to 'GOALS' chat tab.")
        end
    end
end

-- Function to restore or create the "GOALS" chat tab
local function RestoreGoalsChatTab(shouldFocus)
    local chatTabIndex = nil

    -- Check if "GOALS" chat tab already exists
    for i = 1, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        if name == "GOALS" then
            chatTabIndex = i
            break
        end
    end

    -- If "GOALS" tab does not exist, create it
    if not chatTabIndex then
        local success, err = pcall(function()
            FCF_OpenNewWindow("GOALS")
        end)

        -- Handle error if the creation fails
        if not success then
            print("Error creating GOALS tab: " .. tostring(err))
            return
        end

        -- Update chatTabIndex to the new window
        chatTabIndex = NUM_CHAT_WINDOWS
        FCF_SetWindowName(_G["ChatFrame" .. chatTabIndex], "GOALS")
        SendToGoalsChat("GOALS tab created.")
    end

    -- Ensure the tab is docked properly
    local chatFrame = _G["ChatFrame" .. chatTabIndex]
    if chatFrame then
        FCF_DockFrame(chatFrame)
        if not chatFrame:IsVisible() then
            chatFrame:Show()
        end
        if shouldFocus then
            FCF_SelectDockFrame(chatFrame)  -- Focus on the tab only if specified
        end
    else
        print("Error: GOALS chat frame not found.")
    end
end

-- Load the bossEncounters list from the bossEncounters.lua file
local function LoadBossEncounters()
    if type(_G.bossEncounters) == "table" then
        bossEncounters = _G.bossEncounters
        SendToGoalsChat("Boss encounter data loaded successfully.")
    else
        SendToGoalsChat("Error: Failed to load boss encounter data.")
    end
end

local function LoadPlayerPoints()
    if PlayerPointsDB then
        playerPoints = PlayerPointsDB
        SendToGoalsChat("Player points loaded from saved data.")
    else
        SendToGoalsChat("No saved data found, starting fresh.")
    end
end

local function SavePlayerPoints()
    PlayerPointsDB = playerPoints
end

-- Function to handle loot messages
local function HandleLoot(msg)
    local player, itemLink = msg:match("^(%S+) receives (.+)%.$")
    if player and itemLink then
        local itemName, _, itemRarity = GetItemInfo(itemLink)

        -- Ignore Badge of Justice and Void Crystal
        if itemName == "Badge of Justice" or itemName == "Void Crystal" then
            return
        end

        -- Check for Epic or higher quality (4 is Epic)
        if itemRarity and itemRarity >= 4 then
            player = CapitalizeFirstLetter(player)
            EnsurePlayerPointsEntry(player)
            playerPoints[player].points = 0
            SendToGoalsChat(player .. " received " .. itemLink .. " and has reset to 0 points.")

            -- Check if the player is a disenchanter and notify
            if disenchanters[player] then
                SendToGoalsChat(player .. " (Disenchanter) received " .. itemLink .. ".")
            end
        end
    end
end

-- Function to list current raid or party members along with their points (sorted by points, then alphabetically)
local function ListPartyOrRaidMembersSorted()
    local players = {}

    -- If in a raid, get raid members
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(players, {name = name, points = playerPoints[name] and playerPoints[name].points or 0, class = playerPoints[name] and playerPoints[name].class or "unknown"})
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        -- If in a party but not a raid, get party members
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                table.insert(players, {name = name, points = playerPoints[name] and playerPoints[name].points or 0, class = playerPoints[name] and playerPoints[name].class or "unknown"})
            end
        end
        -- Include the player themselves
        local playerName = UnitName("player")
        if playerName then
            table.insert(players, {name = playerName, points = playerPoints[playerName] and playerPoints[playerName].points or 0, class = playerPoints[playerName] and playerPoints[playerName].class or "unknown"})
        end
    else
        -- If not in a group, only include the player themselves
        local playerName = UnitName("player")
        if playerName then
            table.insert(players, {name = playerName, points = playerPoints[playerName] and playerPoints[playerName].points or 0, class = playerPoints[playerName] and playerPoints[playerName].class or "unknown"})
        end
    end

    -- Sort the player list by points (descending) and name (ascending)
    table.sort(players, function(a, b)
        if a.points == b.points then
            return a.name < b.name
        end
        return a.points > b.points
    end)

    -- Display the sorted list with colors and numbering
    SendToGoalsChat("Current Raid/Party Members:")
    for index, player in ipairs(players) do
        local classColor = classColors[strlower(player.class or "unknown")] or {r = 1, g = 1, b = 1}
        local output = string.format("|cff%02x%02x%02x%d. %s: %d|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, index, player.name, player.points)
        SendToGoalsChat(output)
    end
end

-- Award points to group members for boss kills
local function AwardPointsToGroup(encounterName)
    SendToGoalsChat("Awarding points to group for completing encounter: " .. encounterName)

    local members = GetAllGroupMembers()
    for _, member in ipairs(members) do
        -- Prevent duplicate awarding within the same encounter
        if not recentlyAwarded[member.name] then
            recentlyAwarded[member.name] = true
            EnsurePlayerPointsEntry(member.name, member.class)
            playerPoints[member.name].points = playerPoints[member.name].points + 1
            SendToGoalsChat("Awarded 1 point to: " .. member.name .. ". Total points: " .. playerPoints[member.name].points)
        end
    end

    -- Reset encounter status to allow repeating the encounter
    bossesKilled[encounterName] = nil
    encounterCompleted[encounterName] = nil

    -- Update and display points for all members in the group
    ListPartyOrRaidMembersSorted()  -- Automatically list the players in the party/raid after awarding points
end

-- Clear `recentlyAwarded` table after some time (e.g., 5 minutes) to prevent lingering data
local function ClearRecentlyAwarded()
    recentlyAwarded = {}
end

-- Clear `recentlyAwarded` table after some time (e.g., 5 minutes) to prevent lingering data
Delay(300, ClearRecentlyAwarded)

-- Toggle logic for showing points in the "GOALS" chat
SLASH_GOALS_SHOW1 = "/goshow"
SlashCmdList["GOALS_SHOW"] = function()
    RestoreGoalsChatTab(true)
    ListPartyOrRaidMembersSorted()
end

-- Slash command to manually set points for a player
function SetPlayerPoints(player, points)
    -- Convert player name to lowercase for case-insensitive search
    local lowerPlayer = strlower(player)
    local playerFound = false
    local properCasedName = CapitalizeFirstLetter(player)

    for storedPlayer, info in pairs(playerPoints) do
        if strlower(storedPlayer) == lowerPlayer then
            EnsurePlayerPointsEntry(storedPlayer, info.class)
            playerPoints[storedPlayer].points = points
            SendToGoalsChat("Set points for " .. storedPlayer .. ": " .. points)
            playerFound = true
            ListPartyOrRaidMembersSorted()
            break
        end
    end

    if not playerFound then
        playerPoints[properCasedName] = {points = points, class = "unknown"}
        SendToGoalsChat("Added new player: " .. properCasedName .. " with " .. points .. " points")
        ListPartyOrRaidMembersSorted()
    end
end

SLASH_GOSETPOINTS1 = '/gosetpoints'
SlashCmdList["GOSETPOINTS"] = function(msg)
    local player, points = strsplit(" ", msg, 2)
    points = tonumber(points)
    if player and points then
        SetPlayerPoints(player, points)
    else
        SendToGoalsChat("Usage: /gosetpoints [player] [points]")
    end
end

-- Helper function to convert RGB to hexadecimal color code
local function RGBToHex(color)
    return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- Slash command to manually set class for a player
function SetPlayerClass(player, class)
    local lowerPlayer = strlower(player)
    local lowerClass = strlower(class)

    -- Check if the provided class is valid
    if not classColors[lowerClass] then
        local validClassList = ""
        for className, color in pairs(classColors) do
            local hexColor = RGBToHex(color)
            validClassList = validClassList .. hexColor .. className .. "|r, "
        end
        validClassList = validClassList:sub(1, -3)  -- Remove the trailing comma and space
        SendToGoalsChat("Invalid class specified. Valid classes: " .. validClassList .. ".")
        return
    end

    -- Set the class for the player in the database
    local playerFound = false
    for storedPlayer, info in pairs(playerPoints) do
        if strlower(storedPlayer) == lowerPlayer then
            playerPoints[storedPlayer].class = lowerClass
            local hexColor = RGBToHex(classColors[lowerClass])
            SendToGoalsChat("Set class for " .. storedPlayer .. ": " .. hexColor .. lowerClass .. "|r")
            playerFound = true
            break
        end
    end

    -- If player is not found in the database
    if not playerFound then
        SendToGoalsChat("Player not found in the database: " .. player)
    end
end

-- Registering the slash command to set player class
SLASH_GOSETCLASS1 = '/gosetclass'
SlashCmdList["GOSETCLASS"] = function(msg)
    local player, class = strsplit(" ", msg, 2)
    if player and class then
        SetPlayerClass(player, class)
    else
        SendToGoalsChat("Usage: /gosetclass [player] [class]")
    end
end

SLASH_GODISENCHANTER1 = '/gode'
SlashCmdList["GODISENCHANTER"] = function(msg)
    local player, value = strsplit(" ", msg, 2)
    if player and (value == "true" or value == "false") then
        SetDisenchanter(player, value == "true")
    else
        SendToGoalsChat("Usage: /gode [player] [true/false]")
    end
end

-- Slash command to list all players in the database
SLASH_GOLIST1 = '/golist'
SlashCmdList["GOLIST"] = function()
    if next(playerPoints) == nil then
        SendToGoalsChat("No players in the database.")
    else
        SendToGoalsChat("Listing all players:")
        local sortedPlayers = {}
        for player, info in pairs(playerPoints) do
            if type(info) == "table" then
                EnsurePlayerPointsEntry(player, info.class)
                table.insert(sortedPlayers, {name = player, points = info.points, class = info.class})
            else
                SendToGoalsChat(player .. ": 0 points (invalid data format)")
            end
        end

        table.sort(sortedPlayers, function(a, b)
            if a.points == b.points then
                return a.name < b.name
            else
                return a.points > b.points
            end
        end)

        for _, playerData in ipairs(sortedPlayers) do
            local classColor = classColors[strlower(playerData.class)] or classColors["unknown"]
            local colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
            SendToGoalsChat(colorCode .. playerData.name .. "|r: " .. tostring(playerData.points) .. " points")
        end
    end
end


-- Slash command to remove a player from the database
SLASH_GOREMOVE1 = '/goremove'
SlashCmdList["GOREMOVE"] = function(msg)
    local player = strtrim(msg)
    if player then
        local lowerPlayer = strlower(player)
        local removedCount = 0

        for storedPlayer, info in pairs(playerPoints) do
            if strlower(storedPlayer) == lowerPlayer then
                playerPoints[storedPlayer] = nil
                removedCount = removedCount + 1
            end
        end

        if removedCount > 0 then
            SendToGoalsChat("Removed " .. removedCount .. " instance(s) of player: " .. player)
            ListPartyOrRaidMembersSorted()
        else
            SendToGoalsChat("Player not found: " .. player)
        end
    else
        SendToGoalsChat("Usage: /goremove [player]")
    end
end


-- Function to send the current raid/party members' points to raid or party chat
SLASH_GOSEND1 = '/gosend'
SlashCmdList["GOSEND"] = function()
    local playerList = {}

    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name and playerPoints[name] then
                table.insert(playerList, {name = name, points = playerPoints[name].points or 0})
            end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name and playerPoints[name] then
                table.insert(playerList, {name = name, points = playerPoints[name].points or 0})
            end
        end
        local playerName = UnitName("player")
        if playerPoints[playerName] then
            table.insert(playerList, {name = playerName, points = playerPoints[playerName].points or 0})
        end
    else
        local playerName = UnitName("player")
        if playerPoints[playerName] then
            table.insert(playerList, {name = playerName, points = playerPoints[playerName].points or 0})
        end
    end

    table.sort(playerList, function(a, b)
        if a.points == b.points then
            return a.name < b.name
        end
        return a.points > b.points
    end)

    for _, player in ipairs(playerList) do
        local output = player.name .. ": " .. player.points
        SendChatMessage(output, GetNumRaidMembers() > 0 and "RAID" or GetNumPartyMembers() > 0 and "PARTY" or "SAY")
    end
end

-- Function to update player names in the database with correct casing and class from the game
local function UpdatePlayerNamesWithProperCasing()
    local members = GetAllGroupMembers()

    for _, member in ipairs(members) do
        local lowerMemberName = strlower(member.name)

        -- Check if a player with the same name (ignoring case) exists in the database
        for storedPlayer, info in pairs(playerPoints) do
            if strlower(storedPlayer) == lowerMemberName then
                EnsurePlayerPointsEntry(storedPlayer, info.class)
                playerPoints[storedPlayer] = nil  -- Remove old entry
                playerPoints[member.name] = {points = info.points, class = member.class or "unknown"}  -- Add new entry with proper casing and class
                break
            end
        end
    end
end

-- Slash command to provide help about all commands
SLASH_GHELP1 = '/gohelp'
SlashCmdList["GHELP"] = function()
    SendToGoalsChat("|cffFFD700GOALS Help|r:")
    SendToGoalsChat("|cffFFD700/goshow|r - Show raid/party members with their points (sorted by points).")
    SendToGoalsChat("|cffFFD700/golist|r - List all players in the database with their points.")
    SendToGoalsChat("|cffFFD700/gosetpoints [player] [points]|r - Manually set points for a player.")
    SendToGoalsChat("|cffFFD700/gosetclass [player] [class]|r - Manually set the class for a player (valid classes: " ..
        "|cffc41e3a deathknight|r, " ..
        "|cffff7d0a druid|r, " ..
        "|cffabd473 hunter|r, " ..
        "|cff69ccf0 mage|r, " ..
        "|cfff58cba paladin|r, " ..
        "|cffffffff priest|r, " ..
        "|cfffff569 rogue|r, " ..
        "|cff0070de shaman|r, " ..
        "|cff9482c9 warlock|r, " ..
        "|cffc79c6e warrior|r, " ..
        "|cff808080 unknown|r).")
    SendToGoalsChat("|cffFFD700/goremove [player]|r - Remove a player from the database.")
    SendToGoalsChat("|cffFFD700/gosend|r - Send the current raid/party members' points to raid or party chat.")
    SendToGoalsChat("|cffFFD700/gode [player] [true/false]|r - Set or unset a player as a disenchanter.")
end

-- Function to reset encounter data and ensure points reset properly
local function ResetEncounter(encounter)
    if encounter then
        bossesKilled[encounter] = {}
        encounterActive[encounter] = false
        encounterCompleted[encounter] = false
        recentlyAwarded = {}  -- Reset recently awarded points
        SendToGoalsChat("Encounter: [" .. encounter .. "] has been reset.")
    end
end

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Goals" then
            LoadBossEncounters()
            if PlayerPointsDB then
                playerPoints = PlayerPointsDB
            end
            InitializePlayerPoints()
            RestoreGoalsChatTab()  -- Restore or create the "GOALS" chat tab
            self:UnregisterEvent("ADDON_LOADED")
            SendToGoalsChat("Addon: [" .. addonName .. "] loaded.")
            SendToGoalsChat("/gohelp - list GOALS commands.")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Ensure player points are loaded when re-entering the world
        if not playerPoints or next(playerPoints) == nil then
            if PlayerPointsDB then
                playerPoints = PlayerPointsDB
                SendToGoalsChat("Player points loaded from saved data.")
            else
                SendToGoalsChat("No saved data found. Starting fresh.")
            end
        end
        InitializePlayerPoints()

        -- Register the combat log event only after entering the world
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    elseif event == "PLAYER_LOGOUT" then
        -- Save player points when logging out
        PlayerPointsDB = playerPoints

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, _ = ...

        if subevent == "UNIT_DIED" then
            local found = false
            for encounter, bosses in pairs(bossEncounters) do
                for _, bossName in ipairs(bosses) do
                    if destName == bossName then
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
                            SendToGoalsChat("Completed encounter: [" .. encounter .. "], all bosses killed.")
                            encounterCompleted[encounter] = true
                            AwardPointsToGroup(encounter)
                            UpdatePlayerNamesWithProperCasing()
                            ResetEncounter(encounter)
                        elseif not allBossesDead then
                            SendToGoalsChat("Killed: [" .. destName .. "], still more bosses in [" .. encounter .. "].")
                        end
                    end
                end
            end

            -- Handle single boss encounters (only one boss in the encounter)
            if not found then
                for encounter, bosses in pairs(bossEncounters) do
                    if #bosses == 1 and bosses[1] == destName then
                        found = true
                        encounterActive[encounter] = true

                        -- Prevent awarding multiple points for the same kill
                        if not recentlyAwarded[destName] then
                            recentlyAwarded[destName] = true
                            AwardPointsToGroup(encounter)
                            UpdatePlayerNamesWithProperCasing()
                            ResetEncounter(encounter)
                        end
                        break
                    end
                end
            end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Handle encounter failure if the player leaves combat without completing an encounter
        for encounter, bosses in pairs(bossEncounters) do
            if encounterActive[encounter] and not encounterCompleted[encounter] then
                SendToGoalsChat("Checking encounter failure for: [" .. encounter .. "].")
                
                local allBossesDead = true
                for _, bossName in ipairs(bosses) do
                    if not bossesKilled[encounter] or not bossesKilled[encounter][bossName] then
                        allBossesDead = false
                        break
                    end
                end
    
                if allBossesDead then
                    -- If all bosses are dead but the encounter hasn't been marked complete, mark it as completed
                    SendToGoalsChat("All bosses already dead in encounter: [" .. encounter .. "], skipping reset.")
                    encounterCompleted[encounter] = true
                else
                    -- If not all bosses are dead, treat it as a failure and reset the encounter
                    SendToGoalsChat("Encounter failed: [" .. encounter .. "]. Resetting.")
                    ResetEncounter(encounter)
                end
            end
        end
    end
    
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        HandleLoot(msg)
    end
end

-- Creating the frame for event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Register for encounter failure handling
eventFrame:SetScript("OnEvent", OnEvent)

-- Initialize player points on addon load
function InitializePlayerPoints()
    local members = GetAllGroupMembers()
    for _, member in ipairs(members) do
        EnsurePlayerPointsEntry(member.name, member.class)
    end
end
