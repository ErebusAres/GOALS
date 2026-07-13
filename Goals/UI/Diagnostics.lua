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
local createLabel = H.createLabel
function UI:CreateDiagnosticsTab(page)
    local listInset = CreateFrame("Frame", "GoalsDiagnosticsListInset", page, "GoalsInsetTemplate")
    applyInsetTheme(listInset)
    listInset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    listInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    listInset:SetWidth(360)

    local detailInset = CreateFrame("Frame", "GoalsDiagnosticsDetailInset", page, "GoalsInsetTemplate")
    applyInsetTheme(detailInset)
    detailInset:SetPoint("TOPLEFT", listInset, "TOPRIGHT", 10, 0)
    detailInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)

    local listTitle = createLabel(listInset, "Recent API decisions", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listInset, "TOPLEFT", 10, -10)
    local help = createLabel(listInset, "Canonical event names with plain-language outcomes.", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -4)

    self.diagnosticFilter = self.diagnosticFilter or "ALL"
    self.diagnosticOffset = self.diagnosticOffset or 0
    local filterValues = { "ALL", "ENCOUNTER", "WIPE", "LOOT", "SYNC" }
    local filterBtn = CreateFrame("Button", nil, listInset, "UIPanelButtonTemplate")
    filterBtn:SetSize(125, 20)
    filterBtn:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -6)
    filterBtn:SetScript("OnClick", function()
        local current = 1
        for i, value in ipairs(filterValues) do
            if value == UI.diagnosticFilter then current = i break end
        end
        UI.diagnosticFilter = filterValues[(current % #filterValues) + 1]
        UI.diagnosticOffset = 0
        UI.selectedDiagnostic = nil
        UI:UpdateDiagnostics()
    end)
    self.diagnosticFilterButton = filterBtn

    self.diagnosticRows = {}
    for i = 1, 15 do
        local row = CreateFrame("Button", nil, listInset)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT", listInset, "TOPLEFT", 10, -80 - (i - 1) * 23)
        row:SetPoint("RIGHT", listInset, "RIGHT", -10, 0)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", 4, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        row.text = text
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnClick", function(selfRow)
            UI.selectedDiagnostic = selfRow.entry
            UI:UpdateDiagnostics()
        end)
        self.diagnosticRows[i] = row
    end
    listInset:EnableMouseWheel(true)
    listInset:SetScript("OnMouseWheel", function(_, delta)
        local filtered = UI:GetFilteredDiagnostics()
        local maxOffset = math.max(0, #filtered - #UI.diagnosticRows)
        UI.diagnosticOffset = math.max(0, math.min(maxOffset, (UI.diagnosticOffset or 0) - delta * 3))
        UI:UpdateDiagnostics()
    end)

    local detailTitle = createLabel(detailInset, "Decision details", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailInset, "TOPLEFT", 10, -10)
    local activeStatus = createLabel(detailInset, "No active encounter", "GameFontHighlightSmall")
    activeStatus:SetPoint("TOPRIGHT", detailInset, "TOPRIGHT", -12, -10)
    activeStatus:SetJustifyH("RIGHT")
    self.diagnosticEncounterStatus = activeStatus
    local detailScroll = CreateFrame("ScrollFrame", "GoalsDiagnosticDetailScroll", detailInset, "UIPanelScrollFrameTemplate")
    detailScroll:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -10)
    detailScroll:SetPoint("BOTTOMRIGHT", detailInset, "BOTTOMRIGHT", -30, 66)
    local detail = CreateFrame("EditBox", nil, detailScroll)
    detail:SetMultiLine(true)
    detail:SetAutoFocus(false)
    detail:SetFontObject("GameFontHighlight")
    detail:SetWidth(430)
    detail:SetTextInsets(6, 6, 6, 6)
    detail:SetScript("OnEscapePressed", function(selfBox) selfBox:ClearFocus() end)
    detailScroll:SetScrollChild(detail)
    detailScroll:SetScript("OnSizeChanged", function(selfScroll)
        detail:SetWidth(math.max(100, (selfScroll:GetWidth() or 430) - 4))
    end)
    self.diagnosticDetail = detail
    self.diagnosticDetailScroll = detailScroll

    local copyBtn = CreateFrame("Button", nil, detailInset, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 22)
    copyBtn:SetPoint("BOTTOMLEFT", detailInset, "BOTTOMLEFT", 10, 34)
    copyBtn:SetText("Copy Report")
    copyBtn:SetScript("OnClick", function()
        detail:SetFocus()
        detail:HighlightText()
    end)
    local clearBtn = CreateFrame("Button", nil, detailInset, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 22)
    clearBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function() Goals:ClearDiagnostics() end)
    local copyAllBtn = CreateFrame("Button", nil, detailInset, "UIPanelButtonTemplate")
    copyAllBtn:SetSize(80, 22)
    copyAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    copyAllBtn:SetText("Copy All")
    copyAllBtn:SetScript("OnClick", function()
        local reports = {}
        for _, entry in ipairs(UI:GetFilteredDiagnostics()) do
            table.insert(reports, Goals:FormatDiagnostic(entry))
        end
        detail:SetText(table.concat(reports, "\n\n----------------\n\n"))
        detail:SetFocus()
        detail:HighlightText()
    end)
    local pauseBtn = CreateFrame("Button", nil, detailInset, "UIPanelButtonTemplate")
    pauseBtn:SetSize(80, 22)
    pauseBtn:SetPoint("LEFT", copyAllBtn, "RIGHT", 8, 0)
    pauseBtn:SetScript("OnClick", function()
        Goals.diagnostics = Goals.diagnostics or { entries = {}, paused = false, nextId = 1 }
        Goals.diagnostics.paused = not Goals.diagnostics.paused
        UI:UpdateDiagnostics()
    end)
    self.diagnosticPauseButton = pauseBtn
    self:UpdateDiagnostics()
end

function UI:GetFilteredDiagnostics()
    local result = {}
    local filter = self.diagnosticFilter or "ALL"
    for _, entry in ipairs(Goals:GetDiagnostics()) do
        if filter == "ALL" or entry.category == filter then
            table.insert(result, entry)
        end
    end
    return result
end

function UI:UpdateDiagnostics()
    if not self.diagnosticRows then return end
    local entries = self:GetFilteredDiagnostics()
    local maxOffset = math.max(0, #entries - #self.diagnosticRows)
    self.diagnosticOffset = math.max(0, math.min(maxOffset, self.diagnosticOffset or 0))
    for i, row in ipairs(self.diagnosticRows) do
        local entry = entries[i + self.diagnosticOffset]
        row.entry = entry
        if entry then
            row.text:SetText(string.format("%s  %-10s  %s", date("%H:%M:%S", entry.ts), entry.category, entry.summary))
            row:Show()
        else
            row:Hide()
        end
    end
    if self.selectedDiagnostic then
        local stillPresent = false
        for _, entry in ipairs(entries) do
            if entry == self.selectedDiagnostic then stillPresent = true break end
        end
        if not stillPresent then self.selectedDiagnostic = nil end
    end
    if not self.selectedDiagnostic then self.selectedDiagnostic = entries[1] end
    if self.diagnosticDetail then self.diagnosticDetail:SetText(Goals:FormatDiagnostic(self.selectedDiagnostic)) end
    if self.diagnosticPauseButton then
        self.diagnosticPauseButton:SetText(Goals.diagnostics and Goals.diagnostics.paused and "Resume" or "Pause")
    end
    if self.diagnosticFilterButton then
        self.diagnosticFilterButton:SetText("Filter: " .. (self.diagnosticFilter == "ALL" and "All" or self.diagnosticFilter))
    end
    if self.diagnosticEncounterStatus then
        if Goals.encounter and Goals.encounter.active then
            local rule = Goals.encounter.rule and Goals.encounter.rule.type or "all required"
            self.diagnosticEncounterStatus:SetText(string.format("Active: %s  |  Rule: %s", Goals.encounter.name or "Encounter", rule))
            self.diagnosticEncounterStatus:SetTextColor(1, 0.82, 0.25, 1)
        else
            self.diagnosticEncounterStatus:SetText("No active encounter")
            self.diagnosticEncounterStatus:SetTextColor(0.65, 0.65, 0.65, 1)
        end
    end
end
