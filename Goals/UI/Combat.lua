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
function UI:GetDamageTrackerDropdownList()
    return {
        COMBAT_SHOW_ALL,
        COMBAT_SHOW_BOSS,
        COMBAT_SHOW_TRASH,
    }
end

function UI:GetCombatDisplayStyle()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local mode = settings and settings.combatWhtmDisplayStyle or COMBAT_DISPLAY_TABLE
    if mode ~= COMBAT_DISPLAY_CHAT then
        mode = COMBAT_DISPLAY_TABLE
    end
    return mode
end

function UI:GetCombatTheme()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local theme = settings and settings.combatWhtmTheme or COMBAT_THEME_NEUTRAL
    if theme ~= COMBAT_THEME_ALLIANCE and theme ~= COMBAT_THEME_HORDE and theme ~= COMBAT_THEME_CLASS then
        theme = COMBAT_THEME_NEUTRAL
    end
    return theme
end

function UI:GetCombatThemePalette()
    local theme = self:GetCombatTheme()
    local accent = { 0.92, 0.80, 0.50 }
    local headerBg = { 0.00, 0.00, 0.00, 0.45 }
    local hover = { 1.00, 1.00, 1.00, 0.12 }
    local selected = { 1.00, 0.82, 0.25, 0.16 }

    if theme == COMBAT_THEME_ALLIANCE then
        accent = { 0.36, 0.62, 1.00 }
        headerBg = { 0.06, 0.13, 0.25, 0.68 }
        hover = { 0.36, 0.62, 1.00, 0.14 }
        selected = { 0.36, 0.62, 1.00, 0.24 }
    elseif theme == COMBAT_THEME_HORDE then
        accent = { 1.00, 0.34, 0.28 }
        headerBg = { 0.24, 0.07, 0.05, 0.70 }
        hover = { 1.00, 0.34, 0.28, 0.14 }
        selected = { 1.00, 0.34, 0.28, 0.24 }
    elseif theme == COMBAT_THEME_CLASS then
        local classFile = UnitClass and select(2, UnitClass("player")) or nil
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local c = RAID_CLASS_COLORS[classFile]
            accent = { c.r, c.g, c.b }
        else
            accent = { 0.75, 0.75, 0.75 }
        end
        headerBg = { accent[1] * 0.22, accent[2] * 0.22, accent[3] * 0.22, 0.68 }
        hover = { accent[1], accent[2], accent[3], 0.14 }
        selected = { accent[1], accent[2], accent[3], 0.24 }
    end

    return {
        accent = accent,
        headerBg = headerBg,
        hover = hover,
        selected = selected,
    }
end

function UI:ApplyCombatTheme()
    local palette = self:GetCombatThemePalette()
    local accent = palette.accent
    if self.damageTableWidget then
        if self.damageTableWidget.headerBg then
            self.damageTableWidget.headerBg:SetTexture(palette.headerBg[1], palette.headerBg[2], palette.headerBg[3], palette.headerBg[4])
        end
        for _, col in ipairs(self.damageTableWidget.columns or {}) do
            if col.header and col.header.SetTextColor then
                col.header:SetTextColor(accent[1], accent[2], accent[3], 1)
            end
        end
    end
    for _, row in ipairs(self.damageTrackerRows or {}) do
        if row.hoverTint then
            row.hoverTint:SetTexture(palette.hover[1], palette.hover[2], palette.hover[3], palette.hover[4])
        end
        if row.selectedTint then
            row.selectedTint:SetTexture(palette.selected[1], palette.selected[2], palette.selected[3], palette.selected[4])
        end
    end
    if self.combatRowTooltip and self.combatRowTooltip.TitleText then
        self.combatRowTooltip.TitleText:SetTextColor(accent[1], accent[2], accent[3], 1)
    end
end

function UI:GetCombatRowBgStyle()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local mode = settings and settings.combatWhtmRowBgStyle or COMBAT_ROW_BG_EVENT_TINT
    if mode == "color" then
        mode = COMBAT_ROW_BG_EVENT_TINT
    elseif mode == "mono" then
        mode = COMBAT_ROW_BG_NEUTRAL
    end
    if mode ~= COMBAT_ROW_BG_NEUTRAL then
        mode = COMBAT_ROW_BG_EVENT_TINT
    end
    return mode
end

function UI:ApplyCombatDisplayStyle(mode)
    if not self.damageTableWidget then
        return
    end
    mode = mode or self:GetCombatDisplayStyle()
    local isChat = mode == COMBAT_DISPLAY_CHAT
    local dynDetail = tonumber(self.combatDynamicDetailWidth) or COMBAT_DETAIL_WIDTH_BASE
    local dynTotal = tonumber(self.combatDynamicTotalWidth) or COMBAT_TOTAL_WIDTH_BASE
    if dynDetail < COMBAT_DETAIL_WIDTH_BASE then
        dynDetail = COMBAT_DETAIL_WIDTH_BASE
    end
    if dynTotal < COMBAT_TOTAL_WIDTH_BASE then
        dynTotal = COMBAT_TOTAL_WIDTH_BASE
    end
    local tableWidths = {
        time = 68, icon = 34, source = 110, target = 110, ability = 140, type = 62, detail = dynDetail, total = dynTotal,
    }
    local chatWidths = {
        time = 0, icon = 0, source = 0, target = 0, ability = 0, type = 0, detail = 0, total = 0,
    }
    local chatTitles = {
        time = "", icon = "", source = "", target = "", ability = "", type = "", detail = "", total = "", where = "",
    }
    local cols = self.damageTableWidget.columns or {}
    if self.damageTableWidget.header then
        setShown(self.damageTableWidget.header, not isChat)
    end
    if self.damageTableWidget.headerLine then
        setShown(self.damageTableWidget.headerLine, not isChat)
    end
    for _, col in ipairs(cols) do
        if col.header then
            if isChat then
                col.header:SetText(chatTitles[col.key] or "")
                col.header:Hide()
            else
                col.header:SetText(col.title or "")
                col.header:Show()
            end
        end
        if not col.fill then
            local width = isChat and chatWidths[col.key] or tableWidths[col.key]
            if width then
                col.width = width
                if col.header then
                    col.header:SetWidth(width)
                end
                for _, row in ipairs(self.damageTrackerRows or {}) do
                    local text = row.cols and row.cols[col.key]
                    if text then
                        text:SetWidth(width)
                    end
                end
            end
        end
    end
    local rowTopOffset = isChat and -6 or (self.damageTableWidget.rowTopOffset or -22)
    for idx, row in ipairs(self.damageTrackerRows or {}) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", self.damageTableWidget.headerLeft or 6, rowTopOffset - (idx - 1) * (self.damageTableWidget.rowHeight or DAMAGE_ROW_HEIGHT))
        row:SetPoint("RIGHT", row:GetParent(), "RIGHT", self.damageTableWidget.headerRight or -32, 0)
    end
    for _, row in ipairs(self.damageTrackerRows or {}) do
        if isChat then
            for _, col in ipairs(cols) do
                local text = row.cols and row.cols[col.key]
                if text then
                    text:ClearAllPoints()
                    if col.key == "where" then
                        text:SetPoint("LEFT", row, "LEFT", 0, 0)
                        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                    else
                        text:SetPoint("LEFT", row, "LEFT", 0, 0)
                        text:SetWidth(0)
                    end
                end
            end
        else
            local prev = nil
            for _, col in ipairs(cols) do
                local text = row.cols and row.cols[col.key]
                if text then
                    text:ClearAllPoints()
                    if prev then
                        text:SetPoint("LEFT", prev, "RIGHT", col.spacing or 6, 0)
                    else
                        text:SetPoint("LEFT", row, "LEFT", 0, 0)
                    end
                    if col.fill then
                        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                    else
                        text:SetWidth(col.width or 80)
                    end
                    prev = text
                end
            end
        end
    end
    for _, row in ipairs(self.damageTrackerRows or {}) do
        if row.cols and row.cols.where and row.cols.where.SetJustifyH then
            row.cols.where:SetJustifyH(isChat and "LEFT" or "RIGHT")
        end
    end
    for _, col in ipairs(cols) do
        if col.key == "where" and col.header and col.header.SetJustifyH then
            col.header:SetJustifyH(isChat and "LEFT" or "RIGHT")
            break
        end
    end
end

function UI:UpdateCombatDynamicSizing(data, displayStyle)
    if displayStyle == COMBAT_DISPLAY_CHAT then
        if self.combatDynamicDetailWidth or self.combatDynamicTotalWidth or self.combatDynamicWidthExtra then
            self.combatDynamicDetailWidth = nil
            self.combatDynamicTotalWidth = nil
            self.combatDynamicWidthExtra = 0
            self:ApplyCombatDisplayStyle(displayStyle)
            if self.damageTabId and self.currentTab == self.damageTabId then
                self:UpdateFrameWidthForTab(self.damageTabId)
            end
        end
        self.combatBaseWhereWidth = nil
        return
    end
    local settings = Goals and Goals.db and Goals.db.settings or nil
    if not (settings and settings.combatWhtmCombineOverTime) then
        if self.combatDynamicDetailWidth or self.combatDynamicTotalWidth or self.combatDynamicWidthExtra then
            self.combatDynamicDetailWidth = nil
            self.combatDynamicTotalWidth = nil
            self.combatDynamicWidthExtra = 0
            self:ApplyCombatDisplayStyle(displayStyle)
            if self.damageTabId and self.currentTab == self.damageTabId then
                self:UpdateFrameWidthForTab(self.damageTabId)
            end
        end
        local whereCell = self.damageTrackerRows and self.damageTrackerRows[1] and self.damageTrackerRows[1].cols and self.damageTrackerRows[1].cols.where or nil
        self.combatBaseWhereWidth = (whereCell and whereCell.GetWidth and tonumber(whereCell:GetWidth())) or self.combatBaseWhereWidth
        return
    end
    local fs = self.combatMeasureFontString
    if not fs then
        fs = UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:Hide()
        self.combatMeasureFontString = fs
    end
    local function textWidth(text)
        fs:SetText(tostring(text or ""))
        return (fs:GetStringWidth() or 0) + 8
    end
    local function fmtDuration(seconds)
        local s = tonumber(seconds) or 0
        if s < 0.1 then s = 0.1 end
        local rounded = math.floor((s * 10) + 0.5) / 10
        local text = tostring(rounded)
        return string.gsub(text, "%.0$", "")
    end
    local maxDetail = COMBAT_DETAIL_WIDTH_BASE
    local maxTotal = COMBAT_TOTAL_WIDTH_BASE
    local maxWhere = 0
    local hasCombined = false
    local n = math.min(#(data or {}), DAMAGE_ROWS + 10)
    for i = 1, n do
        local event = data[i]
        if event and event.isCombinedOverTime then
            hasCombined = true
            local where = tostring((event.subzone and event.subzone ~= "" and event.subzone) or event.zone or "")
            if event.coordsText and event.coordsText ~= "" then
                where = where ~= "" and (where .. " " .. tostring(event.coordsText)) or tostring(event.coordsText)
            end
            local ww = textWidth(where)
            if ww > maxWhere then
                maxWhere = ww
            end
            local total = tonumber(event.combinedTotal or event.effectiveAmount or event.amount) or 0
            local duration = math.max(0.1, tonumber(event.combinedDuration) or 0.1)
            local rate = tonumber(event.combinedRate) or (total / duration)
            local oh = tonumber(event.combinedOverheal or event.overheal) or 0
            local ok = tonumber(event.combinedOverkill or event.overkill) or 0
            local rs = tonumber(event.combinedResisted or event.resisted) or 0
            local bl = tonumber(event.combinedBlocked or event.blocked) or 0
            local ab = tonumber(event.combinedAbsorbed or event.absorbed) or 0
            local prevented = (event.eventGroup == "heal") and oh or (ok + rs + bl + ab)
            local detailText = tostring(math.floor(rate + 0.5)) .. " (" .. tostring(math.floor((prevented / duration) + 0.5)) .. ") /s"
            local totalText = tostring(math.floor(total + 0.5)) .. " ( " .. tostring(math.floor(prevented + 0.5)) .. " ) /" .. fmtDuration(duration) .. "s"
            local dw = textWidth(detailText)
            local tw = textWidth(totalText)
            if dw > maxDetail then maxDetail = dw end
            if tw > maxTotal then maxTotal = tw end
        end
    end
    if maxDetail > COMBAT_DETAIL_DYNAMIC_CAP then maxDetail = COMBAT_DETAIL_DYNAMIC_CAP end
    if maxTotal > COMBAT_TOTAL_DYNAMIC_CAP then maxTotal = COMBAT_TOTAL_DYNAMIC_CAP end
    if (maxDetail - COMBAT_DETAIL_WIDTH_BASE) <= COMBAT_DYNAMIC_DEADZONE then
        maxDetail = COMBAT_DETAIL_WIDTH_BASE
    end
    if (maxTotal - COMBAT_TOTAL_WIDTH_BASE) <= COMBAT_DYNAMIC_DEADZONE then
        maxTotal = COMBAT_TOTAL_WIDTH_BASE
    end
    local detailExtra = (maxDetail - COMBAT_DETAIL_WIDTH_BASE)
    local totalExtra = (maxTotal - COMBAT_TOTAL_WIDTH_BASE)
    if detailExtra < 0 then detailExtra = 0 end
    if totalExtra < 0 then totalExtra = 0 end
    local whereExtra = 0
    if hasCombined then
        local whereCell = self.damageTrackerRows and self.damageTrackerRows[1] and self.damageTrackerRows[1].cols and self.damageTrackerRows[1].cols.where or nil
        local baseWhere = tonumber(self.combatBaseWhereWidth) or 0
        if baseWhere <= 0 and whereCell and whereCell.GetWidth then
            baseWhere = tonumber(whereCell:GetWidth()) or 0
        end
        if baseWhere <= 0 then
            baseWhere = COMBAT_WHERE_MIN_WIDTH
        end
        self.combatBaseWhereWidth = baseWhere
        if maxWhere > baseWhere + COMBAT_DYNAMIC_DEADZONE then
            whereExtra = maxWhere - baseWhere
        end
    end

    local extra = detailExtra + totalExtra + whereExtra
    if extra < 0 then extra = 0 end
    if extra > COMBAT_DYNAMIC_EXTRA_MAX then
        extra = COMBAT_DYNAMIC_EXTRA_MAX
    end
    local changed = (self.combatDynamicDetailWidth ~= maxDetail)
        or (self.combatDynamicTotalWidth ~= maxTotal)
        or ((self.combatDynamicWidthExtra or 0) ~= extra)
    if not changed then
        return
    end
    self.combatDynamicDetailWidth = maxDetail
    self.combatDynamicTotalWidth = maxTotal
    self.combatDynamicWidthExtra = extra
    self:ApplyCombatDisplayStyle(displayStyle)
    if self.damageTabId and self.currentTab == self.damageTabId then
        self:UpdateFrameWidthForTab(self.damageTabId)
    end
end

function UI:UpdateDamageTabVisibility()
    if not self.damageTab or not self.damageTabId then
        return
    end
    local enabled = true
    setShown(self.damageTab, enabled)
    self:LayoutTabs()
end

function UI:NormalizeCombatShowFlags(settings)
    if not settings then
        return false, false, true
    end
    local mode = settings.combatLogViewMode
    if mode ~= COMBAT_SHOW_ALL and mode ~= COMBAT_SHOW_BOSS and mode ~= COMBAT_SHOW_TRASH then
        mode = COMBAT_SHOW_ALL
        settings.combatLogViewMode = mode
    end
    local showHealing = settings.combatLogShowHealing
    if showHealing == nil then
        showHealing = false
        settings.combatLogShowHealing = showHealing
    end
    local showDealt = settings.combatLogShowDamageDealt
    if showDealt == nil then
        showDealt = false
        settings.combatLogShowDamageDealt = showDealt
    end
    local showReceived = settings.combatLogShowDamageReceived
    if showReceived == nil then
        showReceived = true
        settings.combatLogShowDamageReceived = showReceived
    end
    return showHealing, showDealt, showReceived
end

function UI:GetCombatShowMode(settings)
    settings = settings or (Goals and Goals.db and Goals.db.settings) or nil
    if not settings then
        return COMBAT_SHOW_ALL
    end
    local mode = settings.combatLogViewMode
    if mode == COMBAT_SHOW_BOSS or mode == COMBAT_SHOW_TRASH then
        return mode
    end
    settings.combatLogViewMode = COMBAT_SHOW_ALL
    return COMBAT_SHOW_ALL
end

function UI:SetCombatShowMode(mode, settings)
    settings = settings or (Goals and Goals.db and Goals.db.settings) or nil
    if not settings then
        return
    end
    if mode ~= COMBAT_SHOW_ALL and mode ~= COMBAT_SHOW_BOSS and mode ~= COMBAT_SHOW_TRASH then
        mode = COMBAT_SHOW_ALL
    end
    settings.combatLogViewMode = mode
    settings.combatLogShowHealing = false
    settings.combatLogShowDamageDealt = false
    settings.combatLogShowDamageReceived = true
end

function UI:GetCombatShowSummary(settings)
    local mode = self:GetCombatShowMode(settings)
    if mode == COMBAT_SHOW_ALL then
        return "Show: All"
    end
    return "Show: " .. mode
end

function UI:UpdateDamageOptionsVisibility()
    if not self.damageOptionsFrame then
        return
    end
    local open = self.damageOptionsOpen
    if self.damageOptionsInline then
        open = true
    end
    local show = self.currentTab == self.damageTabId and open
    if self.damageOptionsOuter then
        setShown(self.damageOptionsOuter, show)
    end
    setShown(self.damageOptionsFrame, show)
end

function UI:CreateDamageTrackerTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsDamageOptionsInset", OPTIONS_PANEL_WIDTH)
    self.damageOptionsFrame = optionsPanel
    self.damageOptionsScroll = optionsPanel.scroll
    self.damageOptionsContent = optionsContent
    self.damageOptionsOpen = true
    self.damageOptionsInline = true

    local inset = CreateFrame("Frame", "GoalsDamageTrackerInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    inset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(inset, "GoalsDamageTrackerTable", {
        columns = {
            { key = "time", title = "Time", width = 68, justify = "LEFT", wrap = false },
            { key = "icon", title = "Icon", width = 34, justify = "LEFT", wrap = false },
            { key = "source", title = "Source", width = 110, justify = "LEFT", wrap = false },
            { key = "target", title = "Target", width = 110, justify = "LEFT", wrap = false },
            { key = "ability", title = "Ability", width = 140, justify = "LEFT", wrap = false },
            { key = "type", title = "Type", width = 62, justify = "LEFT", wrap = false },
            { key = "detail", title = "Detail", width = COMBAT_DETAIL_WIDTH_BASE, justify = "LEFT", wrap = false },
            { key = "total", title = "Total", width = COMBAT_TOTAL_WIDTH_BASE, justify = "LEFT", wrap = false },
            { key = "where", title = "Where", fill = true, justify = "RIGHT", wrap = false },
        },
        rowHeight = DAMAGE_ROW_HEIGHT,
        visibleRows = DAMAGE_ROWS,
        headerHeight = 16,
    })
    self.damageTableWidget = tableWidget
    self.damageTrackerScroll = tableWidget.scroll
    self.damageTrackerRows = tableWidget.rows

    local function clearCombatSession()
        if Goals and Goals.CombatProvider and Goals.CombatProvider.ClearLog then
            Goals.CombatProvider:ClearLog()
        end
        UI:UpdateDamageTrackerList()
    end

    if tableWidget and tableWidget.header then
        local headerClearBtn = CreateFrame("Button", nil, tableWidget.header, "UIPanelButtonTemplate")
        headerClearBtn:SetSize(16, 16)
        headerClearBtn:SetParent(inset)
        headerClearBtn:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -9, -6)
        headerClearBtn:SetText("X")
        headerClearBtn:SetScript("OnClick", function()
            clearCombatSession()
        end)
        attachSideTooltip(headerClearBtn, "Clear session combat rows.")
        self.combatHeaderClearButton = headerClearBtn
    end

    self.damageTrackerScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, DAMAGE_ROW_HEIGHT, function()
            UI:UpdateDamageTrackerList()
        end)
    end)
    self.damageTrackerScroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, selfScroll._contentHeight or 0)
    end)

    self.combatUnavailableLabel = createLabel(inset, "WHTM not loaded. Install/enable WHTM to use Combat.", "GameFontHighlight")
    self.combatUnavailableLabel:SetPoint("CENTER", inset, "CENTER", 0, 0)
    self.combatUnavailableLabel:SetJustifyH("CENTER")
    self.combatUnavailableLabel:SetTextColor(1, 0.35, 0.35, 1)
    self.combatUnavailableLabel:Hide()

    self.combatRetryButton = createOptionsButton(inset)
    styleOptionsButton(self.combatRetryButton, 170)
    self.combatRetryButton:SetPoint("TOP", self.combatUnavailableLabel, "BOTTOM", 0, -8)
    self.combatRetryButton:SetText("Retry WHTM detection")
    self.combatRetryButton:SetScript("OnClick", function()
        if Goals and Goals.CombatProvider and Goals.CombatProvider.Init then
            Goals.CombatProvider:Init()
        end
        UI:UpdateDamageTrackerList()
    end)
    self.combatRetryButton:Hide()

    for _, row in ipairs(self.damageTrackerRows) do
        if not row.softTint then
            local soft = row:CreateTexture(nil, "BACKGROUND", nil, 1)
            soft:SetAllPoints(row)
            soft:SetTexture(0, 0, 0, 0)
            row.softTint = soft
        end
        if not row.hoverTint then
            local hover = row:CreateTexture(nil, "HIGHLIGHT", nil, 1)
            hover:SetAllPoints(row)
            hover:SetTexture(1, 1, 1, 0.12)
            hover:Hide()
            row.hoverTint = hover
        end
        if not row.selectedTint then
            local selected = row:CreateTexture(nil, "ARTWORK", nil, 1)
            selected:SetAllPoints(row)
            selected:SetTexture(1, 0.82, 0.25, 0.16)
            selected:Hide()
            row.selectedTint = selected
        end
        row:EnableMouse(true)
        if row.RegisterForClicks then
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.hoverTint then
                selfRow.hoverTint:Show()
            end
            if selfRow.entry and not (UI and UI.combatTooltipLocked) then
                showCombatRowTooltip(selfRow.entry)
            end
        end)
        row:SetScript("OnLeave", function(selfRow)
            if selfRow.hoverTint then
                selfRow.hoverTint:Hide()
            end
            if not (UI and UI.combatTooltipLocked) then
                hideCombatRowTooltip()
            end
        end)
        row:SetScript("OnMouseUp", function(selfRow, button)
            if button == "LeftButton" and selfRow.entry then
                setCombatRowTooltipLock(selfRow.entry, true)
                showCombatRowTooltip(selfRow.entry)
                return
            end
            if button == "RightButton" and selfRow.entry and UI and UI.ShowCombatRowMenu then
                setCombatRowTooltipLock(selfRow.entry, true)
                showCombatRowTooltip(selfRow.entry)
                UI:ShowCombatRowMenu(selfRow.entry, selfRow)
            end
        end)
    end

    inset:EnableMouse(true)
    inset:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        clearCombatRowTooltipLock()
        hideCombatRowTooltip()
    end)
    if tableWidget and tableWidget.header then
        tableWidget.header:EnableMouse(true)
        tableWidget.header:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then
                return
            end
            clearCombatRowTooltipLock()
            hideCombatRowTooltip()
        end)
    end

    local y = -10
    local function addSectionHeader(text)
        createOptionsHeader(optionsContent, text, y)
        y = y - 22
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

    local function addLabel(text)
        local label = createLabel(optionsContent, text, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsControlLabel(label)
        y = y - 18
        return label
    end

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    local provider = Goals and Goals.CombatProvider or nil
    Goals.db.settings.combatWhtmDirections = Goals.db.settings.combatWhtmDirections or { incoming = true, outgoing = false, internal = false }
    Goals.db.settings.combatWhtmGroups = Goals.db.settings.combatWhtmGroups or {
        damage = true, heal = true, aura = true, miss = true, death = true, control = true, resource = true
    }
    Goals.db.settings.combatWhtmAuraStates = Goals.db.settings.combatWhtmAuraStates or { gained = true, lost = true, other = true }
    if Goals.db.settings.combatWhtmSoftRowColors == nil then
        Goals.db.settings.combatWhtmSoftRowColors = true
    end
    if Goals.db.settings.combatWhtmRowBgStyle == nil then
        Goals.db.settings.combatWhtmRowBgStyle = COMBAT_ROW_BG_EVENT_TINT
    end
    if Goals.db.settings.combatWhtmHideMinimapIcon == nil then
        Goals.db.settings.combatWhtmHideMinimapIcon = false
    end
    if Goals.db.settings.combatWhtmBossOnly == nil then
        Goals.db.settings.combatWhtmBossOnly = false
    end
    if Goals.db.settings.combatWhtmRetainFullHistory == nil then
        Goals.db.settings.combatWhtmRetainFullHistory = false
    end
    if Goals.db.settings.combatWhtmTheme == nil then
        Goals.db.settings.combatWhtmTheme = COMBAT_THEME_NEUTRAL
    end
    if Goals.db.settings.combatWhtmDisplayStyle == nil then
        Goals.db.settings.combatWhtmDisplayStyle = COMBAT_DISPLAY_TABLE
    end
    if Goals.db.settings.combatWhtmCombineOverTime == nil then
        Goals.db.settings.combatWhtmCombineOverTime = false
    end
    local function syncProvider()
        if provider and provider.SyncSettingsToWHTM then
            provider:SyncSettingsToWHTM()
            provider:RefreshEvents()
        end
        UI:UpdateDamageTrackerList()
    end

    addSectionHeader("Capture")
    addLabel("Scope")
    local scopeDrop = addDropdown("GoalsCombatScopeDropdown")
    self:SetupDropdown(scopeDrop, function()
        return {
            { value = "player", text = "Self only" },
            { value = "party", text = "Party group" },
            { value = "raid", text = "Raid group" },
        }
    end, function(value)
        Goals.db.settings.combatWhtmScope = value
        syncProvider()
    end, Goals.db.settings.combatWhtmScope or "player")
    self.combatScopeDropdown = scopeDrop

    local pausedCheck = addCheck("Pause capture", function(selfBtn)
        Goals.db.settings.combatWhtmPaused = selfBtn:GetChecked() and true or false
        syncProvider()
    end, "Pause/resume combat capture.")
    self.combatPausedCheck = pausedCheck
    self.combatBossOnlyCheck = addCheck("Boss encounters only", function(selfBtn)
        Goals.db.settings.combatWhtmBossOnly = selfBtn:GetChecked() and true or false
        syncProvider()
    end, "Only show events where source or target is classified as boss.")

    addSectionHeader("Filters")
    addLabel("Direction")
    local dirIn = addCheck("Incoming", function(selfBtn)
        Goals.db.settings.combatWhtmDirections.incoming = selfBtn:GetChecked() and true or false
        syncProvider()
    end, "Events happening to tracked units.")
    local dirOut = addCheck("Outgoing", function(selfBtn)
        Goals.db.settings.combatWhtmDirections.outgoing = selfBtn:GetChecked() and true or false
        syncProvider()
    end, "Events done by tracked units.")
    local dirInternal = addCheck("Internal", function(selfBtn)
        Goals.db.settings.combatWhtmDirections.internal = selfBtn:GetChecked() and true or false
        syncProvider()
    end, "Tracked source and target events.")
    self.combatDirIncomingCheck = dirIn
    self.combatDirOutgoingCheck = dirOut
    self.combatDirInternalCheck = dirInternal

    addSectionHeader("Groups")
    self.combatGroupChecks = {}
    local groupKeys = {
        { "damage", "Damage" },
        { "heal", "Heal" },
        { "aura", "Aura" },
        { "miss", "Miss" },
        { "death", "Death" },
        { "control", "Control" },
        { "resource", "Resource" },
    }
    for i = 1, #groupKeys do
        local key, label = groupKeys[i][1], groupKeys[i][2]
        self.combatGroupChecks[key] = addCheck(label, function(selfBtn)
            Goals.db.settings.combatWhtmGroups[key] = selfBtn:GetChecked() and true or false
            syncProvider()
        end, "Toggle " .. label .. " events.")
    end

    addSectionHeader("Aura State")
    self.combatAuraChecks = {}
    local auraKeys = {
        { "gained", "Aura gained" },
        { "lost", "Aura lost" },
        { "other", "Aura other" },
    }
    for i = 1, #auraKeys do
        local key, label = auraKeys[i][1], auraKeys[i][2]
        self.combatAuraChecks[key] = addCheck(label, function(selfBtn)
            Goals.db.settings.combatWhtmAuraStates[key] = selfBtn:GetChecked() and true or false
            syncProvider()
        end, "Toggle " .. label .. " entries.")
    end

    addSectionHeader("Display")
    addLabel("Display style")
    local displayDrop = addDropdown("GoalsCombatDisplayStyleDropdown")
    self:SetupDropdown(displayDrop, function()
        return {
            { value = COMBAT_DISPLAY_TABLE, text = "Table" },
            { value = COMBAT_DISPLAY_CHAT, text = "Chat style" },
        }
    end, function(value)
        Goals.db.settings.combatWhtmDisplayStyle = value
        UI:ApplyCombatDisplayStyle(value)
        syncProvider()
    end, "Table")
    self.combatDisplayStyleDropdown = displayDrop

    addLabel("Timestamp")
    local tsDrop = addDropdown("GoalsCombatTimestampDropdown")
    self:SetupDropdown(tsDrop, function()
        return {
            { value = "24h", text = "24h" },
            { value = "12h", text = "12h" },
        }
    end, function(value)
        Goals.db.settings.combatWhtmTimestampFormat = value
        syncProvider()
    end, Goals.db.settings.combatWhtmTimestampFormat or "24h")
    self.combatTimestampDropdown = tsDrop

    addLabel("Theme")
    local themeDrop = addDropdown("GoalsCombatThemeDropdown")
    self:SetupDropdown(themeDrop, function()
        return {
            { value = COMBAT_THEME_NEUTRAL, text = "Neutral" },
            { value = COMBAT_THEME_ALLIANCE, text = "Alliance" },
            { value = COMBAT_THEME_HORDE, text = "Horde" },
            { value = COMBAT_THEME_CLASS, text = "Class Accent" },
        }
    end, function(value)
        Goals.db.settings.combatWhtmTheme = value
        UI:ApplyCombatTheme()
    end, "Neutral")
    self.combatThemeDropdown = themeDrop

    self.combatSoftRowsCheck = addCheck("Soft row colors", function(selfBtn)
        Goals.db.settings.combatWhtmSoftRowColors = selfBtn:GetChecked() and true or false
        UI:UpdateDamageTrackerList()
    end, "Use subtle per-event row tinting in the combat table.")
    self.combatCombineOverTimeCheck = addCheck("Combine Over-Time Events", function(selfBtn)
        Goals.db.settings.combatWhtmCombineOverTime = selfBtn:GetChecked() and true or false
        UI:UpdateDamageTrackerList()
    end, "Merge DoT/HoT periodic ticks into rolling summaries.")
    addLabel("Row background style")
    local rowBgStyleDrop = addDropdown("GoalsCombatRowBgStyleDropdown")
    self:SetupDropdown(rowBgStyleDrop, function()
        return {
            { value = COMBAT_ROW_BG_EVENT_TINT, text = "Event" },
            { value = COMBAT_ROW_BG_NEUTRAL, text = "Neutral (B/W)" },
        }
    end, function(value)
        Goals.db.settings.combatWhtmRowBgStyle = value
        UI:UpdateDamageTrackerList()
    end, "Event")
    self.combatRowBgStyleDropdown = rowBgStyleDrop
    self.combatHideMinimapCheck = addCheck("Hide WHTM minimap icon", function(selfBtn)
        Goals.db.settings.combatWhtmHideMinimapIcon = selfBtn:GetChecked() and true or false
        syncProvider()
    end, "Hide/show WHTM minimap launcher icon.")

    addSectionHeader("Session")
    local retainHistoryCheck = addCheck("Retain full history", function(selfBtn)
        Goals.db.settings.combatWhtmRetainFullHistory = selfBtn:GetChecked() and true or false
        local retain = Goals.db.settings.combatWhtmRetainFullHistory
        if UI.combatMaxRowsSlider then
            if retain then
                UI.combatMaxRowsSlider:Disable()
                if UI.combatMaxRowsSlider.SetAlpha then
                    UI.combatMaxRowsSlider:SetAlpha(0.45)
                end
            else
                UI.combatMaxRowsSlider:Enable()
                if UI.combatMaxRowsSlider.SetAlpha then
                    UI.combatMaxRowsSlider:SetAlpha(1)
                end
            end
        end
        if UI.combatMaxRowsValue then
            if retain then
                UI.combatMaxRowsValue:SetText("Max rows: Session (unlimited)")
            else
                UI.combatMaxRowsValue:SetText(("Max rows: %d"):format(Goals.db.settings.combatWhtmMaxRows or 600))
            end
        end
        syncProvider()
    end, "Keep the full combat history for this play session (disables row cap).")
    self.combatRetainHistoryCheck = retainHistoryCheck

    local maxRowsSlider = CreateFrame("Slider", "GoalsCombatMaxRowsSlider", optionsContent, "OptionsSliderTemplate")
    maxRowsSlider:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    styleOptionsSlider(maxRowsSlider)
    maxRowsSlider:SetMinMaxValues(100, 3000)
    maxRowsSlider:SetValueStep(50)
    attachSideTooltip(maxRowsSlider, "Max in-memory combat rows.")
    y = y - 28
    local maxRowsValue = createLabel(optionsContent, "", "GameFontHighlightSmall")
    maxRowsValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    y = y - 18
    maxRowsSlider:SetScript("OnValueChanged", function(selfSlider, value)
        local clamped = math.floor((tonumber(value) or 600) / 50 + 0.5) * 50
        if clamped < 100 then
            clamped = 100
        elseif clamped > 3000 then
            clamped = 3000
        end
        Goals.db.settings.combatWhtmMaxRows = clamped
        if Goals.db.settings.combatWhtmRetainFullHistory then
            maxRowsValue:SetText("Max rows: Session (unlimited)")
        else
            maxRowsValue:SetText(("Max rows: %d"):format(clamped))
        end
        syncProvider()
    end)
    self.combatMaxRowsSlider = maxRowsSlider
    self.combatMaxRowsValue = maxRowsValue
    if Goals.db.settings.combatWhtmRetainFullHistory then
        maxRowsSlider:Disable()
        if maxRowsSlider.SetAlpha then
            maxRowsSlider:SetAlpha(0.45)
        end
        maxRowsValue:SetText("Max rows: Session (unlimited)")
    end

    local clearBtn = createOptionsButton(optionsContent)
    styleOptionsButton(clearBtn, OPTIONS_CONTROL_WIDTH)
    clearBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    clearBtn:SetText("Clear session")
    clearBtn:SetScript("OnClick", function()
        clearCombatSession()
    end)
    attachSideTooltip(clearBtn, "Clear current session combat rows.")
    y = y - 30
    self.combatLogClearButton = clearBtn

    local broadcastBtn = createOptionsButton(optionsContent)
    styleOptionsButton(broadcastBtn, OPTIONS_CONTROL_WIDTH)
    broadcastBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    broadcastBtn:SetText("Open share panel")
    broadcastBtn:SetScript("OnClick", function()
        if UI and UI.ToggleCombatBroadcastPopout then
            UI:ToggleCombatBroadcastPopout()
        end
    end)
    y = y - 30

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
    self:ApplyCombatDisplayStyle(Goals.db.settings.combatWhtmDisplayStyle or COMBAT_DISPLAY_TABLE)
    self:ApplyCombatTheme()
end

function UI:EnsureCombatWhisperPopup()
    if not StaticPopupDialogs or StaticPopupDialogs.GOALS_COMBAT_WHISPER then
        return
    end
    StaticPopupDialogs.GOALS_COMBAT_WHISPER = {
        text = "Whisper target",
        button1 = "Send",
        button2 = "Cancel",
        hasEditBox = 1,
        maxLetters = 64,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = function(selfPopup, data)
            local target = data and data.target or ""
            selfPopup.editBox:SetText(target or "")
            selfPopup.editBox:SetFocus()
            selfPopup.editBox:HighlightText()
        end,
        OnAccept = function(selfPopup, data)
            local target = selfPopup.editBox:GetText()
            if target and target ~= "" and data and data.entry and Goals and Goals.UI and Goals.UI.SendCombatEntryToChannel then
                if Goals.db and Goals.db.settings then
                    Goals.db.settings.combatLogBroadcastWhisperTarget = target
                end
                Goals.UI:SendCombatEntryToChannel(data.entry, "WHISPER", target)
            end
        end,
        EditBoxOnEnterPressed = function(selfPopup)
            local parent = selfPopup:GetParent()
            local target = selfPopup:GetText()
            local data = parent and parent.data or nil
            if target and target ~= "" and data and data.entry and Goals and Goals.UI and Goals.UI.SendCombatEntryToChannel then
                if Goals.db and Goals.db.settings then
                    Goals.db.settings.combatLogBroadcastWhisperTarget = target
                end
                Goals.UI:SendCombatEntryToChannel(data.entry, "WHISPER", target)
            end
            parent:Hide()
        end,
    }
end

function UI:ShowCombatWhisperPopup(entry, defaultTarget)
    self:EnsureCombatWhisperPopup()
    if StaticPopup_Show then
        StaticPopup_Show("GOALS_COMBAT_WHISPER", nil, nil, { entry = entry, target = defaultTarget })
    end
end

function UI:SendCombatEntryToChannel(entry, channel, target)
    if channel == "WHISPER_TARGET" then
        if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
            target = UnitName and UnitName("target") or target
            channel = "WHISPER"
        end
    end
    local line = self:FormatCombatBroadcastLine(entry)
    if not line or line == "" then
        return
    end
    self:SendCombatChatLine(line, channel, target)
end

function UI:ShowCombatRowMenu(entry, anchor)
    if not entry then
        return
    end
    if not self.combatRowMenu then
        self.combatRowMenu = CreateFrame("Frame", "GoalsCombatRowMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = self.combatRowMenu
    menu.entry = entry
    local preview = self:FormatCombatBroadcastLine(entry)
    UIDropDownMenu_Initialize(menu, function(_, level)
        if level == 1 then
            local info = UIDropDownMenu_CreateInfo()
            info.isTitle = true
            info.text = "Send To..."
            UIDropDownMenu_AddButton(info, level)

            local inRaid = Goals and Goals.IsInRaid and Goals:IsInRaid()
            local inParty = Goals and Goals.IsInParty and Goals:IsInParty() and (GetNumPartyMembers and GetNumPartyMembers() > 0)
            local isLeader = Goals and Goals.IsGroupLeader and Goals:IsGroupLeader()

            if inRaid then
                if isLeader then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "Raid"
                    info.value = "RAID_MENU"
                    info.hasArrow = true
                    info.tooltipTitle = "Raid"
                    info.tooltipText = preview
                    UIDropDownMenu_AddButton(info, level)
                else
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "Raid"
                    info.func = function() UI:SendCombatEntryToChannel(entry, "RAID") end
                    info.tooltipTitle = "Raid"
                    info.tooltipText = preview
                    UIDropDownMenu_AddButton(info, level)
                end
            end

            if inParty then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Party"
                info.func = function() UI:SendCombatEntryToChannel(entry, "PARTY") end
                info.tooltipTitle = "Party"
                info.tooltipText = preview
                UIDropDownMenu_AddButton(info, level)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = "Local"
            info.func = function() UI:SendCombatEntryToChannel(entry, "SAY") end
            info.tooltipTitle = "Local"
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)

            if IsInGuild and IsInGuild() then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Guild"
                info.func = function() UI:SendCombatEntryToChannel(entry, "GUILD") end
                info.tooltipTitle = "Guild"
                info.tooltipText = preview
                UIDropDownMenu_AddButton(info, level)
            end

            if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Whisper Target"
                info.func = function() UI:SendCombatEntryToChannel(entry, "WHISPER_TARGET") end
                info.tooltipTitle = "Whisper Target"
                info.tooltipText = preview
                UIDropDownMenu_AddButton(info, level)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = "Whisper..."
            info.func = function() UI:ShowCombatWhisperPopup(entry, Goals.db.settings.combatLogBroadcastWhisperTarget or "") end
            info.tooltipTitle = "Whisper..."
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)
        elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "RAID_MENU" then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Raid"
            info.func = function() UI:SendCombatEntryToChannel(entry, "RAID") end
            info.tooltipTitle = "Raid"
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Raid Warning"
            info.func = function() UI:SendCombatEntryToChannel(entry, "RAID_WARNING") end
            info.tooltipTitle = "Raid Warning"
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    ToggleDropDownMenu(1, nil, menu, anchor, 0, 0)
end

function UI:CreateCombatBroadcastPopout()
    if self.combatBroadcastPopout then
        return
    end
    local frame = CreateFrame("Frame", "GoalsCombatBroadcastPopout", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(frame)
    frame:SetSize(OPTIONS_PANEL_WIDTH + 12, 230)
    frame.baseHeight = 190
    frame.whisperExtra = 54
    if self.frame then
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    self.combatBroadcastPopout = frame

    if frame.TitleText then
        frame.TitleText:SetText("Combat Broadcast")
        frame.TitleText:Show()
    end

    local content = CreateFrame("Frame", nil, frame, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.content = content

    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local y = -24
    local sendLabel = createLabel(content, "Send to", "GameFontNormalSmall")
    sendLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(sendLabel)
    y = y - 18

    local dropdown = CreateFrame("Frame", "GoalsCombatBroadcastChannelDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", content, "TOPLEFT", -6, y)
    styleDropdown(dropdown, OPTIONS_CONTROL_WIDTH)
    self:SetupCombatBroadcastDropdown(dropdown)
    self.combatBroadcastChannelDropdown = dropdown
    y = y - 36
    frame.broadcastYAfterDropdown = y

    local whisperLabel = createLabel(content, "Whisper target", "GameFontNormalSmall")
    whisperLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(whisperLabel)
    local whisperBox = CreateFrame("EditBox", "GoalsCombatBroadcastWhisperBox", content, "InputBoxTemplate")
    whisperBox:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y - 18)
    whisperBox:SetAutoFocus(false)
    whisperBox:SetText(Goals.db.settings.combatLogBroadcastWhisperTarget or "")
    styleOptionsEditBox(whisperBox, OPTIONS_CONTROL_WIDTH)
    self.combatBroadcastWhisperLabel = whisperLabel
    self.combatBroadcastWhisperBox = whisperBox
    y = y - 54
    frame.broadcastYAfterWhisper = y

    local countLabel = createLabel(content, "Lines to send", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(countLabel)
    local countValue = createLabel(content, "9", "GameFontHighlightSmall")
    countValue:SetPoint("TOPRIGHT", content, "TOPLEFT", 8 + OPTIONS_CONTROL_WIDTH, y)
    countValue:SetJustifyH("RIGHT")
    y = y - 18

    local countSlider = CreateFrame("Slider", "GoalsCombatBroadcastCountSlider", content, "OptionsSliderTemplate")
    countSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsSlider(countSlider)
    countSlider:SetMinMaxValues(1, 9)
    countSlider:SetValueStep(1)
    if countSlider.SetObeyStepOnDrag then
        countSlider:SetObeyStepOnDrag(true)
    end
    self.combatBroadcastCountSlider = countSlider
    self.combatBroadcastCountValue = countValue
    y = y - 28

    local sendBtn = createOptionsButton(content)
    styleOptionsButton(sendBtn, OPTIONS_CONTROL_WIDTH)
    sendBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    sendBtn:SetText("Send")
    sendBtn:SetScript("OnClick", function()
        local channel = Goals.db.settings.combatLogBroadcastChannel or "SAY"
        local count = Goals.db.settings.combatLogBroadcastCount or 9
        local target = Goals.db.settings.combatLogBroadcastWhisperTarget or ""
        if channel == "WHISPER" then
            if self.combatBroadcastWhisperBox then
                target = self.combatBroadcastWhisperBox:GetText() or ""
                Goals.db.settings.combatLogBroadcastWhisperTarget = target
            end
            if target == "" then
                if Goals and Goals.Print then
                    Goals:Print("Enter a whisper target.")
                end
                return
            end
        elseif channel == "WHISPER_TARGET" then
            if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
                target = UnitName and UnitName("target") or target
            else
                if Goals and Goals.Print then
                    Goals:Print("No whisper target selected.")
                end
                return
            end
            channel = "WHISPER"
        end
        self:SendCombatBroadcastLines(channel, target, count)
    end)
    attachSideTooltip(sendBtn, "Send recent combat log lines to the selected chat.")

    countSlider:SetScript("OnValueChanged", function(selfSlider, value)
        local val = math.floor((tonumber(value) or 0) + 0.5)
        if val < 1 then
            val = 1
        elseif val > 9 then
            val = 9
        end
        Goals.db.settings.combatLogBroadcastCount = val
        if countValue then
            countValue:SetText(string.format("%d", val))
        end
    end)

    local count = tonumber(Goals.db.settings.combatLogBroadcastCount) or 9
    if count < 1 then
        count = 1
    elseif count > 9 then
        count = 9
    end
    Goals.db.settings.combatLogBroadcastCount = count
    countSlider:SetValue(count)

    self:RefreshCombatBroadcastDropdown()
    self:UpdateCombatBroadcastLayout()

    self.combatBroadcastCountLabel = countLabel
    self.combatBroadcastCountValue = countValue
    self.combatBroadcastCountSlider = countSlider
    self.combatBroadcastSendButton = sendBtn
end

function UI:ToggleCombatBroadcastPopout()
    if not self.combatBroadcastPopout then
        self:CreateCombatBroadcastPopout()
    end
    if not self.combatBroadcastPopout then
        return
    end
    if self.combatBroadcastPopout:IsShown() then
        self.combatBroadcastPopout:Hide()
    else
        self.combatBroadcastPopout:Show()
        self:RefreshCombatBroadcastDropdown()
        self:UpdateCombatBroadcastLayout()
    end
end

function UI:GetCombatBroadcastOptions()
    local options = {}
    local function add(label, value, target)
        table.insert(options, { label = label, value = value, target = target })
    end
    add("Local", "SAY")
    if Goals and Goals.IsInParty and Goals:IsInParty() then
        if GetNumPartyMembers and GetNumPartyMembers() > 0 then
            add("Party", "PARTY")
        end
    end
    if Goals and Goals.IsInRaid and Goals:IsInRaid() then
        add("Raid", "RAID")
        if Goals.IsGroupLeader and Goals:IsGroupLeader() then
            add("Raid Warning", "RAID_WARNING")
        end
    end
    if IsInGuild and IsInGuild() then
        add("Guild", "GUILD")
    end
    if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
        local targetName = UnitName and UnitName("target") or nil
        if targetName and targetName ~= "" then
            add("Whisper Target", "WHISPER_TARGET", targetName)
        end
    end
    add("Whisper", "WHISPER")
    return options
end

function UI:SetupCombatBroadcastDropdown(dropdown)
    if not dropdown then
        return
    end
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local options = self:GetCombatBroadcastOptions()
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.func = function()
                Goals.db.settings.combatLogBroadcastChannel = option.value
                if option.value == "WHISPER_TARGET" and option.target then
                    Goals.db.settings.combatLogBroadcastWhisperTarget = option.target
                end
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                self:SetDropdownText(dropdown, option.label)
                if self.combatBroadcastWhisperBox then
                    if option.value == "WHISPER" then
                        self.combatBroadcastWhisperBox:Show()
                        if self.combatBroadcastWhisperLabel then
                            self.combatBroadcastWhisperLabel:Show()
                        end
                    else
                        self.combatBroadcastWhisperBox:Hide()
                        if self.combatBroadcastWhisperLabel then
                            self.combatBroadcastWhisperLabel:Hide()
                        end
                    end
                end
                if self.UpdateCombatBroadcastLayout then
                    self:UpdateCombatBroadcastLayout()
                end
            end
            info.checked = Goals.db.settings.combatLogBroadcastChannel == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function UI:RefreshCombatBroadcastDropdown()
    local dropdown = self.combatBroadcastChannelDropdown
    if not dropdown then
        return
    end
    local options = self:GetCombatBroadcastOptions()
    local selected = Goals.db.settings.combatLogBroadcastChannel or "SAY"
    local selectedLabel = nil
    local whisperTarget = Goals.db.settings.combatLogBroadcastWhisperTarget or ""
    for _, option in ipairs(options) do
        if option.value == selected then
            selectedLabel = option.label
            if option.value == "WHISPER_TARGET" and option.target then
                whisperTarget = option.target
            end
            break
        end
    end
    if not selectedLabel and options[1] then
        selected = options[1].value
        selectedLabel = options[1].label
    end
    Goals.db.settings.combatLogBroadcastChannel = selected
    if whisperTarget ~= "" then
        Goals.db.settings.combatLogBroadcastWhisperTarget = whisperTarget
    end
    UIDropDownMenu_SetSelectedValue(dropdown, selected)
    self:SetDropdownText(dropdown, selectedLabel or L.SELECT_OPTION)
    if self.combatBroadcastWhisperBox then
        if selected == "WHISPER" then
            self.combatBroadcastWhisperBox:Show()
            if self.combatBroadcastWhisperLabel then
                self.combatBroadcastWhisperLabel:Show()
            end
        else
            self.combatBroadcastWhisperBox:Hide()
            if self.combatBroadcastWhisperLabel then
                self.combatBroadcastWhisperLabel:Hide()
            end
        end
    end
    if self.UpdateCombatBroadcastLayout then
        self:UpdateCombatBroadcastLayout()
    end
end

function UI:UpdateCombatBroadcastLayout()
    if not self.combatBroadcastPopout then
        return
    end
    local frame = self.combatBroadcastPopout
    local content = frame.content or frame
    local showWhisper = self.combatBroadcastWhisperBox and self.combatBroadcastWhisperBox:IsShown()
    local height = frame.baseHeight or 170
    if showWhisper then
        height = height + (frame.whisperExtra or 44)
    end
    frame:SetHeight(height)
    if frame.content then
        frame.content:SetHeight(height - 30)
    end

    local countY = frame.broadcastYAfterDropdown or -86
    if showWhisper then
        countY = frame.broadcastYAfterWhisper or countY
    end
    if self.combatBroadcastCountLabel then
        self.combatBroadcastCountLabel:ClearAllPoints()
        self.combatBroadcastCountLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, countY)
    end
    if self.combatBroadcastCountValue then
        self.combatBroadcastCountValue:ClearAllPoints()
        self.combatBroadcastCountValue:SetPoint("TOPRIGHT", content, "TOPLEFT", 8 + OPTIONS_CONTROL_WIDTH, countY)
    end
    if self.combatBroadcastCountSlider then
        self.combatBroadcastCountSlider:ClearAllPoints()
        self.combatBroadcastCountSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, countY - 18)
    end
    if self.combatBroadcastSendButton then
        self.combatBroadcastSendButton:ClearAllPoints()
        self.combatBroadcastSendButton:SetPoint("TOPLEFT", content, "TOPLEFT", 8, countY - 46)
    end
end

function UI:UpdateCombatDebugStatus()
    if not self.combatDebugLast or not self.combatDebugCount then
        return
    end
    local debug = Goals and Goals.state and Goals.state.combatLogDebug or nil
    if debug and debug.lastEvent and debug.lastEvent ~= "" then
        local status = ""
        if debug.lastAdded then
            status = " | added"
        elseif debug.lastSkip and debug.lastSkip ~= "" then
            status = " | skip: " .. debug.lastSkip
        end
        self.combatDebugLast:SetText(string.format("Last CLEU: %s (src: %s | dest: %s)%s", debug.lastEvent, debug.lastSource or "?", debug.lastDest or "?", status))
    else
        self.combatDebugLast:SetText("Last CLEU: --")
    end
    local count = debug and debug.count or 0
    local logCount = Goals and Goals.state and Goals.state.damageLog and #Goals.state.damageLog or 0
    self.combatDebugCount:SetText(string.format("CLEU events: %d | Log entries: %d", count, logCount))
end

function UI:RefreshDamageTrackerDropdown()
    if not self.damageTrackerDropdown then
        return
    end
    local list = self:GetDamageTrackerDropdownList()
    local selected = self.damageTrackerFilter or COMBAT_SHOW_ALL
    local found = false
    for _, name in ipairs(list) do
        if name == selected then
            found = true
            break
        end
    end
    if not found then
        selected = COMBAT_SHOW_ALL
        self.damageTrackerFilter = selected
    end
    UIDropDownMenu_SetSelectedValue(self.damageTrackerDropdown, selected)
    self:SetDropdownText(self.damageTrackerDropdown, selected)
end

function UI:FormatDamageTrackerEntry(entry)
    if not entry then
        return ""
    end
    local function truncateName(name, maxLen)
        if not name or name == "" then
            return name or ""
        end
        local limit = tonumber(maxLen) or 0
        if limit < 4 then
            return name
        end
        if string.len(name) > limit then
            return string.sub(name, 1, limit - 3) .. "..."
        end
        return name
    end

    local function isPlayerName(name)
        if not name or name == "" then
            return false
        end
        if Goals and Goals.NormalizeName and Goals.DamageTracker and Goals.DamageTracker.rosterNameMap then
            local normalized = Goals:NormalizeName(name)
            return Goals.DamageTracker.rosterNameMap[normalized] and true or false
        end
        if Goals and Goals.GetPlayerName and Goals.NormalizeName then
            return Goals:NormalizeName(name) == Goals:NormalizeName(Goals:GetPlayerName())
        end
        return false
    end

    local function fitName(name)
        if isPlayerName(name) then
            return truncateName(name, DAMAGE_NAME_MAX_PLAYER)
        end
        return truncateName(name, DAMAGE_NAME_MAX_NPC)
    end

    local ts = formatCombatTimestamp(entry.ts)
    local player = entry.player or "Unknown"
    local kind = entry.kind or "DAMAGE"
    local sourceName = ""
    local targetName = ""
    if kind == "DAMAGE" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "THREAT" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "INTERRUPT" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "THREAT_ABILITY" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "DAMAGE_OUT" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "HEAL" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "HEAL_OUT" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "BOSS_HEAL" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "RES" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "DEATH" then
        sourceName = ""
        targetName = player
    end
    sourceName = decorateSelfCombatName(fitName(sourceName))
    targetName = decorateSelfCombatName(fitName(targetName))
    if kind == "DEATH" then
        return string.format("%s | %s | %s | Died |", ts, sourceName, targetName)
    end
    if kind == "THREAT" then
        local reason = entry.reason or "Threat changed"
        return string.format("%s | %s | %s | THREAT | %s", ts, sourceName, targetName, reason)
    end
    if kind == "INTERRUPT" then
        local interruptedText = entry.interruptedSpell or "Interrupted cast"
        local interruptSpell = entry.spell or "Interrupt"
        return string.format("%s | %s | %s | %s | %s", ts, sourceName, targetName, interruptedText, interruptSpell)
    end
    if kind == "THREAT_ABILITY" then
        local reason = entry.reason or "Threat"
        local spellText = entry.spell or "Unknown"
        return string.format("%s | %s | %s | %s | %s", ts, sourceName, targetName, reason, spellText)
    end
    if kind == "BOSS_HEAL" then
        local healAmount = math.floor(tonumber(entry.amount) or 0)
        local healSpell = entry.spell or "Boss heal"
        return string.format("%s | %s | %s | +%d | %s", ts, sourceName, targetName, healAmount, healSpell)
    end
    if kind == "RES" then
        local spell = entry.spell or "Unknown"
        local amount = math.floor(tonumber(entry.amount) or 0)
        if amount > 0 then
            return string.format("%s | %s | %s | Revived +%d | %s", ts, sourceName, targetName, amount, spell)
        end
        return string.format("%s | %s | %s | Revived | %s", ts, sourceName, targetName, spell)
    end
    local amount = math.floor(tonumber(entry.amount) or 0)
    local spell = entry.spell or "Unknown"
    local showOverheal = false
    if kind == "HEAL" then
        local overheal = math.floor(tonumber(entry.overheal) or 0)
        if showOverheal and overheal > 0 then
            return string.format("%s | %s | %s | +%d (%d) | %s", ts, sourceName, targetName, amount, overheal, spell)
        end
        return string.format("%s | %s | %s | +%d | %s", ts, sourceName, targetName, amount, spell)
    end
    if kind == "HEAL_OUT" then
        local overheal = math.floor(tonumber(entry.overheal) or 0)
        if showOverheal and overheal > 0 then
            return string.format("%s | %s | %s | +%d (%d) | %s", ts, sourceName, targetName, amount, overheal, spell)
        end
        return string.format("%s | %s | %s | +%d | %s", ts, sourceName, targetName, amount, spell)
    end
    if kind == "DAMAGE_OUT" then
        return string.format("%s | %s | %s | -%d | %s", ts, sourceName, targetName, amount, spell)
    end
    return string.format("%s | %s | %s | -%d | %s", ts, sourceName, targetName, amount, spell)
end

function UI:GetCombatEntrySourceTarget(entry)
    if not entry then
        return "", ""
    end
    local kind = entry.kind or "DAMAGE"
    if kind == "DAMAGE" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "THREAT" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "INTERRUPT" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "THREAT_ABILITY" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "BOSS_HEAL" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "DAMAGE_OUT" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "HEAL" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "HEAL_OUT" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "RES" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "DEATH" then
        return "", entry.player or "Unknown"
    end
    return entry.source or "Unknown", entry.player or "Unknown"
end

function UI:FormatCombatBroadcastLine(entry)
    if not entry or entry.kind == "BREAK" then
        return nil
    end
    local function short(text)
        if not text or text == "" then
            return ""
        end
        return tostring(text)
    end
    local function raidTag(idx)
        idx = tonumber(idx)
        if not idx or idx < 1 or idx > 8 then
            return nil
        end
        return ("[RT%d]"):format(idx)
    end
    local function actionFor(event)
        local function resourceLabel(ev)
            local rt = ev.resourceType or ev.powerType or ev.resourceName or ev.powerName
            if type(rt) == "number" then
                if rt == 0 then return "Mana" end
                if rt == 1 then return "Rage" end
                if rt == 2 then return "Focus" end
                if rt == 3 then return "Energy" end
                if rt == 6 then return "Runic Power" end
                return "Resource"
            end
            rt = tostring(rt or "")
            if rt == "" then
                local spellText = string.lower(tostring(ev.spellName or ev.spell or ""))
                if string.find(spellText, "mana", 1, true) or string.find(spellText, "life tap", 1, true) then
                    return "Mana"
                end
                return "Resource"
            end
            return rt
        end
        local group = event.eventGroup or ""
        if group == "" then
            local kind = tostring(event.kind or "")
            if kind == "HEAL" or kind == "HEAL_OUT" or kind == "BOSS_HEAL" then group = "heal" end
            if kind == "DAMAGE" or kind == "DAMAGE_OUT" then group = "damage" end
            if kind == "DEATH" then group = "death" end
            if kind == "RES" then group = "control" end
            if kind == "THREAT" or kind == "THREAT_ABILITY" or kind == "INTERRUPT" then group = "control" end
        end
        local subevent = tostring(event.subevent or "")
        local spellText = string.lower(tostring(event.spellName or event.spell or ""))
        if group == "heal" then
            return "healed"
        end
        if group == "damage" then
            return "damaged"
        end
        if group == "aura" then
            if subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REMOVED_DOSE" then
                return "removed aura from"
            end
            if subevent == "SPELL_AURA_REFRESH" then
                return "refreshed aura on"
            end
            if subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_AURA_BROKEN_SPELL" then
                return "broke aura on"
            end
            return "aura'd"
        end
        if group == "miss" then
            return "missed"
        end
        if group == "death" then
            if event.sourceName and event.sourceName ~= "" then
                return "killed"
            end
            return "died"
        end
        if group == "resource" then
            local amount = tonumber(event.effectiveAmount or event.amount) or 0
            if amount < 0 then
                return "spent " .. string.lower(resourceLabel(event))
            end
            return "gained " .. string.lower(resourceLabel(event))
        end
        if group == "control" then
            if string.find(subevent, "INTERRUPT", 1, true) then
                return "interrupted"
            end
            if string.find(spellText, "stun", 1, true) then
                return "stunned"
            end
            if string.find(spellText, "fear", 1, true) or string.find(spellText, "horror", 1, true) then
                return "feared"
            end
            if string.find(spellText, "silence", 1, true) then
                return "silenced"
            end
            if string.find(spellText, "charm", 1, true) or string.find(spellText, "mind control", 1, true) then
                return "charmed"
            end
            if string.find(spellText, "dispel", 1, true) or string.find(subevent, "DISPEL", 1, true) then
                return "dispelled"
            end
            if string.find(spellText, "taunt", 1, true) then
                return "taunted"
            end
            return "controlled"
        end
        return "affected"
    end
    local LIFE_TAP_SPELL_IDS = {
        [1454] = true, [1455] = true, [1456] = true, [11687] = true,
        [11688] = true, [11689] = true, [27222] = true, [57946] = true,
    }
    local function isLifeTap(event, spellLower)
        local sid = tonumber(event.spellId)
        if sid and LIFE_TAP_SPELL_IDS[sid] then
            return true
        end
        return spellLower and string.find(spellLower, "life tap", 1, true) ~= nil
    end
    local function inferGroup(event)
        local group = event.eventGroup or ""
        if group == "" then
            local kind = tostring(event.kind or "")
            if kind == "HEAL" or kind == "HEAL_OUT" or kind == "BOSS_HEAL" then group = "heal" end
            if kind == "DAMAGE" or kind == "DAMAGE_OUT" then group = "damage" end
            if kind == "DEATH" then group = "death" end
            if kind == "THREAT" or kind == "THREAT_ABILITY" or kind == "INTERRUPT" or kind == "RES" then group = "control" end
        end
        return group
    end

    local function resourceLabel(event)
        local rt = event.resourceType or event.powerType or event.resourceName or event.powerName
        if type(rt) == "number" then
            if rt == 0 then return "Mana" end
            if rt == 1 then return "Rage" end
            if rt == 2 then return "Focus" end
            if rt == 3 then return "Energy" end
            if rt == 6 then return "Runic Power" end
            return "Resource"
        end
        rt = short(rt)
        if rt == "" then
            local spellText = string.lower(short(event.spellName or event.spell))
            if string.find(spellText, "mana", 1, true) or string.find(spellText, "life tap", 1, true) then
                return "Mana"
            end
            return "Resource"
        end
        local rtLower = string.lower(rt)
        if rtLower == "0" then
            return "Mana"
        end
        return rt
    end

    local sourceName = decorateSelfCombatName(short(entry.sourceName or entry.source))
    local targetName = decorateSelfCombatName(short(entry.destName or entry.player))
    if sourceName == "" then sourceName = "Unknown" end
    if targetName == "" then targetName = "Unknown" end
    local group = inferGroup(entry)
    local action = actionFor(entry)
    local spell = short(entry.spellName or entry.spell or entry.subevent)
    local where = short((entry.subzone and entry.subzone ~= "" and entry.subzone) or entry.zone)
    if entry.coordsText and entry.coordsText ~= "" then
        where = where ~= "" and (where .. " " .. entry.coordsText) or tostring(entry.coordsText)
    end

    local parts = {}
    local ts = formatCombatTimestamp(entry.timestamp or entry.ts)
    if ts and ts ~= "" then
        parts[#parts + 1] = "[" .. ts .. "]"
    end
    local rt = raidTag(entry.sourceRaidIcon)
    if rt then
        parts[#parts + 1] = rt
    end
    if action == "died" then
        parts[#parts + 1] = targetName
    else
        parts[#parts + 1] = sourceName
    end
    parts[#parts + 1] = action
    if action ~= "died" and group ~= "resource" then
        parts[#parts + 1] = targetName
    end
    if spell ~= "" then
        parts[#parts + 1] = "with"
        parts[#parts + 1] = spell
    end

    local effective = tonumber(entry.effectiveAmount or entry.amount)
    local raw = tonumber(entry.rawAmount or entry.amount)
    local over = tonumber(entry.overheal) or 0
    local resist = tonumber(entry.resisted) or 0
    local overkill = tonumber(entry.overkill) or 0
    local blocked = tonumber(entry.blocked) or 0
    local absorbed = tonumber(entry.absorbed) or 0
    if effective and group ~= "aura" and group ~= "death" then
        parts[#parts + 1] = "for"
        if entry.isCombinedOverTime and (group == "heal" or group == "damage") then
            local total = tonumber(entry.combinedTotal or effective) or 0
            local rawTotal = tonumber(entry.combinedRawTotal or entry.rawAmount or entry.amount) or total
            local duration = math.max(0.1, tonumber(entry.combinedDuration) or 0.1)
            local ticks = math.max(1, math.floor((tonumber(entry.combinedTicks) or 1) + 0.5))
            local rate = tonumber(entry.combinedRate) or (total / duration)
            local oh = tonumber(entry.combinedOverheal or entry.overheal) or 0
            local ok = tonumber(entry.combinedOverkill or entry.overkill) or 0
            local rs = tonumber(entry.combinedResisted or entry.resisted) or 0
            local bl = tonumber(entry.combinedBlocked or entry.blocked) or 0
            local ab = tonumber(entry.combinedAbsorbed or entry.absorbed) or 0
            local prevented = (group == "heal") and oh or (ok + rs + bl + ab)
            parts[#parts + 1] = tostring(math.floor(total + 0.5))
            parts[#parts + 1] = "(" .. tostring(math.floor(prevented + 0.5)) .. ")"
            parts[#parts + 1] = "over"
            parts[#parts + 1] = tostring(math.floor(duration + 0.5)) .. "s,"
            parts[#parts + 1] = tostring(ticks) .. " ticks."
            parts[#parts + 1] = tostring(math.floor(rate + 0.5))
            parts[#parts + 1] = "(" .. tostring(math.floor((prevented / duration) + 0.5)) .. ")"
            parts[#parts + 1] = "/s"
            if rawTotal > 0 then
                parts[#parts + 1] = "[" .. tostring(math.floor(rawTotal + 0.5)) .. "]"
            end
        elseif group == "resource" then
            local resource = string.lower(resourceLabel(entry))
            local resourceShort = (resource == "mana") and "MP" or resource
            local spellLower = string.lower(spell or "")
            local healthLost = tonumber(entry.healthLost or entry.healthCost or entry.lifeCost or entry.hpCost or entry.selfDamage) or 0
            if healthLost <= 0 and isLifeTap(entry, spellLower) then
                healthLost = tonumber(entry.extraAmount) or 0
            end
            if isLifeTap(entry, spellLower) and healthLost > 0 and effective > 0 then
                parts[#parts + 1] = "-" .. tostring(math.floor(healthLost)) .. " HP"
                parts[#parts + 1] = "+" .. tostring(math.floor(effective)) .. " " .. resourceShort
            else
                local sign = effective >= 0 and "+" or ""
                parts[#parts + 1] = sign .. tostring(math.floor(effective)) .. " " .. resourceShort
            end
        else
            parts[#parts + 1] = tostring(math.floor(effective))
        end
        if group == "heal" and over > 0 then
            parts[#parts + 1] = "(" .. tostring(math.floor(over)) .. ")"
        elseif group == "damage" then
            if resist > 0 then
                parts[#parts + 1] = "(" .. tostring(math.floor(resist)) .. ")"
            end
            if overkill > 0 then
                parts[#parts + 1] = "(" .. tostring(math.floor(overkill)) .. ")"
            end
        end
    elseif entry.missType and entry.missType ~= "" then
        parts[#parts + 1] = "for"
        parts[#parts + 1] = tostring(entry.missType)
    end
    if (not entry.isCombinedOverTime) and group ~= "heal" and group ~= "damage" then
        local mods = {}
        if over > 0 then mods[#mods + 1] = "OH " .. tostring(math.floor(over)) end
        if resist > 0 then mods[#mods + 1] = "Resist " .. tostring(math.floor(resist)) end
        if overkill > 0 then mods[#mods + 1] = "OK " .. tostring(math.floor(overkill)) end
        if blocked > 0 then mods[#mods + 1] = "Block " .. tostring(math.floor(blocked)) end
        if absorbed > 0 then mods[#mods + 1] = "Absorb " .. tostring(math.floor(absorbed)) end
        if #mods > 0 then
            parts[#parts + 1] = "(" .. table.concat(mods, ", ") .. ")"
        end
    end
    if (not entry.isCombinedOverTime) and raw then
        parts[#parts + 1] = "[" .. tostring(math.floor(raw)) .. "]"
    end
    if where ~= "" then
        parts[#parts + 1] = "@"
        parts[#parts + 1] = where
    end
    return table.concat(parts, " ")
end

function UI:SendCombatChatLine(line, channel, target)
    if not line or line == "" then
        return
    end
    if not SendChatMessage then
        return
    end
    -- WoW chat parser treats "|" as an escape prefix; literal pipes must be doubled.
    line = tostring(line):gsub("|", "||")
    if channel == "WHISPER" then
        if target and target ~= "" then
            SendChatMessage(line, "WHISPER", nil, target)
        end
        return
    end
    SendChatMessage(line, channel)
end

function UI:SendCombatBroadcastLines(channel, target, count)
    local tracker = Goals and Goals.DamageTracker
    if not tracker or not tracker.GetFilteredEntries then
        return
    end
    local filter = self.damageTrackerFilter or COMBAT_SHOW_ALL
    local data = {}
    if tracker == (Goals and Goals.CombatProvider) then
        data = tracker:GetFilteredEntries({ disableCombine = true }) or {}
    else
        data = tracker:GetFilteredEntries(filter) or {}
    end
    local limit = tonumber(count) or 0
    if limit < 0 then
        limit = 0
    end
    local lines = {}
    for _, entry in ipairs(data) do
        if entry and entry.kind ~= "BREAK" then
            local line = self:FormatCombatBroadcastLine(entry)
            if line and line ~= "" then
                table.insert(lines, line)
                if limit > 0 and #lines >= limit then
                    break
                end
            end
        end
    end
    for i = #lines, 1, -1 do
        self:SendCombatChatLine(lines[i], channel, target)
    end
end

function UI:UpdateDamageTrackerList()
    if not self.damageTrackerScroll or not self.damageTrackerRows then
        return
    end
    if self.ApplyCombatTheme then
        self:ApplyCombatTheme()
    end
    local provider = Goals and Goals.CombatProvider or nil
    local available = provider and provider.IsAvailable and provider:IsAvailable()
    if self.combatUnavailableLabel then
        setShown(self.combatUnavailableLabel, not available)
    end
    if self.combatRetryButton then
        setShown(self.combatRetryButton, not available)
    end

    local data = {}
    if available and provider.GetFilteredEntries then
        data = provider:GetFilteredEntries() or {}
    end
    local offset = FauxScrollFrame_GetOffset(self.damageTrackerScroll) or 0
    FauxScrollFrame_Update(self.damageTrackerScroll, #data, DAMAGE_ROWS, DAMAGE_ROW_HEIGHT)
    local contentHeight = #data * DAMAGE_ROW_HEIGHT
    self.damageTrackerScroll._contentHeight = contentHeight
    setScrollBarAlwaysVisible(self.damageTrackerScroll, contentHeight)
    local displayStyle = self:GetCombatDisplayStyle()
    local chatStyle = displayStyle == COMBAT_DISPLAY_CHAT
    if self.UpdateCombatDynamicSizing then
        self:UpdateCombatDynamicSizing(data, displayStyle)
    end
    local softRowsEnabled = not (Goals and Goals.db and Goals.db.settings and Goals.db.settings.combatWhtmSoftRowColors == false)
    local rowBgStyle = self:GetCombatRowBgStyle()
    local selectedEntry = self.combatTooltipLocked and self.combatTooltipEntry or nil
    local selectedEntryKey = self.combatTooltipLocked and self.combatTooltipEntryKey or nil
    local selectedVisible = false
    local selectedCurrentEvent = nil

    local function iconTag(idx)
        idx = tonumber(idx)
        if not idx or idx < 1 or idx > 8 then
            return ""
        end
        return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(idx)
    end

    local function short(text)
        if not text or text == "" then
            return ""
        end
        return text
    end

    local function groupType(event)
        if event.eventGroup == "aura" then
            return "Aura"
        end
        if event.eventGroup == "heal" then
            return "Heal"
        end
        if event.eventGroup == "damage" then
            return "Damage"
        end
        if event.eventGroup == "death" then
            return "Death"
        end
        if event.eventGroup == "miss" then
            return "Miss"
        end
        if event.eventGroup == "control" then
            local subevent = string.upper(tostring(event.subevent or ""))
            local spellText = string.lower(tostring(event.spellName or event.spell or ""))
            if string.find(subevent, "RESURRECT", 1, true)
                or string.find(spellText, "resurrect", 1, true)
                or string.find(spellText, "revive", 1, true) then
                return "Revive"
            end
            if string.find(subevent, "INTERRUPT", 1, true) then
                return "Interrupt"
            end
            if string.find(subevent, "DISPEL", 1, true)
                or string.find(subevent, "STOLEN", 1, true)
                or string.find(spellText, "dispel", 1, true) then
                return "Dispel"
            end
            if string.find(spellText, "taunt", 1, true) then
                return "Taunt"
            end
            if string.find(spellText, "fear", 1, true) or string.find(spellText, "horror", 1, true) then
                return "Fear"
            end
            if string.find(spellText, "stun", 1, true) then
                return "Stun"
            end
            if string.find(spellText, "silence", 1, true) then
                return "Silence"
            end
            if string.find(spellText, "charm", 1, true) or string.find(spellText, "mind control", 1, true) then
                return "Charm"
            end
            if string.find(spellText, "root", 1, true)
                or string.find(spellText, "snare", 1, true)
                or string.find(spellText, "freeze", 1, true)
                or string.find(spellText, "frost nova", 1, true)
                or string.find(spellText, "entangling", 1, true) then
                return "Root"
            end
            if string.find(spellText, "polymorph", 1, true) or string.find(spellText, "sap", 1, true) then
                return "CC"
            end
            if string.find(spellText, "banish", 1, true) then
                return "CC"
            end
            return "Control"
        end
        if event.eventGroup == "resource" then
            return "Resource"
        end
        return "Event"
    end

    local function auraAction(event)
        if event.subevent == "SPELL_AURA_APPLIED" then return "Applied" end
        if event.subevent == "SPELL_AURA_REMOVED" then return "Lost" end
        if event.subevent == "SPELL_AURA_REFRESH" then return "Refreshed" end
        if event.subevent == "SPELL_AURA_APPLIED_DOSE" then return "Stacked" end
        if event.subevent == "SPELL_AURA_REMOVED_DOSE" then return "Unstacked" end
        if event.subevent == "SPELL_AURA_BROKEN" or event.subevent == "SPELL_AURA_BROKEN_SPELL" then return "Broken" end
        return "Changed"
    end

    local function formatCombinedDuration(seconds)
        local s = tonumber(seconds) or 0
        if s < 0.1 then
            s = 0.1
        end
        local rounded = math.floor((s * 10) + 0.5) / 10
        local text = tostring(rounded)
        text = string.gsub(text, "%.0$", "")
        return text
    end

    local function detailAndTotal(event)
        local function colorWrap(text, r, g, b)
            return string.format("|cff%02x%02x%02x%s|r", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255, tostring(text or ""))
        end
        local LIFE_TAP_SPELL_IDS = {
            [1454] = true, [1455] = true, [1456] = true, [11687] = true,
            [11688] = true, [11689] = true, [27222] = true, [57946] = true,
        }
        local function isLifeTap(event, spellLower)
            local sid = tonumber(event.spellId)
            if sid and LIFE_TAP_SPELL_IDS[sid] then
                return true
            end
            return spellLower and string.find(spellLower, "life tap", 1, true) ~= nil
        end
        local clr = {
            damage = { 1.00, 0.30, 0.30 },
            heal = { 0.30, 1.00, 0.30 },
            overheal = { 0.00, 0.70, 0.20 },
            overkill = { 0.50, 0.02, 0.02 },
            resist = { 0.68, 0.10, 0.10 },
            blocked = { 0.80, 0.74, 0.46 },
            absorbed = { 0.60, 0.74, 0.98 },
        }
        if event.isCombinedOverTime then
            local total = tonumber(event.combinedTotal or event.effectiveAmount or event.amount) or 0
            local duration = tonumber(event.combinedDuration) or 0.1
            local rate = tonumber(event.combinedRate)
            if not rate then
                rate = total / math.max(duration, 0.1)
            end
            local rateDen = math.max(duration, 0.1)
            local detailColor = (event.eventGroup == "heal") and clr.heal or clr.damage
            local oh = tonumber(event.combinedOverheal or event.overheal) or 0
            local ok = tonumber(event.combinedOverkill or event.overkill) or 0
            local rs = tonumber(event.combinedResisted or event.resisted) or 0
            local bl = tonumber(event.combinedBlocked or event.blocked) or 0
            local ab = tonumber(event.combinedAbsorbed or event.absorbed) or 0
            local prevented = (event.eventGroup == "heal") and oh or (ok + rs + bl + ab)
            local rateText = tostring(math.floor(rate + 0.5))
            local preventedRateText = tostring(math.floor((prevented / rateDen) + 0.5))
            local innerColor = (event.eventGroup == "heal") and clr.overheal or clr.resist
            local detail = colorWrap(rateText, detailColor[1], detailColor[2], detailColor[3])
                .. " "
                .. colorWrap("(" .. preventedRateText .. ")", innerColor[1], innerColor[2], innerColor[3])
                .. " "
                .. colorWrap("/s", 0.85, 0.88, 0.92)
            local totalText = colorWrap(tostring(math.floor(total + 0.5)), detailColor[1], detailColor[2], detailColor[3])
                .. " "
                .. colorWrap("( " .. tostring(math.floor(prevented + 0.5)) .. " )", innerColor[1], innerColor[2], innerColor[3])
                .. " "
                .. colorWrap("/" .. formatCombinedDuration(duration) .. "s", 0.85, 0.88, 0.92)
            return detail, totalText
        end
        if event.eventGroup == "aura" then
            local detail = (event.auraType == "BUFF" and "Buff") or (event.auraType == "DEBUFF" and "Debuff") or "Aura"
            return detail, auraAction(event)
        end
        if event.amount then
            local effective = tonumber(event.effectiveAmount or event.amount) or 0
            local detail = tostring(effective)
            if event.eventGroup == "resource" then
                local spellLower = string.lower(tostring(event.spellName or event.spell or ""))
                local resourceName = tostring(event.resourceName or event.powerName or event.powerType or "Resource")
                if tonumber(event.powerType) == 0 then
                    resourceName = "Mana"
                end
                local resourceShort = (string.lower(tostring(resourceName)) == "mana") and "MP" or string.lower(tostring(resourceName))
                local healthLost = tonumber(event.healthLost or event.healthCost or event.lifeCost or event.hpCost or event.selfDamage)
                if (not healthLost or healthLost <= 0) and isLifeTap(event, spellLower) then
                    healthLost = tonumber(event.extraAmount)
                end
                local totalText = colorWrap("+" .. tostring(math.floor(effective)) .. " " .. resourceShort, 0.36, 0.62, 0.95)
                if healthLost and healthLost > 0 and effective > 0 then
                    detail = colorWrap("-" .. tostring(math.floor(healthLost)) .. " HP", 1.00, 0.35, 0.35)
                else
                    detail = "-"
                end
                return detail, totalText
            end
            if event.eventGroup == "heal" then
                detail = colorWrap(detail, clr.heal[1], clr.heal[2], clr.heal[3])
                if event.overheal then
                    detail = detail .. " " .. colorWrap("(" .. tostring(event.overheal) .. ")", clr.overheal[1], clr.overheal[2], clr.overheal[3])
                end
            else
                if event.eventGroup == "damage" then
                    if event.overkill then
                        detail = colorWrap(detail, clr.overkill[1], clr.overkill[2], clr.overkill[3])
                    elseif event.resisted then
                        detail = colorWrap(detail, clr.resist[1], clr.resist[2], clr.resist[3])
                    else
                        detail = colorWrap(detail, clr.damage[1], clr.damage[2], clr.damage[3])
                    end
                end
                local mods = {}
                if event.resisted then
                    mods[#mods + 1] = colorWrap("R " .. tostring(event.resisted), clr.resist[1], clr.resist[2], clr.resist[3])
                end
                if event.overkill then
                    mods[#mods + 1] = colorWrap("OK " .. tostring(event.overkill), clr.overkill[1], clr.overkill[2], clr.overkill[3])
                end
                if event.blocked then
                    mods[#mods + 1] = colorWrap("B " .. tostring(event.blocked), clr.blocked[1], clr.blocked[2], clr.blocked[3])
                end
                if event.absorbed then
                    mods[#mods + 1] = colorWrap("A " .. tostring(event.absorbed), clr.absorbed[1], clr.absorbed[2], clr.absorbed[3])
                end
                if #mods > 0 then
                    detail = detail .. " (" .. table.concat(mods, " ") .. ")"
                end
            end
            return detail, tostring(event.rawAmount or event.amount)
        end
        if event.eventText and event.eventText ~= "" then
            return event.eventText, "-"
        end
        return short(event.missType), "-"
    end

    local function colorForGroup(group)
        if group == "heal" then
            return 0.26, 0.95, 0.42
        end
        if group == "damage" then
            return 0.95, 0.30, 0.30
        end
        if group == "aura" then
            return 0.96, 0.82, 0.34
        end
        if group == "death" then
            return 0.86, 0.42, 0.92
        end
        if group == "control" then
            return 0.44, 0.74, 0.98
        end
        if group == "resource" then
            return 0.34, 0.64, 0.96
        end
        if group == "miss" then
            return 0.86, 0.86, 0.86
        end
        return 1, 1, 1
    end

    local function colorForType(event)
        local group = event and event.eventGroup or nil
        if group ~= "control" then
            return colorForGroup(group)
        end
        local typeText = groupType(event)
        if typeText == "Revive" then
            return 0.64, 1.00, 0.74
        end
        if typeText == "Interrupt" then
            return 1.00, 0.60, 0.30
        end
        if typeText == "Dispel" then
            return 0.54, 0.84, 1.00
        end
        if typeText == "Taunt" then
            return 0.95, 0.78, 0.34
        end
        if typeText == "CC" then
            return 0.70, 0.62, 0.98
        end
        if typeText == "Fear" then
            return 0.88, 0.56, 0.98
        end
        if typeText == "Stun" then
            return 0.98, 0.66, 0.36
        end
        if typeText == "Silence" then
            return 0.66, 0.84, 0.98
        end
        if typeText == "Charm" then
            return 0.98, 0.58, 0.82
        end
        if typeText == "Root" then
            return 0.66, 0.90, 0.72
        end
        return 0.44, 0.74, 0.98
    end

    local function colorForTier(tier)
        if tier == "junk" then
            return 0.62, 0.62, 0.62
        end
        if tier == "normal" then
            return 0.95, 0.95, 0.95
        end
        if tier == "elite" then
            return 1.0, 0.3, 0.3
        end
        if tier == "boss" then
            return 1.0, 0.5, 0.0
        end
        return nil
    end

    local function colorForClass(classFile)
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local c = RAID_CLASS_COLORS[classFile]
            return c.r, c.g, c.b
        end
        return nil
    end

    local function colorForUnit(event, isSource)
        local name = isSource and event.sourceName or event.destName
        local classFile = isSource and event.sourceClass or event.destClass
        if Goals and Goals.GetPlayerColor and name and name ~= "" then
            local pr, pg, pb = Goals:GetPlayerColor(name)
            if pr and pg and pb then
                return pr, pg, pb
            end
        end
        local tier = isSource and event.sourceTier or event.destTier
        local tr, tg, tb = colorForTier(tier)
        if tr then
            return tr, tg, tb
        end
        local cr, cg, cb = colorForClass(classFile)
        if cr then
            return cr, cg, cb
        end
        return 0.95, 0.95, 0.95
    end

    local function colorForAbility(event)
        if event.eventGroup == "heal" then
            if event.overheal then
                return 0.00, 0.70, 0.20
            end
            return 0.30, 1.00, 0.30
        end
        if event.eventGroup == "damage" then
            if event.overkill then
                return 0.50, 0.02, 0.02
            end
            if event.resisted then
                return 0.68, 0.10, 0.10
            end
            return 1.00, 0.30, 0.30
        end
        if event.eventGroup == "aura" then
            return 1.00, 0.88, 0.35
        end
        if event.eventGroup == "control" then
            return 0.35, 0.70, 1.00
        end
        if event.eventGroup == "resource" then
            return 0.36, 0.62, 0.95
        end
        return 0.90, 0.90, 0.90
    end

    local function colorWrap(text, rr, gg, bb)
        if not text or text == "" then
            return ""
        end
        return string.format("|cff%02x%02x%02x%s|r", (rr or 1) * 255, (gg or 1) * 255, (bb or 1) * 255, tostring(text))
    end

    local function resourceLabel(event)
        local rt = event.resourceType or event.powerType or event.resourceName or event.powerName
        if type(rt) == "number" then
            if rt == 0 then return "Mana" end
            if rt == 1 then return "Rage" end
            if rt == 2 then return "Focus" end
            if rt == 3 then return "Energy" end
            if rt == 6 then return "Runic Power" end
            return "Resource"
        end
        rt = short(rt)
        if rt == "" then
            local spellText = string.lower(short(event.spellName or event.spell))
            if string.find(spellText, "mana", 1, true) or string.find(spellText, "life tap", 1, true) then
                return "Mana"
            end
            return "Resource"
        end
        local rtLower = string.lower(rt)
        if rtLower == "0" then
            return "Mana"
        end
        return rt
    end

    local function chatActionVerb(event)
        local subevent = tostring(event.subevent or "")
        local spellText = string.lower(tostring(event.spellName or ""))
        if event.eventGroup == "heal" then
            return "healed"
        end
        if event.eventGroup == "damage" then
            return "damaged"
        end
        if event.eventGroup == "aura" then
            if subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REMOVED_DOSE" then
                return "removed aura from"
            end
            if subevent == "SPELL_AURA_REFRESH" then
                return "refreshed aura on"
            end
            if subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_AURA_BROKEN_SPELL" then
                return "broke aura on"
            end
            return "aura'd"
        end
        if event.eventGroup == "miss" then
            return "missed"
        end
        if event.eventGroup == "death" then
            if event.sourceName and event.sourceName ~= "" then
                return "killed"
            end
            return "died"
        end
        if event.eventGroup == "resource" then
            local amount = tonumber(event.effectiveAmount or event.amount) or 0
            if amount < 0 then
                return "spent " .. string.lower(resourceLabel(event))
            end
            return "gained " .. string.lower(resourceLabel(event))
        end
        if event.eventGroup == "control" then
            if string.find(subevent, "INTERRUPT", 1, true) then
                return "interrupted"
            end
            if string.find(spellText, "stun", 1, true) then
                return "stunned"
            end
            if string.find(spellText, "fear", 1, true) or string.find(spellText, "horror", 1, true) then
                return "feared"
            end
            if string.find(spellText, "silence", 1, true) then
                return "silenced"
            end
            if string.find(spellText, "charm", 1, true) or string.find(spellText, "mind control", 1, true) then
                return "charmed"
            end
            if string.find(spellText, "dispel", 1, true) or string.find(subevent, "DISPEL", 1, true) then
                return "dispelled"
            end
            if string.find(spellText, "taunt", 1, true) then
                return "taunted"
            end
            return "controlled"
        end
        return "affected"
    end

    local function buildChatLine(event, src, dst, where, r, g, b, sr, sg, sb, tr, tg, tb, ar, ag, ab)
        local parts = {}
        local LIFE_TAP_SPELL_IDS = {
            [1454] = true, [1455] = true, [1456] = true, [11687] = true,
            [11688] = true, [11689] = true, [27222] = true, [57946] = true,
        }
        local function isLifeTap(event, spellLower)
            local sid = tonumber(event.spellId)
            if sid and LIFE_TAP_SPELL_IDS[sid] then
                return true
            end
            return spellLower and string.find(spellLower, "life tap", 1, true) ~= nil
        end
        local action = chatActionVerb(event)
        local ts = formatCombatTimestamp(event.timestamp or event.ts)
        if ts and ts ~= "" then
            parts[#parts + 1] = ts
        end
        local rt = iconTag(event.sourceRaidIcon)
        if rt and rt ~= "" then
            parts[#parts + 1] = rt
        end
        local sourceText = src ~= "" and src or "Unknown"
        local targetText = dst ~= "" and dst or "Unknown"
        if action == "died" then
            parts[#parts + 1] = colorWrap(targetText, tr, tg, tb)
        elseif event.eventGroup == "resource" then
            parts[#parts + 1] = colorWrap(sourceText, sr, sg, sb)
        else
            parts[#parts + 1] = colorWrap(sourceText, sr, sg, sb)
        end
        parts[#parts + 1] = colorWrap(action, r, g, b)
        if action ~= "died" and event.eventGroup ~= "resource" then
            parts[#parts + 1] = colorWrap(targetText, tr, tg, tb)
        end

        local spellText = short(event.spellName or event.subevent)
        if spellText ~= "" then
            parts[#parts + 1] = "with"
            parts[#parts + 1] = colorWrap(spellText, ar, ag, ab)
        end

        local effective = tonumber(event.effectiveAmount or event.amount)
        local raw = tonumber(event.rawAmount or event.amount)
        if effective and event.eventGroup ~= "aura" and event.eventGroup ~= "death" then
            parts[#parts + 1] = "for"
            if event.isCombinedOverTime then
                local total = tonumber(event.combinedTotal or effective) or 0
                local rawTotal = tonumber(event.combinedRawTotal or event.rawAmount or event.amount) or total
                local duration = tonumber(event.combinedDuration) or 0.1
                local ticks = math.max(1, math.floor((tonumber(event.combinedTicks) or 1) + 0.5))
                local rate = tonumber(event.combinedRate)
                if not rate then
                    rate = total / math.max(duration, 0.1)
                end
                local rateDen = math.max(duration, 0.1)
                local rr, rg, rb = 1.00, 0.30, 0.30
                if event.eventGroup == "heal" then
                    rr, rg, rb = 0.30, 1.00, 0.30
                end
                local oh = tonumber(event.combinedOverheal or event.overheal) or 0
                local ok = tonumber(event.combinedOverkill or event.overkill) or 0
                local rs = tonumber(event.combinedResisted or event.resisted) or 0
                local bl = tonumber(event.combinedBlocked or event.blocked) or 0
                local ab = tonumber(event.combinedAbsorbed or event.absorbed) or 0
                local prevented = (event.eventGroup == "heal") and oh or (ok + rs + bl + ab)
                local innerR, innerG, innerB = 0.68, 0.10, 0.10
                if event.eventGroup == "heal" then
                    innerR, innerG, innerB = 0.00, 0.70, 0.20
                end
                parts[#parts + 1] = colorWrap(tostring(math.floor(total + 0.5)), rr, rg, rb)
                parts[#parts + 1] = colorWrap("(" .. tostring(math.floor(prevented + 0.5)) .. ")", innerR, innerG, innerB)
                parts[#parts + 1] = "over"
                parts[#parts + 1] = colorWrap(formatCombinedDuration(duration) .. "s, " .. tostring(ticks) .. " ticks.", 0.80, 0.84, 0.90)
                parts[#parts + 1] = colorWrap(tostring(math.floor(rate + 0.5)), rr, rg, rb)
                parts[#parts + 1] = colorWrap("(" .. tostring(math.floor((prevented / rateDen) + 0.5)) .. ")", innerR, innerG, innerB)
                parts[#parts + 1] = colorWrap("/s", 0.85, 0.88, 0.92)
                if rawTotal > 0 then
                    parts[#parts + 1] = colorWrap("[" .. tostring(math.floor(rawTotal + 0.5)) .. "]", 0.70, 0.74, 0.80)
                end
            elseif event.eventGroup == "heal" then
                parts[#parts + 1] = colorWrap(tostring(math.floor(effective)), 0.30, 1.00, 0.30)
                local oh = tonumber(event.overheal) or 0
                if oh > 0 then
                    parts[#parts + 1] = colorWrap("(" .. tostring(math.floor(oh)) .. ")", 0.00, 0.70, 0.20)
                end
            elseif event.eventGroup == "damage" then
                parts[#parts + 1] = colorWrap(tostring(math.floor(effective)), 1.00, 0.30, 0.30)
                local resisted = tonumber(event.resisted) or 0
                local overkill = tonumber(event.overkill) or 0
                if resisted > 0 then
                    parts[#parts + 1] = colorWrap("(" .. tostring(math.floor(resisted)) .. ")", 0.68, 0.10, 0.10)
                end
                if overkill > 0 then
                    parts[#parts + 1] = colorWrap("(" .. tostring(math.floor(overkill)) .. ")", 0.50, 0.02, 0.02)
                end
            elseif event.eventGroup == "resource" then
                local resource = string.lower(resourceLabel(event))
                local resourceShort = (resource == "mana") and "MP" or resource
                local spellLower = string.lower(spellText or "")
                local healthLost = tonumber(event.healthLost or event.healthCost or event.lifeCost or event.hpCost or event.selfDamage) or 0
                if healthLost <= 0 and isLifeTap(event, spellLower) then
                    healthLost = tonumber(event.extraAmount) or 0
                end
                local manaBlue = {0.36, 0.62, 0.95}
                local manaBlueDark = {0.22, 0.45, 0.78}
                if isLifeTap(event, spellLower) and healthLost > 0 and effective > 0 then
                    parts[#parts + 1] = colorWrap("-" .. tostring(math.floor(healthLost)) .. " HP", 1.00, 0.35, 0.35)
                    parts[#parts + 1] = colorWrap("+" .. tostring(math.floor(effective)) .. " " .. resourceShort, manaBlue[1], manaBlue[2], manaBlue[3])
                else
                    local sign = effective >= 0 and "+" or ""
                    parts[#parts + 1] = colorWrap(sign .. tostring(math.floor(effective)), manaBlue[1], manaBlue[2], manaBlue[3])
                    parts[#parts + 1] = colorWrap(resourceShort, manaBlueDark[1], manaBlueDark[2], manaBlueDark[3])
                end
            else
                parts[#parts + 1] = colorWrap(tostring(math.floor(effective)), ar, ag, ab)
            end
        elseif event.missType and event.missType ~= "" then
            parts[#parts + 1] = "for"
            parts[#parts + 1] = colorWrap(event.missType, ar, ag, ab)
        end

        local mods = {}
        local overheal = tonumber(event.overheal) or 0
        local overkill = tonumber(event.overkill) or 0
        local resisted = tonumber(event.resisted) or 0
        local blocked = tonumber(event.blocked) or 0
        local absorbed = tonumber(event.absorbed) or 0
        if event.eventGroup ~= "heal" and overheal > 0 then
            mods[#mods + 1] = "OH " .. tostring(math.floor(overheal))
        end
        if event.eventGroup ~= "damage" and overkill > 0 then
            mods[#mods + 1] = "OK " .. tostring(math.floor(overkill))
        end
        if event.eventGroup ~= "damage" and resisted > 0 then
            mods[#mods + 1] = "Resist " .. tostring(math.floor(resisted))
        end
        if blocked > 0 then
            mods[#mods + 1] = "Block " .. tostring(math.floor(blocked))
        end
        if absorbed > 0 then
            mods[#mods + 1] = "Absorb " .. tostring(math.floor(absorbed))
        end
        if (not event.isCombinedOverTime) and #mods > 0 then
            parts[#parts + 1] = colorWrap("(" .. table.concat(mods, ", ") .. ")", 0.80, 0.84, 0.90)
        end
        if (not event.isCombinedOverTime) and raw then
            parts[#parts + 1] = colorWrap("[" .. tostring(math.floor(raw)) .. "]", 0.70, 0.74, 0.80)
        end
        if where and where ~= "" then
            parts[#parts + 1] = colorWrap("@ " .. where, 0.80, 0.90, 1.00)
        end

        return table.concat(parts, " ")
    end

    for i = 1, DAMAGE_ROWS do
        local row = self.damageTrackerRows[i]
        local event = data[offset + i]
        if event then
            row:Show()
            row.entry = event
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end

            local detail, total = detailAndTotal(event)
            local where = short((event.subzone and event.subzone ~= "" and event.subzone) or event.zone)
            if event.coordsText and event.coordsText ~= "" then
                where = where .. " " .. event.coordsText
            end
            local r, g, b = colorForGroup(event.eventGroup)
            local trr, tgg, tbb = colorForType(event)
            local sr, sg, sb = colorForUnit(event, true)
            local tr, tg, tb = colorForUnit(event, false)
            local ar, ag, ab = colorForAbility(event)

            local src = short(decorateSelfCombatName(event.sourceName))
            local dst = short(decorateSelfCombatName(event.destName))
            row.cols.time:SetText(formatCombatTimestamp(event.timestamp or event.ts))
            row.cols.icon:SetText(iconTag(event.sourceRaidIcon))
            if chatStyle then
                local summary = buildChatLine(event, src, dst, where, r, g, b, sr, sg, sb, tr, tg, tb, ar, ag, ab)
                row.cols.time:SetText("")
                row.cols.icon:SetText("")
                row.cols.source:SetText("")
                row.cols.target:SetText("")
                row.cols.ability:SetText("")
                row.cols.type:SetText("")
                row.cols.detail:SetText("")
                row.cols.total:SetText("")
                row.cols.where:SetText(summary or "")

                row.cols.time:SetTextColor(1, 1, 1)
                row.cols.icon:SetTextColor(1, 1, 1)
                row.cols.source:SetTextColor(1, 1, 1)
                row.cols.target:SetTextColor(1, 1, 1)
                row.cols.ability:SetTextColor(1, 1, 1)
                row.cols.type:SetTextColor(1, 1, 1)
                row.cols.detail:SetTextColor(1, 1, 1)
                row.cols.total:SetTextColor(1, 1, 1)
                row.cols.where:SetTextColor(1, 1, 1)
            else
                row.cols.source:SetText(src)
                row.cols.target:SetText(dst)
                row.cols.ability:SetText(short(event.spellName or event.subevent))
                row.cols.type:SetText(groupType(event))
                row.cols.detail:SetText(detail or "")
                row.cols.total:SetText(total or "")
                row.cols.where:SetText(where or "")

                row.cols.type:SetTextColor(trr, tgg, tbb)
                row.cols.total:SetTextColor(ar, ag, ab)
                row.cols.time:SetTextColor(1, 1, 1)
                row.cols.icon:SetTextColor(1, 1, 1)
                row.cols.source:SetTextColor(sr, sg, sb)
                row.cols.target:SetTextColor(tr, tg, tb)
                row.cols.ability:SetTextColor(ar, ag, ab)
                row.cols.detail:SetTextColor(1, 1, 1)
                row.cols.where:SetTextColor(0.8, 0.9, 1)
            end

            if row.softTint then
                if softRowsEnabled then
                    if rowBgStyle == COMBAT_ROW_BG_NEUTRAL then
                        local odd = ((offset + i) % 2) == 1
                        if odd then
                            row.softTint:SetTexture(0.64, 0.66, 0.70, 0.12)
                        else
                            row.softTint:SetTexture(0.18, 0.20, 0.24, 0.20)
                        end
                    else
                        row.softTint:SetTexture(r, g, b, 0.08)
                    end
                else
                    row.softTint:SetTexture(0, 0, 0, 0)
                end
            end
            if row.selectedTint then
                local eventKey = combatEventKey(event)
                local isSelected = false
                if selectedEntryKey and eventKey and selectedEntryKey == eventKey then
                    isSelected = true
                elseif selectedEntry and selectedEntry == event then
                    isSelected = true
                end
                setShown(row.selectedTint, isSelected)
                if isSelected then
                    selectedVisible = true
                    selectedCurrentEvent = event
                end
            end
        else
            row:Hide()
            row.entry = nil
            if row.softTint then
                row.softTint:SetTexture(0, 0, 0, 0)
            end
            if row.selectedTint then
                row.selectedTint:Hide()
            end
        end
    end
    if (selectedEntry or selectedEntryKey) and self.combatTooltipLocked then
        if selectedVisible then
            self.combatTooltipEntry = selectedCurrentEvent
            self.combatTooltipEntryKey = combatEventKey(selectedCurrentEvent)
            showCombatRowTooltip(selectedCurrentEvent)
        else
            hideCombatRowTooltip()
        end
    end
end
