-- Goals: gui.lua
-- Main UI, tabs, scroll lists, minimap button, and options panel.
-- Usage: Goals.UI:Toggle()

local addonName = ...
local Goals = _G.Goals
local L = Goals.L

Goals.UI = Goals.UI or {}
local UI = Goals.UI

local ROW_HEIGHT = 20
local ROSTER_ROWS = 16
local HISTORY_ROWS = 14

local function formatTime(ts)
    return date("%H:%M:%S", ts or time())
end

local function createLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetText(text)
    return label
end

local function createButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(text)
    button:SetSize(width, height)
    return button
end

function UI:Init()
    if self.frame then
        return
    end
    self:CreateMainFrame()
    self:CreateMinimapButton()
    self:CreateFloatingButton()
    self:CreateOptionsPanel()
    self:Refresh()
end

function UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Refresh()
    end
end

function UI:CreateMainFrame()
    local frame = CreateFrame("Frame", "GoalsMainFrame", UIParent, "UIPanelDialogTemplate")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = createLabel(frame, L.TITLE, "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -12)

    self.frame = frame
    self.tabs = {}
    self.pages = {}

    local tabNames = { L.TAB_OVERVIEW, L.TAB_LOOT, L.TAB_HISTORY, L.TAB_SETTINGS }
    if Goals.Dev and Goals.Dev.enabled then
        table.insert(tabNames, L.TAB_DEV)
    end

    for i, name in ipairs(tabNames) do
        local tabName = frame:GetName() .. "Tab" .. i
        local tab = CreateFrame("Button", tabName, frame, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(name)
        tab:SetScript("OnClick", function()
            UI:SelectTab(i)
        end)
        tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", (i - 1) * 110 + 10, 7)
        PanelTemplates_TabResize(tab, 0)
        self.tabs[i] = tab
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 12, -40)
        page:SetPoint("BOTTOMRIGHT", -12, 12)
        page:Hide()
        self.pages[i] = page
    end

    PanelTemplates_SetNumTabs(frame, #self.tabs)
    self:CreateOverviewTab(self.pages[1])
    self:CreateLootTab(self.pages[2])
    self:CreateHistoryTab(self.pages[3])
    self:CreateSettingsTab(self.pages[4])
    if Goals.Dev and Goals.Dev.enabled then
        self:CreateDevTab(self.pages[5])
    end
    self:SelectTab(1)
end

function UI:SelectTab(index)
    for i, page in ipairs(self.pages) do
        page:SetShown(i == index)
    end
    PanelTemplates_SetTab(self.frame, index)
end

function UI:CreateOverviewTab(parent)
    local header = createLabel(parent, L.TAB_OVERVIEW, "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 6, -6)

    local rosterFrame = CreateFrame("Frame", nil, parent)
    rosterFrame:SetSize(330, 360)
    rosterFrame:SetPoint("TOPLEFT", 6, -36)
    local rosterTitle = createLabel(rosterFrame, L.LABEL_POINTS, "GameFontNormal")
    rosterTitle:SetPoint("TOPLEFT", 2, 18)

    local scroll = CreateFrame("ScrollFrame", "GoalsRosterScroll", rosterFrame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -28, -4)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, ROW_HEIGHT, function()
            UI:UpdateRosterList()
        end)
    end)
    self.rosterScroll = scroll
    self.rosterRows = {}
    for i = 1, ROSTER_ROWS do
        local row = CreateFrame("Frame", nil, rosterFrame)
        row:SetSize(300, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 2, -((i - 1) * ROW_HEIGHT))
        row.name = createLabel(row, "", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 4, 0)
        row.points = createLabel(row, "", "GameFontHighlightSmall")
        row.points:SetPoint("RIGHT", -4, 0)
        self.rosterRows[i] = row
    end

    local statusFrame = CreateFrame("Frame", nil, parent)
    statusFrame:SetSize(360, 120)
    statusFrame:SetPoint("TOPLEFT", rosterFrame, "TOPRIGHT", 20, 0)
    local statusTitle = createLabel(statusFrame, L.LABEL_SYNC, "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", 0, 0)
    self.syncStatus = createLabel(statusFrame, "", "GameFontHighlight")
    self.syncStatus:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -8)
    self.disenchanterLabel = createLabel(statusFrame, "", "GameFontHighlight")
    self.disenchanterLabel:SetPoint("TOPLEFT", self.syncStatus, "BOTTOMLEFT", 0, -8)

    local manualFrame = CreateFrame("Frame", nil, parent)
    manualFrame:SetSize(360, 220)
    manualFrame:SetPoint("TOPLEFT", statusFrame, "BOTTOMLEFT", 0, -12)
    local manualTitle = createLabel(manualFrame, L.LABEL_MANUAL, "GameFontNormal")
    manualTitle:SetPoint("TOPLEFT", 0, 0)

    local nameLabel = createLabel(manualFrame, L.LABEL_PLAYER, "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", manualTitle, "BOTTOMLEFT", 0, -10)
    local nameBox = CreateFrame("EditBox", nil, manualFrame, "InputBoxTemplate")
    nameBox:SetSize(140, 20)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", -2, -4)
    nameBox:SetAutoFocus(false)
    self.adjustNameBox = nameBox

    local amountLabel = createLabel(manualFrame, L.LABEL_AMOUNT, "GameFontHighlightSmall")
    amountLabel:SetPoint("LEFT", nameBox, "RIGHT", 20, 2)
    local amountBox = CreateFrame("EditBox", nil, manualFrame, "InputBoxTemplate")
    amountBox:SetSize(80, 20)
    amountBox:SetPoint("TOPLEFT", amountLabel, "BOTTOMLEFT", -2, -4)
    amountBox:SetAutoFocus(false)
    amountBox:SetNumeric(true)
    self.adjustAmountBox = amountBox

    local addButton = createButton(manualFrame, L.BUTTON_ADD, 80, 22)
    addButton:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -12)
    addButton:SetScript("OnClick", function()
        if not Goals:HasLeaderAccess() then
            return
        end
        local name = nameBox:GetText()
        local value = tonumber(amountBox:GetText()) or 0
        if name ~= "" and value ~= 0 then
            Goals:AdjustPoints(name, value, "Manual award")
        end
    end)
    self.adjustAddButton = addButton

    local setButton = createButton(manualFrame, L.BUTTON_SET, 80, 22)
    setButton:SetPoint("LEFT", addButton, "RIGHT", 12, 0)
    setButton:SetScript("OnClick", function()
        if not Goals:HasLeaderAccess() then
            return
        end
        local name = nameBox:GetText()
        local value = tonumber(amountBox:GetText())
        if name ~= "" and value then
            Goals:SetPoints(name, value, "Manual set")
        end
    end)
    self.adjustSetButton = setButton
end

function UI:CreateLootTab(parent)
    local header = createLabel(parent, L.TAB_LOOT, "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 6, -6)

    local infoLabel = createLabel(parent, L.LABEL_LAST_LOOT, "GameFontNormal")
    infoLabel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    self.lastLootLabel = createLabel(parent, "", "GameFontHighlight")
    self.lastLootLabel:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -8)
end

function UI:CreateHistoryTab(parent)
    local header = createLabel(parent, L.TAB_HISTORY, "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 6, -6)

    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetSize(700, 360)
    listFrame:SetPoint("TOPLEFT", 6, -36)

    local scroll = CreateFrame("ScrollFrame", "GoalsHistoryScroll", listFrame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -28, -4)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, ROW_HEIGHT, function()
            UI:UpdateHistoryList()
        end)
    end)
    self.historyScroll = scroll
    self.historyRows = {}
    for i = 1, HISTORY_ROWS do
        local row = CreateFrame("Frame", nil, listFrame)
        row:SetSize(640, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 2, -((i - 1) * ROW_HEIGHT))
        row.time = createLabel(row, "", "GameFontHighlightSmall")
        row.time:SetPoint("LEFT", 4, 0)
        row.text = createLabel(row, "", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 80, 0)
        self.historyRows[i] = row
    end
end

function UI:CreateSettingsTab(parent)
    local header = createLabel(parent, L.TAB_SETTINGS, "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 6, -6)

    local combineCheck = CreateFrame("CheckButton", "GoalsCombineHistoryCheck", parent, "UICheckButtonTemplate")
    combineCheck:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    _G[combineCheck:GetName() .. "Text"]:SetText(L.CHECK_COMBINE_HISTORY)
    combineCheck:SetScript("OnClick", function(self)
        if not Goals:HasLeaderAccess() then
            self:SetChecked(Goals.db.settings.combineBossHistory)
            return
        end
        Goals:SetRaidSetting("combineBossHistory", self:GetChecked() == 1)
    end)
    self.combineCheck = combineCheck

    local minimapCheck = CreateFrame("CheckButton", "GoalsMinimapCheck", parent, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combineCheck, "BOTTOMLEFT", 0, -8)
    _G[minimapCheck:GetName() .. "Text"]:SetText(L.CHECK_MINIMAP)
    minimapCheck:SetScript("OnClick", function(self)
        Goals.db.settings.minimap.hide = self:GetChecked() ~= 1
        UI:UpdateMinimapButton()
    end)
    self.minimapCheck = minimapCheck

    local disenchantLabel = createLabel(parent, L.LABEL_DISENCHANTER, "GameFontNormal")
    disenchantLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -16)
    local disenchantBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    disenchantBox:SetSize(160, 20)
    disenchantBox:SetPoint("TOPLEFT", disenchantLabel, "BOTTOMLEFT", -2, -4)
    disenchantBox:SetAutoFocus(false)
    self.disenchanterBox = disenchantBox
    local disenchantButton = createButton(parent, L.SETTINGS_DISENCHANTER, 150, 22)
    disenchantButton:SetPoint("LEFT", disenchantBox, "RIGHT", 10, 0)
    disenchantButton:SetScript("OnClick", function()
        if not Goals:HasLeaderAccess() then
            return
        end
        Goals:SetDisenchanter(disenchantBox:GetText())
    end)
    self.disenchanterButton = disenchantButton

    if Goals.Dev and Goals.Dev.enabled then
        local debugCheck = CreateFrame("CheckButton", "GoalsDebugCheck", parent, "UICheckButtonTemplate")
        debugCheck:SetPoint("TOPLEFT", disenchantBox, "BOTTOMLEFT", 0, -12)
        _G[debugCheck:GetName() .. "Text"]:SetText(L.CHECK_DEBUG)
        debugCheck:SetScript("OnClick", function(self)
            Goals.db.settings.debug = self:GetChecked() == 1
        end)
        self.debugCheck = debugCheck
    end
end

function UI:CreateDevTab(parent)
    local header = createLabel(parent, L.TAB_DEV, "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 6, -6)

    local killButton = createButton(parent, L.DEV_SIM_KILL, 160, 22)
    killButton:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    killButton:SetScript("OnClick", function()
        Goals.Dev:SimulateBossKill()
    end)

    local wipeButton = createButton(parent, L.DEV_SIM_WIPE, 160, 22)
    wipeButton:SetPoint("TOPLEFT", killButton, "BOTTOMLEFT", 0, -8)
    wipeButton:SetScript("OnClick", function()
        Goals.Dev:SimulateWipe()
    end)

    local lootButton = createButton(parent, L.DEV_SIM_LOOT, 160, 22)
    lootButton:SetPoint("TOPLEFT", wipeButton, "BOTTOMLEFT", 0, -8)
    lootButton:SetScript("OnClick", function()
        Goals.Dev:SimulateLoot()
    end)

    local debugButton = createButton(parent, L.DEV_TOGGLE_DEBUG, 160, 22)
    debugButton:SetPoint("TOPLEFT", lootButton, "BOTTOMLEFT", 0, -8)
    debugButton:SetScript("OnClick", function()
        Goals.Dev:ToggleDebug()
        UI:Refresh()
    end)
end

function UI:CreateMinimapButton()
    local button = CreateFrame("Button", "GoalsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_01")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            UI:UpdateMinimapPosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Goals")
        GameTooltip:AddLine("Click to toggle UI.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.minimapButton = button
    self:UpdateMinimapButton()
end

function UI:UpdateMinimapPosition()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    x = x / scale
    y = y / scale
    local mx, my = Minimap:GetCenter()
    local angle = math.deg(math.atan2(y - my, x - mx))
    Goals.db.settings.minimap.angle = angle
    self:UpdateMinimapButton()
end

function UI:UpdateMinimapButton()
    local button = self.minimapButton
    if not button then
        return
    end
    if Goals.db.settings.minimap.hide then
        button:Hide()
        return
    end
    local angle = Goals.db.settings.minimap.angle or 220
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    button:Show()
end

function UI:CreateFloatingButton()
    local button = createButton(UIParent, "Goals", 80, 22)
    button:SetPoint("CENTER", UIParent, "CENTER", Goals.db.settings.floatingButton.x, Goals.db.settings.floatingButton.y)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        Goals.db.settings.floatingButton.x = math.floor(x - parentX)
        Goals.db.settings.floatingButton.y = math.floor(y - parentY)
    end)
    button:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)
    self.floatingButton = button
end

function UI:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "GoalsOptionsPanel")
    panel.name = "Goals"
    local title = createLabel(panel, "Goals", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local description = createLabel(panel, "Open the Goals dashboard or configure display options.", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    local openButton = createButton(panel, L.BUTTON_OPEN, 120, 22)
    openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
    openButton:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)
    InterfaceOptions_AddCategory(panel)
end

function UI:GetSortedPlayers()
    local list = {}
    for name, data in pairs(Goals.db.players) do
        table.insert(list, {
            name = name,
            points = data.points or 0,
            class = data.class,
        })
    end
    table.sort(list, function(a, b)
        if a.points == b.points then
            return a.name < b.name
        end
        return a.points > b.points
    end)
    return list
end

function UI:UpdateRosterList()
    if not self.rosterScroll then
        return
    end
    local data = self:GetSortedPlayers()
    FauxScrollFrame_Update(self.rosterScroll, #data, #self.rosterRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.rosterScroll)
    for i, row in ipairs(self.rosterRows) do
        local index = i + offset
        local entry = data[index]
        if entry then
            row:Show()
            row.name:SetText(entry.name)
            row.points:SetText(entry.points)
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class] or nil
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(0.9, 0.9, 0.9)
            end
        else
            row:Hide()
        end
    end
end

function UI:UpdateHistoryList()
    if not self.historyScroll then
        return
    end
    local history = Goals.db.history or {}
    FauxScrollFrame_Update(self.historyScroll, #history, #self.historyRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.historyScroll)
    for i, row in ipairs(self.historyRows) do
        local index = i + offset
        local entry = history[index]
        if entry then
            row:Show()
            row.time:SetText(formatTime(entry.ts))
            row.text:SetText(entry.text or "")
        else
            row:Hide()
        end
    end
end

function UI:RefreshStatus()
    if self.syncStatus then
        self.syncStatus:SetText(Goals.sync.status or "Unknown")
    end
    if self.disenchanterLabel then
        local name = Goals.db.settings.disenchanter or "None"
        self.disenchanterLabel:SetText(L.LABEL_DISENCHANTER .. ": " .. name)
    end
end

function UI:Refresh()
    if not self.frame then
        return
    end
    self:RefreshStatus()
    if self.combineCheck then
        self.combineCheck:SetChecked(Goals.db.settings.combineBossHistory and 1 or 0)
        if Goals:HasLeaderAccess() then
            self.combineCheck:Enable()
        else
            self.combineCheck:Disable()
        end
    end
    if self.minimapCheck then
        self.minimapCheck:SetChecked(Goals.db.settings.minimap.hide and 0 or 1)
    end
    if self.disenchanterBox then
        self.disenchanterBox:SetText(Goals.db.settings.disenchanter or "")
    end
    if self.disenchanterButton then
        if Goals:HasLeaderAccess() then
            self.disenchanterButton:Enable()
        else
            self.disenchanterButton:Disable()
        end
    end
    if self.debugCheck then
        self.debugCheck:SetChecked(Goals.db.settings.debug and 1 or 0)
    end
    if self.adjustAddButton then
        if Goals:HasLeaderAccess() then
            self.adjustAddButton:Enable()
            self.adjustSetButton:Enable()
        else
            self.adjustAddButton:Disable()
            self.adjustSetButton:Disable()
        end
    end
    if self.lastLootLabel then
        if Goals.state.lastLoot then
            self.lastLootLabel:SetText(
                string.format("%s: %s (%s)", Goals.state.lastLoot.name, Goals.state.lastLoot.link, formatTime(Goals.state.lastLoot.ts))
            )
        else
            self.lastLootLabel:SetText("No loot tracked yet.")
        end
    end
    self:UpdateRosterList()
    self:UpdateHistoryList()
end
