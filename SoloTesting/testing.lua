-- Combined WoW Addon File (FrameCode and Testing Combined)

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

local scroll = nil
local rowCount = 0
local playerPoints = {}  -- Table to store player points

-- Ensure the function is globally accessible
function _G.CreateGoalsFrame()
    if GoalsFrame then
        print("GoalsFrame already exists.")
        return
    end

    -- Main Frame
    local frame = CreateFrame("Frame", "GoalsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 300)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    print("Debug: Created GoalsFrame")

    -- Title Box (Frame Title)
    local titleFrame = CreateFrame("Frame", "GoalsFrameTitle", frame)
    titleFrame:SetSize(400, 40)
    titleFrame:SetPoint("BOTTOM", frame, "TOP", 0, -10)
    titleFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    titleFrame:SetBackdropColor(0.2, 0.2, 0.5, 1)  -- Blueish background for the title

    -- Make the title frame movable
    titleFrame:EnableMouse(true)
    titleFrame:SetMovable(true)
    titleFrame:RegisterForDrag("LeftButton")
    titleFrame:SetScript("OnDragStart", function(self)
        frame:StartMoving()
    end)
    titleFrame:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
    end)

    -- Title Text
    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("CENTER", titleFrame, "CENTER", 0, 0)
    titleText:SetText("Boss Kill Tracker")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")

    -- Scroll Frame for Main Content
    local scrollFrame = CreateFrame("ScrollFrame", "GoalsFrameMainContent", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(360, 250)
    scrollFrame:SetPoint("TOPLEFT", 20, -40)

    -- Scroll Child (Container for the scroll frame)
    local scrollChild = CreateFrame("Frame", "GoalsFrameScrollChild", scrollFrame)
    scrollChild:SetSize(360, 250)
    scrollFrame:SetScrollChild(scrollChild)
    scroll = scrollChild

    -- Headers for Players and Points
    local playersHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    playersHeader:SetPoint("TOPLEFT", 20, -5)
    playersHeader:SetText("Players")
    playersHeader:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    local pointsHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pointsHeader:SetPoint("TOPRIGHT", -20, -5)
    pointsHeader:SetText("Points")
    pointsHeader:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    -- Underline for the Headers (Players and Points)
    local underlinePlayers = scrollChild:CreateTexture(nil, "BACKGROUND")
    underlinePlayers:SetSize(150, 2)
    underlinePlayers:SetPoint("TOPLEFT", playersHeader, "BOTTOMLEFT", 0, -2)
    underlinePlayers:SetTexture(1, 1, 1)

    local underlinePoints = scrollChild:CreateTexture(nil, "BACKGROUND")
    underlinePoints:SetSize(150, 2)
    underlinePoints:SetPoint("TOPRIGHT", pointsHeader, "BOTTOMRIGHT", 0, -2)
    underlinePoints:SetTexture(1, 1, 1)

    -- Credits Frame (Bottom)
    local creditsFrame = CreateFrame("Frame", "GoalsFrameCredits", frame)
    creditsFrame:SetSize(400, 30)
    creditsFrame:SetPoint("TOP", frame, "BOTTOM", 0, 5)
    creditsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    creditsFrame:SetBackdropColor(0.2, 0.2, 0.5, 1)

    local creditsText = creditsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    creditsText:SetPoint("CENTER", creditsFrame, "CENTER", 0, 0)
    creditsText:SetText("Made By: Adam and Corey.")
    creditsText:SetFont("Fonts\\FRIZQT__.TTF", 10)

    -- Hide the frame by default
    frame:Hide()
    GoalsFrame = frame
end

-- Adds a row to the table view of the point tracker
function addRow(player, point, class)
    local tableRow = CreateFrame("Frame", "GoalsFrameScrollChildRow" .. rowCount, scroll)
    tableRow:SetSize(150, 20)
    tableRow:SetPoint("TOPLEFT", 0, rowCount * -20)

    local playerText = tableRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetPoint("TOPLEFT", 20, 0)
    playerText:SetJustifyH("LEFT")
    playerText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    local classColor = classColors[strlower(class)] or {r = 1, g = 1, b = 1}
    playerText:SetTextColor(classColor.r, classColor.g, classColor.b, 1.0)
    playerText:SetText(player)

    local pointsText = tableRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointsText:SetPoint("TOP", 75, 0)
    pointsText:SetJustifyH("MIDDLE")
    pointsText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    pointsText:SetText(point)

    rowCount = rowCount + 1
end

-- Function to clear all rows before re-adding data
function ClearAllRows()
    for i = 1, rowCount do
        local row = _G["GoalsFrameScrollChildRow" .. (i - 1)]
        if row then
            row:Hide()
        end
    end
    rowCount = 0
end

-- Function to update party/raid members
function UpdatePartyMembers()
    ClearAllRows()  -- Clear existing rows

    -- Ensure the player is included in the list
    local playerName, playerClass = UnitName("player"), UnitClass("player")
    if playerName and playerClass then
        addRow(playerName, tostring(playerPoints[playerName] or 0), playerClass)
    end

    -- Loop through party/raid members
    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name, _, _, _, class = GetRaidRosterInfo(i)
        if name and class then
            addRow(name, tostring(playerPoints[name] or 0), class)
        end
    end
end

-- Toggle logic for showing and hiding GoalsFrame
function ToggleGoalsFrame()
    if not GoalsFrame then
        CreateGoalsFrame()
    end

    if GoalsFrame:IsShown() then
        GoalsFrame:Hide()
        print("Debug: GoalsFrame is being hidden")
    else
        GoalsFrame:Show()
        print("Debug: GoalsFrame is being shown")
        UpdatePartyMembers()  -- Update data when showing the frame
    end
end

SLASH_TOGGLEGOALS1 = '/tg'
SlashCmdList["TOGGLEGOALS"] = ToggleGoalsFrame

-- Award points to group members
local function AwardPointsToGroup()
    print("Awarding points to group...")

    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name = GetRaidRosterInfo(i)
        if name and name ~= "" then
            playerPoints[name] = (playerPoints[name] or 0) + 1
            print("Awarded 1 point to: " .. name .. ". Total points: " .. playerPoints[name])
        end
    end

    -- Update the frame if it's shown
    if GoalsFrame and GoalsFrame:IsShown() then
        UpdatePartyMembers()
    end
end

-- Event handling function
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Testing" then
            InitializePlayerPoints()
            self:UnregisterEvent("ADDON_LOADED")
            print("Addon: [" .. addonName .. "] loaded.")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, _ = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" then
            AwardPointsToGroup()  -- Award points for boss kills
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
    print("Set points for " .. player .. ": " .. points)
    UpdatePartyMembers()
end

SLASH_SETPOINTS1 = '/setpoints'
SlashCmdList["SETPOINTS"] = function(msg)
    local player, points = strsplit(" ", msg, 2)
    points = tonumber(points)
    if player and points then
        SetPlayerPoints(player, points)
    else
        print("Usage: /setpoints [player] [points]")
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
