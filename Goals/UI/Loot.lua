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

function UI:GetLootNote(key)
    if not key or not Goals.db or not Goals.db.lootNotes then
        return nil
    end
    return Goals.db.lootNotes[key]
end

function UI:SetLootNote(key, text)
    if not key or not Goals.db then
        return
    end
    Goals.db.lootNotes = Goals.db.lootNotes or {}
    local noteText = text or ""
    if noteText == "" then
        Goals.db.lootNotes[key] = nil
        return
    end
    local author = Goals.GetPlayerName and Goals:GetPlayerName() or ""
    Goals.db.lootNotes[key] = {
        note = noteText,
        author = author,
        ts = time(),
    }
end

function UI:GetLootTableEntries()
    local list = {}
    local history = self:GetLootHistoryEntries()
    local foundByLink = {}
    local seenFound = {}
    local foundIndexByKey = {}
    local LOOT_GROUP_WINDOW = 15
    local LOOT_ASSIGN_MERGE_WINDOW = 3600

    local function getItemIdentity(itemLink)
        if Goals and Goals.GetLootIdentityKey then
            return Goals:GetLootIdentityKey(itemLink)
        end
        return itemLink or ""
    end

    for _, entry in ipairs(history) do
        if entry.kind == "LOOT_FOUND" then
            local itemLink = entry.data and entry.data.item or nil
            if itemLink and itemLink ~= "" then
                local identity = getItemIdentity(itemLink)
                foundByLink[identity] = foundByLink[identity] or {}
                table.insert(foundByLink[identity], {
                    entry = entry,
                    key = getLootNoteKey(itemLink, entry.ts),
                })
            end
        end
    end

    for _, entries in pairs(foundByLink) do
        table.sort(entries, function(a, b)
            return (a.entry.ts or 0) < (b.entry.ts or 0)
        end)
    end

    local function markFoundUsed(foundEntry)
        if not foundEntry then
            return
        end
        seenFound[foundEntry.key or ""] = true
    end

    for _, entry in ipairs(history) do
        if entry.kind == "LOOT_ASSIGN" then
            local dataEntry = entry.data or {}
            local itemLink = dataEntry.item or ""
            local matched = nil
            local listForLink = foundByLink[getItemIdentity(itemLink)]
            if listForLink then
                for i = #listForLink, 1, -1 do
                    local candidate = listForLink[i]
                    if (candidate.entry.ts or 0) <= (entry.ts or 0) then
                        matched = candidate
                        table.remove(listForLink, i)
                        break
                    end
                end
            end
            if matched and ((entry.ts or 0) - (matched.entry.ts or 0) <= LOOT_ASSIGN_MERGE_WINDOW) then
                markFoundUsed(matched)
                local playerName = dataEntry.player or ""
                local players = dataEntry.players
                local noteKey = matched.key or getLootNoteKey(itemLink, matched.entry.ts or entry.ts)
                table.insert(list, {
                    kind = "FOUND",
                    ts = matched.entry.ts or entry.ts,
                    item = itemLink,
                    slot = nil,
                    raw = nil,
                    assignedTo = playerName,
                    assignedCount = (players and #players) or nil,
                    assignedPlayers = players,
                    reset = dataEntry.reset,
                    resetBefore = dataEntry.resetBefore,
                    noteKey = noteKey,
                    sourceFoundTs = matched.entry.ts,
                    sourceAssignTs = entry.ts,
                })
                if noteKey then
                    foundIndexByKey[noteKey] = #list
                end
            else
                entry.noteKey = getLootNoteKey(itemLink, entry.ts)
                table.insert(list, entry)
            end
        end
    end

    local remainingByLink = {}
    for _, entry in ipairs(history) do
        if entry.kind == "LOOT_FOUND" then
            local itemLink = entry.data and entry.data.item or nil
            local key = getLootNoteKey(itemLink, entry.ts)
            if key and not seenFound[key] then
                remainingByLink[itemLink] = remainingByLink[itemLink] or {}
                table.insert(remainingByLink[itemLink], { entry = entry, key = key })
            end
        end
    end

    for itemLink, entries in pairs(remainingByLink) do
        table.sort(entries, function(a, b)
            return (a.entry.ts or 0) < (b.entry.ts or 0)
        end)
        local groupCount = 0
        local groupLast = 0
        local groupFirst = 0
        local groupKey = nil
        local groupEntry = nil
        local function flushGroup()
            if groupCount <= 0 then
                return
            end
            local noteKey = groupKey or getLootNoteKey(itemLink, groupLast)
            local foundData = groupEntry and groupEntry.data or nil
            table.insert(list, {
                kind = "FOUND",
                ts = groupLast,
                item = itemLink,
                slot = nil,
                raw = nil,
                noteKey = noteKey,
                stackCount = groupCount,
                assignedTo = groupCount == 1 and foundData and foundData.assignedTo or nil,
                reset = groupCount == 1 and foundData and foundData.reset or nil,
                resetBefore = groupCount == 1 and foundData and foundData.resetBefore or nil,
                sourceFoundTs = groupCount == 1 and groupEntry and groupEntry.ts or nil,
                sourceAssignTs = nil,
            })
            if noteKey then
                foundIndexByKey[noteKey] = #list
            end
            groupCount = 0
            groupLast = 0
            groupFirst = 0
            groupKey = nil
            groupEntry = nil
        end
        for _, wrapper in ipairs(entries) do
            local ts = wrapper.entry.ts or 0
            if groupCount == 0 then
                groupCount = 1
                groupFirst = ts
                groupLast = ts
                groupKey = wrapper.key
                groupEntry = wrapper.entry
            elseif ts - groupLast <= LOOT_GROUP_WINDOW then
                groupCount = groupCount + 1
                groupLast = ts
                groupKey = wrapper.key
                groupEntry = nil
            else
                flushGroup()
                groupCount = 1
                groupFirst = ts
                groupLast = ts
                groupKey = wrapper.key
                groupEntry = wrapper.entry
            end
        end
        flushGroup()
    end

    if Goals and Goals.GetFoundLoot then
        local found = Goals:GetFoundLoot() or {}
        for _, entry in ipairs(found) do
            if entry and entry.link then
                local key = getLootNoteKey(entry.link, entry.ts)
                local matched = nil
                local listForLink = foundByLink[getItemIdentity(entry.link)]
                if listForLink and #listForLink > 0 then
                    local bestIndex = nil
                    local bestDiff = nil
                    for i = #listForLink, 1, -1 do
                        local candidate = listForLink[i]
                        local diff = math.abs((candidate.entry.ts or 0) - (entry.ts or 0))
                        if diff <= 120 and (not bestDiff or diff < bestDiff) then
                            bestDiff = diff
                            bestIndex = i
                        end
                    end
                    if bestIndex then
                        matched = listForLink[bestIndex]
                        table.remove(listForLink, bestIndex)
                        key = matched.key or key
                        markFoundUsed(matched)
                    end
                end
                local existingIndex = key and foundIndexByKey[key] or nil
                if existingIndex then
                    local existing = list[existingIndex]
                    existing.raw = entry
                    existing.slot = entry.slot
                    existing.assignedTo = entry.assignedTo
                elseif key and not seenFound[key] then
                    table.insert(list, {
                        kind = "FOUND",
                        ts = entry.ts,
                        item = entry.link,
                        slot = entry.slot,
                        raw = entry,
                        assignedTo = entry.assignedTo,
                        noteKey = key,
                    })
                    foundIndexByKey[key] = #list
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return (a.ts or 0) > (b.ts or 0)
    end)

    return list
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

function UI:UpdateLootOptionsVisibility()
    if not self.lootOptionsFrame then
        return
    end
    local open = self.lootOptionsOpen
    if self.lootOptionsInline then
        open = true
    end
    local show = self.currentTab == self.lootTabId and open
    if self.lootOptionsOuter then
        setShown(self.lootOptionsOuter, show)
    end
    setShown(self.lootOptionsFrame, show)
end

function UI:CreateLootTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsLootOptionsInset", OPTIONS_PANEL_WIDTH)
    self.lootOptionsFrame = optionsPanel
    self.lootOptionsScroll = optionsPanel.scroll
    self.lootOptionsContent = optionsContent
    self.lootOptionsOpen = true
    self.lootOptionsInline = true

    local inset = CreateFrame("Frame", "GoalsLootInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    inset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    self.lootHistoryInset = inset
    if page.footer then
        anchorToFooter(inset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(inset, "GoalsLootTable", {
        columns = {
            { key = "time", title = "Time", width = 60, justify = "LEFT", wrap = false },
            { key = "item", title = "Item", width = 200, justify = "LEFT", wrap = false },
            { key = "player", title = "Player", width = 120, justify = "LEFT", wrap = false },
            { key = "notes", title = "Notes", fill = true, justify = "LEFT", wrap = false },
        },
        rowHeight = LOOT_HISTORY_ROW_HEIGHT_COMPACT,
        visibleRows = LOOT_HISTORY_ROWS,
        headerHeight = 16,
    })
    self.lootTable = tableWidget
    self.lootHistoryScroll = tableWidget.scroll
    self.lootHistoryRows = tableWidget.rows

    self.lootHistoryScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, LOOT_HISTORY_ROW_HEIGHT_COMPACT, function()
            UI:UpdateLootHistoryList()
        end)
    end)

    for _, row in ipairs(self.lootHistoryRows) do
        row:EnableMouse(true)
        row.badgeExpansion = createBadge(row)
        row.badgeTier = createBadge(row)
        if row.badgeExpansion.SetFrameStrata then
            row.badgeExpansion:SetFrameStrata("DIALOG")
        end
        if row.badgeTier.SetFrameStrata then
            row.badgeTier:SetFrameStrata("DIALOG")
        end
        if row.badgeExpansion.SetFrameLevel then
            row.badgeExpansion:SetFrameLevel(row:GetFrameLevel() + 10)
        end
        if row.badgeTier.SetFrameLevel then
            row.badgeTier:SetFrameLevel(row:GetFrameLevel() + 10)
        end
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        selected:SetBlendMode("ADD")
        selected:SetAlpha(0.5)
        selected:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        selected:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
        selected:Hide()
        row.selected = selected
        row:SetScript("OnMouseUp", function(selfRow, button)
            if selfRow.entry then
                UI:SetLootSelection(selfRow, selfRow.entry)
            end
            if button == "RightButton" and selfRow.entry and selfRow.entry.kind == "FOUND" then
                if selfRow.entry.sourceFoundTs then
                    UI:ShowLootHistoryEditMenu(selfRow, selfRow.entry)
                elseif selfRow.entry.raw and not selfRow.entry.raw.assignedTo then
                    UI:ShowFoundLootMenu(selfRow, selfRow.entry.raw)
                end
            end
        end)

        local itemButton = CreateFrame("Button", nil, row)
        itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        itemButton:SetPoint("TOPLEFT", row.cols.item, "TOPLEFT", 0, 0)
        itemButton:SetPoint("BOTTOMRIGHT", row.cols.item, "BOTTOMRIGHT", 0, 0)
        itemButton:SetScript("OnMouseUp", function(selfBtn, button)
            local selfRow = selfBtn:GetParent()
            if selfRow and selfRow.entry then
                UI:SetLootSelection(selfRow, selfRow.entry)
            end
            if button == "RightButton" and selfRow and selfRow.entry and selfRow.entry.kind == "FOUND"
                and selfRow.entry.raw and not selfRow.entry.raw.assignedTo then
                UI:ShowFoundLootMenu(selfRow, selfRow.entry.raw)
                return
            end
            if button == "LeftButton" and selfRow and selfRow.itemLink and selfRow.itemLink ~= "" then
                if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
                    HandleModifiedItemClick(selfRow.itemLink)
                    return
                end
                if ItemRefTooltip then
                    ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
                    ItemRefTooltip:SetHyperlink(selfRow.itemLink)
                elseif GameTooltip then
                    GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(selfRow.itemLink)
                end
            end
        end)
        itemButton:SetScript("OnEnter", function(selfBtn)
            local selfRow = selfBtn:GetParent()
            if not selfRow or not selfRow.itemLink or selfRow.itemLink == "" then
                return
            end
            if GameTooltip then
                GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(selfRow.itemLink)
                GameTooltip:Show()
            end
        end)
        itemButton:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        row.itemButton = itemButton
    end

    local function setLootMethod(method)
        local ok, err = Goals:SetLootMethod(method)
        if not ok and err then
            Goals:Print(err)
        end
    end

    local y = -10
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

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    addSectionHeader(L.LABEL_LOOT_METHOD)
    addButton(L.LOOT_METHOD_MASTER, function()
        setLootMethod("master")
    end)
    addButton(L.LOOT_METHOD_GROUP, function()
        setLootMethod("group")
    end)
    addButton(L.LOOT_METHOD_FREE, function()
        setLootMethod("freeforall")
    end)

    y = y - 8
    addSectionHeader(L.LABEL_LOOT_HISTORY)
    addLabel(L.LABEL_LOOT_HISTORY_FILTER)

    local minFilterDrop = addDropdown("GoalsLootHistoryMinQuality")
    attachSideTooltip(minFilterDrop, "Hide items below this quality in Loot History.")
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

    y = y - 8
    addSectionHeader(L.LABEL_RESET_POINTS)
    self.resetMountsCheck = addCheck("Reset mounts to 0", function(selfBtn)
        Goals:SetRaidSetting("resetMounts", selfBtn:GetChecked() and true or false)
    end, "Set mount winners to 0 points when they win these items.")
    self.resetPetsCheck = addCheck("Reset pets to 0", function(selfBtn)
        Goals:SetRaidSetting("resetPets", selfBtn:GetChecked() and true or false)
    end, "Set pet winners to 0 points when they win these items.")
    self.resetRecipesCheck = addCheck("Reset recipes to 0", function(selfBtn)
        Goals:SetRaidSetting("resetRecipes", selfBtn:GetChecked() and true or false)
    end, "Set recipe winners to 0 points when they win these items.")
    self.resetTokensCheck = addCheck("Reset tier tokens to 0", function(selfBtn)
        Goals:SetRaidSetting("resetTokens", selfBtn:GetChecked() and true or false)
    end, "Set tier token winners to 0 points when they win these items.")
    self.resetQuestItemsCheck = addCheck("Reset quest items to 0", function(selfBtn)
        Goals:SetRaidSetting("resetQuestItems", selfBtn:GetChecked() and true or false)
    end, "Set quest item winners to 0 points when they win these items.")
    self.resetBagsCheck = addCheck("Reset bags to 0", function(selfBtn)
        Goals:SetRaidSetting("resetBags", selfBtn:GetChecked() and true or false)
    end, "When disabled, bags remain in loot history but never reset the winner's points because of item quality.")
    self.resetLootWindowCheck = addCheck("Manual mode", function(selfBtn)
        Goals:SetRaidSetting("resetRequiresLootWindow", selfBtn:GetChecked() and true or false)
    end, "Disable automatic resets unless loot is being assigned.")

    addLabel(L.LABEL_MIN_RESET_QUALITY)
    local minDrop = addDropdown("GoalsResetQualityDropdown")
    attachSideTooltip(minDrop, "Only reset points for items at or above this quality.")
    self.resetQualityDropdown = minDrop
    self:SetupResetQualityDropdown(minDrop)

    y = y - 6
    addSectionHeader("Current Point Policy")
    local policy = addInfoLabel("")
    policy:SetWidth(OPTIONS_CONTROL_WIDTH)
    policy:SetJustifyH("LEFT")
    policy:SetJustifyV("TOP")
    policy:SetHeight(92)
    y = y - 76
    self.lootPolicyPreview = policy

    y = y - 8
    addSectionHeader("Notes")

    addLabel("Selected entry")
    local selectedValue = createLabel(optionsContent, "None", "GameFontHighlightSmall")
    selectedValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    selectedValue:SetWidth(OPTIONS_CONTROL_WIDTH)
    selectedValue:SetJustifyH("LEFT")
    styleOptionsLabel(selectedValue)
    self.lootNotesSelectedLabel = selectedValue
    y = y - 18

    addLabel("Note text")
    local notesBox = CreateFrame("EditBox", nil, optionsContent, "InputBoxTemplate")
    notesBox:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 18, y)
    styleOptionsEditBox(notesBox, OPTIONS_CONTROL_WIDTH - 10)
    attachSideTooltip(notesBox, "Add a note for the selected loot entry.")
    notesBox:SetAutoFocus(false)
    bindEscapeClear(notesBox)
    notesBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    self.lootNotesBox = notesBox
    y = y - 30

    local applyBtn, clearBtn = addButtonPair("Apply", function()
        if not UI.lootSelectedNoteKey then
            return
        end
        UI:SetLootNote(UI.lootSelectedNoteKey, notesBox:GetText() or "")
        UI:UpdateLootHistoryList()
        UI:UpdateLootNoteSelection()
    end, "Clear", function()
        if not UI.lootSelectedNoteKey then
            return
        end
        UI:SetLootNote(UI.lootSelectedNoteKey, "")
        UI:UpdateLootHistoryList()
        UI:UpdateLootNoteSelection()
    end)
    self.lootNotesApplyButton = applyBtn
    self.lootNotesClearButton = clearBtn

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
end

function UI:SetLootSelection(row, entry)
    if self.lootSelectedRow and self.lootSelectedRow.selected then
        self.lootSelectedRow.selected:Hide()
    end
    self.lootSelectedRow = row
    self.lootSelectedEntry = entry
    self.lootSelectedNoteKey = entry and entry.noteKey or nil
    if row and row.selected then
        row.selected:Show()
    end
    if self.UpdateLootNoteSelection then
        self:UpdateLootNoteSelection()
    end
end

function UI:UpdateLootNoteSelection()
    if not self.lootNotesBox or not self.lootNotesApplyButton or not self.lootNotesClearButton then
        return
    end
    local key = self.lootSelectedNoteKey
    local entry = self.lootSelectedEntry
    if not key or not entry then
        if self.lootNotesSelectedLabel then
            self.lootNotesSelectedLabel:SetText("None")
        end
        self.lootNotesBox:SetText("")
        if self.lootNotesApplyButton.Disable then
            self.lootNotesApplyButton:Disable()
        end
        if self.lootNotesClearButton.Disable then
            self.lootNotesClearButton:Disable()
        end
        return
    end
    local label = entry.item or (entry.data and entry.data.item) or entry.text or "Selected"
    if self.lootNotesSelectedLabel then
        self.lootNotesSelectedLabel:SetText(label)
    end
    local note = self:GetLootNote(key)
    self.lootNotesBox:SetText(note and note.note or "")
    if self.lootNotesApplyButton.Enable then
        self.lootNotesApplyButton:Enable()
    end
    if self.lootNotesClearButton.Enable then
        self.lootNotesClearButton:Enable()
    end
end

function UI:UpdateLootHistoryList()
    if not self.lootHistoryScroll or not self.lootHistoryRows then
        return
    end
    local data = self:GetLootTableEntries()
    self.lootHistoryData = data
    local offset = FauxScrollFrame_GetOffset(self.lootHistoryScroll) or 0
    local visibleRows = #self.lootHistoryRows
    FauxScrollFrame_Update(self.lootHistoryScroll, #data, visibleRows, LOOT_HISTORY_ROW_HEIGHT_COMPACT)
    setScrollBarAlwaysVisible(self.lootHistoryScroll, #data * LOOT_HISTORY_ROW_HEIGHT_COMPACT)
    local dis = Goals.db and Goals.db.settings and Goals.db.settings.disenchanter or ""
    local disenchanterActive = dis ~= "" and dis ~= "0" and dis ~= L.NONE_OPTION
    local groupSize = 0
    if Goals and Goals.IsInRaid and Goals:IsInRaid() then
        groupSize = GetNumRaidMembers and GetNumRaidMembers() or 0
    elseif Goals and Goals.IsInParty and Goals:IsInParty() then
        local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
        groupSize = partyCount + 1
    else
        groupSize = 1
    end
    local hasRainbow = false
    local selectedFound = false
    for i = 1, visibleRows do
        local row = self.lootHistoryRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            row.entry = entry
            if row.timeText then
                row.timeText:SetText(formatTime(entry.ts))
            end
            row.rainbowData = nil
            row.itemLink = nil
            local itemText = ""
            local playerText = ""
            local notesText = ""
            local isPlayer = false

            if entry.kind == "FOUND" then
                itemText = entry.item or ""
                if entry.assignedCount and entry.assignedCount >= 3 then
                    playerText = formatPlayersCount(entry.assignedCount)
                    notesText = "Assigned"
                    row.rainbowData = {
                        kind = "loot",
                        count = entry.assignedCount,
                        itemLink = entry.item or "",
                    }
                    hasRainbow = true
                elseif entry.assignedTo and entry.assignedTo ~= "" then
                    playerText = entry.assignedTo
                    isPlayer = true
                    local isDisenchant = disenchanterActive and playerText == dis
                    if isDisenchant then
                        notesText = "Disenchanted"
                    elseif entry.reset then
                        local before = tonumber(entry.resetBefore) or 0
                        notesText = string.format("Assigned (Reset -%d)", before)
                    else
                        notesText = "Assigned"
                    end
                else
                    local stackCount = entry.stackCount or 0
                    if stackCount > 1 then
                        if groupSize > 0 and (stackCount % groupSize) == 0 then
                            local perPlayer = math.floor(stackCount / groupSize)
                            if perPlayer > 1 then
                                itemText = string.format("%s x%d", itemText, perPlayer)
                            else
                                itemText = string.format("%s x%d", itemText, stackCount)
                            end
                            playerText = "All Players"
                        else
                            itemText = string.format("%s x%d", itemText, stackCount)
                            playerText = "Group"
                        end
                    else
                        playerText = "Unassigned"
                    end
                    if entry.raw then
                        notesText = "Found"
                    else
                        notesText = "Looted"
                    end
                end
                row.itemLink = entry.item
            elseif entry.kind == "LOOT_FOUND" then
                local itemLink = entry.data and entry.data.item or ""
                itemText = itemLink
                notesText = "Looted"
                row.itemLink = itemLink
            elseif entry.kind == "LOOT_ASSIGN" then
                local dataEntry = entry.data or {}
                local itemLink = dataEntry.item or ""
                local players = dataEntry.players or nil
                itemText = itemLink
                row.itemLink = itemLink
                if players and #players >= 3 then
                    local count = #players
                    row.rainbowData = {
                        kind = "loot",
                        count = count,
                        itemLink = itemLink,
                    }
                    playerText = formatPlayersCount(count)
                    notesText = "Assigned"
                    hasRainbow = true
                else
                    playerText = dataEntry.player or ""
                    isPlayer = playerText ~= ""
                    local isDisenchant = disenchanterActive and playerText ~= "" and playerText == dis
                    if isDisenchant then
                        notesText = "Disenchanted"
                    elseif dataEntry.reset then
                        local before = tonumber(dataEntry.resetBefore) or 0
                        notesText = string.format("Assigned (Reset -%d)", before)
                    else
                        notesText = "Assigned"
                    end
                end
            else
                itemText = entry.text or ""
            end

            if entry.noteKey then
                local manualNote = self:GetLootNote(entry.noteKey)
                if manualNote and manualNote.note and manualNote.note ~= "" then
                    notesText = manualNote.note
                end
            end

            if row.cols then
                if row.cols.item then
                    setLootItemLabelText(row.cols.item, itemText or "")
                end
                if row.cols.player then
                    row.cols.player:SetText(playerText or "")
                    if isPlayer and playerText ~= "" then
                        local r, g, b = Goals:GetPlayerColor(playerText)
                        row.cols.player:SetTextColor(r, g, b)
                    elseif entry.kind == "FOUND" then
                        row.cols.player:SetTextColor(0.8, 0.8, 0.8)
                    else
                        row.cols.player:SetTextColor(1, 1, 1)
                    end
                end
                if row.cols.notes then
                    row.cols.notes:SetText(notesText or "")
                end
            elseif row.text then
                row.text:SetText(entry.text or "")
            end
            if row.selected then
                if entry.noteKey and self.lootSelectedNoteKey and entry.noteKey == self.lootSelectedNoteKey then
                    row.selected:Show()
                    self.lootSelectedRow = row
                    self.lootSelectedEntry = entry
                    selectedFound = true
                else
                    row.selected:Hide()
                end
            end
        else
            row:Hide()
            row.itemLink = nil
            row.rainbowData = nil
            row.entry = nil
            if row.selected then
                row.selected:Hide()
            end
        end
    end
    if hasRainbow then
        self:StartRainbowTicker()
    end
    if self.lootSelectedNoteKey and not selectedFound then
        self.lootSelectedRow = nil
        self.lootSelectedEntry = nil
        self.lootSelectedNoteKey = nil
    end
    if self.UpdateLootNoteSelection then
        self:UpdateLootNoteSelection()
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
    local filtered = {}
    for _, entry in ipairs(data) do
        if entry and not entry.assignedTo then
            table.insert(filtered, entry)
        end
    end
    self.foundLootData = filtered
    local offset = FauxScrollFrame_GetOffset(self.foundLootScroll) or 0
    FauxScrollFrame_Update(self.foundLootScroll, #filtered, LOOT_ROWS, ROW_HEIGHT)
    for i = 1, LOOT_ROWS do
        local row = self.foundLootRows[i]
        local entry = filtered[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
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
        local players = {}
        if Goals.GetGroupMembers then
            local members = Goals:GetGroupMembers()
            local seen = {}
            for _, member in ipairs(members) do
                local normalized = Goals:NormalizeName(member.name)
                if normalized ~= "" and not seen[normalized] then
                    seen[normalized] = true
                    table.insert(players, member.name)
                end
            end
        end
        if #players == 0 then
            players = UI:GetPresentPlayerNames()
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

function UI:ShowLootHistoryEditMenu(row, entry)
    local hasLeaderAccess = Goals and Goals.HasLeaderAccess and Goals:HasLeaderAccess()
    if not entry or not entry.sourceFoundTs or (not hasLeaderAccess and not hasModifyAccess()) then
        return
    end
    if not self.lootHistoryEditMenu then
        self.lootHistoryEditMenu = CreateFrame("Frame", "GoalsLootHistoryEditMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local players = {}
    local seen = {}
    for _, member in ipairs(Goals:GetGroupMembers() or {}) do
        local name = Goals:NormalizeName(member.name)
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(players, name)
        end
    end
    if #players == 0 then
        players = self:GetPresentPlayerNames()
    end
    table.sort(players)
    local menu = self.lootHistoryEditMenu
    menu.lootEntry = entry
    UIDropDownMenu_Initialize(menu, function(_, level)
        local selected = menu.lootEntry
        if not selected then return end
        if level == 1 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Change recipient"
            info.notCheckable = true
            info.hasArrow = true
            info.value = "ASSIGN"
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Change recipient + reset points"
            info.notCheckable = true
            info.hasArrow = true
            info.value = "RESET"
            UIDropDownMenu_AddButton(info, level)

            if selected.assignedTo and selected.assignedTo ~= "" then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Mark unassigned (undo reset)"
                info.notCheckable = true
                info.func = function()
                    Goals:EditLootHistoryRecord(selected.item, selected.sourceFoundTs, selected.sourceAssignTs or 0, "UNASSIGN", "", false)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        elseif level == 2 and (UIDROPDOWNMENU_MENU_VALUE == "ASSIGN" or UIDROPDOWNMENU_MENU_VALUE == "RESET") then
            local mode = UIDROPDOWNMENU_MENU_VALUE
            for _, name in ipairs(players) do
                local player = name
                local info = UIDropDownMenu_CreateInfo()
                info.text = colorizeName(player)
                info.notCheckable = true
                info.func = function()
                    Goals:EditLootHistoryRecord(selected.item, selected.sourceFoundTs, selected.sourceAssignTs or 0, mode, player, false)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end
