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

function UI:GetAllPlayerNames()
    local names = {}
    local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
    for name in pairs(players) do
        table.insert(names, name)
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

function UI:GetSortedPlayers()
    local list = {}
    local playerMap = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players)
    if not playerMap then
        return list
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    local present = Goals:GetPresenceMap()
    local showPresentOnly = overviewSettings.showPresentOnly
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
    local mode = overviewSettings.sortMode or "POINTS"
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
                local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
                overviewSettings.sortMode = option.value
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                UIDropDownMenu_SetText(dropdown, option.text)
                Goals:NotifyDataChanged()
            end
            local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
            info.checked = overviewSettings.sortMode == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self:SyncSortDropdown()
end

function UI:SyncSortDropdown()
    if not self.sortDropdown then
        return
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    local selected = overviewSettings.sortMode or "POINTS"
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

function UI:ShowOverviewMigrationPrompt()
    local frame = ensureOverviewMigrationPrompt()
    if not frame then
        return
    end
    if frame.content then
        frame.content:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
        frame.content:SetAlpha(1)
    end
    ensureOverviewMigrationPromptWidgets(frame)
    if self.frame and self.frame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    layoutOverviewMigrationPrompt(frame)
    frame:Show()
    layoutOverviewMigrationPrompt(frame)
end

function UI:CreateOverviewTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsOverviewOptionsInset", OPTIONS_PANEL_WIDTH)
    self.overviewOptionsFrame = optionsPanel
    self.overviewOptionsScroll = optionsPanel.scroll
    self.overviewOptionsContent = optionsContent
    self.overviewOptionsOpen = true
    self.overviewOptionsInline = true

    local rosterInset = CreateFrame("Frame", "GoalsOverviewRosterInset", page, "GoalsInsetTemplate")
    applyInsetTheme(rosterInset)
    rosterInset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    rosterInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    rosterInset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    self.rosterInset = rosterInset
    if page.footer then
        anchorToFooter(rosterInset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(rosterInset, "GoalsRosterTable", {
        columns = {
            { key = "status", title = "", width = 18, justify = "LEFT", wrap = false },
            { key = "player", title = "Player", width = 220, justify = "LEFT", wrap = false },
            { key = "points", title = "Points", width = 60, justify = "RIGHT", wrap = false },
            { key = "actions", title = "Actions", fill = true, justify = "LEFT", wrap = false },
        },
        rowHeight = ROW_HEIGHT,
        visibleRows = ROSTER_ROWS,
        headerHeight = 16,
    })
    self.rosterTable = tableWidget
    self.rosterScroll = tableWidget.scroll
    self.rosterRows = tableWidget.rows

    local actionsHeader = nil
    for _, col in ipairs(tableWidget.columns or {}) do
        if col.key == "actions" then
            actionsHeader = col.header
            break
        end
    end
    if actionsHeader then
        local okAllPlus, allPlusBtn = pcall(CreateFrame, "Button", "GoalsRosterAllPlusButton", tableWidget.header, "UIPanelButtonTemplate2")
        if not (okAllPlus and allPlusBtn) then
            allPlusBtn = CreateFrame("Button", "GoalsRosterAllPlusButton", tableWidget.header, "UIPanelButtonTemplate")
        end
        allPlusBtn:SetSize(48, 16)
        allPlusBtn:SetText("+1 All")
        allPlusBtn:SetPoint("RIGHT", tableWidget.header, "RIGHT", -2, 0)
        allPlusBtn:SetScript("OnClick", function()
            Goals:AwardPresentPoints(1, "Roster +1 All")
        end)
        self.rosterAllPlusButton = allPlusBtn
    end

    self.rosterScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateRosterList()
        end)
    end)
    self.rosterScroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, selfScroll._contentHeight or 0)
    end)
    local autoSyncTicker = CreateFrame("Frame", nil, rosterInset)
    autoSyncTicker.elapsed = 0
    local function startAutoSyncTicker()
        autoSyncTicker:SetScript("OnUpdate", function(selfFrame, elapsed)
            selfFrame.elapsed = selfFrame.elapsed + (elapsed or 0)
            if selfFrame.elapsed < 0.5 then
                return
            end
            selfFrame.elapsed = 0
            if UI and UI.UpdateAutoSyncLabel then
                UI:UpdateAutoSyncLabel()
            end
        end)
    end
    local function stopAutoSyncTicker()
        autoSyncTicker:SetScript("OnUpdate", nil)
    end
    autoSyncTicker:SetScript("OnShow", function()
        startAutoSyncTicker()
    end)
    autoSyncTicker:SetScript("OnHide", function()
        stopAutoSyncTicker()
    end)
    if autoSyncTicker:IsShown() then
        startAutoSyncTicker()
    end
    self.autoSyncTicker = autoSyncTicker

    for i = 1, #self.rosterRows do
        local row = self.rosterRows[i]
        if row.cols and row.cols.status then
            row.cols.status:SetText("")
        end
        if row.cols and row.cols.actions then
            row.cols.actions:SetText("")
        end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        if row.cols and row.cols.status then
            icon:SetPoint("LEFT", row.cols.status, "LEFT", 0, 0)
        else
            icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        end
        row.icon = icon

        local nameText = row.cols and row.cols.player or row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        nameText:SetText("")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        local pointsText = row.cols and row.cols.points or row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        pointsText:SetText("0")
        pointsText:SetWordWrap(false)
        pointsText:SetJustifyH("RIGHT")
        if not (row.cols and row.cols.points) then
            pointsText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        end
        row.pointsText = pointsText

        local actionsAnchor = CreateFrame("Frame", nil, row)
        if row.cols and row.cols.actions then
            actionsAnchor:SetPoint("LEFT", row.cols.actions, "LEFT", 0, 0)
        else
            actionsAnchor:SetPoint("LEFT", row, "LEFT", 0, 0)
        end
        actionsAnchor:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        actionsAnchor:SetHeight(ROW_HEIGHT)
        row.actionsAnchor = actionsAnchor

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

        add:SetPoint("LEFT", actionsAnchor, "LEFT", 0, 0)
        sub:SetPoint("LEFT", add, "RIGHT", 2, 0)
        reset:SetPoint("LEFT", sub, "RIGHT", 2, 0)
        undo:SetPoint("LEFT", reset, "RIGHT", 2, 0)
        remove:SetPoint("LEFT", undo, "RIGHT", 2, 0)

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
                local dis = Goals.db and Goals.db.settings and Goals.db.settings.disenchanter or ""
                local playerName = row.playerName
                if dis ~= "" and Goals.NormalizeName and Goals:NormalizeName(dis) == Goals:NormalizeName(playerName) then
                    local last = Goals.state and Goals.state.lastLoot or nil
                    if last and last.name and last.link then
                        local window = 600
                        if Goals:NormalizeName(last.name) == Goals:NormalizeName(playerName) and (time() - (last.ts or 0)) <= window then
                            if Goals.HandleManualLootReset and Goals:HandleManualLootReset(playerName, last.link, false) then
                                return
                            end
                        end
                    end
                end
                Goals:SetPoints(playerName, 0, "Roster reset")
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
    end

    local y = -10
    local adminControls = {}
    local function trackAdmin(control)
        if control then
            table.insert(adminControls, control)
        end
    end
    self.overviewAdminControls = adminControls
    local function addSectionHeader(text)
        local label, bar = createOptionsHeader(optionsContent, text, y)
        y = y - 22
        return label, bar
    end

    local function addLabel(text)
        local label = createLabel(optionsContent, text, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsControlLabel(label)
        y = y - 18
        return label
    end

    local function addInfoLabel(text, template)
        local label = createLabel(optionsContent, text, template or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsLabel(label)
        y = y - 16
        return label
    end

    local function addCheck(text, onClick, tooltipText)
        local check = CreateFrame("CheckButton", nil, optionsContent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsCheck(check)
        setCheckText(check, text)
        check:SetScript("OnClick", onClick)
        attachSideTooltip(check, tooltipText)
        y = y - 28
        return check
    end

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        y = y - 30
        return btn
    end

    local function addButtonPair(leftText, leftClick, rightText, rightClick)
        local gap = 6
        local width = math.floor((OPTIONS_CONTROL_WIDTH - gap) / 2)
        local leftBtn = createOptionsButton(optionsContent)
        styleOptionsButton(leftBtn, width)
        leftBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        leftBtn:SetText(leftText)
        leftBtn:SetScript("OnClick", leftClick)

        local rightBtn = createOptionsButton(optionsContent)
        styleOptionsButton(rightBtn, width)
        rightBtn:SetPoint("LEFT", leftBtn, "RIGHT", gap, 0)
        rightBtn:SetText(rightText)
        rightBtn:SetScript("OnClick", rightClick)

        y = y - 30
        return leftBtn, rightBtn
    end

    addSectionHeader("Roster")
    addLabel(L.LABEL_SORT)
    local sortDrop = addDropdown("GoalsSortDropdown")
    attachSideTooltip(sortDrop, "Choose how the roster is sorted.")
    self.sortDropdown = sortDrop
    self:SetupSortDropdown(sortDrop)

    local presentCheck = addCheck("Show present players", function(selfBtn)
        local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
        overviewSettings.showPresentOnly = selfBtn:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end, "Show only players currently in your group.")
    self.presentCheck = presentCheck

    local disableGainCheck = addCheck("Pause point gains", function(selfBtn)
        Goals:SetRaidSetting("disablePointGain", selfBtn:GetChecked() and true or false)
    end, "Pause automatic point awards and adjustments.")
    self.disablePointGainCheck = disableGainCheck

    local disableGainStatus = addInfoLabel("")
    disableGainStatus:SetJustifyH("LEFT")
    disableGainStatus:Hide()
    self.disablePointGainStatus = disableGainStatus

    y = y - 8
    addSectionHeader("General")

    local minimapCheck = addCheck("Show minimap button", function(selfBtn)
        Goals.db.settings.minimap.hide = not selfBtn:GetChecked()
        UI:UpdateMinimapButton()
    end, "Show the GOALS minimap button.")
    self.quickMinimapCheck = minimapCheck

    local autoMinCheck = addCheck("Auto-minimize in combat", function(selfBtn)
        Goals.db.settings.autoMinimizeCombat = selfBtn:GetChecked() and true or false
    end, "Minimize GOALS automatically when combat starts.")
    self.quickAutoMinimizeCheck = autoMinCheck

    self.quickAnnounceEncounterStartCheck = addCheck("Announce encounter starts", function(selfBtn)
        Goals.db.settings.announceEncounterStarts = selfBtn:GetChecked() and true or false
    end, "Show a local chat message when a tracked encounter begins.")

    self.quickAnnounceEncounterWipeCheck = addCheck("Announce encounter wipes", function(selfBtn)
        Goals.db.settings.announceEncounterWipes = selfBtn:GetChecked() and true or false
    end, "Show a local chat message when a tracked encounter ends in a wipe.")

    self.quickAnnounceEncounterCompletionCheck = addCheck("Announce encounter completion", function(selfBtn)
        Goals.db.settings.announceEncounterCompletions = selfBtn:GetChecked() and true or false
    end, "Show a local chat message when a boss point is awarded.")

    local localOnlyCheck = addCheck("Local-only mode", function(selfBtn)
        Goals.db.settings.localOnly = selfBtn:GetChecked() and true or false
    end, "Disable syncing; changes stay on this client.")
    self.quickLocalOnlyCheck = localOnlyCheck

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
        local dbmCheck = addCheck("Use DBM encounter events", function(selfBtn)
            Goals.db.settings.dbmIntegration = selfBtn:GetChecked() and true or false
            if Goals.db.settings.dbmIntegration and Goals.Events and Goals.Events.InitDBMCallbacks then
                Goals.Events:InitDBMCallbacks()
            end
        end, "Use DBM encounter events to improve boss tracking (if installed).")
        self.quickDbmIntegrationCheck = dbmCheck

        local dbmWishlistCheck = addCheck("DBM wishlist alerts", function(selfBtn)
            Goals.db.settings.wishlistDbmIntegration = selfBtn:GetChecked() and true or false
        end, "Use DBM events to help detect wishlist drops.")
        self.quickWishlistDbmIntegrationCheck = dbmWishlistCheck
    end

    y = y - 8
    addSectionHeader(L.LABEL_SYNC)
    local syncValue = createLabel(optionsContent, "", "GameFontHighlight")
    syncValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    syncValue:SetJustifyH("LEFT")
    self.syncValue = syncValue
    y = y - 18

    local autoSyncLabel = createLabel(optionsContent, "", "GameFontHighlightSmall")
    autoSyncLabel:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    autoSyncLabel:SetJustifyH("LEFT")
    styleOptionsLabel(autoSyncLabel)
    self.autoSyncLabel = autoSyncLabel
    y = y - 16

    local syncNote = createLabel(optionsContent, "", "GameFontHighlightSmall")
    syncNote:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    syncNote:SetJustifyH("LEFT")
    styleOptionsLabel(syncNote)
    syncNote:Hide()
    self.syncNoteLabel = syncNote
    y = y - 20

    local syncRequestBtn = addButton("Request sync", function()
        if Goals and Goals.Comm and Goals.Comm.RequestSync then
            Goals.Comm:RequestSync("MANUAL")
        end
    end)
    syncRequestBtn:SetScript("OnEnter", function(selfBtn)
        showSideTooltip("Request a full roster and points sync from the loot master.")
    end)
    syncRequestBtn:SetScript("OnLeave", function()
        hideSideTooltip()
    end)
    self.syncRequestButton = syncRequestBtn

    addLabel(L.LABEL_DISENCHANTER)
    local disValue = createLabel(optionsContent, "", "GameFontHighlight")
    disValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    disValue:SetJustifyH("LEFT")
    self.disenchantValue = disValue
    y = y - 18

    addLabel(L.SETTINGS_DISENCHANTER)
    local disDrop = addDropdown("GoalsDisenchanterDropdown")
    attachSideTooltip(disDrop, "Select the player who will disenchant items.")
    disDrop.colorize = true
    self.disenchanterDropdown = disDrop
    self:SetupDropdown(disDrop, function()
        return UI:GetDisenchanterCandidates()
    end, function(name)
        if name == L.NONE_OPTION then
            Goals:SetDisenchanter("")
            return
        end
        Goals:SetDisenchanter(name)
    end, L.SELECT_OPTION)
    y = y - 8

    setupSudoDevPopup()
    setupSaveTableHelpPopup()
    setupBuildSharePopup()

    local function addActionButton(text, onClick)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        y = y - 30
        return btn
    end

    y = y - 8
    local maintenanceLabel, maintenanceBar = addSectionHeader("Maintenance")
    self.overviewMaintenanceLabel = maintenanceLabel
    self.overviewMaintenanceBar = maintenanceBar
    trackAdmin(maintenanceLabel)
    trackAdmin(maintenanceBar)

    local clearPointsBtn = addActionButton("Clear All Points", function()
        if Goals and Goals.ClearAllPointsLocal then
            Goals:ClearAllPointsLocal()
        end
    end)
    trackAdmin(clearPointsBtn)
    self.overviewClearPointsBtn = clearPointsBtn

    local clearPlayersBtn = addActionButton("Clear Players List", function()
        if Goals and Goals.ClearPlayersLocal then
            Goals:ClearPlayersLocal()
        end
    end)
    trackAdmin(clearPlayersBtn)
    self.overviewClearPlayersBtn = clearPlayersBtn

    local clearHistoryBtn = addActionButton("Clear History", function()
        if Goals and Goals.ClearHistoryLocal then
            Goals:ClearHistoryLocal()
        end
    end)
    trackAdmin(clearHistoryBtn)
    self.overviewClearHistoryBtn = clearHistoryBtn

    local clearAllBtn = addActionButton("Clear All", function()
        if Goals and Goals.ClearAllLocal then
            Goals:ClearAllLocal()
        end
    end)
    trackAdmin(clearAllBtn)
    self.overviewClearAllBtn = clearAllBtn

    y = y - 8
    local miniLabel, miniBar = addSectionHeader(L.LABEL_MINI_TRACKER)
    self.overviewMiniLabel = miniLabel
    self.overviewMiniBar = miniBar
    local resetMiniBtn = addActionButton("Reset Mini Position", function()
        if UI and UI.ResetMiniTrackerPosition then
            UI:ResetMiniTrackerPosition()
        end
    end)
    self.overviewResetMiniBtn = resetMiniBtn

    local miniBtn = addActionButton(L.BUTTON_TOGGLE_MINI_TRACKER, function()
        if UI and UI.ToggleMiniTracker then
            UI:ToggleMiniTracker()
        end
    end)
    self.miniTrackerButton = miniBtn

    y = y - 8
    local devLabel, devBar = addSectionHeader("Dev Tools")
    self.overviewDevLabel = devLabel
    self.overviewDevBar = devBar
    trackAdmin(devLabel)
    trackAdmin(devBar)

    local sudoBtn = addActionButton("", function()
        if Goals.db.settings.sudoDev then
            Goals.db.settings.sudoDev = false
            UI:Refresh()
            return
        end
        if StaticPopup_Show then
            StaticPopup_Show("GOALS_SUDO_DEV")
        end
    end)
    self.sudoDevButton = sudoBtn
    trackAdmin(sudoBtn)

    y = y - 8
    local keybindsLabel, keybindsBar = addSectionHeader("Keybindings")
    self.overviewKeybindsLabel = keybindsLabel
    self.overviewKeybindsBar = keybindsBar
    self.keybindsTitle = keybindsLabel

    local uiBindLabel = addLabel("Toggle main window:")
    self.keybindUiLabel = uiBindLabel
    local uiBindValue = createLabel(optionsContent, "", "GameFontHighlightSmall")
    uiBindValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    uiBindValue:SetJustifyH("LEFT")
    styleOptionsLabel(uiBindValue)
    self.keybindUiValue = uiBindValue
    y = y - 16

    local miniBindLabel = addLabel("Toggle mini tracker:")
    self.keybindMiniLabel = miniBindLabel
    local miniBindValue = createLabel(optionsContent, "", "GameFontHighlightSmall")
    miniBindValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    miniBindValue:SetJustifyH("LEFT")
    styleOptionsLabel(miniBindValue)
    self.keybindMiniValue = miniBindValue
    y = y - 16

    local function storeOverviewAnchor(control)
        if not control or control._overviewAnchor then
            return
        end
        local point, relative, relativePoint, x, y = control:GetPoint(1)
        if not point then
            return
        end
        control._overviewAnchor = {
            point = point,
            relative = relative,
            relativePoint = relativePoint,
            x = x or 0,
            y = y or 0,
        }
    end

    self.overviewShiftBelowMaintenance = {
        self.overviewMiniBar,
        self.overviewResetMiniBtn,
        self.miniTrackerButton,
        self.overviewDevBar,
        self.sudoDevButton,
    }

    self.overviewShiftBelowDev = {
        self.overviewKeybindsBar,
        self.keybindsTitle,
        self.keybindUiLabel,
        self.keybindUiValue,
        self.keybindMiniLabel,
        self.keybindMiniValue,
    }

    for _, control in ipairs(self.overviewShiftBelowMaintenance) do
        storeOverviewAnchor(control)
    end
    for _, control in ipairs(self.overviewShiftBelowDev) do
        storeOverviewAnchor(control)
    end
    storeOverviewAnchor(self.overviewMaintenanceBar)

    function UI:UpdateOverviewOptionsLayout(hasAccess)
        local function restore(list)
            for _, control in ipairs(list or {}) do
                local anchor = control and control._overviewAnchor or nil
                if anchor and control.ClearAllPoints then
                    control:ClearAllPoints()
                    control:SetPoint(anchor.point, anchor.relative, anchor.relativePoint, anchor.x, anchor.y)
                end
            end
        end

        local function shift(list, delta)
            for _, control in ipairs(list or {}) do
                local anchor = control and control._overviewAnchor or nil
                if anchor and control.ClearAllPoints then
                    control:ClearAllPoints()
                    control:SetPoint(anchor.point, anchor.relative, anchor.relativePoint, anchor.x, anchor.y + delta)
                end
            end
        end

        restore(self.overviewShiftBelowMaintenance)
        restore(self.overviewShiftBelowDev)

        if not hasAccess then
            local content = self.overviewOptionsContent or nil
            local anchor = self.overviewMaintenanceBar and self.overviewMaintenanceBar._overviewAnchor or nil
            if content and anchor then
                local y = anchor.y or 0
                local function setHeader(bar)
                    if not bar or not bar.ClearAllPoints then
                        return
                    end
                    bar:ClearAllPoints()
                    bar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                    bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                    y = y - 22
                end
                local function setControl(control, step)
                    if not control or not control.ClearAllPoints then
                        return
                    end
                    control:ClearAllPoints()
                    control:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - (step or 30)
                end
                local function setControlIfShown(control, step)
                    if control and control.IsShown and not control:IsShown() then
                        return
                    end
                    setControl(control, step)
                end
                local function setSpacer(amount)
                    y = y - (amount or 8)
                end

                -- Mini section
                setHeader(self.overviewMiniBar)
                setControl(self.overviewResetMiniBtn, 30)
                setControl(self.miniTrackerButton, 30)

                -- Keybindings section (skip Dev Tools entirely)
                setSpacer(0)
                setHeader(self.overviewKeybindsBar)
                if self.keybindUiLabel and self.keybindUiLabel.ClearAllPoints then
                    self.keybindUiLabel:ClearAllPoints()
                    self.keybindUiLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 18
                end
                if self.keybindUiValue and self.keybindUiValue.ClearAllPoints then
                    self.keybindUiValue:ClearAllPoints()
                    self.keybindUiValue:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 16
                end
                if self.keybindMiniLabel and self.keybindMiniLabel.ClearAllPoints then
                    self.keybindMiniLabel:ClearAllPoints()
                    self.keybindMiniLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 18
                end
                if self.keybindMiniValue and self.keybindMiniValue.ClearAllPoints then
                    self.keybindMiniValue:ClearAllPoints()
                    self.keybindMiniValue:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 16
                end

                local contentHeight = math.abs(y) + 24
                content:SetHeight(contentHeight)
                if self.overviewOptionsScroll then
                    setScrollBarAlwaysVisible(self.overviewOptionsScroll, contentHeight)
                end
            else
                shift(self.overviewShiftBelowMaintenance, 0)
            end
        else
            local content = self.overviewOptionsContent
            if content and content._defaultHeight then
                content:SetHeight(content._defaultHeight)
                if self.overviewOptionsScroll then
                    setScrollBarAlwaysVisible(self.overviewOptionsScroll, content._defaultHeight)
                end
            end
        end
    end

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    optionsContent._defaultHeight = contentHeight
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
end
