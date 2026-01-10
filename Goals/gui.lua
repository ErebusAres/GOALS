-- Goals: gui.lua
-- UI implementation and layout helpers.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.UI = Goals.UI or {}
local UI = Goals.UI
local L = Goals.L

local ROW_HEIGHT = 20
local ROSTER_ROWS = 12
local HISTORY_ROWS = 18
local LOOT_HISTORY_ROWS = 16
local LOOT_HISTORY_ROW_HEIGHT = 28
local LOOT_HISTORY_ROW_HEIGHT_COMPACT = 20
local LOOT_ROWS = 18

local function createLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetText(text or "")
    return label
end

local function setCheckText(check, text)
    if not check then
        return
    end
    local label = check.Text
    if not label then
        local name = check:GetName()
        if name then
            label = _G[name .. "Text"]
        end
    end
    if not label then
        label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        check.Text = label
    end
    if label then
        label:SetText(text or "")
    end
end

local function getDropDownPart(dropdown, part)
    if dropdown[part] then
        return dropdown[part]
    end
    local name = dropdown:GetName()
    if name then
        return _G[name .. part]
    end
    return nil
end

local function colorizeName(name)
    if Goals and Goals.ColorizeName then
        return Goals:ColorizeName(name)
    end
    return name
end

local function hasModifyAccess()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    if not Goals or not Goals.IsGroupLeader then
        return false
    end
    local inRaid = Goals.IsInRaid and Goals:IsInRaid()
    local inParty = Goals.IsInParty and Goals:IsInParty()
    return (inRaid or inParty) and Goals:IsGroupLeader()
end

local function setDropdownEnabled(dropdown, enabled)
    if not dropdown then
        return
    end
    if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
        if enabled then
            UIDropDownMenu_EnableDropDown(dropdown)
        else
            UIDropDownMenu_DisableDropDown(dropdown)
        end
        return
    end
    if enabled then
        if dropdown.Enable then
            dropdown:Enable()
        end
    else
        if dropdown.Disable then
            dropdown:Disable()
        end
    end
end

local function styleDropdown(dropdown, width)
    UIDropDownMenu_SetWidth(dropdown, width or 120)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")
    local left = getDropDownPart(dropdown, "Left")
    local middle = getDropDownPart(dropdown, "Middle")
    local right = getDropDownPart(dropdown, "Right")
    if left then
        left:Hide()
    end
    if middle then
        middle:Hide()
    end
    if right then
        right:Hide()
    end
    local button = getDropDownPart(dropdown, "Button")
    if button then
        button:ClearAllPoints()
        button:SetPoint("RIGHT", dropdown, "RIGHT", -2, 0)
    end
end

local function formatTime(ts)
    return date("%H:%M:%S", ts or time())
end

function UI:GetAllPlayerNames()
    local names = {}
    if Goals.db and Goals.db.players then
        for name in pairs(Goals.db.players) do
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function UI:GetPresentPlayerNames()
    local present = Goals:GetPresenceMap()
    local names = {}
    for name in pairs(present) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function UI:GetDisenchanterCandidates()
    local list = self:GetPresentPlayerNames()
    table.insert(list, 1, L.NONE_OPTION)
    return list
end

function UI:GetDisenchanterStatus()
    local current = Goals.db and Goals.db.settings and Goals.db.settings.disenchanter or ""
    if current == "" then
        return "None set"
    end
    local present = Goals:GetPresenceMap()
    if not present[current] then
        return "Not present"
    end
    return colorizeName(current)
end

function UI:GetSortedPlayers()
    local list = {}
    if not Goals.db or not Goals.db.players then
        return list
    end
    local present = Goals:GetPresenceMap()
    local showPresentOnly = Goals.db.settings and Goals.db.settings.showPresentOnly
    for name, data in pairs(Goals.db.players) do
        local isPresent = present[name] or false
        if not showPresentOnly or isPresent then
            table.insert(list, {
                name = name,
                points = data.points or 0,
                class = data.class,
                present = isPresent,
            })
        end
    end
    local mode = (Goals.db.settings and Goals.db.settings.sortMode) or "POINTS"
    table.sort(list, function(a, b)
        if mode == "ALPHA" then
            return a.name < b.name
        end
        if mode == "PRESENCE" then
            if a.present ~= b.present then
                return a.present and not b.present
            end
            if a.points ~= b.points then
                return a.points > b.points
            end
            return a.name < b.name
        end
        if a.points ~= b.points then
            return a.points > b.points
        end
        return a.name < b.name
    end)
    return list
end

function UI:GetLootHistoryEntries()
    local list = {}
    if not Goals.db or not Goals.db.history then
        return list
    end
    local epicOnly = Goals.db.settings and Goals.db.settings.lootHistoryEpicOnly
    for _, entry in ipairs(Goals.db.history) do
        if entry.kind == "LOOT_FOUND" or entry.kind == "LOOT_ASSIGN" then
            if epicOnly then
                local itemLink = entry.data and entry.data.item or nil
                if itemLink and GetItemInfo then
                    local quality = select(3, GetItemInfo(itemLink))
                    if quality and quality < 4 then
                        entry = nil
                    end
                end
            end
            if entry then
                table.insert(list, entry)
            end
        end
    end
    return list
end

function UI:SetupDropdown(dropdown, getList, onSelect, fallbackText)
    dropdown.getList = getList
    dropdown.onSelect = onSelect
    dropdown.fallbackText = fallbackText or L.SELECT_OPTION
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local list = dropdown.getList and dropdown.getList() or {}
        local info
        if #list == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = L.LABEL_NO_PLAYERS
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for _, name in ipairs(list) do
            info = UIDropDownMenu_CreateInfo()
            if dropdown.colorize and name ~= L.NONE_OPTION then
                info.text = colorizeName(name)
            else
                info.text = name
            end
            info.value = name
            info.func = function()
                dropdown.selectedValue = name
                UIDropDownMenu_SetSelectedValue(dropdown, name)
                if dropdown.colorize and name ~= L.NONE_OPTION then
                    UIDropDownMenu_SetText(dropdown, colorizeName(name))
                else
                    UIDropDownMenu_SetText(dropdown, name)
                end
                if dropdown.onSelect then
                    dropdown.onSelect(name)
                end
            end
            info.checked = dropdown.selectedValue == name
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function UI:SetDropdownText(dropdown, text)
    local value = text or dropdown.fallbackText or L.SELECT_OPTION
    if dropdown.colorize and value ~= L.NONE_OPTION and value ~= dropdown.fallbackText then
        UIDropDownMenu_SetText(dropdown, colorizeName(value))
    else
        UIDropDownMenu_SetText(dropdown, value)
    end
end

function UI:SetupSortDropdown(dropdown)
    self.sortOptions = {
        { text = L.SORT_POINTS, value = "POINTS" },
        { text = L.SORT_ALPHA, value = "ALPHA" },
        { text = L.SORT_PRESENCE, value = "PRESENCE" },
    }
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(self.sortOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                Goals.db.settings.sortMode = option.value
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                UIDropDownMenu_SetText(dropdown, option.text)
                Goals:NotifyDataChanged()
            end
            info.checked = Goals.db.settings.sortMode == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self:SyncSortDropdown()
end

function UI:SyncSortDropdown()
    if not self.sortDropdown then
        return
    end
    local selected = Goals.db.settings.sortMode or "POINTS"
    local text = L.SORT_POINTS
    if self.sortOptions then
        for _, option in ipairs(self.sortOptions) do
            if option.value == selected then
                text = option.text
                break
            end
        end
    end
    UIDropDownMenu_SetSelectedValue(self.sortDropdown, selected)
    UIDropDownMenu_SetText(self.sortDropdown, text)
end

function UI:Init()
    if self.frame then
        return
    end
    self:CreateMainFrame()
    self:CreateMinimapButton()
    self:CreateFloatingButton()
    self:CreateOptionsPanel()
    self:UpdateMinimapButton()
    self:Refresh()
end

function UI:Toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
        if Goals.db and Goals.db.settings and Goals.db.settings.floatingButton and Goals.db.settings.floatingButton.show then
            self:ShowFloatingButton(true)
        end
        return
    end
    self.frame:Show()
    self:ShowFloatingButton(false)
    self:Refresh()
end

function UI:Minimize()
    if not self.frame then
        return
    end
    self.frame:Hide()
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

function UI:CreateMainFrame()
    if self.frame then
        return
    end
    local frame = CreateFrame("Frame", "GoalsMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:Hide()
    end
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetText(L.TITLE)
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -6)
    titleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -70, -6)
    titleText:SetJustifyH("LEFT")
    frame.titleText = titleText

    local close = _G[frame:GetName() .. "CloseButton"]
    if close then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 5)
    end

    local minimize = CreateFrame("Button", nil, frame)
    if close then
        minimize:SetSize(close:GetWidth(), close:GetHeight())
        minimize:SetFrameLevel(close:GetFrameLevel())
    else
        minimize:SetSize(24, 24)
    end
    local normal = minimize:CreateTexture(nil, "ARTWORK")
    normal:SetTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    normal:SetAllPoints(minimize)
    minimize:SetNormalTexture(normal)
    local pushed = minimize:CreateTexture(nil, "ARTWORK")
    pushed:SetTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    pushed:SetAllPoints(minimize)
    minimize:SetPushedTexture(pushed)
    local highlight = minimize:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Panel-HideButton-Highlight")
    highlight:SetAllPoints(minimize)
    minimize:SetHighlightTexture(highlight)
    if close then
        minimize:ClearAllPoints()
        minimize:SetPoint("TOPRIGHT", close, "TOPLEFT", 7, 0)
    else
        minimize:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -5)
    end
    minimize:SetScript("OnClick", function()
        UI:Minimize()
    end)
    frame.minimize = minimize

    self.frame = frame
    self.tabs = {}
    self.pages = {}

    local tabDefs = {
        { key = "overview", text = L.TAB_OVERVIEW, create = "CreateOverviewTab" },
        { key = "loot", text = L.TAB_LOOT, create = "CreateLootTab" },
        { key = "history", text = L.TAB_HISTORY, create = "CreateHistoryTab" },
        { key = "settings", text = L.TAB_SETTINGS, create = "CreateSettingsTab" },
    }
    if Goals.Dev and Goals.Dev.enabled then
        table.insert(tabDefs, { key = "dev", text = L.TAB_DEV, create = "CreateDevTab" })
        table.insert(tabDefs, { key = "debug", text = L.TAB_DEBUG, create = "CreateDebugTab" })
    end

    for i, def in ipairs(tabDefs) do
        local tabName = frame:GetName() .. "Tab" .. i
        local tab = CreateFrame("Button", tabName, frame, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(def.text)
        PanelTemplates_TabResize(tab, 0)
        tab:SetScript("OnClick", function()
            UI:SelectTab(i)
        end)
        if i == 1 then
            tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, -4)
        else
            tab:SetPoint("LEFT", self.tabs[i - 1], "RIGHT", -12, 0)
        end
        self.tabs[i] = tab

        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -34)
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 26)
        page:Hide()
        self.pages[i] = page

        local createFunc = self[def.create]
        if createFunc then
            createFunc(self, page)
        end
    end

    PanelTemplates_SetNumTabs(frame, #tabDefs)
    PanelTemplates_SetTab(frame, 1)
    self:SelectTab(1)
end

function UI:SelectTab(id)
    if not self.frame or not self.tabs[id] then
        return
    end
    PanelTemplates_SetTab(self.frame, id)
    for index, page in ipairs(self.pages) do
        page:SetShown(index == id)
    end
    self.currentTab = id
    self:Refresh()
end

function UI:CreateOverviewTab(page)
    local sortLabel = createLabel(page, L.LABEL_SORT, "GameFontNormal")
    sortLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -4)

    local sortDrop = CreateFrame("Frame", "GoalsSortDropdown", page, "UIDropDownMenuTemplate")
    sortDrop:SetPoint("LEFT", sortLabel, "RIGHT", -6, 0)
    styleDropdown(sortDrop, 110)
    self.sortDropdown = sortDrop
    self:SetupSortDropdown(sortDrop)

    local presentCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    presentCheck:SetPoint("LEFT", sortDrop, "RIGHT", 12, 1)
    setCheckText(presentCheck, L.CHECK_PRESENT_ONLY)
    presentCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.showPresentOnly = selfBtn:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end)
    self.presentCheck = presentCheck

    local rosterInset = CreateFrame("Frame", "GoalsOverviewRosterInset", page, "InsetFrameTemplate")
    rosterInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -30)
    rosterInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    rosterInset:SetWidth(360)
    self.rosterInset = rosterInset

    local pointsLabel = createLabel(rosterInset, L.LABEL_POINTS, "GameFontNormal")
    pointsLabel:SetPoint("TOPLEFT", rosterInset, "TOPLEFT", 6, -6)

    local rosterScroll = CreateFrame("ScrollFrame", "GoalsRosterScroll", rosterInset, "FauxScrollFrameTemplate")
    rosterScroll:SetPoint("TOPLEFT", rosterInset, "TOPLEFT", 0, -22)
    rosterScroll:SetPoint("BOTTOMRIGHT", rosterInset, "BOTTOMRIGHT", -26, 4)
    rosterScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateRosterList()
        end)
    end)
    self.rosterScroll = rosterScroll

    self.rosterRows = {}
    for i = 1, ROSTER_ROWS do
        local row = CreateFrame("Button", nil, rosterInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", rosterInset, "TOPLEFT", 6, -22 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", rosterInset, "RIGHT", -6, 0)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon

        local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        nameText:SetText("")
        row.nameText = nameText

        local pointsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        pointsText:SetText("0")
        row.pointsText = pointsText

        local add = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        add:SetSize(18, 16)
        add:SetText("+")
        row.add = add

        local sub = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        sub:SetSize(18, 16)
        sub:SetText("-")
        row.sub = sub

        local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        reset:SetSize(18, 16)
        reset:SetText("0")
        row.reset = reset

        local undo = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        undo:SetSize(22, 16)
        undo:SetText("U")
        row.undo = undo

        local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        remove:SetSize(18, 16)
        remove:SetText("X")
        row.remove = remove

        remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        undo:SetPoint("RIGHT", remove, "LEFT", -2, 0)
        reset:SetPoint("RIGHT", undo, "LEFT", -2, 0)
        sub:SetPoint("RIGHT", reset, "LEFT", -2, 0)
        add:SetPoint("RIGHT", sub, "LEFT", -2, 0)
        pointsText:SetPoint("RIGHT", add, "LEFT", -8, 0)

        add:SetScript("OnClick", function()
            if row.playerName then
                Goals:AdjustPoints(row.playerName, 1, "Roster +1")
            end
        end)
        sub:SetScript("OnClick", function()
            if row.playerName then
                Goals:AdjustPoints(row.playerName, -1, "Roster -1")
            end
        end)
        reset:SetScript("OnClick", function()
            if row.playerName then
                Goals:SetPoints(row.playerName, 0, "Roster reset")
            end
        end)
        undo:SetScript("OnClick", function()
            if row.playerName then
                Goals:UndoPoints(row.playerName)
            end
        end)
        remove:SetScript("OnClick", function()
            if row.playerName then
                Goals:RemovePlayer(row.playerName)
            end
        end)

        self.rosterRows[i] = row
    end

    local rightInset = CreateFrame("Frame", "GoalsOverviewRightInset", page, "InsetFrameTemplate")
    rightInset:SetPoint("TOPLEFT", rosterInset, "TOPRIGHT", 12, 0)
    rightInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.overviewRightInset = rightInset

    local syncLabel = createLabel(rightInset, L.LABEL_SYNC, "GameFontNormal")
    syncLabel:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 10, -10)
    local syncValue = createLabel(rightInset, "", "GameFontHighlight")
    syncValue:SetPoint("TOPLEFT", syncLabel, "BOTTOMLEFT", 0, -4)
    self.syncValue = syncValue

    local disLabel = createLabel(rightInset, L.LABEL_DISENCHANTER, "GameFontNormal")
    disLabel:SetPoint("TOPLEFT", syncValue, "BOTTOMLEFT", 0, -10)
    local disValue = createLabel(rightInset, "", "GameFontHighlight")
    disValue:SetPoint("TOPLEFT", disLabel, "BOTTOMLEFT", 0, -4)
    self.disenchantValue = disValue

    local manualTitle = createLabel(rightInset, L.LABEL_MANUAL, "GameFontNormal")
    manualTitle:SetPoint("TOPLEFT", disValue, "BOTTOMLEFT", 0, -18)

    local playerLabel = createLabel(rightInset, L.LABEL_PLAYER, "GameFontNormal")
    playerLabel:SetPoint("TOPLEFT", manualTitle, "BOTTOMLEFT", 0, -10)
    local playerDrop = CreateFrame("Frame", "GoalsManualPlayerDropdown", rightInset, "UIDropDownMenuTemplate")
    playerDrop:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", -10, -2)
    styleDropdown(playerDrop, 140)
    playerDrop.colorize = true
    self.manualPlayerDropdown = playerDrop
    self.manualSelected = nil
    self:SetupDropdown(playerDrop, function()
        return UI:GetAllPlayerNames()
    end, function(name)
        UI.manualSelected = name
    end, L.SELECT_OPTION)

    local amountBox = CreateFrame("EditBox", nil, rightInset, "InputBoxTemplate")
    amountBox:SetSize(60, 20)
    amountBox:SetPoint("TOPLEFT", playerDrop, "TOPRIGHT", 16, -2)
    amountBox:SetAutoFocus(false)
    amountBox:SetNumeric(true)
    amountBox:SetNumber(1)
    amountBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    self.amountBox = amountBox

    local amountLabel = createLabel(rightInset, L.LABEL_AMOUNT, "GameFontNormal")
    amountLabel:SetPoint("BOTTOMLEFT", amountBox, "TOPLEFT", 0, 2)

    local addButton = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
    addButton:SetSize(70, 20)
    addButton:SetText(L.BUTTON_ADD)
    addButton:SetPoint("TOPLEFT", playerDrop, "BOTTOMLEFT", 14, -12)

    local setButton = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
    setButton:SetSize(70, 20)
    setButton:SetText(L.BUTTON_SET)
    setButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)

    local addAllButton = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
    addAllButton:SetSize(80, 20)
    addAllButton:SetText(L.BUTTON_ADD_ALL)
    addAllButton:SetPoint("LEFT", setButton, "RIGHT", 8, 0)

    addButton:SetScript("OnClick", function()
        local name = UI.manualSelected
        local amount = tonumber(amountBox:GetText() or "") or 0
        if name and amount ~= 0 then
            Goals:AdjustPoints(name, amount, "Manual add")
        end
    end)
    setButton:SetScript("OnClick", function()
        local name = UI.manualSelected
        local amount = tonumber(amountBox:GetText() or "") or 0
        if name then
            Goals:SetPoints(name, amount, "Manual set")
        end
    end)
    addAllButton:SetScript("OnClick", function()
        Goals:AwardPresentPoints(1, "Manual group +1")
    end)

    self.manualAddButton = addButton
    self.manualSetButton = setButton
    self.manualAddAllButton = addAllButton
end

function UI:CreateLootTab(page)
    local lootLabel = createLabel(page, L.LABEL_LOOT_METHOD, "GameFontNormal")
    lootLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -6)

    local masterBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    masterBtn:SetSize(150, 20)
    masterBtn:SetText(L.LOOT_METHOD_MASTER)
    masterBtn:SetPoint("LEFT", lootLabel, "RIGHT", 10, 0)

    local groupBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    groupBtn:SetSize(110, 20)
    groupBtn:SetText(L.LOOT_METHOD_GROUP)
    groupBtn:SetPoint("LEFT", masterBtn, "RIGHT", 8, 0)

    local freeBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    freeBtn:SetSize(110, 20)
    freeBtn:SetText(L.LOOT_METHOD_FREE)
    freeBtn:SetPoint("LEFT", groupBtn, "RIGHT", 8, 0)

    local function setLootMethod(method)
        local ok, err = Goals:SetLootMethod(method)
        if not ok and err then
            Goals:Print(err)
        end
    end

    masterBtn:SetScript("OnClick", function()
        setLootMethod("master")
    end)
    groupBtn:SetScript("OnClick", function()
        setLootMethod("group")
    end)
    freeBtn:SetScript("OnClick", function()
        setLootMethod("freeforall")
    end)

    local resetCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    resetCheck:SetPoint("TOPLEFT", lootLabel, "BOTTOMLEFT", 0, -8)
    setCheckText(resetCheck, L.CHECK_RESET_MOUNT_PET)
    resetCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("resetMountPet", selfBtn:GetChecked() and true or false)
    end)
    self.resetMountPetCheck = resetCheck

    local historyInset = CreateFrame("Frame", "GoalsLootHistoryInset", page, "InsetFrameTemplate")
    historyInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -60)
    historyInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    historyInset:SetWidth(350)
    self.lootHistoryInset = historyInset

    local historyLabel = createLabel(historyInset, L.LABEL_LOOT_HISTORY, "GameFontNormal")
    historyLabel:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 6, -6)

    local epicOnlyCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    epicOnlyCheck:SetPoint("LEFT", resetCheck, "RIGHT", 160, 0)
    setCheckText(epicOnlyCheck, L.CHECK_LOOT_EPIC_ONLY)
    epicOnlyCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.lootHistoryEpicOnly = selfBtn:GetChecked() and true or false
        UI:UpdateLootHistoryList()
    end)
    self.lootHistoryEpicCheck = epicOnlyCheck

    local historyScroll = CreateFrame("ScrollFrame", "GoalsLootHistoryScroll", historyInset, "FauxScrollFrameTemplate")
    historyScroll:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 0, -22)
    historyScroll:SetPoint("BOTTOMRIGHT", historyInset, "BOTTOMRIGHT", -26, 4)
    historyScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, LOOT_HISTORY_ROW_HEIGHT, function()
            UI:UpdateLootHistoryList()
        end)
    end)
    self.lootHistoryScroll = historyScroll

    self.lootHistoryRows = {}
    for i = 1, LOOT_HISTORY_ROWS do
        local row = CreateFrame("Button", nil, historyInset)
        row:SetHeight(LOOT_HISTORY_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 6, -22 - (i - 1) * LOOT_HISTORY_ROW_HEIGHT)
        row:SetPoint("RIGHT", historyInset, "RIGHT", -6, 0)

        local timeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        timeText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        timeText:SetWidth(50)
        timeText:SetJustifyH("LEFT")
        row.timeText = timeText

        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOPLEFT", timeText, "TOPRIGHT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        row.text = text

        local resetText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        resetText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
        resetText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        resetText:SetJustifyH("LEFT")
        resetText:SetWordWrap(false)
        resetText:Hide()
        row.resetText = resetText

        row:SetScript("OnEnter", function(selfRow)
            if selfRow.itemLink then
                GameTooltip:SetOwner(selfRow, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(selfRow.itemLink)
                if IsShiftKeyDown and IsShiftKeyDown() and GameTooltip_ShowCompareItem then
                    GameTooltip_ShowCompareItem(GameTooltip)
                end
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnMouseUp", function(selfRow, button)
            if button == "LeftButton" and selfRow.itemLink then
                if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
                    HandleModifiedItemClick(selfRow.itemLink)
                    return
                end
                if ItemRefTooltip then
                    ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
                    ItemRefTooltip:SetHyperlink(selfRow.itemLink)
                else
                    GameTooltip:SetOwner(selfRow, "ANCHOR_CURSOR")
                    GameTooltip:SetHyperlink(selfRow.itemLink)
                end
            end
        end)

        self.lootHistoryRows[i] = row
    end

    local foundInset = CreateFrame("Frame", "GoalsFoundLootInset", page, "InsetFrameTemplate")
    foundInset:SetPoint("TOPLEFT", historyInset, "TOPRIGHT", 12, 0)
    foundInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)

    local foundLabel = createLabel(foundInset, L.LABEL_FOUND_LOOT, "GameFontNormal")
    foundLabel:SetPoint("TOPLEFT", foundInset, "TOPLEFT", 6, -6)

    local foundHint = createLabel(foundInset, L.LABEL_FOUND_LOOT_HINT, "GameFontHighlightSmall")
    foundHint:SetPoint("TOPLEFT", foundLabel, "BOTTOMLEFT", 0, -2)
    self.foundHintLabel = foundHint

    local foundLocked = createLabel(foundInset, L.LABEL_FOUND_LOOT_LOCKED, "GameFontHighlightSmall")
    foundLocked:SetPoint("TOPLEFT", foundLabel, "BOTTOMLEFT", 0, -2)
    self.foundLockedLabel = foundLocked

    local foundScroll = CreateFrame("ScrollFrame", "GoalsFoundLootScroll", foundInset, "FauxScrollFrameTemplate")
    foundScroll:SetPoint("TOPLEFT", foundInset, "TOPLEFT", 0, -36)
    foundScroll:SetPoint("BOTTOMRIGHT", foundInset, "BOTTOMRIGHT", -26, 4)
    foundScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateFoundLootList()
        end)
    end)
    self.foundLootScroll = foundScroll

    self.foundLootRows = {}
    for i = 1, LOOT_ROWS do
        local row = CreateFrame("Button", nil, foundInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", foundInset, "TOPLEFT", 6, -36 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", foundInset, "RIGHT", -6, 0)

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.3)
        highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
        row.highlight = highlight
        row:SetHighlightTexture(highlight)

        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        selected:SetBlendMode("ADD")
        selected:SetAlpha(0.7)
        selected:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        selected:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
        selected:Hide()
        row.selected = selected

        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 0, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        row:SetScript("OnMouseUp", function(selfRow, button)
            if button == "RightButton" and selfRow.entry then
                UI:ShowFoundLootMenu(selfRow, selfRow.entry)
            end
        end)

        self.foundLootRows[i] = row
    end
end

function UI:CreateHistoryTab(page)
    local inset = CreateFrame("Frame", "GoalsHistoryInset", page, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.historyInset = inset

    local label = createLabel(inset, L.LABEL_HISTORY, "GameFontNormal")
    label:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)

    local scroll = CreateFrame("ScrollFrame", "GoalsHistoryScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, -22)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 4)
    scroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateHistoryList()
        end)
    end)
    self.historyScroll = scroll

    self.historyRows = {}
    for i = 1, HISTORY_ROWS do
        local row = CreateFrame("Frame", nil, inset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -22 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", inset, "RIGHT", -6, 0)

        local timeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        timeText:SetPoint("LEFT", row, "LEFT", 0, 0)
        timeText:SetWidth(50)
        timeText:SetJustifyH("LEFT")
        row.timeText = timeText

        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", timeText, "RIGHT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        self.historyRows[i] = row
    end
end

function UI:CreateSettingsTab(page)
    local inset = CreateFrame("Frame", "GoalsSettingsInset", page, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.settingsInset = inset

    local combineCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    combineCheck:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -12)
    setCheckText(combineCheck, L.CHECK_COMBINE_HISTORY)
    combineCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("combineBossHistory", selfBtn:GetChecked() and true or false)
    end)
    self.combineCheck = combineCheck

    local minimapCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combineCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(minimapCheck, L.CHECK_MINIMAP)
    minimapCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.minimap.hide = not selfBtn:GetChecked()
        UI:UpdateMinimapButton()
    end)
    self.minimapCheck = minimapCheck

    local disLabel = createLabel(inset, L.SETTINGS_DISENCHANTER, "GameFontNormal")
    disLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -12)

    local disDrop = CreateFrame("Frame", "GoalsDisenchanterDropdown", inset, "UIDropDownMenuTemplate")
    disDrop:SetPoint("TOPLEFT", disLabel, "BOTTOMLEFT", -10, -2)
    styleDropdown(disDrop, 160)
    disDrop.colorize = true
    self.disenchanterDropdown = disDrop
    self:SetupDropdown(disDrop, function()
        return UI:GetDisenchanterCandidates()
    end, function(name)
        if name == L.NONE_OPTION then
            Goals:SetDisenchanter("")
            UI:SetDropdownText(disDrop, L.NONE_OPTION)
            disDrop.selectedValue = ""
            return
        end
        Goals:SetDisenchanter(name)
    end, L.NONE_OPTION)
end

function UI:CreateDevTab(page)
    local inset = CreateFrame("Frame", "GoalsDevInset", page, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)

    local killBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    killBtn:SetSize(160, 20)
    killBtn:SetText(L.DEV_SIM_KILL)
    killBtn:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -12)
    killBtn:SetScript("OnClick", function()
        Goals.Dev:SimulateBossKill()
    end)

    local wipeBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    wipeBtn:SetSize(160, 20)
    wipeBtn:SetText(L.DEV_SIM_WIPE)
    wipeBtn:SetPoint("TOPLEFT", killBtn, "BOTTOMLEFT", 0, -8)
    wipeBtn:SetScript("OnClick", function()
        Goals.Dev:SimulateWipe()
    end)

    local lootBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    lootBtn:SetSize(160, 20)
    lootBtn:SetText(L.DEV_SIM_LOOT)
    lootBtn:SetPoint("TOPLEFT", wipeBtn, "BOTTOMLEFT", 0, -8)
    lootBtn:SetScript("OnClick", function()
        Goals.Dev:SimulateLoot()
    end)

    local syncBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    syncBtn:SetSize(160, 20)
    syncBtn:SetText("Send Sync")
    syncBtn:SetPoint("TOPLEFT", lootBtn, "BOTTOMLEFT", 0, -8)
    syncBtn:SetScript("OnClick", function()
        if Goals.Comm and Goals.Comm.BroadcastFullSync then
            Goals.Comm:BroadcastFullSync()
            Goals:Print("Sync sent.")
        end
    end)

    local devBossCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    devBossCheck:SetPoint("TOPLEFT", syncBtn, "BOTTOMLEFT", 0, -12)
    setCheckText(devBossCheck, L.DEV_TEST_BOSS)
    devBossCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.devTestBoss = selfBtn:GetChecked() and true or false
        if Goals.Events and Goals.Events.BuildBossLookup then
            Goals.Events:BuildBossLookup()
        end
    end)
    self.devBossCheck = devBossCheck
end

function UI:CreateDebugTab(page)
    local inset = CreateFrame("Frame", "GoalsDebugInset", page, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)

    local debugCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -12)
    setCheckText(debugCheck, L.CHECK_DEBUG)
    debugCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("debug", selfBtn:GetChecked() and true or false)
    end)
    self.debugCheck = debugCheck
end

function UI:UpdateRosterList()
    if not self.rosterScroll or not self.rosterRows then
        return
    end
    local data = self:GetSortedPlayers()
    self.rosterData = data
    local offset = FauxScrollFrame_GetOffset(self.rosterScroll) or 0
    FauxScrollFrame_Update(self.rosterScroll, #data, ROSTER_ROWS, ROW_HEIGHT)
    local hasAccess = hasModifyAccess()
    for i = 1, ROSTER_ROWS do
        local row = self.rosterRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            row.playerName = entry.name
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(Goals:GetClassColor(entry.class))
            row.pointsText:SetText(entry.points)
            if entry.present then
                row.icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
            else
                row.icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
            end
            row.icon:SetVertexColor(1, 1, 1)
            row.icon:Show()
            if hasAccess then
                row.add:Show()
                row.sub:Show()
                row.reset:Show()
                row.undo:Show()
                if row.remove then
                    row.remove:Show()
                end
                row.add:Enable()
                row.sub:Enable()
                row.reset:Enable()
                row.undo:Enable()
                if row.remove then
                    row.remove:Enable()
                end
                row.pointsText:ClearAllPoints()
                row.pointsText:SetPoint("RIGHT", row.add, "LEFT", -8, 0)
            else
                row.add:Hide()
                row.sub:Hide()
                row.reset:Hide()
                row.undo:Hide()
                if row.remove then
                    row.remove:Hide()
                end
                row.pointsText:ClearAllPoints()
                row.pointsText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            end
            if Goals:GetUndoPoints(entry.name) == nil then
                row.undo:Disable()
            end
        else
            row:Hide()
            row.playerName = nil
        end
    end
    if self.presentCheck then
        self.presentCheck:SetChecked(Goals.db.settings.showPresentOnly and true or false)
    end
end

function UI:FormatHistoryEntry(entry)
    if not entry then
        return ""
    end
    local data = entry.data or {}
    if entry.kind == "BOSSKILL" and data.player then
        return string.format("%s: %s +%d", data.encounter or "Boss", colorizeName(data.player), data.points or 0)
    end
    if entry.kind == "ADJUST" then
        local delta = data.delta or 0
        local sign = delta >= 0 and "+" or ""
        return string.format("%s: %s%d (%s)", colorizeName(data.player or ""), sign, delta, data.reason or "Adjustment")
    end
    if entry.kind == "SET" then
        return string.format("%s: %d -> %d (%s)", colorizeName(data.player or ""), data.before or 0, data.after or 0, data.reason or "Set points")
    end
    if entry.kind == "LOOT_ASSIGN" then
        local itemLink = data.item or ""
        local quality = itemLink ~= "" and select(3, GetItemInfo(itemLink)) or nil
        if quality and quality < 4 then
            return string.format("%s Looted: %s", colorizeName(data.player or ""), itemLink)
        end
        if data.reset then
            return string.format("Gave %s: %s\n%s DKP Reset.", colorizeName(data.player or ""), itemLink, colorizeName(data.player or ""))
        end
        return string.format("Gave %s: %s", colorizeName(data.player or ""), itemLink)
    end
    if entry.kind == "LOOT_FOUND" then
        return entry.text or ""
    end
    return entry.text or ""
end

function UI:UpdateHistoryList()
    if not self.historyScroll or not self.historyRows then
        return
    end
    local data = Goals.db.history or {}
    local offset = FauxScrollFrame_GetOffset(self.historyScroll) or 0
    FauxScrollFrame_Update(self.historyScroll, #data, HISTORY_ROWS, ROW_HEIGHT)
    for i = 1, HISTORY_ROWS do
        local row = self.historyRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            row.timeText:SetText(formatTime(entry.ts))
            row.text:SetText(self:FormatHistoryEntry(entry))
        else
            row:Hide()
        end
    end
end

function UI:UpdateLootHistoryList()
    if not self.lootHistoryScroll or not self.lootHistoryRows then
        return
    end
    local data = self:GetLootHistoryEntries()
    self.lootHistoryData = data
    local offset = FauxScrollFrame_GetOffset(self.lootHistoryScroll) or 0
    FauxScrollFrame_Update(self.lootHistoryScroll, #data, LOOT_HISTORY_ROWS, LOOT_HISTORY_ROW_HEIGHT_COMPACT)
    local yOffset = -22
    for i = 1, LOOT_HISTORY_ROWS do
        local row = self.lootHistoryRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            row.timeText:SetText(formatTime(entry.ts))
            if entry.kind == "LOOT_ASSIGN" then
                local playerName = colorizeName(entry.data and entry.data.player or "")
                local itemLink = entry.data and entry.data.item or ""
                row.text:SetText(string.format("Gave %s: %s", playerName, itemLink))
                if entry.data and entry.data.reset then
                    row.resetText:SetText(string.format("%s DKP Reset.", playerName))
                    row.resetText:Show()
                    row:SetHeight(LOOT_HISTORY_ROW_HEIGHT)
                else
                    row.resetText:SetText("")
                    row.resetText:Hide()
                    row:SetHeight(LOOT_HISTORY_ROW_HEIGHT_COMPACT)
                end
            else
                row.text:SetText(entry.text or "")
                row.resetText:SetText("")
                row.resetText:Hide()
                row:SetHeight(LOOT_HISTORY_ROW_HEIGHT_COMPACT)
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.lootHistoryInset, "TOPLEFT", 6, yOffset)
            row:SetPoint("RIGHT", self.lootHistoryInset, "RIGHT", -6, 0)
            yOffset = yOffset - row:GetHeight()
            row.itemLink = entry.data and entry.data.item or nil
        else
            row:Hide()
            row.itemLink = nil
            if row.resetText then
                row.resetText:Hide()
            end
        end
    end
end

function UI:UpdateFoundLootList()
    if not self.foundLootScroll or not self.foundLootRows then
        return
    end
    local hasAccess = hasModifyAccess()
    if self.foundHintLabel then
        self.foundHintLabel:SetShown(hasAccess)
    end
    if self.foundLockedLabel then
        self.foundLockedLabel:SetShown(not hasAccess)
    end
    if not hasAccess then
        self.foundLootScroll:Hide()
        for _, row in ipairs(self.foundLootRows) do
            row:Hide()
            row.selected:Hide()
            row.entry = nil
        end
        FauxScrollFrame_Update(self.foundLootScroll, 0, LOOT_ROWS, ROW_HEIGHT)
        return
    end
    self.foundLootScroll:Show()
    local data = Goals:GetFoundLoot() or {}
    self.foundLootData = data
    local offset = FauxScrollFrame_GetOffset(self.foundLootScroll) or 0
    FauxScrollFrame_Update(self.foundLootScroll, #data, LOOT_ROWS, ROW_HEIGHT)
    for i = 1, LOOT_ROWS do
        local row = self.foundLootRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            row.entry = entry
            row.text:SetText(entry.link or "")
            if self.foundSelected == row then
                row.selected:Show()
            else
                row.selected:Hide()
            end
        else
            row:Hide()
            row.entry = nil
            row.selected:Hide()
        end
    end
end

function UI:ShowFoundLootMenu(row, entry)
    if not entry or not hasModifyAccess() then
        return
    end
    self.foundSelected = row
    for _, rowItem in ipairs(self.foundLootRows or {}) do
        rowItem.selected:SetShown(rowItem == row)
    end
    if not self.foundLootMenu then
        self.foundLootMenu = CreateFrame("Frame", "GoalsFoundLootMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = self.foundLootMenu
    UIDropDownMenu_Initialize(menu, function(_, level)
        local players = UI:GetPresentPlayerNames()
        local info
        if #players == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = L.LABEL_NO_PLAYERS
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for _, name in ipairs(players) do
            info = UIDropDownMenu_CreateInfo()
            info.text = colorizeName(name)
            info.value = name
            info.func = function()
                Goals:AssignLootSlot(entry.slot, name, entry.link)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

function UI:RefreshStatus()
    if Goals and Goals.UpdateSyncStatus then
        Goals:UpdateSyncStatus(true)
    end
    if self.syncValue then
        local status = Goals.sync and Goals.sync.status or ""
        if Goals.sync then
            if Goals.sync.isMaster then
                status = "Master (You)"
            elseif Goals.sync.masterName and Goals.sync.masterName ~= "" then
                status = "Following " .. colorizeName(Goals.sync.masterName)
            end
        end
        self.syncValue:SetText(status)
    end
    if self.disenchantValue then
        self.disenchantValue:SetText(self:GetDisenchanterStatus())
    end
end

function UI:Refresh()
    if not self.frame then
        return
    end
    self:RefreshStatus()
    self:SyncSortDropdown()
    if self.manualPlayerDropdown then
        self.manualPlayerDropdown.selectedValue = self.manualSelected
        if self.manualSelected and self.manualSelected ~= "" then
            self:SetDropdownText(self.manualPlayerDropdown, self.manualSelected)
        else
            self:SetDropdownText(self.manualPlayerDropdown, L.SELECT_OPTION)
        end
    end
    if self.disenchanterDropdown then
        local current = Goals.db.settings.disenchanter or ""
        self.disenchanterDropdown.selectedValue = current
        if current ~= "" then
            self:SetDropdownText(self.disenchanterDropdown, current)
        else
            self:SetDropdownText(self.disenchanterDropdown, L.NONE_OPTION)
        end
    end
    if self.combineCheck then
        self.combineCheck:SetChecked(Goals.db.settings.combineBossHistory and true or false)
    end
    if self.minimapCheck then
        self.minimapCheck:SetChecked(not Goals.db.settings.minimap.hide)
    end
    if self.resetMountPetCheck then
        self.resetMountPetCheck:SetChecked(Goals.db.settings.resetMountPet and true or false)
    end
    if self.debugCheck then
        self.debugCheck:SetChecked(Goals.db.settings.debug and true or false)
    end
    if self.lootHistoryEpicCheck then
        self.lootHistoryEpicCheck:SetChecked(Goals.db.settings.lootHistoryEpicOnly and true or false)
    end
    if self.devBossCheck then
        self.devBossCheck:SetChecked(Goals.db.settings.devTestBoss and true or false)
    end
    local hasAccess = hasModifyAccess()
    if self.manualAddButton then
        if hasAccess then
            self.manualAddButton:Enable()
            self.manualSetButton:Enable()
            if self.manualAddAllButton then
                self.manualAddAllButton:Enable()
            end
            if self.manualPlayerDropdown then
                setDropdownEnabled(self.manualPlayerDropdown, true)
            end
            if self.amountBox then
                if self.amountBox.Enable then
                    self.amountBox:Enable()
                end
            end
        else
            self.manualAddButton:Disable()
            self.manualSetButton:Disable()
            if self.manualAddAllButton then
                self.manualAddAllButton:Disable()
            end
            if self.manualPlayerDropdown then
                setDropdownEnabled(self.manualPlayerDropdown, false)
            end
            if self.amountBox then
                if self.amountBox.Disable then
                    self.amountBox:Disable()
                end
            end
        end
    end
    self:UpdateRosterList()
    self:UpdateHistoryList()
    self:UpdateLootHistoryList()
    self:UpdateFoundLootList()
    self:UpdateMinimapButton()
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
            Goals:ToggleUI()
        end
    end)
    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_LEFT")
        GameTooltip:SetText("Goals v2")
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or ""
        local entry = Goals and Goals.db and Goals.db.players and Goals.db.players[playerName] or nil
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
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:Hide()
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

function UI:UpdateMinimapPositionFromCursor()
    if not self.minimapButton then
        return
    end
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    x = x / scale
    y = y / scale
    local mx, my = Minimap:GetCenter()
    local dx = x - mx
    local dy = y - my
    local angle = math.deg(math.atan2(dy, dx))
    Goals.db.settings.minimap.angle = angle
    self:UpdateMinimapPosition()
end

function UI:UpdateMinimapPosition()
    if not self.minimapButton then
        return
    end
    local angle = Goals.db.settings.minimap.angle or 220
    local radius = (Minimap:GetWidth() / 2) + 8
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function UI:UpdateMinimapButton()
    if not self.minimapButton or not Goals.db or not Goals.db.settings then
        return
    end
    if Goals.db.settings.minimap.hide then
        self.minimapButton:Hide()
        return
    end
    self.minimapButton:Show()
    self:UpdateMinimapPosition()
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

function UI:UpdateFloatingPosition()
    if not self.floatingButton or not Goals.db or not Goals.db.settings then
        return
    end
    local pos = Goals.db.settings.floatingButton or { x = 0, y = 0 }
    self.floatingButton:ClearAllPoints()
    self.floatingButton:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
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
