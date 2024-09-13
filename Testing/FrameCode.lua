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
        GoalsFrameTitle:StartMoving()  -- Move the title with the main frame
        GoalsFrameCredits:StartMoving()  -- Move the credits frame with the main frame
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        GoalsFrameTitle:StopMovingOrSizing()
        GoalsFrameCredits:StopMovingOrSizing()
    end)
    print("Created GoalsFrame.")

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

    -- Create FontStrings for displaying players and points
    local playerText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetPoint("TOPLEFT", 20, -30)
    playerText:SetJustifyH("LEFT")
    playerText:SetFont("Fonts\\FRIZQT__.TTF", 12)

    local pointsText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointsText:SetPoint("TOPRIGHT", -20, -30)
    pointsText:SetJustifyH("RIGHT")
    pointsText:SetFont("Fonts\\FRIZQT__.TTF", 12)

    -- Save FontStrings to the frame for later access
    frame.playerText = playerText
    frame.pointsText = pointsText

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

    -- Enable the credits frame to be movable with the main frame
    creditsFrame:EnableMouse(true)
    creditsFrame:SetMovable(true)
    creditsFrame:RegisterForDrag("LeftButton")
    creditsFrame:SetScript("OnDragStart", function(self)
        frame:StartMoving()
        GoalsFrameTitle:StartMoving()
    end)
    creditsFrame:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        GoalsFrameTitle:StopMovingOrSizing()
    end)

    print("Created Credits Frame.")

    -- Hide the frame by default
    frame:Hide()

    return frame
end
