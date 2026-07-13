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
        for _, option in ipairs(list) do
            local value = option
            local text = option
            if type(option) == "table" then
                value = option.value
                text = option.text or option.label or option.value
            end
            if value == nil then
                value = text
            end
            if text == nil then
                text = tostring(value or "")
            end
            info = UIDropDownMenu_CreateInfo()
            if dropdown.colorize and text ~= L.NONE_OPTION then
                info.text = colorizeName(text)
            else
                info.text = text
            end
            info.value = value
            info.func = function()
                dropdown.selectedValue = value
                UIDropDownMenu_SetSelectedValue(dropdown, value)
                if dropdown.colorize and text ~= L.NONE_OPTION then
                    UIDropDownMenu_SetText(dropdown, colorizeName(text))
                else
                    UIDropDownMenu_SetText(dropdown, text)
                end
                if dropdown.onSelect then
                    dropdown.onSelect(value, option)
                end
            end
            info.checked = dropdown.selectedValue == value
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
        if self.combatBroadcastPopout and self.combatBroadcastPopout:IsShown() then
            self.combatBroadcastPopout:Hide()
        end
        if Goals.db and Goals.db.settings and Goals.db.settings.floatingButton and Goals.db.settings.floatingButton.show then
            self:ShowFloatingButton(true)
        end
        return
    end
    self.frame:Show()
    self:ShowFloatingButton(false)
    self:Refresh()
end

function UI:CreateMainFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "GoalsMainFrame", UIParent, "GoalsFrameTemplate")
    frame:SetSize(MAIN_FRAME_WIDTH, MAIN_FRAME_HEIGHT + FOOTER_BAR_EXTRA)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    applyFrameTheme(frame)

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
    titleText:SetTextColor(THEME.titleText[1], THEME.titleText[2], THEME.titleText[3], THEME.titleText[4])
    frame.titleText = titleText

    local close = _G[frame:GetName() .. "CloseButton"]
    if close then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 5)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    frame:SetScript("OnHide", function()
        if UI and UI.combatBroadcastPopout and UI.combatBroadcastPopout:IsShown() then
            UI.combatBroadcastPopout:Hide()
        end
        if hideBuildPreviewTooltip then
            hideBuildPreviewTooltip()
        end
    end)

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
    self.mainFrameNormalWidth = MAIN_FRAME_WIDTH
    self.mainFrameCombatWidth = MAIN_FRAME_WIDTH_COMBAT
    self.tabs = {}
    self.pages = {}
    self.damageTab = nil
    self.damageTabId = nil
    self.damageTableWidget = nil
    self.damageTrackerScroll = nil
    self.damageTrackerRows = nil
    self.damageOptionsFrame = nil

    local tabBar = CreateFrame("Frame", "GoalsMainTabBar", frame)
    tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    tabBar:SetHeight(24)
    local tabBg = tabBar:CreateTexture(nil, "BORDER")
    tabBg:SetAllPoints(tabBar)
    tabBg:SetTexture(0, 0, 0, 0.45)
    self.tabBar = tabBar
    local tabLine = frame:CreateTexture(nil, "BORDER")
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -1)
    tabLine:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -1)
    tabLine:SetTexture(1, 1, 1, 0.08)
    self.tabBarLine = tabLine

    local hasWHTMInstalled = (GetAddOnInfo and GetAddOnInfo("WHTM")) and true or false

    local tabDefs = {
        { key = "overview", text = L.TAB_OVERVIEW, create = "CreateOverviewTab" },
        { key = "loot", text = L.TAB_LOOT, create = "CreateLootTab" },
        { key = "history", text = L.TAB_HISTORY, create = "CreateHistoryTab" },
        { key = "wishlist", text = L.TAB_WISHLIST, create = "CreateWishlistTab" },
        { key = "diagnostics", text = L.TAB_DIAGNOSTICS or "Diag", create = "CreateDiagnosticsTab" },
        { key = "settings", text = L.TAB_SETTINGS or "Settings", create = "CreateSettingsTab" },
    }
    if hasWHTMInstalled then
        table.insert(tabDefs, { key = "damage", text = L.TAB_DAMAGE_TRACKER, create = "CreateDamageTrackerTab" })
    end
    if self:ShouldShowUpdateTab() then
        table.insert(tabDefs, { key = "update", text = L.TAB_UPDATE, create = "CreateUpdateTab" })
    end
    if Goals.Dev and Goals.Dev.enabled then
        table.insert(tabDefs, { key = "dev", text = L.TAB_DEV, create = "CreateDevTab" })
        table.insert(tabDefs, { key = "debug", text = L.TAB_DEBUG, create = "CreateDebugTab" })
    end
    -- Help tab removed; tooltips provide guidance inline.

    for i, def in ipairs(tabDefs) do
        local tabName = frame:GetName() .. "Tab" .. i
        local tab = CreateFrame("Button", tabName, tabBar, "OptionsFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetHeight(24)
        tab:SetText(def.text)
        PanelTemplates_TabResize(tab, 8)
        tab:SetScript("OnClick", function()
            UI:SelectTab(i)
        end)
        if i == 1 then
            tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
        else
            tab:SetPoint("TOPLEFT", self.tabs[i - 1], "TOPRIGHT", 0, 0)
        end
        if def.key == "update" then
            self.updateTab = tab
            self.updateTabId = i
        end
        if def.key == "loot" then
            self.lootTabId = i
        end
        if def.key == "history" then
            self.historyTabId = i
        end
        if def.key == "wishlist" then
            self.wishlistTabId = i
        end
        if def.key == "damage" then
            self.damageTab = tab
            self.damageTabId = i
        end
        if def.key == "dev" then
            self.devTab = tab
        end
        if def.key == "debug" then
            self.debugTab = tab
        end
        self.tabs[i] = tab

        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 2, -6)
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, PAGE_BOTTOM_OFFSET + FOOTER_BAR_EXTRA)
        page:Hide()
        self.pages[i] = page
        page.footer = createTabFooter(self, page, def.key)
        page.footer2 = createTabFooter2(self, page, def.key, page.footer)

        local createFunc = self[def.create]
        if createFunc then
            createFunc(self, page)
        end
    end

    PanelTemplates_SetNumTabs(frame, #tabDefs)
    PanelTemplates_SetTab(frame, 1)
    self:SelectTab(1)
    self:UpdateUpdateTabGlow()
    self:LayoutTabs()
    self:UpdateDamageTabVisibility()
end

function UI:LayoutTabs()
    if not self.frame or not self.tabs then
        return
    end
    local tabBar = self.tabBar or self.frame
    local previous = nil
    for _, tab in ipairs(self.tabs) do
        if tab ~= self.helpTab and tab:IsShown() then
            tab:ClearAllPoints()
            if not previous then
                tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
            else
                tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 0, 0)
            end
            previous = tab
        end
    end
    if self.helpTab then
        self.helpTab:ClearAllPoints()
        self.helpTab:SetPoint("TOPRIGHT", tabBar, "TOPRIGHT", 0, 0)
    end
end

function UI:GetTopPointsSummary()
    if not self.GetSortedPlayers then
        return nil
    end
    local list = self:GetSortedPlayers()
    if #list == 0 then
        return nil
    end
    local topPoints = nil
    local topNames = {}
    for _, entry in ipairs(list) do
        local points = entry.points or 0
        if topPoints == nil or points > topPoints then
            topPoints = points
            topNames = { entry.name }
        elseif points == topPoints then
            table.insert(topNames, entry.name)
        end
    end
    if #topNames == 0 then
        return nil
    end
    table.sort(topNames)
    local displayName = colorizeName(topNames[1])
    if #topNames > 1 then
        displayName = string.format("%s +%d", displayName, #topNames - 1)
    end
    return string.format("Top: (%d) %s", topPoints, displayName)
end

function UI:GetTabFooter2Segments(key)
    local settings = (Goals and Goals.db and Goals.db.settings) or {}
    if key == "overview" then
        local topText = self:GetTopPointsSummary()
        local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or settings or {}
        local sortText = getSortLabel(overviewSettings.sortMode)
        local presentText = overviewSettings.showPresentOnly and "Present only: On" or "Present only: Off"
        return topText, sortText, presentText
    end
    if key == "loot" then
        local minQuality = settings.lootHistoryMinQuality or 0
        local qualityText = "Min quality: " .. getQualityLabel(minQuality)
        local resetText = settings.resetRequiresLootWindow and "Mode: Manual" or "Mode: Auto"
        local count = self.GetLootHistoryEntries and #self:GetLootHistoryEntries() or 0
        local entriesText = "Entries: " .. tostring(count)
        return qualityText, resetText, entriesText
    end
    if key == "history" then
        local filtersText = getHistoryFilterSummary(settings)
        local count = self.GetHistoryEntries and #self:GetHistoryEntries() or 0
        local entriesText = "Entries: " .. tostring(count)
        return filtersText, nil, entriesText
    end
    if key == "wishlist" then
        local list = Goals.GetActiveWishlist and Goals:GetActiveWishlist() or nil
        local listName = list and list.name or "Wishlist"
        local listText = "List: " .. listName
        local tabLabel = self:GetWishlistTabLabel(self.wishlistActiveTab)
        if tabLabel and tabLabel ~= "" then
            listText = listText .. " | " .. tabLabel
        end
        local completionText = self.wishlistCompletionText
        local alertsText = self:GetWishlistAlertsSummary(settings)
        return listText, completionText, alertsText
    end
    if key == "damage" then
        local filter = self.damageTrackerFilter or COMBAT_SHOW_ALL
        local filterText = "Filter: " .. tostring(filter)
        local showText = self:GetCombatShowSummary(settings)
        local threshold = settings.combatLogBigThreshold or 0
        local thresholdText = string.format("Threshold: %d%%", math.floor(threshold + 0.5))
        local rightText = thresholdText
        return filterText, showText, rightText
    end
    return nil, nil, nil
end

function UI:SelectTab(id)
    if not self.frame or not self.tabs[id] then
        return
    end
    if not self.frame.numTabs and self.tabs then
        self.frame.numTabs = #self.tabs
    end
    PanelTemplates_SetTab(self.frame, id)
    for index, page in ipairs(self.pages) do
        setShown(page, index == id)
    end
    if self.UpdateFrameWidthForTab then
        self:UpdateFrameWidthForTab(id)
    end
    self.currentTab = id
    clearCombatRowTooltipLock()
    hideCombatRowTooltip()
    if self.wishlistTabId and id ~= self.wishlistTabId then
        hideBuildPreviewTooltip()
        hideBuildShareTooltip()
        if self.buildShareTargetFrame then
            self.buildShareTargetFrame:Hide()
        end
    end
    if self.UpdateLootOptionsVisibility then
        self:UpdateLootOptionsVisibility()
    end
    if self.UpdateDamageOptionsVisibility then
        self:UpdateDamageOptionsVisibility()
    end
    if self.UpdateHistoryOptionsVisibility then
        self:UpdateHistoryOptionsVisibility()
    end
    if self.UpdateWishlistHelpVisibility then
        self:UpdateWishlistHelpVisibility()
    end
    if self.UpdateWishlistSocketPickerVisibility then
        self:UpdateWishlistSocketPickerVisibility()
    end
    self:Refresh()
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
    if self.UpdateAutoSyncLabel then
        self:UpdateAutoSyncLabel()
    end
    if self.syncNoteLabel then
        if Goals and Goals.db and Goals.db.settings and Goals.db.settings.localOnly then
            self.syncNoteLabel:SetText("Sync disabled (Local-only mode).")
            self.syncNoteLabel:Show()
        else
            self.syncNoteLabel:SetText("")
            self.syncNoteLabel:Hide()
        end
    end
end

function UI:Refresh()
    local traceEnabled = Goals and Goals.UI and Goals.UI.IsCpuDebugTracingEnabled and Goals.UI:IsCpuDebugTracingEnabled()
    local t0 = (traceEnabled and type(debugprofilestop) == "function") and debugprofilestop() or 0
    if not self.frame then
        return
    end
    self:RefreshStatus()
    self:SyncSortDropdown()
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
    if self.quickMinimapCheck then
        self.quickMinimapCheck:SetChecked(not Goals.db.settings.minimap.hide)
    end
    if self.autoMinimizeCheck then
        self.autoMinimizeCheck:SetChecked(Goals.db.settings.autoMinimizeCombat and true or false)
    end
    if self.quickAutoMinimizeCheck then
        self.quickAutoMinimizeCheck:SetChecked(Goals.db.settings.autoMinimizeCombat and true or false)
    end
    if self.announceEncounterStartCheck then
        self.announceEncounterStartCheck:SetChecked(Goals.db.settings.announceEncounterStarts ~= false)
    end
    if self.quickAnnounceEncounterStartCheck then
        self.quickAnnounceEncounterStartCheck:SetChecked(Goals.db.settings.announceEncounterStarts ~= false)
    end
    if self.announceEncounterWipeCheck then
        self.announceEncounterWipeCheck:SetChecked(Goals.db.settings.announceEncounterWipes ~= false)
    end
    if self.quickAnnounceEncounterWipeCheck then
        self.quickAnnounceEncounterWipeCheck:SetChecked(Goals.db.settings.announceEncounterWipes ~= false)
    end
    if self.announceEncounterCompletionCheck then
        self.announceEncounterCompletionCheck:SetChecked(Goals.db.settings.announceEncounterCompletions ~= false)
    end
    if self.quickAnnounceEncounterCompletionCheck then
        self.quickAnnounceEncounterCompletionCheck:SetChecked(Goals.db.settings.announceEncounterCompletions ~= false)
    end
    if self.announceEncounterProgressCheck then
        self.announceEncounterProgressCheck:SetChecked(Goals.db.settings.announceEncounterProgress ~= false)
    end
    local root = Goals.dbRoot or Goals.db
    local localBackup = root and root.localBackup or nil
    if self.backupStatusLabel then
        self.backupStatusLabel:SetText(localBackup and localBackup.created and ("Saved " .. date("%Y-%m-%d %H:%M", localBackup.created)) or "No local backup")
    end
    if self.restoreBackupButton then
        if localBackup then
            self.restoreBackupButton:Enable()
            self.restoreBackupButton:SetAlpha(1)
        else
            self.restoreBackupButton:Disable()
            self.restoreBackupButton:SetAlpha(0.5)
        end
    end
    local trackingEnabled = Goals.db.settings.combatLogTracking and true or false
    if self.combatLogTrackingCheck then
        self.combatLogTrackingCheck:SetChecked(trackingEnabled)
    end
    if Goals.db.settings.combatWhtmDirections then
        if self.combatDirIncomingCheck then
            self.combatDirIncomingCheck:SetChecked(Goals.db.settings.combatWhtmDirections.incoming and true or false)
        end
        if self.combatDirOutgoingCheck then
            self.combatDirOutgoingCheck:SetChecked(Goals.db.settings.combatWhtmDirections.outgoing and true or false)
        end
        if self.combatDirInternalCheck then
            self.combatDirInternalCheck:SetChecked(Goals.db.settings.combatWhtmDirections.internal and true or false)
        end
    end
    if self.combatGroupChecks and Goals.db.settings.combatWhtmGroups then
        for key, check in pairs(self.combatGroupChecks) do
            check:SetChecked(Goals.db.settings.combatWhtmGroups[key] and true or false)
        end
    end
    if self.combatAuraChecks and Goals.db.settings.combatWhtmAuraStates then
        for key, check in pairs(self.combatAuraChecks) do
            check:SetChecked(Goals.db.settings.combatWhtmAuraStates[key] and true or false)
        end
    end
    if self.combatPausedCheck then
        self.combatPausedCheck:SetChecked(Goals.db.settings.combatWhtmPaused and true or false)
    end
    if self.combatSoftRowsCheck then
        self.combatSoftRowsCheck:SetChecked(Goals.db.settings.combatWhtmSoftRowColors ~= false)
    end
    if self.combatCombineOverTimeCheck then
        self.combatCombineOverTimeCheck:SetChecked(Goals.db.settings.combatWhtmCombineOverTime and true or false)
    end
    if self.combatThemeDropdown then
        local theme = self:GetCombatTheme()
        UIDropDownMenu_SetSelectedValue(self.combatThemeDropdown, theme)
        local label = "Neutral"
        if theme == COMBAT_THEME_ALLIANCE then
            label = "Alliance"
        elseif theme == COMBAT_THEME_HORDE then
            label = "Horde"
        elseif theme == COMBAT_THEME_CLASS then
            label = "Class Accent"
        end
        self:SetDropdownText(self.combatThemeDropdown, label)
        self:ApplyCombatTheme()
    end
    if self.combatRowBgStyleDropdown then
        local rowStyle = self:GetCombatRowBgStyle()
        UIDropDownMenu_SetSelectedValue(self.combatRowBgStyleDropdown, rowStyle)
        self:SetDropdownText(self.combatRowBgStyleDropdown, rowStyle == COMBAT_ROW_BG_NEUTRAL and "Neutral (B/W)" or "Event")
    end
    if self.combatHideMinimapCheck then
        self.combatHideMinimapCheck:SetChecked(Goals.db.settings.combatWhtmHideMinimapIcon and true or false)
    end
    if self.combatBossOnlyCheck then
        self.combatBossOnlyCheck:SetChecked(Goals.db.settings.combatWhtmBossOnly and true or false)
    end
    if self.combatRetainHistoryCheck then
        self.combatRetainHistoryCheck:SetChecked(Goals.db.settings.combatWhtmRetainFullHistory and true or false)
    end
    if self.combatScopeDropdown then
        local scope = Goals.db.settings.combatWhtmScope or "player"
        local scopeText = "Self only"
        if scope == "party" then
            scopeText = "Party group"
        elseif scope == "raid" then
            scopeText = "Raid group"
        end
        UIDropDownMenu_SetSelectedValue(self.combatScopeDropdown, scope)
        self:SetDropdownText(self.combatScopeDropdown, scopeText)
    end
    if self.combatTimestampDropdown then
        local fmt = Goals.db.settings.combatWhtmTimestampFormat or "24h"
        UIDropDownMenu_SetSelectedValue(self.combatTimestampDropdown, fmt)
        self:SetDropdownText(self.combatTimestampDropdown, fmt)
    end
    if self.combatDisplayStyleDropdown then
        local style = self:GetCombatDisplayStyle()
        UIDropDownMenu_SetSelectedValue(self.combatDisplayStyleDropdown, style)
        self:SetDropdownText(self.combatDisplayStyleDropdown, style == COMBAT_DISPLAY_CHAT and "Chat style" or "Table")
        self:ApplyCombatDisplayStyle(style)
    end
    if self.combatMaxRowsSlider then
        self.combatMaxRowsSlider:SetValue(Goals.db.settings.combatWhtmMaxRows or 600)
        if Goals.db.settings.combatWhtmRetainFullHistory then
            self.combatMaxRowsSlider:Disable()
            if self.combatMaxRowsSlider.SetAlpha then
                self.combatMaxRowsSlider:SetAlpha(0.45)
            end
        else
            self.combatMaxRowsSlider:Enable()
            if self.combatMaxRowsSlider.SetAlpha then
                self.combatMaxRowsSlider:SetAlpha(1)
            end
        end
    end
    if self.combatMaxRowsValue then
        if Goals.db.settings.combatWhtmRetainFullHistory then
            self.combatMaxRowsValue:SetText("Max rows: Session (unlimited)")
        else
            self.combatMaxRowsValue:SetText(("Max rows: %d"):format(Goals.db.settings.combatWhtmMaxRows or 600))
        end
    end
    if Goals and Goals.db and Goals.db.settings then
        self:NormalizeCombatShowFlags(Goals.db.settings)
    end
    local mode = self:GetCombatShowMode(Goals.db.settings)
    self.damageTrackerFilter = mode
    if self.damageTrackerDropdown then
        self.damageTrackerDropdown.selectedValue = mode
        UIDropDownMenu_SetSelectedValue(self.damageTrackerDropdown, mode)
        self:SetDropdownText(self.damageTrackerDropdown, mode)
        setDropdownEnabled(self.damageTrackerDropdown, trackingEnabled)
        if self.damageTrackerDropdown.SetAlpha then
            self.damageTrackerDropdown:SetAlpha(trackingEnabled and 1 or 0.6)
        end
    end
    if self.combatLogShowDropdown then
        local enabled = trackingEnabled
        self.combatLogShowDropdown.selectedValue = mode
        UIDropDownMenu_SetSelectedValue(self.combatLogShowDropdown, mode)
        self:SetDropdownText(self.combatLogShowDropdown, mode)
        setDropdownEnabled(self.combatLogShowDropdown, enabled)
        if self.combatLogShowDropdown.SetAlpha then
            self.combatLogShowDropdown:SetAlpha(enabled and 1 or 0.6)
        end
    end
    local function clampSliderValue(value)
        local clamped = math.floor((tonumber(value) or 0) + 0.5)
        if clamped < 0 then
            clamped = 0
        elseif clamped > 100 then
            clamped = 100
        end
        return clamped
    end

    local threshold = tonumber(Goals.db.settings.combatLogBigThreshold)
    if threshold == nil then
        local oldDamage = tonumber(Goals.db.settings.combatLogBigDamageThreshold)
        local oldHeal = tonumber(Goals.db.settings.combatLogBigHealingThreshold)
        if oldDamage or oldHeal then
            threshold = math.max(oldDamage or 0, oldHeal or 0)
        end
    end
    if threshold == nil then
        threshold = (Goals.db.settings.combatLogShowBig and 50 or 0)
    end
    Goals.db.settings.combatLogBigThreshold = threshold
    threshold = clampSliderValue(threshold)

    local function updateSlider(slider, valueLabel, value, enabled)
        if slider then
            slider:SetValue(value)
            if slider.SetAlpha then
                slider:SetAlpha(enabled and 1 or 0.6)
            end
            if enabled then
                if slider.Enable then
                    slider:Enable()
                end
            else
                if slider.Disable then
                    slider:Disable()
                end
            end
        end
        if valueLabel then
            valueLabel:SetText(string.format("%d%%", value))
        end
    end

    if self.combatLogBigThresholdSlider then
        updateSlider(self.combatLogBigThresholdSlider, self.combatLogBigThresholdValue, threshold, trackingEnabled)
    end
    if self.combatLogShowBossHealingCheck then
        local enabled = trackingEnabled
        local showBossHealing = Goals.db.settings.combatLogShowBossHealing
        if showBossHealing == nil then
            showBossHealing = true
            Goals.db.settings.combatLogShowBossHealing = true
        end
        self.combatLogShowBossHealingCheck:SetChecked(showBossHealing and true or false)
        if self.combatLogShowBossHealingCheck.SetAlpha then
            self.combatLogShowBossHealingCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogShowBossHealingCheck.Enable then
                self.combatLogShowBossHealingCheck:Enable()
            end
        else
            if self.combatLogShowBossHealingCheck.Disable then
                self.combatLogShowBossHealingCheck:Disable()
            end
        end
    end
    if self.combatLogShowThreatCheck then
        local enabled = trackingEnabled
        local showThreat = Goals.db.settings.combatLogShowThreat
        if showThreat == nil then
            showThreat = true
            Goals.db.settings.combatLogShowThreat = true
        end
        self.combatLogShowThreatCheck:SetChecked(showThreat and true or false)
        if self.combatLogShowThreatCheck.SetAlpha then
            self.combatLogShowThreatCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogShowThreatCheck.Enable then
                self.combatLogShowThreatCheck:Enable()
            end
        else
            if self.combatLogShowThreatCheck.Disable then
                self.combatLogShowThreatCheck:Disable()
            end
        end
    end
    if self.combatLogShowThreatAbilitiesCheck then
        local enabled = trackingEnabled
        local showThreatAbilities = Goals.db.settings.combatLogShowThreatAbilities
        if showThreatAbilities == nil then
            showThreatAbilities = true
            Goals.db.settings.combatLogShowThreatAbilities = true
        end
        self.combatLogShowThreatAbilitiesCheck:SetChecked(showThreatAbilities and true or false)
        if self.combatLogShowThreatAbilitiesCheck.SetAlpha then
            self.combatLogShowThreatAbilitiesCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogShowThreatAbilitiesCheck.Enable then
                self.combatLogShowThreatAbilitiesCheck:Enable()
            end
        else
            if self.combatLogShowThreatAbilitiesCheck.Disable then
                self.combatLogShowThreatAbilitiesCheck:Disable()
            end
        end
    end
    if self.combatLogCombinePeriodicCheck then
        local enabled = trackingEnabled
        self.combatLogCombinePeriodicCheck:SetChecked(Goals.db.settings.combatLogCombinePeriodic and true or false)
        if self.combatLogCombinePeriodicCheck.SetAlpha then
            self.combatLogCombinePeriodicCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogCombinePeriodicCheck.Enable then
                self.combatLogCombinePeriodicCheck:Enable()
            end
        else
            if self.combatLogCombinePeriodicCheck.Disable then
                self.combatLogCombinePeriodicCheck:Disable()
            end
        end
    end
    if self.combatLogCombineAllCheck then
        local enabled = trackingEnabled
        self.combatLogCombineAllCheck:SetChecked(Goals.db.settings.combatLogCombineAll and true or false)
        if self.combatLogCombineAllCheck.SetAlpha then
            self.combatLogCombineAllCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogCombineAllCheck.Enable then
                self.combatLogCombineAllCheck:Enable()
            end
        else
            if self.combatLogCombineAllCheck.Disable then
                self.combatLogCombineAllCheck:Disable()
            end
        end
    end
    if self.localOnlyCheck then
        self.localOnlyCheck:SetChecked(Goals.db.settings.localOnly and true or false)
    end
    if self.quickLocalOnlyCheck then
        self.quickLocalOnlyCheck:SetChecked(Goals.db.settings.localOnly and true or false)
    end
    if self.dbmIntegrationCheck then
        self.dbmIntegrationCheck:SetChecked(Goals.db.settings.dbmIntegration and true or false)
    end
    if self.quickDbmIntegrationCheck then
        self.quickDbmIntegrationCheck:SetChecked(Goals.db.settings.dbmIntegration and true or false)
    end
    if self.wishlistDbmIntegrationCheck then
        self.wishlistDbmIntegrationCheck:SetChecked(Goals.db.settings.wishlistDbmIntegration and true or false)
    end
    if self.quickWishlistDbmIntegrationCheck then
        self.quickWishlistDbmIntegrationCheck:SetChecked(Goals.db.settings.wishlistDbmIntegration and true or false)
    end
    if self.sudoDevButton then
        if Goals.db.settings.sudoDev then
            self.sudoDevButton:SetText(L.BUTTON_SUDO_DEV_DISABLE)
        else
            self.sudoDevButton:SetText(L.BUTTON_SUDO_DEV_ENABLE)
        end
    end
    if self.settingsSudoDevButton then
        if Goals.db.settings.sudoDev then
            self.settingsSudoDevButton:SetText(L.BUTTON_SUDO_DEV_DISABLE)
        else
            self.settingsSudoDevButton:SetText(L.BUTTON_SUDO_DEV_ENABLE)
        end
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
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
    if self.resetBagsCheck then
        self.resetBagsCheck:SetChecked(Goals.db.settings.resetBags and true or false)
    end
    if self.resetLootWindowCheck then
        self.resetLootWindowCheck:SetChecked(Goals.db.settings.resetRequiresLootWindow and true or false)
    end
    if self.lootPolicyPreview then
        local s = Goals.db.settings
        local quality = getQualityLabel(Goals:GetResetMinQuality())
        local function state(enabled) return enabled and "|cff55ff55RESET|r" or "|cffaaaaaaIGNORE|r" end
        self.lootPolicyPreview:SetText(table.concat({
            quality .. " armor: |cff55ff55RESET|r",
            "Tier tokens: " .. state(s.resetTokens),
            quality .. " bags: " .. state(s.resetBags),
            "Mounts: " .. state(s.resetMounts),
            "Recipes: " .. state(s.resetRecipes),
            "Mode: " .. (s.resetRequiresLootWindow and "Manual loot assignment" or "Automatic raid loot"),
        }, "\n"))
    end
    if self.debugCheck then
        self.debugCheck:SetChecked(Goals.db.settings.debug and true or false)
    end
    if self.wishlistChatCheck then
        self.wishlistChatCheck:SetChecked(Goals.db.settings.devTestWishlistChat and true or false)
    end

    local function formatBinding(action)
        if not GetBindingKey then
            return "Unbound"
        end
        local key1, key2 = GetBindingKey(action)
        local function normalizeKey(key)
            if not key or key == "" then
                return nil
            end
            if GetBindingText then
                return GetBindingText(key, "KEY_") or key
            end
            return key
        end
        local text1 = normalizeKey(key1)
        local text2 = normalizeKey(key2)
        if text1 and text2 then
            return text1 .. " / " .. text2
        end
        return text1 or text2 or "Unbound"
    end

    if self.keybindUiValue then
        self.keybindUiValue:SetText(formatBinding("GOALS_TOGGLE_UI"))
    end
    if self.keybindMiniValue then
        self.keybindMiniValue:SetText(formatBinding("GOALS_TOGGLE_MINI"))
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
    if self.wishlistPopupSoundToggle and self.wishlistPopupSoundToggle.icon then
        self.wishlistPopupSoundToggle.icon:SetTexture("Interface\\Common\\VoiceChat-Speaker")
        if self.wishlistPopupSoundToggle.waveIcon then
            setShown(self.wishlistPopupSoundToggle.waveIcon, Goals.db.settings.wishlistPopupSound ~= false)
        end
    end
    if self.UpdateCombatDebugStatus then
        self:UpdateCombatDebugStatus()
    end
    if self.UpdateTabFooters then
        self:UpdateTabFooters()
    end
    -- Auto-only announcement channel; no user selection.
    if self.wishlistTemplateBox then
        self.wishlistTemplateBox:SetText(Goals.db.settings.wishlistAnnounceTemplate or "%s is on my wishlist")
    end
    if self.lootHistoryMinQuality then
        local value = Goals.db.settings.lootHistoryMinQuality or 0
        UIDropDownMenu_SetSelectedValue(self.lootHistoryMinQuality, value)
        UIDropDownMenu_SetText(self.lootHistoryMinQuality, getQualityLabel(value))
    end
    if self.historyPointsCheck then
        local settings = Goals.db.settings or {}
        self.historyEncounterCheck:SetChecked(settings.historyFilterEncounter ~= false)
        self.historyPointsCheck:SetChecked(settings.historyFilterPoints ~= false)
        self.historyBuildCheck:SetChecked(settings.historyFilterBuild ~= false)
        self.historyWishlistStatusCheck:SetChecked(settings.historyFilterWishlistStatus ~= false)
        self.historyWishlistItemsCheck:SetChecked(settings.historyFilterWishlistItems ~= false)
        self.historyLootCheck:SetChecked(settings.historyFilterLoot ~= false)
        if self.historySyncCheck then
            self.historySyncCheck:SetChecked(settings.historyFilterSync ~= false)
        end
    end
    if self.historyLootMinQuality then
        local value = Goals.db.settings.historyLootMinQuality or 0
        UIDropDownMenu_SetSelectedValue(self.historyLootMinQuality, value)
        UIDropDownMenu_SetText(self.historyLootMinQuality, getQualityLabel(value))
    end
    self:SyncResetQualityDropdown()
    if self.devBossCheck then
        self.devBossCheck:SetChecked(Goals.db.settings.devTestBoss and true or false)
    end
    local hasAccess = hasModifyAccess()
    if self.overviewAdminControls then
        for _, control in ipairs(self.overviewAdminControls) do
            setShown(control, hasAccess)
        end
    end
    if self.UpdateOverviewOptionsLayout then
        self:UpdateOverviewOptionsLayout(hasAccess)
    end
    local currentTab = self.currentTab or 1
    local debugTabId = self.debugTab and self.debugTab.GetID and self.debugTab:GetID() or nil

    if self.lootTabId and currentTab == self.lootTabId then
        self:UpdateLootHistoryList()
        self:UpdateFoundLootList()
    elseif self.historyTabId and currentTab == self.historyTabId then
        self:UpdateHistoryList()
    elseif self.wishlistTabId and currentTab == self.wishlistTabId then
        self:UpdateWishlistUI()
    elseif self.damageTabId and currentTab == self.damageTabId then
        self:UpdateDamageTrackerList()
    elseif debugTabId and currentTab == debugTabId then
        self:UpdateDebugLogList()
    else
        -- Overview and other lightweight tabs.
        self:UpdateRosterList()
    end
    self:UpdateMiniTracker()
    self:UpdateMiniFloatingButtonPosition()
    self:UpdateMinimapButton()
    if traceEnabled and self.RecordCpuSpikeDetail and type(debugprofilestop) == "function" then
        local detail = string.format("tab=%s frame=%s", tostring(self.currentTab or 0), tostring(self.frame and self.frame:IsShown() and "shown" or "hidden"))
        self:RecordCpuSpikeDetail("UI.Refresh", debugprofilestop() - t0, detail)
    end
end
