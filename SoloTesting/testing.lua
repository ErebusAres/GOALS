-- Combined WoW Addon File with Chat Integration and Boss Encounter Checking

-- Class colors configuration
local classColors = { 
    deathKnight = {r = 0.77, g = 0.12, b = 0.23},
    druid       = {r = 1.0, g = 0.49, b = 0.04},
    hunter      = {r = 0.67, g = 0.83, b = 0.45},
    mage        = {r = 0.25, g = 0.78, b = 0.92},
    paladin     = {r = 0.96, g = 0.55, b = 0.73},
    priest      = {r = 1.0, g = 1.0, b = 1.0},
    rogue       = {r = 1.0, g = 0.96, b = 0.41},
    shaman      = {r = 0.0, g = 0.44, b = 0.87},
    warlock     = {r = 0.53, g = 0.53, b = 0.93},
    warrior     = {r = 0.78, g = 0.63, b = 0.43}
}

local playerPoints = {}  -- Table to store player points
local bossEncounters = {}  -- Table to store boss encounter information

-- Load the bossEncounters list from the bossEncounters.lua file
local function LoadBossEncounters()
    if bossEncountersList then
        bossEncounters = bossEncountersList
    else
        SendToGoalsChat("Error: Failed to load boss encounter data.")
    end
end

-- Function to check if the killed unit is a boss
local function IsBoss(unitName)
    return bossEncounters[unitName] ~= nil
end

-- Function to send messages to the "GOALS" chat tab
local function SendToGoalsChat(msg)
    if msg then
        local chatTabIndex = nil
        for i = 1, NUM_CHAT_WINDOWS do
            local name = GetChatWindowInfo(i)
            if name == "GOALS" then
                chatTabIndex = i
                break
            end
        end

        -- If "GOALS" chat tab does not exist, create it
        if not chatTabIndex then
            FCF_OpenNewWindow("GOALS")
            chatTabIndex = NUM_CHAT_WINDOWS  -- New chat window is always the last one
            FCF_SetWindowName(_G["ChatFrame" .. chatTabIndex], "GOALS")
            SendToGoalsChat("GOALS tab created.")
        end

        -- Send the message to the "GOALS" chat tab
        local color = "|cffFFD700"  -- Gold color code for the prefix
        _G["ChatFrame" .. chatTabIndex]:AddMessage(color .. "[GOALS]:|r " .. msg)
    end
end

-- Function to update party/raid members and send to chat
function UpdatePartyMembers()
    SendToGoalsChat("Updating party/raid members...")

    -- Ensure the player is included in the list
    local playerName, playerClass = UnitName("player"), UnitClass("player")
    if playerName and playerClass then
        local classColor = classColors[strlower(playerClass)] or {r = 1, g = 1, b = 1}
        local colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        SendToGoalsChat(colorCode .. playerName .. "|r: " .. tostring(playerPoints[playerName] or 0) .. " points")
    end

    -- Loop through party/raid members
    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name, _, _, _, class = GetRaidRosterInfo(i)
        if name and class then
            local classColor = classColors[strlower(class)] or {r = 1, g = 1, b = 1}
            local colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
            SendToGoalsChat(colorCode .. name .. "|r: " .. tostring(playerPoints[name] or 0) .. " points")
        end
    end
end

-- Toggle logic for showing points in the "GOALS" chat
function ToggleGoalsPoints()
    UpdatePartyMembers()
end

SLASH_TOGGLEGOALS1 = '/tg'
SlashCmdList["TOGGLEGOALS"] = ToggleGoalsPoints

-- Award points to group members for boss kills
local function AwardPointsToGroup(unitName)
    if IsBoss(unitName) then
        SendToGoalsChat("Awarding points to group for killing: " .. unitName)

        local numGroupMembers = GetNumGroupMembers()
        for i = 1, numGroupMembers do
            local name = GetRaidRosterInfo(i)
            if name and name ~= "" then
                playerPoints[name] = (playerPoints[name] or 0) + 1
                SendToGoalsChat("Awarded 1 point to: " .. name .. ". Total points: " .. playerPoints[name])
            end
        end

        UpdatePartyMembers() -- Update data when points are awarded
    else
        SendToGoalsChat("Unit killed was not a boss: " .. unitName)
    end
end

-- Event handling function
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Testing" then
            LoadBossEncounters()
            InitializePlayerPoints()
            self:UnregisterEvent("ADDON_LOADED")
            SendToGoalsChat("Addon: [" .. addonName .. "] loaded.")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, _ = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" and destName then
            AwardPointsToGroup(destName)  -- Award points for boss kills if the unit is a boss
        end
    end
end

-- Event registration
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnEvent)

-- Slash command to manually set points for a player
function SetPlayerPoints(player, points)
    playerPoints[player] = points
    SendToGoalsChat("Set points for " .. player .. ": " .. points)
    UpdatePartyMembers()
end

SLASH_SETPOINTS1 = '/setpoints'
SlashCmdList["SETPOINTS"] = function(msg)
    local player, points = strsplit(" ", msg, 2)
    points = tonumber(points)
    if player and points then
        SetPlayerPoints(player, points)
    else
        SendToGoalsChat("Usage: /setpoints [player] [points]")
    end
end

-- Initialize player points on addon load
function InitializePlayerPoints()
    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name = GetRaidRosterInfo(i)
        if name then
            playerPoints[name] = 0
        end
    end
end
