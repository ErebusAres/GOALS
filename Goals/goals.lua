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

local function HandleLoot(msg)
    local player, itemLink = msg:match("^(%S+) receives (.+)%.$")
    if player and itemLink then
        local _, _, itemRarity = GetItemInfo(itemLink)
        if itemRarity and itemRarity >= 4 then  -- Check for Epic or higher quality (4 is Epic)
            player = CapitalizeFirstLetter(player)
            EnsurePlayerPointsEntry(player)
            playerPoints[player].points = 0
            SendToGoalsChat(player .. " received " .. itemLink .. " and has reset to 0 points.")
        end
    end
end

-- Award points to group members for boss kills
local function AwardPointsToGroup(encounterName)
    SendToGoalsChat("Awarding points to group for completing encounter: " .. encounterName)

    local members = GetAllGroupMembers()
    for _, member in ipairs(members) do
        EnsurePlayerPointsEntry(member.name, member.class)
        playerPoints[member.name].points = playerPoints[member.name].points + 1
        SendToGoalsChat("Awarded 1 point to: " .. member.name .. ". Total points: " .. playerPoints[member.name].points)
    end

    -- Reset encounter status to allow repeating the encounter
    bossesKilled[encounterName] = nil
    encounterCompleted[encounterName] = nil

    -- Update and display points for all members in the group
    ListPartyOrRaidMembersSorted()  -- Automatically list the players in the party/raid after awarding points
end

-- Function to list players in the current raid/party, sorted by points (high to low) and alphabetically if tied
function ListPartyOrRaidMembersSorted()
    local members = GetAllGroupMembers()
    local memberList = {}

    -- Collect all group members into a list for sorting
    for _, member in ipairs(members) do
        local playerName = member.name
        EnsurePlayerPointsEntry(playerName, member.class)
        table.insert(memberList, {name = playerName, points = playerPoints[playerName].points, class = playerPoints[playerName].class})
    end

    -- Sort the member list: First by points descending, then by name ascending
    table.sort(memberList, function(a, b)
        if a.points == b.points then
            return a.name < b.name  -- Sort alphabetically if points are the same
        else
            return a.points > b.points  -- Sort by points (high to low)
        end
    end)

    -- Display the sorted list in the "GOALS" chat tab
    SendToGoalsChat("Listing raid/party members (sorted by points):")
    for _, playerData in ipairs(memberList) do
        local classColor = classColors[strlower(playerData.class)] or classColors["unknown"]
        local colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        SendToGoalsChat(colorCode .. playerData.name .. "|r: " .. tostring(playerData.points) .. " points")
    end
end

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

SLASH_GSETPOINTS1 = '/gosetpoints'
SlashCmdList["GSETPOINTS"] = function(msg)
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
SLASH_GSETCLASS1 = '/gosetclass'
SlashCmdList["GSETCLASS"] = function(msg)
    local player, class = strsplit(" ", msg, 2)
    if player and class then
        SetPlayerClass(player, class)
    else
        SendToGoalsChat("Usage: /gosetclass [player] [class]")
    end
end


-- Slash command to list all players in the database
SLASH_GLIST1 = '/golist'
SlashCmdList["GLIST"] = function()
    if next(playerPoints) == nil then
        SendToGoalsChat("No players in the database.")
    else
        SendToGoalsChat("Listing all players:")
        -- Sort players in the database by points and alphabetically
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
SLASH_GREMOVE1 = '/goremove'
SlashCmdList["GREMOVE"] = function(msg)
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

-- Function to send raid/party points to chat
function SendPointsToChat()
    local members = GetAllGroupMembers()
    local memberList = {}

    -- Collect all group members into a list for sorting
    for _, member in ipairs(members) do
        local playerName = member.name
        EnsurePlayerPointsEntry(playerName, member.class)
        table.insert(memberList, {name = playerName, points = playerPoints[playerName].points, class = playerPoints[playerName].class})
    end

    -- Sort the member list: First by points descending, then by name ascending
    table.sort(memberList, function(a, b)
        if a.points == b.points then
            return a.name < b.name
        else
            return a.points > b.points
        end
    end)

    -- Determine chat type (raid, party, or say if alone)
    local chatType
    if GetNumRaidMembers() > 0 then
        chatType = "RAID"
    elseif GetNumPartyMembers() > 0 then
        chatType = "PARTY"
    else
        chatType = "SAY"
    end

    -- Send points to raid/party chat or say chat if alone
    if #memberList > 0 then
        for _, playerData in ipairs(memberList) do
            local message = playerData.name .. ": " .. playerData.points .. " points"
            SendChatMessage(message, chatType)
        end
    else
        SendToGoalsChat("No members found to send points for.")
    end
end

SLASH_GSEND1 = '/gosend'
SlashCmdList["GSEND"] = SendPointsToChat

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
        "|cffc41e3a deathknight|r, " ..  -- Correct color for Death Knight
        "|cffff7d0a druid|r, " ..        -- Correct color for Druid
        "|cffabd473 hunter|r, " ..       -- Correct color for Hunter
        "|cff69ccf0 mage|r, " ..         -- Correct color for Mage
        "|cfff58cba paladin|r, " ..      -- Correct color for Paladin
        "|cffffffff priest|r, " ..       -- Correct color for Priest
        "|cfffff569 rogue|r, " ..        -- Correct color for Rogue
        "|cff0070de shaman|r, " ..       -- Correct color for Shaman
        "|cff9482c9 warlock|r, " ..      -- Correct color for Warlock
        "|cffc79c6e warrior|r, " ..      -- Correct color for Warrior
        "|cff808080 unknown|r).")        -- Correct color for Unknown
    SendToGoalsChat("|cffFFD700/goremove [player]|r - Remove a player from the database.")
    SendToGoalsChat("|cffFFD700/gosend|r - Send the current raid/party members' points to raid or party chat.")
end


-- Function to reset an encounter
local function ResetEncounter(encounter)
    if bossesKilled[encounter] then
        bossesKilled[encounter] = nil
    end
    if encounterCompleted[encounter] then
        encounterCompleted[encounter] = nil
    end
    if encounterActive[encounter] then
        encounterActive[encounter] = nil
    end
    SendToGoalsChat("Encounter reset: [" .. encounter .. "].")
end

-- Main event handler function
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
        PlayerPointsDB = playerPoints

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, _ = ...

        if subevent == "UNIT_DIED" then
            local found = false
            for encounter, bosses in pairs(bossEncounters) do
                for i, bossName in ipairs(bosses) do
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

            -- Handle single boss encounters
            if not found then
                for encounter, bosses in pairs(bossEncounters) do
                    if #bosses == 1 and bosses[1] == destName then
                        SendToGoalsChat("Killed: [" .. destName .. "], a boss unit.")
                        found = true
                        encounterActive[encounter] = true
                        AwardPointsToGroup(encounter)  -- Award points for single boss encounter
                        UpdatePlayerNamesWithProperCasing()
                        ResetEncounter(encounter)
                        break
                    end
                end
            end

            -- If not found, log that the unit was not on the boss list
            if not found then
                SendToGoalsChat("Killed: [" .. destName .. "], not on the boss list.")
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

                if not allBossesDead then
                    SendToGoalsChat("Encounter failed: [" .. encounter .. "]. Resetting.")
                    ResetEncounter(encounter)
                else
                    SendToGoalsChat("All bosses already dead in encounter: [" .. encounter .. "], skipping reset.")
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
