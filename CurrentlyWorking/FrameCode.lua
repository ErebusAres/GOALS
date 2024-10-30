local scroll = nil;
local rowCount = 0;

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


-- Ensure the function is globally accessible
function _G.CreateGoalsFrame()
    if GoalsFrame then
        print("GoalsFrame already exists.")
        return
    end

    -- Main Frame
    local frame = CreateFrame("Frame", "GoalsFrame", UIParent)
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
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
        
    if not GoalsFrameTitle then
        print("Debug: GoalsFrameTitle not found, creating it")
        titleFrame = CreateFrame("Frame", "GoalsFrameTitle", frame)
    end
    GoalsFrameTitle:StartMoving()
      -- Move the title with the main frame
        
    if not GoalsFrameCredits then
        print("Debug: GoalsFrameCredits not found, creating it")
        creditsFrame = CreateFrame("Frame", "GoalsFrameCredits", frame)
    end
    GoalsFrameCredits:StartMoving()
      -- Move the credits frame with the main frame
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
    if not GoalsFrameTitle then
        print("Debug: GoalsFrameTitle not found on drag stop, creating it")
        titleFrame = CreateFrame("Frame", "GoalsFrameTitle", frame)
    end
    GoalsFrameTitle:StopMovingOrSizing()
    
        
    if not GoalsFrameCredits then
        print("Debug: GoalsFrameCredits not found on drag stop, creating it")
        creditsFrame = CreateFrame("Frame", "GoalsFrameCredits", frame)
    end
    GoalsFrameCredits:StopMovingOrSizing()
    
    end)
    print("Debug: Created GoalsFrame")

    -- Title Box (Frame Title)
    
    -- Initialize the GoalsFrameTitle only if it does not already exist
    
    print("Debug: Checking GoalsFrameTitle existence")
    if not GoalsFrameTitle then
    print("Debug: Creating GoalsFrameTitle")
    
        titleFrame = CreateFrame("Frame", "GoalsFrameTitle", frame)
    end
    
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
    titleFrame:SetMovable(true)  -- Mark title frame as movable
    titleFrame:RegisterForDrag("LeftButton")
    titleFrame:SetScript("OnDragStart", function(self)
        frame:StartMoving()  -- Move the main frame when the title is dragged
    end)
    titleFrame:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()  -- Stop moving the main frame
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

    scroll = scrollChild;

    

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
    underlinePlayers:SetTexture(1, 1, 1)  -- Use SetTexture with color values (1, 1, 1) for white

    local underlinePoints = scrollChild:CreateTexture(nil, "BACKGROUND")
    underlinePoints:SetSize(150, 2)
    underlinePoints:SetPoint("TOPRIGHT", pointsHeader, "BOTTOMRIGHT", 0, -2)
    underlinePoints:SetTexture(1, 1, 1)  -- Use SetTexture with color values (1, 1, 1) for white

    -- This is the previous way of showing values, in the concatenated string method. Leaving this here in case we need to go back
    -- Create FontStrings for displaying players and points
    --local playerText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    --playerText:SetPoint("TOPLEFT", 20, -30)
    --playerText:SetJustifyH("LEFT")
    --playerText:SetFont("Fonts\\FRIZQT__.TTF", 12)

    --local pointsText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    --pointsText:SetPoint("TOPRIGHT", -20, -30)
    --pointsText:SetJustifyH("RIGHT")
    --pointsText:SetFont("Fonts\\FRIZQT__.TTF", 12)

    -- Save FontStrings to the frame for later access
    --frame.playerText = playerText
    --frame.pointsText = pointsText

    -- Credits Frame (Bottom)
    
    -- Initialize the GoalsFrameCredits only if it does not already exist
    
    print("Debug: Checking GoalsFrameCredits existence")
    if not GoalsFrameCredits then
    print("Debug: Creating GoalsFrameCredits")
    
        creditsFrame = CreateFrame("Frame", "GoalsFrameCredits", frame)
    end
    
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

    -- Enable the credits frame to be movable with the main frame
    creditsFrame:EnableMouse(true)
    creditsFrame:SetMovable(true)
    creditsFrame:RegisterForDrag("LeftButton")
    creditsFrame:SetScript("OnDragStart", function(self)
        frame:StartMoving()
        
    if not GoalsFrameTitle then
        print("Debug: GoalsFrameTitle not found, creating it")
        titleFrame = CreateFrame("Frame", "GoalsFrameTitle", frame)
    end
    GoalsFrameTitle:StartMoving()
    
    end)
    creditsFrame:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        
    if not GoalsFrameTitle then
        print("Debug: GoalsFrameTitle not found on drag stop, creating it")
        titleFrame = CreateFrame("Frame", "GoalsFrameTitle", frame)
    end
    GoalsFrameTitle:StopMovingOrSizing()
    
    end)

    print("Created Credits Frame.")

    -- Hide the frame by default
    frame:Hide()

    return frame
end

-- Adds a row to the table view of the point tracker
function addRow(player, point, class)
    local tableRow = CreateFrame("Frame", "GoalsFrameScrollChildRow" .. rowCount, scroll)
    tableRow:SetSize(150, 20);
    tableRow:SetPoint("TOPLEFT", 0, rowCount * -20)

    local playerText = tableRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetPoint("TOPLEFT", 20, -30)
    playerText:SetJustifyH("LEFT")
    playerText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    
    print("Debug: Setting text color for class:", class)
    if not classColors[strlower(class)] then
        print("Error: classColors for", class, "is nil")
    else
        print("Debug: classColors for", class, "exists with r:", classColors[strlower(class)]["r"], "g:", classColors[strlower(class)]["g"], "b:", classColors[strlower(class)]["b"])
    end
    playerText:SetTextColor(classColors[strlower(class)]["r"], classColors[strlower(class)]["g"], classColors[strlower(class)]["b"], 1.0)
    

    local pointsText = tableRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointsText:SetPoint("TOP", 75, -30)
    pointsText:SetJustifyH("MIDDLE")
    pointsText:SetFont("Fonts\\FRIZQT__.TTF", 12)

    -- Buttons in each row. Currently don't want them, but leaving this here for now in case we change our minds.
    --local awardButton = CreateFrame("Button", "GoalsFrameScrollChildAwardButton" .. rowCount, tableRow, "UIPanelButtonTemplate")
    --awardButton:SetText("Award")
    --awardButton:SetSize(75, 20)
    --awardButton:SetPoint("TOPRIGHT", 150, -30)
    
    --local plusButton = CreateFrame("Button", "GoalsFrameScrollChildPlusButton" .. rowCount, tableRow, "UIPanelButtonTemplate")
    --awardButton:SetText("+")
    --awardButton:SetSize(20, 20)
    --awardButton:SetPoint("TOPRIGHT", 170, -30)

    --local minusButton = CreateFrame("Button", "GoalsFrameScrollChildMinusButton" .. rowCount, tableRow, "UIPanelButtonTemplate")
    --awardButton:SetText("-")
    --awardButton:SetSize(20, 20)
    --awardButton:SetPoint("TOPRIGHT", 190, -30)


    playerText:SetText(player)
    pointsText:SetText(point)

    rowCount = rowCount + 1;
end

-- Function to clear all rows before re-adding data
function ClearAllRows()
    if GoalsFrame.rows then
        for i, row in ipairs(GoalsFrame.rows) do
            row:Hide()  -- Hide each row
        end
    end
    GoalsFrame.rows = {}  -- Ensure rows are initialized  -- Reset rows table
end

-- Add event listener for group/party changes

-- Ensure GoalsFrame is created before registering events
if not GoalsFrame then
    CreateGoalsFrame()
end
GoalsFrame:RegisterEvent("RAID_ROSTER_UPDATE")  -- Correct for raid changes in 3.3.5a
GoalsFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- Correct for party changes in 3.3.5a
    

GoalsFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        ClearAllRows()  -- Clear existing rows
        UpdatePartyMembers()  -- Custom function to add updated party/raid members
    end
end)

-- Function to update party/raid members
function UpdatePartyMembers()
    -- Ensure the player is included in the list
    local name, class = UnitName("player"), UnitClass("player")
    if name and class then
        addRow(name, tostring(playerPoints[name] or 0), class)
    end
    
    
    -- Ensure the player is included in the list
    local playerName, playerClass = UnitName("player"), UnitClass("player")
    if playerName and playerClass then
        addRow(playerName, tostring(playerPoints[playerName] or 0), playerClass)
    end
    
    -- Loop through party/raid members
    
    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local memberName, _, _, _, memberClass = GetRaidRosterInfo(i)
        if memberName and memberClass then
            addRow(memberName, tostring(playerPoints[memberName] or 0), memberClass)
        end
    end
end

-- Toggle logic for showing and hiding GoalsFrame
function ToggleGoalsFrame()
    if GoalsFrame:IsShown() then
        GoalsFrame:Hide()
        print("Debug: GoalsFrame is being hidden")
    else
        GoalsFrame:Show()
        print("Debug: GoalsFrame is being shown")
    end
end
