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
function UI:UpdateRainbowRows()
    local function updateRow(row)
        if not row or not row.rainbowData then
            return false
        end
        local data = row.rainbowData
        if row.cols then
            if data.kind == "loot" then
                local eventCol = row.cols.event or row.cols.item
                if eventCol then
                    if row.cols and eventCol == row.cols.item then
                        setLootItemLabelText(eventCol, data.itemLink or "")
                    else
                        eventCol:SetText(data.itemLink or "")
                    end
                end
                if row.cols.player then
                    row.cols.player:SetText(formatPlayersCount(data.count))
                    row.cols.player:SetTextColor(1, 1, 1)
                end
                if row.cols.notes then
                    row.cols.notes:SetText("Assigned")
                end
            elseif data.kind == "boss" then
                if row.cols.event then
                    row.cols.event:SetText(data.encounter or "Boss")
                end
                if row.cols.player then
                    row.cols.player:SetText(formatPlayersCount(data.count))
                    row.cols.player:SetTextColor(1, 1, 1)
                end
                if row.cols.notes then
                    row.cols.notes:SetText(string.format("+%d", data.points or 0))
                end
            end
            return true
        end
        if not row.text or not row.text.SetText then
            return false
        end
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

function UI:UpdateFrameWidthForTab(tabId)
    if not self.frame then
        return
    end
    local normalW = self.mainFrameNormalWidth or MAIN_FRAME_WIDTH
    local combatW = self.mainFrameCombatWidth or MAIN_FRAME_WIDTH_COMBAT
    local targetW = normalW
    if self.damageTabId and tabId == self.damageTabId then
        targetW = combatW
        local extra = tonumber(self.combatDynamicWidthExtra) or 0
        if extra < 0 then
            extra = 0
        elseif extra > COMBAT_DYNAMIC_EXTRA_MAX then
            extra = COMBAT_DYNAMIC_EXTRA_MAX
        end
        targetW = targetW + extra
    end
    local parentW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
    if parentW and parentW > 0 then
        local maxAllowed = parentW - (FRAME_EDGE_MARGIN_UI * 2)
        if maxAllowed > 420 and targetW > maxAllowed then
            targetW = maxAllowed
        end
    end
    local currentW = self.frame:GetWidth() or normalW
    if math.abs(currentW - targetW) < 1 then
        return
    end
    self.frame:SetWidth(targetW)
end

function UI:UpdateTabFooters()
    if not self.tabFooters then
        return
    end
    local access = getAccessStatus()
    local settings = Goals.db and Goals.db.settings or {}
    local localOnly = settings.localOnly and "Local only" or "Sync enabled"
    local syncFrom = "Unknown"
    if Goals and Goals.sync then
        if Goals.sync.isMaster then
            syncFrom = Goals.GetPlayerName and Goals:GetPlayerName() or "You"
        elseif Goals.sync.masterName and Goals.sync.masterName ~= "" then
            syncFrom = colorizeName(Goals.sync.masterName)
        end
    end
    local last = Goals and Goals.lastSyncReceivedAt or nil
    local lastText = "--:--:--"
    if last then
        local elapsed = math.max(0, time() - last)
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        lastText = string.format("%02d:%02d:%02d", hours, mins, secs)
    end
    local dis = self.GetDisenchanterStatus and self:GetDisenchanterStatus() or "None set"
    local rightText = string.format("Tracking: Enabled | Disenchanter: %s", dis)
    local leftText = string.format("%s | %s", access, localOnly)
    local centerText = string.format("Syncing From: %s | %s ago", syncFrom, lastText)

    for key, footer in pairs(self.tabFooters) do
        if footer.leftText then
            footer.leftText:SetText(leftText)
        end
        if footer.centerText then
            footer.centerText:SetText(centerText)
        end
        if footer.rightText then
            footer.rightText:SetText(rightText)
        end

        local footer2 = self.tabFooters2 and self.tabFooters2[key] or nil
        if footer2 then
            local left2, center2, right2 = self:GetTabFooter2Segments(key)
            local hasAny = (left2 and left2 ~= "") or (center2 and center2 ~= "") or (right2 and right2 ~= "")
            if footer2.leftText then
                footer2.leftText:SetText(left2 or "")
            end
            if footer2.centerText then
                footer2.centerText:SetText(center2 or "")
            end
            if footer2.rightText then
                footer2.rightText:SetText(right2 or "")
            end
            setShown(footer2, hasAny)

        end
    end
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
    local urlText = updateUrl ~= "" and updateUrl or L.UPDATE_DOWNLOAD_MISSING
    if self.updateUrlText.SetText then
        self.updateUrlText._lockedText = urlText
        self.updateUrlText:SetText(urlText)
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

function UI:CreateHelpTab(page)
    local navInset = CreateFrame("Frame", "GoalsHelpNavInset", page, "GoalsInsetTemplate")
    applyInsetTheme(navInset)
    navInset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    navInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    navInset:SetWidth(190)
    self.helpNavInset = navInset

    local contentInset = CreateFrame("Frame", "GoalsHelpContentInset", page, "GoalsInsetTemplate")
    applyInsetTheme(contentInset)
    contentInset:SetPoint("TOPLEFT", navInset, "TOPRIGHT", 12, 0)
    contentInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    self.helpContentInset = contentInset
    if page.footer then
        anchorToFooter(navInset, page.footer, 2, nil, 6)
        anchorToFooter(contentInset, page.footer, nil, -2, 6)
    end

    local navTitle = createLabel(navInset, "Help Topics", "GameFontNormal")
    navTitle:SetPoint("TOPLEFT", navInset, "TOPLEFT", 10, -10)

    local navScroll = CreateFrame("ScrollFrame", "GoalsHelpNavScroll", navInset, "FauxScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", navTitle, "BOTTOMLEFT", -2, -6)
    navScroll:SetPoint("BOTTOMRIGHT", navInset, "BOTTOMRIGHT", -26, 10)
    self.helpNavScroll = navScroll

    local rowHeight = 18
    local maxRows = 24
    self.helpNavRows = {}
    for i = 1, maxRows do
        local row = CreateFrame("Button", nil, navInset)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", navScroll, "TOPLEFT", 0, -6 - (i - 1) * rowHeight)
        row:SetPoint("RIGHT", navInset, "RIGHT", -6, 0)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(row)
        row.highlight = highlight
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selected:SetBlendMode("ADD")
        selected:SetAllPoints(row)
        selected:Hide()
        row.selected = selected
        local expandBtn = CreateFrame("Button", nil, row)
        expandBtn:SetSize(14, 14)
        expandBtn:SetScript("OnClick", function()
            if row.nodeType ~= "folder" then
                return
            end
            self.helpNavState = self.helpNavState or {}
            self.helpNavState[row.nodeId] = not self.helpNavState[row.nodeId]
            self:RefreshHelpNav()
        end)
        row.expandBtn = expandBtn
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetJustifyH("LEFT")
        row.text = text
        row:SetScript("OnClick", function()
            if row.nodeType == "folder" then
                self.helpNavState = self.helpNavState or {}
                self.helpNavState[row.nodeId] = not self.helpNavState[row.nodeId]
                self:RefreshHelpNav()
                return
            end
            if row.nodeId then
                self:SelectHelpPage(row.nodeId)
            end
        end)
        self.helpNavRows[i] = row
    end

    local contentTitle = createLabel(contentInset, "Help", "GameFontNormalLarge")
    contentTitle:SetPoint("TOPLEFT", contentInset, "TOPLEFT", 12, -12)
    self.helpContentTitle = contentTitle

    local contentScroll = CreateFrame("ScrollFrame", "GoalsHelpContentScroll", contentInset, "UIPanelScrollFrameTemplate")
    contentScroll:SetPoint("TOPLEFT", contentTitle, "BOTTOMLEFT", -2, -8)
    contentScroll:SetPoint("BOTTOMRIGHT", contentInset, "BOTTOMRIGHT", -26, 12)
    self.helpContentScroll = contentScroll

    local contentChild = CreateFrame("Frame", nil, contentScroll)
    contentChild:SetPoint("TOPLEFT", contentScroll, "TOPLEFT", 0, 0)
    contentChild:SetPoint("TOPRIGHT", contentScroll, "TOPRIGHT", -20, 0)
    contentChild:SetHeight(200)
    contentScroll:SetScrollChild(contentChild)
    self.helpContentChild = contentChild

    local contentText = contentChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    contentText:SetPoint("TOPLEFT", contentChild, "TOPLEFT", 8, -4)
    contentText:SetPoint("TOPRIGHT", contentChild, "TOPRIGHT", -8, -4)
    contentText:SetJustifyH("LEFT")
    contentText:SetText("")
    self.helpContentText = contentText

    local function updateHelpContentWidth()
        local width = contentScroll:GetWidth() or 0
        if width > 0 then
            local childWidth = math.max(1, width - 24)
            contentChild:SetWidth(childWidth)
            contentText:SetWidth(childWidth - 16)
            if self.helpContentText then
                local height = (self.helpContentText:GetStringHeight() or 0) + 12
                self.helpContentChild:SetHeight(height)
            end
        end
    end

    contentInset:SetScript("OnSizeChanged", updateHelpContentWidth)
    contentScroll:SetScript("OnShow", updateHelpContentWidth)
    navScroll:SetScript("OnSizeChanged", function()
        self:RefreshHelpNav()
    end)

    self.helpNodes = {
        {
            id = "home",
            title = "Home / About",
            type = "page",
            content = "GOALS is a DKP-style boss and loot tracker for Wrath 3.3.5a.\n\n" ..
                "What it does:\n" ..
                "- Track boss kills, attendance, and point changes.\n" ..
                "- Record loot assignments and history.\n" ..
                "- Maintain a wishlist with gems, enchants, and required tokens.\n" ..
                "- Notify you when wishlist items are found.\n\n" ..
                "Who it is for:\n" ..
                "- Raid leaders, loot masters, and guild admins.\n" ..
                "- Players who want a clean, searchable wishlist.\n\n" ..
                "Project:\n" ..
                "- GitHub: https://github.com/ErebusAres/GOALS/\n" ..
                "- Author: ErebusAres\n" ..
                "- Discord: erebusares\n" ..
                "- Bug reports: open an issue on GitHub with steps and errors.\n\n" ..
                "Tip: After updates, use /reload to refresh UI state.",
        },
                {
                    id = "getting_started",
                    title = "Getting Started",
                    type = "page",
                    content = "Quick start:\n" ..
                        "1) Open GOALS and choose the tab you need.\n" ..
                        "2) Use Overview to see the roster and points.\n" ..
                        "3) Use Loot to assign items and adjust points.\n" ..
                        "4) Use Wishlist to track personal upgrades.\n\n" ..
                        "Commands and shortcuts:\n" ..
                        "- /goals opens the main UI.\n" ..
                        "- /dkp opens the main UI.\n" ..
                        "- /goalsui opens the main UI.\n" ..
                        "- /goals mini toggles the Mini Viewer.\n" ..
                        "- /goals dev on|off|toggle|status controls dev mode.\n" ..
                        "- Alt-click the minimap icon to toggle the Mini Viewer.\n\n" ..
                        "Keybindings:\n" ..
                        "- Toggle GOALS UI (set in Key Bindings).\n" ..
                        "- Toggle Mini Viewer (set in Key Bindings).\n\n" ..
                        "Example: first raid flow:\n" ..
                        "- Track boss kills to award points.\n" ..
                        "- Assign loot as it drops.\n" ..
                        "- Check History to verify assignments.\n\n" ..
                        "Tip: Use Search to cache items by name, ID, or in-game link.",
                },
        {
            id = "overview_folder",
            title = "Overview",
            type = "folder",
            children = {
                {
                    id = "overview_basics",
                    title = "Overview Basics",
                    type = "page",
                    content = "Overview shows roster, attendance, and points at a glance.\n\n" ..
                        "Use filters to focus on present players, and watch point changes after boss kills or loot.\n\n" ..
                        "Tip: Keep Overview open during raids to monitor point swings.",
                },
                {
                    id = "overview_mini_viewer",
                    title = "Mini Viewer",
                    type = "page",
                    content = "Mini Viewer is a compact tracker that stays on screen during raids.\n\n" ..
                        "Use it to watch key info without keeping the full UI open.\n\n" ..
                        "Commands and shortcuts:\n" ..
                        "- Alt-click the minimap icon to toggle it.\n\n" ..
                        "Keybinding:\n" ..
                        "- Toggle Mini Viewer (set in Key Bindings).\n\n" ..
                        "Tip: Toggle it in Settings and reposition it if needed.",
                },
                {
                    id = "overview_roster",
                    title = "Roster and Filters",
                    type = "page",
                    content = "Use roster filters to focus on roles or specific players.\n\n" ..
                        "The Present Only toggle helps hide absentees.\n\n" ..
                        "Example: switch to Present Only before loot assignment.",
                },
                {
                    id = "overview_points",
                    title = "Point Tracking",
                    type = "page",
                    content = "Point tracking updates from boss kills and loot assignments.\n\n" ..
                        "Admins can disable tracking for testing or special events.\n\n" ..
                        "Note: When disabled, kills and minimum rank items do not change points.",
                },
                {
                    id = "overview_present",
                    title = "Present Only",
                    type = "page",
                    content = "Present Only limits the roster to players currently in raid.\n\n" ..
                        "Useful when distributing loot mid-raid.\n\n" ..
                        "Tip: Toggle off to review absent players after the raid.",
                },
            },
        },
        {
            id = "loot_folder",
            title = "Loot",
            type = "folder",
            children = {
                {
                    id = "loot_assign",
                    title = "Assigning Loot",
                    type = "page",
                    content = "Use the Loot tab to assign items to players.\n\n" ..
                        "You can set amounts, reasons, and see who is eligible.\n\n" ..
                        "Example:\n" ..
                        "- Select an item.\n" ..
                        "- Choose the recipient(s).\n" ..
                        "- Confirm to log the entry.",
                },
                {
                    id = "loot_found",
                    title = "Found Loot",
                    type = "page",
                    content = "Found Loot lists nearby drops and lets you assign quickly.\n\n" ..
                        "Right-click entries to move them into assignments.\n\n" ..
                        "Tip: This is fastest for farm content or badge runs.",
                },
                {
                    id = "loot_multi",
                    title = "Multi-Recipient Loot",
                    type = "page",
                    content = "When more than two players receive the same item, the history entry shows a grouped line.\n\n" ..
                        "This keeps logs readable for badge-style drops.\n\n" ..
                        "Example: \"Gave 5 Players: Badge of Justice\".",
                },
                {
                    id = "loot_manual",
                    title = "Manual Adjustments",
                    type = "page",
                    content = "Use Manual Adjust for point changes outside normal loot flow.\n\n" ..
                        "Always record a reason for auditing.\n\n" ..
                        "Tip: Use consistent reasons to keep logs clean.",
                },
            },
        },
        {
            id = "history_folder",
            title = "History",
            type = "folder",
            children = {
                {
                    id = "history_boss",
                    title = "Boss History",
                    type = "page",
                    content = "Boss history shows kills and point awards.\n\n" ..
                        "Use it to review attendance and raid pace.\n\n" ..
                        "Tip: Confirm kill counts after raid end.",
                },
                {
                    id = "history_loot",
                    title = "Loot History",
                    type = "page",
                    content = "Loot history records item awards and point changes.\n\n" ..
                        "Entries show time, recipient(s), and item links.\n\n" ..
                        "Tip: Use it to resolve loot disputes quickly.",
                },
                {
                    id = "history_filters",
                    title = "Filtering History",
                    type = "page",
                    content = "Use filters to narrow results by player or item.\n\n" ..
                        "This helps resolve disputes quickly.\n\n" ..
                        "Example: filter to a player to audit their loot.",
                },
            },
        },
        {
            id = "wishlist_folder",
            title = "Wishlist",
            type = "folder",
            children = {
                {
                    id = "wishlist_basics",
                    title = "Wishlist Basics",
                    type = "page",
                    content = "Wishlist stores gear goals by slot.\n\n" ..
                        "Select a slot and add items from Search to track upgrades.\n\n" ..
                        "Tip: The icon border highlights the selected slot.",
                },
                {
                    id = "wishlist_search",
                    title = "Search",
                    type = "page",
                    content = "Search supports item names, IDs, or in-game item links.\n\n" ..
                        "Paste a link to cache it instantly.\n\n" ..
                        "Examples:\n" ..
                        "- Name: \"Cataclysm Headguard\"\n" ..
                        "- ID: 30166\n" ..
                        "- Link: |cff...|Hitem:30166:...|h[Cataclysm Headguard]|h|r",
                },
                {
                    id = "wishlist_slots",
                    title = "Slots and Claims",
                    type = "page",
                    content = "Click a slot to select it. Right-click clears the slot.\n\n" ..
                        "Alt-click marks found/unfound manually.\n\n" ..
                        "Tip: The green checkmark means the item is claimed.",
                },
                {
                    id = "wishlist_gems",
                    title = "Gems and Enchants",
                    type = "page",
                    content = "Use the socket picker to add gems or enchants for a slot.\n\n" ..
                        "Hover icons to view tooltips and IDs.\n\n" ..
                        "Flow:\n" ..
                        "1) Select a slot.\n" ..
                        "2) Open the socket picker.\n" ..
                        "3) Search and Apply.",
                },
                {
                    id = "wishlist_tokens",
                    title = "Required Tokens",
                    type = "page",
                    content = "Required tokens list updates as wishlist items are added.\n\n" ..
                        "Claimed items are removed from the token list.\n\n" ..
                        "Tip: On custom servers, token rules may be adjusted.",
                },
                {
                    id = "wishlist_import",
                    title = "Import / Export",
                    type = "page",
                    content = "Import supports wishlist strings and Wowhead links.\n\n" ..
                        "Export copies your current list for sharing or backup.\n\n" ..
                        "Example: paste a Wowhead gear planner link to import.",
                },
                {
                    id = "wishlist_alerts",
                    title = "Alerts and Popups",
                    type = "page",
                    content = "Wishlist alerts can post to chat and show a popup.\n\n" ..
                        "Toggle sound and popup options in Actions.\n\n" ..
                        "Tip: Use local popup if chat spam is an issue.",
                },
            },
        },
        {
            id = "settings_folder",
            title = "Settings",
            type = "folder",
            children = {
                {
                    id = "settings_general",
                    title = "General Settings",
                    type = "page",
                    content = "Configure minimap, auto-minimize, and sync options here.\n\n" ..
                        "Table tools help manage saved data across sessions.\n\n" ..
                        "Tip: Keep auto-minimize enabled for raid combat.",
                },
                {
                    id = "settings_minimap",
                    title = "Minimap and UI",
                    type = "page",
                    content = "Toggle the minimap icon and configure auto-minimize.\n\n" ..
                        "Use this to keep the UI tidy during combat.\n\n" ..
                        "Tip: You can hide the minimap icon if it gets in the way.",
                },
                {
                    id = "settings_data",
                    title = "Data Management",
                    type = "page",
                    content = "Clear points, players, or history when needed.\n\n" ..
                        "Use these tools carefully before raids.\n\n" ..
                        "Warning: Clear actions are permanent.",
                },
                {
                    id = "settings_dbm",
                    title = "DBM Integration",
                    type = "page",
                    content = "If DBM is installed, you can enable wishlist loot integration.\n\n" ..
                        "Disable it if you prefer the local popup only.\n\n" ..
                        "Tip: DBM integration is auto-detected when available.",
                },
            },
        },
        {
            id = "update_folder",
            title = "Updates",
            type = "folder",
            children = {
                {
                    id = "update_check",
                    title = "Checking for Updates",
                    type = "page",
                    content = "The Update tab compares your version with the latest.\n\n" ..
                        "Use the download link shown to update manually.\n\n" ..
                        "Tip: The tab will glow if an update is available.",
                },
                {
                    id = "update_versions",
                    title = "Versioning",
                    type = "page",
                    content = "Versions follow the addon major/minor scheme.\n\n" ..
                        "The title bar and minimap tooltip show the current version.\n\n" ..
                        "Example: v2.11 means major 2, minor 11.",
                },
            },
        },
        {
            id = "faq",
            title = "FAQ / Troubleshooting",
            type = "page",
            content = "Common fixes:\n" ..
                "- Search results missing: press Refresh in Wishlist.\n" ..
                "- Enchants missing: clear search and reselect the slot.\n" ..
                "- Popups missing: check Actions settings.\n" ..
                "- Sync issues: verify local-only is disabled.\n\n" ..
                "If issues persist:\n" ..
                "- /reload and retry.\n" ..
                "- Report on GitHub with steps and errors.",
        },
    }

    self.helpNodeById = {}
    for _, node in ipairs(self.helpNodes) do
        self.helpNodeById[node.id] = node
        if node.children then
            for _, child in ipairs(node.children) do
                self.helpNodeById[child.id] = child
            end
        end
    end

    self.helpNavState = self.helpNavState or {
        overview_folder = true,
        loot_folder = true,
        history_folder = true,
        wishlist_folder = true,
        settings_folder = true,
        update_folder = true,
    }

    navScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, rowHeight, function()
            UI:RefreshHelpNav()
        end)
    end)

    self.helpSelectedId = self.helpSelectedId or "home"
    self:SelectHelpPage(self.helpSelectedId)
end

function UI:BuildHelpNavList()
    local list = {}
    local function addNode(node, depth)
        if not node then
            return
        end
        table.insert(list, {
            id = node.id,
            title = node.title,
            type = node.type,
            depth = depth or 0,
            node = node,
        })
        if node.type == "folder" then
            local expanded = self.helpNavState and self.helpNavState[node.id]
            if expanded then
                for _, child in ipairs(node.children or {}) do
                    addNode(child, (depth or 0) + 1)
                end
            end
        end
    end
    for _, node in ipairs(self.helpNodes or {}) do
        addNode(node, 0)
    end
    return list
end

function UI:RefreshHelpNav()
    if not self.helpNavScroll or not self.helpNavRows then
        return
    end
    local rows = self.helpNavRows
    local rowHeight = 18
    local navList = self:BuildHelpNavList()
    local offset = FauxScrollFrame_GetOffset(self.helpNavScroll) or 0
    FauxScrollFrame_Update(self.helpNavScroll, #navList, #rows, rowHeight)
    setScrollBarAlwaysVisible(self.helpNavScroll, #navList * rowHeight)

    for i = 1, #rows do
        local row = rows[i]
        local entry = navList[offset + i]
        if entry then
            row:Show()
            row.nodeId = entry.id
            row.nodeType = entry.type
            row.nodeDepth = entry.depth or 0
            local indent = 6 + (entry.depth or 0) * 12

            if row.expandBtn then
                if entry.type == "folder" then
                    row.expandBtn:Show()
                    row.expandBtn:ClearAllPoints()
                    row.expandBtn:SetPoint("LEFT", row, "LEFT", indent, 0)
                    local expanded = self.helpNavState and self.helpNavState[entry.id]
                    row.expandBtn:SetNormalTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                    row.expandBtn:SetPushedTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Down" or "Interface\\Buttons\\UI-PlusButton-Down")
                    row.expandBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                else
                    row.expandBtn:Hide()
                end
            end

            if row.text then
                row.text:ClearAllPoints()
                local textIndent = indent + (entry.type == "folder" and 16 or 4)
                row.text:SetPoint("LEFT", row, "LEFT", textIndent, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.text:SetText(entry.title or "")
            end

            if row.selected then
                if entry.id == self.helpSelectedId and entry.type ~= "folder" then
                    row.selected:Show()
                else
                    row.selected:Hide()
                end
            end
        else
            row:Hide()
            row.nodeId = nil
            row.nodeType = nil
            row.nodeDepth = nil
            if row.selected then
                row.selected:Hide()
            end
        end
    end
end

function UI:SelectHelpPage(pageId)
    if not pageId then
        return
    end
    local node = self.helpNodeById and self.helpNodeById[pageId] or nil
    if not node then
        return
    end
    if node.type == "folder" then
        self.helpNavState = self.helpNavState or {}
        self.helpNavState[node.id] = not self.helpNavState[node.id]
        self:RefreshHelpNav()
        return
    end
    self.helpSelectedId = node.id
    if self.helpContentTitle then
        self.helpContentTitle:SetText(node.title or "Help")
    end
    if self.helpContentText then
        self.helpContentText:SetText(node.content or "")
    end
    if self.helpContentText and self.helpContentChild then
        local height = (self.helpContentText:GetStringHeight() or 0) + 12
        self.helpContentChild:SetHeight(height)
    end
    if self.helpContentScroll then
        self.helpContentScroll:SetVerticalScroll(0)
    end
    self:RefreshHelpNav()
end

function UI:CreateUpdateTab(page)
    local inset = CreateFrame("Frame", "GoalsUpdateInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, -2, 6)
    end

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

    local urlBox = CreateFrame("EditBox", "GoalsUpdateUrlBox", inset, "InputBoxTemplate")
    urlBox:SetPoint("TOPLEFT", urlLabel, "BOTTOMLEFT", -4, -6)
    urlBox:SetSize(520, OPTIONS_EDITBOX_HEIGHT)
    urlBox:SetAutoFocus(false)
    urlBox:SetFontObject("ChatFontNormal")
    urlBox:SetTextInsets(6, 6, 3, 3)
    urlBox:SetScript("OnEditFocusGained", function(selfBox)
        selfBox:HighlightText()
    end)
    urlBox:SetScript("OnMouseUp", function(selfBox)
        if not selfBox:HasFocus() then
            selfBox:SetFocus()
        end
        selfBox:HighlightText()
    end)
    urlBox:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    urlBox:SetScript("OnTextChanged", function(selfBox, userInput)
        if userInput then
            local locked = selfBox._lockedText or ""
            if selfBox:GetText() ~= locked then
                selfBox:SetText(locked)
                selfBox:HighlightText()
            end
        end
    end)
    urlBox:SetScript("OnShow", function(selfBox)
        if selfBox:GetText() ~= "" then
            selfBox:HighlightText()
        end
    end)
    self.updateUrlText = urlBox

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
    copyHint:SetPoint("TOPLEFT", urlBox, "BOTTOMLEFT", 4, -6)

    local stepsLabel = createLabel(inset, "Quick steps", "GameFontNormal")
    stepsLabel:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", 0, -12)

    local step1 = createLabel(inset, L.UPDATE_STEP1, "GameFontHighlight")
    step1:SetPoint("TOPLEFT", stepsLabel, "BOTTOMLEFT", 0, -6)
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
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, -2, 6)
    end

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
            Goals.Comm:BroadcastFullSync("MANUAL")
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

    local combatTitle = createLabel(inset, "Combat Testing", "GameFontNormal")
    combatTitle:SetPoint("TOPLEFT", testDbmBtn, "TOPRIGHT", 30, 0)

    local combatAmountLabel = createLabel(inset, "Amount", "GameFontHighlightSmall")
    combatAmountLabel:SetPoint("TOPLEFT", combatTitle, "BOTTOMLEFT", 0, -6)

    local combatAmountBox = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    combatAmountBox:SetSize(60, 18)
    combatAmountBox:SetPoint("LEFT", combatAmountLabel, "RIGHT", 6, 0)
    combatAmountBox:SetNumeric(true)
    combatAmountBox:SetMaxLetters(6)
    combatAmountBox:SetAutoFocus(false)
    combatAmountBox:SetText("1234")
    bindEscapeClear(combatAmountBox)
    self.devCombatAmountBox = combatAmountBox

    local combatDamageBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatDamageBtn:SetSize(170, 20)
    combatDamageBtn:SetText("Self Damage")
    combatDamageBtn:SetPoint("TOPLEFT", combatAmountLabel, "BOTTOMLEFT", 0, -6)
    combatDamageBtn:SetScript("OnClick", function()
        local amount = tonumber(combatAmountBox:GetText()) or 1000
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfDamage then
            Goals.Dev:SimulateSelfDamage(amount)
        end
    end)

    local combatHealBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatHealBtn:SetSize(170, 20)
    combatHealBtn:SetText("Self Heal")
    combatHealBtn:SetPoint("TOPLEFT", combatDamageBtn, "BOTTOMLEFT", 0, -6)
    combatHealBtn:SetScript("OnClick", function()
        local amount = tonumber(combatAmountBox:GetText()) or 1000
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfHeal then
            Goals.Dev:SimulateSelfHeal(amount)
        end
    end)

    local combatDeathBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatDeathBtn:SetSize(170, 20)
    combatDeathBtn:SetText("Self Death")
    combatDeathBtn:SetPoint("TOPLEFT", combatHealBtn, "BOTTOMLEFT", 0, -6)
    combatDeathBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfDeath then
            Goals.Dev:SimulateSelfDeath()
        end
    end)

    local combatResBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatResBtn:SetSize(170, 20)
    combatResBtn:SetText("Self Res")
    combatResBtn:SetPoint("TOPLEFT", combatDeathBtn, "BOTTOMLEFT", 0, -6)
    combatResBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfResurrect then
            Goals.Dev:SimulateSelfResurrect()
        end
    end)

    local combatStartBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatStartBtn:SetSize(170, 20)
    combatStartBtn:SetText("Encounter Start")
    combatStartBtn:SetPoint("TOPLEFT", combatResBtn, "BOTTOMLEFT", 0, -10)
    combatStartBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateEncounterStart then
            Goals.Dev:SimulateEncounterStart()
        end
    end)

    local combatEndSuccessBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatEndSuccessBtn:SetSize(170, 20)
    combatEndSuccessBtn:SetText("Encounter End (Success)")
    combatEndSuccessBtn:SetPoint("TOPLEFT", combatStartBtn, "BOTTOMLEFT", 0, -6)
    combatEndSuccessBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateEncounterEnd then
            Goals.Dev:SimulateEncounterEnd(true)
        end
    end)

    local combatEndFailBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatEndFailBtn:SetSize(170, 20)
    combatEndFailBtn:SetText("Encounter End (Wipe)")
    combatEndFailBtn:SetPoint("TOPLEFT", combatEndSuccessBtn, "BOTTOMLEFT", 0, -6)
    combatEndFailBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateEncounterEnd then
            Goals.Dev:SimulateEncounterEnd(false)
        end
    end)

    local socketLinkBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    socketLinkBtn:SetSize(170, 20)
    socketLinkBtn:SetText("Socket Link (29991)")
    socketLinkBtn:SetPoint("TOPLEFT", testDbmBtn, "TOPRIGHT", 190, 0)
    socketLinkBtn:SetScript("OnClick", function()
        if Goals and Goals.BuildFullItemLinkWithSockets then
            local link = Goals:BuildFullItemLinkWithSockets(29991, nil, 0, { 24029, 24029, 24029 })
            if link and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(link)
                DEFAULT_CHAT_FRAME:AddMessage(link:gsub("|", "||"))
            end
        end
    end)

    local socketLinkBtn2 = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    socketLinkBtn2:SetSize(170, 20)
    socketLinkBtn2:SetText("Socket Link (30166)")
    socketLinkBtn2:SetPoint("TOPLEFT", socketLinkBtn, "BOTTOMLEFT", 0, -6)
    socketLinkBtn2:SetScript("OnClick", function()
        if Goals and Goals.BuildFullItemLinkWithSockets then
            local link = Goals:BuildFullItemLinkWithSockets(30166, nil, 35445, { 25901, 30547 })
            if link and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(link)
                DEFAULT_CHAT_FRAME:AddMessage(link:gsub("|", "||"))
            end
        end
    end)

    local enchantInfoBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    enchantInfoBtn:SetSize(170, 20)
    enchantInfoBtn:SetText("Print Enchant IDs")
    enchantInfoBtn:SetPoint("TOPLEFT", socketLinkBtn2, "BOTTOMLEFT", 0, -6)
    enchantInfoBtn:SetScript("OnClick", function()
        local entry = nil
        if Goals and Goals.UI and Goals.UI.selectedWishlistEnchantResult then
            entry = Goals.UI.selectedWishlistEnchantResult
        end
        local enchantId = entry and entry.id or nil
        if not enchantId and Goals and Goals.GetActiveWishlist and Goals.UI then
            local slotKey = Goals.UI.selectedWishlistSlot
            local list = Goals:GetActiveWishlist()
            local slotEntry = slotKey and list and list.items and list.items[slotKey] or nil
            enchantId = slotEntry and slotEntry.enchantId or nil
        end
        if not enchantId then
            if Goals and Goals.Print then
                Goals:Print("No enchant selected.")
            end
            return
        end
        local info = Goals.GetEnchantInfoById and Goals:GetEnchantInfoById(enchantId) or nil
        local spellId = info and info.spellId or nil
        local name = info and info.name or ("Enchant " .. tostring(enchantId))
        local match = spellId and tostring(spellId) == tostring(enchantId) or false
        local msg = string.format("Enchant ID: %s, Spell ID: %s, Match: %s, Name: %s", tostring(enchantId), tostring(spellId or "nil"), match and "yes" or "no", name)
        if Goals and Goals.Print then
            Goals:Print(msg)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end)

    local devBossCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    devBossCheck:SetPoint("TOPLEFT", simulateUpdateBtn, "BOTTOMLEFT", 0, -12)
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

    local updateDebug = createLabel(inset, "", "GameFontHighlightSmall")
    updateDebug:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 12, 10)
    updateDebug:SetWidth(520)
    updateDebug:SetJustifyH("LEFT")
    self.updateDebugText = updateDebug
end

function UI:CreateDebugTab(page)
    local inset = CreateFrame("Frame", "GoalsDebugInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, -2, 6)
    end

    local combatLabel = createLabel(inset, "Combat Tracker", "GameFontNormal")
    combatLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    local combatBar = applySectionHeader(combatLabel, inset, -44)
    applySectionCaption(combatBar, "Debug")

    local combatLast = createLabel(inset, "Last CLEU: --", "GameFontHighlightSmall")
    combatLast:SetPoint("TOPLEFT", combatLabel, "BOTTOMLEFT", 0, -4)
    combatLast:SetJustifyH("LEFT")
    self.combatDebugLast = combatLast

    local combatCount = createLabel(inset, "CLEU events: 0 | Log entries: 0", "GameFontHighlightSmall")
    combatCount:SetPoint("TOPLEFT", combatLast, "BOTTOMLEFT", 0, -2)
    combatCount:SetJustifyH("LEFT")
    self.combatDebugCount = combatCount

    local testDamageBtn = CreateFrame("Button", "GoalsDebugTestDamageButton", inset, "UIPanelButtonTemplate")
    testDamageBtn:SetSize(120, 20)
    testDamageBtn:SetText("Test Damage")
    testDamageBtn:SetPoint("TOPLEFT", combatCount, "BOTTOMLEFT", 0, -6)
    testDamageBtn:SetScript("OnClick", function()
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or "Player"
        if Goals and Goals.DamageTracker and Goals.DamageTracker.AddEntry then
            Goals.DamageTracker:AddEntry({
                ts = time(),
                player = playerName,
                amount = 5,
                spell = "Debug Hit",
                source = "Debug",
                kind = "DAMAGE",
            })
        end
        if UI and UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
    end)
    self.debugTestDamageButton = testDamageBtn

    local testHealBtn = CreateFrame("Button", "GoalsDebugTestHealButton", inset, "UIPanelButtonTemplate")
    testHealBtn:SetSize(120, 20)
    testHealBtn:SetText("Test Heal")
    testHealBtn:SetPoint("LEFT", testDamageBtn, "RIGHT", 6, 0)
    testHealBtn:SetScript("OnClick", function()
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or "Player"
        if Goals and Goals.DamageTracker and Goals.DamageTracker.AddEntry then
            Goals.DamageTracker:AddEntry({
                ts = time(),
                player = playerName,
                amount = 5,
                spell = "Debug Heal",
                source = "Debug",
                kind = "HEAL",
            })
        end
        if UI and UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
    end)
    self.debugTestHealButton = testHealBtn

    local cpuMonitorBtn = CreateFrame("Button", "GoalsDebugCpuMonitorButton", inset, "UIPanelButtonTemplate")
    cpuMonitorBtn:SetSize(120, 20)
    cpuMonitorBtn:SetText("CPU Monitor")
    cpuMonitorBtn:SetPoint("LEFT", testHealBtn, "RIGHT", 6, 0)
    cpuMonitorBtn:SetScript("OnClick", function()
        if UI and UI.ToggleCpuDebugPopout then
            UI:ToggleCpuDebugPopout()
        end
    end)
    self.debugCpuMonitorButton = cpuMonitorBtn

    local title = createLabel(inset, "Debug Log", "GameFontNormal")
    title:SetPoint("TOPLEFT", testDamageBtn, "BOTTOMLEFT", 0, -16)
    local debugBar = applySectionHeader(title, inset, -6)
    applySectionCaption(debugBar, "Logs")

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

    local logScroll = CreateFrame("ScrollFrame", "GoalsDebugCopyScroll", inset, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -2, -6)
    logScroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 12)
    self.debugCopyScroll = logScroll
    self.debugLogScroll = logScroll
    self.debugLogRows = nil

    local edit = CreateFrame("EditBox", nil, logScroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(logScroll:GetWidth())
    bindEscapeClear(edit)
    logScroll:SetScrollChild(edit)
    logScroll:SetScript("OnSizeChanged", function(selfScroll)
        if edit and edit.SetWidth then
            edit:SetWidth(selfScroll:GetWidth())
        end
    end)
    self.debugCopyBox = edit
end

function UI:GetCpuDebugInterval()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local value = settings and tonumber(settings.cpuDebugInterval) or CPU_DEBUG_DEFAULT_INTERVAL
    if not value then
        value = CPU_DEBUG_DEFAULT_INTERVAL
    end
    if value < CPU_DEBUG_MIN_INTERVAL then
        value = CPU_DEBUG_MIN_INTERVAL
    elseif value > CPU_DEBUG_MAX_INTERVAL then
        value = CPU_DEBUG_MAX_INTERVAL
    end
    if settings then
        settings.cpuDebugInterval = value
    end
    return value
end

function UI:IsCpuDebugAllowed()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    if not (Goals and Goals.Dev and Goals.Dev.enabled) then
        return false
    end
    return settings and settings.cpuDebugEnabled and true or false
end

function UI:IsCpuDebugTracingEnabled()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    if not self:IsCpuDebugAllowed() then
        return false
    end
    return settings and settings.cpuDebugTrace and true or false
end

function UI:GetCpuDebugSpikeThreshold()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local value = settings and tonumber(settings.cpuDebugSpikeThreshold) or CPU_DEBUG_DEFAULT_SPIKE_THRESHOLD
    if not value then
        value = CPU_DEBUG_DEFAULT_SPIKE_THRESHOLD
    end
    if value < CPU_DEBUG_MIN_SPIKE_THRESHOLD then
        value = CPU_DEBUG_MIN_SPIKE_THRESHOLD
    elseif value > CPU_DEBUG_MAX_SPIKE_THRESHOLD then
        value = CPU_DEBUG_MAX_SPIKE_THRESHOLD
    end
    if settings then
        settings.cpuDebugSpikeThreshold = value
    end
    return value
end

function UI:RefreshCpuDebugLogView()
    if not self.cpuDebugLogBox then
        return
    end
    local lines = self.cpuDebugLines or {}
    self.cpuDebugLogBox:SetText(table.concat(lines, "\n"))
    self.cpuDebugLogBox:SetCursorPosition(string.len(self.cpuDebugLogBox:GetText() or ""))
    if self.cpuDebugLogScroll then
        self.cpuDebugLogScroll:SetVerticalScroll(self.cpuDebugLogScroll:GetVerticalScrollRange() or 0)
    end
end

function UI:AppendCpuDebugLine(text)
    if not text or text == "" then
        return
    end
    self.cpuDebugLines = self.cpuDebugLines or {}
    table.insert(self.cpuDebugLines, text)
    while #self.cpuDebugLines > CPU_DEBUG_MAX_LINES do
        table.remove(self.cpuDebugLines, 1)
    end
    self:RefreshCpuDebugLogView()
end

function UI:IsCpuDebugProfilingEnabled()
    local profile = GetCVar and tonumber(GetCVar("scriptProfile")) or 0
    return profile == 1
end

function UI:UpdateCpuDebugStatusText()
    if not self.cpuDebugStatusLabel then
        return
    end
    local running = self.cpuDebugRunning and true or false
    local state = running and "|cff66ff66RUNNING|r" or "|cffff6666STOPPED|r"
    local interval = self:GetCpuDebugInterval()
    local profileText = self:IsCpuDebugProfilingEnabled() and "ON" or "OFF"
    local traceText = self:IsCpuDebugTracingEnabled() and "ON" or "OFF"
    local spike = self:GetCpuDebugSpikeThreshold()
    local settings = Goals and Goals.db and Goals.db.settings or {}
    local enabledText = (settings and settings.cpuDebugEnabled) and "ON" or "OFF"
    local devText = (Goals and Goals.Dev and Goals.Dev.enabled) and "ON" or "OFF"
    self.cpuDebugStatusLabel:SetText(string.format("Status: %s  |  Dev: %s  |  CPU dbg: %s  |  Interval: %.1fs  |  scriptProfile: %s  |  trace: %s >= %.1fms", state, devText, enabledText, interval, profileText, traceText, spike))
end

function UI:UpdateCpuDebugControls()
    self:UpdateCpuDebugStatusText()
    local running = self.cpuDebugRunning and true or false
    if self.cpuDebugStartButton then
        self.cpuDebugStartButton:SetEnabled(not running)
    end
    if self.cpuDebugStopButton then
        self.cpuDebugStopButton:SetEnabled(running)
    end
end

function UI:RecordCpuSpikeDetail(tag, totalMs, detail)
    local total = tonumber(totalMs) or 0
    if total <= 0 then
        return
    end
    if not self:IsCpuDebugTracingEnabled() then
        return
    end
    local threshold = self:GetCpuDebugSpikeThreshold()
    if total < threshold then
        return
    end
    local stamp = date and date("%H:%M:%S") or tostring(time())
    local label = tostring(tag or "unknown")
    local extra = detail and tostring(detail) or ""
    if extra ~= "" then
        self:AppendCpuDebugLine(string.format("[SPIKE %s] %s %.2fms | %s", stamp, label, total, extra))
    else
        self:AppendCpuDebugLine(string.format("[SPIKE %s] %s %.2fms", stamp, label, total))
    end
end

function UI:SampleCpuDebugNow(manual)
    if not self:IsCpuDebugAllowed() then
        return
    end
    if not UpdateAddOnCPUUsage or not GetAddOnCPUUsage then
        self:AppendCpuDebugLine("[CPU] CPU profiling API unavailable in this client.")
        return
    end
    UpdateAddOnCPUUsage()
    local goalsCpu = tonumber(GetAddOnCPUUsage(addonName)) or tonumber(GetAddOnCPUUsage("Goals")) or 0
    local prev = tonumber(self.cpuDebugPrevGoalsCpu)
    local delta = prev and (goalsCpu - prev) or 0
    self.cpuDebugPrevGoalsCpu = goalsCpu

    local topName = addonName
    local topCpu = goalsCpu
    if GetNumAddOns and GetAddOnInfo then
        for i = 1, GetNumAddOns() do
            local name = GetAddOnInfo(i)
            local usage = tonumber(GetAddOnCPUUsage(i)) or 0
            if usage > topCpu then
                topCpu = usage
                topName = name or topName
            end
        end
    end

    local stamp = date and date("%H:%M:%S") or tostring(time())
    local flag = manual and " [manual]" or ""
    self:AppendCpuDebugLine(string.format("[%s]%s Goals %.2fms (%+.2f) | Top %s %.2fms", stamp, flag, goalsCpu, delta, tostring(topName or "?"), topCpu))
    self:UpdateCpuDebugStatusText()
end

function UI:StartCpuDebugSampler()
    if not (Goals and Goals.Dev and Goals.Dev.enabled) then
        self.cpuDebugRunning = false
        self:AppendCpuDebugLine("[CPU] Dev mode is OFF. CPU monitor sampling is disabled.")
        self:UpdateCpuDebugControls()
        return
    end
    if Goals and Goals.db and Goals.db.settings then
        Goals.db.settings.cpuDebugEnabled = true
    end
    if not self:IsCpuDebugAllowed() then
        self.cpuDebugRunning = false
        self:UpdateCpuDebugControls()
        return
    end
    self.cpuDebugRunning = true
    self.cpuDebugElapsed = 0
    self:AppendCpuDebugLine(string.format("[CPU] sampler started (interval %.1fs)", self:GetCpuDebugInterval()))
    self:SampleCpuDebugNow(true)
    self:UpdateCpuDebugControls()
end

function UI:StopCpuDebugSampler()
    self.cpuDebugRunning = false
    self:AppendCpuDebugLine("[CPU] sampler stopped")
    self:UpdateCpuDebugControls()
end

function UI:ClearCpuDebugLog()
    self.cpuDebugLines = {}
    self.cpuDebugPrevGoalsCpu = nil
    self:RefreshCpuDebugLogView()
    self:AppendCpuDebugLine("[CPU] log cleared")
end

function UI:CreateCpuDebugPopout()
    if self.cpuDebugPopout then
        return
    end
    local frame = CreateFrame("Frame", "GoalsCpuDebugPopout", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(frame)
    frame:SetSize(460, 320)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(selfFrame)
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if not UI.cpuDebugRunning then
            return
        end
        UI.cpuDebugElapsed = (UI.cpuDebugElapsed or 0) + (elapsed or 0)
        local interval = UI:GetCpuDebugInterval()
        if UI.cpuDebugElapsed >= interval then
            UI.cpuDebugElapsed = 0
            UI:SampleCpuDebugNow(false)
        end
    end)

    if self.frame then
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 8, -28)
    else
        frame:SetPoint("CENTER")
    end

    if frame.TitleText then
        frame.TitleText:SetText("CPU Debug Monitor")
        frame.TitleText:Show()
    end
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local inset = CreateFrame("Frame", "GoalsCpuDebugInset", frame, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

    local status = createLabel(inset, "", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    status:SetJustifyH("LEFT")
    status:SetWidth(430)
    self.cpuDebugStatusLabel = status

    local intervalLabel = createLabel(inset, "Interval (sec)", "GameFontNormalSmall")
    intervalLabel:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
    styleOptionsControlLabel(intervalLabel)

    local intervalBox = CreateFrame("EditBox", "GoalsCpuDebugIntervalBox", inset, "InputBoxTemplate")
    intervalBox:SetPoint("LEFT", intervalLabel, "RIGHT", 8, 0)
    intervalBox:SetAutoFocus(false)
    styleOptionsEditBox(intervalBox, 56)
    intervalBox:SetText(string.format("%.1f", self:GetCpuDebugInterval()))
    intervalBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        local value = tonumber(selfBox:GetText())
        if not value then
            value = CPU_DEBUG_DEFAULT_INTERVAL
        end
        if value < CPU_DEBUG_MIN_INTERVAL then
            value = CPU_DEBUG_MIN_INTERVAL
        elseif value > CPU_DEBUG_MAX_INTERVAL then
            value = CPU_DEBUG_MAX_INTERVAL
        end
        if Goals and Goals.db and Goals.db.settings then
            Goals.db.settings.cpuDebugInterval = value
        end
        selfBox:SetText(string.format("%.1f", value))
        UI:UpdateCpuDebugStatusText()
    end)
    bindEscapeClear(intervalBox)
    self.cpuDebugIntervalBox = intervalBox

    local traceCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    traceCheck:SetPoint("LEFT", intervalBox, "RIGHT", 14, 0)
    setCheckText(traceCheck, "Trace spikes")
    traceCheck:SetChecked(self:IsCpuDebugTracingEnabled())
    traceCheck:SetScript("OnClick", function(selfBtn)
        if Goals and Goals.db and Goals.db.settings then
            Goals.db.settings.cpuDebugTrace = selfBtn:GetChecked() and true or false
        end
        UI:UpdateCpuDebugStatusText()
    end)
    self.cpuDebugTraceCheck = traceCheck

    local spikeLabel = createLabel(inset, "Spike ms", "GameFontNormalSmall")
    spikeLabel:SetPoint("LEFT", traceCheck, "RIGHT", 8, 0)
    styleOptionsControlLabel(spikeLabel)

    local spikeBox = CreateFrame("EditBox", "GoalsCpuDebugSpikeThresholdBox", inset, "InputBoxTemplate")
    spikeBox:SetPoint("LEFT", spikeLabel, "RIGHT", 6, 0)
    spikeBox:SetAutoFocus(false)
    styleOptionsEditBox(spikeBox, 48)
    spikeBox:SetText(string.format("%.1f", self:GetCpuDebugSpikeThreshold()))
    spikeBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        local value = tonumber(selfBox:GetText())
        if not value then
            value = CPU_DEBUG_DEFAULT_SPIKE_THRESHOLD
        end
        if value < CPU_DEBUG_MIN_SPIKE_THRESHOLD then
            value = CPU_DEBUG_MIN_SPIKE_THRESHOLD
        elseif value > CPU_DEBUG_MAX_SPIKE_THRESHOLD then
            value = CPU_DEBUG_MAX_SPIKE_THRESHOLD
        end
        if Goals and Goals.db and Goals.db.settings then
            Goals.db.settings.cpuDebugSpikeThreshold = value
        end
        selfBox:SetText(string.format("%.1f", value))
        UI:UpdateCpuDebugStatusText()
    end)
    bindEscapeClear(spikeBox)
    self.cpuDebugSpikeThresholdBox = spikeBox

    local startBtn = createOptionsButton(inset)
    styleOptionsButton(startBtn, 70)
    startBtn:SetPoint("TOPLEFT", intervalLabel, "BOTTOMLEFT", 0, -8)
    startBtn:SetText("Start")
    startBtn:SetScript("OnClick", function()
        UI:StartCpuDebugSampler()
    end)
    self.cpuDebugStartButton = startBtn

    local stopBtn = createOptionsButton(inset)
    styleOptionsButton(stopBtn, 70)
    stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 6, 0)
    stopBtn:SetText("Stop")
    stopBtn:SetScript("OnClick", function()
        UI:StopCpuDebugSampler()
    end)
    self.cpuDebugStopButton = stopBtn

    local sampleBtn = createOptionsButton(inset)
    styleOptionsButton(sampleBtn, 88)
    sampleBtn:SetPoint("LEFT", stopBtn, "RIGHT", 6, 0)
    sampleBtn:SetText("Sample Now")
    sampleBtn:SetScript("OnClick", function()
        UI:SampleCpuDebugNow(true)
    end)

    local clearBtn = createOptionsButton(inset)
    styleOptionsButton(clearBtn, 70)
    clearBtn:SetPoint("LEFT", sampleBtn, "RIGHT", 6, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        UI:ClearCpuDebugLog()
    end)

    local logScroll = CreateFrame("ScrollFrame", "GoalsCpuDebugLogScroll", inset, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", startBtn, "BOTTOMLEFT", 0, -8)
    logScroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 10)
    self.cpuDebugLogScroll = logScroll

    local logBox = CreateFrame("EditBox", nil, logScroll)
    logBox:SetMultiLine(true)
    logBox:SetAutoFocus(false)
    logBox:SetFontObject("ChatFontNormal")
    logBox:SetWidth(logScroll:GetWidth())
    logScroll:SetScrollChild(logBox)
    logScroll:SetScript("OnSizeChanged", function(selfScroll)
        if logBox and logBox.SetWidth then
            logBox:SetWidth(selfScroll:GetWidth())
        end
    end)
    bindEscapeClear(logBox)
    self.cpuDebugLogBox = logBox

    self.cpuDebugPopout = frame
    self.cpuDebugLines = self.cpuDebugLines or {}
    if #self.cpuDebugLines == 0 then
        self:AppendCpuDebugLine("[CPU] Monitor ready. Use Start to begin periodic sampling.")
        if not self:IsCpuDebugProfilingEnabled() then
            self:AppendCpuDebugLine("[CPU] scriptProfile is OFF. Enable via /console scriptProfile 1 then /reload.")
        end
    else
        self:RefreshCpuDebugLogView()
    end
    self:UpdateCpuDebugControls()
end

function UI:ToggleCpuDebugPopout()
    if not self.cpuDebugPopout then
        self:CreateCpuDebugPopout()
    end
    if not self.cpuDebugPopout then
        return
    end
    if self.cpuDebugPopout:IsShown() then
        self.cpuDebugPopout:Hide()
    else
        self.cpuDebugPopout:Show()
        if self.cpuDebugIntervalBox then
            self.cpuDebugIntervalBox:SetText(string.format("%.1f", self:GetCpuDebugInterval()))
        end
        if self.cpuDebugSpikeThresholdBox then
            self.cpuDebugSpikeThresholdBox:SetText(string.format("%.1f", self:GetCpuDebugSpikeThreshold()))
        end
        if self.cpuDebugTraceCheck then
            self.cpuDebugTraceCheck:SetChecked(self:IsCpuDebugTracingEnabled())
        end
        self:UpdateCpuDebugControls()
        self:RefreshCpuDebugLogView()
    end
end

function UI:UpdateRosterList()
    if not self.rosterScroll or not self.rosterRows then
        return
    end
    local data = self:GetSortedPlayers()
    self.rosterData = data
    local offset = FauxScrollFrame_GetOffset(self.rosterScroll) or 0
    FauxScrollFrame_Update(self.rosterScroll, #data, ROSTER_ROWS, ROW_HEIGHT)
    local contentHeight = #data * ROW_HEIGHT
    self.rosterScroll._contentHeight = contentHeight
    setScrollBarAlwaysVisible(self.rosterScroll, contentHeight)
    local hasAccess = hasModifyAccess()
    for i = 1, ROSTER_ROWS do
        local row = self.rosterRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            row.playerName = entry.name
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(Goals:GetClassColor(entry.class))
            if not row.pointsText and row.cols and row.cols.points then
                row.pointsText = row.cols.points
            end
            if row.pointsText then
                row.pointsText:SetText(entry.points)
            end
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
            else
                row.add:Hide()
                row.sub:Hide()
                row.reset:Hide()
                row.undo:Hide()
                if row.remove then
                    row.remove:Hide()
                end
            end
            if Goals:GetUndoPoints(entry.name) == nil then
                row.undo:Disable()
            end
        else
            row:Hide()
            row.playerName = nil
        end
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    if self.presentCheck then
        self.presentCheck:SetChecked(overviewSettings.showPresentOnly and true or false)
    end
    if self.disablePointGainCheck then
        self.disablePointGainCheck:SetChecked(overviewSettings.disablePointGain and true or false)
        local canToggle = hasPointGainAccess()
        setShown(self.disablePointGainCheck, canToggle)
        if self.disablePointGainStatus then
            if canToggle then
                self.disablePointGainStatus:Hide()
            else
                local enabled = not overviewSettings.disablePointGain
                if enabled then
                    self.disablePointGainStatus:SetText("Point tracking: enabled")
                    self.disablePointGainStatus:SetTextColor(0.2, 1, 0.2)
                else
                    self.disablePointGainStatus:SetText("Point tracking: disabled")
                    self.disablePointGainStatus:SetTextColor(1, 0.25, 0.25)
                end
                self.disablePointGainStatus:Show()
            end
        end
    end
end

function UI:UpdateDebugLogList()
    local data = (Goals and Goals.GetDebugLog and Goals:GetDebugLog()) or {}
    if self.debugCopyBox and Goals and Goals.GetDebugLogText then
        self.debugCopyBox:SetText(Goals:GetDebugLogText() or "")
    end
    if not self.debugLogScroll or not self.debugLogRows then
        return
    end
    local offset = FauxScrollFrame_GetOffset(self.debugLogScroll) or 0
    FauxScrollFrame_Update(self.debugLogScroll, #data, DEBUG_ROWS, DEBUG_ROW_HEIGHT)
    for i = 1, DEBUG_ROWS do
        local row = self.debugLogRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            local ts = entry.ts and formatTime(entry.ts) or ""
            row.text:SetText(string.format("%s %s", ts, entry.msg or ""))
        else
            row:Hide()
            row.text:SetText("")
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

function UI:UpdateAutoSyncLabel()
    if not self.autoSyncLabel then
        return
    end
    local isMaster = (Goals and Goals.IsSyncMaster and Goals:IsSyncMaster()) or (Goals and Goals.IsMasterLooter and Goals:IsMasterLooter())
    if not isMaster then
        local last = Goals and Goals.lastSyncReceivedAt or nil
        if last then
            self.autoSyncLabel:SetText("Last sync: " .. date("%H:%M:%S", last))
        else
            self.autoSyncLabel:SetText("Last sync: --:--:--")
        end
        return
    end
    local remaining = Goals and Goals.GetAutoSyncRemaining and Goals:GetAutoSyncRemaining() or nil
    if not remaining then
        self.autoSyncLabel:SetText("Auto sync: --")
        return
    end
    local seconds = math.floor(remaining + 0.5)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    self.autoSyncLabel:SetText(string.format("Auto sync: %d:%02d", mins, secs))
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
    self:UpdateMinimapPosition(true)
end

function UI:UpdateMinimapPosition(force)
    if not self.minimapButton then
        return
    end
    local angle = Goals.db.settings.minimap.angle or 220
    if not force and self.minimapLastAngle == angle then
        return
    end
    local radius = (Minimap:GetWidth() / 2) + 8
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    self.minimapLastAngle = angle
end

function UI:UpdateMinimapButton()
    if not self.minimapButton or not Goals.db or not Goals.db.settings then
        return
    end
    if Goals.db.settings.minimap.hide then
        if self.minimapButton:IsShown() then
            self.minimapButton:Hide()
        end
        return
    end
    if not self.minimapButton:IsShown() then
        self.minimapButton:Show()
    end
    self:UpdateMinimapPosition()
end

function UI:UpdateMiniFloatingButtonPosition()
    if not self.miniFloatingButton then
        return
    end
    self:UpdateMiniFloatingPosition()
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
        local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
        local entry = players[name]
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

function UI:UpdateFloatingPosition()
    if not self.floatingButton or not Goals.db or not Goals.db.settings then
        return
    end
    local pos = Goals.db.settings.floatingButton or { x = 0, y = 0 }
    self.floatingButton:ClearAllPoints()
    self.floatingButton:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end
