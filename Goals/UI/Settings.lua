-- Goals UI tab module. Loaded after gui.lua so it can reuse shared UI helpers.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

local UI = Goals.UI
local L = Goals.L
local H = UI and UI.ModuleHelpers
if not UI or not H then
    return
end
local applyInsetTheme = H.applyInsetTheme
local applyFrameTheme = H.applyFrameTheme
local applySectionHeader = H.applySectionHeader
local applySectionCaption = H.applySectionCaption
local createLabel = H.createLabel
local setCheckText = H.setCheckText
local setupSudoDevPopup = H.setupSudoDevPopup
local setupSaveTableHelpPopup = H.setupSaveTableHelpPopup
local setupBuildSharePopup = H.setupBuildSharePopup
local attachSideTooltip = H.attachSideTooltip
local createSmallIconButton = H.createSmallIconButton
local showSideTooltip = H.showSideTooltip
local hideSideTooltip = H.hideSideTooltip
function UI:ShowBackupExport()
    if not self.backupExportFrame then
        local frame = CreateFrame("Frame", "GoalsBackupExportFrame", UIParent, "GoalsFrameTemplate")
        applyFrameTheme(frame)
        frame:SetSize(700, 430)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetToplevel(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        if frame.TitleText then frame.TitleText:SetText("GOALS Backup Export") end

        local hint = createLabel(frame, "Copy this text and keep it somewhere safe. A local restore snapshot is also stored in SavedVariables.", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -38)

        local scroll = CreateFrame("ScrollFrame", "GoalsBackupExportScroll", frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -38, 48)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(630)
        edit:SetScript("OnEscapePressed", function(selfBox) selfBox:ClearFocus() frame:Hide() end)
        scroll:SetScrollChild(edit)
        scroll:SetScript("OnSizeChanged", function(selfScroll)
            edit:SetWidth(math.max(100, (selfScroll:GetWidth() or 630) - 4))
        end)
        local selectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectBtn:SetSize(110, 22)
        selectBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 16)
        selectBtn:SetText("Select All")
        selectBtn:SetScript("OnClick", function() edit:SetFocus() edit:HighlightText() end)
        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeBtn:SetSize(90, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 16)
        closeBtn:SetText(CLOSE or "Close")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)
        frame.edit = edit
        self.backupExportFrame = frame
    end
    self.backupExportFrame.edit:SetText(Goals:ExportBackup())
    self.backupExportFrame:Show()
    self.backupExportFrame.edit:SetFocus()
    self.backupExportFrame.edit:HighlightText()
end

function UI:CreateSettingsTab(page)
    local leftPanel = CreateFrame("Frame", "GoalsSettingsInset", page, "GoalsInsetTemplate")
    applyInsetTheme(leftPanel)
    leftPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    -- Keep the scrolling viewport above the persistent tab footer so the
    -- final checkbox is never drawn underneath the footer text.
    leftPanel:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 42)
    leftPanel:SetWidth(350)
    self.settingsInset = leftPanel
    local leftScroll = CreateFrame("ScrollFrame", "GoalsSettingsScroll", leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -6)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -28, 6)
    local leftInset = CreateFrame("Frame", "GoalsSettingsContent", leftScroll)
    leftInset:SetHeight(600)
    leftInset:SetWidth(316)
    leftScroll:SetScrollChild(leftInset)
    leftScroll:SetScript("OnSizeChanged", function(selfScroll)
        leftInset:SetWidth(math.max(200, (selfScroll:GetWidth() or 316) - 4))
    end)
    self.settingsScroll = leftScroll

    local rightPanel = CreateFrame("Frame", "GoalsSettingsActionsInset", page, "GoalsInsetTemplate")
    applyInsetTheme(rightPanel)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 12, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 42)
    self.settingsActionsInset = rightPanel
    local rightScroll = CreateFrame("ScrollFrame", "GoalsSettingsActionsScroll", rightPanel, "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 6, -6)
    rightScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -28, 6)
    local rightInset = CreateFrame("Frame", "GoalsSettingsActionsContent", rightScroll)
    rightInset:SetHeight(700)
    rightInset:SetWidth(470)
    rightScroll:SetScrollChild(rightInset)
    rightScroll:SetScript("OnSizeChanged", function(selfScroll)
        rightInset:SetWidth(math.max(260, (selfScroll:GetWidth() or 470) - 4))
    end)
    self.settingsActionsScroll = rightScroll

    local settingsTitle = createLabel(leftInset, L.TAB_SETTINGS, "GameFontNormal")
    local settingsBar = applySectionHeader(settingsTitle, leftInset, -6)
    applySectionCaption(settingsBar, "General")

    local combineCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    combineCheck:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -10)
    setCheckText(combineCheck, L.CHECK_COMBINE_HISTORY)
    combineCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("combineBossHistory", selfBtn:GetChecked() and true or false)
    end)
    self.combineCheck = combineCheck

    local minimapCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combineCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(minimapCheck, L.CHECK_MINIMAP)
    minimapCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.minimap.hide = not selfBtn:GetChecked()
        UI:UpdateMinimapButton()
    end)
    self.minimapCheck = minimapCheck

    local autoMinCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    autoMinCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(autoMinCheck, L.CHECK_AUTO_MINIMIZE_COMBAT)
    autoMinCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.autoMinimizeCombat = selfBtn:GetChecked() and true or false
    end)
    self.autoMinimizeCheck = autoMinCheck

    local announceStartCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    announceStartCheck:SetPoint("TOPLEFT", autoMinCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(announceStartCheck, "Announce encounter starts")
    announceStartCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.announceEncounterStarts = selfBtn:GetChecked() and true or false
    end)
    self.announceEncounterStartCheck = announceStartCheck

    local announceWipeCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    announceWipeCheck:SetPoint("TOPLEFT", announceStartCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(announceWipeCheck, "Announce encounter wipes")
    announceWipeCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.announceEncounterWipes = selfBtn:GetChecked() and true or false
    end)
    self.announceEncounterWipeCheck = announceWipeCheck

    local announceCompletionCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    announceCompletionCheck:SetPoint("TOPLEFT", announceWipeCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(announceCompletionCheck, "Announce encounter completion")
    announceCompletionCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.announceEncounterCompletions = selfBtn:GetChecked() and true or false
    end)
    self.announceEncounterCompletionCheck = announceCompletionCheck

    local announceProgressCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    announceProgressCheck:SetPoint("TOPLEFT", announceCompletionCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(announceProgressCheck, "Announce encounter progress")
    announceProgressCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.announceEncounterProgress = selfBtn:GetChecked() and true or false
    end)
    self.announceEncounterProgressCheck = announceProgressCheck

    local localOnlyCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    localOnlyCheck:SetPoint("TOPLEFT", announceProgressCheck, "BOTTOMLEFT", 0, -4)
    setCheckText(localOnlyCheck, "Local-only mode")
    localOnlyCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.localOnly = selfBtn:GetChecked() and true or false
    end)
    self.localOnlyCheck = localOnlyCheck
    local lastSettingsCheck = localOnlyCheck

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
        dbmCheck:SetPoint("TOPLEFT", localOnlyCheck, "BOTTOMLEFT", 0, -4)
        setCheckText(dbmCheck, L.CHECK_DBM_INTEGRATION)
        dbmCheck:SetScript("OnClick", function(selfBtn)
            Goals.db.settings.dbmIntegration = selfBtn:GetChecked() and true or false
            if Goals.db.settings.dbmIntegration and Goals.Events and Goals.Events.InitDBMCallbacks then
                Goals.Events:InitDBMCallbacks()
            end
        end)
        self.dbmIntegrationCheck = dbmCheck

        local dbmWishlistCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
        dbmWishlistCheck:SetPoint("TOPLEFT", dbmCheck, "BOTTOMLEFT", 0, -4)
        setCheckText(dbmWishlistCheck, L.CHECK_DBM_WISHLIST)
        dbmWishlistCheck:SetScript("OnClick", function(selfBtn)
            Goals.db.settings.wishlistDbmIntegration = selfBtn:GetChecked() and true or false
        end)
        self.wishlistDbmIntegrationCheck = dbmWishlistCheck
        lastSettingsCheck = dbmWishlistCheck
    end

    local bindsTitle = createLabel(leftInset, "Keybindings", "GameFontNormal")
    bindsTitle:SetPoint("TOPLEFT", lastSettingsCheck, "BOTTOMLEFT", 12, -16)
    self.settingsKeybindsTitle = bindsTitle

    local uiBindLabel = createLabel(leftInset, "Toggle GOALS UI:", "GameFontHighlightSmall")
    uiBindLabel:SetPoint("TOPLEFT", bindsTitle, "BOTTOMLEFT", 0, -8)
    self.settingsKeybindUiLabel = uiBindLabel

    local uiBindValue = createLabel(leftInset, "", "GameFontHighlightSmall")
    uiBindValue:SetPoint("LEFT", uiBindLabel, "RIGHT", 6, 0)
    uiBindValue:SetJustifyH("LEFT")
    self.settingsKeybindUiValue = uiBindValue

    local miniBindLabel = createLabel(leftInset, "Toggle Mini Viewer:", "GameFontHighlightSmall")
    miniBindLabel:SetPoint("TOPLEFT", uiBindLabel, "BOTTOMLEFT", 0, -6)
    self.settingsKeybindMiniLabel = miniBindLabel

    local miniBindValue = createLabel(leftInset, "", "GameFontHighlightSmall")
    miniBindValue:SetPoint("LEFT", miniBindLabel, "RIGHT", 6, 0)
    miniBindValue:SetJustifyH("LEFT")
    self.settingsKeybindMiniValue = miniBindValue

    setupSudoDevPopup()
    setupSaveTableHelpPopup()
    setupBuildSharePopup()

    local actionsTitle = createLabel(rightInset, "Data Management", "GameFontNormal")
    local actionsBar = applySectionHeader(actionsTitle, rightInset, -6)
    applySectionCaption(actionsBar, "Local maintenance")

    local function createActionButton(text, onClick)
        local btn = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
        btn:SetSize(180, 20)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local function createAlignedDivider(anchor, yOffset)
        if not anchor then
            return nil
        end
        local line = rightInset:CreateTexture(nil, "BORDER")
        line:SetHeight(1)
        line:SetPoint("TOP", anchor, "BOTTOM", 0, yOffset or -8)
        line:SetPoint("LEFT", rightInset, "LEFT", 4, 0)
        line:SetPoint("RIGHT", rightInset, "RIGHT", -4, 0)
        line:SetTexture(1, 1, 1, 0.08)
        return line
    end

    local function applyAlignedSectionHeader(label, anchor, yOffset)
        if not label or not anchor then
            return nil
        end
        local bar = rightInset:CreateTexture(nil, "BORDER")
        bar:SetHeight(16)
        bar:SetPoint("TOP", anchor, "BOTTOM", 0, yOffset or -8)
        bar:SetPoint("LEFT", rightInset, "LEFT", 4, 0)
        bar:SetPoint("RIGHT", rightInset, "RIGHT", -4, 0)
        bar:SetTexture(0, 0, 0, 0.45)
        label:ClearAllPoints()
        label:SetPoint("LEFT", bar, "LEFT", 6, 0)
        label:SetTextColor(0.92, 0.8, 0.5, 1)
        return bar
    end

    local ACTIONS_LEFT = 2

    local backupBtn = createActionButton("Create Local Backup", function()
        local _, msg = Goals:CreateLocalBackup()
        if msg then Goals:Print(msg) end
        UI:Refresh()
    end)
    backupBtn:SetPoint("TOPLEFT", actionsTitle, "BOTTOMLEFT", ACTIONS_LEFT, -10)
    attachSideTooltip(backupBtn, "Create a restorable snapshot inside GOALS SavedVariables.")
    self.createBackupButton = backupBtn

    local exportBackupBtn = createActionButton("Export Backup Text", function()
        Goals:CreateLocalBackup()
        UI:Refresh()
        UI:ShowBackupExport()
    end)
    exportBackupBtn:SetPoint("TOPLEFT", backupBtn, "BOTTOMLEFT", 0, -6)
    attachSideTooltip(exportBackupBtn, "Create a local snapshot and open a copyable archival text version.")

    if StaticPopupDialogs and not StaticPopupDialogs.GOALS_RESTORE_LOCAL_BACKUP then
        StaticPopupDialogs.GOALS_RESTORE_LOCAL_BACKUP = {
            text = "Restore the most recent local GOALS backup? Current points, history, settings, wishlists, and saved tables will be replaced.",
            button1 = "Restore",
            button2 = CANCEL,
            OnAccept = function()
                local ok, msg = Goals:RestoreLocalBackup()
                if msg then Goals:Print(msg) end
                if ok and UI then UI:Refresh() end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
    end
    local restoreBackupBtn = createActionButton("Restore Local Backup", function()
        if StaticPopup_Show then StaticPopup_Show("GOALS_RESTORE_LOCAL_BACKUP") end
    end)
    restoreBackupBtn:SetPoint("TOPLEFT", exportBackupBtn, "BOTTOMLEFT", 0, -6)
    attachSideTooltip(restoreBackupBtn, "Replace current points, history, settings, wishlists, and saved tables with the latest local snapshot.")
    self.restoreBackupButton = restoreBackupBtn

    local backupStatus = createLabel(rightInset, "No local backup", "GameFontHighlightSmall")
    backupStatus:SetPoint("LEFT", backupBtn, "RIGHT", 10, 0)
    backupStatus:SetJustifyH("LEFT")
    self.backupStatusLabel = backupStatus

    if StaticPopupDialogs and not StaticPopupDialogs.GOALS_CONFIRM_LOCAL_ACTION then
        StaticPopupDialogs.GOALS_CONFIRM_LOCAL_ACTION = {
            text = "%s\n\nThis only changes your local GOALS data.",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = function(_, data)
                if data and data.action then data.action() end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
    end
    local function confirmLocalAction(label, action)
        if StaticPopup_Show then
            StaticPopup_Show("GOALS_CONFIRM_LOCAL_ACTION", label, nil, { action = action })
        end
    end

    local clearPointsBtn = createActionButton("Clear All Points", function()
        confirmLocalAction("Clear all points?", function()
            if Goals and Goals.ClearAllPointsLocal then Goals:ClearAllPointsLocal() end
        end)
    end)
    clearPointsBtn:SetPoint("TOPLEFT", restoreBackupBtn, "BOTTOMLEFT", 0, -14)

    local clearPlayersBtn = createActionButton("Clear Players List", function()
        confirmLocalAction("Clear the players list?", function()
            if Goals and Goals.ClearPlayersLocal then Goals:ClearPlayersLocal() end
        end)
    end)
    clearPlayersBtn:SetPoint("TOPLEFT", clearPointsBtn, "BOTTOMLEFT", 0, -6)

    local clearHistoryBtn = createActionButton("Clear History", function()
        confirmLocalAction("Clear local history?", function()
            if Goals and Goals.ClearHistoryLocal then Goals:ClearHistoryLocal() end
        end)
    end)
    clearHistoryBtn:SetPoint("TOPLEFT", clearPlayersBtn, "BOTTOMLEFT", 0, -6)

    local clearAllBtn = createActionButton("Clear Points/Players/History", function()
        confirmLocalAction("Clear points, players, and history?", function()
            if Goals and Goals.ClearAllLocal then Goals:ClearAllLocal() end
        end)
    end)
    clearAllBtn:SetWidth(200)
    clearAllBtn:SetPoint("TOPLEFT", clearHistoryBtn, "BOTTOMLEFT", 0, -10)

    local miniDivider = createAlignedDivider(clearAllBtn, -6)
    local miniTitle = createLabel(rightInset, L.LABEL_MINI_TRACKER, "GameFontNormal")
    local miniBar = applyAlignedSectionHeader(miniTitle, miniDivider or clearAllBtn, -6)
    applySectionCaption(miniBar, "Quick view")
    if miniBar then
        local resetMiniBtn = createSmallIconButton(rightInset, 16, "Interface\\Buttons\\UI-RefreshButton")
        resetMiniBtn:SetPoint("RIGHT", miniBar, "RIGHT", -6, 0)
        resetMiniBtn:SetScript("OnClick", function()
            if UI and UI.ResetMiniTrackerPosition then
                UI:ResetMiniTrackerPosition()
            end
        end)
        resetMiniBtn:SetScript("OnEnter", function(selfBtn)
            showSideTooltip("Reset Mini Position")
        end)
        resetMiniBtn:SetScript("OnLeave", function()
            hideSideTooltip()
        end)
    end

    local miniBtn = createActionButton(L.BUTTON_TOGGLE_MINI_TRACKER, function()
        if UI and UI.ToggleMiniTracker then
            UI:ToggleMiniTracker()
        end
    end)
    miniBtn:SetPoint("TOPLEFT", clearAllBtn, "BOTTOMLEFT", 0, -34)
    self.settingsMiniTrackerButton = miniBtn

    local editDivider = createAlignedDivider(miniBtn, -6)
    local editTitle = createLabel(rightInset, "Local Editing", "GameFontNormal")
    local editBar = applyAlignedSectionHeader(editTitle, editDivider or miniBtn, -6)
    applySectionCaption(editBar, "Admin tools")

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
    sudoBtn:SetPoint("TOPLEFT", miniBtn, "BOTTOMLEFT", 0, -40)
    self.settingsSudoDevButton = sudoBtn

    local syncRequestBtn = createActionButton("Ask for sync", function()
        if Goals and Goals.Comm and Goals.Comm.RequestSync then
            Goals.Comm:RequestSync("MANUAL")
        end
    end)
    syncRequestBtn:SetPoint("TOPLEFT", sudoBtn, "BOTTOMLEFT", 0, -6)
    syncRequestBtn:SetScript("OnEnter", function(selfBtn)
        showSideTooltip("Ask the loot master to send a full roster/points sync.")
    end)
    syncRequestBtn:SetScript("OnLeave", function()
        hideSideTooltip()
    end)
    self.settingsSyncRequestButton = syncRequestBtn

    -- Size each scroll child to its actual controls. Fixed oversized heights
    -- leave a long, empty scroll range when the Settings page is taller than
    -- its contents.
    local function fitScrollContent(scroll, content, bottomControl)
        local function updateHeight()
            local contentTop = content:GetTop()
            local controlBottom = bottomControl:GetBottom()
            local viewportHeight = scroll:GetHeight() or 0
            if contentTop and controlBottom then
                content:SetHeight(math.max(viewportHeight, contentTop - controlBottom + 12))
                scroll:UpdateScrollChildRect()
            end
        end
        scroll:HookScript("OnShow", updateHeight)
        scroll:HookScript("OnSizeChanged", updateHeight)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, updateHeight)
        else
            updateHeight()
        end
    end

    fitScrollContent(leftScroll, leftInset, miniBindLabel)
    fitScrollContent(rightScroll, rightInset, syncRequestBtn)
end
