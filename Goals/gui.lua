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
local ROSTER_BUTTON_SIZE = 18

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

function UI:GetAllPlayerNames()
    local names = {}
    for name in pairs(Goals.db.players) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function UI:CreatePlayerDropdown(parent, width, onSelect)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")
    dropdown.onSelect = onSelect
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local options = UI:GetAllPlayerNames()
        for _, name in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function()
                dropdown.selectedValue = name
                UIDropDownMenu_SetText(dropdown, name)
                if dropdown.onSelect then
                    dropdown.onSelect(name)
                end
            end
            info.checked = dropdown.selectedValue == name
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(dropdown, "")
    return dropdown
end

function UI:SyncDropdownSelection(dropdown, selectedName)
    if not dropdown then
        return
    end
    local names = self:GetAllPlayerNames()
    local valid = false
    for _, name in ipairs(names) do
        if name == selectedName then
            valid = true
            break
        end
    end
    if valid then
        dropdown.selectedValue = selectedName
        UIDropDownMenu_SetText(dropdown, selectedName)
    elseif dropdown.selectedValue and dropdown.selectedValue ~= "" then
        dropdown.selectedValue = nil
        UIDropDownMenu_SetText(dropdown, "")
    end
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

function UI:ShowFloatingButton(show)
    if not self.floatingButton then
        return
    end
    Goals.db.settings.floatingButton.show = show and true or false
    if Goals.db.settings.floatingButton.show then
        self.floatingButton:Show()
    else
        self.floatingButton:Hide()
    end
end

function UI:Minimize()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
    self:ShowFloatingButton(true)
end

function UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:ShowFloatingButton(false)
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
    frame:SetScript("OnShow", function()
        UI:ShowFloatingButton(false)
    end)
    frame:Hide()

    local title = createLabel(frame, L.TITLE, "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    local minimizeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    minimizeButton:SetSize(20, 20)
    minimizeButton:SetText("-")
    if frame.CloseButton then
        minimizeButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", -4, 0)
        minimizeButton:SetPoint("TOP", frame.CloseButton, "TOP", 0, 0)
    else
        minimizeButton:SetPoint("TOPRIGHT", -32, -6)
    end
    minimizeButton:SetScript("OnClick", function()
        UI:Minimize()
    end)
    minimizeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.BUTTON_MINIMIZE or "Minimize")
        GameTooltip:Show()
    end)
    minimizeButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 7)
        else
            tab:SetPoint("LEFT", self.tabs[i - 1], "RIGHT", -12, 0)
        end
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

    local filterFrame = CreateFrame("Frame", nil, parent)
    filterFrame:SetSize(420, 26)
    filterFrame:SetPoint("TOPLEFT", 6, -36)

    local sortLabel = createLabel(filterFrame, L.LABEL_SORT, "GameFontHighlightSmall")
    sortLabel:SetPoint("LEFT", 0, 0)
    local sortDropDown = CreateFrame("Frame", nil, filterFrame, "UIDropDownMenuTemplate")
    sortDropDown:SetPoint("LEFT", sortLabel, "RIGHT", -6, -4)
    UIDropDownMenu_SetWidth(sortDropDown, 100)
    UIDropDownMenu_JustifyText(sortDropDown, "LEFT")
    UIDropDownMenu_Initialize(sortDropDown, function(_, level)
        local options = {
            { value = "POINTS", text = L.SORT_POINTS },
            { value = "ALPHA", text = L.SORT_ALPHA },
            { value = "PRESENCE", text = L.SORT_PRESENCE },
        }
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.checked = Goals.db.settings.sortMode == option.value
            info.func = function()
                Goals.db.settings.sortMode = option.value
                UIDropDownMenu_SetText(sortDropDown, option.text)
                UI:UpdateRosterList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.sortDropDown = sortDropDown

    local presentCheck = CreateFrame("CheckButton", "GoalsPresentOnlyCheck", filterFrame, "UICheckButtonTemplate")
    presentCheck:SetPoint("LEFT", sortDropDown, "RIGHT", 12, 2)
    _G[presentCheck:GetName() .. "Text"]:SetText(L.CHECK_PRESENT_ONLY)
    presentCheck:SetScript("OnClick", function(self)
        Goals.db.settings.showPresentOnly = self:GetChecked() == 1
        UI:UpdateRosterList()
    end)
    self.presentOnlyCheck = presentCheck

    local rosterFrame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    rosterFrame:SetSize(420, 330)
    rosterFrame:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -6)
    local rosterTitle = createLabel(parent, L.LABEL_POINTS, "GameFontNormal")
    rosterTitle:SetPoint("BOTTOMLEFT", rosterFrame, "TOPLEFT", 4, 4)

    local scroll = CreateFrame("ScrollFrame", "GoalsRosterScroll", rosterFrame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, ROW_HEIGHT, function()
            UI:UpdateRosterList()
        end)
    end)
    self.rosterScroll = scroll
    self.rosterRows = {}
    for i = 1, ROSTER_ROWS do
        local row = CreateFrame("Frame", nil, rosterFrame)
        row:SetSize(380, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 8, -((i - 1) * ROW_HEIGHT) - 2)
        row.statusIcon = row:CreateTexture(nil, "ARTWORK")
        row.statusIcon:SetSize(10, 10)
        row.statusIcon:SetPoint("LEFT", 2, 0)
        row.name = createLabel(row, "", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.statusIcon, "RIGHT", 6, 0)
        row.points = createLabel(row, "", "GameFontHighlightSmall")
        row.points:SetPoint("RIGHT", -90, 0)
        row.plus = createButton(row, "+", ROSTER_BUTTON_SIZE, ROSTER_BUTTON_SIZE)
        row.minus = createButton(row, "-", ROSTER_BUTTON_SIZE, ROSTER_BUTTON_SIZE)
        row.reset = createButton(row, "0", ROSTER_BUTTON_SIZE, ROSTER_BUTTON_SIZE)
        row.undo = createButton(row, "U", ROSTER_BUTTON_SIZE, ROSTER_BUTTON_SIZE)
        row.plus:GetFontString():SetFontObject("GameFontHighlightSmall")
        row.minus:GetFontString():SetFontObject("GameFontHighlightSmall")
        row.reset:GetFontString():SetFontObject("GameFontHighlightSmall")
        row.undo:GetFontString():SetFontObject("GameFontHighlightSmall")
        row.undo:SetPoint("RIGHT", -2, 0)
        row.reset:SetPoint("RIGHT", row.undo, "LEFT", -2, 0)
        row.minus:SetPoint("RIGHT", row.reset, "LEFT", -2, 0)
        row.plus:SetPoint("RIGHT", row.minus, "LEFT", -2, 0)
        row.plus:SetScript("OnClick", function(self)
            if not Goals:HasLeaderAccess() then
                return
            end
            if self.playerName then
                Goals:AdjustPoints(self.playerName, 1, "Roster +1")
            end
        end)
        row.minus:SetScript("OnClick", function(self)
            if not Goals:HasLeaderAccess() then
                return
            end
            if self.playerName then
                Goals:AdjustPoints(self.playerName, -1, "Roster -1")
            end
        end)
        row.reset:SetScript("OnClick", function(self)
            if not Goals:HasLeaderAccess() then
                return
            end
            if self.playerName then
                Goals:SetPoints(self.playerName, 0, "Roster reset")
            end
        end)
        row.undo:SetScript("OnClick", function(self)
            if not Goals:HasLeaderAccess() then
                return
            end
            if self.playerName then
                Goals:UndoPoints(self.playerName)
            end
        end)
        row.undo:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(L.BUTTON_UNDO or "Undo")
            GameTooltip:Show()
        end)
        row.undo:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.rosterRows[i] = row
    end

    local statusFrame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    statusFrame:SetSize(300, 120)
    statusFrame:SetPoint("TOPLEFT", rosterFrame, "TOPRIGHT", 12, 0)
    local statusTitle = createLabel(statusFrame, L.LABEL_SYNC, "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", 8, -8)
    self.syncStatus = createLabel(statusFrame, "", "GameFontHighlight")
    self.syncStatus:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -6)
    self.disenchanterLabel = createLabel(statusFrame, "", "GameFontHighlight")
    self.disenchanterLabel:SetPoint("TOPLEFT", self.syncStatus, "BOTTOMLEFT", 0, -6)

    local manualFrame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    manualFrame:SetSize(300, 220)
    manualFrame:SetPoint("TOPLEFT", statusFrame, "BOTTOMLEFT", 0, -12)
    local manualTitle = createLabel(manualFrame, L.LABEL_MANUAL, "GameFontNormal")
    manualTitle:SetPoint("TOPLEFT", 8, -8)

    local nameLabel = createLabel(manualFrame, L.LABEL_PLAYER, "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", manualTitle, "BOTTOMLEFT", 0, -8)
    local nameDropDown = self:CreatePlayerDropdown(manualFrame, 140, function(name)
        UI.adjustSelectedName = name
    end)
    nameDropDown:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", -16, -6)
    self.adjustNameDropDown = nameDropDown

    local amountLabel = createLabel(manualFrame, L.LABEL_AMOUNT, "GameFontHighlightSmall")
    amountLabel:SetPoint("LEFT", nameDropDown, "RIGHT", 10, 4)
    local amountBox = CreateFrame("EditBox", nil, manualFrame, "InputBoxTemplate")
    amountBox:SetSize(60, 20)
    amountBox:SetPoint("TOPLEFT", amountLabel, "BOTTOMLEFT", -2, -4)
    amountBox:SetAutoFocus(false)
    amountBox:SetNumeric(true)
    amountBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    self.adjustAmountBox = amountBox

    local addButton = createButton(manualFrame, L.BUTTON_ADD, 80, 22)
    addButton:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -46)
    addButton:SetScript("OnClick", function()
        if not Goals:HasLeaderAccess() then
            return
        end
        local name = UI.adjustSelectedName or (UI.adjustNameDropDown and UI.adjustNameDropDown.selectedValue)
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
        local name = UI.adjustSelectedName or (UI.adjustNameDropDown and UI.adjustNameDropDown.selectedValue)
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

    local infoFrame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    infoFrame:SetSize(700, 120)
    infoFrame:SetPoint("TOPLEFT", 6, -36)
    local infoLabel = createLabel(infoFrame, L.LABEL_LAST_LOOT, "GameFontNormal")
    infoLabel:SetPoint("TOPLEFT", 10, -10)
    self.lastLootLabel = createLabel(infoFrame, "", "GameFontHighlight")
    self.lastLootLabel:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -6)

    local assignFrame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    assignFrame:SetSize(700, 200)
    assignFrame:SetPoint("TOPLEFT", infoFrame, "BOTTOMLEFT", 0, -12)
    local assignLabel = createLabel(assignFrame, L.LABEL_ASSIGN_LOOT, "GameFontNormal")
    assignLabel:SetPoint("TOPLEFT", 10, -10)

    local playerLabel = createLabel(assignFrame, L.LABEL_PLAYER, "GameFontHighlightSmall")
    playerLabel:SetPoint("TOPLEFT", assignLabel, "BOTTOMLEFT", 0, -8)
    local playerDropDown = self:CreatePlayerDropdown(assignFrame, 160, function(name)
        UI.assignSelectedName = name
    end)
    playerDropDown:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", -16, -6)
    self.assignPlayerDropDown = playerDropDown

    local itemLabel = createLabel(assignFrame, L.LABEL_ITEM, "GameFontHighlightSmall")
    itemLabel:SetPoint("LEFT", playerDropDown, "RIGHT", 14, 4)
    local itemBox = CreateFrame("EditBox", nil, assignFrame, "InputBoxTemplate")
    itemBox:SetSize(360, 20)
    itemBox:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", -2, -4)
    itemBox:SetAutoFocus(false)
    itemBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    self.assignItemBox = itemBox

    local assignButton = createButton(assignFrame, L.BUTTON_ASSIGN, 120, 22)
    assignButton:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", 0, -46)
    assignButton:SetScript("OnClick", function()
        if not Goals:HasLeaderAccess() then
            return
        end
        local name = UI.assignSelectedName or (UI.assignPlayerDropDown and UI.assignPlayerDropDown.selectedValue)
        local itemLink = itemBox:GetText()
        if name ~= "" and itemLink ~= "" then
            Goals:HandleLoot(name, itemLink)
        end
    end)
    self.assignButton = assignButton
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

    local settingsFrame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    settingsFrame:SetSize(700, 360)
    settingsFrame:SetPoint("TOPLEFT", 6, -36)

    local combineCheck = CreateFrame("CheckButton", "GoalsCombineHistoryCheck", settingsFrame, "UICheckButtonTemplate")
    combineCheck:SetPoint("TOPLEFT", 10, -10)
    _G[combineCheck:GetName() .. "Text"]:SetText(L.CHECK_COMBINE_HISTORY)
    combineCheck:SetScript("OnClick", function(self)
        if not Goals:HasLeaderAccess() then
            self:SetChecked(Goals.db.settings.combineBossHistory)
            return
        end
        Goals:SetRaidSetting("combineBossHistory", self:GetChecked() == 1)
    end)
    self.combineCheck = combineCheck

    local minimapCheck = CreateFrame("CheckButton", "GoalsMinimapCheck", settingsFrame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combineCheck, "BOTTOMLEFT", 0, -6)
    _G[minimapCheck:GetName() .. "Text"]:SetText(L.CHECK_MINIMAP)
    minimapCheck:SetScript("OnClick", function(self)
        Goals.db.settings.minimap.hide = self:GetChecked() ~= 1
        UI:UpdateMinimapButton()
    end)
    self.minimapCheck = minimapCheck

    local disenchantLabel = createLabel(settingsFrame, L.LABEL_DISENCHANTER, "GameFontNormal")
    disenchantLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -12)
    local disenchantBox = CreateFrame("EditBox", nil, settingsFrame, "InputBoxTemplate")
    disenchantBox:SetSize(160, 20)
    disenchantBox:SetPoint("TOPLEFT", disenchantLabel, "BOTTOMLEFT", -2, -4)
    disenchantBox:SetAutoFocus(false)
    self.disenchanterBox = disenchantBox
    local disenchantButton = createButton(settingsFrame, L.SETTINGS_DISENCHANTER, 150, 22)
    disenchantButton:SetPoint("LEFT", disenchantBox, "RIGHT", 10, 0)
    disenchantButton:SetScript("OnClick", function()
        if not Goals:HasLeaderAccess() then
            return
        end
        Goals:SetDisenchanter(disenchantBox:GetText())
    end)
    self.disenchanterButton = disenchantButton

    if Goals.Dev and Goals.Dev.enabled then
        local debugCheck = CreateFrame("CheckButton", "GoalsDebugCheck", settingsFrame, "UICheckButtonTemplate")
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
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("CENTER", 0, 0)
    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetSize(22, 22)
    button.background:SetPoint("CENTER", 0, 0)
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetAllPoints()
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAllPoints()
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
    self:ShowFloatingButton(Goals.db.settings.floatingButton.show)
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
    local presentMap = Goals:GetPresenceMap()
    local showPresentOnly = Goals.db.settings.showPresentOnly
    for name, data in pairs(Goals.db.players) do
        local isPresent = presentMap[name] == true
        if not showPresentOnly or isPresent then
            table.insert(list, {
                name = name,
                points = data.points or 0,
                class = data.class,
                present = isPresent,
            })
        end
    end
    local sortMode = Goals.db.settings.sortMode or "POINTS"
    table.sort(list, function(a, b)
        if sortMode == "ALPHA" then
            return a.name < b.name
        end
        if sortMode == "PRESENCE" then
            if a.present ~= b.present then
                return a.present and not b.present
            end
            if a.points == b.points then
                return a.name < b.name
            end
            return a.points > b.points
        end
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
            row.playerName = entry.name
            row.name:SetText(entry.name)
            row.points:SetText(entry.points)
            if entry.present then
                row.statusIcon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
            else
                row.statusIcon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
            end
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class] or nil
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(0.9, 0.9, 0.9)
            end
            row.name:SetAlpha(entry.present and 1 or 0.6)
            local canEdit = Goals:HasLeaderAccess()
            if canEdit then
                row.plus:Enable()
                row.minus:Enable()
                row.reset:Enable()
            else
                row.plus:Disable()
                row.minus:Disable()
                row.reset:Disable()
            end
            local undoPoints = Goals:GetUndoPoints(entry.name)
            if canEdit and undoPoints ~= nil then
                row.undo:Enable()
            else
                row.undo:Disable()
            end
        else
            row:Hide()
            row.playerName = nil
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
    if self.presentOnlyCheck then
        self.presentOnlyCheck:SetChecked(Goals.db.settings.showPresentOnly and 1 or 0)
    end
    if self.sortDropDown then
        local sortMode = Goals.db.settings.sortMode or "POINTS"
        local label = L.SORT_POINTS
        if sortMode == "ALPHA" then
            label = L.SORT_ALPHA
        elseif sortMode == "PRESENCE" then
            label = L.SORT_PRESENCE
        end
        UIDropDownMenu_SetText(self.sortDropDown, label)
    end
    if self.adjustNameDropDown then
        self:SyncDropdownSelection(self.adjustNameDropDown, self.adjustSelectedName)
    end
    if self.assignPlayerDropDown then
        self:SyncDropdownSelection(self.assignPlayerDropDown, self.assignSelectedName)
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
    if self.assignButton then
        if Goals:HasLeaderAccess() then
            self.assignButton:Enable()
        else
            self.assignButton:Disable()
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
