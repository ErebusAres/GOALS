-- Goals UI feature module. Methods are mechanically extracted from gui.lua.

local Goals = _G.Goals
local context = Goals and Goals.UI and Goals.UI.ModuleContext
if not context then
    return
end

local moduleEnvironment = setmetatable({}, {
    __index = context,
    __newindex = context,
})
setfenv(1, moduleEnvironment)
function UI:Minimize()
    if not self.frame then
        return
    end
    self.frame:Hide()
    if self.combatBroadcastPopout and self.combatBroadcastPopout:IsShown() then
        self.combatBroadcastPopout:Hide()
    end
    if Goals.db and Goals.db.settings and Goals.db.settings.floatingButton then
        Goals.db.settings.floatingButton.show = true
    end
    self:ShowFloatingButton(true)
end

function UI:ShowFloatingButton(show)
    if not self.floatingButton then
        return
    end
    if show then
        self.floatingButton:Show()
    else
        self.floatingButton:Hide()
    end
end

function UI:CreateMinimapButton()
    if self.minimapButton then
        return
    end
    local button = CreateFrame("Button", "GoalsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            if IsShiftKeyDown and IsShiftKeyDown() then
                if UI and UI.ToggleMiniTracker then
                    UI:ToggleMiniTracker()
                end
                return
            end
            Goals:ToggleUI()
        end
    end)
    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_LEFT")
        local versionText = Goals and Goals.GetDisplayVersion and Goals:GetDisplayVersion() or "2"
        GameTooltip:SetText("Goals v" .. versionText)
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or ""
        local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
        local entry = players[playerName]
        local points = entry and entry.points or 0
        if playerName ~= "" then
            GameTooltip:AddLine(string.format("%s has %d points", colorizeName(playerName), points), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local icon = button:CreateTexture(nil, "ARTWORK")
    local function setIconTexture(path)
        icon:SetTexture(nil)
        icon:SetTexture(path)
        if icon:GetTexture() then
            return true
        end
        return false
    end

    local iconPath = string.format("Interface\\AddOns\\%s\\Icons\\GoalsRune-Glow", addonName)
    if not setIconTexture(iconPath) then
        icon:SetTexture("Interface\\Icons\\achievement_bg_killflagcarriers_grabflag_capit")
    end
    icon:SetSize(18, 18)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:Show()
    button.border = border

    button:SetScript("OnDragStart", function(selfBtn)
        selfBtn.isMoving = true
        selfBtn:SetScript("OnUpdate", function()
            UI:UpdateMinimapPositionFromCursor()
        end)
    end)
    button:SetScript("OnDragStop", function(selfBtn)
        selfBtn.isMoving = false
        selfBtn:SetScript("OnUpdate", nil)
    end)

    self.minimapButton = button
    self:UpdateMinimapPosition()
end

function UI:CreateMiniTracker()
    if self.miniTracker then
        return
    end
    local frame = CreateFrame("Frame", "GoalsMiniTracker", UIParent, "GoalsInsetTemplate")
    applyInsetTheme(frame)
    frame:SetSize(MINI_FRAME_WIDTH, MINI_HEADER_HEIGHT + 10)
    frame:SetPoint("CENTER", UIParent, "CENTER", MINI_DEFAULT_X, MINI_DEFAULT_Y)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local uiX, uiY = UIParent:GetCenter()
        local x, y = selfFrame:GetCenter()
        local settings = getMiniSettings()
        if settings then
            settings.x = x - uiX
            settings.y = y - uiY
            settings.hasPosition = true
        end
    end)
    frame:SetAlpha(0.85)
    frame:Hide()

    local titleBg = frame:CreateTexture(nil, "BORDER")
    titleBg:SetTexture("Interface\\AddOns\\Goals\\Texture\\FrameGeneral\\_UI-Frame")
    titleBg:SetHeight(17)
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -3)
    titleBg:SetTexCoord(0.0, 1.0, 0.2890625, 0.421875)
    frame.titleBg = titleBg

    local title = createLabel(frame, L.LABEL_MINI_TRACKER, "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -6)
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
    close:SetScript("OnClick", function()
        UI:CloseMiniTracker()
    end)
    frame.close = close

    local minimize = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    minimize:SetSize(18, 18)
    minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-HideButton-Highlight", "ADD")
    minimize:SetPoint("RIGHT", close, "LEFT", 2, 0)
    minimize:SetScript("OnClick", function()
        UI:MinimizeMiniTracker()
    end)
    frame.minimize = minimize

    frame.rows = {}
    self.miniTracker = frame
    self:UpdateMiniTrackerPosition()
end

function UI:ShowMiniTracker(show)
    if not self.miniTracker then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.show = show and true or false
    settings.minimized = false
    if show then
        if not settings.hasPosition then
            self.miniTracker:ClearAllPoints()
            if self.frame and self.frame:IsShown() then
                self.miniTracker:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -4, -2)
            else
                self.miniTracker:SetPoint("CENTER", UIParent, "CENTER", MINI_DEFAULT_X, MINI_DEFAULT_Y)
            end
            local uiX, uiY = UIParent:GetCenter()
            local x, y = self.miniTracker:GetCenter()
            settings.x = x - uiX
            settings.y = y - uiY
            settings.hasPosition = true
        else
            self:UpdateMiniTrackerPosition()
        end
    else
        self:UpdateMiniTrackerPosition()
    end
    self:UpdateMiniTracker()
end

function UI:ToggleMiniTracker()
    if not self.miniTracker then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    if not settings.show then
        self:ShowMiniTracker(true)
        return
    end
    if settings.minimized then
        self:ShowMiniTracker(true)
        return
    end
    self:MinimizeMiniTracker()
end

function UI:MinimizeMiniTracker()
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.minimized = true
    self:UpdateMiniTracker()
end

function UI:CloseMiniTracker()
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.show = false
    settings.minimized = false
    self:UpdateMiniTracker()
end

function UI:ResetMiniTrackerPosition()
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.hasPosition = false
    if self.miniTracker and self.miniTracker:IsShown() then
        self:ShowMiniTracker(true)
    end
end

function UI:CreateMiniFloatingButton()
    if self.miniFloatingButton then
        return
    end
    local button = CreateFrame("Button", "GoalsMiniFloatingButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetText(L.BUTTON_TOGGLE_MINI_TRACKER)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(selfBtn)
        selfBtn:StopMovingOrSizing()
        local uiX, uiY = UIParent:GetCenter()
        local x, y = selfBtn:GetCenter()
        local settings = getMiniSettings()
        if settings then
            settings.buttonX = x - uiX
            settings.buttonY = y - uiY
        end
    end)
    button:SetScript("OnClick", function()
        UI:ShowMiniTracker(true)
    end)
    button:Hide()
    self.miniFloatingButton = button
    self:UpdateMiniFloatingPosition()
end

function UI:CreateFloatingButton()
    if self.floatingButton then
        return
    end
    local button = CreateFrame("Button", "GoalsFloatingButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetText(L.BUTTON_OPEN)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(selfBtn)
        selfBtn:StopMovingOrSizing()
        local uiX, uiY = UIParent:GetCenter()
        local x, y = selfBtn:GetCenter()
        Goals.db.settings.floatingButton.x = x - uiX
        Goals.db.settings.floatingButton.y = y - uiY
    end)
    button:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)
    self.floatingButton = button
    self:UpdateFloatingPosition()
    if Goals.db.settings.floatingButton.show then
        button:Show()
    else
        button:Hide()
    end
end

function UI:CreateOptionsPanel()
    if self.optionsPanel then
        return
    end
    local panel = CreateFrame("Frame", "GoalsOptionsPanel", UIParent)
    panel.name = L.TITLE

    local title = createLabel(panel, L.TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(120, 22)
    openButton:SetText(L.BUTTON_OPEN)
    openButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    openButton:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)

    local floatingCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    floatingCheck:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", -2, -8)
    setCheckText(floatingCheck, "Show floating button")
    floatingCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.floatingButton.show = selfBtn:GetChecked() and true or false
        UI:ShowFloatingButton(Goals.db.settings.floatingButton.show)
    end)

    panel:SetScript("OnShow", function()
        floatingCheck:SetChecked(Goals.db.settings.floatingButton.show and true or false)
    end)

    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
end
