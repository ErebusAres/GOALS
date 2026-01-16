-- Goals: gui.lua
-- UI implementation and layout helpers.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.UI = Goals.UI or {}
local UI = Goals.UI
local L = Goals.L

local ROW_HEIGHT = 20
local ROSTER_ROWS = 20
local HISTORY_ROWS = 17
local HISTORY_ROW_HEIGHT_DOUBLE = 26
local LOOT_HISTORY_ROWS = 15
local DEBUG_ROWS = 16
local DEBUG_ROW_HEIGHT = 16
local MINI_ROW_HEIGHT = 16
local MINI_HEADER_HEIGHT = 22
local MINI_FRAME_WIDTH = 200
local MINI_DEFAULT_X = 260
local MINI_DEFAULT_Y = 0
local LOOT_HISTORY_ROW_HEIGHT = 28
local LOOT_HISTORY_ROW_HEIGHT_COMPACT = 20
local LOOT_ROWS = 18
local WISHLIST_SLOT_SIZE = 36
local WISHLIST_ROW_SPACING = 46

local function createLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetText(text or "")
    return label
end

local function bindEscapeClear(editBox)
    if not editBox then
        return
    end
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
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

local classColorList = nil
local function getClassColorList()
    if classColorList then
        return classColorList
    end
    classColorList = {}
    if RAID_CLASS_COLORS then
        local classes = {}
        for className in pairs(RAID_CLASS_COLORS) do
            table.insert(classes, className)
        end
        table.sort(classes)
        for _, className in ipairs(classes) do
            local color = RAID_CLASS_COLORS[className]
            table.insert(classColorList, { r = color.r, g = color.g, b = color.b })
        end
    end
    if #classColorList == 0 then
        classColorList = {
            { r = 0.9, g = 0.9, b = 0.9 },
        }
    end
    return classColorList
end

local function getRainbowColor()
    local colors = getClassColorList()
    local count = #colors
    local t = GetTime and GetTime() or 0
    local index = (math.floor(t * 2) % count) + 1
    return colors[index]
end

local function formatPlayersCount(count)
    local text = tostring(count) .. " Players"
    local c = getRainbowColor()
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

function UI:UpdateRainbowRows()
    local function updateRow(row)
        if not row or not row.rainbowData then
            return false
        end
        local data = row.rainbowData
        if data.kind == "loot" then
            row.text:SetText(string.format("Gave %s: %s", formatPlayersCount(data.count), data.itemLink or ""))
        elseif data.kind == "boss" then
            row.text:SetText(string.format("Gave %s: +%d (%s)", formatPlayersCount(data.count), data.points or 0, data.encounter or "Boss"))
        end
        return true
    end

    local any = false
    if self.historyRows then
        for _, row in ipairs(self.historyRows) do
            if row:IsShown() then
                any = updateRow(row) or any
            end
        end
    end
    if self.lootHistoryRows then
        for _, row in ipairs(self.lootHistoryRows) do
            if row:IsShown() then
                any = updateRow(row) or any
            end
        end
    end
    return any
end

function UI:StartRainbowTicker()
    if not self.frame then
        return
    end
    if self.rainbowTickerActive then
        return
    end
    self.rainbowTickerActive = true
    self.rainbowElapsed = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.rainbowElapsed = (self.rainbowElapsed or 0) + (elapsed or 0)
        if self.rainbowElapsed < 0.2 then
            return
        end
        self.rainbowElapsed = 0
        if not self:UpdateRainbowRows() then
            self.rainbowTickerActive = false
            self.frame:SetScript("OnUpdate", nil)
        end
    end)
end

local function getUpdateInfo()
    local info = Goals and Goals.UpdateInfo or nil
    local installedMajor = info and tonumber(info.major) or 2
    local installedMinor = info and tonumber(info.version) or 0
    local url = info and info.url or ""
    local availableMajor = Goals and Goals.db and Goals.db.settings and Goals.db.settings.updateAvailableMajor or 0
    local availableMinor = Goals and Goals.db and Goals.db.settings and Goals.db.settings.updateAvailableVersion or 0
    return installedMajor, installedMinor, availableMajor, availableMinor, url
end

local function isUpdateAvailable()
    local installedMajor, installedMinor, availableMajor, availableMinor = getUpdateInfo()
    if availableMajor == 0 and availableMinor == 0 then
        return false
    end
    if availableMajor ~= installedMajor then
        return availableMajor > installedMajor
    end
    return availableMinor > installedMinor
end

local function hasModifyAccess()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return true
    end
    if not Goals or not Goals.IsGroupLeader then
        return false
    end
    local inRaid = Goals.IsInRaid and Goals:IsInRaid()
    local inParty = Goals.IsInParty and Goals:IsInParty()
    return (inRaid or inParty) and Goals:IsGroupLeader()
end

local function hasPointGainAccess()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return true
    end
    return Goals and Goals.sync and Goals.sync.isMaster
end

local function hasDisenchanterAccess()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return true
    end
    if not Goals or not Goals.IsGroupLeader then
        return false
    end
    local inRaid = Goals.IsInRaid and Goals:IsInRaid()
    local inParty = Goals.IsInParty and Goals:IsInParty()
    return (inRaid or inParty) and Goals:IsGroupLeader()
end

local function setupSudoDevPopup()
    if not StaticPopupDialogs or StaticPopupDialogs.GOALS_SUDO_DEV then
        return
    end
    StaticPopupDialogs.GOALS_SUDO_DEV = {
        text = L.POPUP_SUDO_DEV,
        button1 = L.POPUP_SUDO_DEV_ACCEPT,
        button2 = CANCEL,
        OnAccept = function()
            if Goals and Goals.db and Goals.db.settings then
                Goals.db.settings.sudoDev = true
                if Goals.UI then
                    Goals.UI:Refresh()
                end
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
end

local function setupSaveTableHelpPopup()
    if not StaticPopupDialogs or StaticPopupDialogs.GOALS_SAVE_TABLE_HELP then
        return
    end
    StaticPopupDialogs.GOALS_SAVE_TABLE_HELP = {
        text = L.POPUP_SAVE_TABLE_HELP,
        button1 = OKAY,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
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

local function getMiniSettings()
    if not Goals or not Goals.db or not Goals.db.settings then
        return nil
    end
    if type(Goals.db.settings.miniTracker) ~= "table" then
        Goals.db.settings.miniTracker = {
            show = false,
            minimized = false,
            x = MINI_DEFAULT_X,
            y = MINI_DEFAULT_Y,
            hasPosition = false,
            buttonX = 0,
            buttonY = 0,
        }
    end
    return Goals.db.settings.miniTracker
end

local function getQualityLabel(quality)
    local label = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, label)
    end
    return label
end

local function getQualityOptions()
    local qualities = { 0, 1, 2, 3, 4, 5, 6, 7 }
    local options = {}
    for _, quality in ipairs(qualities) do
        local label = _G["ITEM_QUALITY" .. quality .. "_DESC"]
        if label then
            table.insert(options, { value = quality, text = getQualityLabel(quality) })
        end
    end
    return options
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

local function setShown(frame, show)
    if not frame then
        return
    end
    if show then
        frame:Show()
    else
        frame:Hide()
    end
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
    local playerMap = Goals.db.players
    if Goals.db.settings and Goals.db.settings.tableCombined and Goals.GetCombinedPlayers then
        playerMap = Goals:GetCombinedPlayers()
    end
    local present = Goals:GetPresenceMap()
    local showPresentOnly = Goals.db.settings and Goals.db.settings.showPresentOnly
    for name, data in pairs(playerMap) do
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
    local minQuality = Goals.db.settings and Goals.db.settings.lootHistoryMinQuality or 0
    local hiddenBefore = Goals.db.settings and Goals.db.settings.lootHistoryHiddenBefore or 0
    for _, entry in ipairs(Goals.db.history) do
        if entry.kind == "LOOT_FOUND" or entry.kind == "LOOT_ASSIGN" then
            local include = true
            if hiddenBefore > 0 and (entry.ts or 0) <= hiddenBefore then
                include = false
            end
            if include and minQuality > 0 then
                local itemLink = entry.data and entry.data.item or nil
                if itemLink and GetItemInfo then
                    local quality = select(3, GetItemInfo(itemLink))
                    if quality and quality < minQuality then
                        include = false
                    end
                end
            end
            if include then
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

function UI:SetupResetQualityDropdown(dropdown)
    dropdown.options = getQualityOptions()
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(dropdown.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                Goals:SetRaidSetting("resetMinQuality", option.value)
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                UIDropDownMenu_SetText(dropdown, option.text)
            end
            info.checked = (Goals.db.settings.resetMinQuality or 4) == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self:SyncResetQualityDropdown()
end

function UI:SyncResetQualityDropdown()
    if not self.resetQualityDropdown then
        return
    end
    local value = Goals.db.settings.resetMinQuality or 4
    UIDropDownMenu_SetSelectedValue(self.resetQualityDropdown, value)
    UIDropDownMenu_SetText(self.resetQualityDropdown, getQualityLabel(value))
end

function UI:Init()
    if self.frame then
        return
    end
    self:CreateMainFrame()
    self:CreateMinimapButton()
    self:CreateFloatingButton()
    self:CreateMiniTracker()
    self:CreateMiniFloatingButton()
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

local function registerSpecialFrame(name)
    if not name then
        return
    end
    if not UISpecialFrames then
        UISpecialFrames = {}
    end
    for _, existing in ipairs(UISpecialFrames) do
        if existing == name then
            return
        end
    end
    table.insert(UISpecialFrames, name)
end

function UI:CreateMainFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "GoalsMainFrame", UIParent, "GoalsFrameTemplate")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local titleText = frame.TitleText
    if not titleText then
        titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    local version = Goals and Goals.GetDisplayVersion and Goals:GetDisplayVersion() or nil
    if version then
        titleText:SetText(string.format("GOALS v%s - By: ErebusAres", tostring(version)))
    else
        titleText:SetText(L.TITLE)
    end
    titleText:ClearAllPoints()
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -6)
    titleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -70, -6)
    titleText:SetJustifyH("LEFT")
    frame.titleText = titleText

    local close = _G[frame:GetName() .. "CloseButton"]
    if close then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 5)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    registerSpecialFrame(frame:GetName())

    local minimize = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    if close then
        minimize:SetSize(close:GetWidth(), close:GetHeight())
        minimize:SetFrameLevel(close:GetFrameLevel() + 1)
    else
        minimize:SetSize(24, 24)
    end
    minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-HideButton-Highlight", "ADD")
    minimize:SetAlpha(1)
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
        { key = "wishlist", text = L.TAB_WISHLIST, create = "CreateWishlistTab" },
        { key = "settings", text = L.TAB_SETTINGS, create = "CreateSettingsTab" },
    }
    if self:ShouldShowUpdateTab() then
        table.insert(tabDefs, { key = "update", text = L.TAB_UPDATE, create = "CreateUpdateTab" })
    end
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
        if def.key == "update" then
            self.updateTab = tab
            self.updateTabId = i
        end
        if def.key == "loot" then
            self.lootTabId = i
        end
        if def.key == "wishlist" then
            self.wishlistTabId = i
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
    self:UpdateUpdateTabGlow()
end

function UI:ShouldShowUpdateTab()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    return isUpdateAvailable()
end

function UI:SetupUpdateTabGlow(tab)
    if not tab or tab.glow then
        return
    end
    local glow = tab:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 15, 0)
    glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 15, 0)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.15, 0.15)
    glow:SetAlpha(1)
    glow:Hide()
    tab.glow = glow

    local anim = glow:CreateAnimationGroup()
    local fadeIn = anim:CreateAnimation("Alpha")
    if fadeIn and fadeIn.SetFromAlpha then
        fadeIn:SetFromAlpha(0.2)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.8)
        fadeIn:SetOrder(1)
    end
    local fadeOut = anim:CreateAnimation("Alpha")
    if fadeOut and fadeOut.SetFromAlpha then
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.2)
        fadeOut:SetDuration(0.8)
        fadeOut:SetOrder(2)
    end
    if anim.SetLooping then
        anim:SetLooping("REPEAT")
    end
    tab.glowAnim = anim

    local tabPulse = tab:CreateAnimationGroup()
    local tabIn = tabPulse:CreateAnimation("Alpha")
    if tabIn and tabIn.SetFromAlpha then
        tabIn:SetFromAlpha(0.6)
        tabIn:SetToAlpha(1)
        tabIn:SetDuration(0.8)
        tabIn:SetOrder(1)
    end
    local tabOut = tabPulse:CreateAnimation("Alpha")
    if tabOut and tabOut.SetFromAlpha then
        tabOut:SetFromAlpha(1)
        tabOut:SetToAlpha(0.6)
        tabOut:SetDuration(0.8)
        tabOut:SetOrder(2)
    end
    if tabPulse.SetLooping then
        tabPulse:SetLooping("REPEAT")
    end
    tab.tabPulse = tabPulse
end

function UI:UpdateUpdateTabGlow()
    if not self.updateTab then
        return
    end
    local available = isUpdateAvailable()
    local seenFlag = Goals and Goals.db and Goals.db.settings and Goals.db.settings.updateHasBeenSeen
    if available then
        self:SetupUpdateTabGlow(self.updateTab)
        if self.updateTab.glow then
            self.updateTab.glow:Show()
        end
        if not seenFlag then
            if self.updateTab.glowAnim then
                self.updateTab.glowAnim:Stop()
                self.updateTab.glowAnim:Play()
            end
            if self.updateTab.tabPulse then
                self.updateTab.tabPulse:Stop()
                self.updateTab.tabPulse:Play()
            end
        else
            if self.updateTab.glowAnim then
                self.updateTab.glowAnim:Stop()
            end
            if self.updateTab.tabPulse then
                self.updateTab.tabPulse:Stop()
                self.updateTab:SetAlpha(1)
            end
        end
    else
        if self.updateTab.glowAnim then
            self.updateTab.glowAnim:Stop()
        end
        if self.updateTab.glow then
            self.updateTab.glow:Hide()
        end
        if self.updateTab.tabPulse then
            self.updateTab.tabPulse:Stop()
            self.updateTab:SetAlpha(1)
        end
    end
end

function UI:RefreshUpdateTab()
    if not self.updateStatusText or not self.updateVersionText or not self.updateUrlText then
        return
    end
    local installedMajor, installedMinor, availableMajor, availableMinor, updateUrl = getUpdateInfo()
    local installedVersion = string.format("%d.%d", installedMajor, installedMinor)
    local availableVersion = string.format("%d.%d", availableMajor, availableMinor)
    self.updateUrl = updateUrl or ""
    local available = isUpdateAvailable()
    if available and (availableMajor > 0 or availableMinor > 0) then
        self.updateStatusText:SetText(string.format(L.UPDATE_AVAILABLE, availableVersion))
        self.updateVersionText:SetText(string.format(L.UPDATE_VERSION_LINE, installedVersion, availableVersion))
    else
        self.updateStatusText:SetText(L.UPDATE_NONE)
        if installedMinor > 0 then
            self.updateVersionText:SetText(string.format(L.UPDATE_VERSION_CURRENT, installedVersion))
        else
            self.updateVersionText:SetText("")
        end
    end
    if updateUrl ~= "" then
        self.updateUrlText:SetText(updateUrl)
    else
        self.updateUrlText:SetText(L.UPDATE_DOWNLOAD_MISSING)
    end
    if self.updateDownloadButton then
        if updateUrl ~= "" then
            self.updateDownloadButton:Enable()
        else
            self.updateDownloadButton:Disable()
        end
    end
    if self.updateDismissButton then
        if available then
            self.updateDismissButton:Enable()
            self.updateDismissButton:Show()
        else
            self.updateDismissButton:Disable()
            self.updateDismissButton:Hide()
        end
    end
    if self.updateDebugText then
        local settings = Goals and Goals.db and Goals.db.settings or nil
        local seenMajor = settings and settings.updateSeenMajor or 0
        local seenMinor = settings and settings.updateSeenVersion or 0
        local seenFlag = settings and settings.updateHasBeenSeen and "true" or "false"
        self.updateDebugText:SetText(string.format("Debug: installed v%s, available v%s, seen v%d.%d, seenFlag %s", installedVersion, availableVersion, seenMajor, seenMinor, seenFlag))
    end
end

function UI:SelectTab(id)
    if not self.frame or not self.tabs[id] then
        return
    end
    PanelTemplates_SetTab(self.frame, id)
    for index, page in ipairs(self.pages) do
        setShown(page, index == id)
    end
    self.currentTab = id
    if self.UpdateLootOptionsVisibility then
        self:UpdateLootOptionsVisibility()
    end
    if self.UpdateWishlistHelpVisibility then
        self:UpdateWishlistHelpVisibility()
    end
    self:Refresh()
end

function UI:UpdateLootOptionsVisibility()
    if not self.lootOptionsFrame then
        return
    end
    local show = self.currentTab == self.lootTabId and self.lootOptionsOpen
    if self.lootOptionsOuter then
        setShown(self.lootOptionsOuter, show)
    end
    setShown(self.lootOptionsFrame, show)
end

function UI:UpdateWishlistHelpVisibility()
    if not self.wishlistHelpFrame then
        return
    end
    local show = self.currentTab == self.wishlistTabId and self.wishlistHelpOpen
    if self.wishlistHelpOuter then
        setShown(self.wishlistHelpOuter, show)
    end
    setShown(self.wishlistHelpFrame, show)
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

    local disableGainCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    disableGainCheck:SetPoint("LEFT", presentCheck.Text or presentCheck, "RIGHT", 12, 0)
    disableGainCheck:SetPoint("CENTER", presentCheck, "CENTER", 0, 0)
    setCheckText(disableGainCheck, L.CHECK_DISABLE_POINT_GAIN)
    disableGainCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("disablePointGain", selfBtn:GetChecked() and true or false)
    end)
    self.disablePointGainCheck = disableGainCheck

    local rosterInset = CreateFrame("Frame", "GoalsOverviewRosterInset", page, "GoalsInsetTemplate")
    rosterInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -30)
    rosterInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    rosterInset:SetWidth(360)
    self.rosterInset = rosterInset

    local pointsLabel = createLabel(rosterInset, L.LABEL_POINTS, "GameFontNormal")
    pointsLabel:SetPoint("TOPLEFT", rosterInset, "TOPLEFT", 10, -6)

    local rosterScroll = CreateFrame("ScrollFrame", "GoalsRosterScroll", rosterInset, "FauxScrollFrameTemplate")
    rosterScroll:SetPoint("TOPLEFT", rosterInset, "TOPLEFT", 2, -22)
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
        row:SetPoint("TOPLEFT", rosterInset, "TOPLEFT", 8, -22 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", rosterInset, "RIGHT", -26, 0)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        icon:SetPoint("LEFT", row, "LEFT", 2, 0)
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

    local rightInset = CreateFrame("Frame", "GoalsOverviewRightInset", page, "GoalsInsetTemplate")
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

    local disSelectLabel = createLabel(rightInset, L.SETTINGS_DISENCHANTER, "GameFontNormal")
    disSelectLabel:SetPoint("TOPLEFT", disValue, "BOTTOMLEFT", 0, -10)

    local disDrop = CreateFrame("Frame", "GoalsDisenchanterDropdown", rightInset, "UIDropDownMenuTemplate")
    disDrop:SetPoint("TOPLEFT", disSelectLabel, "BOTTOMLEFT", -10, -2)
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

    local manualTitle = createLabel(rightInset, L.LABEL_MANUAL, "GameFontNormal")
    manualTitle:SetPoint("TOPLEFT", disDrop, "BOTTOMLEFT", 10, -12)

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
    bindEscapeClear(amountBox)
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

    local minFilterLabel = createLabel(page, L.LABEL_LOOT_HISTORY_FILTER, "GameFontNormal")
    minFilterLabel:SetPoint("TOPLEFT", lootLabel, "BOTTOMLEFT", 0, -8)

    local minFilterDrop = CreateFrame("Frame", "GoalsLootHistoryMinQuality", page, "UIDropDownMenuTemplate")
    minFilterDrop:SetPoint("LEFT", minFilterLabel, "RIGHT", -6, -2)
    styleDropdown(minFilterDrop, 140)
    minFilterDrop.options = getQualityOptions()
    UIDropDownMenu_Initialize(minFilterDrop, function(_, level)
        for _, option in ipairs(minFilterDrop.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                Goals.db.settings.lootHistoryMinQuality = option.value
                UIDropDownMenu_SetSelectedValue(minFilterDrop, option.value)
                UIDropDownMenu_SetText(minFilterDrop, option.text)
                UI:UpdateLootHistoryList()
            end
            info.checked = (Goals.db.settings.lootHistoryMinQuality or 0) == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.lootHistoryMinQuality = minFilterDrop

    local historyInset = CreateFrame("Frame", "GoalsLootHistoryInset", page, "GoalsInsetTemplate")
    historyInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -60)
    historyInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    historyInset:SetWidth(350)
    self.lootHistoryInset = historyInset

    local historyLabel = createLabel(historyInset, L.LABEL_LOOT_HISTORY, "GameFontNormal")
    historyLabel:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 8, -6)

    local optionsBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    optionsBtn:SetSize(130, 20)
    optionsBtn:SetText(L.LABEL_LOOT_OPTIONS)
    optionsBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -6, -6)

    local optionsIcon = optionsBtn:CreateTexture(nil, "ARTWORK")
    optionsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    optionsIcon:SetSize(16, 16)
    optionsIcon:SetPoint("LEFT", optionsBtn, "LEFT", 6, 0)
    local optionsText = optionsBtn:GetFontString()
    if optionsText then
        optionsText:ClearAllPoints()
        optionsText:SetPoint("LEFT", optionsIcon, "RIGHT", 4, 0)
    end

    optionsBtn:SetScript("OnClick", function()
        UI.lootOptionsOpen = not UI.lootOptionsOpen
        UI:UpdateLootOptionsVisibility()
    end)
    self.lootOptionsButton = optionsBtn
    if self.lootOptionsOpen == nil then
        self.lootOptionsOpen = false
    end

    if not self.lootOptionsFrame then
        local outer = CreateFrame("Frame", "GoalsLootOptionsOuter", self.frame)
        outer:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
        outer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -2, 26)
        outer:SetWidth(238)
        outer:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        outer:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
        outer:Hide()
        self.lootOptionsOuter = outer

        local optionsFrame = CreateFrame("Frame", "GoalsLootOptionsFrame", outer, "GoalsInsetTemplate")
        optionsFrame:SetPoint("TOPLEFT", outer, "TOPLEFT", 4, -4)
        optionsFrame:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -4, 4)
        optionsFrame:Hide()
        self.lootOptionsFrame = optionsFrame

        local optionsTitle = createLabel(optionsFrame, L.LABEL_LOOT_OPTIONS, "GameFontNormal")
        optionsTitle:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 10, -10)

        local resetTitle = createLabel(optionsFrame, L.LABEL_RESET_POINTS, "GameFontNormal")
        resetTitle:SetPoint("TOPLEFT", optionsTitle, "BOTTOMLEFT", 0, -12)

        local resetMountCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        resetMountCheck:SetPoint("TOPLEFT", resetTitle, "BOTTOMLEFT", 0, -6)
        setCheckText(resetMountCheck, L.CHECK_RESET_MOUNTS)
        resetMountCheck:SetScript("OnClick", function(selfBtn)
            Goals:SetRaidSetting("resetMounts", selfBtn:GetChecked() and true or false)
        end)
        self.resetMountsCheck = resetMountCheck

        local resetPetCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        resetPetCheck:SetPoint("TOPLEFT", resetMountCheck, "BOTTOMLEFT", 0, -6)
        setCheckText(resetPetCheck, L.CHECK_RESET_PETS)
        resetPetCheck:SetScript("OnClick", function(selfBtn)
            Goals:SetRaidSetting("resetPets", selfBtn:GetChecked() and true or false)
        end)
        self.resetPetsCheck = resetPetCheck

        local resetRecipesCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        resetRecipesCheck:SetPoint("TOPLEFT", resetPetCheck, "BOTTOMLEFT", 0, -6)
        setCheckText(resetRecipesCheck, L.CHECK_RESET_RECIPES)
        resetRecipesCheck:SetScript("OnClick", function(selfBtn)
            Goals:SetRaidSetting("resetRecipes", selfBtn:GetChecked() and true or false)
        end)
        self.resetRecipesCheck = resetRecipesCheck

        local resetTokensCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        resetTokensCheck:SetPoint("TOPLEFT", resetRecipesCheck, "BOTTOMLEFT", 0, -6)
        setCheckText(resetTokensCheck, L.CHECK_RESET_TOKENS)
        resetTokensCheck:SetScript("OnClick", function(selfBtn)
            Goals:SetRaidSetting("resetTokens", selfBtn:GetChecked() and true or false)
        end)
        self.resetTokensCheck = resetTokensCheck

        local resetQuestCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        resetQuestCheck:SetPoint("TOPLEFT", resetTokensCheck, "BOTTOMLEFT", 0, -6)
        setCheckText(resetQuestCheck, L.CHECK_RESET_QUEST_ITEMS)
        resetQuestCheck:SetScript("OnClick", function(selfBtn)
            Goals:SetRaidSetting("resetQuestItems", selfBtn:GetChecked() and true or false)
        end)
        self.resetQuestItemsCheck = resetQuestCheck

        local minLabel = createLabel(optionsFrame, L.LABEL_MIN_RESET_QUALITY, "GameFontNormal")
        minLabel:SetPoint("TOPLEFT", resetQuestCheck, "BOTTOMLEFT", 0, -12)

        local minDrop = CreateFrame("Frame", "GoalsResetQualityDropdown", optionsFrame, "UIDropDownMenuTemplate")
        minDrop:SetPoint("TOPLEFT", minLabel, "BOTTOMLEFT", -10, -2)
        styleDropdown(minDrop, 160)
        self.resetQualityDropdown = minDrop
        self:SetupResetQualityDropdown(minDrop)
    end

    local historyScroll = CreateFrame("ScrollFrame", "GoalsLootHistoryScroll", historyInset, "FauxScrollFrameTemplate")
    historyScroll:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 2, -22)
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
        row:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 8, -22 - (i - 1) * LOOT_HISTORY_ROW_HEIGHT)
        row:SetPoint("RIGHT", historyInset, "RIGHT", -6, 0)

        local timeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        timeText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2)
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

    local foundInset = CreateFrame("Frame", "GoalsFoundLootInset", page, "GoalsInsetTemplate")
    foundInset:SetPoint("TOPLEFT", historyInset, "TOPRIGHT", 12, 0)
    foundInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)

    local foundLabel = createLabel(foundInset, L.LABEL_FOUND_LOOT, "GameFontNormal")
    foundLabel:SetPoint("TOPLEFT", foundInset, "TOPLEFT", 8, -6)

    local foundHint = createLabel(foundInset, L.LABEL_FOUND_LOOT_HINT, "GameFontHighlightSmall")
    foundHint:SetPoint("TOPLEFT", foundLabel, "BOTTOMLEFT", 0, -2)
    self.foundHintLabel = foundHint

    local foundLocked = createLabel(foundInset, L.LABEL_FOUND_LOOT_LOCKED, "GameFontHighlightSmall")
    foundLocked:SetPoint("TOPLEFT", foundLabel, "BOTTOMLEFT", 0, -2)
    self.foundLockedLabel = foundLocked

    local foundScroll = CreateFrame("ScrollFrame", "GoalsFoundLootScroll", foundInset, "FauxScrollFrameTemplate")
    foundScroll:SetPoint("TOPLEFT", foundInset, "TOPLEFT", 2, -36)
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
        row:SetPoint("TOPLEFT", foundInset, "TOPLEFT", 8, -36 - (i - 1) * ROW_HEIGHT)
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
    local inset = CreateFrame("Frame", "GoalsHistoryInset", page, "GoalsInsetTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.historyInset = inset

    local label = createLabel(inset, L.LABEL_HISTORY, "GameFontNormal")
    label:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -6)

    local scroll = CreateFrame("ScrollFrame", "GoalsHistoryScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 2, -22)
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
        row:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -22 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", inset, "RIGHT", -6, 0)

        local timeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        timeText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2)
        timeText:SetWidth(50)
        timeText:SetJustifyH("LEFT")
        row.timeText = timeText

        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOPLEFT", timeText, "TOPRIGHT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        self.historyRows[i] = row
    end
end

local function fitWishlistLabel(label, text)
    if not label then
        return
    end
    label:SetText(text or "")
    local font, size = label:GetFont()
    local lineHeight = (size or 12) + 2
    local maxHeight = lineHeight * 3
    if label:GetStringHeight() <= maxHeight then
        return
    end
    local base = text or ""
    local left, right = 1, #base
    local best = ""
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local candidate = base:sub(1, mid) .. "..."
        label:SetText(candidate)
        if label:GetStringHeight() <= maxHeight then
            best = candidate
            left = mid + 1
        else
            right = mid - 1
        end
    end
    if best ~= "" then
        label:SetText(best)
    else
        label:SetText("...")
    end
end

-- reserved for future wishlist textbox styling tweaks

function UI:CreateWishlistTab(page)
    local leftInset = CreateFrame("Frame", "GoalsWishlistLeftInset", page, "GoalsInsetTemplate")
    leftInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    leftInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    leftInset:SetWidth(380)
    self.wishlistLeftInset = leftInset

    local rightInset = CreateFrame("Frame", "GoalsWishlistRightInset", page, "GoalsInsetTemplate")
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 12, 0)
    rightInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.wishlistRightInset = rightInset

    local tabBar = CreateFrame("Frame", nil, rightInset)
    tabBar:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 8, -6)
    tabBar:SetPoint("TOPRIGHT", rightInset, "TOPRIGHT", -8, -6)
    tabBar:SetHeight(22)

    local managerPage = CreateFrame("Frame", nil, rightInset)
    managerPage:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -32)
    managerPage:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -6, 6)

    local searchPage = CreateFrame("Frame", nil, rightInset)
    searchPage:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -32)
    searchPage:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -6, 6)
    searchPage:Hide()

    local actionsPage = CreateFrame("Frame", nil, rightInset)
    actionsPage:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -32)
    actionsPage:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -6, 6)
    actionsPage:Hide()

    local function selectWishlistTab(key)
        setShown(managerPage, key == "manage")
        setShown(searchPage, key == "search")
        setShown(actionsPage, key == "actions")
        if self.wishlistSubTabs then
            for name, button in pairs(self.wishlistSubTabs) do
                if name == key then
                    button:LockHighlight()
                else
                    button:UnlockHighlight()
                end
            end
        end
    end

    local function createTabButton(text, key, anchor)
        local btn = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
        btn:SetSize(80, 20)
        btn:SetText(text)
        if anchor then
            btn:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
        else
            btn:SetPoint("LEFT", tabBar, "LEFT", 0, 0)
        end
        btn:SetScript("OnClick", function()
            selectWishlistTab(key)
        end)
        return btn
    end

    self.wishlistSubTabs = {}
    self.wishlistSubTabs.manage = createTabButton("Manage", "manage", nil)
    self.wishlistSubTabs.search = createTabButton("Search", "search", self.wishlistSubTabs.manage)
    self.wishlistSubTabs.actions = createTabButton("Actions", "actions", self.wishlistSubTabs.search)

    local helpBtn = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
    helpBtn:SetSize(22, 20)
    helpBtn:SetText("?")
    helpBtn:SetPoint("RIGHT", tabBar, "RIGHT", 0, 0)
    helpBtn:SetScript("OnClick", function()
        self.wishlistHelpOpen = not self.wishlistHelpOpen
        if self.UpdateWishlistHelpVisibility then
            self:UpdateWishlistHelpVisibility()
        end
    end)
    self.wishlistHelpButton = helpBtn

    selectWishlistTab("manage")

    if self.wishlistHelpOpen == nil then
        self.wishlistHelpOpen = false
    end
    if not self.wishlistHelpFrame then
        local outer = CreateFrame("Frame", "GoalsWishlistHelpOuter", self.frame)
        outer:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
        outer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -2, 26)
        outer:SetWidth(260)
        outer:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        outer:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
        outer:Hide()
        self.wishlistHelpOuter = outer

        local helpFrame = CreateFrame("Frame", "GoalsWishlistHelpFrame", outer, "GoalsInsetTemplate")
        helpFrame:SetPoint("TOPLEFT", outer, "TOPLEFT", 4, -4)
        helpFrame:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -4, 4)
        helpFrame:Hide()
        self.wishlistHelpFrame = helpFrame

        local helpTitle = createLabel(helpFrame, "Wishlist Help", "GameFontNormal")
        helpTitle:SetPoint("TOPLEFT", helpFrame, "TOPLEFT", 10, -10)

        local helpText = helpFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        helpText:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -8)
        helpText:SetPoint("TOPRIGHT", helpFrame, "TOPRIGHT", -10, -8)
        helpText:SetJustifyH("LEFT")
        helpText:SetText(
            "Tips:\n" ..
            "- Use Search to find items and add to a slot.\n" ..
            "- Paste an in-game item link into Search to cache it.\n" ..
            "- Example: |cff...|Hitem:12345:...|h[Item]|h|r\n" ..
            "- You can also paste a raw item ID (12345).\n" ..
            "- Click a slot icon to select it before adding.\n" ..
            "- Alt-click a slot icon to mark found/unfound.\n" ..
            "- Right-click a slot icon to clear it.\n" ..
            "- Enchant ID and Gems apply to the selected slot.\n" ..
            "- Import supports wishlist strings and Wowhead links.\n" ..
            "- Required tokens update as items are marked found."
        )
        self.wishlistHelpText = helpText
    end

    local slotsLabel = createLabel(leftInset, L.LABEL_WISHLIST_SLOTS, "GameFontNormal")
    slotsLabel:SetPoint("TOPLEFT", leftInset, "TOPLEFT", 10, -8)

    self.wishlistSlotButtons = {}
    local slots = Goals:GetWishlistSlotDefs() or {}
    local leftColumnX = 28
    local rightColumnX = leftInset:GetWidth() - WISHLIST_SLOT_SIZE - 30
    local columnCenter = leftInset:GetWidth() * 0.5
    local centerGap = 3
    local gemColumnWidth = 12
    local gemNameGap = 2
    local nameOffset = gemColumnWidth + gemNameGap + 6
    local leftLabelWidth = math.max(80, (columnCenter - centerGap) - (leftColumnX + WISHLIST_SLOT_SIZE + nameOffset) - 4)
    local rightLabelWidth = math.max(80, (rightColumnX - nameOffset) - (columnCenter + centerGap) - 4)
    local topY = -28
    local bottomRowY = 60
    local bottomRowX = {
        MAINHAND = 80,
        OFFHAND = 170,
        RELIC = 260,
    }

    local function createSlotButton(slotDef)
        local button = CreateFrame("Button", nil, leftInset)
        button:SetSize(WISHLIST_SLOT_SIZE, WISHLIST_SLOT_SIZE)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon = icon

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetPoint("CENTER", button, "CENTER", 0, 0)
        border:SetSize(WISHLIST_SLOT_SIZE * 1.8, WISHLIST_SLOT_SIZE * 1.8)
        border:Hide()
        button.border = border

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(button)
        button:SetHighlightTexture(highlight)

        local selected = button:CreateTexture(nil, "OVERLAY")
        selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        selected:SetBlendMode("ADD")
        selected:SetAllPoints(button)
        selected:Hide()
        button.selected = selected

        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        button.label = label

        local foundShadow = button:CreateTexture(nil, "ARTWORK")
        foundShadow:SetTexture("Interface\\Cooldown\\ping4")
        foundShadow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        foundShadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        foundShadow:SetVertexColor(0, 0, 0, 0.45)
        foundShadow:SetDrawLayer("ARTWORK", 0)
        foundShadow:SetBlendMode("BLEND")
        foundShadow:Hide()
        button.foundShadow = foundShadow

        local foundIcon = button:CreateTexture(nil, "OVERLAY")
        foundIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        foundIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        foundIcon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        foundIcon:SetVertexColor(0.2, 1, 0.2)
        foundIcon:SetDrawLayer("OVERLAY", 5)
        foundIcon:SetBlendMode("BLEND")
        foundIcon:Hide()
        button.foundIcon = foundIcon

        button.gems = {}
        for i = 1, 3 do
            local gemBtn = CreateFrame("Button", nil, button)
            gemBtn:SetSize(12, 12)
            gemBtn:Hide()
            local gemTex = gemBtn:CreateTexture(nil, "ARTWORK")
            gemTex:SetAllPoints(gemBtn)
            gemBtn.icon = gemTex
            gemBtn:SetScript("OnEnter", function(selfGem)
                if selfGem.itemId then
                    GameTooltip:SetOwner(selfGem, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. tostring(selfGem.itemId))
                    GameTooltip:Show()
                end
            end)
            gemBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            button.gems[i] = gemBtn
        end

        local enchantBtn = CreateFrame("Button", nil, button)
        enchantBtn:SetSize(12, 12)
        enchantBtn:Hide()
        local enchantTex = enchantBtn:CreateTexture(nil, "ARTWORK")
        enchantTex:SetAllPoints(enchantBtn)
        enchantTex:SetTexture("Interface\\Icons\\inv_enchant_formulagood_01")
        enchantBtn.icon = enchantTex
        enchantBtn:SetScript("OnEnter", function(selfIcon)
            if selfIcon.enchantId then
                GameTooltip:SetOwner(selfIcon, "ANCHOR_RIGHT")
                GameTooltip:SetText("Enchant ID: " .. tostring(selfIcon.enchantId))
                GameTooltip:Show()
            end
        end)
        enchantBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button.enchantIcon = enchantBtn

        button:SetScript("OnEnter", function(selfBtn)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            if selfBtn.itemLink then
                GameTooltip:SetHyperlink(selfBtn.itemLink)
            elseif selfBtn.itemId then
                GameTooltip:SetHyperlink("item:" .. tostring(selfBtn.itemId))
            else
                GameTooltip:SetText(slotDef.label or "")
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetScript("OnClick", function(selfBtn, btn)
            local altDown = (IsModifiedClick and IsModifiedClick("ALT")) or (IsAltKeyDown and IsAltKeyDown())
            if btn == "LeftButton" and altDown then
                if Goals.ToggleWishlistFoundForSlot then
                    Goals:ToggleWishlistFoundForSlot(slotDef.key)
                end
                self.selectedWishlistSlot = slotDef.key
                self:UpdateWishlistUI()
                return
            end
            if btn == "RightButton" then
                Goals:ClearWishlistItem(slotDef.key)
                return
            end
            self.selectedWishlistSlot = slotDef.key
            self:UpdateWishlistUI()
        end)

        return button
    end

    for _, slotDef in ipairs(slots) do
        local button = createSlotButton(slotDef)
        if slotDef.column == 1 then
            button:SetPoint("TOPLEFT", leftInset, "TOPLEFT", leftColumnX, topY - (slotDef.row - 1) * WISHLIST_ROW_SPACING)
            button.label:SetPoint("LEFT", button, "RIGHT", nameOffset, 0)
            button.label:SetWidth(leftLabelWidth)
            button.label:SetJustifyH("LEFT")
            if button.label.SetJustifyV then
                button.label:SetJustifyV("MIDDLE")
            end
            button.label:SetWordWrap(true)
        elseif slotDef.column == 2 then
            button:SetPoint("TOPLEFT", leftInset, "TOPLEFT", rightColumnX, topY - (slotDef.row - 1) * WISHLIST_ROW_SPACING)
            button.label:SetPoint("RIGHT", button, "LEFT", -nameOffset, 0)
            button.label:SetJustifyH("RIGHT")
            if button.label.SetJustifyV then
                button.label:SetJustifyV("MIDDLE")
            end
            button.label:SetWidth(rightLabelWidth)
            button.label:SetWordWrap(true)
        else
            local x = bottomRowX[slotDef.key] or 90
            button:SetPoint("BOTTOMLEFT", leftInset, "BOTTOMLEFT", x, bottomRowY)
            button.label:SetPoint("TOP", button, "BOTTOM", 0, -6)
            button.label:SetWidth(104)
            button.label:SetJustifyH("CENTER")
            if button.label.SetJustifyV then
                button.label:SetJustifyV("MIDDLE")
            end
            button.label:SetWordWrap(true)
        end
        button.slotKey = slotDef.key
        button.slotLabel = slotDef.label or slotDef.key
        button.column = slotDef.column
        self.wishlistSlotButtons[slotDef.key] = button
    end

    local managerLabel = createLabel(managerPage, L.LABEL_WISHLIST_MANAGER, "GameFontNormal")
    managerLabel:SetPoint("TOPLEFT", managerPage, "TOPLEFT", 4, -4)

    local managerInset = CreateFrame("Frame", "GoalsWishlistManagerInset", managerPage, "GoalsInsetTemplate")
    managerInset:SetPoint("TOPLEFT", managerPage, "TOPLEFT", 0, -24)
    managerInset:SetPoint("TOPRIGHT", managerPage, "TOPRIGHT", 0, -24)
    managerInset:SetHeight(110)
    self.wishlistManagerInset = managerInset

    local managerScroll = CreateFrame("ScrollFrame", "GoalsWishlistManagerScroll", managerInset, "FauxScrollFrameTemplate")
    managerScroll:SetPoint("TOPLEFT", managerInset, "TOPLEFT", 2, -6)
    managerScroll:SetPoint("BOTTOMRIGHT", managerInset, "BOTTOMRIGHT", -26, 6)
    managerScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistManagerList()
        end)
    end)
    self.wishlistManagerScroll = managerScroll

    self.wishlistManagerRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, managerInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", managerInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", managerInset, "RIGHT", -26, 0)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        highlight:SetBlendMode("ADD")
        row:SetHighlightTexture(highlight)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 2, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        row:SetScript("OnClick", function(selfRow)
            if selfRow.listId then
                Goals:SetActiveWishlist(selfRow.listId)
                UI.selectedWishlistList = selfRow.listId
                UI:UpdateWishlistUI()
            end
        end)
        self.wishlistManagerRows[i] = row
    end

    local nameBox = CreateFrame("EditBox", nil, managerPage, "InputBoxTemplate")
    nameBox:SetPoint("TOPLEFT", managerInset, "BOTTOMLEFT", 6, -8)
    nameBox:SetSize(140, 20)
    nameBox:SetAutoFocus(false)
    bindEscapeClear(nameBox)
    self.wishlistNameBox = nameBox

    local createBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    createBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    createBtn:SetSize(64, 20)
    createBtn:SetText(L.BUTTON_CREATE)
    createBtn:SetScript("OnClick", function()
        Goals:CreateWishlist(nameBox:GetText())
        nameBox:SetText("")
    end)
    self.wishlistCreateButton = createBtn

    local renameBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    renameBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
    renameBtn:SetSize(64, 20)
    renameBtn:SetText(L.BUTTON_RENAME)
    renameBtn:SetScript("OnClick", function()
        local list = Goals:GetActiveWishlist()
        if list then
            Goals:RenameWishlist(list.id, nameBox:GetText())
            nameBox:SetText("")
        end
    end)
    self.wishlistRenameButton = renameBtn

    local copyBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    copyBtn:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)
    copyBtn:SetSize(64, 20)
    copyBtn:SetText(L.BUTTON_COPY)
    copyBtn:SetScript("OnClick", function()
        local list = Goals:GetActiveWishlist()
        if list then
            Goals:CopyWishlist(list.id, nameBox:GetText())
            nameBox:SetText("")
        end
    end)
    self.wishlistCopyButton = copyBtn

    local deleteBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    deleteBtn:SetSize(64, 20)
    deleteBtn:SetText(L.BUTTON_DELETE)
    deleteBtn:SetScript("OnClick", function()
        local list = Goals:GetActiveWishlist()
        if not list then
            return
        end
        StaticPopupDialogs.GOALS_DELETE_WISHLIST = StaticPopupDialogs.GOALS_DELETE_WISHLIST or {
            text = L.WISHLIST_DELETE_CONFIRM,
            button1 = L.WISHLIST_DELETE_ACCEPT,
            button2 = CANCEL,
            OnAccept = function()
                Goals:DeleteWishlist(list.id)
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        local dialog = StaticPopup_Show("GOALS_DELETE_WISHLIST", list.name or "")
    end)
    self.wishlistDeleteButton = deleteBtn

    local searchLabel = createLabel(searchPage, L.LABEL_WISHLIST_SEARCH, "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 4, -4)

    local searchBox = CreateFrame("EditBox", "GoalsWishlistSearchBox", searchPage, "InputBoxTemplate")
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetSize(210, 20)
    searchBox:SetAutoFocus(false)
    bindEscapeClear(searchBox)
    searchBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        UI:UpdateWishlistSearchResults()
    end)
    self.wishlistSearchBox = searchBox

    local linkHint = createLabel(searchPage, "Paste item link or item:ID", "GameFontHighlightSmall")
    linkHint:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -4)
    linkHint:SetTextColor(0.7, 0.7, 0.7)

    self.wishlistSlotFilter = nil
    self.wishlistIlvlBox = nil
    self.wishlistStatsBox = nil
    self.wishlistSourceBox = nil

    local resultsLabel = createLabel(searchPage, L.LABEL_WISHLIST_RESULTS, "GameFontNormal")
    resultsLabel:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -14)

    local resultsInset = CreateFrame("Frame", "GoalsWishlistResultsInset", searchPage, "GoalsInsetTemplate")
    resultsInset:SetPoint("TOPLEFT", resultsLabel, "BOTTOMLEFT", -4, -6)
    resultsInset:SetPoint("TOPRIGHT", searchPage, "TOPRIGHT", -6, 0)
    resultsInset:SetHeight(110)
    self.wishlistResultsInset = resultsInset

    local resultsScroll = CreateFrame("ScrollFrame", "GoalsWishlistResultsScroll", resultsInset, "FauxScrollFrameTemplate")
    resultsScroll:SetPoint("TOPLEFT", resultsInset, "TOPLEFT", 2, -6)
    resultsScroll:SetPoint("BOTTOMRIGHT", resultsInset, "BOTTOMRIGHT", -26, 6)
    resultsScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistSearchResults()
        end)
    end)
    self.wishlistResultsScroll = resultsScroll

    self.wishlistResultsRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, resultsInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", resultsInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", resultsInset, "RIGHT", -26, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetAllPoints(row)
        selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selected:SetBlendMode("ADD")
        selected:Hide()
        row.selected = selected
        row:SetScript("OnClick", function(selfRow)
            UI.selectedWishlistResult = selfRow.entry
            UI:UpdateWishlistSearchResults()
        end)
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.entry and selfRow.entry.link then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(selfRow.entry.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.wishlistResultsRows[i] = row
    end

    local addSlotBtn = CreateFrame("Button", nil, searchPage, "UIPanelButtonTemplate")
    addSlotBtn:SetPoint("TOPLEFT", resultsInset, "BOTTOMLEFT", 0, -10)
    addSlotBtn:SetSize(110, 20)
    addSlotBtn:SetText(L.BUTTON_ADD_SLOT)
    addSlotBtn:SetScript("OnClick", function()
        if UI.selectedWishlistResult and UI.selectedWishlistSlot then
            local entry = UI.selectedWishlistResult
            Goals:SetWishlistItemSmart(UI.selectedWishlistSlot, {
                itemId = entry.id or entry.itemId,
                enchantId = 0,
                gemIds = {},
                notes = "",
                source = entry.source or "",
            })
        end
    end)
    self.wishlistAddSlotButton = addSlotBtn

    local clearSlotBtn = CreateFrame("Button", nil, searchPage, "UIPanelButtonTemplate")
    clearSlotBtn:SetPoint("LEFT", addSlotBtn, "RIGHT", 8, 0)
    clearSlotBtn:SetSize(100, 20)
    clearSlotBtn:SetText(L.BUTTON_CLEAR_SLOT)
    clearSlotBtn:SetScript("OnClick", function()
        if UI.selectedWishlistSlot then
            Goals:ClearWishlistItem(UI.selectedWishlistSlot)
        end
    end)
    self.wishlistClearSlotButton = clearSlotBtn

    local enchantLabel = createLabel(searchPage, "Enchant ID", "GameFontNormal")
    enchantLabel:SetPoint("TOP", addSlotBtn, "BOTTOM", 0, -12)
    enchantLabel:SetPoint("LEFT", searchLabel, "LEFT", 0, 0)

    local enchantBox = CreateFrame("EditBox", "GoalsWishlistEnchantBox", searchPage, "InputBoxTemplate")
    enchantBox:SetPoint("LEFT", enchantLabel, "RIGHT", 10, 0)
    enchantBox:SetSize(90, 20)
    enchantBox:SetAutoFocus(false)
    enchantBox:SetNumeric(true)
    enchantBox:SetFontObject(searchBox:GetFontObject())
    bindEscapeClear(enchantBox)
    self.wishlistEnchantBox = enchantBox

    local gemsLabel = createLabel(searchPage, "Gems", "GameFontNormal")
    gemsLabel:SetPoint("TOP", enchantLabel, "BOTTOM", 0, -10)
    gemsLabel:SetPoint("LEFT", searchLabel, "LEFT", 0, 0)

    local gemBoxes = {}
    for i = 1, 3 do
        local gemBox = CreateFrame("EditBox", "GoalsWishlistGemBox"..i, searchPage, "InputBoxTemplate")
        if i == 1 then
            gemBox:SetPoint("LEFT", gemsLabel, "RIGHT", 10, 0)
        else
            gemBox:SetPoint("LEFT", gemBoxes[i - 1], "RIGHT", 6, 0)
        end
        gemBox:SetSize(46, 20)
        gemBox:SetAutoFocus(false)
        gemBox:SetNumeric(true)
        gemBox:SetFontObject(searchBox:GetFontObject())
        bindEscapeClear(gemBox)
        gemBoxes[i] = gemBox
    end
    self.wishlistGemBoxes = gemBoxes

    local applyGemsBtn = CreateFrame("Button", nil, searchPage, "UIPanelButtonTemplate")
    applyGemsBtn:SetPoint("TOPLEFT", addSlotBtn, "BOTTOMLEFT", 0, -66)
    applyGemsBtn:SetSize(60, 20)
    applyGemsBtn:SetText(L.BUTTON_APPLY)
    applyGemsBtn:SetScript("OnClick", function()
        if not UI.selectedWishlistSlot then
            return
        end
        local entry = Goals:GetWishlistItem(UI.selectedWishlistSlot)
        if not entry then
            return
        end
        entry.enchantId = tonumber(enchantBox:GetText()) or 0
        entry.gemIds = {}
        for i = 1, 3 do
            local value = tonumber(gemBoxes[i]:GetText())
            if value and value > 0 then
                table.insert(entry.gemIds, value)
            end
        end
        Goals:SetWishlistItemSmart(UI.selectedWishlistSlot, entry)
    end)
    self.wishlistApplyGemsButton = applyGemsBtn

    local tokenLabel = createLabel(searchPage, "Required tokens", "GameFontNormal")
    tokenLabel:SetPoint("TOP", applyGemsBtn, "BOTTOM", 0, -10)
    tokenLabel:SetPoint("LEFT", searchLabel, "LEFT", 0, 0)

    local tokenInset = CreateFrame("Frame", "GoalsWishlistTokenInset", searchPage, "GoalsInsetTemplate")
    tokenInset:SetPoint("TOPLEFT", tokenLabel, "BOTTOMLEFT", -4, -6)
    tokenInset:SetPoint("TOPRIGHT", searchPage, "TOPRIGHT", -6, 0)
    tokenInset:SetHeight(ROW_HEIGHT * 5 + 12)
    self.wishlistTokenInset = tokenInset

    local tokenScroll = CreateFrame("ScrollFrame", "GoalsWishlistTokenScroll", tokenInset, "FauxScrollFrameTemplate")
    tokenScroll:SetPoint("TOPLEFT", tokenInset, "TOPLEFT", 2, -6)
    tokenScroll:SetPoint("BOTTOMRIGHT", tokenInset, "BOTTOMRIGHT", -26, 6)
    tokenScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistTokenDisplay()
        end)
    end)
    self.wishlistTokenScroll = tokenScroll

    self.wishlistTokenRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, tokenInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", tokenInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", tokenInset, "RIGHT", -26, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.itemLink then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(selfRow.itemLink)
                GameTooltip:Show()
            elseif selfRow.itemId then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. tostring(selfRow.itemId))
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.wishlistTokenRows[i] = row
    end
    local tokenEmpty = tokenInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tokenEmpty:SetPoint("TOPLEFT", tokenInset, "TOPLEFT", 8, -10)
    tokenEmpty:SetText("None required")
    tokenEmpty:Hide()
    self.wishlistTokenEmpty = tokenEmpty
    self.wishlistTokenLabel = tokenLabel

    local popout = actionsPage

    local popoutTitle = createLabel(popout, L.LABEL_WISHLIST_ACTIONS, "GameFontNormal")
    popoutTitle:SetPoint("TOPLEFT", popout, "TOPLEFT", 4, -4)

    local notesLabel = createLabel(popout, L.LABEL_WISHLIST_NOTES, "GameFontNormal")
    notesLabel:SetPoint("TOPLEFT", popout, "TOPLEFT", 10, -36)

    local notesBox = CreateFrame("EditBox", "GoalsWishlistNotesBox", popout, "InputBoxTemplate")
    notesBox:SetPoint("TOPLEFT", notesLabel, "BOTTOMLEFT", 0, -2)
    notesBox:SetSize(180, 20)
    notesBox:SetAutoFocus(false)
    bindEscapeClear(notesBox)
    self.wishlistNotesBox = notesBox

    local sourceEntryLabel = createLabel(popout, L.LABEL_WISHLIST_SOURCE, "GameFontNormal")
    sourceEntryLabel:SetPoint("TOPLEFT", popout, "TOPLEFT", 200, -36)

    local sourceEntryBox = CreateFrame("EditBox", "GoalsWishlistSourceBox", popout, "InputBoxTemplate")
    sourceEntryBox:SetPoint("TOPLEFT", sourceEntryLabel, "BOTTOMLEFT", 0, -2)
    sourceEntryBox:SetSize(120, 20)
    sourceEntryBox:SetAutoFocus(false)
    bindEscapeClear(sourceEntryBox)
    self.wishlistSourceEntryBox = sourceEntryBox

    local applyNotesBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    applyNotesBtn:SetPoint("TOPLEFT", notesBox, "BOTTOMLEFT", 0, -6)
    applyNotesBtn:SetSize(60, 20)
    applyNotesBtn:SetText(L.BUTTON_APPLY)
    applyNotesBtn:SetScript("OnClick", function()
        if not UI.selectedWishlistSlot then
            return
        end
        local entry = Goals:GetWishlistItem(UI.selectedWishlistSlot)
        if not entry then
            return
        end
        entry.notes = notesBox:GetText() or ""
        entry.source = sourceEntryBox:GetText() or ""
        Goals:SetWishlistItem(UI.selectedWishlistSlot, entry)
    end)
    self.wishlistApplyNotesButton = applyNotesBtn

    local importLabel = createLabel(popout, L.LABEL_WISHLIST_IMPORT, "GameFontNormal")
    importLabel:SetPoint("TOPLEFT", applyNotesBtn, "BOTTOMLEFT", 0, -10)

    local importFrame = CreateFrame("Frame", "GoalsWishlistImportFrame", popout, "GoalsInsetTemplate")
    importFrame:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -4)
    importFrame:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -10, 0)
    importFrame:SetHeight(110)

    local importScroll = CreateFrame("ScrollFrame", "GoalsWishlistImportScroll", importFrame, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", importFrame, "TOPLEFT", 4, -4)
    importScroll:SetPoint("BOTTOMRIGHT", importFrame, "BOTTOMRIGHT", -26, 4)
    self.wishlistImportScroll = importScroll

    local importBox = CreateFrame("EditBox", "GoalsWishlistImportBox", importScroll)
    importBox:SetMultiLine(true)
    importBox:SetAutoFocus(false)
    importBox:SetFontObject("GameFontHighlightSmall")
    importBox:SetTextInsets(2, 2, 2, 2)
    importBox:SetJustifyH("LEFT")
    importBox:SetPoint("TOPLEFT", importScroll, "TOPLEFT", 0, 0)
    bindEscapeClear(importBox)
    importBox:EnableMouse(true)
    importBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)
    local importMeasure = importFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    importMeasure:SetPoint("TOPLEFT", importFrame, "TOPLEFT", 0, 0)
    importMeasure:SetJustifyH("LEFT")
    importMeasure:SetWordWrap(true)
    importMeasure:SetFontObject(importBox:GetFontObject())
    importMeasure:Hide()
    importBox:SetScript("OnCursorChanged", function(self, x, y)
        local scroll = -y
        if scroll < 0 then
            scroll = 0
        end
        local maxScroll = math.max(0, (self:GetHeight() or 0) - (importScroll:GetHeight() or 0))
        if scroll > maxScroll then
            scroll = maxScroll
        end
        importScroll:SetVerticalScroll(scroll)
    end)
    local function wrapImportText(text, maxWidth)
        local output = {}
        local index = 1
        local length = #text
        if length == 0 then
            return ""
        end
        while index <= length do
            local remaining = text:sub(index)
            importMeasure:SetText(remaining)
            if importMeasure:GetStringWidth() <= maxWidth then
                table.insert(output, remaining)
                break
            end
            local low, high, best = 1, #remaining, 1
            while low <= high do
                local mid = math.floor((low + high) / 2)
                importMeasure:SetText(remaining:sub(1, mid))
                if importMeasure:GetStringWidth() <= maxWidth then
                    best = mid
                    low = mid + 1
                else
                    high = mid - 1
                end
            end
            local cut = best
            local space = remaining:sub(1, cut):match(".*()%s")
            if space and space > 1 then
                cut = space
            end
            table.insert(output, remaining:sub(1, cut))
            index = index + cut
            if remaining:sub(cut, cut):match("%s") then
                index = index + 1
            end
        end
        return table.concat(output, "\n")
    end

    local function updateImportBoxSize()
        local width = importScroll:GetWidth() or 0
        local height = importScroll:GetHeight() or 0
        if width <= 0 then
            width = 1
        end
        importBox:SetWidth(width)
        importMeasure:SetWidth(width)
        importMeasure:SetText(importBox:GetText() or "")
        local textHeight = importMeasure:GetStringHeight() + 6
        if height > textHeight then
            textHeight = height
        end
        importBox:SetHeight(textHeight)
        importScroll:UpdateScrollChildRect()
    end
    local function normalizeImportText()
        if importBox.isWrapping then
            return
        end
        local text = importBox:GetText() or ""
        local raw = text:gsub("\r", ""):gsub("\n", "")
        importBox.rawText = raw
        local width = importScroll:GetWidth() or 0
        if width <= 0 then
            updateImportBoxSize()
            return
        end
        importBox.isWrapping = true
        local wrapped = wrapImportText(raw, width - 6)
        if wrapped ~= text then
            importBox:SetText(wrapped)
        end
        importBox.isWrapping = false
        updateImportBoxSize()
    end
    importBox:SetScript("OnTextChanged", function()
        normalizeImportText()
    end)
    importBox:SetScript("OnEditFocusLost", function()
        normalizeImportText()
    end)
    importScroll:SetScript("OnSizeChanged", function(self)
        local width = self:GetWidth() or 0
        if width > 0 and importBox.SetWidth then
            importBox:SetWidth(width)
        end
        normalizeImportText()
    end)
    local function scheduleImportNormalize()
        if importBox.normalizeScheduled then
            return
        end
        importBox.normalizeScheduled = true
        importScroll:SetScript("OnUpdate", function(self)
            local width = self:GetWidth() or 0
            if width > 0 then
                self:SetScript("OnUpdate", nil)
                importBox.normalizeScheduled = false
                normalizeImportText()
            end
        end)
    end
    importScroll:SetScript("OnShow", function()
        scheduleImportNormalize()
    end)
    importScroll:SetScrollChild(importBox)
    updateImportBoxSize()
    scheduleImportNormalize()
    self.wishlistImportBox = importBox

    local importModeLabel = createLabel(popout, L.WISHLIST_IMPORT_MODE, "GameFontNormal")
    importModeLabel:SetPoint("TOPLEFT", importScroll, "BOTTOMLEFT", 0, -6)

    local importModeDrop = CreateFrame("Frame", "GoalsWishlistImportModeDropdown", popout, "UIDropDownMenuTemplate")
    importModeDrop:SetPoint("TOPLEFT", importModeLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(importModeDrop, 90)
    UIDropDownMenu_SetButtonWidth(importModeDrop, 104)
    importModeDrop.selectedValue = "NEW"
    UIDropDownMenu_Initialize(importModeDrop, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.WISHLIST_IMPORT_NEW
        info.value = "NEW"
        info.func = function()
            importModeDrop.selectedValue = "NEW"
            UIDropDownMenu_SetSelectedValue(importModeDrop, "NEW")
            UI:SetDropdownText(importModeDrop, L.WISHLIST_IMPORT_NEW)
        end
        info.checked = importModeDrop.selectedValue == "NEW"
        UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = L.WISHLIST_IMPORT_ACTIVE
        info.value = "ACTIVE"
        info.func = function()
            importModeDrop.selectedValue = "ACTIVE"
            UIDropDownMenu_SetSelectedValue(importModeDrop, "ACTIVE")
            UI:SetDropdownText(importModeDrop, L.WISHLIST_IMPORT_ACTIVE)
        end
        info.checked = importModeDrop.selectedValue == "ACTIVE"
        UIDropDownMenu_AddButton(info, level)
    end)
    self.wishlistImportMode = importModeDrop
    self:SetDropdownText(importModeDrop, L.WISHLIST_IMPORT_NEW)

    local exportBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    exportBtn:SetPoint("LEFT", importModeDrop, "RIGHT", 0, 2)
    exportBtn:SetSize(60, 20)
    exportBtn:SetText(L.BUTTON_EXPORT)
    exportBtn:SetScript("OnClick", function()
        local text = Goals:ExportActiveWishlist() or ""
        importBox.rawText = text
        importBox:SetText(text)
        importBox:HighlightText()
    end)
    self.wishlistExportButton = exportBtn

    local importBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    importBtn:SetSize(60, 20)
    importBtn:SetText(L.BUTTON_IMPORT)
    importBtn:SetScript("OnClick", function()
        local text = importBox.rawText or importBox:GetText() or ""
        if importModeDrop.selectedValue == "NEW" then
            local ok, err = Goals:ImportWishlistString(text)
            if not ok then
                Goals:Print(err or "Import failed.")
            end
        else
            local data, err = Goals:DeserializeWishlist(text)
            if not data then
                Goals:Print(err or "Import failed.")
                return
            end
            local list = Goals:GetActiveWishlist()
            if list then
                list.items = data.items or {}
                list.updated = time()
                Goals:NotifyDataChanged()
            end
        end
    end)
    self.wishlistImportButton = importBtn

    local wowheadBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    wowheadBtn:SetPoint("TOPLEFT", importModeDrop, "BOTTOMLEFT", 16, -6)
    wowheadBtn:SetSize(130, 20)
    wowheadBtn:SetText(L.BUTTON_IMPORT_WOWHEAD)
    wowheadBtn:SetScript("OnClick", function()
        local text = importBox.rawText or importBox:GetText() or ""
        local items, err = Goals:ImportWowhead(text)
        if not items then
            Goals:Print(err or "Wowhead import failed.")
            return
        end
        local targetId = nil
        if importModeDrop.selectedValue == "NEW" then
            local list = Goals:CreateWishlist("Wowhead Import")
            targetId = list and list.id or nil
        else
            local list = Goals:GetActiveWishlist()
            targetId = list and list.id or nil
        end
        local ok, summary = Goals:ApplyImportedWishlistItems(items, targetId)
        if ok and summary then
            Goals:Print(summary)
            if targetId then
                Goals:SetActiveWishlist(targetId)
            end
        elseif not ok then
            Goals:Print(summary or "Import failed.")
        end
    end)
    self.wishlistWowheadButton = wowheadBtn

    local function formatAtlasListOptions(lists)
        local maxList = 10
        local lines = {}
        local count = math.min(#lists, maxList)
        for i = 1, count do
            local entry = lists[i]
            table.insert(lines, string.format("%d) %s", i, entry.name or entry.key))
        end
        if #lists > maxList then
            table.insert(lines, string.format("...and %d more (type full name).", #lists - maxList))
        end
        return table.concat(lines, "\n")
    end

    local function showAtlasSelectPopup(lists)
        StaticPopupDialogs.GOALS_ATLAS_SELECT = StaticPopupDialogs.GOALS_ATLAS_SELECT or {
            text = "Multiple AtlasLoot wishlists found.",
            button1 = "Import",
            button2 = CANCEL,
            hasEditBox = 1,
            editBoxWidth = 220,
            OnShow = function(selfPopup, data)
                selfPopup.editBox:SetText("")
                selfPopup.editBox:SetFocus()
                if data and data.message then
                    selfPopup.text:SetText(data.message)
                end
            end,
            OnAccept = function(selfPopup, data)
                local input = selfPopup.editBox:GetText() or ""
                local listsData = data and data.lists or {}
                local selected = nil
                local index = tonumber(input)
                if index and listsData[index] then
                    selected = listsData[index]
                elseif input ~= "" then
                    for _, entry in ipairs(listsData) do
                        if entry.name == input or entry.key == input then
                            selected = entry
                            break
                        end
                    end
                end
                if not selected then
                    Goals:Print("No matching AtlasLoot wishlist found.")
                    return
                end
                Goals.db.settings.atlasSelectedListKey = selected.key
                if Goals.ImportAtlasLootWishlist then
                    local ok, msg = Goals:ImportAtlasLootWishlist(selected.key)
                    if msg then
                        Goals:Print(msg)
                    end
                    if ok and Goals.UI and Goals.UI.UpdateWishlistUI then
                        Goals.UI:UpdateWishlistUI()
                    end
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        local message = "Multiple AtlasLoot wishlists found.\nEnter number or name to import:\n" .. formatAtlasListOptions(lists)
        StaticPopup_Show("GOALS_ATLAS_SELECT", nil, nil, { lists = lists, message = message })
    end

    local function startAtlasImport()
        if not Goals.GetAtlasLootWishlistSelection then
            return
        end
        if not (Goals.db and Goals.db.settings) then
            return
        end
        local lists, selected = Goals:GetAtlasLootWishlistSelection()
        if #lists == 0 then
            Goals:Print("No AtlasLoot wishlist items found.")
            return
        end
        if #lists == 1 then
            selected = lists[1]
        end
        if not selected then
            showAtlasSelectPopup(lists)
            return
        end
        Goals.db.settings.atlasSelectedListKey = selected.key
        if Goals.ImportAtlasLootWishlist then
            local ok, msg = Goals:ImportAtlasLootWishlist(selected.key)
            if msg then
                Goals:Print(msg)
            end
            if ok and Goals.UI and Goals.UI.UpdateWishlistUI then
                Goals.UI:UpdateWishlistUI()
            end
        end
    end

    if Goals.HasAtlasLootEnhanced and Goals:HasAtlasLootEnhanced() then
        local atlasBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
        atlasBtn:SetPoint("LEFT", wowheadBtn, "RIGHT", 6, 0)
        atlasBtn:SetSize(120, 20)
        atlasBtn:SetText("Import AtlasLoot")
        atlasBtn:SetScript("OnClick", function()
            startAtlasImport()
        end)
        self.wishlistAtlasButton = atlasBtn
    else
        self.wishlistAtlasButton = nil
    end

    if Goals and Goals.db and Goals.db.settings and not Goals.db.settings.atlasImportPrompted then
        if Goals.HasAtlasLootEnhanced and Goals:HasAtlasLootEnhanced() then
            StaticPopupDialogs.GOALS_ATLAS_IMPORT = StaticPopupDialogs.GOALS_ATLAS_IMPORT or {
                text = "AtlasLoot wishlist detected. Import now?",
                button1 = "Import",
                button2 = CANCEL,
                OnAccept = function()
                    Goals.db.settings.atlasImportPrompted = true
                    startAtlasImport()
                end,
                OnCancel = function()
                    Goals.db.settings.atlasImportPrompted = true
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
            }
            StaticPopup_Show("GOALS_ATLAS_IMPORT")
        else
            Goals.db.settings.atlasImportPrompted = true
        end
    end

    local syncLabel = createLabel(popout, L.LABEL_WISHLIST_SYNC, "GameFontNormal")
    syncLabel:SetPoint("TOPLEFT", wowheadBtn, "BOTTOMLEFT", 0, -10)

    local syncLoadBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    syncLoadBtn:SetPoint("TOPLEFT", syncLabel, "BOTTOMLEFT", -6, -4)
    syncLoadBtn:SetSize(90, 20)
    syncLoadBtn:SetText(L.BUTTON_SYNC_LOAD)
    syncLoadBtn:SetScript("OnClick", function()
        if Goals.Comm and Goals.Comm.RequestWishlistSync then
            Goals.Comm:RequestWishlistSync()
        end
    end)
    self.wishlistSyncLoadButton = syncLoadBtn

    local syncSaveBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    syncSaveBtn:SetPoint("LEFT", syncLoadBtn, "RIGHT", 6, 0)
    syncSaveBtn:SetSize(90, 20)
    syncSaveBtn:SetText(L.BUTTON_SYNC_SAVE)
    syncSaveBtn:SetScript("OnClick", function()
        if Goals.Comm and Goals.Comm.SendWishlistSync then
            Goals.Comm:SendWishlistSync(nil)
        end
    end)
    self.wishlistSyncSaveButton = syncSaveBtn

    local announceLabel = createLabel(popout, L.LABEL_WISHLIST_ANNOUNCE, "GameFontNormal")
    announceLabel:SetPoint("TOPLEFT", syncLoadBtn, "BOTTOMLEFT", 0, -8)
    announceLabel:SetPoint("LEFT", popoutTitle, "LEFT", 0, 0)

    local announceCheck = CreateFrame("CheckButton", nil, popout, "UICheckButtonTemplate")
    announceCheck:SetPoint("TOPLEFT", announceLabel, "BOTTOMLEFT", -4, -2)
    setCheckText(announceCheck, L.CHECK_WISHLIST_ANNOUNCE)
    announceCheck:SetScript("OnClick", function(selfCheck)
        Goals.db.settings.wishlistAnnounce = selfCheck:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end)
    self.wishlistAnnounceCheck = announceCheck

    local soundToggle = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    soundToggle:SetPoint("LEFT", announceLabel, "RIGHT", 6, 0)
    soundToggle:SetSize(36, 20)
    soundToggle:SetText("SND")
    soundToggle:SetScript("OnClick", function()
        local enabled = Goals.db.settings.wishlistPopupSound and true or false
        Goals.db.settings.wishlistPopupSound = not enabled
        if Goals.db.settings.wishlistPopupSound then
            soundToggle:SetText("SND")
        else
            soundToggle:SetText("MUT")
        end
        Goals:NotifyDataChanged()
    end)
    self.wishlistPopupSoundToggle = soundToggle

    local disablePopupCheck = CreateFrame("CheckButton", nil, popout, "UICheckButtonTemplate")
    disablePopupCheck:SetPoint("LEFT", announceCheck, "RIGHT", 120, 0)
    setCheckText(disablePopupCheck, "Disable popup")
    disablePopupCheck:SetScript("OnClick", function(selfCheck)
        Goals.db.settings.wishlistPopupDisabled = selfCheck:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end)
    self.wishlistPopupDisableCheck = disablePopupCheck

    self.wishlistChannelDrop = nil
    if Goals and Goals.db and Goals.db.settings then
        Goals.db.settings.wishlistAnnounceChannel = "AUTO"
    end

    if slots[1] then
        self.selectedWishlistSlot = slots[1].key
    end
end

function UI:CreateSettingsTab(page)
    local leftInset = CreateFrame("Frame", "GoalsSettingsInset", page, "GoalsInsetTemplate")
    leftInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    leftInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    leftInset:SetWidth(350)
    self.settingsInset = leftInset

    local rightInset = CreateFrame("Frame", "GoalsSettingsActionsInset", page, "GoalsInsetTemplate")
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 12, 0)
    rightInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.settingsActionsInset = rightInset

    local combineCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    combineCheck:SetPoint("TOPLEFT", leftInset, "TOPLEFT", 12, -12)
    setCheckText(combineCheck, L.CHECK_COMBINE_HISTORY)
    combineCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("combineBossHistory", selfBtn:GetChecked() and true or false)
    end)
    self.combineCheck = combineCheck

    local minimapCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combineCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(minimapCheck, L.CHECK_MINIMAP)
    minimapCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.minimap.hide = not selfBtn:GetChecked()
        UI:UpdateMinimapButton()
    end)
    self.minimapCheck = minimapCheck

    local autoMinCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    autoMinCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(autoMinCheck, L.CHECK_AUTO_MINIMIZE_COMBAT)
    autoMinCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.autoMinimizeCombat = selfBtn:GetChecked() and true or false
    end)
    self.autoMinimizeCheck = autoMinCheck

    local localOnlyCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    localOnlyCheck:SetPoint("TOPLEFT", autoMinCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(localOnlyCheck, "Disable sync (local only)")
    localOnlyCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.localOnly = selfBtn:GetChecked() and true or false
    end)
    self.localOnlyCheck = localOnlyCheck

    local function hasDBM()
        if DBM and DBM.RegisterCallback then
            return true
        end
        if IsAddOnLoaded then
            return IsAddOnLoaded("DBM-Core") or IsAddOnLoaded("DBM-GUI")
        end
        return false
    end

    if hasDBM() then
        local dbmCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
        dbmCheck:SetPoint("TOPLEFT", localOnlyCheck, "BOTTOMLEFT", 0, -8)
        setCheckText(dbmCheck, L.CHECK_DBM_INTEGRATION)
        dbmCheck:SetScript("OnClick", function(selfBtn)
            Goals.db.settings.dbmIntegration = selfBtn:GetChecked() and true or false
            if Goals.db.settings.dbmIntegration and Goals.Events and Goals.Events.InitDBMCallbacks then
                Goals.Events:InitDBMCallbacks()
            end
        end)
        self.dbmIntegrationCheck = dbmCheck

        local dbmWishlistCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
        dbmWishlistCheck:SetPoint("TOPLEFT", dbmCheck, "BOTTOMLEFT", 0, -8)
        setCheckText(dbmWishlistCheck, L.CHECK_DBM_WISHLIST)
        dbmWishlistCheck:SetScript("OnClick", function(selfBtn)
            Goals.db.settings.wishlistDbmIntegration = selfBtn:GetChecked() and true or false
        end)
        self.wishlistDbmIntegrationCheck = dbmWishlistCheck
    end

    setupSudoDevPopup()
    setupSaveTableHelpPopup()

    local actionsTitle = createLabel(rightInset, "Data Management", "GameFontNormal")
    actionsTitle:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 10, -10)

    local function createActionButton(text, onClick)
        local btn = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
        btn:SetSize(180, 20)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local clearPointsBtn = createActionButton("Clear All Points", function()
        if Goals and Goals.ClearAllPointsLocal then
            Goals:ClearAllPointsLocal()
        end
    end)
    clearPointsBtn:SetPoint("TOPLEFT", actionsTitle, "BOTTOMLEFT", 2, -10)

    local clearPlayersBtn = createActionButton("Clear Players List", function()
        if Goals and Goals.ClearPlayersLocal then
            Goals:ClearPlayersLocal()
        end
    end)
    clearPlayersBtn:SetPoint("TOPLEFT", clearPointsBtn, "BOTTOMLEFT", 0, -6)

    local clearHistoryBtn = createActionButton("Clear History", function()
        if Goals and Goals.ClearHistoryLocal then
            Goals:ClearHistoryLocal()
        end
    end)
    clearHistoryBtn:SetPoint("TOPLEFT", clearPlayersBtn, "BOTTOMLEFT", 0, -6)

    local clearAllBtn = createActionButton("Clear All", function()
        if Goals and Goals.ClearAllLocal then
            Goals:ClearAllLocal()
        end
    end)
    clearAllBtn:SetPoint("TOPLEFT", clearHistoryBtn, "BOTTOMLEFT", 0, -10)

    local miniTitle = createLabel(rightInset, L.LABEL_MINI_TRACKER, "GameFontNormal")
    miniTitle:SetPoint("TOPLEFT", clearAllBtn, "BOTTOMLEFT", 0, -16)

    local miniBtn = createActionButton(L.BUTTON_TOGGLE_MINI_TRACKER, function()
        if UI and UI.ToggleMiniTracker then
            UI:ToggleMiniTracker()
        end
    end)
    miniBtn:SetPoint("TOPLEFT", miniTitle, "BOTTOMLEFT", 0, -6)
    self.miniTrackerButton = miniBtn

    local miniResetBtn = createActionButton("Reset Mini Position", function()
        if UI and UI.ResetMiniTrackerPosition then
            UI:ResetMiniTrackerPosition()
        end
    end)
    miniResetBtn:SetPoint("TOPLEFT", miniBtn, "BOTTOMLEFT", 0, -6)
    self.miniTrackerResetButton = miniResetBtn

    local tableTitle = createLabel(rightInset, L.LABEL_SAVE_TABLES, "GameFontNormal")
    tableTitle:SetPoint("TOPLEFT", miniResetBtn, "BOTTOMLEFT", 0, -16)

    local helpBtn = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
    helpBtn:SetSize(22, 20)
    helpBtn:SetText("?")
    helpBtn:SetPoint("LEFT", tableTitle, "RIGHT", 6, 0)
    helpBtn:SetScript("OnClick", function()
        if StaticPopup_Show then
            StaticPopup_Show("GOALS_SAVE_TABLE_HELP")
        end
    end)
    self.saveTableHelpButton = helpBtn

    local autoSeenCheck = CreateFrame("CheckButton", nil, rightInset, "UICheckButtonTemplate")
    autoSeenCheck:SetPoint("TOPLEFT", tableTitle, "BOTTOMLEFT", 0, -6)
    setCheckText(autoSeenCheck, L.CHECK_AUTOLOAD_SEEN)
    autoSeenCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.tableAutoLoadSeen = selfBtn:GetChecked() and true or false
    end)
    self.autoLoadSeenCheck = autoSeenCheck

    local combinedCheck = CreateFrame("CheckButton", nil, rightInset, "UICheckButtonTemplate")
    combinedCheck:SetPoint("TOPLEFT", autoSeenCheck, "BOTTOMLEFT", 0, -6)
    setCheckText(combinedCheck, L.CHECK_COMBINED_TABLES)
    combinedCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.tableCombined = selfBtn:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end)
    self.combinedTablesCheck = combinedCheck

    local syncSeenBtn = createActionButton(L.BUTTON_SYNC_SEEN, function()
        if Goals and Goals.MergeSeenPlayersIntoCurrent then
            Goals:MergeSeenPlayersIntoCurrent()
        end
    end)
    syncSeenBtn:SetPoint("TOPLEFT", combinedCheck, "BOTTOMLEFT", 4, -8)
    self.syncSeenButton = syncSeenBtn

    local editTitle = createLabel(rightInset, "Local Editing", "GameFontNormal")
    editTitle:SetPoint("TOPLEFT", syncSeenBtn, "BOTTOMLEFT", -2, -16)

    local sudoBtn = createActionButton("", function()
        if Goals.db.settings.sudoDev then
            Goals.db.settings.sudoDev = false
            UI:Refresh()
            return
        end
        if StaticPopup_Show then
            StaticPopup_Show("GOALS_SUDO_DEV")
        end
    end)
    sudoBtn:SetPoint("TOPLEFT", editTitle, "BOTTOMLEFT", 2, -8)
    self.sudoDevButton = sudoBtn
end

function UI:CreateUpdateTab(page)
    local inset = CreateFrame("Frame", "GoalsUpdateInset", page, "GoalsInsetTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)

    local title = createLabel(inset, L.UPDATE_TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -12)

    local status = createLabel(inset, "", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    self.updateStatusText = status

    local versionLine = createLabel(inset, "", "GameFontHighlightSmall")
    versionLine:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -6)
    self.updateVersionText = versionLine

    local urlLabel = createLabel(inset, L.UPDATE_DOWNLOAD_LABEL, "GameFontNormal")
    urlLabel:SetPoint("TOPLEFT", versionLine, "BOTTOMLEFT", 0, -12)

    local urlText = createLabel(inset, "", "GameFontHighlightSmall")
    urlText:SetPoint("TOPLEFT", urlLabel, "BOTTOMLEFT", 0, -4)
    urlText:SetWidth(520)
    urlText:SetJustifyH("LEFT")
    self.updateUrlText = urlText

    local downloadBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    downloadBtn:SetSize(120, 20)
    downloadBtn:SetText(L.UPDATE_DOWNLOAD_BUTTON)
    downloadBtn:SetPoint("LEFT", urlLabel, "RIGHT", 8, 0)
    downloadBtn:SetScript("OnClick", function()
        if not UI.updateUrl or UI.updateUrl == "" then
            return
        end
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat(UI.updateUrl)
        else
            Goals:Print(UI.updateUrl)
        end
    end)
    self.updateDownloadButton = downloadBtn

    local copyHint = createLabel(inset, L.UPDATE_COPY_HINT, "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", urlText, "BOTTOMLEFT", 0, -6)

    local step1 = createLabel(inset, L.UPDATE_STEP1, "GameFontHighlight")
    step1:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", 0, -14)
    step1:SetWidth(520)
    step1:SetJustifyH("LEFT")

    local step2 = createLabel(inset, L.UPDATE_STEP2, "GameFontHighlight")
    step2:SetPoint("TOPLEFT", step1, "BOTTOMLEFT", 0, -6)
    step2:SetWidth(520)
    step2:SetJustifyH("LEFT")

    local step3 = createLabel(inset, L.UPDATE_STEP3, "GameFontHighlight")
    step3:SetPoint("TOPLEFT", step2, "BOTTOMLEFT", 0, -6)
    step3:SetWidth(520)
    step3:SetJustifyH("LEFT")

    local reloadBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 20)
    reloadBtn:SetText(L.UPDATE_RELOAD_BUTTON)
    reloadBtn:SetPoint("LEFT", step3, "RIGHT", 8, 0)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)

    local dismissBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    dismissBtn:SetSize(120, 20)
    dismissBtn:SetText("Dismiss")
    dismissBtn:SetPoint("TOPLEFT", step3, "BOTTOMLEFT", 0, -10)
    dismissBtn:SetScript("OnClick", function()
        local installedMajor, installedMinor, availableMajor, availableMinor = getUpdateInfo()
        local available = isUpdateAvailable()
        if available and Goals and Goals.db and Goals.db.settings then
            Goals.db.settings.updateSeenMajor = availableMajor
            Goals.db.settings.updateSeenVersion = availableMinor
            Goals.db.settings.updateHasBeenSeen = true
            if Goals.UI then
                Goals.UI:RefreshUpdateTab()
                Goals.UI:UpdateUpdateTabGlow()
            end
            Goals:Print("Update dismissed.")
        end
    end)
    self.updateDismissButton = dismissBtn

    self:RefreshUpdateTab()
end

function UI:CreateDevTab(page)
    local inset = CreateFrame("Frame", "GoalsDevInset", page, "GoalsInsetTemplate")
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

    local resetUpdateBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    resetUpdateBtn:SetSize(160, 20)
    resetUpdateBtn:SetText("Reset Update Seen")
    resetUpdateBtn:SetPoint("TOPLEFT", syncBtn, "BOTTOMLEFT", 0, -8)
    resetUpdateBtn:SetScript("OnClick", function()
        if Goals.db and Goals.db.settings then
            Goals.db.settings.updateSeenMajor = 0
            Goals.db.settings.updateSeenVersion = 0
            Goals.db.settings.updateAvailableMajor = 0
            Goals.db.settings.updateAvailableVersion = 0
            Goals.db.settings.updateHasBeenSeen = false
            if Goals.UI then
                Goals.UI:RefreshUpdateTab()
                Goals.UI:UpdateUpdateTabGlow()
            end
            if Goals and Goals.GetInstalledUpdateVersion then
                local installedMajor = Goals:GetUpdateMajorVersion()
                local installedMinor = Goals:GetInstalledUpdateVersion()
                Goals:Print("Update notice reset. Installed v" .. installedMajor .. "." .. installedMinor .. ", available v0.")
            else
                Goals:Print("Update notice reset.")
            end
        end
    end)

    local simulateUpdateBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    simulateUpdateBtn:SetSize(160, 20)
    simulateUpdateBtn:SetText("Simulate Update")
    simulateUpdateBtn:SetPoint("TOPLEFT", resetUpdateBtn, "BOTTOMLEFT", 0, -8)
    simulateUpdateBtn:SetScript("OnClick", function()
        if Goals and Goals.GetInstalledUpdateVersion and Goals.HandleRemoteVersion then
            local installedMajor = Goals:GetUpdateMajorVersion()
            local installedMinor = Goals:GetInstalledUpdateVersion()
            local payload = string.format("%d.%d", installedMajor, installedMinor + 1)
            Goals:HandleRemoteVersion(payload, Goals:GetPlayerName())
            Goals:Print("Simulated update v" .. payload .. ".")
        end
    end)

    local testDbmBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testDbmBtn:SetSize(160, 20)
    testDbmBtn:SetText("Test Wishlist (DBM)")
    testDbmBtn:SetPoint("TOPLEFT", killBtn, "TOPRIGHT", 30, 0)
    testDbmBtn:SetScript("OnClick", function()
        if Goals and Goals.TestWishlistNotification then
            Goals:TestWishlistNotification(nil, true)
        end
    end)

    local testLocalBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testLocalBtn:SetSize(160, 20)
    testLocalBtn:SetText("Test Wishlist (Local)")
    testLocalBtn:SetPoint("TOPLEFT", testDbmBtn, "BOTTOMLEFT", 0, -6)
    testLocalBtn:SetScript("OnClick", function()
        if Goals and Goals.TestWishlistNotification then
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local function getWishlistTestResetDelay()
        local count = 3
        if Goals and Goals.db and Goals.db.settings then
            count = tonumber(Goals.db.settings.devTestWishlistItems) or count
        end
        if count < 1 then
            count = 1
        elseif count > 8 then
            count = 8
        end
        if Goals and Goals.GetDbmLootBannerDuration then
            return Goals:GetDbmLootBannerDuration(count) + 1
        end
        return 8
    end

    local testArcaneBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testArcaneBtn:SetSize(160, 20)
    testArcaneBtn:SetText("Test Local (Arcane)")
    testArcaneBtn:SetPoint("TOPLEFT", testLocalBtn, "BOTTOMLEFT", 0, -6)
    testArcaneBtn:SetScript("OnClick", function()
        if Goals and Goals.ApplyWishlistBannerTexture and Goals.TestWishlistNotification then
            local path = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\ArcaneGlow"
            Goals.WishlistBannerTextureTest = true
            Goals:ApplyWishlistBannerTexture(path)
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local testArcaneBagBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testArcaneBagBtn:SetSize(160, 20)
    testArcaneBagBtn:SetText("Test Local (NewBag)")
    testArcaneBagBtn:SetPoint("TOPLEFT", testArcaneBtn, "BOTTOMLEFT", 0, -6)
    testArcaneBagBtn:SetScript("OnClick", function()
        if Goals and Goals.ApplyWishlistBannerTexture and Goals.TestWishlistNotification then
            local path = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\ArcaneGlow-NewBag"
            Goals.WishlistBannerTextureTest = true
            Goals:ApplyWishlistBannerTexture(path)
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local testArcaneGlowMetalBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testArcaneGlowMetalBtn:SetSize(160, 20)
    testArcaneGlowMetalBtn:SetText("Test Local (GlowMetal)")
    testArcaneGlowMetalBtn:SetPoint("TOPLEFT", testArcaneBagBtn, "BOTTOMLEFT", 0, -6)
    testArcaneGlowMetalBtn:SetScript("OnClick", function()
        if Goals and Goals.ApplyWishlistBannerTexture and Goals.TestWishlistNotification then
            local path = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\ArcaneGlow-NewBag-GlowMetal"
            Goals.WishlistBannerTextureTest = true
            Goals:ApplyWishlistBannerTexture(path)
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local updateDebug = createLabel(inset, "", "GameFontHighlightSmall")
    updateDebug:SetPoint("TOPLEFT", simulateUpdateBtn, "BOTTOMLEFT", 0, -12)
    updateDebug:SetWidth(520)
    updateDebug:SetJustifyH("LEFT")
    self.updateDebugText = updateDebug

    local devBossCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    devBossCheck:SetPoint("TOPLEFT", updateDebug, "BOTTOMLEFT", 0, -8)
    setCheckText(devBossCheck, L.DEV_TEST_BOSS)
    devBossCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.devTestBoss = selfBtn:GetChecked() and true or false
        if Goals.Events and Goals.Events.BuildBossLookup then
            Goals.Events:BuildBossLookup()
        end
    end)
    self.devBossCheck = devBossCheck

    local debugCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", devBossCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(debugCheck, "Enable debug log")
    debugCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.debug = selfBtn:GetChecked() and true or false
    end)
    self.debugCheck = debugCheck

    local wishlistChatCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    wishlistChatCheck:SetPoint("TOPLEFT", testArcaneGlowMetalBtn, "BOTTOMLEFT", 0, -10)
    setCheckText(wishlistChatCheck, "Test wishlist chat messages")
    wishlistChatCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.devTestWishlistChat = selfBtn:GetChecked() and true or false
    end)
    self.wishlistChatCheck = wishlistChatCheck

    local wishlistCountLabel = createLabel(inset, "Test wishlist items (1-8)", "GameFontNormalSmall")
    wishlistCountLabel:SetPoint("TOPLEFT", wishlistChatCheck, "BOTTOMLEFT", 0, -10)
    local wishlistCountBox = CreateFrame("EditBox", "GoalsDevWishlistCountBox", inset, "InputBoxTemplate")
    wishlistCountBox:SetSize(40, 18)
    wishlistCountBox:SetPoint("LEFT", wishlistCountLabel, "RIGHT", 8, 0)
    wishlistCountBox:SetNumeric(true)
    wishlistCountBox:SetMaxLetters(2)
    wishlistCountBox:SetAutoFocus(false)
    wishlistCountBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        local value = tonumber(selfBox:GetText()) or 1
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        Goals.db.settings.devTestWishlistItems = value
        selfBox:SetText(tostring(value))
    end)
    self.wishlistTestCountBox = wishlistCountBox
end

function UI:CreateDebugTab(page)
    local inset = CreateFrame("Frame", "GoalsDebugInset", page, "GoalsInsetTemplate")
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)

    local title = createLabel(inset, "Debug Log", "GameFontNormal")
    title:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)

    local clearBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 20)
    clearBtn:SetText("Clear Log")
    clearBtn:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -10)
    clearBtn:SetScript("OnClick", function()
        if Goals and Goals.ClearDebugLog then
            Goals:ClearDebugLog()
        end
    end)
    self.debugClearButton = clearBtn

    local copyBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 20)
    copyBtn:SetText("Copy Log")
    copyBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
    copyBtn:SetScript("OnClick", function()
        if UI and UI.PopulateDebugCopy then
            UI:PopulateDebugCopy()
        end
    end)
    self.debugCopyButton = copyBtn

    local hint = createLabel(inset, "Select all text below and copy to share.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    self.debugCopyHint = hint

    local scroll = CreateFrame("ScrollFrame", "GoalsDebugLogScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 2, -48)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 110)
    scroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, DEBUG_ROW_HEIGHT, function()
            UI:UpdateDebugLogList()
        end)
    end)
    self.debugLogScroll = scroll

    self.debugLogRows = {}
    for i = 1, DEBUG_ROWS do
        local row = CreateFrame("Frame", nil, inset)
        row:SetHeight(DEBUG_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -34 - (i - 1) * DEBUG_ROW_HEIGHT)
        row:SetPoint("RIGHT", inset, "RIGHT", -6, 0)

        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", 0, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        row.text = text

        self.debugLogRows[i] = row
    end

    local copyScroll = CreateFrame("ScrollFrame", "GoalsDebugCopyScroll", inset, "UIPanelScrollFrameTemplate")
    copyScroll:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 6, 10)
    copyScroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 10)
    copyScroll:SetHeight(90)
    self.debugCopyScroll = copyScroll

    local edit = CreateFrame("EditBox", nil, copyScroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(copyScroll:GetWidth())
    bindEscapeClear(edit)
    copyScroll:SetScrollChild(edit)
    self.debugCopyBox = edit
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
                row.pointsText:SetPoint("RIGHT", row, "RIGHT", -28, 0)
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
    if self.disablePointGainCheck then
        self.disablePointGainCheck:SetChecked(Goals.db.settings.disablePointGain and true or false)
        setShown(self.disablePointGainCheck, hasPointGainAccess())
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
    if entry.kind == "BOSSKILL" and data.players then
        local count = #data.players
        return string.format("Gave %s: +%d (%s)", formatPlayersCount(count), data.points or 0, data.encounter or "Boss")
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
        if data.players and #data.players >= 3 then
            return string.format("Gave %s: %s", formatPlayersCount(#data.players), itemLink)
        end
        if quality and quality < 4 then
            return string.format("%s Looted: %s", colorizeName(data.player or ""), itemLink)
        end
        if data.reset then
            local before = tonumber(data.resetBefore) or 0
            local playerName = colorizeName(data.player or "")
            return string.format("Gave %s: %s\n%s's points set to 0 (-%d).", playerName, itemLink, playerName, before)
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
    local yOffset = -22
    local hasRainbow = false
    for i = 1, HISTORY_ROWS do
        local row = self.historyRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            row.timeText:SetText(formatTime(entry.ts))
            row.rainbowData = nil
            if entry.kind == "BOSSKILL" and entry.data and entry.data.players then
                local count = #entry.data.players
                row.rainbowData = {
                    kind = "boss",
                    count = count,
                    points = entry.data.points or 0,
                    encounter = entry.data.encounter or "Boss",
                }
                row.text:SetText(string.format("Gave %s: +%d (%s)", formatPlayersCount(count), entry.data.points or 0, entry.data.encounter or "Boss"))
                hasRainbow = true
            elseif entry.kind == "LOOT_ASSIGN" and entry.data and entry.data.players and #entry.data.players >= 3 then
                local count = #entry.data.players
                row.rainbowData = {
                    kind = "loot",
                    count = count,
                    itemLink = entry.data.item or "",
                }
                row.text:SetText(string.format("Gave %s: %s", formatPlayersCount(count), entry.data.item or ""))
                hasRainbow = true
            else
                row.text:SetText(self:FormatHistoryEntry(entry))
            end
            local isReset = entry.kind == "LOOT_ASSIGN" and entry.data and entry.data.reset
            if isReset then
                row:SetHeight(HISTORY_ROW_HEIGHT_DOUBLE)
            else
                row:SetHeight(ROW_HEIGHT)
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.historyInset, "TOPLEFT", 6, yOffset)
            row:SetPoint("RIGHT", self.historyInset, "RIGHT", -6, 0)
            yOffset = yOffset - row:GetHeight()
        else
            row:Hide()
            row.rainbowData = nil
        end
    end
    if hasRainbow then
        self:StartRainbowTicker()
    end
end

function UI:UpdateDebugLogList()
    if not self.debugLogScroll or not self.debugLogRows then
        return
    end
    local data = (Goals and Goals.GetDebugLog and Goals:GetDebugLog()) or {}
    local offset = FauxScrollFrame_GetOffset(self.debugLogScroll) or 0
    FauxScrollFrame_Update(self.debugLogScroll, #data, DEBUG_ROWS, DEBUG_ROW_HEIGHT)
    for i = 1, DEBUG_ROWS do
        local row = self.debugLogRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            local ts = entry.ts and formatTime(entry.ts) or ""
            row.text:SetText(string.format("%s %s", ts, entry.msg or ""))
        else
            row:Hide()
            row.text:SetText("")
        end
    end
end

function UI:UpdateWishlistManagerList()
    if not self.wishlistManagerScroll or not self.wishlistManagerRows then
        return
    end
    local data = Goals:EnsureWishlistData()
    local lists = data and data.lists or {}
    local offset = FauxScrollFrame_GetOffset(self.wishlistManagerScroll) or 0
    FauxScrollFrame_Update(self.wishlistManagerScroll, #lists, #self.wishlistManagerRows, ROW_HEIGHT)
    for i = 1, #self.wishlistManagerRows do
        local row = self.wishlistManagerRows[i]
        local index = i + offset
        local list = lists[index]
        if list then
            row:Show()
            row.listId = list.id
            local count = 0
            for _ in pairs(list.items or {}) do
                count = count + 1
            end
            row.text:SetText(string.format("%s (%d)", list.name or "Wishlist", count))
            if data and data.activeId == list.id then
                row.text:SetTextColor(0.1, 1, 0.1)
            else
                row.text:SetTextColor(1, 1, 1)
            end
        else
            row:Hide()
            row.listId = nil
        end
    end
end

function UI:UpdateWishlistSearchResults()
    if not self.wishlistResultsScroll or not self.wishlistResultsRows then
        return
    end
    local query = self.wishlistSearchBox and self.wishlistSearchBox:GetText() or ""
    self.wishlistResults = Goals:SearchWishlistItems(query, nil)
    local offset = FauxScrollFrame_GetOffset(self.wishlistResultsScroll) or 0
    FauxScrollFrame_Update(self.wishlistResultsScroll, #self.wishlistResults, #self.wishlistResultsRows, ROW_HEIGHT)
    for i = 1, #self.wishlistResultsRows do
        local row = self.wishlistResultsRows[i]
        local index = i + offset
        local entry = self.wishlistResults[index]
        if entry then
            row:Show()
            row.entry = entry
            row.text:SetText(entry.name or ("Item " .. tostring(entry.id or "")))
            if entry.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality] then
                local color = ITEM_QUALITY_COLORS[entry.quality]
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            if entry.texture then
                row.icon:SetTexture(entry.texture)
                row.icon:Show()
            else
                row.icon:SetTexture(nil)
                row.icon:Hide()
            end
            if self.selectedWishlistResult == entry then
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
    if self.wishlistAddSlotButton then
        if self.selectedWishlistSlot and self.selectedWishlistResult then
            self.wishlistAddSlotButton:Enable()
        else
            self.wishlistAddSlotButton:Disable()
        end
    end
    if self.wishlistClearSlotButton then
        if self.selectedWishlistSlot then
            self.wishlistClearSlotButton:Enable()
        else
            self.wishlistClearSlotButton:Disable()
        end
    end
    if self.UpdateWishlistTokenDisplay then
        self:UpdateWishlistTokenDisplay()
    end
end

function UI:UpdateWishlistTokenDisplay()
    if not self.wishlistTokenRows or not self.wishlistTokenScroll then
        return
    end
    local list = Goals:GetActiveWishlist()
    local tokens = {}
    local ordered = {}
    local foundMap = nil
    if list and list.id and Goals.GetWishlistFoundMap then
        foundMap = Goals:GetWishlistFoundMap(list.id)
    end
    local slotRank = {}
    if Goals.GetWishlistSlotDefs then
        local defs = Goals:GetWishlistSlotDefs() or {}
        for index, def in ipairs(defs) do
            if def and def.key then
                slotRank[def.key] = index
            end
        end
    end
    for slotKey, entry in pairs(list and list.items or {}) do
        if entry and entry.itemId then
            local isClaimed = foundMap and (foundMap[entry.itemId] or (entry.tokenId and foundMap[entry.tokenId]))
            if not isClaimed then
                local tokenId = Goals.GetArmorTokenForItem and Goals:GetArmorTokenForItem(entry.itemId) or entry.tokenId
                if tokenId and tokenId > 0 then
                    local rank = slotRank[slotKey] or 999
                    if tokens[tokenId] then
                        tokens[tokenId].count = tokens[tokenId].count + 1
                        if rank < tokens[tokenId].rank then
                            tokens[tokenId].rank = rank
                        end
                    else
                        tokens[tokenId] = { count = 1, rank = rank }
                    end
                end
            end
        end
    end
    for tokenId, count in pairs(tokens) do
        table.insert(ordered, { id = tokenId, count = count.count, rank = count.rank })
    end
    table.sort(ordered, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.id < b.id
    end)
    if self.wishlistTokenEmpty then
        setShown(self.wishlistTokenEmpty, #ordered == 0)
    end
    local visibleRows = math.min(#self.wishlistTokenRows, math.max(#ordered, 1))
    local insetHeight = (visibleRows * ROW_HEIGHT) + 12
    if self.wishlistTokenInset then
        self.wishlistTokenInset:SetHeight(insetHeight)
    end
    if self.wishlistTokenScroll then
        if #ordered > #self.wishlistTokenRows then
            self.wishlistTokenScroll:Show()
        else
            self.wishlistTokenScroll:Hide()
        end
    end
    local offset = FauxScrollFrame_GetOffset(self.wishlistTokenScroll) or 0
    FauxScrollFrame_Update(self.wishlistTokenScroll, #ordered, #self.wishlistTokenRows, ROW_HEIGHT)
    for i = 1, #self.wishlistTokenRows do
        local row = self.wishlistTokenRows[i]
        local index = i + offset
        local entry = ordered[index]
        if entry then
            row:Show()
            local cached = Goals.CacheItemById and Goals:CacheItemById(entry.id) or nil
            local name = cached and cached.name or ("Token " .. tostring(entry.id))
            if entry.count and entry.count > 1 then
                name = name .. " x" .. tostring(entry.count)
            end
            row.text:SetText(name)
            row.itemId = entry.id
            row.itemLink = cached and cached.link or nil
            if cached and cached.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[cached.quality] then
                local color = ITEM_QUALITY_COLORS[cached.quality]
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            if cached and cached.texture then
                row.icon:SetTexture(cached.texture)
                row.icon:Show()
            else
                row.icon:SetTexture(nil)
                row.icon:Hide()
            end
        else
            row:Hide()
            row.itemId = nil
            row.itemLink = nil
        end
    end
end

function UI:UpdateWishlistUI()
    if not self.wishlistSlotButtons then
        return
    end
    local list = Goals:GetActiveWishlist()
    local foundMap = nil
    if list and list.id and Goals.GetWishlistFoundMap then
        foundMap = Goals:GetWishlistFoundMap(list.id)
    end
    if list and foundMap and Goals.IsWishlistItemOwned then
        for _, entry in pairs(list.items or {}) do
            if entry and entry.itemId then
                local owned = Goals:IsWishlistItemOwned(entry.itemId)
                foundMap[entry.itemId] = (owned or entry.manualFound) and true or nil
            end
            if entry and entry.tokenId and entry.tokenId > 0 then
                local owned = Goals:IsWishlistItemOwned(entry.tokenId)
                foundMap[entry.tokenId] = (owned or entry.manualFound) and true or nil
            end
        end
    end
    if not self.selectedWishlistSlot then
        for slotKey in pairs(self.wishlistSlotButtons) do
            self.selectedWishlistSlot = slotKey
            break
        end
    end
    Goals:BuildWishlistItemCache()
    for slotKey, button in pairs(self.wishlistSlotButtons) do
        local slotDef = Goals:GetWishlistSlotDef(slotKey)
        local entry = list and list.items and list.items[slotKey] or nil
        local cached = entry and entry.itemId and Goals:CacheItemById(entry.itemId) or nil
        local iconTexture = nil
        if slotDef and slotDef.inv then
            local _, texture = GetInventorySlotInfo(slotDef.inv)
            iconTexture = texture
        end
        if cached and cached.texture then
            button.icon:SetTexture(cached.texture)
            button.icon:SetVertexColor(1, 1, 1)
            local labelText = cached.name or slotDef.label or slotKey
            fitWishlistLabel(button.label, labelText)
            if cached.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[cached.quality] then
                local color = ITEM_QUALITY_COLORS[cached.quality]
            button.label:SetTextColor(color.r, color.g, color.b)
            button.border:Show()
            button.border:SetVertexColor(color.r, color.g, color.b)
            else
            button.label:SetTextColor(1, 1, 1)
            button.border:Hide()
            end
            button.itemId = cached.id
            button.itemLink = cached.link
        else
            if iconTexture then
                button.icon:SetTexture(iconTexture)
            button.icon:SetVertexColor(0.7, 0.7, 0.7)
            else
                button.icon:SetTexture(nil)
            end
            if entry and entry.itemId and entry.itemId > 0 then
                fitWishlistLabel(button.label, "Item " .. tostring(entry.itemId))
            else
                if slotDef and slotDef.key == "RELIC" then
                    fitWishlistLabel(button.label, "Relic / Ranged")
                else
                    fitWishlistLabel(button.label, (slotDef and slotDef.label) or slotKey)
                end
            end
            button.label:SetTextColor(0.9, 0.9, 0.9)
            button.border:Hide()
            button.itemId = entry and entry.itemId or nil
            button.itemLink = nil
        end
        if button.foundIcon then
            local found = false
            if entry and foundMap then
                if entry.itemId and foundMap[entry.itemId] then
                    found = true
                elseif entry.tokenId and foundMap[entry.tokenId] then
                    found = true
                end
            end
            if found then
                button.foundIcon:Show()
                if button.foundShadow then
                    button.foundShadow:Show()
                end
            else
                button.foundIcon:Hide()
                if button.foundShadow then
                    button.foundShadow:Hide()
                end
            end
        end
        local gemCount = 0
        if entry and entry.gemIds then
            for i = 1, 3 do
                if entry.gemIds[i] then
                    gemCount = gemCount + 1
                end
            end
        end
        local gemOffset = (gemCount - 1) * 0.5
        for i = 1, 3 do
            local gemTexture = nil
            if entry and entry.gemIds and entry.gemIds[i] then
                local gemCache = Goals:CacheItemById(entry.gemIds[i])
                gemTexture = gemCache and gemCache.texture or nil
            end
            local gem = button.gems[i]
            if gemTexture then
                gem.icon:SetTexture(gemTexture)
                gem:Show()
                gem:ClearAllPoints()
                local yOffset = (gemOffset - (i - 1)) * 14
                if button.column == 2 then
                    gem:SetPoint("CENTER", button, "LEFT", -8, yOffset)
                else
                    gem:SetPoint("CENTER", button, "RIGHT", 8, yOffset)
                end
                gem.itemId = entry.gemIds[i]
            else
                gem:Hide()
                gem.itemId = nil
            end
        end
        if entry and entry.enchantId and entry.enchantId > 0 then
            button.enchantIcon:Show()
            button.enchantIcon.enchantId = entry.enchantId
            button.enchantIcon:ClearAllPoints()
            if button.column == 2 then
                button.enchantIcon:SetPoint("CENTER", button, "RIGHT", 12, 0)
            elseif button.column == 1 then
                button.enchantIcon:SetPoint("CENTER", button, "LEFT", -12, 0)
            else
                button.enchantIcon:SetPoint("CENTER", button, "LEFT", -12, 0)
            end
        else
            button.enchantIcon:Hide()
            button.enchantIcon.enchantId = nil
        end
        if self.selectedWishlistSlot == slotKey then
            button.selected:Show()
        else
            button.selected:Hide()
        end
    end
    if self.wishlistNotesBox and self.wishlistSourceEntryBox then
        local selected = self.selectedWishlistSlot and list and list.items and list.items[self.selectedWishlistSlot] or nil
        self.wishlistNotesBox:SetText(selected and selected.notes or "")
        self.wishlistSourceEntryBox:SetText(selected and selected.source or "")
    end
    if self.wishlistEnchantBox then
        local selected = self.selectedWishlistSlot and list and list.items and list.items[self.selectedWishlistSlot] or nil
        self.wishlistEnchantBox:SetText(selected and selected.enchantId or "")
    end
    if self.wishlistGemBoxes then
        local selected = self.selectedWishlistSlot and list and list.items and list.items[self.selectedWishlistSlot] or nil
        local gems = selected and selected.gemIds or {}
        for i = 1, 3 do
            local value = gems[i]
            if self.wishlistGemBoxes[i] then
                self.wishlistGemBoxes[i]:SetText(value or "")
            end
        end
    end
    if self.UpdateWishlistTokenDisplay then
        self:UpdateWishlistTokenDisplay()
    end
    self:UpdateWishlistManagerList()
    self:UpdateWishlistSearchResults()
    if self.wishlistAddSlotButton then
        if self.selectedWishlistSlot and self.selectedWishlistResult then
            self.wishlistAddSlotButton:Enable()
        else
            self.wishlistAddSlotButton:Disable()
        end
    end
    if self.wishlistClearSlotButton then
        if self.selectedWishlistSlot then
            self.wishlistClearSlotButton:Enable()
        else
            self.wishlistClearSlotButton:Disable()
        end
    end
end


function UI:PopulateDebugCopy()
    if not self.debugCopyBox then
        return
    end
    local text = Goals and Goals.GetDebugLogText and Goals:GetDebugLogText() or ""
    self.debugCopyBox:SetText(text)
    self.debugCopyBox:HighlightText()
    self.debugCopyBox:SetFocus()
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
    local maxHeight = 0
    if self.lootHistoryInset and self.lootHistoryInset.GetHeight then
        maxHeight = self.lootHistoryInset:GetHeight() or 0
    end
    local bottomLimit = 0
    if maxHeight > 0 then
        bottomLimit = -(maxHeight - 4)
    end
    local hasRainbow = false
    for i = 1, LOOT_HISTORY_ROWS do
        local row = self.lootHistoryRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            row.timeText:SetText(formatTime(entry.ts))
            if entry.kind == "LOOT_ASSIGN" then
                local itemLink = entry.data and entry.data.item or ""
                local players = entry.data and entry.data.players or nil
                local playerName = colorizeName(entry.data and entry.data.player or "")
                if players and #players >= 3 then
                    row.rainbowData = {
                        kind = "loot",
                        count = #players,
                        itemLink = itemLink,
                    }
                    row.text:SetText(string.format("Gave %s: %s", formatPlayersCount(#players), itemLink))
                    hasRainbow = true
                else
                    row.rainbowData = nil
                    row.text:SetText(string.format("Gave %s: %s", playerName, itemLink))
                end
                if entry.data and entry.data.reset then
                    local before = tonumber(entry.data.resetBefore) or 0
                    row.resetText:SetText(string.format("%s's points set to 0 (-%d).", playerName, before))
                    row.resetText:Show()
                    row:SetHeight(LOOT_HISTORY_ROW_HEIGHT)
                else
                    row.resetText:SetText("")
                    row.resetText:Hide()
                    row:SetHeight(LOOT_HISTORY_ROW_HEIGHT_COMPACT)
                end
            else
                row.text:SetText(entry.text or "")
                row.rainbowData = nil
                row.resetText:SetText("")
                row.resetText:Hide()
                row:SetHeight(LOOT_HISTORY_ROW_HEIGHT_COMPACT)
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.lootHistoryInset, "TOPLEFT", 6, yOffset)
            row:SetPoint("RIGHT", self.lootHistoryInset, "RIGHT", -6, 0)
            if bottomLimit ~= 0 and (yOffset - row:GetHeight()) < bottomLimit then
                row:Hide()
                row.itemLink = nil
                if row.resetText then
                    row.resetText:Hide()
                end
            else
                yOffset = yOffset - row:GetHeight()
            end
            row.itemLink = entry.data and entry.data.item or nil
        else
            row:Hide()
            row.itemLink = nil
            row.rainbowData = nil
            if row.resetText then
                row.resetText:Hide()
            end
        end
    end
    if hasRainbow then
        self:StartRainbowTicker()
    end
end

function UI:UpdateFoundLootList()
    if not self.foundLootScroll or not self.foundLootRows then
        return
    end
    local hasAccess = hasModifyAccess()
    if self.foundHintLabel then
        setShown(self.foundHintLabel, hasAccess)
    end
    if self.foundLockedLabel then
        setShown(self.foundLockedLabel, not hasAccess)
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
        setShown(rowItem.selected, rowItem == row)
    end
    if not self.foundLootMenu then
        self.foundLootMenu = CreateFrame("Frame", "GoalsFoundLootMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = self.foundLootMenu
    UIDropDownMenu_Initialize(menu, function(_, level)
        local info
        local players = UI:GetPresentPlayerNames()
        if #players == 0 and Goals.GetGroupMembers then
            local members = Goals:GetGroupMembers()
            local seen = {}
            for _, info in ipairs(members) do
                local normalized = Goals:NormalizeName(info.name)
                if normalized ~= "" and not seen[normalized] then
                    seen[normalized] = true
                    table.insert(players, info.name)
                end
            end
        end
        if entry.slot and entry.slot > 0 and GetMasterLootCandidate then
            local candidates = {}
            local candidateList = {}
            for i = 1, 40 do
                local candidate = GetMasterLootCandidate(entry.slot, i)
                if not candidate then
                    break
                end
                local normalized = Goals:NormalizeName(candidate)
                if normalized ~= "" and not candidates[normalized] then
                    candidates[normalized] = true
                    table.insert(candidateList, normalized)
                end
            end
            if #candidateList > 0 then
                players = candidateList
            else
                info = UIDropDownMenu_CreateInfo()
                info.text = "Open loot window to assign."
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
                return
            end
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
            return
        end
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
    self:RefreshUpdateTab()
    self:UpdateUpdateTabGlow()
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
        local canEditDis = hasDisenchanterAccess()
        setDropdownEnabled(self.disenchanterDropdown, canEditDis)
        if self.disenchanterDropdown.SetAlpha then
            self.disenchanterDropdown:SetAlpha(canEditDis and 1 or 0.6)
        end
    end
    if self.combineCheck then
        self.combineCheck:SetChecked(Goals.db.settings.combineBossHistory and true or false)
    end
    if self.minimapCheck then
        self.minimapCheck:SetChecked(not Goals.db.settings.minimap.hide)
    end
    if self.autoMinimizeCheck then
        self.autoMinimizeCheck:SetChecked(Goals.db.settings.autoMinimizeCombat and true or false)
    end
    if self.localOnlyCheck then
        self.localOnlyCheck:SetChecked(Goals.db.settings.localOnly and true or false)
    end
    if self.dbmIntegrationCheck then
        self.dbmIntegrationCheck:SetChecked(Goals.db.settings.dbmIntegration and true or false)
    end
    if self.wishlistDbmIntegrationCheck then
        self.wishlistDbmIntegrationCheck:SetChecked(Goals.db.settings.wishlistDbmIntegration and true or false)
    end
    if self.sudoDevButton then
        if Goals.db.settings.sudoDev then
            self.sudoDevButton:SetText(L.BUTTON_SUDO_DEV_DISABLE)
        else
            self.sudoDevButton:SetText(L.BUTTON_SUDO_DEV_ENABLE)
        end
    end
    if self.autoLoadSeenCheck then
        self.autoLoadSeenCheck:SetChecked(Goals.db.settings.tableAutoLoadSeen and true or false)
    end
    if self.combinedTablesCheck then
        self.combinedTablesCheck:SetChecked(Goals.db.settings.tableCombined and true or false)
    end
    if self.resetMountsCheck then
        self.resetMountsCheck:SetChecked(Goals.db.settings.resetMounts and true or false)
    end
    if self.resetPetsCheck then
        self.resetPetsCheck:SetChecked(Goals.db.settings.resetPets and true or false)
    end
    if self.resetRecipesCheck then
        self.resetRecipesCheck:SetChecked(Goals.db.settings.resetRecipes and true or false)
    end
    if self.resetTokensCheck then
        self.resetTokensCheck:SetChecked(Goals.db.settings.resetTokens and true or false)
    end
    if self.resetQuestItemsCheck then
        self.resetQuestItemsCheck:SetChecked(Goals.db.settings.resetQuestItems and true or false)
    end
    if self.debugCheck then
        self.debugCheck:SetChecked(Goals.db.settings.debug and true or false)
    end
    if self.wishlistChatCheck then
        self.wishlistChatCheck:SetChecked(Goals.db.settings.devTestWishlistChat and true or false)
    end
    if self.wishlistTestCountBox then
        local value = tonumber(Goals.db.settings.devTestWishlistItems) or 1
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        self.wishlistTestCountBox:SetText(tostring(value))
    end
    if self.wishlistAnnounceCheck then
        self.wishlistAnnounceCheck:SetChecked(Goals.db.settings.wishlistAnnounce and true or false)
    end
    if self.wishlistPopupDisableCheck then
        self.wishlistPopupDisableCheck:SetChecked(Goals.db.settings.wishlistPopupDisabled and true or false)
    end
    if self.wishlistPopupSoundToggle then
        if Goals.db.settings.wishlistPopupSound == false then
            self.wishlistPopupSoundToggle:SetText("MUT")
        else
            self.wishlistPopupSoundToggle:SetText("SND")
        end
    end
    if Goals.db and Goals.db.settings then
        Goals.db.settings.wishlistAnnounceChannel = "AUTO"
    end
    if self.wishlistTemplateBox then
        self.wishlistTemplateBox:SetText(Goals.db.settings.wishlistAnnounceTemplate or "%s is on my wishlist")
    end
    if self.lootHistoryMinQuality then
        local value = Goals.db.settings.lootHistoryMinQuality or 0
        UIDropDownMenu_SetSelectedValue(self.lootHistoryMinQuality, value)
        UIDropDownMenu_SetText(self.lootHistoryMinQuality, getQualityLabel(value))
    end
    self:SyncResetQualityDropdown()
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
    self:UpdateDebugLogList()
    self:UpdateWishlistUI()
    self:UpdateMiniTracker()
    self:UpdateMiniFloatingButtonPosition()
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
    icon:SetSize(16, 16)
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

function UI:UpdateMiniFloatingButtonPosition()
    if not self.miniFloatingButton then
        return
    end
    self:UpdateMiniFloatingPosition()
end

function UI:CreateMiniTracker()
    if self.miniTracker then
        return
    end
    local frame = CreateFrame("Frame", "GoalsMiniTracker", UIParent, "GoalsInsetTemplate")
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

function UI:UpdateMiniTrackerPosition()
    if not self.miniTracker then
        return
    end
    local pos = getMiniSettings()
    if not pos then
        return
    end
    self.miniTracker:ClearAllPoints()
    if pos.hasPosition then
        self.miniTracker:SetPoint("CENTER", UIParent, "CENTER", pos.x or MINI_DEFAULT_X, pos.y or MINI_DEFAULT_Y)
    else
        self.miniTracker:SetPoint("CENTER", UIParent, "CENTER", MINI_DEFAULT_X, MINI_DEFAULT_Y)
    end
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

function UI:UpdateMiniTrackerVisibility()
    if not self.miniTracker then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    local wantShow = settings.show and not settings.minimized
    if Goals.Dev and Goals.Dev.enabled then
        setShown(self.miniTracker, wantShow)
        return
    end
    local inGroup = Goals.IsInRaid and Goals:IsInRaid() or false
    if not inGroup and Goals.IsInParty then
        inGroup = Goals:IsInParty()
    end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    local autoHide = Goals.db.settings.autoMinimizeCombat and true or false
    setShown(self.miniTracker, wantShow and inGroup and (not autoHide or not inCombat))
end

function UI:UpdateMiniTracker()
    if not self.miniTracker or not Goals.db or not Goals.db.settings then
        return
    end
    self:UpdateMiniTrackerVisibility()
    if not self.miniTracker:IsShown() then
        self:UpdateMiniFloatingButton()
        return
    end
    local present = self:GetPresentPlayerNames()
    local rowCount = #present
    local rowY = -MINI_HEADER_HEIGHT
    for i = 1, rowCount do
        local row = self.miniTracker.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.miniTracker)
            row:SetHeight(MINI_ROW_HEIGHT)
            row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.pointsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.pointsText:SetPoint("RIGHT", row, "RIGHT", -11, 0)
            row.pointsText:SetJustifyH("RIGHT")
            self.miniTracker.rows[i] = row
        end
        local name = present[i]
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.miniTracker, "TOPLEFT", 0, rowY)
        row:SetPoint("RIGHT", self.miniTracker, "RIGHT", 0, 0)
        local entry = Goals.db.players and Goals.db.players[name] or nil
        local points = entry and entry.points or 0
        local r, g, b = Goals:GetClassColor(entry and entry.class or nil)
        row.nameText:SetText(name)
        row.nameText:SetTextColor(r, g, b)
        row.pointsText:SetText(points)
        rowY = rowY - MINI_ROW_HEIGHT
    end
    for i = rowCount + 1, #self.miniTracker.rows do
        self.miniTracker.rows[i]:Hide()
    end
    local height = MINI_HEADER_HEIGHT + 8 + (rowCount * MINI_ROW_HEIGHT)
    if height < MINI_HEADER_HEIGHT + 10 then
        height = MINI_HEADER_HEIGHT + 10
    end
    self.miniTracker:SetHeight(height)
    self:UpdateMiniFloatingButton()
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

function UI:UpdateMiniFloatingPosition()
    if not self.miniFloatingButton then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    self.miniFloatingButton:ClearAllPoints()
    self.miniFloatingButton:SetPoint("CENTER", UIParent, "CENTER", settings.buttonX or 0, settings.buttonY or 0)
end

function UI:UpdateMiniFloatingButton()
    if not self.miniFloatingButton then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    local show = settings.show and settings.minimized
    setShown(self.miniFloatingButton, show)
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
